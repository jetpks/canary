require "test_helper"
require "json"
require "tmpdir"
require "async"
require "async/http/endpoint"
require "async/http/server"
require_relative "tool_loop/scripted_gateway"

# Real sockets both edges (socket_test.rb's own port-0 pattern, applied
# twice): a real Canary::Server for the tool edge, and
# Canary::ToolLoop::ScriptedGateway for the model edge - proves
# Canary::ToolLoop's actual machinery (turn counting, tool dispatch against
# the real wire, termination) rather than a stubbed collaborator.
class ToolLoopTest < Minitest::Test
  FIXTURES_ROOT = File.expand_path("server/fixtures/tasks", __dir__)
  TOKEN = "tool-loop-test-token"

  def test_offline_loop_reaches_final_answer_and_records_typed_tool_results
    with_servers(script: "eval-then-tests-then-final") do |chat_provider, canary_client, entry|
      with_transcript do |path|
        loop_runner = Canary::ToolLoop.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", transcript_path: path, max_turns: 6)

        outcome = loop_runner.call(entry)

        assert_equal :final_answer, outcome
        entries = read_transcript(path)
        assert entries.all? { |e| e.key?("type") }

        eval_result = entries.find { |e| e["type"] == "tool_result" && e["tool"] == "ruby_eval" }
        assert_equal "42", eval_result.dig("response", "value", "inspect")

        rollout_result = entries.find { |e| e["type"] == "tool_result" && e["tool"] == "run_tests" }
        assert_kind_of Hash, rollout_result.dig("response", "prefilter")
      end
    end
  end

  def test_max_turns_cap_ends_the_loop_as_a_typed_outcome
    with_servers(script: "always-tool-call") do |chat_provider, canary_client, entry|
      with_transcript do |path|
        loop_runner = Canary::ToolLoop.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", transcript_path: path, max_turns: 3)

        outcome = loop_runner.call(entry)

        assert_equal :max_turns, outcome
        entries = read_transcript(path)
        assert_equal 3, entries.count { |e| e["type"] == "model_turn" }
      end
    end
  end

  def test_tool_choice_required_applies_only_to_the_first_turn
    gateway = Canary::ToolLoop::ScriptedGateway.new(script: "always-tool-call")
    with_bound_servers(gateway: gateway) do |chat_provider, canary_client, entry|
      with_transcript do |path|
        loop_runner = Canary::ToolLoop.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", transcript_path: path, max_turns: 2, tool_choice: "required")

        loop_runner.call(entry)

        assert_equal ["required", "auto"], gateway.received_tool_choices
      end
    end
  end

  def test_a_provider_truncation_ends_the_loop_as_a_typed_truncated_outcome
    with_servers(script: "truncated-first-turn") do |chat_provider, canary_client, entry|
      with_transcript do |path|
        loop_runner = Canary::ToolLoop.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", transcript_path: path)

        outcome = loop_runner.call(entry)

        assert_equal :truncated, outcome
      end
    end
  end

  def test_a_malformed_tool_call_ends_the_loop_as_a_typed_loop_error_rather_than_a_silent_success
    with_servers(script: "malformed-arguments") do |chat_provider, canary_client, entry|
      with_transcript do |path|
        loop_runner = Canary::ToolLoop.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", transcript_path: path)

        outcome = loop_runner.call(entry)

        assert_equal :loop_error, outcome
      end
    end
  end

  def test_run_tests_never_receives_a_model_supplied_task_name
    with_servers(script: "eval-then-tests-then-final") do |chat_provider, canary_client, entry|
      with_transcript do |path|
        loop_runner = Canary::ToolLoop.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", transcript_path: path, max_turns: 6)

        loop_runner.call(entry)

        rollout_result = read_transcript(path).find { |e| e["type"] == "tool_result" && e["tool"] == "run_tests" }
        refute rollout_result["arguments"].key?("task_name")
      end
    end
  end

  private

  def with_transcript
    Dir.mktmpdir do |dir|
      yield File.join(dir, "transcript.jsonl")
    end
  end

  def read_transcript(path)
    File.readlines(path).map { |line| JSON.parse(line) }
  end

  def with_servers(script:)
    with_bound_servers(gateway: Canary::ToolLoop::ScriptedGateway.new(script: script)) { |*args| yield(*args) }
  end

  def with_bound_servers(gateway:)
    entries = Canary::TaskRepo.all(root: FIXTURES_ROOT)
    entry = entries.find { |candidate| candidate.name == "server_fixture" }
    canary_app = Canary::Server::Auth.new(Canary::Server.new(entries: entries), token: TOKEN)

    canary_endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:0")
    canary_bound = canary_endpoint.bound
    gateway_endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:0")
    gateway_bound = gateway_endpoint.bound

    begin
      canary_server = Async::HTTP::Server.new(canary_app, canary_bound, protocol: canary_endpoint.protocol, scheme: canary_endpoint.scheme)
      gateway_server = Async::HTTP::Server.new(gateway, gateway_bound, protocol: gateway_endpoint.protocol, scheme: gateway_endpoint.scheme)

      Sync do |task|
        task.with_timeout(20) do
          canary_task = canary_server.run
          gateway_task = gateway_server.run
          canary_port = canary_bound.sockets.first.local_address.ip_port
          gateway_port = gateway_bound.sockets.first.local_address.ip_port

          chat_provider = Canary::Providers::OpenAICompat.new(base_url: "http://127.0.0.1:#{gateway_port}/v1", api_key: "fixture-key")
          canary_client = Canary::ToolLoop::CanaryClient.new(base_url: "http://127.0.0.1:#{canary_port}", token: TOKEN)

          begin
            yield chat_provider, canary_client, entry
          ensure
            canary_task.stop
            gateway_task.stop
          end
        end
      end
    ensure
      canary_bound.close
      gateway_bound.close
    end
  end
end
