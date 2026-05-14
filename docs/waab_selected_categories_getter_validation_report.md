# WAABProperties selected categories getter validation

## Boolean question
Not all candidates are boolean. Selected categories total `6772`: `bool`=5372, `number`=842, `unknown`=494, `string`=64.

## Confirmed getter surface
SharedModules(3): `boolForKey:defaultValue:`=4, `stringForKey:defaultValue:`=4, `integerForKey:defaultValue:`=4, `doubleForKey:defaultValue:`=4
WhatsApp main executable: `boolForKey:defaultValue:`=2, `stringForKey:defaultValue:`=2, `integerForKey:defaultValue:`=2, `doubleForKey:defaultValue:`=1

## Category summary
| category | total | bool | number | string | unknown | exact key present in WhatsApp exe | policy summary |
|---|---:|---:|---:|---:|---:|---:|---|
| business | 250 | 204 | 18 | 0 | 28 | 30 | typed-override-after-runtime-hit:18; toggle-allowed-after-runtime-hit:204; observe-first:28 |
| calls | 197 | 122 | 60 | 0 | 15 | 42 | toggle-allowed-after-runtime-hit:122; observe-first:15; typed-override-after-runtime-hit:60 |
| dogfood_employee_internal | 24 | 24 | 0 | 0 | 0 | 6 | toggle-allowed-after-runtime-hit:19; toggle-allowed-dogfood-gate:4; observe-first:1 |
| experimentation | 62 | 24 | 9 | 3 | 26 | 12 | observe-first:26; toggle-allowed-after-runtime-hit:24; typed-override-after-runtime-hit:12 |
| groups_communities | 168 | 131 | 27 | 0 | 10 | 46 | typed-override-after-runtime-hit:27; toggle-allowed-after-runtime-hit:131; observe-first:10 |
| keychain_identity | 2 | 2 | 0 | 0 | 0 | 0 | toggle-allowed-after-runtime-hit:2 |
| liquid_glass | 35 | 9 | 1 | 25 | 0 | 4 | toggle-allowed-after-runtime-hit:9; typed-override-after-runtime-hit:26 |
| media | 887 | 597 | 209 | 11 | 70 | 207 | typed-override-after-runtime-hit:220; observe-first:70; toggle-allowed-after-runtime-hit:597 |
| messaging | 986 | 643 | 209 | 8 | 126 | 213 | typed-override-after-runtime-hit:217; toggle-allowed-after-runtime-hit:643; observe-first:126 |
| network_sync | 144 | 108 | 25 | 0 | 11 | 38 | typed-override-after-runtime-hit:25; toggle-allowed-after-runtime-hit:108; observe-first:11 |
| status_stories | 586 | 461 | 79 | 1 | 45 | 212 | toggle-allowed-after-runtime-hit:461; typed-override-after-runtime-hit:80; observe-first:45 |
| ui_ux | 149 | 128 | 12 | 2 | 7 | 30 | toggle-allowed-after-runtime-hit:128; typed-override-after-runtime-hit:14; observe-first:7 |
| uncategorized | 3282 | 2919 | 193 | 14 | 156 | 560 | observe-first:156; typed-override-after-runtime-hit:207; toggle-allowed-after-runtime-hit:2919 |

