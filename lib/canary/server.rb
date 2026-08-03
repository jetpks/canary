require "json"
require "tempfile"
require "async/semaphore"
require "protocol/http"

require_relative "server/auth"
require_relative "server/config"

module Canary
  # The single-shot wire surface (R6): POST /v1/rollouts, JSON over HTTP/1.1.
  # One verb, one resource - no session, no polling, no stateful protocol
  # delta (that is named and deferred, not designed, per the I18 spike).
  #
  # A Protocol::HTTP::Middleware-shaped handler (#call(request) -> response),
  # so it is unit-testable directly - real Canary::Verifier, no HTTP, no
  # mocking - the same way Canary::Verifier itself is tested against a real
  # Canary::Pool rather than a socket. Auth composes ahead of this in
  # Canary::Server::Auth; this class never sees a request auth already
  # rejected.
  #
  # +entries+ mirrors Canary::Eval::Runner's own vocabulary for "the corpus
  # this run knows about" - defaulting to the real corpus via TaskRepo.all,
  # injectable in tests the same way Canary::Verifier.new(pool:) is.
  class Server
    # Matches Canary::Eval::Runner::DEFAULT_CONCURRENCY's own fork-bomb
    # reasoning: every accepted connection that reaches #call forks two OS
    # processes for its rollout (Pool#fork_and_collect's relay + worker) -
    # an unbounded number of concurrent connections would multiply both at
    # once. Independent of Runner's own knob (a live sweep's concurrency)
    # even though the number happens to match today.
    DEFAULT_CONCURRENCY = 5

    # An unbounded caller-supplied timeout is a resource-exhaustion knob
    # (a caller can otherwise just ask for a rollout that occupies a fork
    # slot forever); this is the upper bound a request's own +timeout+ is
    # clamped to, never the default (Pool::DEFAULT_TIMEOUT stays that).
    MAX_TIMEOUT = Pool::DEFAULT_TIMEOUT * 4

    LOCATION_SUFFIX = /:(\d+):(\d+)\z/

    def initialize(verifier: Verifier.new, concurrency: DEFAULT_CONCURRENCY, entries: TaskRepo.all)
      @verifier = verifier
      @semaphore = Async::Semaphore.new(concurrency)
      @entries_by_name = entries.each_with_object({}) { |entry, byname| byname[entry.name] = entry }
    end

    def call(request)
      body = parse_body(request)
      return bad_request("request body must be a JSON object") unless body.is_a?(Hash)

      entry = @entries_by_name[body["task_name"]]
      return bad_request("unknown task_name #{body["task_name"].inspect}") unless entry

      submission_code = body["submission_code"]
      return bad_request("submission_code must be a string") unless submission_code.is_a?(String)

      result = dispatch(entry, submission_code, body)

      json_response(200, serialize(result, body["request_id"]))
    rescue StandardError => e
      ::Protocol::HTTP::Response.for_exception(e)
    end

    def close
    end

    private

    def dispatch(entry, submission_code, body)
      coverage = body.fetch("coverage", true)
      timeout = clamp_timeout(body["timeout"])

      @semaphore.acquire do
        Tempfile.create(["canary_server_", ".rb"]) do |file|
          file.write(submission_code)
          file.flush

          task = Task.new(solution_path: file.path, test_path: entry.reference.test_path, adapter: entry.adapter)
          @verifier.call(task, coverage: coverage, timeout: timeout)
        end
      end
    end

    def parse_body(request)
      JSON.parse(request.read)
    rescue JSON::ParserError, TypeError
      nil
    end

    def clamp_timeout(requested)
      return Pool::DEFAULT_TIMEOUT unless requested.is_a?(Numeric)

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
    def serialize(result, request_id)
      {
        outcome: result.rollout_result ? result.rollout_result.outcome : :prefiltered,
        passed: result.passed,
        prefilter: serialize_prefilter(result.prefilter_report),
        rollout: result.rollout_result && serialize_rollout(result.rollout_result),
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

    # #coverage and #adapter never cross (a coverage map is a free
    # tampering guide; adapter is a harness detail), whatever the request's
    # own +coverage+ flag asked the pool to compute.
    def serialize_rollout(rollout)
      {
        outcome: rollout.outcome,
        passed: rollout.passed,
        failed: rollout.failed,
        total: rollout.total,
        error: rollout.error,
        examples: rollout.examples.map { |example| serialize_example(example) }
      }
    end

    def serialize_example(example)
      { name: example.name, status: example.status, message: example.message }
    end
  end
end
