# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.5-9b                                     132 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## run config

- **schema_version**: `3`
- **generated_at**: `2026-09-01T21:33:04Z`
- **tasks**: `44`
- **hidden_k**: `3`
- **visible_k**: `1`
- **max_tokens**: `16384`
- **temperature**: `1.0`
- **seed_derivation**: `sha256(prompt + sample_index)[0,8]`
- **concurrency**: `{"qwen3.5-9b":1}`
- **providers**: `{"qwen3.5-9b":"studio"}`
- **extra_body**: `{"qwen3.5-9b":{"reasoning_effort":"none"}}`

system prompt (schema 3+; v2 runs had none, so their rates are not poolable with these):

```text
You are completing a self-contained Ruby coding task.

Reply with exactly one fenced Ruby code block containing the complete
implementation, and nothing else - no prose before or after it.

You have no tools, no filesystem access, and no shell. Do not emit
tool calls; write the code directly.
```

## qwen3.5-9b / hidden

### authored

- scored: 104, non_score: 10
- non_scores_by_reason: {premature_stop: 5, truncated: 5}
- pass_at_1: 0.34649122807017546 (tasks_counted: 38)
- wall_clock: total 2685.9s, median/sample 2.5s, per_task_passed 149.2s
- pass_at_3: 0.4827586206896552 (tasks_counted: 29)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 0 | {} |
| block_safe_caller | 3 | 0 | {} |
| case_match_temperature_band | 3 | 0 | {} |
| character_safe_truncator | 2 | 1 | {premature_stop: 1} |
| comparable_money | 3 | 0 | {} |
| coordinate_destructure_splat | 3 | 0 | {} |
| credits_reel_contributor_chain | 3 | 3 | {} |
| delegating_proxy_method_object | 2 | 1 | {truncated: 1} |
| delivery_audited_route_block | 3 | 1 | {} |
| distance_coerce_subtraction | 3 | 0 | {} |
| ensure_return_swallows_exception | 3 | 1 | {} |
| enumerable_sparse_array | 2 | 1 | {premature_stop: 1} |
| enumerator_lazy_short_circuit | 3 | 0 | {} |
| enumerator_without_block_countdown | 2 | 0 | {premature_stop: 1} |
| eql_hash_distance_point | 3 | 0 | {} |
| event_broadcaster_duck_protocol | 3 | 3 | {} |
| exception_retrier | 3 | 0 | {} |
| expense_tracker_injected_rounding | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 0 | {} |
| identity_registry | 2 | 2 | {premature_stop: 1} |
| keyword_splat_invoker | 3 | 2 | {} |
| ledger_freeze_dup_clone | 2 | 0 | {truncated: 1} |
| metaprogramming_open_record | 3 | 0 | {} |
| mood_board_owned_swatches | 3 | 2 | {} |
| numeric_coerce_fraction | 3 | 0 | {} |
| peekable_token_stream | 3 | 2 | {} |
| playlist_dup_clone_singleton | 1 | 0 | {truncated: 2} |
| protected_interval_overlap | 3 | 3 | {} |
| reading_circle_member_enumeration | 3 | 0 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| shipment_alert_recipient_protocol | 3 | 3 | {} |
| shipping_quote_polymorphic_packages | 3 | 3 | {} |
| string_attr_parser | 2 | 0 | {truncated: 1} |
| struct_vector | 3 | 3 | {} |
| tallying_key_store_fetch_contract | 3 | 0 | {} |
| temperature_report_injected_scale | 3 | 2 | {} |
| to_proc_lookup | 3 | 1 | {} |
| weight_unit_partial_order | 2 | 0 | {premature_stop: 1} |

### sourced

- scored: 16, non_score: 2
- non_scores_by_reason: {premature_stop: 1, truncated: 1}
- pass_at_1: 0.4444444444444445 (tasks_counted: 6)
- wall_clock: total 298.2s, median/sample 3.7s, per_task_passed 74.5s
- pass_at_3: 0.75 (tasks_counted: 4)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 1 | {} |
| cache_sweep_packed_entries | 3 | 0 | {} |
| counter_override_dup_clone | 2 | 0 | {truncated: 1} |
| gauge_reading_exact_sum | 3 | 3 | {} |
| stock_count_float_difference | 2 | 2 | {premature_stop: 1} |
| text_squash_no_mutation | 3 | 1 | {} |
