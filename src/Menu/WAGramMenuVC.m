// WAGramMenuVC.m — WAGram v6
// Feature bundles: activate/deactivate all flags for a feature with one tap.
// Same persistence pattern as LiquidGlass (NSUserDefaults + direct hooks + restart).

#import "WAGramMenuVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"

// ── Colors ────────────────────────────────────────────────────────────────────
static UIColor *BG(void)       { return UIColor.systemBackgroundColor; }
static UIColor *CELLBG(void)   { return UIColor.secondarySystemBackgroundColor; }
static UIColor *ACCENT(void)   { return UIColor.systemBlueColor; }
static UIColor *GREEN(void)    { return UIColor.systemGreenColor; }
static UIColor *SECONDARY(void){ return UIColor.secondaryLabelColor; }

// ── NSUserDefaults helpers ────────────────────────────────────────────────────
static BOOL FlagOn(NSString *f) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(f)] isEqualToString:@"on"];
}
static void FlagSet(NSString *f, BOOL on) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (on) [ud setObject:@"on" forKey:WAGRKey(f)];
    else    [ud removeObjectForKey:WAGRKey(f)];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    if ([f containsString:@"liquid_glass"]) WAGRLGPrefsDidChange();
    if ([f hasPrefix:@"aura_"]) WAGRAuraEnsureHooksInstalled();
    if ([f containsString:@"dogfood"] || [f containsString:@"internal"])
        WAGRDogfoodEnsureHooksInstalled();
}

// ── Top VC ────────────────────────────────────────────────────────────────────
static UIViewController *TopVC(void) {
    UIViewController *c = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows)
            if (w.isKeyWindow && w.rootViewController) { c = w.rootViewController; break; }
        if (c) break;
    }
    while (YES) {
        if (c.presentedViewController){c=c.presentedViewController;continue;}
        if ([c isKindOfClass:UINavigationController.class]){UIViewController*v=((UINavigationController*)c).visibleViewController;if(v&&v!=c){c=v;continue;}}
        if ([c isKindOfClass:UITabBarController.class]){UIViewController*v=((UITabBarController*)c).selectedViewController;if(v&&v!=c){c=v;continue;}}
        break;
    }
    return c;
}
static void Alert(NSString *t, NSString *m) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a=[UIAlertController alertControllerWithTitle:t?:@"WAGram" message:m?:@"" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault handler:^(id _){UIPasteboard.generalPasteboard.string=m?:@"";}]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [TopVC() presentViewController:a animated:YES completion:nil];
    });
}

// ─── Section header — plain uppercase like WhatsApp native ────────────────────
@interface WAGRHeader : UIView - (instancetype)initWithTitle:(NSString *)t icon:(NSString *)icon; @end
@implementation WAGRHeader { UILabel *_l; }
- (instancetype)initWithTitle:(NSString *)t icon:(NSString *)icon {
    self=[super init];
    _l=[[UILabel alloc]init]; _l.translatesAutoresizingMaskIntoConstraints=NO;
    NSString *full = icon.length ? [NSString stringWithFormat:@"%@ %@", icon, [t uppercaseString]] : [t uppercaseString];
    _l.text=full; _l.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium]; _l.textColor=SECONDARY();
    [self addSubview:_l];
    [NSLayoutConstraint activateConstraints:@[[_l.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],[_l.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-6]]];
    return self;
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGRABFlagBrowserVC — single working browser used for ALL flag lists
// ═══════════════════════════════════════════════════════════════════════════════
static const char kBKey = 0;

@interface WAGRABFlagBrowserVC () <UISearchResultsUpdating>
@property (nonatomic, strong, readwrite) NSArray<NSString *> *allFlags;
@property (nonatomic, strong) NSArray<NSString *> *filtered;
@property (nonatomic, strong) UISearchController  *search;
@end

@implementation WAGRABFlagBrowserVC

