// WAGramMenuVC.m
// ─────────────────────────────────────────────────────────────────────────────
// 156 curated WAABProperties flags in 11 sections.
// Storage: wagr.waab.<key>.mode  = 0 (system) | 1 (force OFF) | 2 (force ON)
// Compatible with WAABPropsObserver.xm hook_WAABBool / hook_WAABString.
// ─────────────────────────────────────────────────────────────────────────────

#import "WAGramMenuVC.h"
#import "../WAUtils.h"

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramRow
// ═══════════════════════════════════════════════════════════════════════════════
@implementation WAGramRow
+ (instancetype)switchWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key action:(void (^)(BOOL))action {
    WAGramRow *r=[self new]; r.title=title; r.subtitle=subtitle; r.prefsKey=key; r.style=WAGramRowStyleSwitch; r.action=action; return r;
}
+ (instancetype)waabFlagWithTitle:(NSString *)title subtitle:(NSString *)subtitle waabKey:(NSString *)waabKey {
    WAGramRow *r=[self new]; r.title=title; r.subtitle=subtitle; r.waabKey=waabKey; r.style=WAGramRowStyleWAABFlag; return r;
}
+ (instancetype)buttonWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(BOOL))action {
    WAGramRow *r=[self new]; r.title=title; r.subtitle=subtitle; r.style=WAGramRowStyleButton; r.action=action; return r;
}
+ (instancetype)navWithTitle:(NSString *)title subtitle:(NSString *)subtitle target:(UIViewController *)target {
    WAGramRow *r=[self new]; r.title=title; r.subtitle=subtitle; r.style=WAGramRowStyleNavigation; r.navTarget=target; return r;
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramSectionDef
// ═══════════════════════════════════════════════════════════════════════════════
@implementation WAGramSectionDef
+ (instancetype)sectionWithHeader:(NSString *)h footer:(NSString *)f rows:(NSArray<WAGramRow *> *)rows {
    WAGramSectionDef *s=[self new]; s.header=h; s.footer=f; s.rows=rows?:@[]; return s;
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAAB tri-state helpers
// mode: 0=SYS  1=OFF  2=ON
// ═══════════════════════════════════════════════════════════════════════════════
static NSInteger WAGRModeGet(NSString *key) {
    if (!key.length) return 0;
    return [[NSUserDefaults standardUserDefaults] integerForKey:WAGRWAABKeyMode(key)];
}
static void WAGRModeSet(NSString *key, NSInteger mode) {
    if (!key.length) return;
    if (mode == 0) [[NSUserDefaults standardUserDefaults] removeObjectForKey:WAGRWAABKeyMode(key)];
    else [[NSUserDefaults standardUserDefaults] setInteger:mode forKey:WAGRWAABKeyMode(key)];
}
static void WAGRModeCycle(NSString *key) { WAGRModeSet(key, (WAGRModeGet(key) + 1) % 3); }

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════
static UIViewController *WAGRTopVC(void) {
    UIViewController *cur=nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene*)sc).windows) if (w.isKeyWindow&&w.rootViewController){cur=w.rootViewController;break;}
        if(cur) break;
    }
    while(YES){
        if(cur.presentedViewController){cur=cur.presentedViewController;continue;}
        if([cur isKindOfClass:UINavigationController.class]){UIViewController*v=((UINavigationController*)cur).visibleViewController;if(v&&v!=cur){cur=v;continue;}}
        if([cur isKindOfClass:UITabBarController.class]){UIViewController*v=((UITabBarController*)cur).selectedViewController;if(v&&v!=cur){cur=v;continue;}}
        break;
    }
    return cur;
}
static void WAGRAlert(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a=[UIAlertController alertControllerWithTitle:title?:@"WAGram" message:msg?:@"" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction*_){UIPasteboard.generalPasteboard.string=msg?:@"";}]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [WAGRTopVC() presentViewController:a animated:YES completion:nil];
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramSubMenuVC
// ═══════════════════════════════════════════════════════════════════════════════
static NSString *const kSW=@"SW", *const kNAV=@"NAV", *const kBTN=@"BTN", *const kWAAB=@"WAAB";

