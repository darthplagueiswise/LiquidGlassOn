// WAGramMenuVC.m — WAGram v5
// Clean WhatsApp-style dark UI — no subtitle clutter in root nav rows.
// All 34 liquid_glass_* flags, Aura native VC launcher.

#import "WAGramMenuVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"

// ── Theme ─────────────────────────────────────────────────────────────────────
// Pure black background matching WhatsApp dark mode exactly
static UIColor *WAGRBG(void)        { return UIColor.systemBackgroundColor; }
static UIColor *WAGRGroupBG(void)   { return UIColor.secondarySystemBackgroundColor; }
static UIColor *WAGRAccent(void)    { return UIColor.systemBlueColor; }
static UIColor *WAGRDestructive(void) { return UIColor.systemRedColor; }

// ── Storage ───────────────────────────────────────────────────────────────────
static BOOL WAGRFlagIsOn(NSString *f) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(f)] isEqualToString:@"on"];
}
static void WAGRFlagSet(NSString *f, BOOL on) {
    if (!f.length) return;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (on) [ud setObject:@"on" forKey:WAGRKey(f)];
    else    [ud removeObjectForKey:WAGRKey(f)];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    if ([f containsString:@"liquid_glass"] || [f isEqualToString:@"status_viewer_redesign_enabled"])
        WAGRLGPrefsDidChange();
    if ([f hasPrefix:@"aura_"] || [f containsString:@"subscription"])
        WAGRAuraEnsureHooksInstalled();
    if ([f containsString:@"internal"] || [f containsString:@"dogfood"])
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
        if (c.presentedViewController){c=c.presentedViewController;continue;}
        if ([c isKindOfClass:UINavigationController.class]){UIViewController*v=((UINavigationController*)c).visibleViewController;if(v&&v!=c){c=v;continue;}}
        if ([c isKindOfClass:UITabBarController.class]){UIViewController*v=((UITabBarController*)c).selectedViewController;if(v&&v!=c){c=v;continue;}}
        break;
    }
    return c;
}
static void WAGRAlert(NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a=[UIAlertController alertControllerWithTitle:title?:@"WAGram" message:msg?:@"" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault handler:^(id _){ UIPasteboard.generalPasteboard.string=msg?:@""; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [WAGRTopVC() presentViewController:a animated:YES completion:nil];
    });
}

// ── Models ─────────────────────────────────────────────────────────────────────
@implementation WAGramRow
+ (instancetype)switchWithTitle:(NSString *)t subtitle:(NSString *)s key:(NSString *)k action:(void(^)(BOOL))a {
    WAGramRow *r=[self new];r.title=t;r.subtitle=s;r.prefsKey=k;r.style=WAGramRowStyleSwitch;r.action=a;return r;
}
+ (instancetype)waabWithTitle:(NSString *)t key:(NSString *)k {
    WAGramRow *r=[self new];r.title=t;r.subtitle=k;r.waabKey=k;r.style=WAGramRowStyleWAABFlag;return r;
}
+ (instancetype)buttonWithTitle:(NSString *)t action:(void(^)(BOOL))a {
    WAGramRow *r=[self new];r.title=t;r.style=WAGramRowStyleButton;r.action=a;return r;
}
+ (instancetype)navWithTitle:(NSString *)t subtitle:(NSString *)s target:(UIViewController *)vc {
    WAGramRow *r=[self new];r.title=t;r.subtitle=s;r.style=WAGramRowStyleNavigation;r.navTarget=vc;return r;
}
@end
@implementation WAGramSectionDef
+ (instancetype)sectionWithHeader:(NSString *)h footer:(NSString *)f rows:(NSArray<WAGramRow *> *)rows {
    WAGramSectionDef *s=[self new];s.header=h;s.footer=f;s.rows=rows?:@[];return s;
}
@end

// ── Cell IDs ──────────────────────────────────────────────────────────────────
static NSString *const kSW  = @"sw5";
static NSString *const kNAV = @"nav5";
static NSString *const kBTN = @"btn5";
static NSString *const kAB  = @"ab5";

