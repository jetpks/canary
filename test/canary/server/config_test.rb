require "test_helper"

# bin/canary-server's boot-time configuration resolution, factored out into
# Canary::Server::Config precisely so "refuses to boot without a token" and
# "defaults to the loopback interface" are provable without binding a real
# socket.
class Canary::Server::ConfigTest < Minitest::Test
  def test_it_refuses_to_resolve_without_a_token
    assert_raises(Canary::Server::Config::MissingToken) do
      Canary::Server::Config.resolve(env: {})
    end
  end

  def test_it_refuses_to_resolve_with_a_blank_token
    assert_raises(Canary::Server::Config::MissingToken) do
      Canary::Server::Config.resolve(env: { "CANARY_SERVER_TOKEN" => "" })
    end
  end

  def test_the_default_bind_is_loopback_only
    config = Canary::Server::Config.resolve(env: { "CANARY_SERVER_TOKEN" => "t" })

    assert_equal "127.0.0.1", config.bind
  end

  def test_an_env_bind_override_is_honored
    config = Canary::Server::Config.resolve(env: { "CANARY_SERVER_TOKEN" => "t", "CANARY_SERVER_BIND" => "10.0.0.5" })

    assert_equal "10.0.0.5", config.bind
  end

  def test_a_flag_bind_overrides_the_env
    config = Canary::Server::Config.resolve(
      argv: ["--bind", "10.0.0.9"],
      env: { "CANARY_SERVER_TOKEN" => "t", "CANARY_SERVER_BIND" => "10.0.0.5" }
    )

    assert_equal "10.0.0.9", config.bind
  end

  def test_the_default_port_and_concurrency
    config = Canary::Server::Config.resolve(env: { "CANARY_SERVER_TOKEN" => "t" })

    assert_equal 9292, config.port
    assert_equal Canary::Server::DEFAULT_CONCURRENCY, config.concurrency
  end

  def test_a_port_flag_override
    config = Canary::Server::Config.resolve(argv: ["--port", "1234"], env: { "CANARY_SERVER_TOKEN" => "t" })

    assert_equal 1234, config.port
  end

  def test_the_token_comes_only_from_the_environment
    config = Canary::Server::Config.resolve(env: { "CANARY_SERVER_TOKEN" => "t0k3n" })

    assert_equal "t0k3n", config.token
  end
end
