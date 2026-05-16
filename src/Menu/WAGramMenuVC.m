// WAGramMenuVC.m — WAGram v4
// All curated menus now use WAGRABFlagBrowserVC (same logic as the working browser).
// WAGramSubMenuVC kept only for master switches / direct ObjC hook controls.
// WhatsApp Plus / WAAuraGating section added.

#import "WAGramMenuVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"

static UIColor *WAGRAccent(void)  { return [UIColor systemBlueColor]; }
static UIColor *WAGRBG(void)      { return [UIColor systemGroupedBackgroundColor]; }
static UIColor *WAGRCellBG(void)  { return [UIColor secondarySystemGroupedBackgroundColor]; }

// ── NSUserDefaults on/off helpers ─────────────────────────────────────────────
static BOOL WAGRFlagIsOn(NSString *flag) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)] isEqualToString:@"on"];
}
static void WAGRFlagSet(NSString *flag, BOOL on) {
    if (!flag.length) return;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (on) [ud setObject:@"on" forKey:WAGRKey(flag)];
    else    [ud removeObjectForKey:WAGRKey(flag)];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    if ([flag containsString:@"liquid_glass"] || [flag isEqualToString:@"status_viewer_redesign_enabled"])
        WAGRLGPrefsDidChange();
    if ([flag hasPrefix:@"aura_"] || [flag containsString:@"subscription"])
        WAGRWAABEnsureHooksInstalled();  // re-ensure after aura flags
    if ([flag containsString:@"internal"] || [flag containsString:@"dogfood"])
        WAGRDogfoodEnsureHooksInstalled();
}

// ── Helpers ───────────────────────────────────────────────────────────────────
static UIViewController *WAGRTopVC(void) {
    UIViewController *c = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows)
            if (w.isKeyWindow && w.rootViewController) { c = w.rootViewController; break; }
        if (c) break;
    }
    while (YES) {
        if (c.presentedViewController) { c = c.presentedViewController; continue; }
        if ([c isKindOfClass:UINavigationController.class]) {
            UIViewController *v = ((UINavigationController *)c).visibleViewController;
            if (v && v != c) { c = v; continue; }
        }
        if ([c isKindOfClass:UITabBarController.class]) {
            UIViewController *v = ((UITabBarController *)c).selectedViewController;
            if (v && v != c) { c = v; continue; }
        }
        break;
    }
    return c;
}
static void WAGRAlert(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title?:@"WAGram"
                                                                   message:msg?:@""
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault
                                           handler:^(id _){ UIPasteboard.generalPasteboard.string=msg?:@""; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [WAGRTopVC() presentViewController:a animated:YES completion:nil];
    });
}

// ── Model ─────────────────────────────────────────────────────────────────────
@implementation WAGramRow
+ (instancetype)switchWithTitle:(NSString *)t subtitle:(NSString *)s key:(NSString *)k action:(void(^)(BOOL))a {
    WAGramRow *r=[self new]; r.title=t; r.subtitle=s; r.prefsKey=k; r.style=WAGramRowStyleSwitch; r.action=a; return r;
}
+ (instancetype)waabWithTitle:(NSString *)t key:(NSString *)k {
    WAGramRow *r=[self new]; r.title=t; r.subtitle=k; r.waabKey=k; r.style=WAGramRowStyleWAABFlag; return r;
}
+ (instancetype)buttonWithTitle:(NSString *)t action:(void(^)(BOOL))a {
    WAGramRow *r=[self new]; r.title=t; r.style=WAGramRowStyleButton; r.action=a; return r;
}
+ (instancetype)navWithTitle:(NSString *)t subtitle:(NSString *)s target:(UIViewController *)vc {
    WAGramRow *r=[self new]; r.title=t; r.subtitle=s; r.style=WAGramRowStyleNavigation; r.navTarget=vc; return r;
}
@end

@implementation WAGramSectionDef
+ (instancetype)sectionWithHeader:(NSString *)h footer:(NSString *)f rows:(NSArray<WAGramRow *> *)rows {
    WAGramSectionDef *s=[self new]; s.header=h; s.footer=f; s.rows=rows?:@[]; return s;
}
@end

// ── Section header ─────────────────────────────────────────────────────────────
@interface WAGRHeaderView : UIView
- (instancetype)initWithTitle:(NSString *)title;
@end
@implementation WAGRHeaderView { UILabel *_lbl; }
- (instancetype)initWithTitle:(NSString *)title {
    self = [super init];
    _lbl = [[UILabel alloc] init];
    _lbl.translatesAutoresizingMaskIntoConstraints = NO;
    _lbl.text = [title uppercaseString];
    _lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _lbl.textColor = WAGRAccent();
    [self addSubview:_lbl];
    [NSLayoutConstraint activateConstraints:@[
        [_lbl.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:20],
        [_lbl.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-6],
        [_lbl.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-16],
    ]];
    return self;
}
@end

static NSString *const kIDSW  = @"wg_sw";
static NSString *const kIDNAV = @"wg_nav";
static NSString *const kIDBTN = @"wg_btn";
static NSString *const kIDAB  = @"wg_ab";

// ═════════════════════════════════════════════════════════════════════════════
// WAGRABFlagBrowserVC  ← THE WORKING PATH, used for ALL feature flag sections
// ═════════════════════════════════════════════════════════════════════════════
static const char kBrowserKey = 0;

@interface WAGRABFlagBrowserVC () <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSString *> *allFlags;
@property (nonatomic, strong) NSArray<NSString *> *filtered;
@property (nonatomic, strong) UISearchController  *search;
@end

@implementation WAGRABFlagBrowserVC

- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags {
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title  = title;
    _allFlags   = flags ? [flags sortedArrayUsingSelector:@selector(compare:)] : @[];
    _filtered   = _allFlags;
    return self;
}

