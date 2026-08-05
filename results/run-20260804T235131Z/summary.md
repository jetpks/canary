# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0548

spend guard cap derivation:
  nvidia/nemotron-3-super-120b-a12b              102 calls x 16384 x $0.00000040 = $0.6685
  worst case sum: $0.6685
  cap (3x worst case, rounded up): $3

## nvidia/nemotron-3-super-120b-a12b / hidden

### authored

- scored: 71, non_score: 13
- non_scores_by_reason: {unexpected_finish_reason: 1, transport_error: 12}
- pass_at_1: 0.8846153846153846 (tasks_counted: 26)
- pass_at_3: 0.9523809523809523 (tasks_counted: 21)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
| delegating_proxy_method_object | 2 | 2 | {unexpected_finish_reason: 1} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 2 | 2 | {transport_error: 1} |
| identity_registry | 1 | 1 | {transport_error: 2} |
| keyword_splat_invoker | 0 | 0 | {transport_error: 3} |
| ledger_freeze_dup_clone | 0 | 0 | {transport_error: 3} |
| metaprogramming_open_record | 3 | 1 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 3 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 2 | 2 | {transport_error: 1} |
| struct_vector | 1 | 0 | {transport_error: 2} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

### sourced

- scored: 16, non_score: 2
- non_scores_by_reason: {transport_error: 2}
- pass_at_1: 0.9444444444444445 (tasks_counted: 6)
- pass_at_3: 1.0 (tasks_counted: 5)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 3 | {} |
| cache_sweep_packed_entries | 3 | 2 | {} |
| counter_override_dup_clone | 3 | 3 | {} |
| gauge_reading_exact_sum | 3 | 3 | {} |
| stock_count_float_difference | 3 | 3 | {} |
| text_squash_no_mutation | 1 | 1 | {transport_error: 2} |
