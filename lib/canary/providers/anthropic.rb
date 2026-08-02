require "anthropic"
require "dry/monads"
require_relative "sample"
require_relative "error"

module Canary
  module Providers
    # The one live implementation of the provider boundary this iteration:
    # wraps the installed +anthropic+ gem's Anthropic::Client. Every call
    # either returns Success(a Canary::Providers::Sample) or
    # Failure(a Canary::Providers::Error) - it never raises into the
    # caller, mirroring Canary::Pool's "always returns a result" idiom for
    # this new boundary.
    #
    # +stop_reason: :refusal+ is a content outcome on an otherwise
    # successful HTTP response (see Anthropic::Models::StopReason), not an
    # exception - it is handled as a Failure here rather than left to
    # surface as a crash.
    class Anthropic
      include Dry::Monads[:result]

      DEFAULT_MAX_TOKENS = 1024

      def initialize(client: ::Anthropic::Client.new, max_tokens: DEFAULT_MAX_TOKENS)
        @client = client
        @max_tokens = max_tokens
      end

      def sample(model:, prompt:)
        response = @client.messages.create(
          model: model,
          max_tokens: @max_tokens,
          messages: [{role: "user", content: prompt}]
        )

        return Failure(Error.new(reason: :refusal, message: "provider refused: stop_reason=refusal")) if response.stop_reason == :refusal

        Success(Sample.new(text: extract_text(response), raw: response.deep_to_h))
      rescue ::Anthropic::Errors::APIError => e
        Failure(Error.new(reason: :transport_error, message: "#{e.class}: #{e.message}"))
      end

      private

      def extract_text(response)
        response.content.select { |block| block.type == :text }.map(&:text).join
      end
    end
  end
end
