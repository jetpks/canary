require "coverage"
require "async"
require "digest"
require "stringio"

# The async gem's fiber scheduler routes blocking reads through IO::Buffer,
# which is still tagged experimental upstream; it has nothing to do with any
# code in this file. The warning fires in the parent, from
# #fork_and_collect's own `reader.read` below, not in a forked child, so it
# can't be scoped to a fork. Ruby gives Warning.warn no thread- or
# fiber-scoped override point, only this one process-wide one, so any fix
# has to live inside it.
#
# Two narrower predicates were tried live on this interpreter and rejected:
#
# - Toggling Warning[:experimental] off only around the read call races:
#   that read yields to the reactor while it waits, and a *different*
#   fiber's *unrelated* first-time experimental warning can fire while the
#   flag is down and be silently eaten as collateral damage - confirmed live
#   with a sibling fiber's unrelated Ractor "experimental API" warning
#   vanishing while this fiber's toggle window was open.
# - Filtering by message text alone, with no scoping at all, overcorrects
#   the other way: it silences this exact message from *any* caller in the
#   process, forever, not just this file's own read - confirmed live: a
#   bare IO::Buffer.new outside this file's read produced no warning at all
#   under a text-only filter, even though nothing here ever ran.
#
# Thread.current[] is fiber-local, not thread-wide (confirmed live under
# Async::Task - a value set in one task's fiber is invisible to a sibling
# task's fiber). Gating the text filter on a flag #fork_and_collect sets
# only for the span of its own read, in that read's own fiber, gets both:
# no cross-fiber collateral, and no suppression of this message from any
# other caller, ever.
module Warning
  def self.warn(message, category: nil)
    return if Thread.current[:canary_pool_suppress_io_buffer_warning] && message.include?("IO::Buffer is experimental")

    super
  end
end

