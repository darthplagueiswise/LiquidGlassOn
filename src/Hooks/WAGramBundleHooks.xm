// WAGramBundleHooks.xm
// Direct per-method hooks on WAABProperties for all visible WAGram bundles.
// MSHookMessageEx implementation; no Logos original-call macro.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

typedef BOOL (*WAGRWAABOrigBoolIMP)(id, SEL);

static NSMutableDictionary<NSString *, NSValue *> *gWAGRBundleOrig = nil;
static BOOL gWAGRBundleHooksInstalled = NO;

static BOOL WAGRBundleBoolHook(id self, SEL _cmd) {
    NSString *flag = NSStringFromSelector(_cmd);
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)];

    if ([v isEqualToString:@"on"]) return YES;
    if ([v isEqualToString:@"off"]) return NO;

    WAGRWAABOrigBoolIMP orig = NULL;
    NSValue *val = [gWAGRBundleOrig objectForKey:flag];
    if (val) orig = (WAGRWAABOrigBoolIMP)[val pointerValue];

    return orig ? orig(self, _cmd) : NO;
}

static void WAGRHookOneWAABBundleFlag(Class cls, const char *name) {
    if (!cls || !name || !*name) return;

    NSString *key = [NSString stringWithUTF8String:name];
    if ([gWAGRBundleOrig objectForKey:key]) return;

    SEL sel = sel_registerName(name);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    if (method_getNumberOfArguments(m) != 2) return;

    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    if (ret[0] != 'B' && ret[0] != 'c') return;

    IMP orig = NULL;
    MSHookMessageEx(cls, sel, (IMP)WAGRBundleBoolHook, &orig);
    if (orig) [gWAGRBundleOrig setObject:[NSValue valueWithPointer:(void *)orig] forKey:key];
}

