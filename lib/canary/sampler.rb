require "dry/monads"
require "json"
require_relative "prompt"
require_relative "providers/error"

module Canary
  # Ties a provider, a budget, and a place to record what happened into one
  # call: render a task via Canary::Prompt, ask the provider for +n+
  # completions, and return one Dry::Monads::Result per completion. Every
  # request that actually reaches the provider is written to +record_sink+
  # first - a request the budget guard blocked never went out, so it is
  # never recorded.
  class Sampler
    include Dry::Monads[:result]

    # Counts attempted provider calls against a fixed cap. Deliberately
    # request-count based rather than a dollar figure: the sampler cannot
    # know a call's real cost before the provider answers, and the guard
    # has to decide *before* that call is made.
    class Budget
      def initialize(max_samples:)
        @max_samples = max_samples
        @spent = 0
      end

      def exhausted?
        @spent >= @max_samples
      end

      def spend!
        @spent += 1
      end
    end

    # Appends one JSON line per dispatched request/response to +path+.
    class RecordSink
      def initialize(path:)
        @path = path
      end

      def record(model:, mode:, task_name:, sample_index:, prompt:, payload:)
        entry = {
          model: model,
          mode: mode,
          task_name: task_name,
          sample_index: sample_index,
          request: {prompt: prompt},
          response: payload
        }
        File.open(@path, "a") { |f| f.puts(JSON.generate(entry)) }
      end
    end

    def initialize(provider:, budget:, record_sink:)
      @provider = provider
      @budget = budget
      @record_sink = record_sink
    end

    # Renders +entry+ once (hidden by default, grader-visible when
    # +grader+ is true) and asks the provider for +n+ completions,
    # returning one Dry::Monads::Result per completion in order.
    def call(entry, model:, n: 1, grader: false)
      rendered = Prompt.render(entry, grader: grader)

      Array.new(n) { |index| sample_one(entry.name, rendered, model, index) }
    end

    private

    def sample_one(task_name, rendered, model, index)
      if @budget.exhausted?
        return Failure(Providers::Error.new(
          reason: :budget_exhausted,
          message: "budget exhausted before sample #{index} of #{task_name.inspect}"
        ))
      end

      @budget.spend!
      result = @provider.sample(model: model, prompt: rendered.text)

      @record_sink.record(
        model: model,
        mode: rendered.mode,
        task_name: task_name,
        sample_index: index,
        prompt: rendered.text,
        payload: payload_for(result)
      )

      result
    end

    def payload_for(result)
      result.success? ? result.success.raw : {reason: result.failure.reason, message: result.failure.message}
    end
  end
end
