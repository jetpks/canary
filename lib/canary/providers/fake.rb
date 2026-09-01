require "dry/monads"
require_relative "sample"

module Canary
  module Providers
    # A test double for the provider boundary. Records every call it
    # receives - so a caller can prove the provider was, or was not,
    # invoked (see Canary::Sampler's budget guard test) - and answers with
    # whatever the caller configured via the constructor block, defaulting
    # to a canned Success.
    class Fake
      include Dry::Monads[:result]

      attr_reader :calls

      def initialize(&responder)
        @calls = []
        @responder = responder || ->(model:, prompt:) { Success(Sample.new(text: "fake response", raw: {model: model, prompt: prompt}, stop_reason: :end_turn)) }
      end

      def sample(model:, prompt:, system: nil, sample_index: nil, on_request: nil)
        @calls << {model: model, prompt: prompt, system: system, sample_index: sample_index}
        on_request&.call({model: model, prompt: prompt, system: system})
        @responder.call(model: model, prompt: prompt)
      end
    end
  end
end
