require "minitest"

module Canary
  module Adapters
    # Drives Minitest::Runnable directly rather than Minitest.run, since the
    # latter is designed around a single process-lifetime CLI invocation
    # (at_exit hooks, autorun). We fork-and-die per rollout instead, so we
    # only need the pieces that run a suite and hand back results.
    class MinitestAdapter
      NAME = :minitest

      # Preloads Minitest itself. Called once in the parent, before
      # Coverage.start, so none of this file's parsing is instrumented.
      #
      # "pp" is preloaded too: Minitest::Test.make_my_diffs_pretty! (a real,
      # if rare, submission-facing API) lazily requires it, and a submission
      # that calls it would otherwise leak pp/prettyprint into its own
      # coverage.
      def self.preload
        require "minitest"
        require "pp"
        self
      end

      # Loads +submission_path+ (which must happen after Coverage.start in
      # the caller) and runs every Minitest::Test subclass it newly defines.
      def run(submission_path)
        before = Minitest::Runnable.runnables.dup
        load submission_path
        run_suite(Minitest::Runnable.runnables - before)
      end

      # Runs a task: +test_path+ (the grader) is loaded first, then the
      # caller's block, then +solution_path+. This must happen in that
      # order because the caller starts Coverage from the block - loading
      # the grader (which only registers a Minitest::Test subclass; none of
      # its test methods run yet) before Coverage exists keeps the grader
      # and this framework out of the solution's coverage, while loading
      # the solution after keeps it in.
      def run_task(solution_path:, test_path:)
        before = Minitest::Runnable.runnables.dup
        load test_path
        klasses = Minitest::Runnable.runnables - before

        yield if block_given?

        load solution_path
        run_suite(klasses)
      end

      private

      def run_suite(klasses)
        Minitest.seed = 42
        reporter = CollectingReporter.new

        klasses.each do |klass|
          klass.run_suite(reporter, {}) if klass.respond_to?(:run_suite)
        end

        examples = reporter.results.map do |result|
          status = if result.skipped?
                     :skipped
                   elsif result.passed?
                     :passed
                   else
                     :failed
                   end

          ExampleResult.new(
            name: "#{result.klass}##{result.name}",
            status: status,
            message: result.passed? ? nil : result.failure&.message
          )
        end

        passed = examples.count { |e| e.status == :passed }
        failed = examples.count { |e| e.status == :failed }

        RolloutResult.new(
          adapter: NAME,
          examples: examples,
          passed: passed,
          failed: failed,
          total: examples.size
        )
      end

      # Records every result, not just failures, so the pool can report a
      # full pass/fail breakdown.
      class CollectingReporter < Minitest::AbstractReporter
        attr_reader :results

        def initialize
          super
          @results = []
        end

        # +result+ arrives already a Minitest::Result - Runnable.run hands
        # reporters `klass.new(method_name).run`, and Test#run's own return
        # value is `Result.from self` (minitest.rb's own contract comment).
        # Wrapping it again here used to call Result.from on a Result,
        # which stamps `klass` from the wrapper's own class name
        # ("Minitest::Result") instead of the original test class.
        def record(result)
          @results << result
        end
      end
    end
  end
end
