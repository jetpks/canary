module Canary
  module Eval
    # Aggregates a set of Canary::Eval::Record into pass rates. The one rule
    # that matters (R3): a non-score never enters a rate's denominator, and a
    # rate computed over zero scored records is nil, not 0.0 - a 0.0 claims
    # the model failed everything, when in fact nothing was measurable.
    #
    # pass@k uses the unbiased estimator from Chen et al. 2021 ("Evaluating
    # Large Language Models Trained on Code", the Codex paper): per task,
    # 1 - C(n-c, k) / C(n, k), where n is that task's scored sample count and
    # c is how many of them passed - then averaged across tasks. At k=1 this
    # reduces exactly to the empirical per-task pass rate, so pass_at_1 is
    # pass_at_k(1) under a different name.
    class Report
      def initialize(records)
        @records = records
      end

      def scored_count
        scored_records.size
      end

      def non_score_count
        @records.size - scored_count
      end

      def non_scores_by_reason
        @records.reject(&:scored?).group_by(&:non_score_reason).transform_values(&:size)
      end

      def pass_at_1
        pass_at_k(1)
      end

      def pass_at_k(k)
        rates = grouped_by_task.filter_map { |_task_name, records| task_pass_at_k(records, k) }
        return nil if rates.empty?

        rates.sum / rates.size.to_f
      end

      private

      def scored_records
        @records.select(&:scored?)
      end

      def grouped_by_task
        scored_records.group_by(&:task_name)
      end

      def task_pass_at_k(records, k)
        n = records.size
        return nil if n < k

        c = records.count(&:passed)
        1 - comb(n - c, k) / comb(n, k).to_f
      end

      def comb(n, k)
        return 0 if k.negative? || k > n
        return 1 if k.zero?

        (1..k).reduce(1) { |acc, i| acc * (n - k + i) / i }
      end
    end
  end
end
