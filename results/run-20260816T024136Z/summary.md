# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.8-27b-mxfp8-concurrent1                   30 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## qwen3.8-27b-mxfp8-concurrent1 / hidden

### authored

- scored: 25, non_score: 5
- non_scores_by_reason: {extractor_refusal: 5}
- pass_at_1: 0.5833333333333334 (tasks_counted: 10)
- pass_at_3: 0.6 (tasks_counted: 5)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 2 | 2 | {extractor_refusal: 1} |
| case_match_temperature_band | 3 | 3 | {} |
| comparable_money | 2 | 2 | {extractor_refusal: 1} |
| distance_coerce_subtraction | 2 | 0 | {extractor_refusal: 1} |
| enumerable_sparse_array | 2 | 1 | {extractor_refusal: 1} |
| enumerator_without_block_countdown | 3 | 2 | {} |
| exception_retrier | 3 | 2 | {} |
| identity_registry | 2 | 2 | {extractor_refusal: 1} |
| numeric_coerce_fraction | 3 | 0 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |

### sourced

- scored: 0, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: nil (tasks_counted: 0)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
