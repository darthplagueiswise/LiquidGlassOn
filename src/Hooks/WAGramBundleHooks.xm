// WAGramBundleHooks.xm
// Direct per-method hooks on WAABProperties for bundled feature groups.
// MSHookMessageEx implementation; avoids Logos original-call macro expansion.

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
    NSValue *val = gWAGRBundleOrig[flag];
    if (val) orig = (WAGRWAABOrigBoolIMP)[val pointerValue];

    return orig ? orig(self, _cmd) : NO;
}

static void WAGRHookOneWAABBundleFlag(Class cls, const char *name) {
    if (!cls || !name || !*name) return;

    NSString *key = [NSString stringWithUTF8String:name];
    if (gWAGRBundleOrig[key]) return;

    SEL sel = sel_registerName(name);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    if (method_getNumberOfArguments(m) != 2) return;

    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    if (ret[0] != 'B' && ret[0] != 'c') return;

    IMP orig = NULL;
    MSHookMessageEx(cls, sel, (IMP)WAGRBundleBoolHook, &orig);
    if (orig) gWAGRBundleOrig[key] = [NSValue valueWithPointer:(void *)orig];
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

    NSLog(@"[WAGram][BundleHooks] installed %lu direct WAAB bundle hooks",
          (unsigned long)gWAGRBundleOrig.count);
}

__attribute__((constructor))
static void WAGRBundleHooksCtor(void) {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WAGRBundleEnsureHooksInstalled();
        });
    }
}
