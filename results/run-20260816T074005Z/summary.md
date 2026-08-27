# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.8-27b-mxfp8-concurrent1                    4 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## qwen3.8-27b-mxfp8-concurrent1 / hidden

### authored

- scored: 2, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 1)
- pass_at_2: 1.0 (tasks_counted: 1)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| hash_default_proc_tally | 2 | 2 | {} |

### sourced

- scored: 2, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.5 (tasks_counted: 1)
- pass_at_2: 1.0 (tasks_counted: 1)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 2 | 1 | {} |
