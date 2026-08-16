require "test_helper"
require "json"

# Contract tests against Canary::Server as a plain
# Protocol::HTTP::Middleware-shaped handler - #call(request) -> response,
# no socket, real Canary::Verifier throughout. The small number of
# real-socket tests (auth composed in front, a genuine round trip) live
# under server/socket_test.rb instead.
class ServerTest < Minitest::Test
  FIXTURES = Canary::TaskRepo.all(root: File.expand_path("server/fixtures/tasks", __dir__))

  PASSING_SUBMISSION = <<~RUBY
    module CanaryServerFixture
      class Adder
        def self.call(a, b)
          a + b
        end
      end
    end
  RUBY

  FAILING_SUBMISSION = <<~RUBY
    module CanaryServerFixture
      class Adder
        def self.call(a, b)
          a - b
        end
      end
    end
  RUBY

  ERROR_SUBMISSION = <<~RUBY
    raise "boom from submission"
  RUBY

  CRASH_SUBMISSION = <<~RUBY
    exit!
  RUBY

  SYNTAX_INVALID_SUBMISSION = "def foo(1, 2)\nend\n"

  # A wrapper, not a mock of the class under test - Canary::Server is what
  # is being tested, Canary::Verifier is what is injected. Delegates to a
  # real Verifier throughout, so this proves both "never reached" (count
  # stays 0) and "reached with what" (captures the kwargs) without
  # inferring either from the response shape alone.
  class SpyVerifier
    attr_reader :calls

    def initialize(verifier: Canary::Verifier.new)
      @verifier = verifier
      @calls = []
    end

    def call(task, **kwargs)
      @calls << kwargs
      @verifier.call(task, **kwargs)
    end
  end

  # Injects a fixed Verifier::Result directly - AC6's ":invalid" crossing
  # only holds by construction via the real Pool otherwise, which requires
  # actual grader tampering to exercise; this drives it directly instead.
  class StubVerifier
    def initialize(result)
      @result = result
    end

    def call(*, **)
      @result
    end
  end

  # Captures the real solution_path Server handed it, then embeds that path
  # in the free-text fields (rollout.error, an example's message) AC7 says
  # must never cross - a direct test of Server's own sanitization, not the
  # solution_path a real Pool run happens to produce.
  class PathLeakVerifier
    attr_reader :captured_path

    def call(task, **)
      @captured_path = task.solution_path
      prefilter_report = Canary::Prefilter::Report.new(syntax_valid: true, truncated: false, findings: [])
      rollout_result = Canary::RolloutResult.new(
        adapter: :minitest,
        examples: [Canary::ExampleResult.new(name: "ex", status: "failed", message: "boom near #{task.solution_path}")],
        passed: 0, failed: 1, total: 1,
        error: "reading #{task.solution_path} failed", outcome: :error
      )
      Canary::Verifier::Result.new(prefilter_report: prefilter_report, rollout_result: rollout_result, passed: false)
    end
  end

  class RaisingVerifier
    def initialize(error)
      @error = error
    end

    def call(*, **)
      raise @error
    end
  end

  def setup
    @spy = SpyVerifier.new
    @server = Canary::Server.new(verifier: @spy, entries: FIXTURES)
  end

  def test_a_passing_rollout_reports_the_full_field_table
    body = post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, request_id: "req-1")

    assert_equal "ok", body["outcome"]
    assert body["passed"]
    assert body["prefilter"]["clean"]
    assert body["prefilter"]["syntax_valid"]
    refute body["prefilter"]["truncated"]
    assert_equal [], body["prefilter"]["findings"]
    assert_equal "ok", body["rollout"]["outcome"]
    assert_equal 1, body["rollout"]["passed"]
    assert_equal 0, body["rollout"]["failed"]
    assert_equal 1, body["rollout"]["total"]
    assert_nil body["rollout"]["error"]
    assert_equal 1, body["rollout"]["examples"].size
    example = body["rollout"]["examples"].first
    assert_equal "CanaryServerFixtureAdderTest#test_adds_two_numbers", example["name"]
    assert_equal "passed", example["status"]
    assert_nil example["message"]
    assert_equal "req-1", body["request_id"]
  end

  def test_excluded_fields_never_cross
    body = post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION)

    refute body.key?("coverage")
    refute body["rollout"].key?("coverage")
    refute body["rollout"].key?("adapter")
    refute body.key?("solution_path")
    refute body.key?("test_path")
    refute body["rollout"].key?("solution_path")
    refute body["rollout"].key?("test_path")
  end

  def test_a_failing_rollout_is_still_200_with_outcome_ok
    body = post(task_name: "server_fixture", submission_code: FAILING_SUBMISSION)

    assert_equal 200, @last_status
    assert_equal "ok", body["outcome"]
    refute body["passed"]
    assert_equal "ok", body["rollout"]["outcome"]
    assert_equal 1, body["rollout"]["failed"]
  end

  def test_a_raised_submission_reports_outcome_error
    body = post(task_name: "server_fixture", submission_code: ERROR_SUBMISSION)

    assert_equal 200, @last_status
    assert_equal "error", body["outcome"]
    refute body["passed"]
    assert_equal "error", body["rollout"]["outcome"]
    assert_match(/boom from submission/, body["rollout"]["error"])
  end

  def test_a_crashing_submission_reports_outcome_crash
    body = post(task_name: "server_fixture", submission_code: CRASH_SUBMISSION)

    assert_equal 200, @last_status
    assert_equal "crash", body["outcome"]
    refute body["passed"]
    assert_equal "crash", body["rollout"]["outcome"]
  end

  def test_a_timed_out_submission_reports_outcome_timeout
    body = post(task_name: "server_fixture", submission_code: "sleep 3\n" + PASSING_SUBMISSION, timeout: 1)

    assert_equal 200, @last_status
    assert_equal "timeout", body["outcome"]
    refute body["passed"]
    assert_equal "timeout", body["rollout"]["outcome"]
  end

  def test_a_prefilter_reject_is_200_with_rollout_null
    body = post(task_name: "server_fixture", submission_code: SYNTAX_INVALID_SUBMISSION)

    assert_equal 200, @last_status
    assert_equal "prefiltered", body["outcome"]
    refute body["passed"]
    refute body["prefilter"]["clean"]
    refute body["prefilter"]["syntax_valid"]
    refute_empty body["prefilter"]["findings"]
    assert_nil body["rollout"]
  end

  def test_a_finding_location_is_sanitized_to_a_caller_meaningless_path
    body = post(task_name: "server_fixture", submission_code: SYNTAX_INVALID_SUBMISSION)

    location = body["prefilter"]["findings"].first["location"]

    assert_match(/\Asubmission\.rb:\d+:\d+\z/, location)
    refute_includes location, "canary_server_"
    refute_includes location, "/"
  end

  def test_an_unknown_path_is_404_and_never_reaches_the_verifier
    request = ::Protocol::HTTP::Request["POST", "/v1/nope", { "content-type" => "application/json" }, JSON.generate({})]
    response = @server.call(request)

    assert_equal 404, response.status
    assert_empty @spy.calls
  end

  def test_a_malformed_json_body_is_400_and_never_reaches_the_verifier
    request = build_request(%({"not valid json))
    response = @server.call(request)

    assert_equal 400, response.status
    assert_empty @spy.calls
  end

  def test_an_unknown_task_name_is_400_and_never_reaches_the_verifier
    body = post(task_name: "does_not_exist", submission_code: PASSING_SUBMISSION, expect_status: 400)

    assert_equal 400, @last_status
    assert_empty @spy.calls
    assert body.key?("error")
  end

  def test_a_missing_submission_code_is_400_and_never_reaches_the_verifier
    request = build_request(JSON.generate(task_name: "server_fixture"))
    response = @server.call(request)

    assert_equal 400, response.status
    assert_empty @spy.calls
  end

  def test_a_non_string_submission_code_is_400_and_never_reaches_the_verifier
    request = build_request(JSON.generate(task_name: "server_fixture", submission_code: 12_345))
    response = @server.call(request)

    assert_equal 400, response.status
    assert_empty @spy.calls
  end

  def test_the_timeout_is_clamped_to_four_times_the_pool_default
    post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, timeout: 999)

    assert_equal Canary::Server::MAX_TIMEOUT, @spy.calls.last[:timeout]
  end

  def test_a_timeout_under_the_clamp_passes_through_unchanged
    post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, timeout: 2)

    assert_equal 2, @spy.calls.last[:timeout]
  end

  def test_a_negative_timeout_is_400_and_never_reaches_the_verifier
    body = post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, timeout: -1, expect_status: 400)

    assert_equal 400, @last_status
    assert_empty @spy.calls
    assert body.key?("error")
  end

  def test_a_zero_timeout_is_400_and_never_reaches_the_verifier
    post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, timeout: 0, expect_status: 400)

    assert_empty @spy.calls
  end

  def test_an_infinite_timeout_is_400_and_never_reaches_the_verifier
    # Standard JSON has no NaN literal, but it does parse an overflowing
    # exponent straight to Float::INFINITY - a real, wire-representable
    # non-finite value, unlike NaN which JSON.parse rejects outright.
    body_string = %({"task_name":"server_fixture","submission_code":#{JSON.generate(PASSING_SUBMISSION)},"timeout":1e400})
    request = build_request(body_string)
    response = @server.call(request)

    assert_equal 400, response.status
    assert_empty @spy.calls
  end

  # Float::NAN itself can't be carried through a standards-compliant JSON
  # body (JSON.parse raises on a literal NaN token) - exercised directly
  # against the guard instead, per AC5's explicit requirement to cover NaN.
  def test_resolve_timeout_rejects_nan
    assert_nil @server.send(:resolve_timeout, Float::NAN)
  end

  def test_a_non_numeric_timeout_is_400_and_never_reaches_the_verifier
    request = build_request(JSON.generate(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, timeout: "soon"))
    response = @server.call(request)

    assert_equal 400, response.status
    assert_empty @spy.calls
  end

  def test_the_default_timeout_is_the_pool_default_when_omitted
    post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION)

    assert_equal Canary::Pool::DEFAULT_TIMEOUT, @spy.calls.last[:timeout]
  end

  def test_coverage_defaults_to_true_and_is_passed_through
    post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION)

    assert_equal true, @spy.calls.last[:coverage]
  end

  def test_coverage_false_is_passed_through
    post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, coverage: false)

    assert_equal false, @spy.calls.last[:coverage]
  end

  def test_request_id_is_echoed_verbatim_when_present
    body = post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION, request_id: "abc-123")

    assert_equal "abc-123", body["request_id"]
  end

  def test_request_id_is_null_when_omitted
    body = post(task_name: "server_fixture", submission_code: PASSING_SUBMISSION)

    assert_nil body["request_id"]
  end

  def test_concurrent_requests_never_exceed_the_configured_bound
    concurrency = 2
    server = Canary::Server.new(verifier: Canary::Verifier.new, entries: FIXTURES, concurrency: concurrency)
    slow_submission = "sleep 0.4\n" + PASSING_SUBMISSION
    requests = Array.new(6) { build_request(JSON.generate(task_name: "server_fixture", submission_code: slow_submission)) }

    live_during_flight = nil

    Sync do |task|
      task.with_timeout(10) do
        handles = requests.map { |request| task.async { server.call(request) } }

        sleep 0.15
        live_during_flight = descendants(Process.pid).size

        responses = handles.map(&:wait)
        responses.each do |response|
          body = JSON.parse(response.read)
          assert_equal "ok", body["outcome"]
          assert body["passed"]
        end
      end
    end

    refute_nil live_during_flight
    assert_operator live_during_flight, :>, 0, "expected some rollout to be in flight when sampled"
    assert_operator live_during_flight, :<=, concurrency * 2,
      "expected at most #{concurrency} concurrent rollouts (relay+worker each) alive, saw #{live_during_flight}"

    assert_raises(Errno::ECHILD) { Process.wait2(-1, Process::WNOHANG) }
  end

  def test_an_invalid_rollout_outcome_crosses_as_the_string_invalid
    prefilter_report = Canary::Prefilter::Report.new(syntax_valid: true, truncated: false, findings: [])
    rollout_result = Canary::RolloutResult.new(adapter: :minitest, examples: [], passed: 0, failed: 0, total: 0, outcome: :invalid)
    result = Canary::Verifier::Result.new(prefilter_report: prefilter_report, rollout_result: rollout_result, passed: false)
    server = Canary::Server.new(verifier: StubVerifier.new(result), entries: FIXTURES)

    request = build_request(JSON.generate(task_name: "server_fixture", submission_code: PASSING_SUBMISSION))
    response = server.call(request)
    body = JSON.parse(response.read)

    assert_equal 200, response.status
    assert_equal "invalid", body["outcome"]
    refute body["passed"]
    assert_equal "invalid", body["rollout"]["outcome"]
  end

  def test_a_rollout_error_and_example_message_never_carry_the_real_tempfile_path
    verifier = PathLeakVerifier.new
    server = Canary::Server.new(verifier: verifier, entries: FIXTURES)

    request = build_request(JSON.generate(task_name: "server_fixture", submission_code: PASSING_SUBMISSION))
    response = server.call(request)
    raw_body = response.read

    refute_nil verifier.captured_path
    refute_includes raw_body, verifier.captured_path
  end

  def test_an_unexpected_exception_is_500_without_leaking_message_class_or_path
    error = RuntimeError.new("distinctive failure detail at /some/leaked/path.rb")
    server = Canary::Server.new(verifier: RaisingVerifier.new(error), entries: FIXTURES)

    request = build_request(JSON.generate(task_name: "server_fixture", submission_code: PASSING_SUBMISSION))
    response = server.call(request)
    body = response.read

    assert_equal 500, response.status
    refute_includes body, "distinctive failure detail"
    refute_includes body, "RuntimeError"
    refute_includes body, "/some/leaked/path.rb"
  end

  private

  def descendants(pid)
    children = `pgrep -P #{pid}`.split.map(&:to_i)
    children + children.flat_map { |child| descendants(child) }
  end

  def build_request(body_string)
    ::Protocol::HTTP::Request["POST", "/v1/rollouts", { "content-type" => "application/json" }, body_string]
  end

  def post(expect_status: 200, **body)
    request = build_request(JSON.generate(body))
    response = @server.call(request)
    @last_status = response.status

    assert_equal expect_status, response.status
    JSON.parse(response.read)
  end
end
