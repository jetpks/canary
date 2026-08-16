require "test_helper"
require "json"

# Contract tests against Canary::Server's POST /v1/eval route, the same way
# server_test.rb tests POST /v1/rollouts - #call(request) -> response, no
# socket, a real Canary::Pool throughout (no adapter, no grading, no
# prefilter to fake out here, unlike the rollout path's Verifier/TaskRepo).
class ServerEvalTest < Minitest::Test
  # A wrapper, not a mock of the class under test - Server is what is being
  # tested, Pool is what is injected. Delegates to a real Pool throughout,
  # the same way server_test.rb's SpyVerifier wraps a real Verifier, so this
  # proves what timeout Server actually handed the pool without inferring it
  # from a real, slow sleep.
  class SpyPool
    attr_reader :calls

    def initialize(pool: Canary::Pool.new(adapters: []))
      @pool = pool
      @calls = []
    end

    def eval_code(**kwargs)
      @calls << kwargs
      @pool.eval_code(**kwargs)
    end
  end

  def setup
    @server = Canary::Server.new(entries: [])
  end

  def test_an_ok_eval_reports_the_typed_value_and_captured_stdout
    body = post(code: "puts :hello_eval_gate; 6 * 7", request_id: "req-1")

    assert_equal "ok", body["outcome"]
    assert_equal "Integer", body.dig("value", "class")
    assert_equal "42", body.dig("value", "inspect")
    refute body.dig("value", "truncated")
    assert_match(/hello_eval_gate/, body.dig("stdout", "text"))
    refute body.dig("stdout", "truncated")
    assert_equal "", body.dig("stderr", "text")
    refute body.dig("stderr", "truncated")
    assert_nil body["exception"]
    assert_equal "req-1", body["request_id"]
  end

  def test_a_raised_standard_error_reports_the_typed_exception_and_a_null_value
    body = post(code: "raise ArgumentError, 'boom_gate'")

    assert_equal "raised", body["outcome"]
    assert_nil body["value"]
    assert_equal "ArgumentError", body.dig("exception", "class")
    assert_match(/boom_gate/, body.dig("exception", "message"))
  end

  def test_a_timeout_is_honored_and_reported_as_outcome_timeout
    body = post(code: "sleep 30", timeout: 1)

    assert_equal "timeout", body["outcome"]
    assert_nil body["value"]
    assert_equal "", body.dig("stdout", "text")
    refute body.dig("stdout", "truncated")
  end

  def test_a_huge_inspect_is_truncated_on_the_wire
    body = post(code: ":x.to_s * 10_000_000")

    assert_equal "ok", body["outcome"]
    assert body.dig("value", "truncated")
    assert_operator body.dig("value", "inspect").bytesize, :<, 10_000_000
  end

  def test_a_malformed_json_body_is_400
    request = build_request(%({"not valid json))
    response = @server.call(request)

    assert_equal 400, response.status
  end

  def test_a_missing_code_is_400
    request = build_request(JSON.generate({}))
    response = @server.call(request)

    assert_equal 400, response.status
  end

  def test_a_non_string_code_is_400
    request = build_request(JSON.generate(code: 12_345))
    response = @server.call(request)

    assert_equal 400, response.status
  end

  def test_a_negative_timeout_is_400
    request = build_request(JSON.generate(code: "1", timeout: -1))
    response = @server.call(request)

    assert_equal 400, response.status
  end

  def test_the_timeout_is_clamped_to_the_same_max_timeout_as_rollouts
    spy = SpyPool.new
    server = Canary::Server.new(pool: spy, entries: [])

    post(code: "1", timeout: 999, server: server)

    assert_equal Canary::Server::MAX_TIMEOUT, spy.calls.last[:timeout]
  end

  def test_a_timeout_under_the_clamp_passes_through_unchanged
    spy = SpyPool.new
    server = Canary::Server.new(pool: spy, entries: [])

    post(code: "1", timeout: 2, server: server)

    assert_equal 2, spy.calls.last[:timeout]
  end

  def test_the_default_timeout_is_the_pool_default_when_omitted
    spy = SpyPool.new
    server = Canary::Server.new(pool: spy, entries: [])

    post(code: "1", server: server)

    assert_equal Canary::Pool::DEFAULT_TIMEOUT, spy.calls.last[:timeout]
  end

  def test_request_id_is_null_when_omitted
    body = post(code: "1")

    assert_nil body["request_id"]
  end

  def test_an_unknown_path_is_404
    request = ::Protocol::HTTP::Request["POST", "/v1/nope", { "content-type" => "application/json" }, JSON.generate(code: "1")]
    response = @server.call(request)

    assert_equal 404, response.status
  end

  private

  def build_request(body_string)
    ::Protocol::HTTP::Request["POST", "/v1/eval", { "content-type" => "application/json" }, body_string]
  end

  def post(server: @server, **body)
    request = build_request(JSON.generate(body))
    response = server.call(request)

    JSON.parse(response.read)
  end
end
