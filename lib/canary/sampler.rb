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

    # Accumulates real dollar spend from each dispatched response's +usage+
    # and blocks further calls once the running total exceeds a cap. This
    # is deliberately the other shape from Budget: a call's cost is only
    # knowable *after* the provider answers, so the guard checked before
    # dispatch always reflects prior calls' recorded spend, never the
    # pending call's - the call that pushes spend over the cap always
    # completes; only the ones after it are blocked. +price_table+ is
    # caller-supplied ($/token per model) rather than baked in here, since a
    # price table shipped in the repo goes stale.
    class SpendGuard
      def initialize(max_dollars:, price_table:)
        @max_dollars = max_dollars
        @price_table = price_table
        @spent = 0.0
      end

      def exceeded?
        @spent > @max_dollars
      end

      def record!(model:, usage:)
        rate = @price_table.fetch(model)
        @spent += (usage[:input_tokens] * rate[:input_token_price]) + (usage[:output_tokens] * rate[:output_token_price])
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

    def initialize(provider:, budget:, record_sink:, spend_guard: nil)
      @provider = provider
      @budget = budget
      @record_sink = record_sink
      @spend_guard = spend_guard
    end

    # Renders +entry+ once (hidden by default, grader-visible when
    # +grader+ is true) and asks the provider for +n+ completions,
    # returning one Dry::Monads::Result per completion in order. Each
    # completion's recorded sample_index is +base_index+ plus its position
    # in this call, so a caller issuing several n: 1 calls for the same
    # (task, model) can keep indices contiguous by passing successive
    # +base_index+ values instead of every call recording 0.
    def call(entry, model:, n: 1, base_index: 0, grader: false)
      rendered = Prompt.render(entry, grader: grader)

      Array.new(n) { |index| sample_one(entry.name, rendered, model, base_index + index) }
    end

    private

    def sample_one(task_name, rendered, model, index)
      if @budget.exhausted?
        return Failure(Providers::Error.new(
          reason: :budget_exhausted,
          message: "budget exhausted before sample #{index} of #{task_name.inspect}"
        ))
      end

      if @spend_guard&.exceeded?
        return Failure(Providers::Error.new(
          reason: :spend_exceeded,
          message: "spend guard exceeded before sample #{index} of #{task_name.inspect}"
        ))
      end

      @budget.spend!
      result = @provider.sample(model: model, prompt: rendered.text)
      record_spend!(model, result)

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

    def record_spend!(model, result)
      return unless @spend_guard && result.success?

      @spend_guard.record!(model: model, usage: result.success.raw[:usage])
    end

    # A failed sample records its reason AND whatever came back with it:
    # the content outcomes (:refusal, :truncated) carry a full response,
    # and a record that kept only the reason code would throw away the one
    # copy of a truncated answer's text (I14 F1). +raw+ is nil for the
    # failures that genuinely have no response.
    def payload_for(result)
      return result.success.raw if result.success?

      {reason: result.failure.reason, message: result.failure.message, raw: result.failure.raw}
    end
  end
end
