# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.8-flash-next-oq3                         132 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## qwen3.8-flash-next-oq3 / hidden

### authored

- scored: 109, non_score: 5
- non_scores_by_reason: {extractor_refusal: 4, premature_stop: 1}
- pass_at_1: 0.8289473684210527 (tasks_counted: 38)
- pass_at_3: 0.9117647058823529 (tasks_counted: 34)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 3 | 2 | {} |
| block_safe_caller | 3 | 3 | {} |
| case_match_temperature_band | 3 | 3 | {} |
| character_safe_truncator | 3 | 3 | {} |
| comparable_money | 3 | 3 | {} |
| coordinate_destructure_splat | 3 | 2 | {} |
| credits_reel_contributor_chain | 3 | 3 | {} |
| delegating_proxy_method_object | 3 | 2 | {} |
| delivery_audited_route_block | 3 | 3 | {} |
| distance_coerce_subtraction | 3 | 0 | {} |
| ensure_return_swallows_exception | 3 | 2 | {} |
| enumerable_sparse_array | 1 | 1 | {extractor_refusal: 2} |
| enumerator_lazy_short_circuit | 3 | 2 | {} |
| enumerator_without_block_countdown | 2 | 2 | {premature_stop: 1} |
| eql_hash_distance_point | 3 | 3 | {} |
| event_broadcaster_duck_protocol | 3 | 3 | {} |
| exception_retrier | 3 | 2 | {} |
| expense_tracker_injected_rounding | 3 | 3 | {} |
| hash_default_proc_tally | 3 | 3 | {} |
| identity_registry | 3 | 3 | {} |
| keyword_splat_invoker | 3 | 3 | {} |
| ledger_freeze_dup_clone | 3 | 2 | {} |
| metaprogramming_open_record | 3 | 0 | {} |
| mood_board_owned_swatches | 3 | 3 | {} |
| numeric_coerce_fraction | 3 | 2 | {} |
| peekable_token_stream | 3 | 3 | {} |
| playlist_dup_clone_singleton | 3 | 0 | {} |
| protected_interval_overlap | 3 | 3 | {} |
| reading_circle_member_enumeration | 3 | 3 | {} |
| shadowed_constant_circle | 3 | 3 | {} |
| shipment_alert_recipient_protocol | 3 | 3 | {} |
| shipping_quote_polymorphic_packages | 3 | 3 | {} |
| string_attr_parser | 2 | 2 | {extractor_refusal: 1} |
| struct_vector | 3 | 3 | {} |
| tallying_key_store_fetch_contract | 3 | 3 | {} |
| temperature_report_injected_scale | 3 | 3 | {} |
| to_proc_lookup | 3 | 2 | {} |
| weight_unit_partial_order | 2 | 1 | {extractor_refusal: 1} |

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