## High-value samples per category
### business
- `biz_ai_agent_consumer_merge_tos_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `biz_api_payment_links_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `carousel_product_square_preview_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_business_solution_discovery_business_information_forwarding` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_business_solution_discovery_p2p_sharing_logging` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_biz_simple_signal_enabled_int` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_product_surface_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `meta_catalog_linking_m2_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `meta_catalog_linking_m3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `payments_upi_flex_order_details_non_catalog_items_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_business_broadcast_pro_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_catalog_action_load_event_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_custom_url_display_v2_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=2, policy `toggle-allowed-after-runtime-hit`
- `smb_custom_url_qpl_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=2, policy `toggle-allowed-after-runtime-hit`
- `smb_payment_links_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_payment_links_seller_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_profile_action_load_event_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_username_enable_account_linking_flow` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smb_verified_badge_parity_changes_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smbi_business_broadcast_campaign_syncd_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smbi_pm_insights_syncd_mutation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smbi_premium_broadcast_cta_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smbi_premium_broadcast_deeplink_handling_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smbi_premium_broadcast_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=2, policy `toggle-allowed-after-runtime-hit`
- `smbi_premium_broadcast_nse_send_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `smbi_subscription_content_models_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `waffle_companions_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `waffle_enabled_for_unlinked_users` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `waffle_foa_to_wa_linking_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `waffle_mobile_companions_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `allow_other_biz` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `allowed_biz_list` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `foa_to_waffle_linking_eligibility` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_poster_biz` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_smb_user_eligible_for_business_search` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_smb_user_eligible_for_meta_verified` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_smb_user_has_created_ctwa_ad_client_filter` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_smb_user_has_draft_ad` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_smb_user_has_sufficient_internet_connection` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_smb_user_is_eligible_for_ad_resolve_payment` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`

### calls
- `ai_voice_fab_call_history_entry_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `allow_lid_contacts_calling` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `calling_voicemail_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_active_linked_group_call_add_participants` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_bot_call_skip_presentation_animation` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_call_link_random_id_logging` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_call_transfer_notification` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_calling_camera_brightness_processor` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_calling_phone_number_privacy` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_calling_username` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_callkit_generic_handling` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_client_linked_group_call_notification_mute` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_client_linked_group_call_notification_push_config` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_crash_log_call_test_bucket_id_list` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_fallback_to_cellular_option_for_call_intent` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_group_call_invite_close_the_loop` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_in_call_more_menu_ios` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_in_call_picker_merged_list` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_ios_call_intent_availability_fix` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_missed_notification_for_auto_joining_call` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_new_call_invite` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_new_call_link_representation` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_pending_call_mute_button_fix_ios` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_random_scheduled_id_for_call_links` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_schedule_call_from_calls_tab` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_scheduled_calls_v2_entry_points_creation` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_two_person_call_link_context_menu_fix` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_guest_calling_representation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_new_call_list_banner_is_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_wabi_enable_call_permission_settings_on_profile` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_incoming_call_ui_action_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `meta_ai_voice_call_trigger_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `should_log_user_mic_mode_ios_calling` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `unanswered_call_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `username_call_search_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `calling_rust_migration_bitmap` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `calling_rust_migration_incoming_ack_stanza_bitmap` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `calling_rust_migration_incoming_stanza_bitmap` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `call_aec_mode` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`
- `call_agc_mode` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`

### dogfood_employee_internal
- `graphQLEmployeeC1Disabled` — type `bool`, getter `graphQLEmployeeC1Disabled`, exe=1, policy `toggle-allowed-dogfood-gate`
- `username_dogfooding_pn_privacy_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `isInternalUser` — type `bool`, getter `isInternalUser`, exe=1, policy `toggle-allowed-dogfood-gate`
- `is_internal_tester` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `visible_message_drop_placeholder_enabled_internal_only` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `isMetaEmployeeOrInternalTester` — type `bool`, getter `isMetaEmployeeOrInternalTester`, exe=1, policy `toggle-allowed-dogfood-gate`
- `dogfooder_diagnostics` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_internal` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_md_syncd_dogfooding_feature_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_meta_employee_or_internal_tester` — type `bool`, getter `is_meta_employee_or_internal_tester`, exe=0, policy `toggle-allowed-dogfood-gate`
- `md_syncd_dogfooding_feature` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `md_syncd_dogfooding_feature_usage` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `username_dogfooding_pn_privacy_periodic_conversion_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_internal_hall_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_internal_entry_point_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `map_pages_internal` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `mci_handle_notification_internal_invoke_callback` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `mci_handle_notification_internal_sessionless_invoke_callback` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `mci_handle_notification_internal_sessionless_invoke_registered_callback` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `md_internal_app_log` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `mobile_config_debug_internal` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `tam_transport_messages_internal_text_send` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wa_ios_internal_linked_profile_cache` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `zero-dogfood-device-id` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `observe-first`

