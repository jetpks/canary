require "rspec/core"
require "tempfile"

module Canary
  module Adapters
    # RSpec's global state (RSpec.world, RSpec.configuration) is normally a
    # foot-gun across repeated in-process runs, but here it's not a problem:
    # each rollout runs in a forked child that runs one suite and exits, and
    # #warm_up resets that state before any child ever forks, so there's
    # nothing left over for a real rollout to inherit.
    class RSpecAdapter
      NAME = :rspec

      # Preloads rspec-core and everything it would otherwise load lazily.
      # Called once in the parent, before Coverage.start, so none of it is
      # instrumented.
      def self.preload
        require "rspec/core"
        warm_up
        self
      end

      # rspec-core only requires rspec-expectations, rspec-mocks, and
      # rspec-support's diff machinery (differ/source, and under that,
      # ripper/pp/prettyprint/stringio) the first time a suite actually runs
      # a matcher, a mock, or a failing comparison - not when "rspec/core"
      # itself loads. Some of that (the diff machinery) is only reachable by
      # executing a failure, not by requiring a file, so a hand-written
      # require list can't close it. Running one real pass and one real
      # failure here, before any child forks, makes RSpec's own lazy-loading
      # decide what to load - the same thing it would do in a submission's
      # coverage window, just done here instead. Forcing every built-in
      # matcher's autoload closes the same gap for matchers this warmup
      # doesn't itself call. RSpec.reset then discards the World/Configuration
      # state the warmup leaves behind, so none of it leaks into a real
      # rollout's example count.
      def self.warm_up
        out = err = nil

        Tempfile.create(["canary_rspec_warmup", ".rb"]) do |file|
          file.write(<<~RUBY)
            RSpec.describe "canary rspec warmup" do
              it("passes") { expect(1).to eq(1) }
              it("fails") { expect(1).to eq(2) }
            end
          RUBY
          file.flush

          null = File::NULL
          out = File.open(null, "w")
          err = File.open(null, "w")
          RSpec::Core::Runner.run([file.path], err, out)
        end

        RSpec::Matchers::BuiltIn.constants.each { |c| RSpec::Matchers::BuiltIn.const_get(c) }
      ensure
        out&.close
        err&.close
        RSpec.reset
      end
      private_class_method :warm_up

      # Loads and runs +submission_path+ through RSpec::Core::Runner. The
      # actual load of the spec file happens inside Runner.run, so as long
      # as this is called after Coverage.start in the caller, the submission
      # is instrumented correctly.
      def run(submission_path)
        null = File::NULL
        out = File.open(null, "w")
        err = File.open(null, "w")

        RSpec::Core::Runner.run([submission_path], err, out)

        build_result
      ensure
        out&.close
        err&.close
      end

      # Runs a task: +test_path+ (the grader) is loaded first via the
      # runner's own #setup, which registers its example groups but does not
      # yet run them; then the caller's block; then +solution_path+; then
      # the already-registered groups are run. This must happen in that
      # order because the caller starts Coverage from the block - loading
      # the grader before Coverage exists keeps it (and this framework) out
      # of the solution's coverage, while loading the solution after keeps
      # it in. #setup only registers example groups - the `it` blocks that
      # reference the solution don't run until #run_specs below, by which
      # point the solution is loaded.
      def run_task(solution_path:, test_path:)
        null = File::NULL
        out = File.open(null, "w")
        err = File.open(null, "w")

        options = RSpec::Core::ConfigurationOptions.new([test_path])
        runner = RSpec::Core::Runner.new(options)
        runner.setup(err, out)

        yield if block_given?

        load solution_path
        runner.run_specs(runner.world.ordered_example_groups)

        build_result
      ensure
        out&.close
        err&.close
      end

      private

      def build_result
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
      end
    end
  end
end
