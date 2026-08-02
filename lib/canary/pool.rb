require "coverage"
require "async"
require "digest"

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

      return result if digest_file(task.test_path) == grader_digest

      tampered_result(klass)
    end

    private

    def fork_and_collect(klass, timeout)
      reader, writer = IO.pipe

      pid = fork do
        reader.close
        # Lead its own process group so a timeout can kill every descendant
        # the submission leaves behind, not just this one pid.
        Process.setpgid(0, 0)
        writer.binmode
        Marshal.dump(yield, writer)
        writer.close
        exit!(0)
      end

      writer.close

      begin
        # Bounds the whole read, not just the wait for its first byte - a
        # descendant the submission leaves running holds the pipe's write
        # end open and would otherwise block `reader.read` past EOF forever.
        data = Sync { |task| task.with_timeout(timeout) { reader.read } }
      rescue Async::TimeoutError
        return timeout_result(klass, pid, reader, timeout)
      end

      reader.close
      _pid, status = Process.wait2(pid)

      data.empty? ? crash_result(klass, status) : marshalled_result(data, klass, status)
    end

    def marshalled_result(data, klass, status)
      Marshal.load(data)
    rescue ArgumentError
      # A child killed mid-write (e.g. by the timeout path racing a large
      # coverage payload) leaves a non-empty but truncated stream; Marshal
      # rejects it rather than silently returning junk.
      crash_result(klass, status)
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
      result.coverage = Coverage.result if coverage
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
      result.coverage = Coverage.result if coverage
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

    def adapter_class(name)
      ADAPTERS.fetch(name) do
        raise ArgumentError, "unknown adapter #{name.inspect}, expected one of #{ADAPTERS.keys}"
      end
    end
  end
end
