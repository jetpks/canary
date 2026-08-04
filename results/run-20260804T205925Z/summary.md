# Canary eval sweep

actual spend (from recorded token usage x price table): $3.9671

spend guard cap derivation:
  claude-haiku-4-5-20251001                      136 calls x 16384 x $0.00000500 = $11.1411
  claude-sonnet-5                                136 calls x 16384 x $0.00001000 = $22.2822
  deepseek/deepseek-v4-flash                     102 calls x 16384 x $0.00000028 = $0.4679
  deepseek/deepseek-v4-pro                       102 calls x 16384 x $0.00000087 = $1.4539
  moonshotai/kimi-k2.7-code                      102 calls x 16384 x $0.00000350 = $5.8491
  qwen/qwen3-coder-plus                          102 calls x 16384 x $0.00000325 = $5.4313
  qwen/qwen3.7-max                               102 calls x 16384 x $0.00000442 = $7.3949
  accounts/fireworks/models/deepseek-v4-flash    102 calls x 16384 x $0.00000028 = $0.4679
  worst case sum: $54.4884
  cap (3x worst case, rounded up): $164

## accounts/fireworks/models/deepseek-v4-flash / hidden

### authored

- scored: 83, non_score: 1
- non_scores_by_reason: {transport_error: 1}
- pass_at_1: 0.9166666666666667 (tasks_counted: 28)
- pass_at_3: 0.9629629629629629 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 0 | {} |
| delegating_proxy_method_object | 2 | 2 | {transport_error: 1} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 1 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 2 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 3 | {} |
| protected_interval_overlap | 3 | 2 | {} |
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

## claude-haiku-4-5-20251001 / grader_visible

### authored

- scored: 28, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.8571428571428571 (tasks_counted: 28)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 1 | 1 | {} |
| block_safe_caller | 1 | 1 | {} |
| case_match_temperature_band | 1 | 1 | {} |
| character_safe_truncator | 1 | 1 | {} |
| comparable_money | 1 | 1 | {} |
| coordinate_destructure_splat | 1 | 0 | {} |
| delegating_proxy_method_object | 1 | 1 | {} |
| distance_coerce_subtraction | 1 | 0 | {} |
| ensure_return_swallows_exception | 1 | 1 | {} |
| enumerable_sparse_array | 1 | 1 | {} |
| enumerator_lazy_short_circuit | 1 | 1 | {} |
| enumerator_without_block_countdown | 1 | 1 | {} |
| eql_hash_distance_point | 1 | 0 | {} |
| exception_retrier | 1 | 1 | {} |
| hash_default_proc_tally | 1 | 1 | {} |
| identity_registry | 1 | 1 | {} |
| keyword_splat_invoker | 1 | 1 | {} |
| ledger_freeze_dup_clone | 1 | 1 | {} |
| metaprogramming_open_record | 1 | 1 | {} |
| numeric_coerce_fraction | 1 | 1 | {} |
| peekable_token_stream | 1 | 1 | {} |
| playlist_dup_clone_singleton | 1 | 0 | {} |
| protected_interval_overlap | 1 | 1 | {} |
| shadowed_constant_circle | 1 | 1 | {} |
| string_attr_parser | 1 | 1 | {} |
| struct_vector | 1 | 1 | {} |
| to_proc_lookup | 1 | 1 | {} |
| weight_unit_partial_order | 1 | 1 | {} |

### sourced

- scored: 6, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 1 | 1 | {} |
| cache_sweep_packed_entries | 1 | 1 | {} |
| counter_override_dup_clone | 1 | 1 | {} |
| gauge_reading_exact_sum | 1 | 1 | {} |
| stock_count_float_difference | 1 | 1 | {} |
| text_squash_no_mutation | 1 | 1 | {} |

## claude-haiku-4-5-20251001 / hidden

### authored

- scored: 82, non_score: 2
- non_scores_by_reason: {premature_stop: 2}
- pass_at_1: 0.8333333333333333 (tasks_counted: 28)
- pass_at_3: 0.9629629629629629 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 1 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 1 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 2 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 1 | {} |
| exception_retrier | 3 | 3 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 1 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 1 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 1 | 1 | {premature_stop: 2} |
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

## claude-sonnet-5 / grader_visible

### authored

