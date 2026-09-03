# Canary eval sweep

actual spend (from recorded token usage x price table): $0.0000

spend guard cap derivation:
  qwen3.6-35b-a3b-8bit                           132 calls x 16384 x $0.00000000 = $0.0000
  worst case sum: $0.0000
  cap (3x worst case, rounded up): $0

## qwen3.6-35b-a3b-8bit / hidden

### authored

- scored: 0, non_score: 114
- non_scores_by_reason: {transport_error: 114}
- pass_at_1: nil (tasks_counted: 0)
- wall_clock: total 0.9s, median/sample 0.0s, per_task_passed nils
- pass_at_3: nil (tasks_counted: 0)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| block_memoizer | 0 | 0 | {transport_error: 3} |
| block_safe_caller | 0 | 0 | {transport_error: 3} |
| case_match_temperature_band | 0 | 0 | {transport_error: 3} |
| character_safe_truncator | 0 | 0 | {transport_error: 3} |
| comparable_money | 0 | 0 | {transport_error: 3} |
| coordinate_destructure_splat | 0 | 0 | {transport_error: 3} |
| credits_reel_contributor_chain | 0 | 0 | {transport_error: 3} |
| delegating_proxy_method_object | 0 | 0 | {transport_error: 3} |
| delivery_audited_route_block | 0 | 0 | {transport_error: 3} |
| distance_coerce_subtraction | 0 | 0 | {transport_error: 3} |
| ensure_return_swallows_exception | 0 | 0 | {transport_error: 3} |
| enumerable_sparse_array | 0 | 0 | {transport_error: 3} |
| enumerator_lazy_short_circuit | 0 | 0 | {transport_error: 3} |
| enumerator_without_block_countdown | 0 | 0 | {transport_error: 3} |
| eql_hash_distance_point | 0 | 0 | {transport_error: 3} |
| event_broadcaster_duck_protocol | 0 | 0 | {transport_error: 3} |
| exception_retrier | 0 | 0 | {transport_error: 3} |
| expense_tracker_injected_rounding | 0 | 0 | {transport_error: 3} |
| hash_default_proc_tally | 0 | 0 | {transport_error: 3} |
| identity_registry | 0 | 0 | {transport_error: 3} |
| keyword_splat_invoker | 0 | 0 | {transport_error: 3} |
| ledger_freeze_dup_clone | 0 | 0 | {transport_error: 3} |
| metaprogramming_open_record | 0 | 0 | {transport_error: 3} |
| mood_board_owned_swatches | 0 | 0 | {transport_error: 3} |
| numeric_coerce_fraction | 0 | 0 | {transport_error: 3} |
| peekable_token_stream | 0 | 0 | {transport_error: 3} |
| playlist_dup_clone_singleton | 0 | 0 | {transport_error: 3} |
| protected_interval_overlap | 0 | 0 | {transport_error: 3} |
| reading_circle_member_enumeration | 0 | 0 | {transport_error: 3} |
| shadowed_constant_circle | 0 | 0 | {transport_error: 3} |
| shipment_alert_recipient_protocol | 0 | 0 | {transport_error: 3} |
| shipping_quote_polymorphic_packages | 0 | 0 | {transport_error: 3} |
| string_attr_parser | 0 | 0 | {transport_error: 3} |
| struct_vector | 0 | 0 | {transport_error: 3} |
| tallying_key_store_fetch_contract | 0 | 0 | {transport_error: 3} |
| temperature_report_injected_scale | 0 | 0 | {transport_error: 3} |
| to_proc_lookup | 0 | 0 | {transport_error: 3} |
| weight_unit_partial_order | 0 | 0 | {transport_error: 3} |

### sourced

- scored: 0, non_score: 18
- non_scores_by_reason: {transport_error: 18}
- pass_at_1: nil (tasks_counted: 0)
- wall_clock: total 0.1s, median/sample 0.0s, per_task_passed nils
- pass_at_3: nil (tasks_counted: 0)

| task | scored | passed | non_score_reasons |
|---|---|---|---|
| attribute_bag_hash_equality | 0 | 0 | {transport_error: 3} |
| cache_sweep_packed_entries | 0 | 0 | {transport_error: 3} |
| counter_override_dup_clone | 0 | 0 | {transport_error: 3} |
| gauge_reading_exact_sum | 0 | 0 | {transport_error: 3} |
| stock_count_float_difference | 0 | 0 | {transport_error: 3} |
| text_squash_no_mutation | 0 | 0 | {transport_error: 3} |
