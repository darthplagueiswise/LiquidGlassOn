// WAGramBundleHooks.xm
// Direct per-method hooks on WAABProperties for Privacy, Chat, Notifications, TabBar.
// Same pattern as WALiquidGlassHooks.xm — each method hooked directly via Logos,
// reads NSUserDefaults wagr.waab.<flag> = "on"/"off".
//
// Why direct hooks AND the generic observer?
//   Generic: catches every flag at boolForKey:defaultValue: level
//   Direct:  catches flags called as named methods BEFORE boolForKey (faster path)
//   Both together = maximum coverage, same as WALiquidGlass.dylib approach.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "../WAGramPrefix.h"

#define WAAB_HOOK(flag) \
- (BOOL)flag { \
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(@#flag)]; \
    if ([v isEqualToString:@"on"])  return YES; \
    if ([v isEqualToString:@"off"]) return NO; \
    return %orig; \
}

%hook WAABProperties

// ─── PRIVACY sub-menu rows ────────────────────────────────────────────────────
WAAB_HOOK(defense_mode_available)
WAAB_HOOK(passkey_login)
WAAB_HOOK(multiple_passkeys_delete_v2_enabled)
WAAB_HOOK(username_suggestions_enabled)
WAAB_HOOK(username_key_redesign_enabled)
WAAB_HOOK(username_enabled_on_companion)
WAAB_HOOK(username_call_search_enabled)
WAAB_HOOK(username_group_mutation_enabled)
WAAB_HOOK(username_group_learning_enabled)
WAAB_HOOK(username_future_proof_contact_creation_enabled)
WAAB_HOOK(allow_lid_contacts_privacy_settings)
WAAB_HOOK(allow_lid_contacts_calling)
WAAB_HOOK(allow_lid_contacts_status)
WAAB_HOOK(allow_lid_contacts_broadcast)
WAAB_HOOK(enable_calling_phone_number_privacy)
WAAB_HOOK(enable_calling_username)
WAAB_HOOK(ios_wabi_enable_username_migration)
WAAB_HOOK(privacy_aware_secure_dl_logging_enabled)
WAAB_HOOK(privacy_checkup)
WAAB_HOOK(interop_client_ux_enabled)
WAAB_HOOK(interop_contact_master_enabled)
WAAB_HOOK(interop_group_messaging_enabled)
WAAB_HOOK(interop_bootstrap_enabled)
WAAB_HOOK(wa_interop_unified_inbox_enabled)
WAAB_HOOK(is_interop_available_badge_banner_enabled)
WAAB_HOOK(is_interop_new_3p_available_badge_banner_enabled)
WAAB_HOOK(high_quality_link_preview_enabled)
WAAB_HOOK(fb_experiment_for_link_preview_m3_enabled)
WAAB_HOOK(ios_privacy_formatter_enabled)

// ─── CHAT sub-menu rows ────────────────────────────────────────────────────────
WAAB_HOOK(ai_translate_messages_enabled)
WAAB_HOOK(evolve_about_m1_enabled)
WAAB_HOOK(evolve_about_m1_receiver_enabled)
WAAB_HOOK(evolve_about_m1_receiver_for_new_surfaces_enabled)
WAAB_HOOK(ptt_transcription_manual_message_button_enabled)
WAAB_HOOK(ai_imagine_intents_chat_themes_enabled)
WAAB_HOOK(ai_genai_imagine_intent_chat_theme_v3_enabled)
WAAB_HOOK(ai_imagine_intents_chat_wallpaper_enabled)
WAAB_HOOK(ai_genai_imagine_intent_chat_wallpaper_v3_enabled)
WAAB_HOOK(ai_imagine_in_media_editor_enabled)
WAAB_HOOK(ai_imagine_expand_in_media_editor_enabled)
WAAB_HOOK(ios_extend_disappearing_mode_with_ephemerality_disabled_enabled)
WAAB_HOOK(ios_inbox_pinned_chats_in_context_menu_enabled)
WAAB_HOOK(ios_storage_management_clear_chat_entrypoint_context_menu_enabled)
WAAB_HOOK(chat_list_drop_interaction_enabled)
WAAB_HOOK(ios_accordion_tableview_exception_on_delete_fix_enabled)
WAAB_HOOK(ios_chats_tab_null_state_search_bar_enabled)
WAAB_HOOK(ios_chatlist_bundle_pinned_chat_move)
WAAB_HOOK(rename_other_contacts_to_contacts_enabled)
WAAB_HOOK(ai_chat_list_search_enabled)
WAAB_HOOK(ai_chat_threads_enabled)
WAAB_HOOK(ai_chat_threads_infra_enabled)
WAAB_HOOK(ai_chat_thread_capability_enabled)
WAAB_HOOK(ai_chat_threads_multiplayer_enabled)
WAAB_HOOK(ai_chat_threads_pin_enabled)
WAAB_HOOK(ai_chat_threads_side_sheet_enabled)
WAAB_HOOK(ai_chat_threads_search_enabled)
WAAB_HOOK(ai_chat_threads_shy_header_enabled)
WAAB_HOOK(ai_chat_threads_fuzzy_search_enabled)
WAAB_HOOK(scheduled_messages_sender_enabled)
WAAB_HOOK(scheduled_messages_receiver_enabled)
WAAB_HOOK(non_contact_status_receiver_enabled)
WAAB_HOOK(channels_w_variant_enabled)
WAAB_HOOK(channels_message_starring_enabled)
WAAB_HOOK(channels_fts_enabled)
WAAB_HOOK(channels_media_only_deletion_enabled)
WAAB_HOOK(chat_themes_selection_in_reg_flow_enabled)
WAAB_HOOK(ios_disappearing_icon_chatlist_enabled)

// ─── NOTIFICATIONS sub-menu ────────────────────────────────────────────────────
WAAB_HOOK(channel_recommendation_notification_setting_enabled)
WAAB_HOOK(channels_admin_notifications_enabled)
WAAB_HOOK(channels_notification_content_extension_ios_enabled)
WAAB_HOOK(channels_verified_badge_in_compact_inbox_enabled)
WAAB_HOOK(community_general_chat_notification_followup_enabled)
WAAB_HOOK(high_priority_inorganic_notification_enabled)
WAAB_HOOK(inorganic_notification_content_variant_v2_enabled)
WAAB_HOOK(inorganic_notification_logging_update_enabled)
WAAB_HOOK(inorganic_notification_promotion_id_enabled)
WAAB_HOOK(inorganic_notification_timer_emoji_enabled)
WAAB_HOOK(ios_album_v2_notifications_bundling_enabled)
WAAB_HOOK(ios_batched_group_notification_processing_enabled)
WAAB_HOOK(ios_ccq_notifications_enabled)
WAAB_HOOK(ios_message_notification_hq_image_enabled)
WAAB_HOOK(ios_new_media_video_preview_enabled)
WAAB_HOOK(aura_ringtones_enabled)
WAAB_HOOK(aura_ringtones_benefit_active)
WAAB_HOOK(aura_ringtones_per_chat_enabled)

// ─── TAB BAR / navigation ─────────────────────────────────────────────────────
WAAB_HOOK(ai_meta_ai_in_app_tab_main_gate_enabled)
WAAB_HOOK(ai_home_in_tab_main_gate_enabled)
WAAB_HOOK(ai_hatch_integration_tab_enabled)
WAAB_HOOK(ai_tab_glyph_icon_enabled)
WAAB_HOOK(ai_tab_perf_optimizations_enabled)
WAAB_HOOK(community_tab_v2_enabled)
WAAB_HOOK(communities_remove_from_app_tab_enabled)
WAAB_HOOK(channels_creation_entrypoint_in_updates_tab_enabled)
WAAB_HOOK(channels_pinning_nudge_updates_tab_enabled)
WAAB_HOOK(updates_tab_filter_pills_enabled)
WAAB_HOOK(updates_tab_loading_time_measurement_enabled)
WAAB_HOOK(status_archive_updates_tab_entryoint_enabled)
WAAB_HOOK(group_status_creation_updates_tab_entrypoint_enabled)
WAAB_HOOK(status_quick_replies_v2_stickers_tab_enabled)
WAAB_HOOK(waffle_v2_updates_tab_after_share_entrypoint_disabled)

// ─── APPEARANCE (Aura) ────────────────────────────────────────────────────────
WAAB_HOOK(aura_enabled)
WAAB_HOOK(aura_settings_row_enabled)
WAAB_HOOK(aura_subscription_simulation_enabled)
WAAB_HOOK(aura_app_icon_enabled)
WAAB_HOOK(aura_app_icon_benefit_active)
WAAB_HOOK(aura_app_themes_enabled)
WAAB_HOOK(aura_app_themes_benefit_active)
WAAB_HOOK(aura_app_themes_chat_checkmark_themed_enabled)
WAAB_HOOK(aura_app_themes_new_selection_flow_enabled)
WAAB_HOOK(aura_app_themes_share_extension_themed_enabled)
WAAB_HOOK(aura_app_themes_status_ring_enabled)
WAAB_HOOK(aura_app_themes_illustration_lottie_enabled)
WAAB_HOOK(aura_apple_watch_app_theme_enabled)
WAAB_HOOK(aura_apple_watch_app_themes_enabled)
WAAB_HOOK(aura_pinned_chats_enabled)
WAAB_HOOK(aura_pinned_chats_benefit_active)
WAAB_HOOK(aura_enhanced_lists_enabled)
WAAB_HOOK(aura_enhanced_lists_benefit_active)
WAAB_HOOK(aura_stickers_enabled)
WAAB_HOOK(aura_stickers_benefit_active)
WAAB_HOOK(aura_stickers_overlay_animation_enabled)
WAAB_HOOK(aura_painted_door_stickers_enabled)
WAAB_HOOK(aura_logging_enabled)

// ─── SETTINGS HIDDEN ROWS ─────────────────────────────────────────────────────
WAAB_HOOK(lists_feature_enabled)
WAAB_HOOK(lists_sync_enabled)
WAAB_HOOK(events_global_list)
WAAB_HOOK(call_favorites_enabled_companions)
WAAB_HOOK(waffle_mobile_companions_enabled)
WAAB_HOOK(waffle_enabled_for_unlinked_users)
WAAB_HOOK(waffle_foa_to_wa_linking_enabled)
WAAB_HOOK(isPAAEligibleForWaffle)
WAAB_HOOK(isPaymentP2PEnabled)
WAAB_HOOK(foa_threads_bookmarks_enabled)
WAAB_HOOK(foa_bookmark_sk_overlay_enabled)
WAAB_HOOK(foa_bridges_bookmark_meta_horizon)
WAAB_HOOK(foa_bridges_bookmarks_design_update_enabled)
WAAB_HOOK(foa_bookmarks_logging_enabled)
WAAB_HOOK(ai_rich_response_vibes_promotion_enabled)
WAAB_HOOK(ai_rich_response_c50_promotion_enabled)
WAAB_HOOK(sections_in_help_menu)
WAAB_HOOK(premium_blue_enabled)
WAAB_HOOK(ios_contacts_surface_is_enabled)
WAAB_HOOK(isEligibleForFOABookmarks)
WAAB_HOOK(ios_me_tab_new_user_checklist_enabled)
WAAB_HOOK(ios_me_tab_share_updates_enabled)
WAAB_HOOK(ios_me_tab_username_findability_enabled)
WAAB_HOOK(me_tab_settings_header_enabled)
WAAB_HOOK(xfam_lg_switcher_m2_me_tab_enabled)
WAAB_HOOK(wa_subscriptions_entry_point_settings_enabled)
WAAB_HOOK(wa_subscriptions_settings_green_dot_enabled)
WAAB_HOOK(verified_badge_in_chats_list_enabled)
WAAB_HOOK(non_anonymous_group_participation_enable)
WAAB_HOOK(isAfterReadReceiverEnabled)
WAAB_HOOK(reactionsChatPreview)
WAAB_HOOK(username_contact_display)

%end

// ─── isDebugMenuAllowed stays in Tweak.x (on WASettingsViewController) ────────

extern "C" void WAGRBundleHooksInstall(void) {
    // Logos %init called automatically; this is a no-op placeholder for diagnostics
    NSLog(@"[WAGram][Bundles] Direct flag hooks active via Logos %%hook WAABProperties");
}
