# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.8-27b-mxfp8-concurrent4                   12 calls x 32768 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## qwen3.8-27b-mxfp8-concurrent4 / hidden

### authored

- scored: 9, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 9)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| coordinate_destructure_splat | 1 | 1 | {} |
| delivery_audited_route_block | 1 | 1 | {} |
| enumerable_sparse_array | 1 | 1 | {} |
| event_broadcaster_duck_protocol | 1 | 1 | {} |
| hash_default_proc_tally | 1 | 1 | {} |
| ledger_freeze_dup_clone | 1 | 1 | {} |
| peekable_token_stream | 1 | 1 | {} |
| shadowed_constant_circle | 1 | 1 | {} |
| temperature_report_injected_scale | 1 | 1 | {} |

### sourced

- scored: 3, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 3)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 1 | 1 | {} |
| cache_sweep_packed_entries | 1 | 1 | {} |
| stock_count_float_difference | 1 | 1 | {} |
