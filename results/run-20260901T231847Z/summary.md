# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  granite-4.1-8b                                 132 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## run config

- **schema_version**: `3`
- **generated_at**: `2026-09-01T23:18:47Z`
- **tasks**: `44`
- **hidden_k**: `3`
- **visible_k**: `1`
- **max_tokens**: `16384`
- **temperature**: `1.0`
- **seed_derivation**: `sha256(prompt + sample_index)[0,8]`
- **concurrency**: `{"granite-4.1-8b":1}`
- **providers**: `{"granite-4.1-8b":"studio"}`
- **extra_body**: `{"granite-4.1-8b":{}}`

system prompt (schema 3+; v2 runs had none, so their rates are not poolable with these):

```text
You are completing a self-contained Ruby coding task.

Reply with exactly one fenced Ruby code block containing the complete
implementation, and nothing else - no prose before or after it.

You have no tools, no filesystem access, and no shell. Do not emit
tool calls; write the code directly.
```

## granite-4.1-8b / hidden

### authored

- scored: 114, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.0 (tasks_counted: 38)
- wall_clock: total 104.9s, median/sample 0.8s, per_task_passed nils
- pass_at_3: 0.0 (tasks_counted: 38)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 0 | {} |
| block_safe_caller | 3 | 0 | {} |
| case_match_temperature_band | 3 | 0 | {} |
| character_safe_truncator | 3 | 0 | {} |
| comparable_money | 3 | 0 | {} |
| coordinate_destructure_splat | 3 | 0 | {} |
| credits_reel_contributor_chain | 3 | 0 | {} |
| delegating_proxy_method_object | 3 | 0 | {} |
| delivery_audited_route_block | 3 | 0 | {} |
| distance_coerce_subtraction | 3 | 0 | {} |
| ensure_return_swallows_exception | 3 | 0 | {} |
| enumerable_sparse_array | 3 | 0 | {} |
| enumerator_lazy_short_circuit | 3 | 0 | {} |
| enumerator_without_block_countdown | 3 | 0 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| event_broadcaster_duck_protocol | 3 | 0 | {} |
| exception_retrier | 3 | 0 | {} |
| expense_tracker_injected_rounding | 3 | 0 | {} |
| hash_default_proc_tally | 3 | 0 | {} |
| identity_registry | 3 | 0 | {} |
| keyword_splat_invoker | 3 | 0 | {} |
| ledger_freeze_dup_clone | 3 | 0 | {} |
| metaprogramming_open_record | 3 | 0 | {} |
| mood_board_owned_swatches | 3 | 0 | {} |
| numeric_coerce_fraction | 3 | 0 | {} |
| peekable_token_stream | 3 | 0 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |
| protected_interval_overlap | 3 | 0 | {} |
| reading_circle_member_enumeration | 3 | 0 | {} |
| shadowed_constant_circle | 3 | 0 | {} |
| shipment_alert_recipient_protocol | 3 | 0 | {} |
| shipping_quote_polymorphic_packages | 3 | 0 | {} |
| string_attr_parser | 3 | 0 | {} |
| struct_vector | 3 | 0 | {} |
| tallying_key_store_fetch_contract | 3 | 0 | {} |
| temperature_report_injected_scale | 3 | 0 | {} |
| to_proc_lookup | 3 | 0 | {} |
| weight_unit_partial_order | 3 | 0 | {} |

### sourced

- scored: 18, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.0 (tasks_counted: 6)
- wall_clock: total 23.5s, median/sample 0.9s, per_task_passed nils
- pass_at_3: 0.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 0 | {} |
| cache_sweep_packed_entries | 3 | 0 | {} |
| counter_override_dup_clone | 3 | 0 | {} |
| gauge_reading_exact_sum | 3 | 0 | {} |
| stock_count_float_difference | 3 | 0 | {} |
| text_squash_no_mutation | 3 | 0 | {} |