// ── Section header: plain uppercase label, no background view ──────────────────
@interface WAGRHeader5 : UIView
- (instancetype)initWithTitle:(NSString *)title;
@end
@implementation WAGRHeader5 { UILabel *_l; }
- (instancetype)initWithTitle:(NSString *)title {
    self=[super init];
    _l=[[UILabel alloc]init]; _l.translatesAutoresizingMaskIntoConstraints=NO;
    _l.text=[title uppercaseString];
    _l.font=[UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _l.textColor=UIColor.secondaryLabelColor;
    [self addSubview:_l];
    [NSLayoutConstraint activateConstraints:@[
        [_l.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [_l.bottomAnchor  constraintEqualToAnchor:self.bottomAnchor  constant:-6],
    ]];
    return self;
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGRABFlagBrowserVC — working runtime scan browser
// Monospaced 12pt keys, 2-line cell, row height 48
// ═══════════════════════════════════════════════════════════════════════════════
static const char kBKey = 0;

@interface WAGRABFlagBrowserVC () <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSString *> *allFlags;
@property (nonatomic, strong) NSArray<NSString *> *filtered;
@property (nonatomic, strong) UISearchController  *search;
@end
@implementation WAGRABFlagBrowserVC

- (instancetype)initWithTitle:(NSString *)t flags:(NSArray<NSString *> *)flags {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title=t;
    _allFlags = flags ? [flags sortedArrayUsingSelector:@selector(compare:)] : @[];
    _filtered = _allFlags;
    return self;
}
+ (NSArray<NSString *> *)runtimeFlags {
    Class cls = NSClassFromString(@"WAABProperties");
    if (!cls) return @[];
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
    self.tableView.backgroundColor = WAGRBG();
    self.tableView.separatorInset  = UIEdgeInsetsMake(0,16,0,0);
    _search=[[UISearchController alloc]initWithSearchResultsController:nil];
    _search.searchResultsUpdater=self;
    _search.obscuresBackgroundDuringPresentation=NO;
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
    for (NSString *f in _allFlags) if (WAGRFlagIsOn(f)) on++;
    if (on>0) self.navigationItem.title=[NSString stringWithFormat:@"%@ (%lu)",self.title?:@"",(unsigned long)on];
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
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {return (NSInteger)_filtered.count;}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {return 48;}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kAB];
    if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kAB];
    NSString *flag=_filtered[(NSUInteger)ip.row];
    BOOL on=WAGRFlagIsOn(flag);
    c.backgroundColor=WAGRGroupBG();
    c.textLabel.text=flag;
    c.textLabel.font=[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    c.textLabel.textColor=on?WAGRAccent():UIColor.labelColor;
    c.textLabel.numberOfLines=2;
    c.selectionStyle=UITableViewCellSelectionStyleNone;
    UISwitch *sw=[[UISwitch alloc]init]; sw.on=on; sw.onTintColor=WAGRAccent();
    objc_setAssociatedObject(sw,&kBKey,flag,OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView=sw; return c;
}
- (void)toggled:(UISwitch *)sw {
    NSString *flag=objc_getAssociatedObject(sw,&kBKey); if (!flag) return;
    WAGRFlagSet(flag,sw.isOn);
    for (UITableViewCell *c in self.tableView.visibleCells) {
        UISwitch *csw=(UISwitch*)c.accessoryView;
        if ([csw isKindOfClass:UISwitch.class]&&[objc_getAssociatedObject(csw,&kBKey) isEqualToString:flag]) {
            c.textLabel.textColor=sw.isOn?WAGRAccent():UIColor.labelColor;
        }
    }
    [self updateBadge];
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramSubMenuVC — for master switch sections only
// ═══════════════════════════════════════════════════════════════════════════════
static const char kSubKey=0;
@interface WAGramSubMenuVC ()
@property (nonatomic, strong) NSArray<WAGramSectionDef *> *sections;
@end
@implementation WAGramSubMenuVC
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *>*)s title:(NSString *)t {
    if(!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _sections=s?:@[]; self.title=t?:@""; return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor=WAGRBG(); }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {return (NSInteger)_sections.count;}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {return (NSInteger)_sections[(NSUInteger)s].rows.count;}
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSString *h=_sections[(NSUInteger)s].header;
    return h.length?[[WAGRHeader5 alloc]initWithTitle:h]:nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].header.length?32:0;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {return _sections[(NSUInteger)s].footer;}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style==WAGramRowStyleSwitch) {
        UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kSW];
        if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSW];
        c.backgroundColor=WAGRGroupBG();
        c.textLabel.text=row.title; c.textLabel.textColor=UIColor.labelColor;
        c.detailTextLabel.text=row.subtitle; c.detailTextLabel.textColor=UIColor.secondaryLabelColor;
        c.selectionStyle=UITableViewCellSelectionStyleNone;
        UISwitch *sw=[[UISwitch alloc]init];
        sw.on=row.prefsKey?WAEnabled(row.prefsKey):NO; sw.onTintColor=WAGRAccent();
        sw.tag=(ip.section<<16)|ip.row;
        [sw addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView=sw; return c;
    }
    if (row.style==WAGramRowStyleNavigation) {
        UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kNAV];
        if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kNAV];
        c.backgroundColor=WAGRGroupBG();
        c.textLabel.text=row.title; c.textLabel.textColor=UIColor.labelColor;
        c.detailTextLabel.text=row.subtitle; c.detailTextLabel.textColor=UIColor.tertiaryLabelColor;
        c.accessoryType=UITableViewCellAccessoryDisclosureIndicator; return c;
    }
    UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kBTN];
    if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kBTN];
    c.backgroundColor=WAGRGroupBG();
    c.textLabel.text=row.title; c.textLabel.textColor=WAGRAccent();
    c.accessoryType=UITableViewCellAccessoryNone; c.accessoryView=nil; return c;
}
- (void)swChanged:(UISwitch *)sw {
    NSUInteger sec=(NSUInteger)(sw.tag>>16),row=(NSUInteger)(sw.tag&0xFFFF);
    WAGramRow *r=_sections[sec].rows[row];
    if (r.prefsKey) WASetEnabled(r.prefsKey,sw.isOn);
    if (r.action)   r.action(sw.isOn);
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style==WAGramRowStyleNavigation&&row.navTarget) [self.navigationController pushViewController:row.navTarget animated:YES];
    else if (row.style==WAGramRowStyleButton&&row.action)   row.action(NO);
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// Macros
// ═══════════════════════════════════════════════════════════════════════════════
#define SW(k,t,s,a)   [WAGramRow switchWithTitle:(t) subtitle:(s) key:(k) action:(a)]
#define BTN(t,a)      [WAGramRow buttonWithTitle:(t) action:(a)]
#define NAV(t,s,vc)   [WAGramRow navWithTitle:(t) subtitle:(s) target:(vc)]
#define SEC(h,f,...)  [WAGramSectionDef sectionWithHeader:(h) footer:(f) rows:@[__VA_ARGS__]]

