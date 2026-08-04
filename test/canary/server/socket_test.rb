require "test_helper"
require "json"
require "async"
require "async/http/endpoint"
require "async/http/server"
require "async/http/client"

# The small number of real-socket tests: Canary::Server::Auth composed
# ahead of a real Canary::Server, served by a real Async::HTTP::Server
# bound to 127.0.0.1:0 (never a fixed port), one real client round trip,
# explicit timeout, torn down.
class Canary::Server::SocketTest < Minitest::Test
  FIXTURES_ROOT = File.expand_path("fixtures/tasks", __dir__)
  TOKEN = "sekrit"

  PASSING_SUBMISSION = <<~RUBY
    module CanaryServerFixture
      class Adder
        def self.call(a, b)
          a + b
        end
      end
    end
  RUBY

  def test_a_real_round_trip_over_a_bound_loopback_socket
    entries = Canary::TaskRepo.all(root: FIXTURES_ROOT)
    app = Canary::Server::Auth.new(Canary::Server.new(entries: entries), token: TOKEN)

    endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:0")
    bound = endpoint.bound

    begin
      server = Async::HTTP::Server.new(app, bound, protocol: endpoint.protocol, scheme: endpoint.scheme)

      Sync do |task|
        task.with_timeout(10) do
          server_task = server.run
          port = bound.sockets.first.local_address.ip_port
          client = Async::HTTP::Client.new(Async::HTTP::Endpoint.parse("http://127.0.0.1:#{port}"))

          begin
            response = client.post(
              "/v1/rollouts",
              { "authorization" => "Bearer #{TOKEN}", "content-type" => "application/json" },
              [JSON.generate(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, request_id: "sock-1")]
            )

            assert_equal 200, response.status
            body = JSON.parse(response.read)
            assert_equal "ok", body["outcome"]
            assert body["passed"]
            assert_equal "sock-1", body["request_id"]
          ensure
            response&.close
            client.close
            server_task.stop
          end
        end
      end
    ensure
      bound.close
    end
  end

  def test_a_real_request_without_the_bearer_token_is_401_over_the_socket
    entries = Canary::TaskRepo.all(root: FIXTURES_ROOT)
    app = Canary::Server::Auth.new(Canary::Server.new(entries: entries), token: TOKEN)

    endpoint = Async::HTTP::Endpoint.parse("http://127.0.0.1:0")
    bound = endpoint.bound

    begin
      server = Async::HTTP::Server.new(app, bound, protocol: endpoint.protocol, scheme: endpoint.scheme)

      Sync do |task|
        task.with_timeout(10) do
          server_task = server.run
          port = bound.sockets.first.local_address.ip_port
          client = Async::HTTP::Client.new(Async::HTTP::Endpoint.parse("http://127.0.0.1:#{port}"))

          begin
            response = client.post(
              "/v1/rollouts",
              { "content-type" => "application/json" },
              [JSON.generate(task_name: "server_fixture", submission_code: PASSING_SUBMISSION)]
            )

            assert_equal 401, response.status
          ensure
            response&.close
            client.close
            server_task.stop
          end
        end
      end
    ensure
      bound.close
    end
  end
end