+ (NSArray<NSString *> *)runtimeFlags {
    Class cls = NSClassFromString(@"WAABProperties");
    if (!cls) return @[];
    NSMutableArray *out = [NSMutableArray array];
    unsigned int n = 0;
    Method *ms = class_copyMethodList(cls, &n);
    for (unsigned int i = 0; i < n; i++) {
        if (method_getNumberOfArguments(ms[i]) != 2) continue;
        char ret[8]={0}; method_getReturnType(ms[i], ret, 8);
        if (ret[0] != 'B' && ret[0] != 'c') continue;
        NSString *nm = NSStringFromSelector(method_getName(ms[i]));
        if ([nm containsString:@":"]) continue;
        [out addObject:nm];
    }
    free(ms);
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGRBG();
    self.tableView.rowHeight = 52;

    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar flag…";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self action:@selector(reloadFlags)];
    [self updateTitle];
    // If no flags passed, scan runtime
    if (_allFlags.count == 0) [self reloadFlags];
}

- (void)updateTitle {
    NSUInteger on = 0;
    for (NSString *f in _allFlags) if (WAGRFlagIsOn(f)) on++;
    self.title = on > 0
        ? [NSString stringWithFormat:@"%@ (%lu ✓)", self.navigationItem.backButtonTitle ?: @"Flags", (unsigned long)on]
        : (self.navigationItem.backButtonTitle ?: @"Flags");
}

- (void)reloadFlags {
    if (_allFlags.count == 0) _allFlags = [[self class] runtimeFlags];
    [self updateSearchResults:_search.searchBar.text];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    [self updateSearchResults:sc.searchBar.text];
}
- (void)updateSearchResults:(NSString *)q {
    _filtered = q.length
        ? [_allFlags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@", q]]
        : _allFlags;
    [self.tableView reloadData];
    [self updateTitle];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)_filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDAB];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kIDAB];

    NSString *flag = _filtered[(NSUInteger)ip.row];
    c.backgroundColor = WAGRCellBG();
    c.textLabel.text  = flag;
    c.textLabel.font  = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    c.textLabel.textColor = UIColor.labelColor;
    if (WAGRIsOn(flag)) { c.detailTextLabel.text = @"force ON"; c.detailTextLabel.textColor = UIColor.systemGreenColor; }
    else if (WAGRIsOff(flag)) { c.detailTextLabel.text = @"force OFF"; c.detailTextLabel.textColor = UIColor.systemRedColor; }
    else { c.detailTextLabel.text = @"system"; c.detailTextLabel.textColor = UIColor.secondaryLabelColor; }
    c.selectionStyle = UITableViewCellSelectionStyleNone;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = WAGRFlagIsOn(flag);
    sw.onTintColor = WAGRAccent();
    objc_setAssociatedObject(sw, &kBrowserKey, flag, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView = sw;
    return c;
}

- (void)toggled:(UISwitch *)sw {
    NSString *flag = objc_getAssociatedObject(sw, &kBrowserKey);
    if (!flag) return;
    WAGRFlagSet(flag, sw.isOn);
    [self.tableView reloadData];
    [self updateTitle];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if ((NSUInteger)ip.row >= _filtered.count) return;
    NSString *flag = _filtered[(NSUInteger)ip.row];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:flag
                                                               message:@"Escolha o estado do override. System remove a chave do NSUserDefaults."
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Force ON" style:UIAlertActionStyleDefault handler:^(__unused id _) {
        WAGRSet(flag, @"on");
        WAGRWAABEnsureHooksInstalled();
        if ([flag containsString:@"liquid_glass"] || [flag isEqualToString:@"status_viewer_redesign_enabled"]) WAGRLGPrefsDidChange();
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Force OFF" style:UIAlertActionStyleDefault handler:^(__unused id _) {
        WAGRSet(flag, @"off");
        WAGRWAABEnsureHooksInstalled();
        if ([flag containsString:@"liquid_glass"] || [flag isEqualToString:@"status_viewer_redesign_enabled"]) WAGRLGPrefsDidChange();
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"System / remover override" style:UIAlertActionStyleDestructive handler:^(__unused id _) {
        WAGRSet(flag, nil);
        WAGRWAABEnsureHooksInstalled();
        if ([flag containsString:@"liquid_glass"] || [flag isEqualToString:@"status_viewer_redesign_enabled"]) WAGRLGPrefsDidChange();
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

// ═════════════════════════════════════════════════════════════════════════════
// WAGramSubMenuVC — only for master switches & direct hook controls
// ═════════════════════════════════════════════════════════════════════════════
@interface WAGramSubMenuVC ()
@property (nonatomic, strong) NSArray<WAGramSectionDef *> *sections;
@end

@implementation WAGramSubMenuVC
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *> *)sections title:(NSString *)title {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _sections = sections ?: @[];
    self.title = title ?: @"";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGRBG();
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv  { return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_sections[(NSUInteger)s].rows.count; }

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSString *h = _sections[(NSUInteger)s].header;
    return h.length ? [[WAGRHeaderView alloc] initWithTitle:h] : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].header.length ? 36 : 0;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];

    if (row.style == WAGramRowStyleSwitch) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDSW];
        if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kIDSW];
        c.backgroundColor = WAGRCellBG();
        c.textLabel.text = row.title; c.textLabel.textColor = UIColor.labelColor;
        c.detailTextLabel.text = row.subtitle; c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = row.prefsKey ? WAEnabled(row.prefsKey) : NO;
        sw.onTintColor = WAGRAccent();
        sw.tag = (ip.section<<16)|ip.row;
        [sw addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        return c;
    }
    if (row.style == WAGramRowStyleNavigation) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDNAV];
        if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kIDNAV];
        c.backgroundColor = WAGRCellBG();
        c.textLabel.text = row.title; c.textLabel.textColor = UIColor.labelColor;
        c.detailTextLabel.text = row.subtitle; c.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDBTN];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kIDBTN];
    c.backgroundColor = WAGRCellBG();
    c.textLabel.text = row.title; c.textLabel.textColor = WAGRAccent();
    c.textLabel.textAlignment = NSTextAlignmentLeft;
    c.accessoryType = UITableViewCellAccessoryNone; c.accessoryView = nil;
    return c;
}