static WAGRABFlagBrowserVC *browser(NSString *title, NSArray *flags) {
    WAGRABFlagBrowserVC *vc=[[WAGRABFlagBrowserVC alloc]initWithTitle:title flags:flags]; return vc;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Curated browsers — ALL 34 liquid_glass flags + complete categories
// ═══════════════════════════════════════════════════════════════════════════════
static WAGRABFlagBrowserVC *LGBrowser(void) {
    // ALL 34 confirmed in binary
    return browser(@"Liquid Glass", @[
        @"ios_liquid_glass_enabled",
        @"ios_liquid_glass_launched",
        @"ios_liquid_glass_media_m0",
        @"ios_liquid_glass_m1",
        @"ios_liquid_glass_m_1_5",
        @"ios_liquid_glass_m_1_5_context_menu",
        @"ios_liquid_glass_m_2_action_tile",
        @"ios_liquid_glass_m_2_chips",
        @"ios_liquid_glass_m_2_lightweight_dialogs",
        @"ios_liquid_glass_m_2_text_layout",
        @"ios_liquid_glass_larger_composer",
        @"ios_liquid_glass_media_editor_enabled",
        @"ios_liquid_glass_calling_improvement_enabled",
        @"ios_liquid_glass_chat_top_bar_m2_enabled",
        @"ios_liquid_glass_enable_new_chatbar_ux",
        @"ios_liquid_glass_reduce_transparency",
        @"ios_liquid_glass_ptt_oot",
        @"ios_liquid_glass_fixes_for_older_ios",
        // Fix flags (stability)
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
        // Workarounds
        @"ios_liquid_glass_workaround_attachment_tray",
        @"ios_liquid_glass_workaround_hides_bottombar",
        @"ios_liquid_glass_workaround_topbar_appearance",
        @"status_viewer_redesign_enabled",
    ]);
}

// Aura Native VC launcher
static UIViewController *AuraNativeVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Status dos Flags WAAB",
            @"Estes flags habilitam o sistema Aura no nível WAABProperties. O tweak hookeia os 4 getters de tipos.",
            BTN(@"Ativar TODOS os flags Aura", ^(BOOL _){
                WAGRAuraActivateAllFlags();
                WAGRAlert(@"Aura Ativada", @"Todos os flags aura_* foram forçados. aura_kill_switch = OFF. Reinicie o WhatsApp para que as VCs sejam inicializadas.");
            }),
            BTN(@"Desativar TODOS os flags Aura", ^(BOOL _){
                WAGRAuraDeactivateAllFlags();
                WAGRAlert(@"Aura Desativada", @"Overrides removidos.");
            }),
            BTN(@"Diagnóstico Aura", ^(BOOL _){ WAGRAlert(@"Aura", WAGRAuraDiagnostic()); })
        ),
        SEC(@"Abrir VCs Nativas (requer flags ativos + restart)",
            @"Estes VCs existem em _TtC6WAAura22AppIconsViewController e _TtC6WAAura23AppThemesViewController. São instâncias diretas — precisam do contexto de subscription ativo para renderizar corretamente.",
            BTN(@"Temas e Cores  →  AppThemesViewController", ^(BOOL _){
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIViewController *top = WAGRTopVC();
                    if (!WAGRPushAuraThemesVC(top))
                        WAGRAlert(@"Aura Temas", @"AppThemesViewController não encontrada em runtime. Certifique-se que os flags Aura estão ativos e o app foi reiniciado.");
                });
            }),
            BTN(@"Ícones do App  →  AppIconsViewController", ^(BOOL _){
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIViewController *top = WAGRTopVC();
                    if (!WAGRPushAuraIconsVC(top))
                        WAGRAlert(@"Aura Ícones", @"AppIconsViewController não encontrada. Reinicie após ativar os flags.");
                });
            }),
            BTN(@"Ringtones  →  WACallRingtonePickerViewController", ^(BOOL _){
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!WAGRPushAuraRingtonesVC(WAGRTopVC()))
                        WAGRAlert(@"Ringtones", @"WACallRingtonePickerViewController não encontrada.");
                });
            })
        ),
        SEC(@"Flags WAAB individuais",
            @"Toggle ON = force YES via WAABPropsObserver hook. aura_kill_switch deve ser OFF.",
            NAV(@"Abrir Flags Aura", @"runtime WAAB", browser(@"Flags Aura", @[
                @"aura_enabled",
                @"aura_settings_row_enabled",
                @"aura_subscription_simulation_enabled",
                @"aura_kill_switch",
                @"aura_premium_stickers_killswitch",
                @"aura_app_icon_enabled",
                @"aura_app_icon_benefit_active",
                @"aura_app_themes_enabled",
                @"aura_app_themes_benefit_active",
                @"aura_app_themes_chat_checkmark_themed_enabled",
                @"aura_app_themes_new_selection_flow_enabled",
                @"aura_app_themes_share_extension_themed_enabled",
                @"aura_app_themes_status_ring_enabled",
                @"aura_app_themes_illustration_lottie_enabled",
                @"aura_apple_watch_app_theme_enabled",
                @"aura_pinned_chats_enabled",
                @"aura_pinned_chats_benefit_active",
                @"aura_pinned_chats_targeted_nux_force",
                @"aura_enhanced_lists_enabled",
                @"aura_enhanced_lists_benefit_active",
                @"aura_ringtones_enabled",
                @"aura_ringtones_benefit_active",
                @"aura_ringtones_per_chat_enabled",
                @"aura_stickers_enabled",
                @"aura_stickers_benefit_active",
                @"aura_stickers_overlay_animation_enabled",
                @"aura_settings_row_enabled",
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
            ]))
        ),
    ] title:@"WA Plus / Aura"];
}

