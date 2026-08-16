require "net/http"
require "json"
require_relative "prompt"
require_relative "providers/openai_compat"

module Canary
  # The tool loop (BRIEF §7.2): drives a chat model through
  # Providers::OpenAICompat#chat with canary's two verbs bound as OpenAI
  # tools, executes every tool call the model issues against the real
  # bin/canary-server over loopback HTTP (never Pool/Verifier in-process),
  # and relays the wire's typed JSON response back to the model verbatim -
  # no re-serialization, no summarizing (BRIEF §7.3). A sibling of
  # Eval::Runner, not a subclass: its own inner loop, its own transcript.
  #
  # Fibers, not threads (BRIEF §2) - #call makes one HTTP round trip at a
  # time, sequentially, the same way Providers::OpenAICompat's own comment
  # notes net/http already cooperates with Ruby's Fiber scheduler under
  # Async with no extra plumbing.
  class ToolLoop
    DEFAULT_MAX_TURNS = 6

    # The two verbs Canary::Server exposes (docs/reference/wire-protocol.md),
    # as OpenAI tool definitions. run_tests deliberately has no task_name
    # property - it is bound by the loop from the TaskRepo::Entry #call is
    # given, never model-supplied (BRIEF §7.2 settled decision 3).
    TOOLS = [
      {
        type: "function",
        function: {
          name: "ruby_eval",
          description: "Evaluate a string of Ruby code and return the result: outcome, value (class, inspect, truncated), stdout (text, truncated), stderr (text, truncated), exception. No grading - just runs the code and reports what happened.",
          parameters: {
            type: "object",
            properties: {
              code: {type: "string", description: "Ruby source to evaluate"},
              timeout: {type: "number", description: "optional timeout in seconds"}
            },
            required: ["code"]
          }
        }
      },
      {
        type: "function",
        function: {
          name: "run_tests",
          description: "Submit a Ruby solution for this task and grade it against the task's own test suite. Returns outcome, passed, prefilter, and rollout details.",
          parameters: {
            type: "object",
            properties: {
              submission_code: {type: "string", description: "the Ruby solution to grade"}
            },
            required: ["submission_code"]
          }
        }
      }
    ].freeze

    TOOL_PREAMBLE = <<~TEXT.freeze

      You have two tools available:
      - ruby_eval(code, timeout?): evaluate a string of Ruby and observe what happens - no grading, just execution.
      - run_tests(submission_code): submit your solution and grade it against this task's own test suite.

      Use ruby_eval to explore before submitting, if that helps. When you are ready to give your final answer, reply with plain text and no further tool calls.
    TEXT

    # One JSONL entry per model request/response.
    ModelTurnEntry = Data.define(:type, :turn, :request, :response, :elapsed_s) do
      def initialize(turn:, request:, response:, elapsed_s:)
        super(type: "model_turn", turn: turn, request: request, response: response, elapsed_s: elapsed_s)
      end
    end

    # One JSONL entry per tool execution - +response+ is the canary wire
    # body verbatim (the pinned wire-format contract every gate asserts on).
    ToolResultEntry = Data.define(:type, :turn, :tool, :arguments, :response, :elapsed_s) do
      def initialize(turn:, tool:, arguments:, response:, elapsed_s:)
        super(type: "tool_result", turn: turn, tool: tool, arguments: arguments, response: response, elapsed_s: elapsed_s)
      end
    end

    # HTTP client for the tool edge - the real bin/canary-server, never
    # Pool/Verifier in-process (BRIEF §7.3). Hands back the parsed response
    # body exactly as the wire sent it; nothing here reshapes it. The same
    # transport: lambda seam Providers::OpenAICompat uses, so a caller can
    # inject a fake transport in a unit test without a real socket.
    class CanaryClient
      OPEN_TIMEOUT = 10
      # Comfortably above Canary::Server::MAX_TIMEOUT's own 20s eval/rollout
      # cap (4x Pool::DEFAULT_TIMEOUT) - a request can never legitimately
      # take longer than the server itself is willing to run it for.
      READ_TIMEOUT = 30

      TransportError = Class.new(StandardError)

      def self.default_transport
        lambda do |uri:, headers:, body:|
          Net::HTTP.start(uri.host, uri.port, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
            request = Net::HTTP::Post.new(uri, headers)
            request.body = body
            http.request(request)
          end
        end
      end

      def initialize(base_url:, token:, transport: nil)
        @base_url = base_url
        @token = token
        @transport = transport || CanaryClient.default_transport
      end

      def eval(code:, timeout: nil)
        post("/v1/eval", {code: code, timeout: timeout}.compact)
      end

      def run_tests(task_name:, submission_code:)
        post("/v1/rollouts", {task_name: task_name, submission_code: submission_code})
      end

      private

      def post(path, body_hash)
        uri = URI("#{@base_url}#{path}")
        headers = {"Authorization" => "Bearer #{@token}", "Content-Type" => "application/json"}
        response = @transport.call(uri: uri, headers: headers, body: JSON.generate(body_hash))
        JSON.parse(response.body, symbolize_names: true)
      rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout, IOError, JSON::ParserError => e
        raise TransportError, "#{e.class}: #{e.message}"
      end
    end

    def initialize(chat_provider:, canary_client:, model:, transcript_path:, max_turns: DEFAULT_MAX_TURNS, tool_choice: "auto", max_tokens: Providers::OpenAICompat::DEFAULT_MAX_TOKENS)
      @chat_provider = chat_provider
      @canary_client = canary_client
      @model = model
      @transcript_path = transcript_path
      @max_turns = max_turns
      @first_tool_choice = tool_choice
      @max_tokens = max_tokens
    end

    # Runs the loop for +entry+ (a Canary::TaskRepo::Entry): renders its
    # statement into the model-facing prompt (Canary::Prompt.render, hidden
    # mode) plus this loop's own tool preamble, then lets the model call
    # tools - bound to entry.name - until it answers, is cut off, or the
    # turn cap is reached. Returns a typed outcome: :final_answer,
    # :max_turns, :truncated, or :loop_error - never raises for a wire
    # violation (BRIEF §6.3).
    def call(entry)
      messages = [{role: "user", content: "#{Prompt.render(entry, grader: false).text}#{TOOL_PREAMBLE}"}]

      (1..@max_turns).each do |turn|
        tool_choice = turn == 1 ? @first_tool_choice : "auto"
        result = request_turn(turn, messages, tool_choice)

        return :truncated if result.failure? && result.failure.reason == :truncated
        return :loop_error if result.failure?

        chat_turn = result.success
        return :final_answer if chat_turn.tool_calls.empty?

        messages << replay_message(chat_turn.message)

        begin
          chat_turn.tool_calls.each { |tool_call| messages << execute_tool(entry.name, turn, tool_call) }
        rescue CanaryClient::TransportError
          return :loop_error
        end
      end

      :max_turns
    end

    private

    def request_turn(turn, messages, tool_choice)
      started = elapsed_start
      result = @chat_provider.chat(model: @model, messages: messages, tools: TOOLS, tool_choice: tool_choice, max_tokens: @max_tokens)
      record(ModelTurnEntry.new(turn: turn, request: request_payload(messages, tool_choice), response: turn_payload(result), elapsed_s: elapsed_since(started)))
      result
    end

    def request_payload(messages, tool_choice)
      {model: @model, messages: messages, tools: TOOLS.map { |tool| tool[:function][:name] }, tool_choice: tool_choice, max_tokens: @max_tokens}
    end

    def turn_payload(result)
      return result.success.raw if result.success?

      {reason: result.failure.reason, message: result.failure.message, raw: result.failure.raw}
    end

    # The verified-working replay shape (edge-probe.json leg2): role,
    # content, and the tool_calls array verbatim - not the fuller message
    # the wire sent back (which also carries refusal/reasoning_content).
    def replay_message(message)
      {role: "assistant", content: message[:content], tool_calls: message[:tool_calls]}
    end

    def execute_tool(task_name, turn, tool_call)
      started = elapsed_start
      response = dispatch_tool(task_name, tool_call)
      record(ToolResultEntry.new(turn: turn, tool: tool_call.name, arguments: tool_call.arguments, response: response, elapsed_s: elapsed_since(started)))

      {role: "tool", tool_call_id: tool_call.id, content: JSON.generate(response)}
    end

    # A tool name the schema didn't offer, or arguments missing a required
    # key, still reaches here honestly rather than being pre-validated away:
    # bin/canary-server's own 400 body ({"error": "..."}) is itself valid
    # typed JSON the model can read and correct from, so it is handed back
    # like any other tool response rather than treated as a loop failure.
    def dispatch_tool(task_name, tool_call)
      case tool_call.name
      when "ruby_eval"
        @canary_client.eval(code: tool_call.arguments[:code], timeout: tool_call.arguments[:timeout])
      when "run_tests"
        @canary_client.run_tests(task_name: task_name, submission_code: tool_call.arguments[:submission_code])
      else
        {error: "no such tool: #{tool_call.name.inspect}"}
      end
    end

    def record(entry)
      File.open(@transcript_path, "a") { |f| f.puts(JSON.generate(entry.to_h)) }
    end

    def elapsed_start
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def elapsed_since(started)
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)
    end
  end
end