@interface WAGramSubMenuVC ()
@property (nonatomic, strong) NSArray<WAGramSectionDef *> *sections;
@end
@implementation WAGramSubMenuVC
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *> *)sections title:(NSString *)title {
    if(!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _sections=sections?:@[]; self.title=title?:@""; return self;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv {return(NSInteger)_sections.count;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s {return(NSInteger)_sections[(NSUInteger)s].rows.count;}
- (NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)s {return _sections[(NSUInteger)s].header;}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {return _sections[(NSUInteger)s].footer;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    NSString *rid=(row.style==WAGramRowStyleSwitch)?kSW:(row.style==WAGramRowStyleNavigation)?kNAV:(row.style==WAGramRowStyleWAABFlag)?kWAAB:kBTN;
    UITableViewCell *cell=[tv dequeueReusableCellWithIdentifier:rid];
    if(!cell){UITableViewCellStyle sty=row.subtitle.length?UITableViewCellStyleSubtitle:UITableViewCellStyleDefault;cell=[[UITableViewCell alloc]initWithStyle:sty reuseIdentifier:rid];}
    cell.textLabel.text=row.title; cell.detailTextLabel.text=row.subtitle;
    cell.accessoryType=UITableViewCellAccessoryNone; cell.accessoryView=nil;
    if(row.style==WAGramRowStyleSwitch){
        UISwitch*sw=[[UISwitch alloc]init];
        sw.on=row.prefsKey?[[NSUserDefaults standardUserDefaults]boolForKey:row.prefsKey]:NO;
        sw.tag=(ip.section<<16)|ip.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=sw; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if(row.style==WAGramRowStyleWAABFlag){
        NSInteger mode=WAGRModeGet(row.waabKey);
        NSArray *labels=@[@"SYS",@"OFF",@"ON"];
        NSArray *colors=@[UIColor.secondaryLabelColor,UIColor.systemRedColor,UIColor.systemGreenColor];
        UILabel *badge=[[UILabel alloc]init];
        badge.font=[UIFont boldSystemFontOfSize:12]; badge.text=labels[(NSUInteger)mode]; badge.textColor=colors[(NSUInteger)mode];
        [badge sizeToFit]; cell.accessoryView=badge;
    } else if(row.style==WAGramRowStyleNavigation){
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.textColor=self.view.tintColor;
    }
    return cell;
}
- (void)switchChanged:(UISwitch*)sw {
    NSUInteger sec=(NSUInteger)(sw.tag>>16), row=(NSUInteger)(sw.tag&0xFFFF);
    WAGramRow *r=_sections[sec].rows[row];
    if(r.prefsKey) WASetEnabled(r.prefsKey, sw.isOn);
    if(r.action) r.action(sw.isOn);
}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if(row.style==WAGramRowStyleWAABFlag && row.waabKey.length){
        WAGRModeCycle(row.waabKey);
        WAGRWAABEnsureHooksInstalled();
        [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    } else if(row.style==WAGramRowStyleNavigation && row.navTarget){
        [self.navigationController pushViewController:row.navTarget animated:YES];
    } else if(row.style==WAGramRowStyleButton && row.action){
        row.action(NO);
    }
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// Sub-menu builders — one per section
// ═══════════════════════════════════════════════════════════════════════════════
#define WAAB(key, title, sub) [WAGramRow waabFlagWithTitle:(title) subtitle:(sub) waabKey:(key)]
#define SW(prefKey, title, sub, act) [WAGramRow switchWithTitle:(title) subtitle:(sub) key:(prefKey) action:(act)]
#define BTN(title, sub, act) [WAGramRow buttonWithTitle:(title) subtitle:(sub) action:(act)]
#define SEC(hdr, ftr, ...) [WAGramSectionDef sectionWithHeader:(hdr) footer:(ftr) rows:@[__VA_ARGS__]]

static UIViewController *LGSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Bool flags (boolForKey:defaultValue:)",
            @"ios_liquid_glass_enabled etc. Bool bool → SYS / OFF / ON.",
            WAAB(@"ios_liquid_glass_enabled",              @"LG Enabled",                  @"ios_liquid_glass_enabled [bool sm]"),
            WAAB(@"ios_liquid_glass_chat_top_bar_m2_enabled", @"LG Chat Top Bar M2",       @"[bool sm]"),
            WAAB(@"ios_liquid_glass_enable_new_chatbar_ux",@"LG New Chatbar UX",           @"[bool sm]"),
            WAAB(@"ios_liquid_glass_media_editor_enabled", @"LG Media Editor",             @"[bool sm]")
        ),
        SEC(@"String flags (stringForKey:defaultValue: → 'enabled')",
            @"mode=ON injects 'enabled'; mode=OFF injects '' (empty = disabled).",
            WAAB(@"ios_liquid_glass_launched",             @"LG Launched",                 @"[string sm]"),
            WAAB(@"ios_liquid_glass_m1",                   @"LG M1",                       @"[string sm]"),
            WAAB(@"ios_liquid_glass_m_1_5",                @"LG M1.5",                     @"[string sm]"),
            WAAB(@"ios_liquid_glass_m_1_5_context_menu",   @"LG M1.5 Context Menu",        @"[string sm]"),
            WAAB(@"ios_liquid_glass_larger_composer",      @"LG Larger Composer",          @"[string sm]"),
            WAAB(@"ios_liquid_glass_reduce_transparency",  @"LG Reduce Transparency",      @"[string sm]"),
            WAAB(@"ios_liquid_glass_m_2_action_tile",      @"LG M2 Action Tile",           @"[string sm]"),
            WAAB(@"ios_liquid_glass_m_2_chips",            @"LG M2 Chips",                 @"[string sm]"),
            WAAB(@"ios_liquid_glass_m_2_lightweight_dialogs",@"LG M2 Lightweight Dialogs", @"[string sm]"),
            WAAB(@"ios_liquid_glass_m_2_text_layout",      @"LG M2 Text Layout",           @"[string sm]"),
            WAAB(@"ios_liquid_glass_workaround_attachment_tray",   @"LG Fix: Attachment Tray",   @"[string sm]"),
            WAAB(@"ios_liquid_glass_workaround_hides_bottombar",   @"LG Fix: Hides Bottom Bar",  @"[string sm]"),
            WAAB(@"ios_liquid_glass_workaround_topbar_appearance", @"LG Fix: Top Bar Appearance",@"[string sm]")
        ),
    ] title:@"LiquidGlass Flags"];
}

static UIViewController *UISubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"UI & UX",
            @"General UI experiments. ✓exe = present in main executable.",
            WAAB(@"wb_standard_layout_enabled_ios",           @"WB Standard Layout",          @"✓exe"),
            WAAB(@"view_replies_follow_up_ui_enabled",        @"View Replies Follow-Up UI",   @"✓exe"),
            WAAB(@"should_use_select_multiple_context_menu",  @"Select Multiple Context Menu",@"✓exe"),
            WAAB(@"newsletter_forward_counter_ui_enabled",    @"Channel Forward Counter",     @"✓exe"),
            WAAB(@"context_menu_keyboard_fix_enabled",        @"Context Menu Keyboard Fix",   @"✓exe"),
            WAAB(@"enable_more_menu_in_vc",                   @"More Menu in Video Calls",    @"✓exe"),
            WAAB(@"ios_reaction_keyboard_uilabel_enabled",    @"Reaction Keyboard Label",     @"✓exe"),
            WAAB(@"ai_tab_glyph_icon_enabled",                @"AI Tab Glyph Icon",           @"✓exe"),
            WAAB(@"channels_pinning_nudge_updates_tab_enabled",@"Channels Pinning Nudge",     @"✓exe"),
            WAAB(@"new_number_not_on_whatsapp_dialog_enabled",@"New Number Dialog",           @"✓exe"),
            WAAB(@"ios_linked_devices_empty_states_ui_refresh_enabled",@"Linked Devices UI Refresh",@"✓exe"),
            WAAB(@"aura_stickers_enabled",                    @"Aura Stickers",               @"sm"),
            WAAB(@"aura_stickers_overlay_animation_enabled",  @"Aura Stickers Overlay",      @"✓exe"),
            WAAB(@"aura_painted_door_stickers_enabled",       @"Aura Painted-Door Stickers",  @"✓exe"),
            WAAB(@"aura_apple_watch_app_themes_enabled",      @"Aura Apple Watch Themes",     @"sm"),
            WAAB(@"aura_app_themes_chat_checkmark_themed_enabled",@"Chat Checkmark Themed",   @"sm"),
            WAAB(@"payments_selection_ui_updates_enabled",    @"Payments Selection UI",       @"✓exe")
        ),
    ] title:@"UI & UX"];
}