static WAGRABFlagBrowserVC *AIBrowser(void) {
    return browser(@"AI & Meta AI", @[
        @"ai_meta_ai_in_app_tab_main_gate_enabled",
        @"ai_home_redesign_enabled",
        @"ai_psi_ux_enabled",
        @"ai_dynamic_mode_selector_enabled",
        @"ai_dynamic_model_branding_enabled",
        @"ai_tab_glyph_icon_enabled",
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
        @"ai_chat_threads_enabled",
        @"ai_chat_threads_side_sheet_enabled",
        @"ai_rewrite_in_edit_message_enabled",
        @"ai_rich_response_tables_enabled",
        @"ai_contextual_writing_help_enabled",
        @"ai_group_participation_enabled",
        @"ai_group_participation_send_enabled",
        @"ai_group_multi_modal_enabled",
        @"ai_voice_image_input_enabled",
        @"ai_voice_live_video_input_enabled",
        @"ai_voice_live_video_pip_enabled",
        @"ai_voice_ptt_coexistence_enabled",
        @"ai_imagine_bottom_sheet_enabled",
        @"ai_imagine_in_media_editor_enabled",
        @"ai_imagine_video_edit_in_media_editor_enabled",
        @"ai_genai_imagine_intent_ar_effects_v3_enabled",
        @"ai_genai_imagine_intent_attachment_tray_enabled",
        @"ai_genai_imagine_intent_status_v3_enabled",
        @"ai_bot_imagine_me_enabled",
        @"ai_subscription_enabled",
        @"ai_subscription_imagine_intent_enabled",
        @"ai_llama_premium_model_main_gate_enabled",
    ]);
}

