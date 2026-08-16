require "canary"
require "json"
require "optparse"
require "async"
require "async/http/endpoint"
require "async/http/server"
require "protocol/http/response"

module Canary
  class ToolLoop
    # A minimal fake OpenAI-compatible /v1/chat/completions server for
    # offline ToolLoop tests and the offline-loop/offline-maxturns gates: no
    # real model, just a scripted sequence of canned tool_calls/stop/length
    # responses, so the loop's real machinery - turn counting, tool dispatch
    # against a real bin/canary-server, termination - gets proven without
    # spending on a live model. A Protocol::HTTP::Middleware-shaped handler,
    # the same seam Canary::Server itself is.
    #
    # A conversation's position in its script is read off the request
    # itself - the number of "tool"-role messages already in +messages+ -
    # rather than tracked in shared mutable state: with several
    # Canary::LoopBench conversations in flight against one gateway
    # instance, a global counter would hand one conversation's turn to
    # another's request. Every SCRIPTS entry below already advances one
    # step per tool result, so counting tool messages reproduces the same
    # sequence a single in-flight conversation always got.
    class ScriptedGateway
      # Long enough that several conversations' requests are reliably still
      # in flight together (making concurrent overlap unambiguous in a
      # transcript's started_at/finished_at), short enough not to slow the
      # offline gates down noticeably.
      RESPONSE_DELAY = 0.05
      # A generically-valid Ruby submission (borrowed from the server_fixture
      # fixture task's own passing submission, test/canary/server/socket_test.rb)
      # - reused as the canned run_tests call's argument regardless of which
      # task the loop actually binds it to, since every script here only
      # needs a real prefilter/rollout response shape back, never a pass.
      PASSING_SUBMISSION = <<~RUBY
        module CanaryServerFixture
          class Adder
            def self.call(a, b)
              a + b
            end
          end
        end
      RUBY

      SCRIPTS = {
        "eval-then-tests-then-final" => lambda { |index|
          case index
          when 0 then tool_call_response("ruby_eval", {code: "6 * 7"})
          when 1 then tool_call_response("run_tests", {submission_code: PASSING_SUBMISSION})
          else final_response("6 * 7 is 42, verified by run_tests.")
          end
        },
        "always-tool-call" => ->(_index) { tool_call_response("ruby_eval", {code: "1"}) },
        "truncated-first-turn" => ->(_index) { length_response("cut off mid-") },
        "malformed-arguments" => ->(_index) { tool_call_response("ruby_eval", nil, raw_arguments: "{not json") }
      }.freeze

      attr_reader :received_tool_choices

      def self.tool_call_response(name, arguments, raw_arguments: nil)
        {
          id: "chatcmpl-scripted", object: "chat.completion", created: 0, model: "scripted",
          choices: [{
            index: 0,
            message: {
              role: "assistant", content: nil, refusal: nil,
              tool_calls: [{type: "function", index: 0, id: "call-#{name}", function: {name: name, arguments: raw_arguments || JSON.generate(arguments)}}]
            },
            finish_reason: "tool_calls", logprobs: nil
          }],
          usage: {prompt_tokens: 10, completion_tokens: 10, total_tokens: 20}
        }
      end

      def self.final_response(text)
        {
          id: "chatcmpl-scripted-final", object: "chat.completion", created: 0, model: "scripted",
          choices: [{index: 0, message: {role: "assistant", content: text, refusal: nil, tool_calls: nil}, finish_reason: "stop", logprobs: nil}],
          usage: {prompt_tokens: 10, completion_tokens: 5, total_tokens: 15}
        }
      end

      def self.length_response(text)
        {
          id: "chatcmpl-scripted-length", object: "chat.completion", created: 0, model: "scripted",
          choices: [{index: 0, message: {role: "assistant", content: text, refusal: nil, tool_calls: nil}, finish_reason: "length", logprobs: nil}],
          usage: {prompt_tokens: 10, completion_tokens: 999, total_tokens: 1009}
        }
      end

      def initialize(script:)
        @responses = SCRIPTS.fetch(script)
        @received_tool_choices = []
      end

      def call(request)
        return not_found unless request.method == "POST" && request.path == "/v1/chat/completions"

        body = JSON.parse(request.read, symbolize_names: true)
        @received_tool_choices << body[:tool_choice]
        index = body[:messages].count { |message| message[:role] == "tool" }
        sleep RESPONSE_DELAY
        response = @responses.call(index)

        json_response(200, response)
      end

      def close
      end

      private

      def not_found
        ::Protocol::HTTP::Response[404, {"content-type" => "application/json"}, [JSON.generate(error: "not found")]]
      end

      def json_response(status, payload)
        ::Protocol::HTTP::Response[status, {"content-type" => "application/json"}, [JSON.generate(payload)]]
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {port: nil, script: nil}
  OptionParser.new do |parser|
    parser.on("--port PORT", Integer, "Port to bind") { |v| options[:port] = v }
    parser.on("--script NAME", "Which Canary::ToolLoop::ScriptedGateway::SCRIPTS entry to serve") { |v| options[:script] = v }
  end.parse!(ARGV)

  abort "--port is required" unless options[:port]
  abort "--script is required" unless options[:script]

  endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:#{options[:port]}")
  app = Canary::ToolLoop::ScriptedGateway.new(script: options[:script])

  Sync do
    Async::HTTP::Server.new(app, endpoint).run.wait
  end
end
