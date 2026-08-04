# Canary eval sweep

actual spend (from recorded token usage x price table): $5.0349

spend guard cap derivation:
  claude-haiku-4-5-20251001                      112 calls x 16384 x $0.00000500 = $9.1750
  claude-sonnet-5                                112 calls x 16384 x $0.00001000 = $18.3501
  deepseek/deepseek-v4-flash                      84 calls x 16384 x $0.00000028 = $0.3854
  deepseek/deepseek-v4-pro                        84 calls x 16384 x $0.00000087 = $1.1973
  moonshotai/kimi-k3                              84 calls x 16384 x $0.00001500 = $20.6438
  moonshotai/kimi-k2.7-code                       84 calls x 16384 x $0.00000350 = $4.8169
  qwen/qwen3-coder-plus                           84 calls x 16384 x $0.00000325 = $4.4728
  qwen/qwen3.7-max                                84 calls x 16384 x $0.00000442 = $6.0899
  z-ai/glm-5.2                                    84 calls x 16384 x $0.00000374 = $5.1472
  accounts/fireworks/models/deepseek-v4-flash     84 calls x 16384 x $0.00000028 = $0.3854
  worst case sum: $70.6639
  cap (3x worst case, rounded up): $212

## accounts/fireworks/models/deepseek-v4-flash / hidden

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9285714285714286 (tasks_counted: 28)
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
| exception_retrier | 3 | 1 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 2 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 2 | {} |
| protected_interval_overlap | 3 | 2 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

## claude-haiku-4-5-20251001 / grader_visible

- scored: 27, non_score: 1
- non_scores_by_reason: {truncated: 1}
- pass_at_1: 0.9259259259259259 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 1 | 1 | {} |
| block_safe_caller | 1 | 1 | {} |
| case_match_temperature_band | 1 | 1 | {} |
| character_safe_truncator | 1 | 1 | {} |
| comparable_money | 1 | 1 | {} |
| coordinate_destructure_splat | 1 | 0 | {} |
| delegating_proxy_method_object | 1 | 1 | {} |
| distance_coerce_subtraction | 1 | 1 | {} |
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
| playlist_dup_clone_singleton | 1 | 1 | {} |
| protected_interval_overlap | 1 | 1 | {} |
| shadowed_constant_circle | 1 | 1 | {} |
| string_attr_parser | 0 | 0 | {truncated: 1} |
| struct_vector | 1 | 1 | {} |
| to_proc_lookup | 1 | 1 | {} |
| weight_unit_partial_order | 1 | 1 | {} |

## claude-haiku-4-5-20251001 / hidden

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.8571428571428571 (tasks_counted: 28)
- pass_at_3: 0.9642857142857143 (tasks_counted: 28)

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
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 1 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

## claude-sonnet-5 / grader_visible

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

## claude-sonnet-5 / hidden

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9523809523809524 (tasks_counted: 28)
- pass_at_3: 0.9642857142857143 (tasks_counted: 28)

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
| exception_retrier | 3 | 0 | {} |
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

## deepseek/deepseek-v4-flash / hidden

- scored: 84, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9404761904761905 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 28)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
| delegating_proxy_method_object | 3 | 2 | {} |
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
| playlist_dup_clone_singleton | 3 | 2 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

## deepseek/deepseek-v4-pro / hidden

- scored: 82, non_score: 2
- non_scores_by_reason: {truncated: 2}
- pass_at_1: 0.9880952380952381 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 26)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
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
| metaprogramming_open_record | 2 | 2 | {truncated: 1} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 3 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

## moonshotai/kimi-k2.7-code / hidden

- scored: 80, non_score: 4
- non_scores_by_reason: {unexpected_finish_reason: 2, truncated: 2}
- pass_at_1: 0.9523809523809524 (tasks_counted: 28)
- pass_at_3: 1.0 (tasks_counted: 26)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 1 | 1 | {unexpected_finish_reason: 2} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 1 | {} |
| delegating_proxy_method_object | 1 | 1 | {truncated: 2} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 2 | {} |
| exception_retrier | 3 | 3 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 2 | {} |
| numeric_coerce_fraction | 3 | 3 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 3 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 3 | {} |

## moonshotai/kimi-k3 / hidden

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
| exception_retrier | 3 | 3 | {} |
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

## qwen/qwen3-coder-plus / hidden

- scored: 83, non_score: 1
- non_scores_by_reason: {truncated: 1}
- pass_at_1: 0.6666666666666667 (tasks_counted: 28)
- pass_at_3: 0.8518518518518519 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 0 | {} |
| delegating_proxy_method_object | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 1 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 1 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 0 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 2 | {} |
| metaprogramming_open_record | 3 | 1 | {} |
| numeric_coerce_fraction | 3 | 1 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 2 | 0 | {truncated: 1} |
| protected_interval_overlap | 3 | 1 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 1 | {} |

## qwen/qwen3.7-max / hidden

- scored: 81, non_score: 3
- non_scores_by_reason: {truncated: 3}
- pass_at_1: 0.9506172839506173 (tasks_counted: 27)
- pass_at_3: 1.0 (tasks_counted: 27)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 1 | {} |
| delegating_proxy_method_object | 0 | 0 | {truncated: 3} |
| distance_coerce_subtraction | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 2 | {} |
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

## z-ai/glm-5.2 / hidden

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
| coordinate_destructure_splat | 3 | 3 | {} |
| delegating_proxy_method_object | 3 | 2 | {} |
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
| ledger_freeze_dup_clone | 3 | 2 | {} |
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