- scored: 28, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 28)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 1 | 1 | {} |
| block_safe_caller | 1 | 1 | {} |
| case_match_temperature_band | 1 | 1 | {} |
| character_safe_truncator | 1 | 1 | {} |
| comparable_money | 1 | 1 | {} |
| coordinate_destructure_splat | 1 | 1 | {} |
| delegating_proxy_method_object | 1 | 1 | {} |
| distance_coerce_subtraction | 1 | 1 | {} |
| ensure_return_swallows_exception | 1 | 1 | {} |
| enumerable_sparse_array | 1 | 1 | {} |
| enumerator_lazy_short_circuit | 1 | 1 | {} |
| enumerator_without_block_countdown | 1 | 1 | {} |
| eql_hash_distance_point | 1 | 1 | {} |
| exception_retrier | 1 | 1 | {} |
| hash_default_proc_tally | 1 | 1 | {} |
| identity_registry | 1 | 1 | {} |
| keyword_splat_invoker | 1 | 1 | {} |
| ledger_freeze_dup_clone | 1 | 1 | {} |
| metaprogramming_open_record | 1 | 1 | {} |
| numeric_coerce_fraction | 1 | 1 | {} |
| peekable_token_stream | 1 | 1 | {} |
| playlist_dup_clone_singleton | 1 | 1 | {} |
| protected_interval_overlap | 1 | 1 | {} |
| shadowed_constant_circle | 1 | 1 | {} |
| string_attr_parser | 1 | 1 | {} |
| struct_vector | 1 | 1 | {} |
| to_proc_lookup | 1 | 1 | {} |
| weight_unit_partial_order | 1 | 1 | {} |

### sourced

- scored: 6, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 1 | 1 | {} |
| cache_sweep_packed_entries | 1 | 1 | {} |
| counter_override_dup_clone | 1 | 1 | {} |
| gauge_reading_exact_sum | 1 | 1 | {} |
| stock_count_float_difference | 1 | 1 | {} |
| text_squash_no_mutation | 1 | 1 | {} |

## claude-sonnet-5 / hidden

### authored

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9761904761904762 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 28)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 2 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
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
- pass_at_1: 0.8888888888888888 (tasks_counted: 6)
- pass_at_3: 1.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 1 | {} |
| cache_sweep_packed_entries | 3 | 3 | {} |
| counter_override_dup_clone | 3 | 3 | {} |
| gauge_reading_exact_sum | 3 | 3 | {} |
| stock_count_float_difference | 3 | 3 | {} |
| text_squash_no_mutation | 3 | 3 | {} |

## deepseek/deepseek-v4-flash / hidden

### authored

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9166666666666667 (tasks_counted: 28)
- pass_at_3: 0.9285714285714286 (tasks_counted: 28)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 0 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 2 | {} |
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

## deepseek/deepseek-v4-pro / hidden

### authored

- scored: 83, non_score: 1
- non_scores_by_reason: {truncated: 1}
- pass_at_1: 1.0 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 3 | {} |
| delegating_proxy_method_object | 2 | 2 | {truncated: 1} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 3 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
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

## moonshotai/kimi-k2.7-code / hidden

### authored

- scored: 83, non_score: 1
- non_scores_by_reason: {truncated: 1}
- pass_at_1: 0.9761904761904762 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 2 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 2 | 2 | {truncated: 1} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 3 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

### sourced

- scored: 17, non_score: 1
- non_scores_by_reason: {truncated: 1}
- pass_at_1: 0.9444444444444445 (tasks_counted: 6)
- pass_at_3: 1.0 (tasks_counted: 5)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 3 | {} |
| cache_sweep_packed_entries | 2 | 2 | {truncated: 1} |
| counter_override_dup_clone | 3 | 3 | {} |
| gauge_reading_exact_sum | 3 | 2 | {} |
| stock_count_float_difference | 3 | 3 | {} |
| text_squash_no_mutation | 3 | 3 | {} |

## qwen/qwen3-coder-plus / hidden

### authored

- scored: 83, non_score: 1
- non_scores_by_reason: {premature_stop: 1}
- pass_at_1: 0.6726190476190476 (tasks_counted: 28)
- pass_at_3: 0.8148148148148148 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 0 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 2 | 1 | {premature_stop: 1} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 0 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 2 | {} |
| metaprogramming_open_record | 3 | 1 | {} |
| numeric_coerce_fraction | 3 | 1 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |
| protected_interval_overlap | 3 | 1 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 1 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 1 | {} |

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

## qwen/qwen3.7-max / hidden

### authored

- scored: 82, non_score: 2
- non_scores_by_reason: {extractor_refusal: 1, truncated: 1}
- pass_at_1: 0.9761904761904762 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 26)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 2 | 2 | {extractor_refusal: 1} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 3 | {} |
| delegating_proxy_method_object | 2 | 2 | {truncated: 1} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 3 | {} |
| exception_retrier | 3 | 1 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
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
