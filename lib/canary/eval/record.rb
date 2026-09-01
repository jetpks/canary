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
    # than guessing from which keys happen to be present. Version 2 added
    # sample_ms, and is also the first version whose sampling is trustworthy:
    # every version-1 run on disk was drawn either greedily or with a seed
    # that correlated the samples across tasks.
    #
    # Version 3 states the output contract to the model (Canary::Prompt::SYSTEM)
    # instead of assuming it. Every v1/v2 hidden-arm number was partly a
    # measure of whether a model guessed that an unfenced answer would be
    # thrown away, so v2 and v3 rates are NOT poolable - the input changed.
    # v3 runs also record the provider's real request body in
    # completions.jsonl and a run_config.json beside it, so a run's own
    # evidence states the sampling parameters it was drawn under.
    #
    # +sample_ms+ is wall time for the whole attempt at one sample - render,
    # provider round trip, and the queueing behind it - measured in the
    # runner rather than the provider, because what a time-vs-accuracy
    # comparison wants is how long an answer took to obtain, not how long
    # the socket was open. It is set on every record, including non-scored
    # ones: a refusal that took four minutes is a different thing from one
    # that took four seconds.
    Record = Data.define(
      :schema_version, :task_name, :model, :sample_index, :render_mode,
      :scored, :non_score_reason, :passed,
      :prefilter_clean, :rollout_outcome, :passed_examples, :total_examples, :coverage_fraction,
      :extractor_outcome, :stop_reason, :input_tokens, :output_tokens, :sample_ms
    ) do
      # No required fields beyond whatever the caller supplies (Runner's
      # four record-building sites each set a different subset; Report and
      # the results-schema gate build records with only a handful of keys
      # set) - Data.define has no equivalent to Struct's free keyword_init
      # nil-fill, so this replicates it explicitly rather than naming 17
      # individual defaults.
      def initialize(**kwargs)
        super(**members.to_h { |member| [member, nil] }.merge(kwargs))
      end

      def scored?
        scored
      end
    end
  end
end
