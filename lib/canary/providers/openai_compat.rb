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

      # +extra_body_by_model+ merges provider- and model-specific request
      # fields (e.g. OpenRouter's "reasoning": {"effort" => "low"}, or
      # Fireworks' "reasoning_effort" => "low") into the POST body for
      # whichever model is being sampled - a lookup by model id rather than
      # a single fixed hash, since one provider instance here serves every
      # model routed through its endpoint (bin/eval_sweep.rb), and a
      # reasoning-heavy model needs a different setting than one that
      # doesn't reason at all. Absent from the hash for a given model is a
      # no-op merge, not an error - most models need nothing extra.
      def initialize(base_url:, api_key:, max_tokens: DEFAULT_MAX_TOKENS, transport: DEFAULT_TRANSPORT, extra_body_by_model: {})
        @uri = URI("#{base_url}/chat/completions")
        @api_key = api_key
        @max_tokens = max_tokens
        @transport = transport
        @extra_body_by_model = extra_body_by_model
      end

      def sample(model:, prompt:, max_tokens: @max_tokens)
        body_hash = {model: model, max_tokens: max_tokens, messages: [{role: "user", content: prompt}]}.merge(@extra_body_by_model.fetch(model, {}))
        body = JSON.generate(body_hash)
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
          return content_failure(:empty_completion, "empty completion despite finish_reason=stop", raw, content) if content.nil? || content.empty?

          Success(Sample.new(text: content, raw: raw, stop_reason: :stop))
        when "length"
          content_failure(:truncated, "response truncated: finish_reason=length, max_tokens=#{max_tokens}", raw, content)
        when "content_filter"
          content_failure(:refusal, "provider refused: finish_reason=content_filter", raw, content)
        else
          content_failure(:unexpected_finish_reason, "unexpected finish_reason=#{finish_reason.inspect}", raw, content)
        end
      end

      # +content+ travels through as Error#text, nil-normalized the same
      # way visible_text does below - empty_completion's call site always
      # has a nil/empty content by construction, so no special-casing is
      # needed there.
      def content_failure(reason, message, raw, content = nil)
        Failure(Error.new(reason: reason, message: message, raw: raw, text: visible_text(content)))
      end

      def visible_text(content)
        content unless content.nil? || content.empty?
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
