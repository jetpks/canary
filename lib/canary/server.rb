require "json"
require "tempfile"
require "async/semaphore"
require "protocol/http"

require_relative "server/auth"
require_relative "server/config"

module Canary
  # The single-shot wire surface (R6): JSON over HTTP/1.1, no session, no
  # polling, no stateful protocol delta (that is named and deferred, not
  # designed, per the I18 spike). Two verbs: POST /v1/rollouts (grade a
  # submission against a task) and POST /v1/eval (run arbitrary Ruby and
  # report what happened - no adapter, no grading, no prefilter).
  #
  # A Protocol::HTTP::Middleware-shaped handler (#call(request) -> response),
  # so it is unit-testable directly - real Canary::Verifier/Canary::Pool, no
  # HTTP, no mocking - the same way Canary::Verifier itself is tested
  # against a real Canary::Pool rather than a socket. Auth composes ahead of
  # this in Canary::Server::Auth; this class never sees a request auth
  # already rejected.
  #
  # +entries+ mirrors Canary::Eval::Runner's own vocabulary for "the corpus
  # this run knows about" - defaulting to the real corpus via TaskRepo.all,
  # injectable in tests the same way Canary::Verifier.new(pool:) is.
  class Server
    # Matches Canary::Eval::Runner::DEFAULT_CONCURRENCY's own fork-bomb
    # reasoning: every accepted connection that reaches #call forks two OS
    # processes, for a rollout or an eval alike (Pool#fork_and_collect's
    # relay + worker) - an unbounded number of concurrent connections would
    # multiply both at once. Independent of Runner's own knob (a live
    # sweep's concurrency) even though the number happens to match today.
    DEFAULT_CONCURRENCY = 5

    # An unbounded caller-supplied timeout is a resource-exhaustion knob
    # (a caller can otherwise just ask for a rollout that occupies a fork
    # slot forever); this is the upper bound a request's own +timeout+ is
    # clamped to, never the default (Pool::DEFAULT_TIMEOUT stays that).
    MAX_TIMEOUT = Pool::DEFAULT_TIMEOUT * 4

    LOCATION_SUFFIX = /:(\d+):(\d+)\z/

    ROUTES = {
      ["POST", "/v1/rollouts"] => :call_rollout,
      ["POST", "/v1/eval"] => :call_eval,
    }.freeze

    # +pool+ defaults to one shared instance, handed to the default
    # +verifier+ too (Verifier.new(pool:) is already its own public
    # constructor) - so a plain `Server.new` preloads adapters exactly
    # once, not once for rollouts and again for eval.
    def initialize(pool: Pool.new, verifier: Verifier.new(pool: pool), concurrency: DEFAULT_CONCURRENCY, entries: TaskRepo.all)
      @pool = pool
      @verifier = verifier
      @semaphore = Async::Semaphore.new(concurrency)
      @entries_by_name = entries.each_with_object({}) { |entry, byname| byname[entry.name] = entry }
    end

    def call(request)
      handler = ROUTES[[request.method, request.path]]
      return not_found unless handler

      send(handler, request)
    rescue StandardError
      json_response(500, error: "internal error")
    end

    def close
    end

    private

    def call_rollout(request)
      body = parse_body(request)
      return bad_request("request body must be a JSON object") unless body.is_a?(Hash)

      entry = @entries_by_name[body["task_name"]]
      return bad_request("unknown task_name #{body["task_name"].inspect}") unless entry

      submission_code = body["submission_code"]
      return bad_request("submission_code must be a string") unless submission_code.is_a?(String)

      timeout = resolve_timeout(body["timeout"])
      return bad_request("timeout must be a positive, finite number") unless timeout

      result, tempfile_path = dispatch(entry, submission_code, body, timeout)

      json_response(200, serialize(result, body["request_id"], tempfile_path))
    end

    def call_eval(request)
      body = parse_body(request)
      return bad_request("request body must be a JSON object") unless body.is_a?(Hash)

      code = body["code"]
      return bad_request("code must be a string") unless code.is_a?(String)

      timeout = resolve_timeout(body["timeout"])
      return bad_request("timeout must be a positive, finite number") unless timeout

      result = dispatch_eval(code, timeout)

      json_response(200, serialize_eval(result, body["request_id"]))
    end

    def not_found
      json_response(404, error: "not found")
    end

    def dispatch(entry, submission_code, body, timeout)
      coverage = body.fetch("coverage", true)

      @semaphore.acquire do
        Tempfile.create(["canary_server_", ".rb"]) do |file|
          file.write(submission_code)
          file.flush

          task = Task.new(solution_path: file.path, test_path: entry.reference.test_path, adapter: entry.adapter)
          [@verifier.call(task, coverage: coverage, timeout: timeout), file.path]
        end
      end
    end

    def dispatch_eval(code, timeout)
      @semaphore.acquire { @pool.eval_code(code: code, timeout: timeout) }
    end

    def parse_body(request)
      JSON.parse(request.read)
    rescue JSON::ParserError, TypeError
      nil
    end

    # Absent -> the pool's own default (unchanged); present and a positive,
    # finite Numeric -> clamped to MAX_TIMEOUT (unchanged); anything else
    # (negative, zero, NaN, non-Numeric) -> nil, which #call turns into a
    # 400 before the verifier ever sees it. NaN fails both #finite? and
    # #positive? (verified live: Float::NAN <= x is false for every x, so a
    # bare range check can't be trusted to catch it - #finite?/#positive?
    # are the explicit checks that do).
    def resolve_timeout(requested)
      return Pool::DEFAULT_TIMEOUT if requested.nil?
      return nil unless requested.is_a?(Numeric) && requested.finite? && requested.positive?

      [requested, MAX_TIMEOUT].min
    end

    def bad_request(message)
      json_response(400, error: message)
    end

    def json_response(status, payload)
      ::Protocol::HTTP::Response[status, { "content-type" => "application/json" }, [JSON.generate(payload)]]
    end

    # The wire's own outcome taxonomy is one layer out from
    # RolloutResult#outcome (I15/I16 dishonesty class, promoted a layer up
    # by the I18 verdict): a prefiltered-and-rejected submission never ran a
    # rollout at all, which :ok/:error/:crash/:timeout/:invalid has no
    # member for - so it gets its own, distinct :prefiltered value here
    # rather than overloading one of the rollout's own terminal states.
    def serialize(result, request_id, tempfile_path)
      {
        outcome: result.rollout_result ? result.rollout_result.outcome : :prefiltered,
        passed: result.passed,
        prefilter: serialize_prefilter(result.prefilter_report),
        rollout: result.rollout_result && serialize_rollout(result.rollout_result, tempfile_path),
        request_id: request_id
      }
    end

    def serialize_prefilter(report)
      {
        clean: report.clean?,
        syntax_valid: report.syntax_valid,
        truncated: report.truncated,
        findings: report.findings.map { |finding| serialize_finding(finding) }
      }
    end

    # Finding#location carries the server's own Tempfile path -
    # meaningless, and unwanted, on the wire (it names nothing the caller
    # can act on and would otherwise leak the host's tmp layout) - reduced
    # to the line:col a caller can actually use, against a fixed,
    # caller-meaningless filename.
    def serialize_finding(finding)
      {
        tier: finding.tier,
        severity: finding.severity,
        type: finding.type,
        message: finding.message,
        location: sanitize_location(finding.location),
        gating: finding.gating?
      }
    end

    def sanitize_location(location)
      match = LOCATION_SUFFIX.match(location)
      match ? "submission.rb:#{match[1]}:#{match[2]}" : "submission.rb"
    end

    # rollout.error and an example's message are free text - unlike a
    # Finding's location, there's no fixed suffix shape to match, so this
    # scrubs the one tempfile path the server itself knows it handed to the
    # child rather than any path-shaped pattern (a submission's own text may
    # legitimately look like a path).
    def sanitize_text(text, tempfile_path)
      text&.gsub(tempfile_path, "submission.rb")
    end

    # #coverage and #adapter never cross (a coverage map is a free
    # tampering guide; adapter is a harness detail), whatever the request's
    # own +coverage+ flag asked the pool to compute.
    def serialize_rollout(rollout, tempfile_path)
      {
        outcome: rollout.outcome,
        passed: rollout.passed,
        failed: rollout.failed,
        total: rollout.total,
        error: sanitize_text(rollout.error, tempfile_path),
        examples: rollout.examples.map { |example| serialize_example(example, tempfile_path) }
      }
    end

    def serialize_example(example, tempfile_path)
      { name: example.name, status: example.status, message: sanitize_text(example.message, tempfile_path) }
    end

    # No tempfile in the eval path (the code string is eval'd directly, per
    # Pool#run_eval_in_child) and no location/backtrace crosses the wire at
    # all, so nothing here needs sanitize_location/sanitize_text's scrubbing
    # - there is no host path in EvalResult's fields to begin with.
    # EvalResult#error is deliberately excluded (see eval_result.rb): it is
    # this class's own crash/timeout diagnostic, not part of the frozen
    # /v1/eval response shape.
    def serialize_eval(result, request_id)
      {
        outcome: result.outcome,
        value: result.value && serialize_eval_value(result.value),
        stdout: serialize_eval_stream(result.stdout),
        stderr: serialize_eval_stream(result.stderr),
        exception: result.exception && serialize_eval_exception(result.exception),
        request_id: request_id
      }
    end

    def serialize_eval_value(value)
      { class: value.class_name, inspect: value.inspect_text, truncated: value.truncated }
    end

    def serialize_eval_stream(stream)
      { text: stream.text, truncated: stream.truncated }
    end

    def serialize_eval_exception(exception)
      { class: exception.class_name, message: exception.message }
    end
  end
end
