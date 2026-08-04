# Canary eval sweep

actual spend (from recorded token usage x price table): $0.4603

spend guard cap derivation:
  z-ai/glm-5.2                                   102 calls x 16384 x $0.00000374 = $6.2502
  worst case sum: $6.2502
  cap (3x worst case, rounded up): $19

## z-ai/glm-5.2 / hidden

### authored

- scored: 43, non_score: 41
- non_scores_by_reason: {transport_error: 41}
- pass_at_1: 0.8846153846153846 (tasks_counted: 26)
- pass_at_3: 1.0 (tasks_counted: 2)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 2 | 2 | {transport_error: 1} |
| block_safe_caller | 2 | 2 | {transport_error: 1} |
| case_match_temperature_band | 2 | 2 | {transport_error: 1} |
| character_safe_truncator | 2 | 2 | {transport_error: 1} |
| comparable_money | 0 | 0 | {transport_error: 3} |
| coordinate_destructure_splat | 2 | 0 | {transport_error: 1} |
| delegating_proxy_method_object | 2 | 1 | {transport_error: 1} |
| distance_coerce_subtraction | 0 | 0 | {transport_error: 3} |
| ensure_return_swallows_exception | 1 | 1 | {transport_error: 2} |
| enumerable_sparse_array | 1 | 1 | {transport_error: 2} |
| enumerator_lazy_short_circuit | 1 | 1 | {transport_error: 2} |
| enumerator_without_block_countdown | 1 | 1 | {transport_error: 2} |
| eql_hash_distance_point | 1 | 1 | {transport_error: 2} |
| exception_retrier | 2 | 1 | {transport_error: 1} |
| hash_default_proc_tally | 1 | 1 | {transport_error: 2} |
| identity_registry | 1 | 1 | {transport_error: 2} |
| keyword_splat_invoker | 1 | 1 | {transport_error: 2} |
| ledger_freeze_dup_clone | 2 | 1 | {transport_error: 1} |
| metaprogramming_open_record | 2 | 1 | {transport_error: 1} |
| numeric_coerce_fraction | 2 | 2 | {transport_error: 1} |
| peekable_token_stream | 1 | 1 | {transport_error: 2} |
| playlist_dup_clone_singleton | 2 | 2 | {transport_error: 1} |
| protected_interval_overlap | 1 | 1 | {transport_error: 2} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 1 | 1 | {transport_error: 2} |
| to_proc_lookup | 2 | 2 | {transport_error: 1} |
| weight_unit_partial_order | 2 | 2 | {transport_error: 1} |

### sourced

- scored: 12, non_score: 6
- non_scores_by_reason: {transport_error: 6}
- pass_at_1: 1.0 (tasks_counted: 6)
- pass_at_3: 1.0 (tasks_counted: 2)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 2 | 2 | {transport_error: 1} |
| cache_sweep_packed_entries | 3 | 3 | {} |
| counter_override_dup_clone | 1 | 1 | {transport_error: 2} |
| gauge_reading_exact_sum | 1 | 1 | {transport_error: 2} |
| stock_count_float_difference | 2 | 2 | {transport_error: 1} |
| text_squash_no_mutation | 3 | 3 | {} |