- (void)swChanged:(UISwitch *)sw {
    NSUInteger sec=(NSUInteger)(sw.tag>>16), row=(NSUInteger)(sw.tag&0xFFFF);
    WAGramRow *r = _sections[sec].rows[row];
    if (r.prefsKey) WASetEnabled(r.prefsKey, sw.isOn);
    if (r.action)   r.action(sw.isOn);
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style == WAGramRowStyleNavigation && row.navTarget)
        [self.navigationController pushViewController:row.navTarget animated:YES];
    else if (row.style == WAGramRowStyleButton && row.action)
        row.action(NO);
}
@end

// ═════════════════════════════════════════════════════════════════════════════
// Helper macros
// ═════════════════════════════════════════════════════════════════════════════
#define SW(k,t,s,a)   [WAGramRow switchWithTitle:(t) subtitle:(s) key:(k) action:(a)]
#define BTN(t,a)      [WAGramRow buttonWithTitle:(t) action:(a)]
#define NAV(t,s,vc)   [WAGramRow navWithTitle:(t) subtitle:(s) target:(vc)]
#define SEC(h,f,...)  [WAGramSectionDef sectionWithHeader:(h) footer:(f) rows:@[__VA_ARGS__]]

// ── Browser VC builder — ALL curated menus use this ───────────────────────────
static WAGRABFlagBrowserVC *browser(NSString *title, NSArray<NSString *> *flags) {
    WAGRABFlagBrowserVC *vc = [[WAGRABFlagBrowserVC alloc] initWithTitle:title flags:flags];
    vc.navigationItem.backButtonTitle = title;
    return vc;
}

// ═════════════════════════════════════════════════════════════════════════════
// Curated flag lists — ALL go through WAGRABFlagBrowserVC (the working path)
// ═════════════════════════════════════════════════════════════════════════════

// ── Liquid Glass (13 confirmed direct methods on WAABProperties + WDSLiquidGlass)
static WAGRABFlagBrowserVC *LGBrowser(void) {
    return browser(@"🔵 Liquid Glass", @[
        @"ios_liquid_glass_enabled",
        @"ios_liquid_glass_launched",
        @"ios_liquid_glass_media_m0",
        @"ios_liquid_glass_m1",
        @"ios_liquid_glass_m_1_5",
        @"ios_liquid_glass_m_1_5_context_menu",
        @"ios_liquid_glass_larger_composer",
        @"ios_liquid_glass_media_editor_enabled",
        @"ios_liquid_glass_calling_improvement_enabled",
        @"ios_liquid_glass_reduce_transparency",
        @"ios_liquid_glass_fixes_for_older_ios",
        @"ios_liquid_glass_workaround_attachment_tray",
        @"ios_liquid_glass_chat_top_bar_m2_enabled",
        @"ios_liquid_glass_enable_new_chatbar_ux",
        @"status_viewer_redesign_enabled",
    ]);
}

// ── WhatsApp Plus / WAAuraGating ──────────────────────────────────────────────
// Confirmed from WAAuraGating module in SharedModules:
// GatedBenefitProvider has isAppIconsBenefitActive, isAppThemesBenefitActive, etc.
// WAABProperties has aura_* flags.
static WAGRABFlagBrowserVC *PlusBrowser(void) {
    return browser(@"⭐ WhatsApp Plus", @[
        // WAABProperties WAAB flags for Aura (gating layer 1)
        @"aura_enabled",
        @"aura_settings_row_enabled",       // shows Subscriptions row in Settings
        @"aura_subscription_simulation_enabled",  // simulation = no real payment needed
        @"aura_logging_enabled",
        @"aura_kill_switch",                // ← must be FORCE OFF for Plus to work
        // Custom app icon
        @"aura_app_icon_enabled",
        @"aura_app_icon_benefit_active",
        // Custom themes
        @"aura_app_themes_enabled",
        @"aura_app_themes_benefit_active",
        @"aura_app_themes_chat_checkmark_themed_enabled",
        @"aura_app_themes_new_selection_flow_enabled",
        @"aura_app_themes_share_extension_themed_enabled",
        @"aura_app_themes_status_ring_enabled",
        @"aura_app_themes_illustration_lottie_enabled",
        @"aura_apple_watch_app_theme_enabled",
        @"aura_apple_watch_app_themes_enabled",
        // Pin more chats
        @"aura_pinned_chats_enabled",
        @"aura_pinned_chats_benefit_active",
        @"aura_pinned_chats_targeted_nux_force",
        // Enhanced lists
        @"aura_enhanced_lists_enabled",
        @"aura_enhanced_lists_benefit_active",
        // Custom ringtones
        @"aura_ringtones_enabled",
        @"aura_ringtones_benefit_active",
        @"aura_ringtones_per_chat_enabled",
        // Premium stickers
        @"aura_stickers_enabled",
        @"aura_stickers_benefit_active",
        @"aura_stickers_old_client_block_enabled",
        @"aura_stickers_overlay_animation_enabled",
        @"aura_painted_door_stickers_enabled",
        @"aura_premium_stickers_killswitch",  // ← must be force OFF
        // AI subscription
        @"ai_subscription_enabled",
        @"ai_subscription_imagine_intent_enabled",
        // Expanded formatting (Plus feature)
        @"isExpandedFormattingPlusEnabled",   // direct method on some class
        // Eligibility
        @"isEligibleForSubscriptions",
        @"isAppIconsBenefitActive",
        @"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive",
        @"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive",
        @"isStickersBenefitActive",
        @"isSubscribedToAiBenefit",
        @"isAISubscriptionEnabled",
    ]);
}

