require "test_helper"

# Canary::Server::Auth is the delegate's only guard: no token, wrong token,
# and correct token, proven against a spy delegate rather than a real
# Canary::Server so a passing case can also prove the request body was
# never touched before the delegate saw it.
class Canary::Server::AuthTest < Minitest::Test
  class SpyDelegate
    attr_reader :calls

    def initialize
      @calls = []
    end

    def call(request)
      @calls << request
      ::Protocol::HTTP::Response[200, {}, ["ok"]]
    end

    def close
    end
  end

  # A body that raises if anything ever reads it - proves a rejected
  # request's body is never touched, the same spy-not-mock idiom
  # VerifierTest's ExplodingPool already uses for the analogous "tier 2
  # must not run" guarantee.
  class ExplodingBody
    def each
      raise "the request body must not be read for a request auth rejects"
    end

    def read
      raise "the request body must not be read for a request auth rejects"
    end
  end

  def setup
    @delegate = SpyDelegate.new
    @app = Canary::Server::Auth.new(@delegate, token: "s3cret")
  end

  def test_a_missing_token_is_401
    response = @app.call(request(headers: {}))

    assert_equal 401, response.status
    assert_empty @delegate.calls
  end

  def test_a_wrong_token_is_401
    response = @app.call(request(headers: { "authorization" => "Bearer nope" }))

    assert_equal 401, response.status
    assert_empty @delegate.calls
  end

  def test_a_correct_token_reaches_the_delegate
    response = @app.call(request(headers: { "authorization" => "Bearer s3cret" }))

    assert_equal 200, response.status
    assert_equal 1, @delegate.calls.size
  end

  def test_a_rejected_request_body_is_never_read
    response = @app.call(request(headers: { "authorization" => "Bearer nope" }, body: ExplodingBody.new))

    assert_equal 401, response.status
  end

  private

  def request(headers:, body: nil)
    ::Protocol::HTTP::Request.new(nil, nil, "POST", "/v1/rollouts", nil, ::Protocol::HTTP::Headers[headers], body)
  end
end
