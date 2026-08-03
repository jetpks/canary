require_relative "prefilter"

module Canary
  # Composes the reward tiers over a Canary::Task: tier 0/1 (static, via the
  # existing Prefilter) gate tier 2 (the rollout), so a submission that can
  # be rejected for free never pays for a fork. Binary pass/fail only - no
  # weighting, no partial credit, no numeric reward.
  class Verifier
    Result = Data.define(:prefilter_report, :rollout_result, :passed)

    def initialize(pool: Pool.new)
      @pool = pool
    end

    def call(task, coverage: true, timeout: Pool::DEFAULT_TIMEOUT)
      report = Prefilter.call(task.solution_path)

      return Result.new(prefilter_report: report, rollout_result: nil, passed: false) unless report.clean?

      rollout_result = @pool.rollout_task(task: task, coverage: coverage, timeout: timeout)
      Result.new(prefilter_report: report, rollout_result: rollout_result, passed: rollout_result.success?)
    end
  end
end
