module Canary
  module Eval
    # One row per (task, model, sample index): whatever the runner learned
    # trying to get one graded answer out of one model on one task.
    #
    # +scored+ is the load-bearing field. A sample the harness never got to
    # judge - a refusal, a truncated response, an extractor that found no
    # fenced Ruby, a budget/spend guard trip, a transport error - carries
    # scored: false and a non_score_reason, and MUST NOT carry a passed
    # verdict. Canary::Eval::Report relies on this to keep non-scores out of
    # every rate's denominator (R3): folding one of these into "failed"
    # reports a harness limitation as a model failure.
    #
    # schema_version is a plain field, not inferred from shape, so a future
    # format change can tell old records apart from new ones on disk rather
    # than guessing from which keys happen to be present.
    Record = Struct.new(
      :schema_version, :task_name, :model, :sample_index, :render_mode,
      :scored, :non_score_reason, :passed,
      :prefilter_clean, :rollout_outcome, :passed_examples, :total_examples, :coverage_fraction,
      :extractor_outcome, :stop_reason, :input_tokens, :output_tokens,
      keyword_init: true
    ) do
      def scored?
        scored
      end
    end
  end
end