static UIViewController *MsgSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Messaging & Chat",
            @"Schedule messages, GIF/sticker search, editing, animated stickers.",
            WAAB(@"scheduled_messages_sender_enabled",       @"Schedule Messages",           @"✓exe"),
            WAAB(@"ios_klipy_logging_enabled",               @"Klipy GIF (Logging)",         @"✓exe"),
            WAAB(@"ios_enable_klipy_sticker_search",         @"Klipy Sticker Search",        @"✓exe"),
            WAAB(@"enable_sticker_lottie_reader_in_tray",    @"Lottie Stickers in Tray",     @"✓exe"),
            WAAB(@"ios_lottie_sticker_frame_decode_immediately_enabled",@"Lottie Frame Decode Immediately",@"sm"),
            WAAB(@"status_animated_music_stickers_enabled",  @"Animated Music Stickers",     @"sm"),
            WAAB(@"status_animated_sticker_with_static_media_enabled",@"Animated Sticker+Static",@"✓exe"),
            WAAB(@"status_stamps_animated_stickers_enabled", @"Animated Stamp Stickers",     @"sm"),
            WAAB(@"ai_rewrite_in_edit_message_enabled",      @"AI Rewrite in Edit",          @"✓exe"),
            WAAB(@"ai_rewrite_in_context_menu_enabled",      @"AI Rewrite Context Menu",     @"✓exe"),
            WAAB(@"ai_contextual_writing_help_enabled",      @"AI Contextual Writing Help",  @"✓exe"),
            WAAB(@"ai_side_chat_writing_help_enabled",       @"AI Side Chat Writing Help",   @"✓exe"),
            WAAB(@"ai_imagine_intent_ptt_enabled",           @"AI Imagine in PTT",           @"✓exe"),
            WAAB(@"ai_imagine_intent_v3_ptt_enabled",        @"AI Imagine v3 PTT",           @"✓exe"),
            WAAB(@"ai_imagine_system_message_enabled",       @"AI Imagine System Message",   @"✓exe"),
            WAAB(@"ai_rich_response_tables_enabled",         @"AI Rich Response Tables",     @"✓exe")
        ),
    ] title:@"Messaging & Chat"];
}

