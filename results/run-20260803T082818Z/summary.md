# Canary eval sweep

## accounts/fireworks/models/deepseek-v4-flash / hidden

- scored: 35, non_score: 4
- non_scores_by_reason: {truncated: 1, transport_error: 3}
- pass_at_1: 0.8611111111111112 (tasks_counted: 12)
- pass_at_3: 0.9090909090909091 (tasks_counted: 11)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 2 | 2 | {truncated: 1} |
| eql_hash_distance_point | 3 | 1 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 0 | 0 | {transport_error: 3} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## claude-haiku-4-5-20251001 / grader_visible

- scored: 13, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9230769230769231 (tasks_counted: 13)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 1 | 1 | {} |
| block_safe_caller | 1 | 1 | {} |
| comparable_money | 1 | 1 | {} |
| ensure_return_swallows_exception | 1 | 1 | {} |
| enumerable_sparse_array | 1 | 1 | {} |
| enumerator_lazy_short_circuit | 1 | 1 | {} |
| eql_hash_distance_point | 1 | 0 | {} |
| exception_retrier | 1 | 1 | {} |
| hash_default_proc_tally | 1 | 1 | {} |
| metaprogramming_open_record | 1 | 1 | {} |
| shadowed_constant_circle | 1 | 1 | {} |
| string_attr_parser | 1 | 1 | {} |
| struct_vector | 1 | 1 | {} |

## claude-haiku-4-5-20251001 / hidden

- scored: 39, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.8717948717948718 (tasks_counted: 13)
- pass_at_3: 0.9230769230769231 (tasks_counted: 13)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 2 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 2 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## claude-sonnet-5 / grader_visible

- scored: 13, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 13)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 1 | 1 | {} |
| block_safe_caller | 1 | 1 | {} |
| comparable_money | 1 | 1 | {} |
| ensure_return_swallows_exception | 1 | 1 | {} |
| enumerable_sparse_array | 1 | 1 | {} |
| enumerator_lazy_short_circuit | 1 | 1 | {} |
| eql_hash_distance_point | 1 | 1 | {} |
| exception_retrier | 1 | 1 | {} |
| hash_default_proc_tally | 1 | 1 | {} |
| metaprogramming_open_record | 1 | 1 | {} |
| shadowed_constant_circle | 1 | 1 | {} |
| string_attr_parser | 1 | 1 | {} |
| struct_vector | 1 | 1 | {} |

## claude-sonnet-5 / hidden

- scored: 39, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.8974358974358974 (tasks_counted: 13)
- pass_at_3: 1.0 (tasks_counted: 13)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 1 | {} |
| exception_retrier | 3 | 1 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## deepseek/deepseek-v4-flash / hidden

- scored: 38, non_score: 1
- non_scores_by_reason: {truncated: 1}
- pass_at_1: 0.8461538461538461 (tasks_counted: 13)
- pass_at_3: 0.8333333333333334 (tasks_counted: 12)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 2 | 2 | {truncated: 1} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## deepseek/deepseek-v4-pro / hidden

- scored: 36, non_score: 3
- non_scores_by_reason: {truncated: 3}
- pass_at_1: 0.8717948717948718 (tasks_counted: 13)
- pass_at_3: 0.9 (tasks_counted: 10)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 2 | 2 | {truncated: 1} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 2 | 2 | {truncated: 1} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 1 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 2 | 2 | {truncated: 1} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## moonshotai/kimi-k2.7-code / hidden

- scored: 27, non_score: 12
- non_scores_by_reason: {truncated: 12}
- pass_at_1: 0.85 (tasks_counted: 10)
- pass_at_3: 0.875 (tasks_counted: 8)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 0 | 0 | {truncated: 3} |
| block_safe_caller | 1 | 1 | {truncated: 2} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 0 | 0 | {truncated: 3} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 2 | 1 | {truncated: 1} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 0 | 0 | {truncated: 3} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## moonshotai/kimi-k3 / hidden

- scored: 26, non_score: 13
- non_scores_by_reason: {unexpected_finish_reason: 12, transport_error: 1}
- pass_at_1: 0.9696969696969696 (tasks_counted: 11)
- pass_at_3: 1.0 (tasks_counted: 7)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 2 | 2 | {unexpected_finish_reason: 1} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 1 | 1 | {unexpected_finish_reason: 2} |
| eql_hash_distance_point | 0 | 0 | {unexpected_finish_reason: 3} |
| exception_retrier | 3 | 2 | {} |
| hash_default_proc_tally | 0 | 0 | {unexpected_finish_reason: 3} |
| metaprogramming_open_record | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 1 | 1 | {unexpected_finish_reason: 2} |
| struct_vector | 1 | 1 | {unexpected_finish_reason: 1, transport_error: 1} |

## qwen/qwen3-coder-plus / hidden

- scored: 39, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.7692307692307693 (tasks_counted: 13)
- pass_at_3: 0.8461538461538461 (tasks_counted: 13)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 1 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 2 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## qwen/qwen3.7-max / hidden

- scored: 39, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.9230769230769231 (tasks_counted: 13)
- pass_at_3: 0.9230769230769231 (tasks_counted: 13)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 3 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |

## z-ai/glm-5.2 / hidden

- scored: 33, non_score: 6
- non_scores_by_reason: {truncated: 6}
- pass_at_1: 0.8974358974358974 (tasks_counted: 13)
- pass_at_3: 0.8888888888888888 (tasks_counted: 9)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 1 | 1 | {truncated: 2} |
| comparable_money | 3 | 3 | {} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 2 | 2 | {truncated: 1} |
| enumerator_lazy_short_circuit | 2 | 2 | {truncated: 1} |
| eql_hash_distance_point | 3 | 0 | {} |
| exception_retrier | 3 | 2 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| metaprogramming_open_record | 1 | 1 | {truncated: 2} |
| shadowed_constant_circle | 3 | 3 | {} |
| string_attr_parser | 3 | 3 | {} |
| struct_vector | 3 | 3 | {} |