static WAGRABFlagBrowserVC *UIBrowser(void) {
    return browser(@"UI & UX", @[
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
        @"evolve_about_m1_receiver_enabled",
        @"evolve_about_m1_receiver_for_new_surfaces_enabled",
    ]);
}

static WAGRABFlagBrowserVC *MsgBrowser(void) {
    return browser(@"Messaging & Stickers", @[
        @"scheduled_messages_sender_enabled",
        @"scheduled_messages_receiver_enabled",
        @"ios_klipy_logging_enabled",
        @"ios_enable_klipy_sticker_search",
        @"enable_sticker_lottie_reader_in_tray",
        @"status_animated_music_stickers_enabled",
        @"status_animated_sticker_with_static_media_enabled",
        @"aura_stickers_enabled",
        @"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",
        @"aura_painted_door_stickers_enabled",
        @"ai_rewrite_in_edit_message_enabled",
        @"ai_rich_response_tables_enabled",
        @"sg_message_recall_enabled",
        @"poll_add_option_enabled",
        @"poll_creator_edit_enabled",
        @"poll_end_time_enabled",
        @"view_replies_follow_up_ui_enabled",
        @"ai_translate_messages_enabled",
    ]);
}

static WAGRABFlagBrowserVC *CallsBrowser(void) {
    return browser(@"Calls", @[
        @"calling_voicemail_enabled",
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
        @"missed_call_reminder_client_filter_enabled",
        @"ai_voice_fab_call_history_entry_enabled",
        @"ai_voice_image_input_enabled",
        @"ai_voice_live_video_input_enabled",
        @"ai_voice_live_video_pip_enabled",
        @"ai_voice_ptt_coexistence_enabled",
    ]);
}

static WAGRABFlagBrowserVC *StatusBrowser(void) {
    return browser(@"Status", @[
        @"status_viewer_redesign_enabled",
        @"status_3p_api_apple_music_integration_enabled",
        @"status_bolder_tiles_enabled",
        @"status_close_friends_multi_select_enabled",
        @"status_animated_sticker_with_static_media_enabled",
        @"status_animated_music_stickers_enabled",
        @"channel_status_creation_music_enabled",
        @"channel_status_consumption_music_enabled",
        @"channel_poll_status_card_enabled",
        @"enable_reasoning_status",
        @"add_status_bolder_tile_entrypoint_enabled",
        @"ios_status_audience_ranker_enabled",
        @"ai_genai_imagine_intent_status_v3_enabled",
        @"ai_imagine_intents_status_mimicry_sender_enabled",
        @"ai_imagine_intents_status_mimicry_receiver_enabled",
    ]);
}

static WAGRABFlagBrowserVC *ChannelsBrowser(void) {
    return browser(@"Channels", @[
        @"newsletter_forward_counter_ui_enabled",
        @"channels_admin_profiles_forwarding_to_status_enabled",
        @"channels_admin_profiles_receiver_enabled",
        @"channels_albums_v2_forwarding_to_status_enabled",
        @"channels_ptv_forwarding_to_status_enabled",
        @"channels_creation_enabled",
        @"channels_pinning_nudge_updates_tab_enabled",
        @"channels_admin_reply_enabled",
        @"group_status_receiver_enabled",
        @"group_status_forward_to_channels_enabled",
        @"group_status_enable_nux_new_badge",
    ]);
}

static WAGRABFlagBrowserVC *GroupsBrowser(void) {
    return browser(@"Groups & Interop", @[
        @"interop_group_messaging_enabled",
        @"interop_bootstrap_enabled",
        @"interop_client_ux_enabled",
        @"non_anonymous_group_participation_enable",
        @"group_invite_contacts_count_enabled",
        @"empty_group_creation_enabled_int",
        @"push_name_in_community_groups_picker_enabled",
        @"poll_add_option_enabled",
        @"poll_creator_edit_enabled",
        @"poll_end_time_enabled",
        @"sg_message_recall_enabled",
        @"scheduled_messages_sender_enabled",
        @"ai_group_participation_enabled",
        @"ai_group_participation_send_enabled",
        @"ai_group_multi_modal_enabled",
    ]);
}