### experimentation
- `br_payments_order_detail_payment_link_iab_experiment_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `demystifying_history_sync_rollout_phase` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `fb_experiment_for_link_preview_m3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_experimental` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `status_rollout_privacy_list_changes` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_foa_admin_id_startup_experiments.cache_text_kit_layout` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ios_foa_admin_id_startup_experiments.cache_text_kit_size` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `wa_growth_offline_abprops_device_country_filter` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ai_experiment_graphql_config` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`
- `ai_imagine_icebreakers_experimentation` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=2, policy `observe-first`
- `inapp_signup_agm_cta_experiment` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`
- `ios_suma_experiment_aa` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`
- `enable_data_quality_experiment` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `demystifying_history_sync_rollout_phase_two_or_more` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `gphotos_playback_rollout_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `group_status_group_level_experiment_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `hide_link_device_button_release_rollout_universe` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_foa_admin_id_startup_experiments.use_uiview_dock_animations` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_kvs_cql_reads_rollout` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_rollout_ca_tos_reg_experiment` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_rollout_quebec_tos_reg_universe` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_status_infra_read_rollout_period_hours` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_feature_flag_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wa_link_fb_experiment_measurement_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `waios_mc_rollout_use_callsite_default` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `waios_rollout_sessionbased_mc` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wamo_exp_ios_wave_4_pp_tos_trigger_3_offline_rollout_v1` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wamo_exp_wave_2b_pp_tos_trigger_3_offline_rollout` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wamo_exp_wave_2b_pp_tos_trigger_3_offline_rollout_exp` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wamo_exp_wave_4_pp_tos_trigger_3_offline_rollout` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `wamo_exp_wave_4_pp_tos_trigger_3_offline_rollout_exp` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_foa_admin_id_startup_experiments` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_foa_admin_id_startup_experiments.bottom_sheet_pop_to_uiview_animation` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `mobileconfig_freshinstall_track_version` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `traffanon_experiment_intervals` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `wa_growth_offline_abprops_device_country_filter_ios_aa_experiment_v1` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `wa_growth_offline_abprops_device_country_filter_ios_aa_universe` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `experiment_key` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `mobileconfig_first_user_session_id` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `override_experiment` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`

### groups_communities
- `not_allow_non_admin_sub_group_creation` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `add_member_group_ranking_allow_non_contact` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_genai_imagine_intent_group_profile_picture_v3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_meta_ai_null_state_capability_entrypoint_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_meta_ai_null_state_overflow_menu_entrypoint_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_multi_modal_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_participation_add_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_participation_add_tee_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_participation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_participation_send_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_participation_tee_gs_auth_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_send_mentioned_pushname_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_group_tee_streaming_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `br_payments_pix_groups_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `br_payments_pix_groups_enabled_for_broadcast` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `br_payments_pix_groups_enabled_for_group_type` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `capi_groups_infra_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `empty_group_creation_enabled_int` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_scams_group_engagment_logging` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_invite_contacts_count_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_member_updates_usernames_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `interop_group_messaging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_modal_splitview_contact_group_info_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `non_anonymous_group_participation_enable` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `pnh_cag_disable_polls_group_size` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `privacy_settings_group_add_lid_migration_enable` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `push_name_in_community_groups_picker_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `username_group_learning_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `username_group_mutation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `add_member_group_picker_frequent_section_limit` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ai_group_participation_tee_request_debouncing_interval` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `bug_reporting_peer_log_max_group_size` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `community_announcement_group_size_limit` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `default_sub_group_admin_add` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `group_creation_frequent_section_limit` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `group_invite_contacts_count_killswitch` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `group_picker_suggestion_timeout` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `interop_group_size_limit` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ios_community_nesting_subgroup_db_migration` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ios_reset_inactive_group_migration_state_if_needed` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`

### keychain_identity
- `ios_signal_nse_keychain_reload_on_offd_pop_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_signal_reload_keychain_on_regid_mismatch_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`

### liquid_glass
- `ai_meta_ai_glasses_at_contact_info_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_liquid_glass_media_header_min_cut_off_device_width` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_status_dismiss_when_locked` — type `string`, getter `stringForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_media_m0` — type `string`, getter `stringForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_chat_top_bar_m2_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_liquid_glass_enable_new_chatbar_ux` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_liquid_glass_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_liquid_glass_media_editor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ai_meta_ai_glasses_at_contact_info_banner_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_sent_from_glasses` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_user_has_meta_glasses_connected` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `whatsapp_user_has_used_meta_glasses_features_in_last_x_days` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ios_liquid_glass_fix_context_menu_on_disappear` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_context_menu_transition_safety` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_feedback_generator_retain` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_forward_picker_share_extension_crash` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_multisend_preview_dealloc` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_tabbar_badge_offthread` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_uiimage_trait_collection` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_updates_table_dynamic_color` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fix_weak_hashtable_snapshot` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_fixes_for_older_ios` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_larger_composer` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_launched` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m1` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m_1_5` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m_1_5_context_menu` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m_2_action_tile` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m_2_chips` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m_2_lightweight_dialogs` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_m_2_text_layout` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_reduce_transparency` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_workaround_attachment_tray` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_workaround_hides_bottombar` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`
- `ios_liquid_glass_workaround_topbar_appearance` — type `string`, getter `stringForKey:defaultValue:`, exe=0, policy `typed-override-after-runtime-hit`