// ── AI & Meta AI ──────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *AIBrowser(void) {
    return browser(@"🤖 AI & Meta AI", @[
        @"ai_meta_ai_in_app_tab_main_gate_enabled",
        @"ai_home_redesign_enabled",
        @"ai_psi_ux_enabled",
        @"ai_dynamic_mode_selector_enabled",
        @"ai_dynamic_model_branding_enabled",
        @"ai_tab_glyph_icon_enabled",
        @"ai_tab_perf_optimizations_enabled",
        @"ai_search_bar_2025_redesign_enabled",
        @"ai_chat_list_search_enabled",
        @"ai_incognito_mode_enabled",
        @"ai_incognito_mode_disappearing_messages_enabled",
        @"ai_incognito_mode_personalization_enabled",
        @"ai_incognito_media_input_enabled",
        @"non_anonymous_incognito_enable",
        @"ai_translate_messages_enabled",
        @"ai_side_chat_enabled",
        @"ai_side_chat_search_starter_enabled",
        @"ai_side_chat_summarization_enabled",
        @"ai_side_chat_writing_help_enabled",
        @"ai_side_chat_image_creation_enabled",
        @"ai_side_chat_media_input_enabled",
        @"ai_side_chat_contextual_suggestions_enabled",
        @"ai_side_chat_animation_enabled",
        @"ai_hatch_integration_enabled",
        @"ai_hatch_integration_tab_enabled",
        @"ai_hatch_commands_enabled",
        @"ai_hatch_video_upload_enabled",
        @"ai_chat_threads_enabled",
        @"ai_chat_threads_side_sheet_enabled",
        @"ai_chat_threads_multiplayer_enabled",
        @"ai_chat_threads_pin_enabled",
        @"ai_rewrite_in_edit_message_enabled",
        @"ai_rewrite_in_context_menu_enabled",
        @"ai_rich_response_tables_enabled",
        @"ai_contextual_writing_help_enabled",
        @"ai_group_participation_enabled",
        @"ai_group_participation_send_enabled",
        @"ai_group_multi_modal_enabled",
        @"ai_voice_image_input_enabled",
        @"ai_voice_live_video_input_enabled",
        @"ai_voice_live_video_pip_enabled",
        @"ai_voice_ptt_coexistence_enabled",
        @"ai_voice_fab_call_history_entry_enabled",
        @"ai_imagine_bottom_sheet_enabled",
        @"ai_imagine_in_media_editor_enabled",
        @"ai_imagine_video_edit_in_media_editor_enabled",
        @"ai_genai_imagine_intent_ar_effects_v3_enabled",
        @"ai_genai_imagine_intent_attachment_tray_enabled",
        @"ai_genai_imagine_intent_status_v3_enabled",
        @"ai_imagine_intents_status_mimicry_sender_enabled",
        @"ai_imagine_intents_status_mimicry_receiver_enabled",
        @"ai_bot_imagine_me_enabled",
        @"ai_bot_imagine_me_auto_capture_enabled",
        @"ai_ask_meta_ai_in_media_viewer",
        @"ai_ask_metai_in_message_long_press",
        @"ai_subscription_enabled",
        @"ai_subscription_imagine_intent_enabled",
        @"ai_llama_premium_model_main_gate_enabled",
        @"ai_fab_chat_list_refactor_enabled",
        @"ai_account_linking_enabled",
        @"ai_stickers_rebranding_enabled",
    ]);
}

// ── About / Recado ────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *AboutBrowser(void) {
    return browser(@"📝 About / Recado", @[
        @"evolve_about_m1_receiver_enabled",
        @"evolve_about_m1_receiver_for_new_surfaces_enabled",
    ]);
}

// ── Translation ───────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *TranslateBrowser(void) {
    return browser(@"🌐 Translation", @[
        @"ai_translate_messages_enabled",
    ]);
}

// ── Calls ─────────────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *CallsBrowser(void) {
    return browser(@"📞 Calls", @[
        @"calling_voicemail_enabled",
        @"calling_invite_expired_content_change_enabled",
        @"calling_skip_audio_session_activation_enabled",
        @"enable_schedule_call_from_calls_tab",
        @"enable_scheduled_calls_v2_entry_points_creation",
        @"enable_new_call_invite",
        @"enable_new_call_link_representation",
        @"enable_in_call_more_menu_ios",
        @"enable_in_call_picker_merged_list",
        @"enable_active_linked_group_call_add_participants",
        @"ios_guest_calling_representation_enabled",
        @"ios_new_call_list_banner_is_enabled",
        @"enable_call_transfer_notification",
        @"enable_group_call_invite_close_the_loop",
        @"enable_missed_notification_for_auto_joining_call",
        @"enable_calling_phone_number_privacy",
        @"enable_calling_username",
        @"enable_callkit_generic_handling",
        @"enable_random_scheduled_id_for_call_links",
        @"missed_call_reminder_client_filter_enabled",
        @"missed_call_reminder_notification_content_variant_enabled",
    ]);
}

// ── Status ────────────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *StatusBrowser(void) {
    return browser(@"✅ Status", @[
        @"status_viewer_redesign_enabled",
        @"status_3p_api_enabled",
        @"status_3p_api_apple_music_integration_enabled",
        @"status_bolder_tiles_enabled",
        @"status_close_friends_multi_select_enabled",
        @"status_add_yours_receiving_notifications_enabled",
        @"status_add_yours_sending_notifications_enabled",
        @"status_archive_my_status_entrypoints_enabled",
        @"status_archives_storage_screen_management_enabled",
        @"status_animated_sticker_with_static_media_enabled",
        @"status_animated_music_stickers_enabled",
        @"status_stamps_animated_stickers_enabled",
        @"status_audience_on_viewer_sheet_enabled",
        @"status_caption_edit_send_enabled",
        @"status_caption_edit_receive_enabled",
        @"channel_status_creation_music_enabled",
        @"channel_status_consumption_music_enabled",
        @"channel_poll_status_card_enabled",
        @"channel_ptt_status_card_enabled",
        @"enable_reasoning_status",
        @"add_status_bolder_tile_entrypoint_enabled",
        @"ios_status_audience_ranker_enabled",
    ]);
}