static UIViewController *CallsSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Calls",
            @"Voicemail, scheduled calls, call links and in-call UX.",
            WAAB(@"calling_voicemail_enabled",                @"Voicemail / Missed-Call VM",  @"✓exe"),
            WAAB(@"missed_call_reminder_client_filter_enabled",@"Missed Call Reminder",       @"sm"),
            WAAB(@"missed_call_reminder_notification_content_variant_enabled",@"Missed Call Notif Variant",@"sm"),
            WAAB(@"enable_schedule_call_from_calls_tab",      @"Schedule Call (Calls Tab)",  @"✓exe"),
            WAAB(@"enable_scheduled_calls_v2_entry_points_creation",@"Scheduled Calls v2",    @"✓exe"),
            WAAB(@"enable_new_call_invite",                   @"New Call Invite",             @"✓exe"),
            WAAB(@"enable_new_call_link_representation",      @"New Call Link UI",            @"✓exe"),
            WAAB(@"enable_in_call_more_menu_ios",             @"In-Call More Menu",           @"✓exe"),
            WAAB(@"enable_in_call_picker_merged_list",        @"In-Call Merged Picker",       @"✓exe"),
            WAAB(@"enable_active_linked_group_call_add_participants",@"Add Participants (Linked)",@"✓exe"),
            WAAB(@"ios_guest_calling_representation_enabled", @"Guest Calling UI",            @"✓exe"),
            WAAB(@"ios_new_call_list_banner_is_enabled",      @"New Call List Banner",        @"✓exe"),
            WAAB(@"enable_call_transfer_notification",        @"Call Transfer Notification",  @"✓exe"),
            WAAB(@"enable_group_call_invite_close_the_loop",  @"Group Call Invite CtL",       @"✓exe"),
            WAAB(@"enable_missed_notification_for_auto_joining_call",@"Missed Notif Auto-Join",@"✓exe"),
            WAAB(@"ai_voice_fab_call_history_entry_enabled",  @"AI Voice FAB Call History",  @"✓exe")
        ),
    ] title:@"Calls"];
}

static UIViewController *ChannelsSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Channels & Status",
            @"Newsletter forward counter, group status, admin profiles, animated stickers.",
            WAAB(@"newsletter_forward_counter_ui_enabled",           @"Channel Forward Counter",         @"✓exe"),
            WAAB(@"channels_admin_profiles_forwarding_to_status_enabled",@"Admin Profiles → Status",    @"✓exe"),
            WAAB(@"channels_albums_v2_forwarding_to_status_enabled", @"Albums v2 → Status",             @"✓exe"),
            WAAB(@"channels_ptv_forwarding_to_status_enabled",       @"PTV → Status",                   @"✓exe"),
            WAAB(@"group_status_receiver_enabled",                   @"Group Status Receiver",           @"✓exe"),
            WAAB(@"group_status_forward_to_channels_enabled",        @"Group Status → Channels",         @"✓exe"),
            WAAB(@"group_status_enable_nux_new_badge",               @"Group Status NUX Badge",          @"✓exe"),
            WAAB(@"channel_poll_status_card_enabled",                @"Channel Poll Status Card",        @"✓exe"),
            WAAB(@"channel_status_creation_music_enabled",           @"Status Music (Create)",           @"✓exe"),
            WAAB(@"channel_status_consumption_music_enabled",        @"Status Music (View)",             @"✓exe"),
            WAAB(@"enable_reasoning_status",                         @"Reasoning Status",                @"✓exe"),
            WAAB(@"add_status_bolder_tile_entrypoint_enabled",       @"Bolder Status Tile",             @"✓exe"),
            WAAB(@"ios_status_audience_ranker_enabled",              @"Status Audience Ranker",          @"✓exe"),
            WAAB(@"ai_genai_imagine_intent_status_v3_enabled",       @"AI Imagine in Status v3",         @"✓exe"),
            WAAB(@"ai_imagine_intents_status_mimicry_sender_enabled",@"AI Status Mimicry (Send)",        @"✓exe"),
            WAAB(@"ai_imagine_intents_status_mimicry_receiver_enabled",@"AI Status Mimicry (Recv)",     @"✓exe")
        ),
    ] title:@"Channels & Status"];
}