- (instancetype)initWithTitle:(NSString *)t flags:(NSArray<NSString *> *)flags {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title=t;
    _allFlags=flags?[flags sortedArrayUsingSelector:@selector(compare:)]:@[];
    _filtered=_allFlags;
    return self;
}
+ (NSArray<NSString *> *)runtimeFlags {
    Class cls=NSClassFromString(@"WAABProperties"); if (!cls) return @[];
    NSMutableArray *out=[NSMutableArray array];
    unsigned int n=0; Method *ms=class_copyMethodList(cls,&n);
    for (unsigned int i=0;i<n;i++) {
        if (method_getNumberOfArguments(ms[i])!=2) continue;
        char ret[8]={0}; method_getReturnType(ms[i],ret,8);
        if (ret[0]!='B'&&ret[0]!='c') continue;
        NSString *nm=NSStringFromSelector(method_getName(ms[i]));
        if ([nm containsString:@":"]) continue;
        [out addObject:nm];
    }
    free(ms);
    return [out sortedArrayUsingSelector:@selector(compare:)];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor=BG();
    _search=[[UISearchController alloc]initWithSearchResultsController:nil];
    _search.searchResultsUpdater=self; _search.obscuresBackgroundDuringPresentation=NO;
    _search.searchBar.placeholder=@"Buscar flag…";
    self.navigationItem.searchController=_search;
    self.navigationItem.hidesSearchBarWhenScrolling=NO;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    [self updateBadge];
    if (_allFlags.count==0) [self reload];
}
- (void)updateBadge {
    NSUInteger on=0;
    for (NSString *f in _allFlags) if (FlagOn(f)) on++;
    self.title = on>0 ? [NSString stringWithFormat:@"%@ (%lu ✓)",(self.navigationItem.backButtonTitle?:self.title),(unsigned long)on]
                      : (self.navigationItem.backButtonTitle?:self.title?:@"Flags");
}
- (void)reload {
    if (_allFlags.count==0) _allFlags=[[self class] runtimeFlags];
    [self updateSearchResultsForSearchController:_search];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q=sc.searchBar.text;
    _filtered=q.length?[_allFlags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@",q]]:_allFlags;
    [self.tableView reloadData]; [self updateBadge];
}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return (NSInteger)_filtered.count;}
- (CGFloat)tableView:(UITableView*)tv heightForRowAtIndexPath:(NSIndexPath*)ip{return 48;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:@"b"];
    if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"b"];
    NSString *flag=_filtered[(NSUInteger)ip.row];
    BOOL on=FlagOn(flag);
    c.backgroundColor=CELLBG();
    c.textLabel.text=flag;
    c.textLabel.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    c.textLabel.textColor=on?ACCENT():UIColor.labelColor;
    c.textLabel.numberOfLines=2;
    c.selectionStyle=UITableViewCellSelectionStyleNone;
    UISwitch *sw=[[UISwitch alloc]init]; sw.on=on; sw.onTintColor=ACCENT();
    objc_setAssociatedObject(sw,&kBKey,flag,OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(tog:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView=sw; return c;
}
- (void)tog:(UISwitch*)sw {
    NSString *flag=objc_getAssociatedObject(sw,&kBKey); if (!flag) return;
    FlagSet(flag,sw.isOn);
    for (UITableViewCell *c in self.tableView.visibleCells) {
        UISwitch *s=(UISwitch*)c.accessoryView;
        if ([s isKindOfClass:UISwitch.class]&&[objc_getAssociatedObject(s,&kBKey) isEqualToString:flag])
            c.textLabel.textColor=sw.isOn?ACCENT():UIColor.labelColor;
    }
    [self updateBadge];
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramBundleVC — master toggle + individual browser (the LiquidGlass pattern)
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGramBundleVC : UITableViewController
- (instancetype)initWithTitle:(NSString *)title
                        flags:(NSArray<NSString *> *)flags
                         icon:(NSString *)icon
                   prefixDesc:(NSString *)desc;
@end

@implementation WAGramBundleVC {
    NSArray<NSString *> *_flags;
    NSString *_icon;
    NSString *_desc;
    UISwitch *_masterSwitch;
    WAGRABFlagBrowserVC *_browser;
}


- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags
                         icon:(NSString *)icon prefixDesc:(NSString *)desc {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title=title; _flags=flags; _icon=icon; _desc=desc;
    _browser=[[WAGRABFlagBrowserVC alloc]initWithTitle:title flags:flags];
    _browser.navigationItem.backButtonTitle=title;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor=BG();
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 3;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{
    if (s==0) return 1; // Master toggle
    if (s==1) return 1; // "Ver todos" navigation
    return 1;           // Info button
}
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    if (s==0) return [[WAGRHeader alloc]initWithTitle:@"Ativar Grupo" icon:_icon];
    if (s==1) return [[WAGRHeader alloc]initWithTitle:@"Flags individuais" icon:nil];
    return nil;
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s{return s<2?32:0;}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    if (s==0) return [NSString stringWithFormat:@"%@\n\nUsa NSUserDefaults wagr.waab.<flag> = \"on\" + hook direto em WAABProperties (mesmo padrão do LiquidGlass). Reiniciar após ativar.", _desc?:@""];
    return nil;
}

- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if (ip.section==0) {
        // Master "Ativar Todos" toggle
        UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        c.backgroundColor=CELLBG();
        NSUInteger on=WAGRBundleActiveCount(_flags);
        c.textLabel.text=[NSString stringWithFormat:@"Ativar Todos (%lu/%lu)", (unsigned long)on, (unsigned long)_flags.count];
        c.textLabel.textColor=UIColor.labelColor;
        c.detailTextLabel.text=on>0?[NSString stringWithFormat:@"%lu flags ativos",(unsigned long)on]:@"Todos desativados";
        c.detailTextLabel.textColor=on>0?GREEN():SECONDARY();
        c.selectionStyle=UITableViewCellSelectionStyleNone;
        _masterSwitch=[[UISwitch alloc]init];
        _masterSwitch.on=WAGRBundleAllActive(_flags);
        _masterSwitch.onTintColor=ACCENT();
        [_masterSwitch addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView=_masterSwitch;
        return c;
    }
    if (ip.section==1) {
        // Navigate to individual browser
        UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        c.backgroundColor=CELLBG();
        c.textLabel.text=@"Flags individuais";
        c.textLabel.textColor=UIColor.labelColor;
        NSUInteger on=WAGRBundleActiveCount(_flags);
        c.detailTextLabel.text=[NSString stringWithFormat:@"%lu/%lu", (unsigned long)on, (unsigned long)_flags.count];
        c.detailTextLabel.textColor=SECONDARY();
        c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    // Info cell
    UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    c.backgroundColor=CELLBG();
    c.textLabel.text=@"Diagnóstico WAAB";
    c.textLabel.textColor=ACCENT();
    return c;
}

- (void)masterChanged:(UISwitch*)sw {
    if (sw.isOn) WAGRActivateBundle(_flags);
    else         WAGRDeactivateBundle(_flags);
    WAGRWAABEnsureHooksInstalled();
    [self.tableView reloadData];
    [_browser reload];
}

- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section==1) [self.navigationController pushViewController:_browser animated:YES];
    if (ip.section==2) Alert(@"WAAB", WAGRWAABDiagnosticText());
}
@end

// ── Bundle builders ───────────────────────────────────────────────────────────
static NSArray *LGFlags(void) {
    return @[@"ios_liquid_glass_enabled",@"ios_liquid_glass_launched",@"ios_liquid_glass_media_m0",
             @"ios_liquid_glass_m1",@"ios_liquid_glass_m_1_5",@"ios_liquid_glass_m_1_5_context_menu",
             @"ios_liquid_glass_m_2_action_tile",@"ios_liquid_glass_m_2_chips",
             @"ios_liquid_glass_m_2_lightweight_dialogs",@"ios_liquid_glass_m_2_text_layout",
             @"ios_liquid_glass_larger_composer",@"ios_liquid_glass_media_editor_enabled",
             @"ios_liquid_glass_calling_improvement_enabled",@"ios_liquid_glass_chat_top_bar_m2_enabled",
             @"ios_liquid_glass_enable_new_chatbar_ux",@"ios_liquid_glass_reduce_transparency",
             @"ios_liquid_glass_ptt_oot",@"ios_liquid_glass_fixes_for_older_ios",
             @"ios_liquid_glass_fix_context_menu_on_disappear",
             @"ios_liquid_glass_fix_context_menu_transition_safety",
             @"ios_liquid_glass_fix_feedback_generator_retain",
             @"ios_liquid_glass_fix_forward_picker_share_extension_crash",
             @"ios_liquid_glass_fix_me_tab_profile_render_throttle_enabled",
             @"ios_liquid_glass_fix_multisend_preview_dealloc",
             @"ios_liquid_glass_fix_status_dismiss_when_locked",
             @"ios_liquid_glass_fix_tabbar_badge_offthread",
             @"ios_liquid_glass_fix_uiimage_trait_collection",
             @"ios_liquid_glass_fix_updates_table_dynamic_color",
             @"ios_liquid_glass_fix_weak_hashtable_snapshot",
             @"ios_liquid_glass_workaround_attachment_tray",
             @"ios_liquid_glass_workaround_hides_bottombar",
             @"ios_liquid_glass_workaround_topbar_appearance",
             @"status_viewer_redesign_enabled"];
}

static NSArray *PrivacyFlags(void) {
    return @[
        // Rows in WAPrivacySettingsViewController
        @"defense_mode_available",               // Defense Mode row
        @"passkey_login",                        // Passkey row
        @"multiple_passkeys_delete_v2_enabled",
        @"username_suggestions_enabled",         // Username row
        @"username_key_redesign_enabled",
        @"username_enabled_on_companion",
        @"username_call_search_enabled",
        @"username_group_mutation_enabled",
        @"username_group_learning_enabled",
        @"allow_lid_contacts_privacy_settings",  // LID contacts privacy
        @"allow_lid_contacts_calling",
        @"allow_lid_contacts_status",
        @"enable_calling_phone_number_privacy",  // Calling Privacy row
        @"enable_calling_username",
        @"ios_wabi_enable_username_migration",
        @"privacy_checkup",                      // Privacy Checkup row
        @"interop_client_ux_enabled",            // Interop row
        @"interop_contact_master_enabled",
        @"interop_group_messaging_enabled",
        @"interop_bootstrap_enabled",
        @"wa_interop_unified_inbox_enabled",
        @"is_interop_available_badge_banner_enabled",
        @"high_quality_link_preview_enabled",    // Link preview
        @"fb_experiment_for_link_preview_m3_enabled",
        @"privacy_aware_secure_dl_logging_enabled",
        @"ios_privacy_formatter_enabled",
        @"non_anonymous_group_participation_enable",
        @"privacy_setting_relay_all_calls",      // Settings-level relay calls
        @"foa_threads_bookmarks_enabled",        // Bookmarks section
        @"foa_bridges_bookmark_meta_horizon",
        @"foa_bookmark_sk_overlay_enabled",
        @"isEligibleForFOABookmarks",
    ];
}

static NSArray *ChatFlags(void) {
    return @[
        // Translation row
        @"ai_translate_messages_enabled",
        // About/Recado redesign
        @"evolve_about_m1_enabled",
        @"evolve_about_m1_receiver_enabled",
        @"evolve_about_m1_receiver_for_new_surfaces_enabled",
        // Transcription
        @"ptt_transcription_manual_message_button_enabled",
        // AI Themes / Wallpaper
        @"ai_imagine_intents_chat_themes_enabled",
        @"ai_genai_imagine_intent_chat_theme_v3_enabled",
        @"ai_imagine_intents_chat_wallpaper_enabled",
        @"ai_genai_imagine_intent_chat_wallpaper_v3_enabled",
        @"ai_imagine_in_media_editor_enabled",
        @"ai_imagine_expand_in_media_editor_enabled",
        @"chat_themes_selection_in_reg_flow_enabled",
        // Chat list features
        @"ios_chatlist_bundle_pinned_chat_move",
        @"ios_inbox_pinned_chats_in_context_menu_enabled",
        @"ios_chats_tab_null_state_search_bar_enabled",
        @"chat_list_drop_interaction_enabled",
        @"ai_chat_list_search_enabled",
        @"ios_disappearing_icon_chatlist_enabled",
        @"rename_other_contacts_to_contacts_enabled",
        // AI Threads (ALL THREE required)
        @"ai_chat_thread_capability_enabled",
        @"ai_chat_threads_infra_enabled",
        @"ai_chat_threads_enabled",
        @"ai_chat_threads_multiplayer_enabled",
        @"ai_chat_threads_pin_enabled",
        @"ai_chat_threads_side_sheet_enabled",
        @"ai_chat_threads_search_enabled",
        @"ai_chat_threads_shy_header_enabled",
        @"ai_chat_threads_fuzzy_search_enabled",
        // Scheduled messages
        @"scheduled_messages_sender_enabled",
        @"scheduled_messages_receiver_enabled",
        // Channels in chat list
        @"channels_w_variant_enabled",
        @"channels_message_starring_enabled",
        @"channels_fts_enabled",
        // Status
        @"non_contact_status_receiver_enabled",
        @"group_status_receiver_enabled",
        @"ios_extend_disappearing_mode_with_ephemerality_disabled_enabled",
        // Storage
        @"ios_storage_management_clear_chat_entrypoint_context_menu_enabled",
    ];
}

static NSArray *NotifFlags(void) {
    return @[
        @"channel_recommendation_notification_setting_enabled",
        @"channels_admin_notifications_enabled",
        @"channels_notification_content_extension_ios_enabled",
        @"channels_verified_badge_in_compact_inbox_enabled",
        @"community_general_chat_notification_followup_enabled",
        @"high_priority_inorganic_notification_enabled",
        @"inorganic_notification_content_variant_v2_enabled",
        @"inorganic_notification_timer_emoji_enabled",
        @"ios_album_v2_notifications_bundling_enabled",
        @"ios_batched_group_notification_processing_enabled",
        @"ios_message_notification_hq_image_enabled",
        @"ios_new_media_video_preview_enabled",
        @"aura_ringtones_enabled",
        @"aura_ringtones_benefit_active",
        @"aura_ringtones_per_chat_enabled",
        @"is_status_opt_in_notification_enabled",
        @"notification_highlight_sync",
    ];
}

static NSArray *TabBarFlags(void) {
    return @[
        @"ai_meta_ai_in_app_tab_main_gate_enabled",
        @"ai_home_in_tab_main_gate_enabled",
        @"ai_hatch_integration_tab_enabled",
        @"ai_tab_glyph_icon_enabled",
        @"ai_tab_perf_optimizations_enabled",
        @"community_tab_v2_enabled",
        @"communities_remove_from_app_tab_enabled",
        @"channels_creation_entrypoint_in_updates_tab_enabled",
        @"channels_pinning_nudge_updates_tab_enabled",
        @"updates_tab_filter_pills_enabled",
        @"status_archive_updates_tab_entryoint_enabled",
        @"group_status_creation_updates_tab_entrypoint_enabled",
        @"status_quick_replies_v2_stickers_tab_enabled",
             @"sg_ios_multi_account_enabled",@"wa_xfam_ios_switcher_multiaccount_enabled",@"foa_bridges_account_switcher_ios_enabled",
    ];
}

static NSArray *SettingsRowFlags(void) {
    return @[
        @"lists_feature_enabled",
        @"lists_sync_enabled",
        @"events_global_list",
        @"call_favorites_enabled_companions",
        @"waffle_mobile_companions_enabled",
        @"waffle_enabled_for_unlinked_users",
        @"waffle_foa_to_wa_linking_enabled",
        @"isPAAEligibleForWaffle",
        @"isPaymentP2PEnabled",
        @"foa_threads_bookmarks_enabled",
        @"foa_bookmark_sk_overlay_enabled",
        @"foa_bridges_bookmark_meta_horizon",
        @"foa_bridges_bookmarks_design_update_enabled",
        @"foa_bookmarks_logging_enabled",
        @"ai_rich_response_vibes_promotion_enabled",
        @"ai_rich_response_c50_promotion_enabled",
        @"sections_in_help_menu",
        @"premium_blue_enabled",
        @"ios_contacts_surface_is_enabled",
        @"isEligibleForFOABookmarks",
        @"ios_me_tab_new_user_checklist_enabled",
        @"ios_me_tab_share_updates_enabled",
        @"ios_me_tab_username_findability_enabled",
        @"me_tab_settings_header_enabled",
        @"xfam_lg_switcher_m2_me_tab_enabled",
        @"wa_subscriptions_entry_point_settings_enabled",
        @"wa_subscriptions_settings_green_dot_enabled",
        @"verified_badge_in_chats_list_enabled",
             @"aura_settings_row_enabled",@"aura_enabled",@"sg_ios_multi_account_enabled",@"wa_xfam_ios_switcher_multiaccount_enabled",@"foa_bridges_account_switcher_ios_enabled",@"deletion_reason_multi_account_enabled",
    ];
}

static NSArray *AuraFlags(void) {
    return @[
        @"aura_enabled",
        @"aura_settings_row_enabled",
        @"aura_subscription_simulation_enabled",
        @"aura_app_icon_enabled",
        @"aura_app_icon_benefit_active",
        @"aura_app_themes_enabled",
        @"aura_app_themes_benefit_active",
        @"aura_app_themes_chat_checkmark_themed_enabled",
        @"aura_app_themes_new_selection_flow_enabled",
        @"aura_app_themes_share_extension_themed_enabled",
        @"aura_apple_watch_app_theme_enabled",
        @"aura_pinned_chats_enabled",
        @"aura_pinned_chats_benefit_active",
        @"aura_enhanced_lists_enabled",
        @"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled",
        @"aura_ringtones_benefit_active",
        @"aura_ringtones_per_chat_enabled",
        @"aura_stickers_enabled",
        @"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",
        @"aura_logging_enabled",
        @"ai_subscription_enabled",
        @"ai_subscription_imagine_intent_enabled",
        @"isAppIconsBenefitActive",
        @"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive",
        @"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive",
        @"isStickersBenefitActive",
        @"isEligibleForSubscriptions",
        @"isExpandedFormattingPlusEnabled",
        @"wa_subscriptions_entry_point_settings_enabled",
    ];
}


static NSArray *WAGramFinalExtraFlags(void) {
    return @[
        @"ai_genai_imagine_intent_attachment_tray_enabled",
        @"ai_group_multi_modal_enabled",
        @"ai_imagine_intents_status_mimicry_receiver_enabled",
        @"ai_imagine_intents_status_mimicry_sender_enabled",
        @"ai_imagine_video_edit_in_media_editor_enabled",
        @"ai_rewrite_in_context_menu_enabled",
        @"ai_voice_fab_call_history_entry_enabled",
        @"ai_voice_live_video_pip_enabled",
        @"aura_painted_door_stickers_enabled",
        @"calling_voicemail_enabled",
        @"channel_poll_status_card_enabled",
        @"channel_status_consumption_music_enabled",
        @"channel_status_creation_music_enabled",
        @"context_menu_keyboard_fix_enabled",
        @"enable_call_transfer_notification",
        @"enable_in_call_more_menu_ios",
        @"enable_in_call_picker_merged_list",
        @"enable_more_menu_in_vc",
        @"enable_new_call_invite",
        @"enable_new_call_link_representation",
        @"enable_reasoning_status",
        @"enable_schedule_call_from_calls_tab",
        @"enable_scheduled_calls_v2_entry_points_creation",
        @"enable_sticker_lottie_reader_in_tray",
        @"group_invite_contacts_count_enabled",
        @"group_status_forward_to_channels_enabled",
        @"ios_enable_klipy_sticker_search",
        @"ios_guest_calling_representation_enabled",
        @"ios_klipy_logging_enabled",
        @"ios_linked_devices_empty_states_ui_refresh_enabled",
        @"ios_reaction_keyboard_uilabel_enabled",
        @"isInternalUser",
        @"isMetaEmployeeOrInternalTester",
        @"is_meta_employee_or_internal_tester",
        @"meta_catalog_linking_m3_enabled",
        @"newsletter_forward_counter_ui_enabled",
        @"payments_selection_ui_updates_enabled",
        @"push_name_in_community_groups_picker_enabled",
        @"should_use_select_multiple_context_menu",
        @"smb_custom_url_display_v2_enabled",
        @"smb_verified_badge_parity_changes_enabled",
        @"smbi_premium_broadcast_enabled",
        @"status_animated_music_stickers_enabled",
        @"status_animated_sticker_with_static_media_enabled",
        @"status_viewer_redesign",
        @"view_replies_follow_up_ui_enabled",
        @"waffle_companions_enabled",
        @"wagr_debug_mode_enabled",
        @"wb_standard_layout_enabled_ios"
    ];
}

// Bundle VCs
static WAGramBundleVC *LGBundle(void)        { return [[WAGramBundleVC alloc]initWithTitle:@"Liquid Glass"     flags:LGFlags()         icon:@"🌊" prefixDesc:@"34 flags. WDSLiquidGlass hooks + WAABProperties diretos."]; }
static WAGramBundleVC *PrivacyBundle(void)   { return [[WAGramBundleVC alloc]initWithTitle:@"Privacy"          flags:PrivacyFlags()     icon:@"🔐" prefixDesc:@"Rows ocultos em Privacy Settings: Defense Mode, Passkey, Username, Interop, Calling Privacy, Link Preview."]; }
static WAGramBundleVC *ChatBundle(void)      { return [[WAGramBundleVC alloc]initWithTitle:@"Chats"            flags:ChatFlags()        icon:@"💬" prefixDesc:@"Features no Chat: Translation, About redesign, AI Threads (3 flags juntos!), Scheduled, Channels variant, AI Wallpaper/Themes."]; }
static WAGramBundleVC *NotifBundle(void)     { return [[WAGramBundleVC alloc]initWithTitle:@"Notifications"    flags:NotifFlags()       icon:@"🔔" prefixDesc:@"Notificações: channel notif, ringtones custom, HQ images, video preview."]; }
static WAGramBundleVC *TabBarBundle(void)    { return [[WAGramBundleVC alloc]initWithTitle:@"Tab Bar"          flags:TabBarFlags()      icon:@"⊞" prefixDesc:@"Tab bar: AI tab, Community tab v2, Updates tab pills, Channels in updates."]; }
static WAGramBundleVC *SettingsBundle(void)  { return [[WAGramBundleVC alloc]initWithTitle:@"Settings Rows"    flags:SettingsRowFlags() icon:@"⚙️" prefixDesc:@"Células ocultas em Settings principal: Lists, Events, Waffle, Payments, FOA Bookmarks, WA Plus, Me Tab."]; }
static WAGramBundleVC *AuraBundle(void)      { return [[WAGramBundleVC alloc]initWithTitle:@"WA Plus (Aura)"   flags:AuraFlags()        icon:@"⭐" prefixDesc:@"WA Plus: todos os flags aura_* + benefit hooks. Após ativar → reiniciar → Settings > Subscriptions. NÃO abre VC direto (crash SIGTRAP)."]; }
static WAGramBundleVC *FinalExtrasBundle(void) { return [[WAGramBundleVC alloc]initWithTitle:@"WAGram Final Extras" flags:WAGramFinalExtraFlags() icon:@"＋" prefixDesc:@"Flags que estavam na WAGram_final e não apareciam no v6: Calls, Status, Channels, SMB, UI e dogfood extras. Usa o mesmo WAAB runtime hook."]; }

static WAGRABFlagBrowserVC *AIBrowser(void) {
    return [[WAGRABFlagBrowserVC alloc]initWithTitle:@"AI & Meta AI" flags:@[
        @"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_redesign_enabled",@"ai_psi_ux_enabled",
        @"ai_dynamic_mode_selector_enabled",@"ai_dynamic_model_branding_enabled",
        @"ai_incognito_mode_enabled",@"ai_incognito_mode_disappearing_messages_enabled",
        @"ai_incognito_mode_personalization_enabled",@"ai_incognito_media_input_enabled",
        @"non_anonymous_incognito_enable",@"ai_translate_messages_enabled",
        @"ai_side_chat_enabled",@"ai_side_chat_search_starter_enabled",
        @"ai_side_chat_summarization_enabled",@"ai_side_chat_writing_help_enabled",
        @"ai_side_chat_image_creation_enabled",@"ai_side_chat_media_input_enabled",
        @"ai_hatch_integration_enabled",@"ai_hatch_integration_tab_enabled",
        @"ai_hatch_commands_enabled",@"ai_chat_threads_enabled",
        @"ai_chat_threads_infra_enabled",@"ai_chat_thread_capability_enabled",
        @"ai_chat_threads_multiplayer_enabled",@"ai_chat_threads_pin_enabled",
        @"ai_chat_threads_side_sheet_enabled",@"ai_rewrite_in_edit_message_enabled",
        @"ai_rich_response_tables_enabled",@"ai_contextual_writing_help_enabled",
        @"ai_group_participation_enabled",@"ai_group_participation_send_enabled",
        @"ai_voice_image_input_enabled",@"ai_voice_live_video_input_enabled",
        @"ai_voice_ptt_coexistence_enabled",@"ai_imagine_bottom_sheet_enabled",
        @"ai_imagine_in_media_editor_enabled",@"ai_genai_imagine_intent_ar_effects_v3_enabled",
        @"ai_genai_imagine_intent_status_v3_enabled",@"ai_bot_imagine_me_enabled",
        @"ai_subscription_enabled",@"ai_llama_premium_model_main_gate_enabled",
    ]];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramMenuVC — root
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGramMenuVC ()
@property (nonatomic, strong) NSArray *rows; // tuples: @[title, subtitle, vc/action]
@end

@implementation WAGramMenuVC

- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title=@"WAGram";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor=BG();
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"sw"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"nav"];
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"btn"];
}
- (void)close {[self dismissViewControllerAnimated:YES completion:nil];}