module Canary
  # A fork-preloaded rollout pool.
  #
  # The parent preloads harness/framework scaffolding exactly once. Each
  # rollout forks a fresh child which starts Coverage (if requested), loads
  # the untrusted submission, runs it through the requested adapter, and
  # ships the structured result back to the parent over a pipe before
  # exiting.
  #
  # This ordering is load-bearing: Ruby only instruments code parsed after
  # Coverage.start/.setup. Everything preloaded here in the parent -
  # Minitest, RSpec, this library itself - is deliberately parsed before any
  # Coverage instance exists, so it never shows up in a submission's
  # coverage report. The submission is `load`ed only in the child, only
  # after Coverage.start.
  class Pool
    ADAPTERS = {
      minitest: Adapters::MinitestAdapter,
      rspec: Adapters::RSpecAdapter,
    }.freeze

    # Measured rollouts run 2.4ms-29ms; untrusted submissions are ordinary
    # inputs, not attacks, so a submission that merely runs a slow-but-legit
    # suite should never be mistaken for a hang. Generous on purpose - a
    # timeout that fires early is a worse bug than one that waits too long.
    DEFAULT_TIMEOUT = 5 # seconds

    # Preloads every requested adapter's framework in the parent process.
    def initialize(adapters: ADAPTERS.keys)
      adapters.each do |name|
        adapter_class(name).preload
      end
    end

    # Forks a child to run +submission_path+ through +adapter+, returning a
    # Canary::RolloutResult. When +coverage+ is true (the default) the child
    # also reports Coverage.result for every file it parsed.
    #
    # This always returns a RolloutResult and never raises into the caller:
    # a child that exits, exit!s, is killed by a signal, or never finishes
    # within +timeout+ seconds is reported via RolloutResult#outcome rather
    # than propagated as an exception.
    def rollout(adapter:, submission_path:, coverage: true, timeout: DEFAULT_TIMEOUT)
      klass = adapter_class(adapter)
      fork_and_collect(klass, timeout) { run_in_child(klass, submission_path, coverage) }
    end

    # Forks a child to run +task+ (a solution file graded by a separate test
    # file, per Canary::Task) through the task's adapter. Same failure
    # taxonomy and Coverage semantics as #rollout, plus one more terminal
    # outcome: the parent digests the grader file before forking and again
    # after the child exits, and reports :invalid rather than the child's
    # own result if it changed - a rollout that tampered with its own grader
    # is not scored, whatever it claims to have done.
    def rollout_task(task:, coverage: true, timeout: DEFAULT_TIMEOUT)
      klass = adapter_class(task.adapter)
      grader_digest = digest_file(task.test_path)

      result = fork_and_collect(klass, timeout) { run_task_in_child(klass, task, coverage) }

      return result if grader_unchanged?(task.test_path, grader_digest)

      tampered_result(klass)
    end

    private

    def fork_and_collect(klass, timeout, &block)
      reader, writer = IO.pipe

      pid = fork do
        reader.close
        # Lead its own process group so a timeout can kill every descendant
        # the submission leaves behind, not just this one pid. The worker
        # #relay forks below inherits this group automatically.
        Process.setpgid(0, 0)
        writer.binmode
        relay(writer, &block)
      end

      writer.close

      begin
        # Bounds the whole read, not just the wait for its first byte - a
        # descendant the submission leaves running holds the pipe's write
        # end open and would otherwise block `reader.read` past EOF forever.
        data = Sync do |task|
          Thread.current[:canary_pool_suppress_io_buffer_warning] = true
          task.with_timeout(timeout) { reader.read }
        end
      rescue Async::TimeoutError
        return timeout_result(klass, pid, reader, timeout)
      ensure
        Thread.current[:canary_pool_suppress_io_buffer_warning] = false
      end

      reader.close
      _pid, status = Process.wait2(pid)

      data.empty? ? crash_result(klass, status) : marshalled_result(data, klass, status)
    end

    # Runs inside the process #fork_and_collect just forked (the "relay").
    # The relay never runs a line of the submission itself: it forks a
    # second child (the "worker") to do that, and the worker closes
    # +writer+ - the parent-facing pipe it would otherwise have inherited -
    # before the submission gets to run at all. A pipe closed this way has
    # no path back open from inside the worker: not via ObjectSpace, not via
    # a guessed file descriptor, not via /dev/fd (verified against this
    # interpreter on darwin - each raises Errno::EBADF). The relay itself
    # only ever forwards bytes between two pipes it owns; it never
    # interprets or trusts them, and it reproduces the worker's own exit
    # status so the parent's failure taxonomy (crash/signal/timeout) still
    # reads off a single Process.wait2 the way it always has.
    def relay(writer, &block)
      inner_reader, inner_writer = IO.pipe
      inner_writer.binmode

      worker_pid = fork do
        inner_reader.close
        writer.close
        Marshal.dump(block.call, inner_writer)
        inner_writer.close
        exit!(0)
      end

      inner_writer.close
      IO.copy_stream(inner_reader, writer)
      inner_reader.close
      _worker_pid, worker_status = Process.wait2(worker_pid)
      writer.close

      Process.kill(worker_status.termsig, Process.pid) if worker_status.signaled?
      exit!(worker_status.exitstatus || 1)
    end

    def marshalled_result(data, klass, status)
      io = StringIO.new(data)

      begin
        result = Marshal.load(io)
      rescue ArgumentError
        # A child killed mid-write (e.g. by the timeout path racing a large
        # coverage payload) leaves a non-empty but truncated stream; Marshal
        # rejects it rather than silently returning junk. Verified live on
        # this interpreter: a truncated-but-structurally-plausible stream
        # raises ArgumentError specifically ("marshal data too short"),
        # which is why this stays paired with the real process status
        # rather than falling into the generic branch below - and why it's
        # scoped to just this call: a bug anywhere else in this method
        # should surface as the diagnostic branch below, not get mistaken
        # for a truncated wire.
        return crash_result(klass, status)
      end

      # The worker still has to hold *some* open pipe to the relay for the
      # length of the submission's run (it has to report a result
      # eventually), so a submission that finds it via ObjectSpace can still
      # write a forged object onto it - Marshal.load only ever consumes the
      # first object in a stream, same as the vulnerability this whole
      # relay exists to close. The honest path calls Marshal.dump exactly
      # once, ever, so any wire with bytes left after the first object
      # carries more than the trusted final write and is not trustworthy at
      # all - not the first object on it, not the last.
      return wire_tampered_result(klass) unless io.eof?

      result
    rescue StandardError, SystemStackError => e
      # Bytes that aren't a truncated dump of something real - garbage with
      # no valid version header, a corrupt embedded literal, a wire an
      # attacker wrote directly rather than one a legitimate write got cut
      # short - can make Marshal.load raise almost anything. Fuzzed this
      # live rather than guessing: TypeError, EOFError and RegexpError all
      # showed up (all StandardError, caught above), and a deeply-nested
      # array wire raises SystemStackError, which isn't - hence naming it
      # explicitly rather than trusting a bare `rescue` to catch everything
      # Marshal.load can throw at us.
      malformed_wire_result(klass, e)
    end

    def wire_tampered_result(klass)
      RolloutResult.new(
        adapter: klass::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :crash,
        error: "reporting pipe carried more than one object; discarding an untrustworthy result"
      )
    end

    def malformed_wire_result(klass, error)
      RolloutResult.new(
        adapter: klass::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :crash,
        error: "reporting pipe carried data Marshal.load could not parse " \
               "(#{error.class}: #{error.message}); discarding an untrustworthy result"
      )
    end

    def timeout_result(klass, pid, reader, timeout)
      begin
        # A leading "-" targets the whole process group (by construction,
        # this pid's own group), not just its leader. Never look the group
        # up via Process.getpgid: it raises Errno::ESRCH for an
        # exited-but-unreaped child - exactly this child's state - and
        # rescuing that would silently stop reaping its descendants.
        Process.kill("KILL", -pid)
      rescue Errno::ESRCH
        # the whole group already exited between the timeout firing and the
        # kill; still reap it below so it doesn't linger as a zombie.
      end
      Process.wait2(pid)
      reader.close

      RolloutResult.new(
        adapter: klass::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :timeout,
        error: "rollout exceeded #{timeout}s timeout"
      )
    end

    def tampered_result(klass)
      RolloutResult.new(
        adapter: klass::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :invalid,
        error: "grader file changed during the rollout; not scored"
      )
    end

    def digest_file(path)
      Digest::SHA256.file(path).hexdigest
    end

    # Deleting a grader outright - the most direct way to "modify" one - is
    # a bare Digest::SHA256.file away from crashing the harness instead of
    # scoring the rollout: the file this checks for no longer exists at all.
    # Treat that the same as a changed digest rather than let ENOENT escape
    # into the caller.
    def grader_unchanged?(path, digest)
      digest_file(path) == digest
    rescue Errno::ENOENT
      false
    end

    def crash_result(klass, status)
      detail = if status.signaled?
                 "terminated by signal #{status.termsig} (#{Signal.signame(status.termsig)})"
               else
                 "exited with status #{status.exitstatus} without reporting a result"
               end

      RolloutResult.new(
        adapter: klass::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :crash,
        error: detail
      )
    end

    def run_in_child(adapter_class, submission_path, coverage)
      Coverage.start(lines: true, branches: true) if coverage

      result = adapter_class.new.run(submission_path)
      result.coverage = coverage_result if coverage
      result
    rescue StandardError => e
      RolloutResult.new(
        adapter: adapter_class::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :error,
        error: "#{e.class}: #{e.message}"
      )
    end

    # The task-aware sibling of #run_in_child. The adapter is handed the
    # coverage-start hook as a block instead of this method calling
    # Coverage.start itself, because for a task the correct moment to start
    # it sits *between* the adapter's two loads (test file, then solution
    # file) - see each adapter's #run_task for why that ordering matters.
    def run_task_in_child(adapter_class, task, coverage)
      result = adapter_class.new.run_task(solution_path: task.solution_path, test_path: task.test_path) do
        Coverage.start(lines: true, branches: true) if coverage
      end
      result.coverage = coverage_result if coverage
      result
    rescue StandardError => e
      RolloutResult.new(
        adapter: adapter_class::NAME,
        examples: [],
        passed: 0,
        failed: 0,
        total: 0,
        outcome: :error,
        error: "#{e.class}: #{e.message}"
      )
    end

    # A submission that calls the bare Coverage.result itself stops
    # measurement as a side effect (that's the whole method's contract, not
    # a bug); our own later call above would otherwise raise and, caught by
    # the generic rescue on either caller, turn an honest pass into
    # outcome::error. Losing coverage data to that is a fair price - losing
    # the actual pass/fail verdict to it is not.
    def coverage_result
      Coverage.result
    rescue RuntimeError
      nil
    end

    def adapter_class(name)
      ADAPTERS.fetch(name) do
        raise ArgumentError, "unknown adapter #{name.inspect}, expected one of #{ADAPTERS.keys}"
      end
    end
  end
end