static UIViewController *AISubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Meta AI — Main Gate & Home",
            @"AI tab, home redesign, dynamic models.",
            WAAB(@"ai_meta_ai_in_app_tab_main_gate_enabled",  @"Meta AI Tab (Main Gate)",   @"✓exe"),
            WAAB(@"ai_home_redesign_enabled",                 @"AI Home Redesign",          @"✓exe"),
            WAAB(@"ai_dynamic_mode_selector_enabled",         @"AI Dynamic Mode Selector",  @"✓exe"),
            WAAB(@"ai_dynamic_model_branding_enabled",        @"AI Dynamic Model Branding", @"✓exe"),
            WAAB(@"ai_psi_ux_enabled",                        @"AI PSI UX",                 @"✓exe")
        ),
        SEC(@"Incognito AI Chat",
            @"Zuckerberg's announced Incognito Meta AI Chat feature.",
            WAAB(@"ai_incognito_mode_enabled",                @"Incognito AI Chat",                   @"sm"),
            WAAB(@"ai_incognito_mode_disappearing_messages_enabled",@"Incognito Disappearing Msgs",  @"sm"),
            WAAB(@"ai_incognito_mode_personalization_enabled",@"Incognito Personalization",           @"sm"),
            WAAB(@"ai_incognito_media_input_enabled",         @"Incognito Media Input",               @"sm"),
            WAAB(@"non_anonymous_incognito_enable",           @"Non-Anon Incognito",                  @"✓exe")
        ),
        SEC(@"AI Side Chat & Threads",
            @"Side chat panel and threaded AI conversations.",
            WAAB(@"ai_side_chat_enabled",                     @"AI Side Chat",              @"✓exe"),
            WAAB(@"ai_side_chat_search_starter_enabled",      @"Side Chat Search",          @"✓exe"),
            WAAB(@"ai_side_chat_summarization_enabled",       @"Side Chat Summarize",       @"✓exe"),
            WAAB(@"ai_side_chat_writing_help_enabled",        @"Side Chat Writing Help",    @"✓exe"),
            WAAB(@"ai_side_chat_image_creation_enabled",      @"Side Chat Image Create",    @"✓exe"),
            WAAB(@"ai_chat_threads_enabled",                  @"AI Chat Threads",           @"✓exe"),
            WAAB(@"ai_chat_threads_side_sheet_enabled",       @"AI Threads Side Sheet",     @"✓exe")
        ),
        SEC(@"AI Imagine",
            @"AI-powered image generation in media editor, attachment tray and status.",
            WAAB(@"ai_imagine_bottom_sheet_enabled",          @"AI Imagine Bottom Sheet",            @"✓exe"),
            WAAB(@"ai_imagine_expand_in_media_editor_enabled",@"AI Imagine in Media Editor",         @"✓exe"),
            WAAB(@"ai_imagine_in_media_editor_enabled",       @"AI Imagine Media Editor",            @"✓exe"),
            WAAB(@"ai_imagine_video_edit_in_media_editor_enabled",@"AI Imagine Video Edit",          @"✓exe"),
            WAAB(@"ai_genai_imagine_intent_ar_effects_v3_enabled",@"AI AR Effects v3",               @"✓exe"),
            WAAB(@"ai_genai_imagine_intent_attachment_tray_enabled",@"AI Imagine Attachment Tray",  @"✓exe"),
            WAAB(@"ai_bot_imagine_me_enabled",                @"AI Imagine Me",                      @"✓exe")
        ),
        SEC(@"AI Voice",
            @"AI voice assistant capabilities.",
            WAAB(@"ai_voice_image_input_enabled",             @"AI Voice Image Input",      @"✓exe"),
            WAAB(@"ai_voice_live_video_input_enabled",        @"AI Voice Live Video",       @"✓exe"),
            WAAB(@"ai_voice_live_video_pip_enabled",          @"AI Voice PiP",              @"✓exe"),
            WAAB(@"ai_voice_ptt_coexistence_enabled",         @"AI Voice + PTT Coexist",    @"✓exe"),
            WAAB(@"ai_hatch_integration_enabled",             @"AI Hatch Integration",      @"✓exe"),
            WAAB(@"ai_hatch_integration_tab_enabled",         @"AI Hatch Tab",              @"✓exe")
        ),
    ] title:@"AI & Meta AI"];
}