// ── Channels ──────────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *ChannelsBrowser(void) {
    return browser(@"📢 Channels", @[
        @"channel_forward_to_chat_enabled",
        @"channel_media_viewer_improvements_enabled",
        @"channel_photo_poll_receiver_enabled",
        @"channel_poll_forwarding_enabled",
        @"channel_recommendation_notification_setting_enabled",
        @"channels_archive_enabled",
        @"channels_admin_profiles_forwarding_to_status_enabled",
        @"channels_admin_profiles_receiver_enabled",
        @"channels_albums_v2_forwarding_to_status_enabled",
        @"channels_ptv_forwarding_to_status_enabled",
        @"channels_creation_enabled",
        @"channels_pinning_nudge_updates_tab_enabled",
        @"channels_admin_reply_enabled",
        @"channels_sticker_quick_forward_ios_enabled",
        @"newsletter_forward_counter_ui_enabled",
        @"group_status_receiver_enabled",
        @"group_status_forward_to_channels_enabled",
        @"group_status_enable_nux_new_badge",
    ]);
}

// ── Groups & Interop ──────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *GroupsBrowser(void) {
    return browser(@"👥 Groups & Interop", @[
        @"interop_group_messaging_enabled",
        @"interop_bootstrap_enabled",
        @"interop_client_ux_enabled",
        @"interop_contact_master_enabled",
        @"non_anonymous_group_participation_enable",
        @"not_allow_non_admin_sub_group_creation",
        @"group_invite_contacts_count_enabled",
        @"empty_group_creation_enabled_int",
        @"push_name_in_community_groups_picker_enabled",
        @"poll_add_option_enabled",
        @"poll_add_option_receiving_enabled",
        @"poll_creator_edit_enabled",
        @"poll_end_time_enabled",
        @"sg_message_recall_enabled",
        @"scheduled_messages_sender_enabled",
        @"scheduled_messages_receiver_enabled",
        @"ai_group_participation_enabled",
        @"ai_group_participation_send_enabled",
        @"ai_group_multi_modal_enabled",
        @"ai_group_meta_ai_null_state_capability_entrypoint_enabled",
    ]);
}

// ── Privacy & Username ────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *PrivacyBrowser(void) {
    return browser(@"🔐 Privacy & Username", @[
        @"username_suggestions_enabled",
        @"username_activation_disabled",
        @"username_enabled_on_companion",
        @"username_call_search_enabled",
        @"username_key_redesign_enabled",
        @"ios_wabi_enable_username_migration",
        @"allow_lid_contacts_privacy_settings",
        @"allow_lid_contacts_calling",
        @"allow_lid_contacts_status",
        @"enable_calling_phone_number_privacy",
        @"enable_calling_username",
        @"privacy_checkup",
        @"privacy_aware_secure_dl_logging_enabled",
        @"defense_mode_available",
        @"passkey_login",
        @"multiple_passkeys_delete_v2_enabled",
    ]);
}

// ── Messaging & Stickers ──────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *MessagingBrowser(void) {
    return browser(@"💬 Messaging & Stickers", @[
        @"scheduled_messages_sender_enabled",
        @"scheduled_messages_receiver_enabled",
        @"ios_klipy_logging_enabled",
        @"ios_enable_klipy_sticker_search",
        @"enable_sticker_lottie_reader_in_tray",
        @"ios_lottie_sticker_frame_decode_immediately_enabled",
        @"enable_sticker_lottie_reader_in_tray",
        @"aura_stickers_enabled",
        @"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",
        @"aura_painted_door_stickers_enabled",
        @"ai_rewrite_in_edit_message_enabled",
        @"ai_rewrite_in_context_menu_enabled",
        @"ai_contextual_writing_help_enabled",
        @"ai_rich_response_tables_enabled",
        @"sg_message_recall_enabled",
        @"poll_add_option_enabled",
        @"poll_creator_edit_enabled",
        @"poll_end_time_enabled",
        @"view_replies_follow_up_ui_enabled",
        @"should_use_select_multiple_context_menu",
    ]);
}

// ── UI & UX ───────────────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *UIBrowser(void) {
    return browser(@"🎨 UI & UX", @[
        @"wb_standard_layout_enabled_ios",
        @"view_replies_follow_up_ui_enabled",
        @"should_use_select_multiple_context_menu",
        @"newsletter_forward_counter_ui_enabled",
        @"context_menu_keyboard_fix_enabled",
        @"enable_more_menu_in_vc",
        @"ios_reaction_keyboard_uilabel_enabled",
        @"ai_tab_glyph_icon_enabled",
        @"channels_pinning_nudge_updates_tab_enabled",
        @"new_number_not_on_whatsapp_dialog_enabled",
        @"ios_linked_devices_empty_states_ui_refresh_enabled",
        @"payments_selection_ui_updates_enabled",
        @"ios_modal_splitview_contact_group_info_enabled",
        @"add_status_bolder_tile_entrypoint_enabled",
        @"ios_linked_devices_empty_states_ui_refresh_enabled",
    ]);
}

// ── Dogfood / Internal WAAB flags ─────────────────────────────────────────────
static WAGRABFlagBrowserVC *DogfoodWAABBrowser(void) {
    return browser(@"WAAB Dogfood Flags", @[
        @"is_internal_tester",
        @"mobile_config_debug_internal",
        @"dogfooder_diagnostics",
        @"ios_internal_hall_enabled",
        @"defense_mode_available",
        @"ios_optic_debug_indicator_enabled",
        @"visible_message_drop_placeholder_enabled_internal_only",
        @"sections_in_help_menu",
        @"dogfood_settings_enabled",
    ]);
}

