require "test_helper"
require "json"
require "tmpdir"
require "socket"
require "async"
require "async/http/endpoint"
require "async/http/server"
require_relative "tool_loop/scripted_gateway"

# Real sockets both edges, same pattern as ToolLoopTest: a real
# Canary::Server for the tool edge, Canary::ToolLoop::ScriptedGateway for
# the model edge - proves Canary::LoopBench's actual concurrency (several
# Canary::ToolLoop conversations sharing one gateway, one canary server) and
# its summary.json shape, rather than a stubbed collaborator.
class LoopBenchTest < Minitest::Test
  TOKEN = "loop-bench-test-token"

  def test_concurrent_loops_run_genuinely_concurrently_with_complete_pinned_turn_fields
    with_bound_servers(script: "eval-then-tests-then-final") do |chat_provider, canary_client|
      with_out_dir do |out_dir|
        bench = Canary::LoopBench.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", entries: [entry("struct_vector")], concurrency: 3, out_dir: out_dir, max_turns: 6)

        loops = bench.call

        assert_equal 3, loops.length
        assert loops.all? { |l| l["outcome"] == "final_answer" }

        loops.each do |l|
          refute_empty l["turns"]
          l["turns"].each do |t|
            assert_kind_of String, t["finish_reason"]
            assert_kind_of Integer, t["prompt_tokens"]
            assert_kind_of Integer, t["completion_tokens"]
            assert_kind_of Numeric, t["elapsed_s"]
          end

          transcript_entries = File.readlines(File.join(out_dir, l["transcript"])).map { |line| JSON.parse(line) }
          assert transcript_entries.any? { |e| e["type"] == "tool_result" }
        end

        overlap = loops.combination(2).any? { |a, b| a["started_at"] < b["finished_at"] && b["started_at"] < a["finished_at"] }
        assert overlap, "expected at least two loops to run concurrently, got #{loops.map { |l| [l["started_at"], l["finished_at"]] }}"

        assert_equal({"loops" => loops}, JSON.parse(File.read(File.join(out_dir, "summary.json"))))
      end
    end
  end

  def test_round_robin_task_assignment_cycles_when_fewer_tasks_than_loops
    with_bound_servers(script: "always-tool-call") do |chat_provider, canary_client|
      with_out_dir do |out_dir|
        bench = Canary::LoopBench.new(chat_provider: chat_provider, canary_client: canary_client, model: "scripted", entries: [entry("struct_vector"), entry("comparable_money")], concurrency: 4, out_dir: out_dir, max_turns: 1)

        loops = bench.call

        assert_equal %w[struct_vector comparable_money struct_vector comparable_money], loops.map { |l| l["task"] }
      end
    end
  end

  def test_a_transport_error_turn_row_still_carries_typed_pinned_fields_not_nils
    dead_chat_provider = Canary::Providers::OpenAICompat.new(base_url: "http://127.0.0.1:#{closed_port}", api_key: "unused", read_timeout: 2)
    dead_canary_client = Canary::ToolLoop::CanaryClient.new(base_url: "http://127.0.0.1:#{closed_port}", token: "unused")

    with_out_dir do |out_dir|
      bench = Canary::LoopBench.new(chat_provider: dead_chat_provider, canary_client: dead_canary_client, model: "scripted", entries: [entry("struct_vector")], concurrency: 1, out_dir: out_dir)

      loops = bench.call

      assert_equal ["loop_error"], loops.map { |l| l["outcome"] }
      turn = loops.first.fetch("turns").first
      assert_equal "transport_error", turn["finish_reason"]
      assert_equal 0, turn["prompt_tokens"]
      assert_equal 0, turn["completion_tokens"]
    end
  end

  private

  def entry(name)
    Canary::TaskRepo.all.find { |candidate| candidate.name == name }
  end

  def with_out_dir
    Dir.mktmpdir { |dir| yield dir }
  end

  def closed_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def with_bound_servers(script:)
    canary_app = Canary::Server::Auth.new(Canary::Server.new, token: TOKEN)
    gateway = Canary::ToolLoop::ScriptedGateway.new(script: script)

    canary_endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:0")
    canary_bound = canary_endpoint.bound
    gateway_endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:0")
    gateway_bound = gateway_endpoint.bound

    begin
      canary_server = Async::HTTP::Server.new(canary_app, canary_bound, protocol: canary_endpoint.protocol, scheme: canary_endpoint.scheme)
      gateway_server = Async::HTTP::Server.new(gateway, gateway_bound, protocol: gateway_endpoint.protocol, scheme: gateway_endpoint.scheme)

      Sync do |task|
        task.with_timeout(30) do
          canary_task = canary_server.run
          gateway_task = gateway_server.run
          canary_port = canary_bound.sockets.first.local_address.ip_port
          gateway_port = gateway_bound.sockets.first.local_address.ip_port

          chat_provider = Canary::Providers::OpenAICompat.new(base_url: "http://127.0.0.1:#{gateway_port}/v1", api_key: "fixture-key")
          canary_client = Canary::ToolLoop::CanaryClient.new(base_url: "http://127.0.0.1:#{canary_port}", token: TOKEN)

          begin
            yield chat_provider, canary_client
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