static UIViewController *PrivacySubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Privacy & Usernames",
            @"Username rollout, private calling, LID migration. Most exe-confirmed.",
            WAAB(@"username_suggestions_enabled",             @"Username Suggestions",          @"✓exe"),
            WAAB(@"username_enabled_on_companion",            @"Usernames on Companion",        @"✓exe"),
            WAAB(@"username_call_search_enabled",             @"Username Call Search",          @"✓exe"),
            WAAB(@"username_group_mutation_enabled",          @"Username Group Mutation",       @"✓exe"),
            WAAB(@"username_group_learning_enabled",          @"Username Group Learning",       @"✓exe"),
            WAAB(@"username_key_redesign_enabled",            @"Username Key Redesign",         @"✓exe"),
            WAAB(@"enable_calling_phone_number_privacy",      @"Phone Privacy in Calls",        @"✓exe"),
            WAAB(@"enable_calling_username",                  @"Username Calling",              @"✓exe"),
            WAAB(@"ios_wabi_enable_username_migration",       @"Username Migration",            @"✓exe"),
            WAAB(@"privacy_settings_about_lid_migration_enable",@"Privacy About LID Mig.",     @"✓exe"),
            WAAB(@"allow_lid_contacts_privacy_settings",      @"LID Contacts Privacy Settings",@"✓exe"),
            WAAB(@"privacy_aware_secure_dl_logging_enabled",  @"Privacy-Aware Secure DL Log",  @"✓exe")
        ),
    ] title:@"Privacy & Usernames"];
}

static UIViewController *GroupsSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Groups & Communities",
            @"AI participation, interop messaging, community tools.",
            WAAB(@"ai_group_participation_enabled",           @"AI Group Participation",      @"✓exe"),
            WAAB(@"ai_group_participation_send_enabled",      @"AI Group Participation Send", @"✓exe"),
            WAAB(@"ai_group_multi_modal_enabled",             @"AI Group Multimodal",         @"✓exe"),
            WAAB(@"ai_group_meta_ai_null_state_capability_entrypoint_enabled",@"AI Group Null State",@"✓exe"),
            WAAB(@"interop_group_messaging_enabled",          @"Interop Group Messaging",     @"✓exe"),
            WAAB(@"non_anonymous_group_participation_enable", @"Non-Anon Group Participation",@"✓exe"),
            WAAB(@"not_allow_non_admin_sub_group_creation",   @"Only Admins Create Sub-Groups",@"✓exe"),
            WAAB(@"group_invite_contacts_count_enabled",      @"Group Invite Count",          @"✓exe"),
            WAAB(@"empty_group_creation_enabled_int",         @"Empty Group Creation",        @"✓exe"),
            WAAB(@"ios_modal_splitview_contact_group_info_enabled",@"iPad Modal Group Info",  @"✓exe"),
            WAAB(@"push_name_in_community_groups_picker_enabled",@"Push Name in Community",   @"✓exe")
        ),
    ] title:@"Groups & Communities"];
}

static UIViewController *PremiumSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Premium & Business",
            @"WhatsApp Premium broadcast, Waffle companions, Meta catalog.",
            WAAB(@"smbi_premium_broadcast_enabled",            @"Premium Broadcast",           @"✓exe"),
            WAAB(@"smbi_premium_broadcast_cta_enabled",        @"Premium Broadcast CTA",       @"✓exe"),
            WAAB(@"smbi_premium_broadcast_deeplink_handling_enabled",@"Premium Broadcast Deeplink",@"✓exe"),
            WAAB(@"smbi_subscription_content_models_enabled",  @"Subscription Content Models",@"✓exe"),
            WAAB(@"waffle_companions_enabled",                  @"Waffle Companions",          @"✓exe"),
            WAAB(@"waffle_enabled_for_unlinked_users",          @"Waffle for Unlinked Users",  @"✓exe"),
            WAAB(@"waffle_mobile_companions_enabled",           @"Waffle Mobile Companions",   @"✓exe"),
            WAAB(@"waffle_foa_to_wa_linking_enabled",           @"FOA → WA Linking",           @"✓exe"),
            WAAB(@"meta_catalog_linking_m3_enabled",            @"Meta Catalog Linking M3",    @"✓exe"),
            WAAB(@"smb_custom_url_display_v2_enabled",          @"SMB Custom URL v2",          @"✓exe"),
            WAAB(@"smb_verified_badge_parity_changes_enabled",  @"SMB Verified Badge",         @"✓exe"),
            WAAB(@"aura_apple_watch_app_theme_enabled",         @"Apple Watch App Themes",     @"sm")
        ),
    ] title:@"Premium & Business"];
}