// ─── Section/row data ─────────────────────────────────────────────────────────
typedef enum { kSwitch=0, kNav=1, kButton=2 } RowType;

struct RowDef { RowType type; NSString *title; NSString *detail; id target; NSString *prefKey; void (^action)(BOOL); };

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 4;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{
    if (s==0) return 4;   // Masters (switches)
    if (s==1) return 9;   // Feature bundles
    if (s==2) return 4;   // More features
    return 2;              // Actions
}
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    NSString *titles[]={@"CONTROLES",@"FEATURE BUNDLES",@"MAIS FEATURES",@""};
    NSString *icons[]={@"",@"",@"",@""};
    if (!titles[s].length) return nil;
    return [[WAGRHeader alloc]initWithTitle:titles[s] icon:icons[s]];
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s {
    return (s==3)?8:32;
}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    if (s==0) return @"Cada bundle ativa TODOS os flags do grupo com um toggle, persiste em NSUserDefaults, e usa hook direto em WAABProperties (igual ao LiquidGlass). Reiniciar após ativar.";
    if (s==1) return @"Toca numa row para ver flags individuais e ativar/desativar separadamente.";
    return nil;
}

- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if (ip.section==0) {
        // Master switches
        NSString *titles[] = {@"Liquid Glass", @"Employee / Dogfood", @"Native Debug Menu", @"WAAB Observer"};
        NSString *subs[]   = {@"34 flags: WDSLiquidGlass + WAABProperties", @"isMetaEmployee · isInternalUser · graphQLEmpC1", @"isDebugMenuAllowed = YES", @"Log all WAABProperties calls"};
        NSString *keys[]   = {WA_PREF_LIQUID_GLASS, kWAGREmployeeMaster, kWAGRDebugMenuNative, WA_PREF_AB_OBSERVER};
        UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
        c.backgroundColor=CELLBG();
        c.textLabel.text=titles[ip.row]; c.textLabel.textColor=UIColor.labelColor;
        c.detailTextLabel.text=subs[ip.row]; c.detailTextLabel.textColor=SECONDARY();
        c.selectionStyle=UITableViewCellSelectionStyleNone;
        UISwitch *sw=[[UISwitch alloc]init];
        sw.on=WAEnabled(keys[ip.row]); sw.onTintColor=ACCENT();
        sw.tag=(NSInteger)ip.row;
        [sw addTarget:self action:@selector(masterChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView=sw; return c;
    }
    if (ip.section==1) {
        // Bundle rows
        NSArray *bundles=@[LGBundle(),PrivacyBundle(),ChatBundle(),NotifBundle(),TabBarBundle(),SettingsBundle(),AuraBundle(),FinalExtrasBundle(),AIBrowser()];
        NSArray *names=@[@"🌊  Liquid Glass",@"🔐  Privacy",@"💬  Chat",@"🔔  Notificações",@"⊞  Tab Bar",@"⚙️  Settings Rows",@"⭐  WA Plus / Aura",@"＋  WAGram Final Extras",@"🤖  AI & Meta AI"];
        UIViewController *vc = bundles[ip.row];
        NSString *name = names[ip.row];
        
        // Count active flags
        NSArray *flags = nil;
        if ([vc isKindOfClass:WAGRABFlagBrowserVC.class])
            flags = ((WAGRABFlagBrowserVC*)vc).allFlags;
        NSUInteger on = flags ? WAGRBundleActiveCount(flags) : 0;
        NSUInteger total = flags.count;
        
        UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        c.backgroundColor=CELLBG();
        c.textLabel.text=name; c.textLabel.textColor=UIColor.labelColor;
        c.detailTextLabel.text = on>0 ? [NSString stringWithFormat:@"%lu/%lu ✓",(unsigned long)on,(unsigned long)total]
                                      : [NSString stringWithFormat:@"%lu flags",(unsigned long)total];
        c.detailTextLabel.textColor=on>0?GREEN():SECONDARY();
        c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        objc_setAssociatedObject(c, (void*)0xB, vc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return c;
    }
    if (ip.section==2) {
        NSArray *names=@[@"🔎  Todos os Flags WAAB",@"🧬  Runtime não-WAAB",@"👤  Dogfood / Internal",@"🐛  Debug & Sistema"];
        UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        c.backgroundColor=CELLBG(); c.textLabel.text=names[ip.row]; c.textLabel.textColor=UIColor.labelColor;
        c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return c;
    }
    // Actions section
    NSString *actionTitles[]={@"Reiniciar WhatsApp",@"Reset TODOS os overrides"};
    UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    c.backgroundColor=CELLBG();
    c.textLabel.text=actionTitles[ip.row];
    c.textLabel.textColor = ip.row==0 ? UIColor.systemRedColor : UIColor.systemOrangeColor;
    c.textLabel.textAlignment=NSTextAlignmentCenter;
    return c;
}

- (void)masterChanged:(UISwitch*)sw {
    NSString *keys[]={WA_PREF_LIQUID_GLASS,kWAGREmployeeMaster,kWAGRDebugMenuNative,WA_PREF_AB_OBSERVER};
    WASetEnabled(keys[sw.tag], sw.isOn);
    switch (sw.tag) {
        case 0: WAGRLGPrefsDidChange(); break;
        case 1: WAGRDogfoodEnsureHooksInstalled(); WAGRNativeSurfaceEnsureHooksInstalled(); break;
        case 2: WAGRDebugMenuEnsureHooksInstalled(); WAGRNativeSurfaceEnsureHooksInstalled(); break;
        case 3: WAGRWAABEnsureHooksInstalled(); break;
    }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    
    if (ip.section==1) {
        UITableViewCell *c=[tv cellForRowAtIndexPath:ip];
        UIViewController *vc=objc_getAssociatedObject(c,(void*)0xB);
        if (vc) [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (ip.section==2) {
        if (ip.row==0) {
            WAGRABFlagBrowserVC *vc=[[WAGRABFlagBrowserVC alloc]initWithTitle:@"Todos os Flags WAAB" flags:@[]];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (ip.row==1) {
            WAGRRuntimeMethodBrowserVC *vc=[[WAGRRuntimeMethodBrowserVC alloc]initWithTitle:@"Runtime não-WAAB" tokens:@[@"aura",@"subscription",@"benefit",@"premium",@"liquid",@"theme",@"icon",@"ringtone",@"sticker",@"business",@"smb",@"ai",@"plus",@"debug",@"internal",@"dogfood",@"multiaccount",@"accountswitcher",@"waffle",@"paa"]];
            [self.navigationController pushViewController:vc animated:YES];
        } else if (ip.row==2) {
            [self showDogfoodVC];
        } else {
            Alert(@"Sistema", [NSString stringWithFormat:@"%@\n\n%@\n\n%@", WAGRWAABDiagnosticText(), WAGRDogfoodDiagnosticText(), WAGRNativeSurfaceDiagnosticText()]);
        }
        return;
    }
    if (ip.section==3) {
        if (ip.row==0) {
            UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Reiniciar?" message:@"Reinicia o WhatsApp para aplicar hooks que precisam de startup." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Reiniciar" style:UIAlertActionStyleDestructive handler:^(id _){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{exit(0);});
            }]];
            [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
            [TopVC() presentViewController:a animated:YES completion:nil];
        } else {
            NSUserDefaults *ud=NSUserDefaults.standardUserDefaults;
            NSUInteger n=0;
            for (NSString *k in [[ud dictionaryRepresentation]allKeys])
                if ([k hasPrefix:@"wagr."]) { [ud removeObjectForKey:k]; n++; }
            [ud synchronize];
            [self.tableView reloadData];
            Alert(@"Reset",[NSString stringWithFormat:@"%lu entradas removidas.",(unsigned long)n]);
        }
    }
}

- (void)showDogfoodVC {
    // Simple dogfood VC with switches
    UITableViewController *vc=[[UITableViewController alloc]initWithStyle:UITableViewStyleInsetGrouped];
    vc.title=@"Dogfood / Internal";
    vc.tableView.backgroundColor=BG();
    // Implement as a basic browser of dogfood flags
    WAGRABFlagBrowserVC *browser=[[WAGRABFlagBrowserVC alloc]initWithTitle:@"Dogfood Flags" flags:@[
        @"is_internal_tester",@"mobile_config_debug_internal",@"dogfooder_diagnostics",
        @"ios_internal_hall_enabled",@"defense_mode_available",
        @"visible_message_drop_placeholder_enabled_internal_only",@"sections_in_help_menu",
    ]];
    [self.navigationController pushViewController:browser animated:YES];
}

@end