// ── Premium & Business ────────────────────────────────────────────────────────
static WAGRABFlagBrowserVC *PremiumBrowser(void) {
    return browser(@"⭐ Premium & Business", @[
        @"smbi_premium_broadcast_enabled",
        @"smbi_premium_broadcast_cta_enabled",
        @"smbi_premium_broadcast_deeplink_handling_enabled",
        @"smbi_premium_broadcast_threads_in_chat_home_enabled",
        @"smbi_subscription_content_models_enabled",
        @"waffle_companions_enabled",
        @"waffle_enabled_for_unlinked_users",
        @"waffle_mobile_companions_enabled",
        @"waffle_foa_to_wa_linking_enabled",
        @"meta_catalog_linking_m3_enabled",
        @"smb_custom_url_display_v2_enabled",
        @"smb_verified_badge_parity_changes_enabled",
        @"smb_agent_chat_list_indicator_enabled",
        @"smb_agent_thread_control_notification_enabled",
    ]);
}

// ── Dogfood / Internal direct hooks ──────────────────────────────────────────

static WAGRABFlagBrowserVC *SettingsRowsBrowser(void) {
    return [[WAGRABFlagBrowserVC alloc] initWithTitle:@"Settings Rows" flags:@[
        @"lists_feature_enabled",
        @"call_favorites_enabled_companions",
        @"events_global_list",
        @"waffle_mobile_companions_enabled",
        @"waffle_enabled_for_unlinked_users",
        @"waffle_foa_to_wa_linking_enabled",
        @"isPAAEligibleForWaffle",
        @"aura_settings_row_enabled",
        @"aura_enabled",
        @"sections_in_help_menu",
        @"foa_threads_bookmarks_enabled",
        @"foa_bridges_bookmark_meta_horizon",
        @"ai_rich_response_vibes_promotion_enabled",
        @"ios_me_tab_new_user_checklist_enabled",
        @"me_tab_settings_header_enabled",
        @"wa_subscriptions_entry_point_settings_enabled",
        @"wa_subscriptions_settings_green_dot_enabled"
    ]];
}

static WAGRABFlagBrowserVC *TabBarBrowser(void) {
    return [[WAGRABFlagBrowserVC alloc] initWithTitle:@"Tab Bar / Multi Account" flags:@[
        @"sg_ios_multi_account_enabled",
        @"wa_xfam_ios_switcher_multiaccount_enabled",
        @"foa_bridges_account_switcher_ios_enabled",
        @"deletion_reason_multi_account_enabled",
        @"ai_meta_ai_in_app_tab_main_gate_enabled",
        @"ai_home_in_tab_main_gate_enabled",
        @"ai_hatch_integration_tab_enabled",
        @"ai_tab_glyph_icon_enabled",
        @"community_tab_v2_enabled",
        @"communities_remove_from_app_tab_enabled",
        @"channels_creation_entrypoint_in_updates_tab_enabled",
        @"channels_pinning_nudge_updates_tab_enabled",
        @"updates_tab_filter_pills_enabled"
    ]];
}

static WAGRABFlagBrowserVC *KillSwitchBrowser(void) {
    return [[WAGRABFlagBrowserVC alloc] initWithTitle:@"Kill Switches / Disable" flags:@[
        @"aura_kill_switch",
        @"aura_premium_stickers_killswitch",
        @"aura_stickers_old_client_block_enabled",
        @"lottie_sticker_rendering_killswitch",
        @"label_storage_chat_session_cleanup_killswitch",
        @"killswitch_vault_backup",
        @"killswitch_vault_media_offload",
        @"killswitch_vault_restore",
        @"kill_switch_groups_creation_banner_smb_enabled"
    ]];
}

static WAGRRuntimeMethodBrowserVC *RuntimeAuraBrowser(void) {
    return [[WAGRRuntimeMethodBrowserVC alloc] initWithTitle:@"Aura / Subscription Getters" tokens:@[@"aura", @"subscription", @"benefit", @"premium", @"theme", @"icon", @"ringtone", @"sticker"]];
}

static WAGRRuntimeMethodBrowserVC *RuntimeDebugBrowser(void) {
    return [[WAGRRuntimeMethodBrowserVC alloc] initWithTitle:@"Internal / Debug Getters" tokens:@[@"internal", @"debug", @"dogfood", @"employee", @"alpha", @"beta", @"developer", @"isdebug", @"isinternal"]];
}

static WAGRRuntimeMethodBrowserVC *RuntimeAllWABrowser(void) {
    return [[WAGRRuntimeMethodBrowserVC alloc] initWithTitle:@"Runtime BOOL Getters" tokens:@[@"aura", @"subscription", @"benefit", @"premium", @"liquid", @"debug", @"internal", @"dogfood", @"multiaccount", @"accountswitcher", @"waffle", @"settings", @"tab", @"chat", @"profile"]];
}

static UIViewController *DogfoodVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Direct ObjC Selector Hooks",
            @"MSHookMessageEx scan em runtime. Quando o código pergunta 'sou employee?', o hook responde SIM. Instalar estes hooks ANTES de ativar features que os consultam.",
            SW(kWAGREmployeeMaster, @"Employee Master (todos os 4)",
               @"isMetaEmployee · isInternalUser · graphQLEmpC1",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateMetaEmployee, @"isMetaEmployeeOrInternalTester",
               @"WA:136909 + SM:94927 → YES",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateMetaEmployeeSnake, @"is_meta_employee_or_internal_tester",
               @"SM:73827 → YES",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateInternalUser, @"isInternalUser",
               @"WA:94156 → YES",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateGraphQLEmpC1, @"graphQLEmployeeC1Disabled",
               @"WA:94150 → NO (= C1 enabled)",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            BTN(@"Dogfood Diagnostic", ^(BOOL _){ WAGRAlert(@"Dogfood", WAGRDogfoodDiagnosticText()); })
        ),
        SEC(@"WAAB Bool Flags",
            @"Mesma lógica do browser — acessa via WAGRABFlagBrowserVC.",
            NAV(@"Browser WAAB Dogfood Flags", @"is_internal_tester, mobile_config_debug_internal…", DogfoodWAABBrowser())
        ),
    ] title:@"Dogfood / Internal"];
}

