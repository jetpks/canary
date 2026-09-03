# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  olmo-3-7b                                      132 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## run config

- **schema_version**: `3`
- **generated_at**: `2026-09-01T23:01:11Z`
- **tasks**: `44`
- **hidden_k**: `3`
- **visible_k**: `1`
- **max_tokens**: `16384`
- **temperature**: `1.0`
- **seed_derivation**: `sha256(prompt + sample_index)[0,8]`
- **concurrency**: `{"olmo-3-7b":1}`
- **providers**: `{"olmo-3-7b":"studio"}`
- **extra_body**: `{"olmo-3-7b":{}}`

system prompt (schema 3+; v2 runs had none, so their rates are not poolable with these):

```text
You are completing a self-contained Ruby coding task.

Reply with exactly one fenced Ruby code block containing the complete
implementation, and nothing else - no prose before or after it.

You have no tools, no filesystem access, and no shell. Do not emit
tool calls; write the code directly.
```

## olmo-3-7b / hidden

### authored

- scored: 57, non_score: 57
- non_scores_by_reason: {extractor_refusal: 47, premature_stop: 10}
- pass_at_1: 0.1904761904761905 (tasks_counted: 28)
- wall_clock: total 962.1s, median/sample 2.7s, per_task_passed 120.3s
- pass_at_3: 0.4 (tasks_counted: 10)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 0 | 0 | {extractor_refusal: 3} |
| block_safe_caller | 2 | 0 | {extractor_refusal: 1} |
| case_match_temperature_band | 1 | 0 | {extractor_refusal: 2} |
| character_safe_truncator | 1 | 0 | {extractor_refusal: 2} |
| comparable_money | 1 | 0 | {extractor_refusal: 2} |
| coordinate_destructure_splat | 0 | 0 | {extractor_refusal: 3} |
| credits_reel_contributor_chain | 2 | 2 | {extractor_refusal: 1} |
| delegating_proxy_method_object | 3 | 0 | {} |
| delivery_audited_route_block | 3 | 0 | {} |
| distance_coerce_subtraction | 2 | 0 | {extractor_refusal: 1} |
| ensure_return_swallows_exception | 2 | 0 | {extractor_refusal: 1} |
| enumerable_sparse_array | 0 | 0 | {extractor_refusal: 3} |
| enumerator_lazy_short_circuit | 0 | 0 | {premature_stop: 1, extractor_refusal: 2} |
| enumerator_without_block_countdown | 2 | 0 | {premature_stop: 1} |
| eql_hash_distance_point | 0 | 0 | {extractor_refusal: 3} |
| event_broadcaster_duck_protocol | 3 | 1 | {} |
| exception_retrier | 0 | 0 | {extractor_refusal: 3} |
| expense_tracker_injected_rounding | 1 | 0 | {premature_stop: 2} |
| hash_default_proc_tally | 2 | 1 | {extractor_refusal: 1} |
| identity_registry | 3 | 0 | {} |
| keyword_splat_invoker | 3 | 0 | {} |
| ledger_freeze_dup_clone | 3 | 0 | {} |
| metaprogramming_open_record | 1 | 0 | {extractor_refusal: 2} |
| mood_board_owned_swatches | 3 | 2 | {} |
| numeric_coerce_fraction | 2 | 0 | {extractor_refusal: 1} |
| peekable_token_stream | 2 | 0 | {extractor_refusal: 1} |
| playlist_dup_clone_singleton | 1 | 0 | {premature_stop: 2} |
| protected_interval_overlap | 3 | 0 | {} |
| reading_circle_member_enumeration | 1 | 1 | {extractor_refusal: 1, premature_stop: 1} |
| shadowed_constant_circle | 3 | 1 | {} |
| shipment_alert_recipient_protocol | 2 | 1 | {extractor_refusal: 1} |
| shipping_quote_polymorphic_packages | 3 | 3 | {} |
| string_attr_parser | 0 | 0 | {extractor_refusal: 3} |
| struct_vector | 0 | 0 | {extractor_refusal: 3} |
| tallying_key_store_fetch_contract | 1 | 0 | {extractor_refusal: 1, premature_stop: 1} |
| temperature_report_injected_scale | 0 | 0 | {extractor_refusal: 3} |
| to_proc_lookup | 1 | 0 | {extractor_refusal: 2} |
| weight_unit_partial_order | 0 | 0 | {extractor_refusal: 1, premature_stop: 2} |

### sourced

- scored: 8, non_score: 10
- non_scores_by_reason: {extractor_refusal: 9, premature_stop: 1}
- pass_at_1: 0.2 (tasks_counted: 5)
- wall_clock: total 92.8s, median/sample 3.4s, per_task_passed 92.8s
- pass_at_3: nil (tasks_counted: 0)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 1 | 1 | {extractor_refusal: 2} |
| cache_sweep_packed_entries | 2 | 0 | {premature_stop: 1} |
| counter_override_dup_clone | 2 | 0 | {extractor_refusal: 1} |
| gauge_reading_exact_sum | 2 | 0 | {extractor_refusal: 1} |
| stock_count_float_difference | 0 | 0 | {extractor_refusal: 3} |
| text_squash_no_mutation | 1 | 0 | {extractor_refusal: 2} |