static WAGRABFlagBrowserVC *PrivacyBrowser(void) {
    return browser(@"Privacy & Username", @[
        @"username_suggestions_enabled",
        @"username_enabled_on_companion",
        @"username_call_search_enabled",
        @"username_key_redesign_enabled",
        @"ios_wabi_enable_username_migration",
        @"allow_lid_contacts_privacy_settings",
        @"enable_calling_phone_number_privacy",
        @"enable_calling_username",
        @"defense_mode_available",
        @"passkey_login",
        @"multiple_passkeys_delete_v2_enabled",
        @"privacy_aware_secure_dl_logging_enabled",
    ]);
}

static WAGRABFlagBrowserVC *PremiumBrowser(void) {
    return browser(@"Premium & Business", @[
        @"smbi_premium_broadcast_enabled",
        @"smbi_subscription_content_models_enabled",
        @"waffle_companions_enabled",
        @"waffle_enabled_for_unlinked_users",
        @"waffle_mobile_companions_enabled",
        @"waffle_foa_to_wa_linking_enabled",
        @"meta_catalog_linking_m3_enabled",
        @"smb_custom_url_display_v2_enabled",
        @"smb_verified_badge_parity_changes_enabled",
        @"smb_agent_chat_list_indicator_enabled",
        @"ai_subscription_enabled",
        @"ai_llama_premium_model_main_gate_enabled",
    ]);
}

static UIViewController *DogfoodVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Direct ObjC Selector Hooks",
            @"MSHookMessageEx scan em runtime. Confirmados: WA:136909 (isMetaEmployee), WA:94150 (graphQLEmpC1), WA:94156 (isInternalUser).",
            SW(kWAGREmployeeMaster, @"Employee Master",
               @"isMetaEmployee · isInternalUser · graphQLEmpC1",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateMetaEmployee, @"isMetaEmployeeOrInternalTester",
               @"WA:136909 / SM:94927 → YES",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateMetaEmployeeSnake, @"is_meta_employee_or_internal_tester",
               @"SM:73827 → YES",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateInternalUser, @"isInternalUser",
               @"WA:94156 → YES",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateGraphQLEmpC1, @"graphQLEmployeeC1Disabled",
               @"WA:94150 → NO (C1 enabled)",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            BTN(@"Diagnóstico", ^(BOOL _){ WAGRAlert(@"Dogfood", WAGRDogfoodDiagnosticText()); })
        ),
        SEC(@"WAAB Flags",
            @"Via WAABPropsObserver generic hook.",
            NAV(@"Dogfood Flags", @"runtime WAAB", browser(@"Dogfood Flags", @[
                @"is_internal_tester",
                @"mobile_config_debug_internal",
                @"dogfooder_diagnostics",
                @"ios_internal_hall_enabled",
                @"defense_mode_available",
                @"visible_message_drop_placeholder_enabled_internal_only",
                @"sections_in_help_menu",
            ]))
        ),
    ] title:@"Dogfood / Internal"];
}

static UIViewController *SystemVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"WAAB Observer",
            @"",
            SW(WA_PREF_AB_OBSERVER, @"Observer",
               @"Log getter calls", ^(BOOL _){ WAGRWAABEnsureHooksInstalled(); }),
            BTN(@"Ver Log",       ^(BOOL _){ WAGRAlert(@"Log", WAGRABObsLog()); }),
            BTN(@"Limpar Log",    ^(BOOL _){ WAGRABObsClear(); }),
            BTN(@"Diagnóstico",   ^(BOOL _){ WAGRAlert(@"WAAB", WAGRWAABDiagnosticText()); })
        ),
        SEC(@"Debug Menu",
            @"",
            SW(kWAGRDebugMenuNative, @"isDebugMenuAllowed = YES",
               @"SettingsView_DeveloperCell → WADebugMenuMain",
               ^(BOOL _){ WAGRDebugMenuEnsureHooksInstalled(); }),
            BTN(@"Diagnóstico", ^(BOOL _){ WAGRAlert(@"Debug Menu", WAGRDebugMenuDiagnosticText()); })
        ),
        SEC(@"Reset",
            @"",
            SW(@"wagr_debug_mode_enabled", @"Debug Logging", @"NSLog [LiquidGlassOn]", nil),
            BTN(@"Reset TODOS os overrides", ^(BOOL _){
                NSUserDefaults *ud=NSUserDefaults.standardUserDefaults;
                NSUInteger n=0;
                for (NSString *k in [[ud dictionaryRepresentation]allKeys])
                    if ([k hasPrefix:@"wagr."]) { [ud removeObjectForKey:k]; n++; }
                [ud synchronize];
                WAGRAlert(@"Reset",[NSString stringWithFormat:@"%lu entradas removidas.",(unsigned long)n]);
            })
        ),
    ] title:@"Sistema"];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramMenuVC — Root