// ── Debug / Developer Menu ────────────────────────────────────────────────────
static UIViewController *DebugMenuVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Native Debug Menu Gate",
            @"isDebugMenuAllowed em WASettingsViewController (WA:107333). ON → SettingsView_DeveloperCell aparece → WADebugMenuMain nativo do WA (com WADebugABPropertiesTableViewController — UI nativa de override).",
            SW(kWAGRDebugMenuNative, @"isDebugMenuAllowed = YES",
               @"Mostra Developer cell nas Settings",
               ^(BOOL on){ WAGRDebugMenuEnsureHooksInstalled(); }),
            BTN(@"Debug Menu Diagnostic", ^(BOOL _){ WAGRAlert(@"Debug Menu", WAGRDebugMenuDiagnosticText()); })
        ),
    ] title:@"Debug / Developer Menu"];
}

// ── System / Debug ────────────────────────────────────────────────────────────
static UIViewController *SystemVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Keychain",
            @"fishhook-based. Nunca lê kSecValueData.",
            SW(WA_PREF_KEYCHAIN_REWRITE, @"Access Group Rewrite",
               @"Fix keychain em sideload", ^(BOOL _){ WAInstallKeychainPatchIfNeeded(); }),
            SW(WA_PREF_KEYCHAIN_OBSERVER, @"Metadata Observer",
               @"Log SecItem* calls", ^(BOOL _){ WAInstallKeychainPatchIfNeeded(); }),
            BTN(@"Keychain Diagnostic", ^(BOOL _){ WAGRAlert(@"Keychain", WAKeychainAccessGroupDiagnostic()); })
        ),
        SEC(@"WAAB Observer",
            @"",
            SW(WA_PREF_AB_OBSERVER, @"WAAB Observer",
               @"Log todas as getter calls", ^(BOOL _){ WAGRWAABEnsureHooksInstalled(); }),
            BTN(@"Ver Log",          ^(BOOL _){ WAGRAlert(@"WAAB Log", WAGRABObsLog()); }),
            BTN(@"Limpar Log",       ^(BOOL _){ WAGRABObsClear(); }),
            BTN(@"WAAB Diagnostic",  ^(BOOL _){ WAGRAlert(@"WAAB", WAGRWAABDiagnosticText()); })
        ),
        SEC(@"Overrides", @"",
            SW(@"wagr_debug_mode_enabled", @"Debug Logging", @"NSLog [LiquidGlassOn]", nil),
            BTN(@"Reset TODOS os overrides", ^(BOOL _){
                NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
                NSUInteger n = 0;
                for (NSString *k in [[ud dictionaryRepresentation] allKeys])
                    if ([k hasPrefix:@"wagr.waab."]) { [ud removeObjectForKey:k]; n++; }
                [ud synchronize];
                WAGRAlert(@"Reset", [NSString stringWithFormat:@"%lu entradas removidas.", (unsigned long)n]);
            })
        ),
    ] title:@"Sistema & Debug"];
}

// ═════════════════════════════════════════════════════════════════════════════
// WAGramMenuVC — Root
// ═════════════════════════════════════════════════════════════════════════════
@interface WAGramMenuVC ()
@property (nonatomic, strong) NSArray<WAGramSectionDef *> *sections;
@end

@implementation WAGramMenuVC

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAGram";
    [self buildSections];
    return self;
}

