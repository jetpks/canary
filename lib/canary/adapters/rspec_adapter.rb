require "rspec/core"

module Canary
  module Adapters
    # RSpec's global state (RSpec.world, RSpec.configuration) is normally a
    # foot-gun across repeated in-process runs, but here it's not a problem:
    # each rollout runs in a forked child that runs one suite and exits.
    # There's nothing left to leak into.
    class RSpecAdapter
      NAME = :rspec

      # Preloads rspec-core itself. Called once in the parent, before
      # Coverage.start, so none of this file's parsing is instrumented.
      def self.preload
        require "rspec/core"
        self
      end

      # Loads and runs +submission_path+ through RSpec::Core::Runner. The
      # actual load of the spec file happens inside Runner.run, so as long
      # as this is called after Coverage.start in the caller, the submission
      # is instrumented correctly.
      def run(submission_path)
        null = File::NULL
        out = File.open(null, "w")
        err = File.open(null, "w")

        RSpec::Core::Runner.run([submission_path], err, out)

        examples = RSpec.world.all_examples.map do |example|
          result = example.execution_result

          ExampleResult.new(
            name: example.full_description,
            status: result.status,
            message: result.exception&.message
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
      ensure
        out&.close
        err&.close
      end
    end
  end
end