static UIViewController *DogfoodSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Dogfood Gates",
            @"Direct ObjC selectors on WAABProperties (policy: dogfood-gate). Controlled by the master 'Dogfood / Employee Gates' toggle. These are NOT WAAB overrides — they're method hooks installed by WAEmployeeDogfoodHooks.xm.",
            BTN(@"isMetaEmployeeOrInternalTester",    @"Selector ✓exe — returns YES when master ON", ^(BOOL _){
                WAGRAlert(@"Dogfood Gate Info", @"isMetaEmployeeOrInternalTester: direct ObjC selector hook via MSHookMessageEx on WAABProperties. Controlled by 'Dogfood / Employee Gates' master toggle, not WAAB override system.");
            }),
            BTN(@"isInternalUser",                    @"Selector ✓exe — returns YES when master ON", ^(BOOL _){
                WAGRAlert(@"Dogfood Gate Info", @"isInternalUser: direct ObjC selector. Returns YES when master ON.");
            }),
            BTN(@"graphQLEmployeeC1Disabled",         @"Selector ✓exe — returns NO when master ON", ^(BOOL _){
                WAGRAlert(@"Dogfood Gate Info", @"graphQLEmployeeC1Disabled: gate meaning 'is C1 disabled?'. Returns NO (= C1 enabled) when master ON.");
            }),
            BTN(@"is_meta_employee_or_internal_tester",@"Selector sm — returns YES when master ON", ^(BOOL _){
                WAGRAlert(@"Dogfood Gate Info", @"is_meta_employee_or_internal_tester: confirmed in SharedModules. Returns YES when master ON.");
            })
        ),
        SEC(@"Dogfood Bool Flags (via boolForKey:)",
            @"These use the standard WAAB override system.",
            WAAB(@"is_internal_tester",                    @"is_internal_tester",                @"✓exe"),
            WAAB(@"username_dogfooding_pn_privacy_enabled",@"Username Dogfood PN Privacy",       @"✓exe"),
            WAAB(@"visible_message_drop_placeholder_enabled_internal_only",@"Message Drop Placeholder",@"✓exe"),
            WAAB(@"dogfooder_diagnostics",                 @"Dogfooder Diagnostics",             @"sm"),
            WAAB(@"ios_internal_hall_enabled",             @"iOS Internal Hall",                 @"sm"),
            WAAB(@"mobile_config_debug_internal",          @"MobileConfig Debug (Internal)",     @"sm")
        ),
    ] title:@"Dogfood / Employee"];
}

static UIViewController *DebugSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Keychain Observer",
            @"fishhook-based. Logs SecItemAdd/Copy/Update/Delete metadata — never kSecValueData. Also rewrites kSecAttrAccessGroup on sideload if a real group was detected.",
            SW(WA_PREF_KEYCHAIN_REWRITE, @"Keychain Access Group Rewrite", @"Fix keychain on sideload by rewriting accessGroup", ^(BOOL on){
                WAInstallKeychainPatchIfNeeded();
            }),
            SW(WA_PREF_KEYCHAIN_OBSERVER, @"Keychain Metadata Observer", @"Log metadata for all SecItem calls (no kSecValueData)", ^(BOOL on){
                WAInstallKeychainPatchIfNeeded();
            }),
            BTN(@"Keychain Diagnostics", @"Show bundle, accessGroup, hook status", ^(BOOL _){
                WAGRAlert(@"Keychain Diagnostics", WAKeychainAccessGroupDiagnostic());
            })
        ),
        SEC(@"WAAB Observer & Logging",
            @"Logs WAABProperties getter calls. Ring buffer: 200 entries.",
            SW(WA_PREF_AB_OBSERVER, @"WAAB Observer", @"Log all boolForKey:/stringForKey: calls on WAABProperties", ^(BOOL on){
                WAGRWAABEnsureHooksInstalled();
            }),
            BTN(@"View WAAB Log", @"Last 200 getter calls", ^(BOOL _){
                WAGRAlert(@"WAAB Log", WAGRABObsLog());
            }),
            BTN(@"Clear WAAB Log", @"Erase ring buffer", ^(BOOL _){
                WAGRABObsClear();
            }),
            BTN(@"WAAB Diagnostics", @"Hook status + active overrides count", ^(BOOL _){
                WAGRAlert(@"WAAB Diagnostics", WAGRWAABDiagnosticText());
            })
        ),
        SEC(@"Misc",
            @"",
            SW(@"wagr_debug_mode_enabled", @"Verbose Debug Logging", @"WALog() to Console.app — filter [LiquidGlassOn]", nil),
            BTN(@"Dogfood Hook Diagnostics", @"Which selectors were hooked", ^(BOOL _){
                WAGRAlert(@"Dogfood Diagnostics", WAGRDogfoodDiagnosticText());
            }),
            BTN(@"Reset ALL WAAB Overrides", @"Remove all wagr.waab.*.mode entries", ^(BOOL _){
                NSUserDefaults *ud=NSUserDefaults.standardUserDefaults;
                NSDictionary *all=[ud dictionaryRepresentation];
                NSUInteger n=0;
                for(NSString *k in all){if([k hasPrefix:@"wagr.waab."]){[ud removeObjectForKey:k];n++;}}
                WAGRAlert(@"Reset", [NSString stringWithFormat:@"Removed %lu override entries.", (unsigned long)n]);
            })
        ),
    ] title:@"Debug"];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramMenuVC — root
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGramMenuVC ()
@property (nonatomic, strong) NSArray<WAGramSectionDef *> *sections;
@end