extern "C" void WAGRBundleEnsureHooksInstalled(void) {
    if (gWAGRBundleHooksInstalled) return;
    gWAGRBundleHooksInstalled = YES;

    if (!gWAGRBundleOrig) gWAGRBundleOrig = [NSMutableDictionary dictionary];

    Class cls = NSClassFromString(@"WAABProperties");
    if (!cls) return;

    WAGRHookOneWAABBundleFlag(cls, "defense_mode_available");
    WAGRHookOneWAABBundleFlag(cls, "passkey_login");
    WAGRHookOneWAABBundleFlag(cls, "multiple_passkeys_delete_v2_enabled");
    WAGRHookOneWAABBundleFlag(cls, "username_suggestions_enabled");
    WAGRHookOneWAABBundleFlag(cls, "username_key_redesign_enabled");
    WAGRHookOneWAABBundleFlag(cls, "username_enabled_on_companion");
    WAGRHookOneWAABBundleFlag(cls, "username_call_search_enabled");
    WAGRHookOneWAABBundleFlag(cls, "username_group_mutation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "username_group_learning_enabled");
    WAGRHookOneWAABBundleFlag(cls, "username_future_proof_contact_creation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "allow_lid_contacts_privacy_settings");
    WAGRHookOneWAABBundleFlag(cls, "allow_lid_contacts_calling");
    WAGRHookOneWAABBundleFlag(cls, "allow_lid_contacts_status");
    WAGRHookOneWAABBundleFlag(cls, "allow_lid_contacts_broadcast");
    WAGRHookOneWAABBundleFlag(cls, "enable_calling_phone_number_privacy");
    WAGRHookOneWAABBundleFlag(cls, "enable_calling_username");
    WAGRHookOneWAABBundleFlag(cls, "ios_wabi_enable_username_migration");
    WAGRHookOneWAABBundleFlag(cls, "privacy_aware_secure_dl_logging_enabled");
    WAGRHookOneWAABBundleFlag(cls, "privacy_checkup");
    WAGRHookOneWAABBundleFlag(cls, "interop_client_ux_enabled");
    WAGRHookOneWAABBundleFlag(cls, "interop_contact_master_enabled");
    WAGRHookOneWAABBundleFlag(cls, "interop_group_messaging_enabled");
    WAGRHookOneWAABBundleFlag(cls, "interop_bootstrap_enabled");
    WAGRHookOneWAABBundleFlag(cls, "wa_interop_unified_inbox_enabled");
    WAGRHookOneWAABBundleFlag(cls, "is_interop_available_badge_banner_enabled");
    WAGRHookOneWAABBundleFlag(cls, "is_interop_new_3p_available_badge_banner_enabled");
    WAGRHookOneWAABBundleFlag(cls, "high_quality_link_preview_enabled");
    WAGRHookOneWAABBundleFlag(cls, "fb_experiment_for_link_preview_m3_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_privacy_formatter_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_translate_messages_enabled");
    WAGRHookOneWAABBundleFlag(cls, "evolve_about_m1_enabled");
    WAGRHookOneWAABBundleFlag(cls, "evolve_about_m1_receiver_enabled");
    WAGRHookOneWAABBundleFlag(cls, "evolve_about_m1_receiver_for_new_surfaces_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ptt_transcription_manual_message_button_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_intents_chat_themes_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_genai_imagine_intent_chat_theme_v3_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_intents_chat_wallpaper_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_genai_imagine_intent_chat_wallpaper_v3_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_in_media_editor_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_expand_in_media_editor_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_extend_disappearing_mode_with_ephemerality_disabled_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_inbox_pinned_chats_in_context_menu_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_storage_management_clear_chat_entrypoint_context_menu_enabled");
    WAGRHookOneWAABBundleFlag(cls, "chat_list_drop_interaction_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_accordion_tableview_exception_on_delete_fix_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_chats_tab_null_state_search_bar_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_chatlist_bundle_pinned_chat_move");
    WAGRHookOneWAABBundleFlag(cls, "rename_other_contacts_to_contacts_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_list_search_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_infra_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_thread_capability_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_multiplayer_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_pin_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_side_sheet_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_search_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_shy_header_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_chat_threads_fuzzy_search_enabled");
    WAGRHookOneWAABBundleFlag(cls, "scheduled_messages_sender_enabled");
    WAGRHookOneWAABBundleFlag(cls, "scheduled_messages_receiver_enabled");
    WAGRHookOneWAABBundleFlag(cls, "non_contact_status_receiver_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_w_variant_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_message_starring_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_fts_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_media_only_deletion_enabled");
    WAGRHookOneWAABBundleFlag(cls, "chat_themes_selection_in_reg_flow_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_disappearing_icon_chatlist_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channel_recommendation_notification_setting_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_admin_notifications_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_notification_content_extension_ios_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_verified_badge_in_compact_inbox_enabled");
    WAGRHookOneWAABBundleFlag(cls, "community_general_chat_notification_followup_enabled");
    WAGRHookOneWAABBundleFlag(cls, "high_priority_inorganic_notification_enabled");
    WAGRHookOneWAABBundleFlag(cls, "inorganic_notification_content_variant_v2_enabled");
    WAGRHookOneWAABBundleFlag(cls, "inorganic_notification_logging_update_enabled");
    WAGRHookOneWAABBundleFlag(cls, "inorganic_notification_promotion_id_enabled");
    WAGRHookOneWAABBundleFlag(cls, "inorganic_notification_timer_emoji_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_album_v2_notifications_bundling_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_batched_group_notification_processing_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_ccq_notifications_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_message_notification_hq_image_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_new_media_video_preview_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_ringtones_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_ringtones_benefit_active");
    WAGRHookOneWAABBundleFlag(cls, "aura_ringtones_per_chat_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_meta_ai_in_app_tab_main_gate_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_home_in_tab_main_gate_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_hatch_integration_tab_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_tab_glyph_icon_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_tab_perf_optimizations_enabled");
    WAGRHookOneWAABBundleFlag(cls, "community_tab_v2_enabled");
    WAGRHookOneWAABBundleFlag(cls, "communities_remove_from_app_tab_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_creation_entrypoint_in_updates_tab_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channels_pinning_nudge_updates_tab_enabled");
    WAGRHookOneWAABBundleFlag(cls, "updates_tab_filter_pills_enabled");
    WAGRHookOneWAABBundleFlag(cls, "updates_tab_loading_time_measurement_enabled");
    WAGRHookOneWAABBundleFlag(cls, "status_archive_updates_tab_entryoint_enabled");
    WAGRHookOneWAABBundleFlag(cls, "group_status_creation_updates_tab_entrypoint_enabled");
    WAGRHookOneWAABBundleFlag(cls, "status_quick_replies_v2_stickers_tab_enabled");
    WAGRHookOneWAABBundleFlag(cls, "waffle_v2_updates_tab_after_share_entrypoint_disabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_settings_row_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_subscription_simulation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_icon_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_icon_benefit_active");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_benefit_active");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_chat_checkmark_themed_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_new_selection_flow_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_share_extension_themed_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_status_ring_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_app_themes_illustration_lottie_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_apple_watch_app_theme_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_apple_watch_app_themes_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_pinned_chats_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_pinned_chats_benefit_active");
    WAGRHookOneWAABBundleFlag(cls, "aura_enhanced_lists_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_enhanced_lists_benefit_active");
    WAGRHookOneWAABBundleFlag(cls, "aura_stickers_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_stickers_benefit_active");
    WAGRHookOneWAABBundleFlag(cls, "aura_stickers_overlay_animation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_painted_door_stickers_enabled");
    WAGRHookOneWAABBundleFlag(cls, "aura_logging_enabled");
    WAGRHookOneWAABBundleFlag(cls, "lists_feature_enabled");
    WAGRHookOneWAABBundleFlag(cls, "lists_sync_enabled");
    WAGRHookOneWAABBundleFlag(cls, "events_global_list");
    WAGRHookOneWAABBundleFlag(cls, "call_favorites_enabled_companions");
    WAGRHookOneWAABBundleFlag(cls, "waffle_mobile_companions_enabled");
    WAGRHookOneWAABBundleFlag(cls, "waffle_enabled_for_unlinked_users");
    WAGRHookOneWAABBundleFlag(cls, "waffle_foa_to_wa_linking_enabled");
    WAGRHookOneWAABBundleFlag(cls, "isPAAEligibleForWaffle");
    WAGRHookOneWAABBundleFlag(cls, "isPaymentP2PEnabled");
    WAGRHookOneWAABBundleFlag(cls, "foa_threads_bookmarks_enabled");
    WAGRHookOneWAABBundleFlag(cls, "foa_bookmark_sk_overlay_enabled");
    WAGRHookOneWAABBundleFlag(cls, "foa_bridges_bookmark_meta_horizon");
    WAGRHookOneWAABBundleFlag(cls, "foa_bridges_bookmarks_design_update_enabled");
    WAGRHookOneWAABBundleFlag(cls, "foa_bookmarks_logging_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_rich_response_vibes_promotion_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_rich_response_c50_promotion_enabled");
    WAGRHookOneWAABBundleFlag(cls, "sections_in_help_menu");
    WAGRHookOneWAABBundleFlag(cls, "premium_blue_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_contacts_surface_is_enabled");
    WAGRHookOneWAABBundleFlag(cls, "isEligibleForFOABookmarks");
    WAGRHookOneWAABBundleFlag(cls, "ios_me_tab_new_user_checklist_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_me_tab_share_updates_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_me_tab_username_findability_enabled");
    WAGRHookOneWAABBundleFlag(cls, "me_tab_settings_header_enabled");
    WAGRHookOneWAABBundleFlag(cls, "xfam_lg_switcher_m2_me_tab_enabled");
    WAGRHookOneWAABBundleFlag(cls, "wa_subscriptions_entry_point_settings_enabled");
    WAGRHookOneWAABBundleFlag(cls, "wa_subscriptions_settings_green_dot_enabled");
    WAGRHookOneWAABBundleFlag(cls, "verified_badge_in_chats_list_enabled");
    WAGRHookOneWAABBundleFlag(cls, "non_anonymous_group_participation_enable");
    WAGRHookOneWAABBundleFlag(cls, "isAfterReadReceiverEnabled");
    WAGRHookOneWAABBundleFlag(cls, "reactionsChatPreview");
    WAGRHookOneWAABBundleFlag(cls, "username_contact_display");
    WAGRHookOneWAABBundleFlag(cls, "liquid_glass");
    WAGRHookOneWAABBundleFlag(cls, "aura_");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_launched");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_media_m0");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m1");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m_1_5");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m_1_5_context_menu");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m_2_action_tile");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m_2_chips");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m_2_lightweight_dialogs");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_m_2_text_layout");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_larger_composer");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_media_editor_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_calling_improvement_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_chat_top_bar_m2_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_enable_new_chatbar_ux");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_reduce_transparency");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_ptt_oot");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fixes_for_older_ios");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_context_menu_on_disappear");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_context_menu_transition_safety");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_feedback_generator_retain");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_forward_picker_share_extension_crash");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_me_tab_profile_render_throttle_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_multisend_preview_dealloc");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_status_dismiss_when_locked");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_tabbar_badge_offthread");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_uiimage_trait_collection");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_updates_table_dynamic_color");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_fix_weak_hashtable_snapshot");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_workaround_attachment_tray");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_workaround_hides_bottombar");
    WAGRHookOneWAABBundleFlag(cls, "ios_liquid_glass_workaround_topbar_appearance");
    WAGRHookOneWAABBundleFlag(cls, "status_viewer_redesign_enabled");
    WAGRHookOneWAABBundleFlag(cls, "privacy_setting_relay_all_calls");
    WAGRHookOneWAABBundleFlag(cls, "group_status_receiver_enabled");
    WAGRHookOneWAABBundleFlag(cls, "is_status_opt_in_notification_enabled");
    WAGRHookOneWAABBundleFlag(cls, "notification_highlight_sync");
    WAGRHookOneWAABBundleFlag(cls, "sg_ios_multi_account_enabled");
    WAGRHookOneWAABBundleFlag(cls, "wa_xfam_ios_switcher_multiaccount_enabled");
    WAGRHookOneWAABBundleFlag(cls, "foa_bridges_account_switcher_ios_enabled");
    WAGRHookOneWAABBundleFlag(cls, "deletion_reason_multi_account_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_subscription_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_subscription_imagine_intent_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_genai_imagine_intent_attachment_tray_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_group_multi_modal_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_intents_status_mimicry_receiver_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_intents_status_mimicry_sender_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_video_edit_in_media_editor_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_rewrite_in_context_menu_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_voice_fab_call_history_entry_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_voice_live_video_pip_enabled");
    WAGRHookOneWAABBundleFlag(cls, "calling_voicemail_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channel_poll_status_card_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channel_status_consumption_music_enabled");
    WAGRHookOneWAABBundleFlag(cls, "channel_status_creation_music_enabled");
    WAGRHookOneWAABBundleFlag(cls, "context_menu_keyboard_fix_enabled");
    WAGRHookOneWAABBundleFlag(cls, "enable_call_transfer_notification");
    WAGRHookOneWAABBundleFlag(cls, "enable_in_call_more_menu_ios");
    WAGRHookOneWAABBundleFlag(cls, "enable_in_call_picker_merged_list");
    WAGRHookOneWAABBundleFlag(cls, "enable_more_menu_in_vc");
    WAGRHookOneWAABBundleFlag(cls, "enable_new_call_invite");
    WAGRHookOneWAABBundleFlag(cls, "enable_new_call_link_representation");
    WAGRHookOneWAABBundleFlag(cls, "enable_reasoning_status");
    WAGRHookOneWAABBundleFlag(cls, "enable_schedule_call_from_calls_tab");
    WAGRHookOneWAABBundleFlag(cls, "enable_scheduled_calls_v2_entry_points_creation");
    WAGRHookOneWAABBundleFlag(cls, "enable_sticker_lottie_reader_in_tray");
    WAGRHookOneWAABBundleFlag(cls, "group_invite_contacts_count_enabled");
    WAGRHookOneWAABBundleFlag(cls, "group_status_forward_to_channels_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_enable_klipy_sticker_search");
    WAGRHookOneWAABBundleFlag(cls, "ios_guest_calling_representation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_klipy_logging_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_linked_devices_empty_states_ui_refresh_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ios_reaction_keyboard_uilabel_enabled");
    WAGRHookOneWAABBundleFlag(cls, "is_meta_employee_or_internal_tester");
    WAGRHookOneWAABBundleFlag(cls, "meta_catalog_linking_m3_enabled");
    WAGRHookOneWAABBundleFlag(cls, "newsletter_forward_counter_ui_enabled");
    WAGRHookOneWAABBundleFlag(cls, "payments_selection_ui_updates_enabled");
    WAGRHookOneWAABBundleFlag(cls, "push_name_in_community_groups_picker_enabled");
    WAGRHookOneWAABBundleFlag(cls, "should_use_select_multiple_context_menu");
    WAGRHookOneWAABBundleFlag(cls, "smb_custom_url_display_v2_enabled");
    WAGRHookOneWAABBundleFlag(cls, "smb_verified_badge_parity_changes_enabled");
    WAGRHookOneWAABBundleFlag(cls, "smbi_premium_broadcast_enabled");
    WAGRHookOneWAABBundleFlag(cls, "status_animated_music_stickers_enabled");
    WAGRHookOneWAABBundleFlag(cls, "status_animated_sticker_with_static_media_enabled");
    WAGRHookOneWAABBundleFlag(cls, "status_viewer_redesign");
    WAGRHookOneWAABBundleFlag(cls, "view_replies_follow_up_ui_enabled");
    WAGRHookOneWAABBundleFlag(cls, "waffle_companions_enabled");
    WAGRHookOneWAABBundleFlag(cls, "wagr_debug_mode_enabled");
    WAGRHookOneWAABBundleFlag(cls, "wb_standard_layout_enabled_ios");
    WAGRHookOneWAABBundleFlag(cls, "ai_home_redesign_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_psi_ux_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_dynamic_mode_selector_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_dynamic_model_branding_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_incognito_mode_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_incognito_mode_disappearing_messages_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_incognito_mode_personalization_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_incognito_media_input_enabled");
    WAGRHookOneWAABBundleFlag(cls, "non_anonymous_incognito_enable");
    WAGRHookOneWAABBundleFlag(cls, "ai_side_chat_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_side_chat_search_starter_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_side_chat_summarization_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_side_chat_writing_help_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_side_chat_image_creation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_side_chat_media_input_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_hatch_integration_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_hatch_commands_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_rewrite_in_edit_message_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_rich_response_tables_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_contextual_writing_help_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_group_participation_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_group_participation_send_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_voice_image_input_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_voice_live_video_input_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_voice_ptt_coexistence_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_imagine_bottom_sheet_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_genai_imagine_intent_ar_effects_v3_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_genai_imagine_intent_status_v3_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_bot_imagine_me_enabled");
    WAGRHookOneWAABBundleFlag(cls, "ai_llama_premium_model_main_gate_enabled");
    WAGRHookOneWAABBundleFlag(cls, "is_internal_tester");
    WAGRHookOneWAABBundleFlag(cls, "mobile_config_debug_internal");
    WAGRHookOneWAABBundleFlag(cls, "dogfooder_diagnostics");
    WAGRHookOneWAABBundleFlag(cls, "ios_internal_hall_enabled");
    WAGRHookOneWAABBundleFlag(cls, "visible_message_drop_placeholder_enabled_internal_only");

    NSLog(@"[WAGram][BundleHooks] installed %lu direct WAAB bundle hooks",
          (unsigned long)gWAGRBundleOrig.count);
}

__attribute__((constructor))
static void WAGRBundleHooksCtor(void) {
    @autoreleasepool {
        // Safe-startup rule:
        // Bundle hooks are still installed by menu/toggle actions, but not during launch.
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"wagr_startup_hooks_enabled"]) {
            NSLog(@"[WAGram][BundleHooks] inert startup; hooks install only from menu/toggle");
            return;
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WAGRBundleEnsureHooksInstalled();
        });
    }
}
