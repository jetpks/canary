require "coverage"

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

    # Preloads every requested adapter's framework in the parent process.
    def initialize(adapters: ADAPTERS.keys)
      adapters.each do |name|
        adapter_class(name).preload
      end
    end

    # Forks a child to run +submission_path+ through +adapter+, returning a
    # Canary::RolloutResult. When +coverage+ is true (the default) the child
    # also reports Coverage.result for every file it parsed.
    def rollout(adapter:, submission_path:, coverage: true)
      klass = adapter_class(adapter)
      reader, writer = IO.pipe

      pid = fork do
        reader.close
        writer.binmode
        Marshal.dump(run_in_child(klass, submission_path, coverage), writer)
        writer.close
        exit!(0)
      end

      writer.close
      data = reader.read
      reader.close
      Process.wait(pid)

      Marshal.load(data)
    end

    private

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
