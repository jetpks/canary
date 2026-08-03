require "net/http"
require "json"
require "dry/monads"
require_relative "sample"
require_relative "error"

module Canary
  module Providers
    # A thin adapter over any OpenAI-compatible chat completions endpoint
    # (OpenRouter, Fireworks) - POST {base_url}/chat/completions, bearer
    # auth, and the response's finish_reason carries the same
    # truncation/refusal honesty semantics Providers::Anthropic reads off
    # stop_reason. Net::HTTP rather than a gem: both endpoints speak the
    # same one POST, and Ruby's Fiber scheduler already makes stdlib
    # sockets non-blocking under Async without any extra plumbing here.
    #
    # +finish_reason: "stop"+ with real text is the only Success. "length"
    # and "content_filter" are content outcomes on an otherwise well-formed
    # response - Failures, not exceptions - mirroring Providers::Anthropic's
    # :max_tokens/:refusal handling. Anything else (absent, "tool_calls", an
    # unrecognized string, or empty text despite "stop") is a content
    # Failure too: a Success here must always be a complete, plain-text
    # answer.
    class OpenAICompat
      include Dry::Monads[:result]

      DEFAULT_MAX_TOKENS = 4096
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 60

      DEFAULT_TRANSPORT = lambda do |uri:, headers:, body:|
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          request = Net::HTTP::Post.new(uri, headers)
          request.body = body
          http.request(request)
        end
      end

      def initialize(base_url:, api_key:, max_tokens: DEFAULT_MAX_TOKENS, transport: DEFAULT_TRANSPORT)
        @uri = URI("#{base_url}/chat/completions")
        @api_key = api_key
        @max_tokens = max_tokens
        @transport = transport
      end

      def sample(model:, prompt:, max_tokens: @max_tokens)
        body = JSON.generate(model: model, max_tokens: max_tokens, messages: [{role: "user", content: prompt}])
        headers = {"Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json"}
        response = @transport.call(uri: @uri, headers: headers, body: body)

        return Failure(Error.new(reason: :transport_error, message: "HTTP #{response.code}")) unless success_status?(response)

        handle_body(JSON.parse(response.body, symbolize_names: true), max_tokens)
      rescue => e
        Failure(Error.new(reason: :transport_error, message: "#{e.class}: #{e.message}"))
      end

      private

      def success_status?(response)
        response.code.to_i.between?(200, 299)
      end

      def handle_body(body, max_tokens)
        choice = body.dig(:choices, 0) || {}
        finish_reason = choice[:finish_reason]
        content = choice.dig(:message, :content)
        raw = normalize_raw(body, finish_reason)

        case finish_reason
        when "stop"
          return content_failure(:empty_completion, "empty completion despite finish_reason=stop", raw) if content.nil? || content.empty?

          Success(Sample.new(text: content, raw: raw, stop_reason: :stop))
        when "length"
          content_failure(:truncated, "response truncated: finish_reason=length, max_tokens=#{max_tokens}", raw)
        when "content_filter"
          content_failure(:refusal, "provider refused: finish_reason=content_filter", raw)
        else
          content_failure(:unexpected_finish_reason, "unexpected finish_reason=#{finish_reason.inspect}", raw)
        end
      end

      def content_failure(reason, message, raw)
        Failure(Error.new(reason: reason, message: message, raw: raw))
      end

      # Anthropic's raw response happens to already carry top-level
      # :stop_reason and usage.input_tokens/output_tokens (see
      # Providers::Anthropic) - Canary::Sampler's SpendGuard and
      # Canary::Eval::Runner's non-Sample (Error) reads rely on exactly
      # those key names and are frozen this iteration. Rather than teach
      # that frozen code an OpenAI-compatible shape, the adapter carries
      # both vocabularies: the response body verbatim (so a run stays
      # re-scorable), plus a normalized :stop_reason and enriched :usage
      # so the rest of the pipeline can't tell the difference.
      def normalize_raw(body, finish_reason)
        usage = body[:usage] || {}
        body.merge(
          stop_reason: finish_reason&.to_sym,
          usage: usage.merge(input_tokens: usage[:prompt_tokens], output_tokens: usage[:completion_tokens])
        )
      end
    end
  end
end
