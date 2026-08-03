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
    # surface as a crash. +stop_reason: :max_tokens+ is handled the same
    # way: the response is well-formed HTTP-wise, but the text it carries
    # ends wherever the token budget ran out, mid-word if that's where it
    # landed - a Success here would be indistinguishable from a complete
    # answer to every caller downstream.
    class Anthropic
      include Dry::Monads[:result]

      DEFAULT_MAX_TOKENS = 4096

      def initialize(client: ::Anthropic::Client.new, max_tokens: DEFAULT_MAX_TOKENS)
        @client = client
        @max_tokens = max_tokens
      end

      def sample(model:, prompt:, max_tokens: @max_tokens)
        response = @client.messages.create(
          model: model,
          max_tokens: max_tokens,
          messages: [{role: "user", content: prompt}]
        )

        return content_failure(:refusal, "provider refused: stop_reason=refusal", response) if response.stop_reason == :refusal
        return content_failure(:truncated, "response truncated: stop_reason=max_tokens, max_tokens=#{max_tokens}", response) if response.stop_reason == :max_tokens

        Success(Sample.new(text: extract_text(response), raw: response.deep_to_h))
      rescue ::Anthropic::Errors::APIError => e
        Failure(Error.new(reason: :transport_error, message: "#{e.class}: #{e.message}"))
      end

      private

      # A content outcome came back well-formed, so the response travels on
      # the Failure exactly as it would on a Success. Dropping it here is
      # what once made a truncated answer unrecoverable from the record
      # even though its fenced code block was complete (I14 F1).
      def content_failure(reason, message, response)
        Failure(Error.new(reason: reason, message: message, raw: response.deep_to_h))
      end

      def extract_text(response)
        response.content.select { |block| block.type == :text }.map(&:text).join
      end
    end
  end
end