@implementation WAGramMenuVC

- (instancetype)init {
    if(!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAGram";
    _sections = @[
        SEC(@"WAGram — Masters",
            @"Enable WAAB Hooks to activate any flag override below. All default OFF.",
            SW(WA_PREF_LIQUID_GLASS, @"LiquidGlass (master)", @"Applies UserDefaults override + method hooks for LG", ^(BOOL on){
                WAGRLGPrefsDidChange();
            }),
            SW(WA_PREF_EMPLOYEE_MASTER, @"Dogfood / Employee Gates", @"isMetaEmployeeOrInternalTester · isInternalUser · graphQLEmployeeC1Disabled", ^(BOOL on){
                WAGRDogfoodEnsureHooksInstalled();
            }),
            [WAGramRow navWithTitle:@"🔵  LiquidGlass Flags"        subtitle:@"17 flags — bool + string overrides via WAABProperties"       target:LGSubVC()],
            [WAGramRow navWithTitle:@"🎨  UI & UX"                  subtitle:@"17 flags"                                                    target:UISubVC()],
            [WAGramRow navWithTitle:@"💬  Messaging & Chat"         subtitle:@"16 flags"                                                    target:MsgSubVC()],
            [WAGramRow navWithTitle:@"📞  Calls"                    subtitle:@"16 flags"                                                    target:CallsSubVC()],
            [WAGramRow navWithTitle:@"📢  Channels & Status"        subtitle:@"16 flags"                                                    target:ChannelsSubVC()],
            [WAGramRow navWithTitle:@"🤖  AI & Meta AI"             subtitle:@"31 flags incl. Incognito AI Chat"                           target:AISubVC()],
            [WAGramRow navWithTitle:@"🔐  Privacy & Usernames"      subtitle:@"12 flags"                                                    target:PrivacySubVC()],
            [WAGramRow navWithTitle:@"👥  Groups & Communities"     subtitle:@"11 flags"                                                    target:GroupsSubVC()],
            [WAGramRow navWithTitle:@"⭐  Premium & Business"       subtitle:@"12 flags"                                                    target:PremiumSubVC()],
            [WAGramRow navWithTitle:@"🐾  Dogfood / Employee"       subtitle:@"4 gates + 6 bool flags"                                     target:DogfoodSubVC()],
            [WAGramRow navWithTitle:@"🔧  Debug"                    subtitle:@"Keychain observer, WAAB log, reset"                         target:DebugSubVC()]
        ),
    ];
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv {return(NSInteger)_sections.count;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s {return(NSInteger)_sections[(NSUInteger)s].rows.count;}
- (NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)s {return _sections[(NSUInteger)s].header;}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {return _sections[(NSUInteger)s].footer;}

- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    NSString *rid=(row.style==WAGramRowStyleSwitch)?kSW:(row.style==WAGramRowStyleNavigation)?kNAV:kBTN;
    UITableViewCell *cell=[tv dequeueReusableCellWithIdentifier:rid];
    if(!cell){UITableViewCellStyle sty=row.subtitle.length?UITableViewCellStyleSubtitle:UITableViewCellStyleDefault;cell=[[UITableViewCell alloc]initWithStyle:sty reuseIdentifier:rid];}
    cell.textLabel.text=row.title; cell.detailTextLabel.text=row.subtitle;
    cell.detailTextLabel.numberOfLines=2; cell.accessoryType=UITableViewCellAccessoryNone; cell.accessoryView=nil;
    if(row.style==WAGramRowStyleSwitch){
        UISwitch*sw=[[UISwitch alloc]init];
        sw.on=row.prefsKey?WAEnabled(row.prefsKey):NO;
        sw.tag=(ip.section<<16)|ip.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=sw; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if(row.style==WAGramRowStyleNavigation){
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.textColor=self.view.tintColor;
    }
    return cell;
}

- (void)switchChanged:(UISwitch*)sw {
    NSUInteger sec=(NSUInteger)(sw.tag>>16), row=(NSUInteger)(sw.tag&0xFFFF);
    WAGramRow *r=_sections[sec].rows[row];
    if(r.prefsKey) WASetEnabled(r.prefsKey, sw.isOn);
    if(r.action) r.action(sw.isOn);
}

- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if(row.style==WAGramRowStyleNavigation&&row.navTarget)
        [self.navigationController pushViewController:row.navTarget animated:YES];
    else if(row.style==WAGramRowStyleButton&&row.action)
        row.action(NO);
}
@end