### media
- `add_status_tile_center_profile_photo_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `address_book_image_fallback_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_access_token_migration_media_editor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_access_token_migration_stickers_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_imagine_me_one_image_onboarding_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_genai_imagine_intent_media_viewer_v3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_hatch_video_upload_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_expand_in_media_editor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_expand_in_media_editor_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_languages_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_m1_edit_buttons_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_m1_edit_buttons_in_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_progress_loading_indicator_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_progress_loading_indicator_in_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_in_media_editor_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_video_edit_in_media_editor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_video_edit_in_media_editor_in_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_media_captions_in_channels_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_media_editor_3p_model_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_meta2_video_input_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_metabot_document_ocr_image_conversion_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_forward_media_sending_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_multi_media_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_ur_imagine_video_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_ur_media_fetch_coalescing_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_stickers_rebranding_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_voice_image_input_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_voice_live_video_input_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_voice_live_video_pip_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `album_v2_sender_delay_dismiss_media_picker_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `aura_painted_door_stickers_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `aura_stickers_overlay_animation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `bug_reporting_upload_peer_log_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channel_media_viewer_improvements_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channel_photo_poll_receiver_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channel_status_question_stickers_consumption_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_device_storage_clear_media_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_expired_media_improvements_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_ios_missing_backup_media_fix_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`

### messaging
- `ai_bot_channel_threading_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_chat_view_controller_subclass_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_integration_history_sync_pre_chatd_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_list_search_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_open_time_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_thread_capability_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_threads_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_threads_infra_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_threads_multiplayer_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_threads_pin_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_threads_recent_chats_widget_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_chat_threads_side_sheet_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_fab_chat_list_refactor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_genai_imagine_intent_chat_theme_v3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_genai_imagine_intent_chat_wallpaper_v3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_hatch_integration_history_sync_pre_chatd_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intent_ptt_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intent_v3_ptt_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_system_message_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_mata_ai_chat_composer_improvements_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_meta_ai_chat_ui_top_navigation_parity_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_new_chat_surface_meta_ai_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rewrite_in_edit_message_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_c50_promotion_in_message_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_message_long_press_log_events_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_message_signature_verification_on_receive_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_thread_surfing_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_side_chat_contextual_suggestions_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_side_chat_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_side_chat_image_creation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_side_chat_search_starter_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_side_chat_summarization_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_side_chat_writing_help_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_tos_reset_on_message_nack_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_voice_mmc_audio_output_routing_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_voice_ptt_coexistence_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `biz_ai_agent_thread_status_history_sync_ios_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `bonsai_chat_list_entry_point_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `bonsai_ptt_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `bot_proactive_messages_control_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`

### network_sync
- `enable_tigon_mns_qpl_ios` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_tigon_mns_bug_report_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_tigon_mns_fizz_mobile_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_tigon_mns_pqc_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `async_mms_thumb_generation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `device_capabilities_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_generating_new_syncd_key_proactively_if_missing_on_primary` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_syncd_debug_data_in_patch` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_can_sync_resume_set_to_false_when_logout` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_coex_remove_onboarding_syncd_deps_enable` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_loom_core.disable_separate_blackbox_async` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `kmp_syncd_engine_crypto_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `kmp_syncd_engine_outgoing_processor_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `lists_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `md_syncd_external_web_beta_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `md_syncd_primary_version_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `order_details_payment_instructions_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `orion_usync_allow_mutation_attribute` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `out_contact_sync_primary_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `payment_tos_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `payments_br_pix_phase_1_seller_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `settings_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `sg_enable_previous_id_in_contact_sync` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `sg_use_hmac_in_contact_sync` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `syncd_key_max_use_days` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `username_contact_allow_lid_contact_storage_with_usync` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `username_contact_syncd_companion_creation_support_enable` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `username_contact_syncd_support_enable` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `wa_nct_token_syncd_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `web_link_preview_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `sg_contact_sync_prefetch_expiration_seconds` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `syncd_additional_mutations_count` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `syncd_critical_contacts_limit` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `syncd_inline_mutations_max_count` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `syncd_patch_inline_payload_max_size_in_kb` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `syncd_patch_protobuf_max_size` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `syncd_wait_for_key_timeout_days` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ai_tee_fetch_config_using_tigon_ios` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`
- `disable_sync` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_network_change` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`