- (void)buildSections {
    // Runtime browser (scans WAABProperties class at launch)
    WAGRABFlagBrowserVC *runtimeBrowser = [[WAGRABFlagBrowserVC alloc] initWithTitle:@"Todos os Flags" flags:@[]];

    _sections = @[
        SEC(@"Masters",
            @"LiquidGlass: Logos %hook em WDSLiquidGlass + WAABProperties. Employee/Dogfood: MSHookMessageEx em selectors ObjC. WA Plus: WAAuraGating + WAAB aura_* flags. A ordem importa: instale os gates ANTES de ativar features que os consultam.",
            SW(WA_PREF_LIQUID_GLASS, @"🔵  Liquid Glass",
               @"WDSLiquidGlass + WAABProperties direct method hooks",
               ^(BOOL _){ WAGRLGPrefsDidChange(); }),
            SW(kWAGREmployeeMaster, @"👤  Employee / Dogfood Gates",
               @"isMetaEmployee · isInternalUser · graphQLEmpC1",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDebugMenuNative, @"🐛  Native Debug Menu",
               @"isDebugMenuAllowed = YES → Developer cell",
               ^(BOOL _){ WAGRDebugMenuEnsureHooksInstalled(); }),
            SW(WA_PREF_AB_OBSERVER, @"🔍  WAAB Observer",
               @"Log all WAABProperties method calls",
               ^(BOOL _){ WAGRWAABEnsureHooksInstalled(); })
        ),
        SEC(@"Feature Flags",
            @"Todos os menus usam WAGRABFlagBrowserVC — mesma lógica que o browser completo que funciona. Toggle ON = wagr.waab.<flag> = 'on' em NSUserDefaults. Restart para features que inicializam em viewDidLoad.",
            NAV(@"🔵  Liquid Glass",        @"13 direct methods — mirror do dylib funcional",         LGBrowser()),
            NAV(@"⭐  WhatsApp Plus",        @"WAAuraGating + aura_* WAAB flags",                     PlusBrowser()),
            NAV(@"🧬  Aura Runtime Getters", @"benefits/subscription getters fora do WAAB",             RuntimeAuraBrowser()),
            NAV(@"🧩  Settings Rows",        @"subscriptions, waffle, bookmarks, help sections",         SettingsRowsBrowser()),
            NAV(@"⊞  Tab Bar / Multi Account", @"account switcher + tabs",                              TabBarBrowser()),
            NAV(@"🛑  Kill Switches",        @"force OFF para permitir, ON para bloquear",              KillSwitchBrowser()),
            NAV(@"📝  About / Recado",       @"evolve_about_m1_receiver_enabled",                      AboutBrowser()),
            NAV(@"🌐  Translation",          @"ai_translate_messages_enabled",                          TranslateBrowser()),
            NAV(@"🤖  AI & Meta AI",         @"60+ flags: incognito, side chat, hatch, imagine, voice", AIBrowser()),
            NAV(@"🎨  UI & UX",              @"15 flags",                                               UIBrowser()),
            NAV(@"💬  Messaging & Stickers", @"20 flags incl. polls, recall, stickers",                MessagingBrowser()),
            NAV(@"📞  Calls",                @"21 flags",                                               CallsBrowser()),
            NAV(@"✅  Status",               @"22 flags",                                               StatusBrowser()),
            NAV(@"📢  Channels",             @"18 flags",                                               ChannelsBrowser()),
            NAV(@"👥  Groups & Interop",     @"20 flags incl. interop, polls, scheduled",              GroupsBrowser()),
            NAV(@"🔐  Privacy & Username",   @"16 flags incl. passkey, defense",                       PrivacyBrowser()),
            NAV(@"💼  Premium & Business",   @"14 flags",                                              PremiumBrowser()),
            NAV(@"👤  Dogfood / Internal",   @"4 direct hooks + WAAB flags",                           DogfoodVC()),
            NAV(@"🐛  Debug / Dev Menu",     @"isDebugMenuAllowed · WADebugMenuMain",                   DebugMenuVC()),
            NAV(@"⚙️  Sistema & Debug",      @"Keychain, WAAB log, reset",                             SystemVC())
        ),
        SEC(@"All WAABProperties Flags",
            @"Escaneia WAABProperties em runtime (~6892 métodos). Search integrado.",
            NAV(@"🔎  Browser — Todos os Flags", @"Runtime scan + search", runtimeBrowser),
            NAV(@"🧬  Runtime BOOL Getters", @"on-demand scan; exact class+selector overrides", RuntimeAllWABrowser()),
            NAV(@"🐛  Runtime Internal/Debug", @"debug/internal/alpha/dogfood getters", RuntimeDebugBrowser()),
            NAV(@"📚  Catálogo WAAB Validado", @"lê JSON staged e agrupa bools validadas", [WAGRWAABCatalogBrowserVC new])
        ),
        SEC(@"", @"Restart fecha o WhatsApp. Necessário para features que inicializam em viewDidLoad.",
            BTN(@"Reiniciar WhatsApp", ^(BOOL _){
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reiniciar?"
                                                                           message:@"Fecha o app. Reabra para aplicar hooks de startup."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"Reiniciar"
                                                     style:UIAlertActionStyleDestructive
                                                   handler:^(id _){
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.3*NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{ exit(0); });
                }]];
                [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
                [WAGRTopVC() presentViewController:a animated:YES completion:nil];
            })
        ),
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGRBG();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_sections[(NSUInteger)s].rows.count; }

- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSString *h = _sections[(NSUInteger)s].header;
    return h.length ? [[WAGRHeaderView alloc] initWithTitle:h] : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].header.length ? 38 : 8;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];

    if (row.style == WAGramRowStyleSwitch) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDSW];
        if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kIDSW];
        c.backgroundColor = WAGRCellBG();
        c.textLabel.text = row.title; c.textLabel.textColor = UIColor.labelColor;
        c.detailTextLabel.text = row.subtitle; c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = row.prefsKey ? WAEnabled(row.prefsKey) : NO;
        sw.onTintColor = WAGRAccent();
        sw.tag = (ip.section<<16)|ip.row;
        [sw addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        return c;
    }
    if (row.style == WAGramRowStyleNavigation) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDNAV];
        if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kIDNAV];
        c.backgroundColor = WAGRCellBG();
        c.textLabel.text = row.title; c.textLabel.textColor = UIColor.labelColor;
        c.detailTextLabel.text = row.subtitle; c.detailTextLabel.textColor = UIColor.tertiaryLabelColor;
        c.detailTextLabel.font = [UIFont systemFontOfSize:13];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDBTN];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kIDBTN];
    c.backgroundColor = WAGRCellBG();
    BOOL destruct = [row.title containsString:@"Reiniciar"];
    c.textLabel.text = row.title;
    c.textLabel.textColor = destruct ? UIColor.systemRedColor : WAGRAccent();
    c.textLabel.textAlignment = NSTextAlignmentCenter;
    c.accessoryType = UITableViewCellAccessoryNone; c.accessoryView = nil;
    return c;
}

- (void)swChanged:(UISwitch *)sw {
    NSUInteger sec=(NSUInteger)(sw.tag>>16), row=(NSUInteger)(sw.tag&0xFFFF);
    WAGramRow *r = _sections[sec].rows[row];
    if (r.prefsKey) WASetEnabled(r.prefsKey, sw.isOn);
    if (r.action)   r.action(sw.isOn);
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style == WAGramRowStyleNavigation && row.navTarget)
        [self.navigationController pushViewController:row.navTarget animated:YES];
    else if (row.style == WAGramRowStyleButton && row.action)
        row.action(NO);
}
@end
