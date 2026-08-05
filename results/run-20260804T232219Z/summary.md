# Canary eval sweep

actual spend (from recorded token usage x price table): $0.7356

spend guard cap derivation:
  qwen/qwen3.6-35b-a3b                           102 calls x 16384 x $0.00000160 = $2.6739
  worst case sum: $2.6739
  cap (3x worst case, rounded up): $9

## qwen/qwen3.6-35b-a3b / hidden

### authored

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.8452380952380952 (tasks_counted: 28)
- pass_at_3: 0.9285714285714286 (tasks_counted: 28)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 1 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 0 | {} |
| metaprogramming_open_record | 3 | 1 | {} |
| numeric_coerce_fraction | 3 | 2 | {} |
| peekable_token_stream | 3 | 2 | {} |
| playlist_dup_clone_singleton | 3 | 3 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

### sourced

- scored: 18, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 6)
- pass_at_3: 1.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 3 | {} |
| cache_sweep_packed_entries | 3 | 3 | {} |
| counter_override_dup_clone | 3 | 3 | {} |
| gauge_reading_exact_sum | 3 | 3 | {} |
| stock_count_float_difference | 3 | 3 | {} |
| text_squash_no_mutation | 3 | 3 | {} |
