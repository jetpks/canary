# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  nemotron-3-super                               132 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## run config

- **schema_version**: `3`
- **generated_at**: `2026-09-01T21:13:47Z`
- **tasks**: `44`
- **hidden_k**: `3`
- **visible_k**: `1`
- **max_tokens**: `16384`
- **temperature**: `1.0`
- **seed_derivation**: `sha256(prompt + sample_index)[0,8]`
- **concurrency**: `{"nemotron-3-super":1}`
- **providers**: `{"nemotron-3-super":"studio"}`
- **extra_body**: `{"nemotron-3-super":{"reasoning_effort":"none"}}`

system prompt (schema 3+; v2 runs had none, so their rates are not poolable with these):

```text
You are completing a self-contained Ruby coding task.

Reply with exactly one fenced Ruby code block containing the complete
implementation, and nothing else - no prose before or after it.

You have no tools, no filesystem access, and no shell. Do not emit
tool calls; write the code directly.
```

## nemotron-3-super / hidden

### authored

- scored: 45, non_score: 69
- non_scores_by_reason: {extractor_refusal: 69}
- pass_at_1: 0.8209876543209877 (tasks_counted: 27)
- wall_clock: total 374.3s, median/sample 2.6s, per_task_passed 16.3s
- pass_at_3: 1.0 (tasks_counted: 6)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 3 | {} |
| block_safe_caller | 2 | 2 | {extractor_refusal: 1} |
| case_match_temperature_band | 1 | 1 | {extractor_refusal: 2} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 0 | 0 | {extractor_refusal: 3} |
| coordinate_destructure_splat | 0 | 0 | {extractor_refusal: 3} |
| credits_reel_contributor_chain | 2 | 2 | {extractor_refusal: 1} |
| delegating_proxy_method_object | 1 | 1 | {extractor_refusal: 2} |
| delivery_audited_route_block | 0 | 0 | {extractor_refusal: 3} |
| distance_coerce_subtraction | 0 | 0 | {extractor_refusal: 3} |
| ensure_return_swallows_exception | 3 | 3 | {} |
| enumerable_sparse_array | 2 | 1 | {extractor_refusal: 1} |
| enumerator_lazy_short_circuit | 3 | 3 | {} |
| enumerator_without_block_countdown | 1 | 1 | {extractor_refusal: 2} |
| eql_hash_distance_point | 1 | 1 | {extractor_refusal: 2} |
| event_broadcaster_duck_protocol | 1 | 1 | {extractor_refusal: 2} |
| exception_retrier | 2 | 0 | {extractor_refusal: 1} |
| expense_tracker_injected_rounding | 0 | 0 | {extractor_refusal: 3} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 0 | 0 | {extractor_refusal: 3} |
| keyword_splat_invoker | 2 | 2 | {extractor_refusal: 1} |
| ledger_freeze_dup_clone | 0 | 0 | {extractor_refusal: 3} |
| metaprogramming_open_record | 1 | 0 | {extractor_refusal: 2} |
| mood_board_owned_swatches | 1 | 1 | {extractor_refusal: 2} |
| numeric_coerce_fraction | 1 | 0 | {extractor_refusal: 2} |
| peekable_token_stream | 1 | 1 | {extractor_refusal: 2} |
| playlist_dup_clone_singleton | 0 | 0 | {extractor_refusal: 3} |
| protected_interval_overlap | 1 | 1 | {extractor_refusal: 2} |
| reading_circle_member_enumeration | 1 | 1 | {extractor_refusal: 2} |
| shadowed_constant_circle | 1 | 1 | {extractor_refusal: 2} |
| shipment_alert_recipient_protocol | 1 | 1 | {extractor_refusal: 2} |
| shipping_quote_polymorphic_packages | 1 | 1 | {extractor_refusal: 2} |
| string_attr_parser | 3 | 2 | {} |
| struct_vector | 1 | 0 | {extractor_refusal: 2} |
| tallying_key_store_fetch_contract | 0 | 0 | {extractor_refusal: 3} |
| temperature_report_injected_scale | 0 | 0 | {extractor_refusal: 3} |
| to_proc_lookup | 2 | 2 | {extractor_refusal: 1} |
| weight_unit_partial_order | 0 | 0 | {extractor_refusal: 3} |

### sourced

- scored: 4, non_score: 14
- non_scores_by_reason: {extractor_refusal: 14}
- pass_at_1: 1.0 (tasks_counted: 2)
- wall_clock: total 76.4s, median/sample 2.9s, per_task_passed 38.2s
- pass_at_3: 1.0 (tasks_counted: 1)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 0 | 0 | {extractor_refusal: 3} |
| cache_sweep_packed_entries | 3 | 3 | {} |
| counter_override_dup_clone | 0 | 0 | {extractor_refusal: 3} |
| gauge_reading_exact_sum | 0 | 0 | {extractor_refusal: 3} |
| stock_count_float_difference | 0 | 0 | {extractor_refusal: 3} |
| text_squash_no_mutation | 1 | 1 | {extractor_refusal: 2} |