### status_stories
- `add_status_bolder_tile_entrypoint_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_genai_imagine_intent_status_v3_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intent_3p_model_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intents_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intents_status_mimicry_design_update_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intents_status_mimicry_receiver_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_intents_status_mimicry_sender_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_ur_embedded_status_view_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `allow_lid_contacts_status` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channel_poll_status_card_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channel_status_consumption_music_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channel_status_creation_music_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_admin_profiles_forwarding_to_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_albums_v2_forwarding_to_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_ptv_forwarding_to_status_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `demystifying_history_sync_ui_on_sync_progress_view_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_reasoning_status` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `fmx_history_sync_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_info_redesign_group_status_tile_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_creation_updates_tab_entrypoint_disabled_with_no_groups` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_enable_nux_new_badge` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_enable_nux_tooltip` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_forward_to_channels_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_group_level_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `group_status_receiver_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `history_sync_primary_full_sync_on_cellular_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `hsm_tag_in_history_sync_serialization_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_history_sync_pn_to_lid_mappings_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_status_audience_ranker_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_status_db_revoke_ack_update_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_status_ranking_combined_fetch_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_status_viewer_fix_pinch_zoom_with_caption_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_background_refresh_status_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_contacts_permission_authorization_status_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_group_status` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_group_status_badge_tracking_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_group_status_opt_in_notification_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_status_opt_in_notification_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_status_type_set` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`

### ui_ux
- `ai_hatch_integration_tab_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_meta_ai_in_app_tab_main_gate_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_metabot_command_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_psi_ux_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rewrite_default_tab_mitigation_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rewrite_in_context_menu_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_structured_response_truncated_table_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_tables_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_tab_glyph_icon_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_tab_perf_optimizations_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `channels_pinning_nudge_updates_tab_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `communities_remove_from_app_tab_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `context_menu_keyboard_fix_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_ban_appeals_ux_voluntary_education` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `enable_more_menu_in_vc` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `interop_client_ux_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_linked_devices_empty_states_ui_refresh_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_reaction_keyboard_uilabel_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `new_number_not_on_whatsapp_dialog_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `newsletter_forward_counter_ui_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `payments_india_account_recovery_inprogress_dialog_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `payments_selection_ui_updates_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `should_use_select_multiple_context_menu` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `view_replies_follow_up_ui_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `wamo_privacy_tos_show_channels_nux_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `wb_standard_layout_enabled_ios` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `xfam_lg_quick_sends_attribution_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_imagine_me_bottom_sheet_retake_nux_show_count` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `channels_ios_updates_tab_prefetch_max_hours_since_last_visit` — type `number`, getter `integerForKey:defaultValue:, doubleForKey:defaultValue:`, exe=1, policy `typed-override-after-runtime-hit`
- `ai_meta_ai_in_app_tab_screen_type` — type `unknown`, getter `boolForKey:defaultValue:, stringForKey:defaultValue:`, exe=1, policy `observe-first`
- `integrity_analysis_result_table` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `integrity_analysis_result_table_crc` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_external_build` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `is_required` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `quic_can_read` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `uiqr_runtime_detection_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ai_conversation_starter_in_null_state_card_view_ui_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ai_home_in_tab_main_gate_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ai_ios_rich_response_new_container_stack_view_layout_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`
- `ai_rich_response_structured_response_table_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=0, policy `toggle-allowed-after-runtime-hit`

### uncategorized
- `auto_add_disabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `can_appeal` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `can_auto_file` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `evolve_about_m1_receiver_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `has_next_page` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ios_batch_prefetch_relationships_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_authorized_agent` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_available` — type `bool`, getter `boolForKey:defaultValue:`, exe=2, policy `toggle-allowed-after-runtime-hit`
- `is_default` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_eligible` — type `bool`, getter `boolForKey:defaultValue:`, exe=2, policy `toggle-allowed-after-runtime-hit`
- `is_first_wave` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_hidden` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_international_pay_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_mapper_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_meta_created` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_offered` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_pando` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_platform_changed` — type `bool`, getter `boolForKey:defaultValue:`, exe=4, policy `toggle-allowed-after-runtime-hit`
- `is_popular` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_registered` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_sanctioned` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_sub_impression` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_success` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_verified` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `is_viewed_in_landscape` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `not_allow_admin_reports` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `suma_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `use_case` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `acp_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `admin_profiles_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_abft_logging_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_ac_shared_memories_enabled_ios` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_access_token_migration_imagine_intents_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_access_token_migration_imagine_intents_genai_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_account_linking_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_agentic_planning_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_imagine_me_auto_capture_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_imagine_me_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_imagine_me_onboarding_without_spark_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
- `ai_bot_integration_enabled` — type `bool`, getter `boolForKey:defaultValue:`, exe=1, policy `toggle-allowed-after-runtime-hit`
