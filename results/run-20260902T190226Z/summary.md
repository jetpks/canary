# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.6-35b-a3b-4bit                           132 calls x 4096 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## run config

- **schema_version**: `3`
- **generated_at**: `2026-09-02T19:02:26Z`
- **tasks**: `44`
- **hidden_k**: `3`
- **visible_k**: `1`
- **max_tokens**: `4096`
- **temperature**: `1.0`
- **seed_derivation**: `sha256(prompt + sample_index)[0,8]`
- **concurrency**: `{"qwen3.6-35b-a3b-4bit":1}`
- **providers**: `{"qwen3.6-35b-a3b-4bit":"studio"}`
- **extra_body**: `{"qwen3.6-35b-a3b-4bit":{"reasoning_effort":"none"}}`

system prompt (schema 3+; v2 runs had none, so their rates are not poolable with these):

```text
You are completing a self-contained Ruby coding task.

Reply with exactly one fenced Ruby code block containing the complete
implementation, and nothing else - no prose before or after it.

You have no tools, no filesystem access, and no shell. Do not emit
tool calls; write the code directly.
```

## qwen3.6-35b-a3b-4bit / hidden

### authored

- scored: 114, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 0.7105263157894737 (tasks_counted: 38)
- wall_clock: total 199.4s, median/sample 1.2s, per_task_passed 5.9s
- pass_at_3: 0.8947368421052632 (tasks_counted: 38)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 3 | 1 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 3 | {} |
| credits_reel_contributor_chain | 3 | 3 | {} |
| delegating_proxy_method_object | 3 | 2 | {} |
| delivery_audited_route_block | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 0 | {} |
| ensure_return_swallows_exception | 3 | 2 | {} |
| enumerable_sparse_array | 3 | 3 | {} |
| enumerator_lazy_short_circuit | 3 | 2 | {} |
| enumerator_without_block_countdown | 3 | 1 | {} |
| eql_hash_distance_point | 3 | 0 | {} |
| event_broadcaster_duck_protocol | 3 | 3 | {} |
| exception_retrier | 3 | 2 | {} |
| expense_tracker_injected_rounding | 3 | 1 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 1 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 2 | {} |
| metaprogramming_open_record | 3 | 3 | {} |
| mood_board_owned_swatches | 3 | 1 | {} |
| numeric_coerce_fraction | 3 | 0 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |
| protected_interval_overlap | 3 | 2 | {} |
| reading_circle_member_enumeration | 3 | 2 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| shipment_alert_recipient_protocol | 3 | 3 | {} |
| shipping_quote_polymorphic_packages | 3 | 3 | {} |
| string_attr_parser | 3 | 1 | {} |
| struct_vector | 3 | 3 | {} |
| tallying_key_store_fetch_contract | 3 | 3 | {} |
| temperature_report_injected_scale | 3 | 3 | {} |
| to_proc_lookup | 3 | 3 | {} |
| weight_unit_partial_order | 3 | 1 | {} |

### sourced

- scored: 18, non_score: 0
- non_scores_by_reason: {}
- pass_at_1: 1.0 (tasks_counted: 6)
- wall_clock: total 31.0s, median/sample 1.3s, per_task_passed 5.2s
- pass_at_3: 1.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 3 | 3 | {} |
| cache_sweep_packed_entries | 3 | 3 | {} |
| counter_override_dup_clone | 3 | 3 | {} |
| gauge_reading_exact_sum | 3 | 3 | {} |
| stock_count_float_difference | 3 | 3 | {} |
| text_squash_no_mutation | 3 | 3 | {} |