// Clean WhatsApp style: no subtitles on nav rows, plain list, no emoji pollution
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGramMenuVC ()
@property (nonatomic, strong) NSArray<WAGramSectionDef *> *sections;
@end
@implementation WAGramMenuVC

- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title=@"WAGram";
    WAGRABFlagBrowserVC *runtimeBrowser=[[WAGRABFlagBrowserVC alloc]initWithTitle:@"Todos os Flags" flags:@[]];
    _sections = @[
        // ── Masters (UISwitch only, no nav clutter) ────────────────────────
        SEC(@"Controles",
            @"",
            SW(WA_PREF_LIQUID_GLASS,   @"Liquid Glass",           @"WDSLiquidGlass + WAABProperties", ^(BOOL _){ WAGRLGPrefsDidChange(); }),
            SW(kWAGREmployeeMaster,    @"Employee / Dogfood",     @"isMetaEmployee · isInternalUser · graphQLEmpC1", ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDebugMenuNative,   @"Native Debug Menu",      @"isDebugMenuAllowed = YES", ^(BOOL _){ WAGRDebugMenuEnsureHooksInstalled(); }),
            SW(WA_PREF_AB_OBSERVER,    @"WAAB Observer",          @"Log all WAABProperties calls", ^(BOOL _){ WAGRWAABEnsureHooksInstalled(); })
        ),
        // ── WA Plus / Aura (destaque próprio) ──────────────────────────────
        SEC(@"WhatsApp Plus",
            @"WAAura: AppThemesViewController, AppIconsViewController, WACallRingtonePickerViewController.",
            BTN(@"Ativar WA Plus (Aura)", ^(BOOL _){
                WAGRAuraActivateAllFlags();
                WAGRAlert(@"WA Plus Ativado", @"Todos os flags Aura foram forçados.\n\nReinicie o WhatsApp para que as VCs sejam carregadas e a cell Subscriptions apareça em Settings.");
            }),
            BTN(@"Abrir Temas",    ^(BOOL _){ dispatch_async(dispatch_get_main_queue(), ^{ if (!WAGRPushAuraThemesVC(WAGRTopVC())) WAGRAlert(@"Erro", @"AppThemesViewController não disponível. Ative WA Plus e reinicie."); }); }),
            BTN(@"Abrir Ícones",   ^(BOOL _){ dispatch_async(dispatch_get_main_queue(), ^{ if (!WAGRPushAuraIconsVC(WAGRTopVC())) WAGRAlert(@"Erro", @"AppIconsViewController não disponível. Ative WA Plus e reinicie."); }); }),
            BTN(@"Abrir Ringtones",^(BOOL _){ dispatch_async(dispatch_get_main_queue(), ^{ if (!WAGRPushAuraRingtonesVC(WAGRTopVC())) WAGRAlert(@"Erro", @"RintonePickerVC não disponível."); }); }),
            [WAGramRow navWithTitle:@"Todos os flags Aura" subtitle:@"" target:AuraNativeVC()]
        ),
        // ── Feature flags (clean, no subtitles, count as detail) ─────────
        SEC(@"Feature Flags",
            @"",
            [WAGramRow navWithTitle:@"Liquid Glass"       subtitle:@"34 flags" target:LGBrowser()],
            [WAGramRow navWithTitle:@"AI & Meta AI"       subtitle:@"44 flags" target:AIBrowser()],
            [WAGramRow navWithTitle:@"UI & UX"            subtitle:@"16 flags" target:UIBrowser()],
            [WAGramRow navWithTitle:@"Messaging"          subtitle:@"19 flags" target:MsgBrowser()],
            [WAGramRow navWithTitle:@"Calls"              subtitle:@"21 flags" target:CallsBrowser()],
            [WAGramRow navWithTitle:@"Status"             subtitle:@"15 flags" target:StatusBrowser()],
            [WAGramRow navWithTitle:@"Channels"           subtitle:@"11 flags" target:ChannelsBrowser()],
            [WAGramRow navWithTitle:@"Groups & Interop"   subtitle:@"15 flags" target:GroupsBrowser()],
            [WAGramRow navWithTitle:@"Privacy & Username" subtitle:@"12 flags" target:PrivacyBrowser()],
            [WAGramRow navWithTitle:@"Premium & Business" subtitle:@"12 flags" target:PremiumBrowser()],
            [WAGramRow navWithTitle:@"Dogfood / Internal" subtitle:@""         target:DogfoodVC()],
            [WAGramRow navWithTitle:@"Sistema"            subtitle:@""         target:SystemVC()]
        ),
        // ── All flags browser ─────────────────────────────────────────────
        SEC(@"",
            @"",
            [WAGramRow navWithTitle:@"Todos os Flags (runtime scan)" subtitle:@"~6892 métodos WAABProperties" target:runtimeBrowser],
            [WAGramRow navWithTitle:@"Runtime Methods (Non-WAAB)" subtitle:@"is/has/should" target:[[WAGRRuntimeMethodBrowserVC alloc] initWithTitle:@"Runtime Methods" tokens:@[]]]
        ),
        // ── Restart ───────────────────────────────────────────────────────
        SEC(@"",
            @"",
            BTN(@"Reiniciar WhatsApp", ^(BOOL _){
                UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Reiniciar?"
                                                                         message:@"Fecha o app. Reabra para aplicar hooks."
                                                                  preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"Reiniciar" style:UIAlertActionStyleDestructive handler:^(id _){
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{exit(0);});
                }]];
                [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
                [WAGRTopVC() presentViewController:a animated:YES completion:nil];
            })
        ),
    ];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor=WAGRBG();
    self.tableView.separatorInset=UIEdgeInsetsMake(0,16,0,0);
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {return (NSInteger)_sections.count;}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {return (NSInteger)_sections[(NSUInteger)s].rows.count;}
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSString *h=_sections[(NSUInteger)s].header;
    return h.length?[[WAGRHeader5 alloc]initWithTitle:h]:nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].header.length?32:8;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {return _sections[(NSUInteger)s].footer;}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style==WAGramRowStyleSwitch) {
        UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kSW];
        if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kSW];
        c.backgroundColor=WAGRGroupBG();
        c.textLabel.text=row.title; c.textLabel.textColor=UIColor.labelColor;
        c.detailTextLabel.text=row.subtitle; c.detailTextLabel.textColor=UIColor.secondaryLabelColor;
        c.selectionStyle=UITableViewCellSelectionStyleNone;
        UISwitch *sw=[[UISwitch alloc]init];
        sw.on=row.prefsKey?WAEnabled(row.prefsKey):NO; sw.onTintColor=WAGRAccent();
        sw.tag=(ip.section<<16)|ip.row;
        [sw addTarget:self action:@selector(swChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView=sw; return c;
    }
    if (row.style==WAGramRowStyleNavigation) {
        UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kNAV];
        if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kNAV];
        c.backgroundColor=WAGRGroupBG();
        c.textLabel.text=row.title; c.textLabel.textColor=UIColor.labelColor;
        // Subtitle = right-aligned count (WhatsApp style)
        c.detailTextLabel.text=row.subtitle; c.detailTextLabel.textColor=UIColor.secondaryLabelColor;
        c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        return c;
    }
    UITableViewCell *c=[tv dequeueReusableCellWithIdentifier:kBTN];
    if (!c) c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kBTN];
    c.backgroundColor=WAGRGroupBG();
    BOOL destruct=[row.title containsString:@"Reiniciar"];
    c.textLabel.text=row.title;
    c.textLabel.textColor=destruct?WAGRDestructive():WAGRAccent();
    c.textLabel.textAlignment=destruct?NSTextAlignmentCenter:NSTextAlignmentLeft;
    c.accessoryType=UITableViewCellAccessoryNone; c.accessoryView=nil; return c;
}
- (void)swChanged:(UISwitch *)sw {
    NSUInteger sec=(NSUInteger)(sw.tag>>16),row=(NSUInteger)(sw.tag&0xFFFF);
    WAGramRow *r=_sections[sec].rows[row];
    if (r.prefsKey) WASetEnabled(r.prefsKey,sw.isOn);
    if (r.action)   r.action(sw.isOn);
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row=_sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style==WAGramRowStyleNavigation&&row.navTarget) [self.navigationController pushViewController:row.navTarget animated:YES];
    else if (row.style==WAGramRowStyleButton&&row.action)   row.action(NO);
}
@end
