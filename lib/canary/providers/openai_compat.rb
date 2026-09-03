require "digest"
require "net/http"
require "openssl"
require "json"
require "dry/monads"
require_relative "sample"
require_relative "error"
require_relative "chat_turn"

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
      DEFAULT_READ_TIMEOUT = 60

      # Sampling is stated on every request rather than left to the server,
      # because "the server default" is not one behaviour. OpenRouter and
      # Anthropic sample at 1.0; mlx-vlm's server decodes greedily
      # (generate/common.py DEFAULT_TEMPERATURE = 0.0), and it reaches that
      # fallback even for a model whose own generation_config.json asks for
      # 1.0, because it reads sampling defaults off config.json instead.
      #
      # Sending nothing therefore made every k>1 sweep against the studio
      # arm a k=1 sweep billed three times: measured 2026-08-27, the
      # committed run-20260815T215441Z has byte-identical completions across
      # all three samples for 44/44 tasks, as did the Flash-Next run that
      # surfaced this. A seed alone would not have helped - greedy decoding
      # has nothing to seed.
      #
      # 1.0 specifically because it is what the hosted arms were already
      # doing implicitly: stating it changes no hosted result and fixes the
      # local ones, which is the only choice here that does not silently
      # re-baseline evidence that is already committed.
      DEFAULT_TEMPERATURE = 1.0

      # A per-instance read timeout, not a fixed constant: most callers are
      # fine with DEFAULT_READ_TIMEOUT's 60s, but a backend that has to load
      # a model into memory before it can answer at all needs an order of
      # magnitude more headroom - a caller with that need should be able to
      # say so without moving the default every other caller inherits.
      def self.default_transport(read_timeout)
        lambda do |uri:, headers:, body:|
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: read_timeout) do |http|
            request = Net::HTTP::Post.new(uri, headers)
            request.body = body
            http.request(request)
          end
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
      def initialize(base_url:, api_key:, max_tokens: DEFAULT_MAX_TOKENS,
                     read_timeout: DEFAULT_READ_TIMEOUT, transport: nil,
                     extra_body_by_model: {}, temperature: DEFAULT_TEMPERATURE)
        @uri = URI("#{base_url}/chat/completions")
        @api_key = api_key
        @max_tokens = max_tokens
        @transport = transport || OpenAICompat.default_transport(read_timeout)
        @extra_body_by_model = extra_body_by_model
        @temperature = temperature
      end

      # +sample_index+ selects the request's seed, so the k samples of one
      # task differ from each other while a re-run of the same sweep asks
      # for the same set again - varying and reproducible, rather than
      # trading one for the other. A backend that ignores seed still samples
      # correctly, since temperature is what does the work.
      #
      # extra_body_by_model merges last and so overrides both: a model whose
      # card asks for its own sampling (Flash-Next wants top_k 20 / top_p
      # 0.95) states that per-model rather than by moving this default.
      # +on_request+, when given, receives the exact body hash that is about
      # to go on the wire. RecordSink uses it so completions.jsonl carries
      # what was actually sent rather than a second reconstruction of it -
      # a reconstruction drifts from the real request the moment either side
      # changes, and a run whose evidence cannot state its own temperature,
      # seed or system prompt cannot be audited or reproduced.
      #
      # The seed still digests the user prompt only. +system+ is constant
      # across every request in a sweep, so folding it in would shift every
      # seed without decorrelating anything, and would silently break
      # re-runs of older sweeps.
      def sample(model:, prompt:, system: nil, max_tokens: @max_tokens, sample_index: 0, on_request: nil)
        messages = []
        messages << {role: "system", content: system} if system
        messages << {role: "user", content: prompt}
        body_hash = {
          model: model, max_tokens: max_tokens, temperature: @temperature,
          seed: self.class.seed_for(prompt, sample_index),
          messages: messages
        }.merge(@extra_body_by_model.fetch(model, {}))
        on_request&.call(body_hash)
        body = JSON.generate(body_hash)
        headers = {"Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json"}
        response = @transport.call(uri: @uri, headers: headers, body: body)

        return Failure(Error.new(reason: :transport_error, message: "HTTP #{response.code}", raw: error_raw(response))) unless success_status?(response)

        handle_body(JSON.parse(response.body, symbolize_names: true), max_tokens)
      rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, IOError, JSON::ParserError => e
        Failure(Error.new(reason: :transport_error, message: "#{e.class}: #{e.message}"))
      end

      # The seed must vary with the prompt, not only with the sample index.
      # A backend seeds its RNG per request, so an index-only seed replays
      # the SAME uniform draw sequence for every task at that index: one
      # high first draw makes every task whose top token is less than
      # certain pick its second-ranked token at once, which correlates the
      # samples instead of making them independent draws.
      #
      # That is not hypothetical. Measured 2026-08-27 with seed ==
      # sample_index, qwen3.8-27b-mxfp8-concurrent1 opened with prose and
      # slid into <tool_call> syntax on 19 of 44 tasks at sample 1, against
      # 0 and 1 at samples 0 and 2 - a property of the seed, not the model,
      # and it cost 15% of that arm's samples to the extractor.
      #
      # Digesting the prompt alongside the index keeps a re-run exactly
      # reproducible while decorrelating the tasks. 8 hex digits because
      # seed fields are commonly 32-bit.
      def self.seed_for(prompt, sample_index)
        Digest::SHA256.hexdigest("#{sample_index}\0#{prompt}")[0, 8].to_i(16)
      end

      # BRIEF §7.2's chat-with-tools seam, kept entirely separate from
      # #sample/#handle_body above (byte-untouched by design - the sweep
      # path's finish_reason: "tool_calls" strictness there is load-bearing,
      # sweep-record-schema.md:60). +messages+ is the full conversation so
      # far, built and owned by the caller (Canary::Prompt stays out of this
      # seam - BRIEF §7.2 is plumbing, not a new render mode);
      # +tools+/+tool_choice+ pass straight through to the request body when
      # given. A Success carries a Canary::Providers::ChatTurn; every
      # failure mode BRIEF §6.3 names (no choices[0].message, an
      # empty/malformed tool_calls array, a missing id/function.name,
      # unparseable JSON arguments) is a typed Failure(Error) here, never an
      # exception - the same field-read discipline #sample already holds.
      def chat(model:, messages:, tools: nil, tool_choice: nil, max_tokens: @max_tokens)
        body_hash = {model: model, max_tokens: max_tokens, messages: messages}
        body_hash[:tools] = tools if tools
        body_hash[:tool_choice] = tool_choice if tool_choice
        body_hash = body_hash.merge(@extra_body_by_model.fetch(model, {}))
        body = JSON.generate(body_hash)
        headers = {"Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json"}
        response = @transport.call(uri: @uri, headers: headers, body: body)

        return Failure(Error.new(reason: :transport_error, message: "HTTP #{response.code}", raw: error_raw(response))) unless success_status?(response)

        handle_chat_body(JSON.parse(response.body, symbolize_names: true))
      rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, IOError, JSON::ParserError => e
        Failure(Error.new(reason: :transport_error, message: "#{e.class}: #{e.message}"))
      end

      private

      def success_status?(response)
        response.code.to_i.between?(200, 299)
      end

      # A non-2xx body carries the provider's own diagnosis of what went
      # wrong (e.g. the Qwen privacy-404 body I19 F4 had to re-buy evidence
      # for after this went uncaptured once already) - preserved as parsed
      # JSON when the body is JSON, or wrapped verbatim when it isn't, same
      # as every other Error#raw on this boundary: never dropped.
      def error_raw(response)
        JSON.parse(response.body, symbolize_names: true)
      rescue JSON::ParserError
        {body: response.body}
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

      # BRIEF §6.3's field-read gate for a chat turn: choices[0].message
      # must exist at all; from there this reads the same finish_reason
      # taxonomy #handle_body does (stop/length/content_filter/other), plus
      # the one branch #handle_body has no use for - "tool_calls", which
      # #sample's own contract treats as an unconditional content Failure
      # (see test_a_tool_calls_finish_reason_is_a_content_failure) and this
      # seam instead validates and carries forward as a Success.
      def handle_chat_body(body)
        choice = body.dig(:choices, 0)
        message = choice && choice[:message]
        finish_reason = choice && choice[:finish_reason]
        raw = normalize_raw(body, finish_reason)

        return Failure(Error.new(reason: :malformed_response, message: "no choices[0].message", raw: raw)) unless message

        case finish_reason
        when "tool_calls"
          handle_tool_calls(message, raw)
        when "stop"
          content = message[:content]
          return content_failure(:empty_completion, "empty completion despite finish_reason=stop", raw, content) if content.nil? || content.empty?

          Success(ChatTurn.new(message: message, tool_calls: [], finish_reason: :stop, raw: raw))
        when "length"
          content_failure(:truncated, "response truncated: finish_reason=length", raw, message[:content])
        when "content_filter"
          content_failure(:refusal, "provider refused: finish_reason=content_filter", raw, message[:content])
        else
          content_failure(:unexpected_finish_reason, "unexpected finish_reason=#{finish_reason.inspect}", raw, message[:content])
        end
      end

      # A non-empty tool_calls array where every entry names a real id, a
      # function name, and JSON-parseable arguments is the only shape that
      # becomes a Success - anything short of that (BRIEF §6.3) is
      # :malformed_tool_call, an honestly-named addition to the reason
      # taxonomy providers/error.rb's own doc comment already sanctions a
      # provider making (see :empty_completion/:unexpected_finish_reason
      # above).
      def handle_tool_calls(message, raw)
        calls = message[:tool_calls]
        return Failure(Error.new(reason: :malformed_tool_call, message: "finish_reason=tool_calls but tool_calls was empty or absent", raw: raw)) if calls.nil? || calls.empty?

        parsed = calls.map { |call| parse_tool_call(call) }
        return Failure(Error.new(reason: :malformed_tool_call, message: "a tool_calls entry was missing id/function.name or had unparseable arguments", raw: raw)) if parsed.any?(&:nil?)

        Success(ChatTurn.new(message: message, tool_calls: parsed, finish_reason: :tool_calls, raw: raw))
      end

      def parse_tool_call(call)
        function = call[:function]
        id = call[:id]
        name = function && function[:name]
        return nil unless id && name

        ChatTurn::ToolCall.new(id: id, name: name, arguments: JSON.parse(function[:arguments], symbolize_names: true))
      rescue JSON::ParserError
        nil
      end
    end
  end
end
