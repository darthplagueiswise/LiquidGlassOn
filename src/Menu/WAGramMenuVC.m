// WAGramMenuVC.m — WAGram v7 RyukGram-style UI
// Persistence: wagr.waab.<flag> = "on"/"off" para WAAB flags
//             wagr.context.<key>    para debug build gates
//             NSUserDefaults boolForKey para master switches
// TODOS os toggles persistem — nada hardcoded.

#import "WAGramMenuVC.h"
#import "WAGRRuntimeBrowserVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"
#import "../WAGramUI.h"
#import <CoreFoundation/CoreFoundation.h>

// ── Persistent keys para Context/Debug ───────────────────────────────────────
#define kWAGRCtxDebugBuild  @"wagr.context.simulateDebugBuild"
#define kWAGRCtxDebugMenu   @"wagr.context.debugMenuAllowed"
#define kWAGRAuraSimKey     @"wagr_aura_simulation_enabled"

// ── Pref helpers ──────────────────────────────────────────────────────────────
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
    if ([f hasPrefix:@"aura_"] || [f containsString:@"benefit"]) WAGRAuraGatingEnsureHooksInstalled();
    if ([f containsString:@"dogfood"] || [f containsString:@"internal"] || [f containsString:@"employee"]) WAGRDogfoodEnsureHooksInstalled();
}
static BOOL CtxOn(NSString *k)     { return [[NSUserDefaults standardUserDefaults] boolForKey:k]; }
static void CtxSet(NSString *k, BOOL v) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (v) [ud setBool:YES forKey:k]; else [ud removeObjectForKey:k];
    [ud synchronize];
}

// ── TopVC + Alert ─────────────────────────────────────────────────────────────
static UIViewController *TopVC(void) {
    UIViewController *c = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows)
            if (w.isKeyWindow && w.rootViewController) { c = w.rootViewController; break; }
        if (c) break;
    }
    UIViewController *prev = nil;
    while (c != prev) {
        prev = c;
        if (c.presentedViewController) c = c.presentedViewController;
        else if ([c isKindOfClass:UINavigationController.class]) { UIViewController *v = ((UINavigationController*)c).visibleViewController; if (v && v != c) c = v; }
        else if ([c isKindOfClass:UITabBarController.class])     { UIViewController *v = ((UITabBarController*)c).selectedViewController; if (v && v != c) c = v; }
    }
    return c;
}
static void Alert(NSString *t, NSString *m) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:t?:@"WAGram" message:m?:@"" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault handler:^(id _){ UIPasteboard.generalPasteboard.string = m?:@""; }]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [TopVC() presentViewController:a animated:YES completion:nil];
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGRABFlagBrowserVC — curated flag browser (same as working v4 — DO NOT CHANGE)
// ═══════════════════════════════════════════════════════════════════════════════
static const char kSwKey = 0;

@interface WAGRABFlagBrowserVC () <UISearchResultsUpdating>
@property (nonatomic,strong) NSArray<NSString*> *allFlags;
@property (nonatomic,strong) NSArray<NSString*> *filtered;
@property (nonatomic,strong) UISearchController *search;
@end
@implementation WAGRABFlagBrowserVC
- (instancetype)initWithTitle:(NSString *)t flags:(NSArray<NSString*>*)flags {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = t;
    _allFlags = flags ? [flags sortedArrayUsingSelector:@selector(compare:)] : @[];
    _filtered = _allFlags;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGR_BG();
    self.tableView.rowHeight = 54;
    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar flag…";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
    [self updateTitle];
    if (_allFlags.count == 0) [self reload];
}
- (void)updateTitle {
    NSUInteger on = 0; for (NSString *f in _allFlags) if (FlagOn(f)) on++;
    self.title = on > 0 ? [NSString stringWithFormat:@"%@ (%lu✓)", self.navigationItem.backButtonTitle?:@"Flags",(unsigned long)on] : (self.navigationItem.backButtonTitle?:@"Flags");
}
- (void)reload {
    if (_allFlags.count == 0) {
        // runtime scan
        Class cls = NSClassFromString(@"WAABProperties"); if (!cls) return;
        NSMutableArray *out = [NSMutableArray array];
        unsigned int n = 0; Method *ms = class_copyMethodList(cls, &n);
        for (unsigned int i = 0; i < n; i++) {
            if (method_getNumberOfArguments(ms[i])!=2) continue;
            char ret[8]={0}; method_getReturnType(ms[i],ret,8);
            if (ret[0]!='B' && ret[0]!='c') continue;
            NSString *nm = NSStringFromSelector(method_getName(ms[i]));
            if ([nm containsString:@":"]) continue;
            [out addObject:nm];
        }
        free(ms);
        _allFlags = [out sortedArrayUsingSelector:@selector(compare:)];
    }
    [self updateSearchResultsForSearchController:_search];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text;
    _filtered = q.length ? [_allFlags filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@",q]] : _allFlags;
    [self.tableView reloadData]; [self updateTitle];
}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_filtered.count; }
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"fl"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"fl"];
    NSString *flag = _filtered[(NSUInteger)ip.row];
    BOOL on = FlagOn(flag);
    c.backgroundColor = WAGR_CELL();
    c.textLabel.text = flag; c.textLabel.numberOfLines = 2;
    c.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    c.textLabel.textColor = on ? WAGR_GREEN() : WAGR_LABEL();
    c.detailTextLabel.text = on ? @"✓ ON" : @"system/off";
    c.detailTextLabel.textColor = on ? WAGR_GREEN() : WAGR_SEC();
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    UISwitch *sw = (UISwitch*)objc_getAssociatedObject(c,&kSwKey);
    if (!sw) {
        sw = [[UISwitch alloc] init]; sw.onTintColor = WAGR_ACCENT();
        [sw addTarget:self action:@selector(togFlag:) forControlEvents:UIControlEventValueChanged];
        objc_setAssociatedObject(c,&kSwKey,sw,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        c.accessoryView = sw;
    }
    sw.on = on; sw.tag = ip.row; return c;
}
- (void)togFlag:(UISwitch*)sw {
    NSString *flag = _filtered[(NSUInteger)sw.tag]; FlagSet(flag,sw.isOn);
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:sw.tag inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    [self updateTitle];
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramBundleVC — bundle with master toggle + individual browser (RyukGram style)
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGramBundleVC : UITableViewController
- (instancetype)initWithTitle:(NSString*)t icon:(NSString*)ico iconColor:(UIColor*)clr flags:(NSArray<NSString*>*)flags killFlags:(NSArray<NSString*>*)kills desc:(NSString*)desc;
@property (nonatomic, readonly) NSArray<NSString*> *allFlags;
- (void)reload;
@end

static const char kBundleAssoc = 0;

@implementation WAGramBundleVC {
    NSArray<NSString*> *_flags, *_kills;
    NSString *_icon, *_desc;
    UIColor  *_iconColor;
    WAGRABFlagBrowserVC *_browser;
}
- (instancetype)initWithTitle:(NSString*)t icon:(NSString*)ico iconColor:(UIColor*)clr flags:(NSArray<NSString*>*)flags killFlags:(NSArray<NSString*>*)kills desc:(NSString*)desc {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title=t; _icon=ico; _iconColor=clr; _flags=flags?:@[]; _kills=kills?:@[]; _desc=desc;
    _browser = [[WAGRABFlagBrowserVC alloc] initWithTitle:t flags:flags];
    _browser.navigationItem.backButtonTitle = t;
    return self;
}
- (NSArray<NSString*>*)allFlags { return _flags; }
- (NSUInteger)onCount { NSUInteger n=0; for(NSString*f in _flags)if(FlagOn(f))n++; return n; }
- (BOOL)allOn  { return _flags.count>0 && [self onCount]==_flags.count; }
- (void)reload { [self.tableView reloadData]; [_browser updateTitle]; }

- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor=WAGR_BG(); }
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv { return 3; }
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s { return 1; }
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    return s==0 ? [NSString stringWithFormat:@"%@\n\nPersiste como wagr.waab.<flag> = \"on\"/\"off\" em NSUserDefaults. Reiniciar para aplicar na interface.", _desc?:@""] : nil;
}
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    NSString *titles[] = {@"Ativar Grupo", @"Flags Individuais", @"Diagnóstico"};
    return [[WAGRSectionHeader alloc] initWithTitle:titles[s]];
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s { return 36; }

- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if (ip.section==0) {
        NSUInteger on = [self onCount];
        UITableViewCell *c = WAGRIconCell(_icon, _iconColor,
            [NSString stringWithFormat:@"Ativar Todos (%lu/%lu)",(unsigned long)on,(unsigned long)_flags.count],
            on>0 ? [NSString stringWithFormat:@"%lu flags ativos — killswitches desativados",(unsigned long)on] : @"Todos no sistema",
            UITableViewCellAccessoryNone);
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init]; sw.on=[self allOn]; sw.onTintColor=WAGR_ACCENT();
        [sw addTarget:self action:@selector(masterTog:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        c.detailTextLabel.textColor = on>0 ? WAGR_GREEN() : WAGR_SEC();
        return c;
    }
    if (ip.section==1) {
        NSUInteger on=[self onCount];
        UITableViewCell *c = WAGRIconCell(@"slider.horizontal.3", WAGR_SEC(),
            @"Flags individuais",
            [NSString stringWithFormat:@"%lu/%lu ativos",(unsigned long)on,(unsigned long)_flags.count],
            UITableViewCellAccessoryDisclosureIndicator);
        return c;
    }
    return WAGRIconCell(@"stethoscope", WAGR_TEAL(), @"Diagnóstico WAAB", @"Ver estado dos hooks", UITableViewCellAccessoryDisclosureIndicator);
}
- (void)masterTog:(UISwitch*)sw {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in _flags)  sw.isOn ? [ud setObject:@"on"  forKey:WAGRKey(f)] : [ud removeObjectForKey:WAGRKey(f)];
    for (NSString *f in _kills)  sw.isOn ? [ud setObject:@"off" forKey:WAGRKey(f)] : [ud removeObjectForKey:WAGRKey(f)];
    [ud synchronize]; WAGRWAABEnsureHooksInstalled();
    [self reload]; [_browser reload];
}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section==1) [self.navigationController pushViewController:_browser animated:YES];
    if (ip.section==2) Alert(@"WAAB",WAGRWAABDiagnosticText());
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGRContextToggleVC — Debug Build toggles WITH persistence (not hardcoded)
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGRContextToggleVC : UITableViewController @end
@implementation WAGRContextToggleVC {
    NSArray<NSDictionary*> *_rows;
}
- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Debug Build Gates";
    _rows = @[
        @{@"key": kWAGRCtxDebugBuild, @"title": @"Simulate Debug Build",
          @"icon": @"hammer.fill", @"color": WAGR_ORANGE(),
          @"detail": @"isDebugBuild=YES · desbloqueia AB Props no Developer menu"},
        @{@"key": kWAGRCtxDebugMenu, @"title": @"Developer Menu Forçado",
          @"icon": @"wrench.and.screwdriver.fill", @"color": WAGR_INDIGO(),
          @"detail": @"isDebugMenuAllowed=YES · Developer cell aparece em Settings"},
        @{@"key": @"wagr.context.testFlight", @"title": @"Simulate TestFlight",
          @"icon": @"airplane", @"color": WAGR_TEAL(),
          @"detail": @"isTestFlightApp=YES · features TestFlight-only"},
        @{@"key": @"wagr.context.betaVerbose", @"title": @"Beta / Verbose Mode",
          @"icon": @"text.magnifyingglass", @"color": WAGR_PURPLE(),
          @"detail": @"isBetaOrMoreVerbose=YES · mais debug UI disponível"},
    ];
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor=WAGR_BG(); }
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    return [[WAGRSectionHeader alloc] initWithTitle:s==0?@"Persistência":@"Info"];
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s{return 36;}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    return s==0 ? @"Cada toggle persiste em NSUserDefaults com a chave wagr.context.*. Os hooks leem essa chave — nada hardcoded. Hook instalado via scan de runtime em WAGRContextHooks.xm." : nil;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 2;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s{return s==0?(NSInteger)_rows.count:1;}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if (ip.section==1) return WAGRIconCell(@"info.circle",WAGR_ACCENT(),@"Diagnóstico Context",@"Ver estado dos hooks",UITableViewCellAccessoryDisclosureIndicator);
    NSDictionary *row = _rows[(NSUInteger)ip.row];
    NSString *key = row[@"key"];
    BOOL on = CtxOn(key);
    UITableViewCell *c = WAGRIconCell(row[@"icon"], row[@"color"], row[@"title"], row[@"detail"], UITableViewCellAccessoryNone);
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    c.detailTextLabel.textColor = on ? WAGR_GREEN() : WAGR_SEC();
    UISwitch *sw = [[UISwitch alloc] init]; sw.on=on; sw.onTintColor=WAGR_ACCENT(); sw.tag=ip.row;
    [sw addTarget:self action:@selector(ctxTog:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView = sw;
    return c;
}
- (void)ctxTog:(UISwitch*)sw {
    NSDictionary *row = _rows[(NSUInteger)sw.tag];
    NSString *key = row[@"key"];
    CtxSet(key, sw.isOn);
    WAGRContextEnsureHooksInstalled();
    NSLog(@"[WAGram][Ctx] %@ = %@", key, sw.isOn?@"YES":@"NO");
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:sw.tag inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section==1) Alert(@"Context", WAGRContextDiagnosticText());
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGRSettingsRowsVC — todos os 31 SettingsView_* cells e seus gates
// ═══════════════════════════════════════════════════════════════════════════════
@interface WAGRSettingsRowsVC : UITableViewController @end
@implementation WAGRSettingsRowsVC {
    NSArray<NSDictionary*> *_cells;
}
- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Settings Rows";
    _cells = @[
        // Células que precisam de gate
        @{@"name":@"SettingsView_SubscriptionsCell", @"flag":@"aura_settings_row_enabled",     @"icon":@"star.fill",              @"color":WAGR_ORANGE(),  @"desc":@"WA Plus / Subscriptions"},
        @{@"name":@"SettingsView_DeveloperCell",     @"flag":@"wagr.context.debugMenuAllowed",  @"icon":@"hammer.fill",            @"color":WAGR_RED(),     @"desc":@"Developer Menu (Context gate)"},
        @{@"name":@"SettingsView_ListCell",          @"flag":@"lists_feature_enabled",          @"icon":@"list.bullet",            @"color":WAGR_ACCENT(),  @"desc":@"Lists / Folders"},
        @{@"name":@"SettingsView_FavoritesCell",     @"flag":@"call_favorites_enabled_companions",@"icon":@"heart.fill",           @"color":WAGR_RED(),     @"desc":@"Favorites"},
        @{@"name":@"SettingsView_EventsCell",        @"flag":@"events_global_list",             @"icon":@"calendar",               @"color":WAGR_TEAL(),    @"desc":@"Events"},
        @{@"name":@"SettingsView_WAFFLEHomeCell",    @"flag":@"waffle_mobile_companions_enabled",@"icon":@"apps.ipad",             @"color":WAGR_INDIGO(),  @"desc":@"Connected Apps (Waffle)"},
        @{@"name":@"SettingsView_PaymentsCell",      @"flag":@"isPaymentP2PEnabled",            @"icon":@"brazilianrealsign.circle.fill",@"color":WAGR_GREEN(),@"desc":@"Payments"},
        // Bookmarks (seção Também da Meta)
        @{@"name":@"SettingsView_ThreadsBookmark",   @"flag":@"foa_threads_bookmarks_enabled",  @"icon":@"at",                     @"color":WAGR_ACCENT(),  @"desc":@"Threads Bookmark"},
        @{@"name":@"SettingsView_MetaHorizonBookmark",@"flag":@"foa_bridges_bookmark_meta_horizon",@"icon":@"vr.fill",             @"color":WAGR_PURPLE(),  @"desc":@"Meta Horizon Bookmark"},
        @{@"name":@"SettingsView_FBBookmark",        @"flag":@"foa_bridges_bookmarks_design_update_enabled",@"icon":@"f.cursive", @"color":WAGR_ACCENT(),  @"desc":@"Facebook Bookmark"},
        @{@"name":@"SettingsView_IGBookmark",        @"flag":@"isEligibleForFOABookmarks",      @"icon":@"camera.fill",            @"color":WAGR_ORANGE(),  @"desc":@"Instagram Bookmark"},
        @{@"name":@"SettingsView_MetaAIAppBookmark", @"flag":@"ai_rich_response_c50_promotion_enabled",@"icon":@"sparkles",        @"color":WAGR_PURPLE(),  @"desc":@"Meta AI Bookmark"},
        @{@"name":@"SettingsView_VibesBookmark",     @"flag":@"ai_rich_response_vibes_promotion_enabled",@"icon":@"waveform",     @"color":WAGR_MINT(),    @"desc":@"Vibes Bookmark"},
        // Help menu rows (aparecem DENTRO de Ajuda e Feedback)
        @{@"name":@"SettingsView_DogfoodingNudge",   @"flag":@"sections_in_help_menu",          @"icon":@"dog.fill",               @"color":WAGR_ORANGE(),  @"desc":@"Participar do beta [Internal] — dentro de Ajuda"},
        @{@"name":@"SettingsView_SendFeedback",      @"flag":@"sections_in_help_menu",          @"icon":@"paperplane.fill",        @"color":WAGR_ACCENT(),  @"desc":@"Enviar Feedback [Internal]"},
        @{@"name":@"SettingsView_ReportABug",        @"flag":@"sections_in_help_menu",          @"icon":@"ant.fill",               @"color":WAGR_RED(),     @"desc":@"Reportar Bug [Internal]"},
    ];
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.backgroundColor=WAGR_BG(); }
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    NSString *titles[] = {@"Células Ocultas", @"Sempre Visíveis"};
    return [[WAGRSectionHeader alloc] initWithTitle:titles[s]];
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s{return 36;}
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    return s==0?@"Cada row só aparece quando o gate flag está ativo. O toggle aqui persiste o override em NSUserDefaults e reaplica via hook."
              :@"Estas células aparecem sempre — não precisam de override.";
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv{return 2;}
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s {
    return s==0?(NSInteger)_cells.count:3;
}
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if (ip.section==1) {
        NSString *always[] = {@"AccountsCell",@"PrivacyCell",@"ChatsCell"};
        return WAGRIconCell(@"checkmark.seal.fill",WAGR_GREEN(),[NSString stringWithFormat:@"SettingsView_%@",always[ip.row]],@"Sempre visível",UITableViewCellAccessoryNone);
    }
    NSDictionary *row = _cells[(NSUInteger)ip.row];
    NSString *flag = row[@"flag"];
    // Check if this is a context key or WAAB key
    BOOL isCtx = [flag hasPrefix:@"wagr.context."];
    BOOL on = isCtx ? CtxOn(flag) : FlagOn(flag);
    UITableViewCell *c = WAGRIconCell(row[@"icon"],row[@"color"],row[@"name"],
        [NSString stringWithFormat:@"%@ • %@", on?@"✓ ATIVO":@"off", row[@"desc"]],
        UITableViewCellAccessoryNone);
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    c.detailTextLabel.textColor = on ? WAGR_GREEN() : WAGR_SEC();
    UISwitch *sw = [[UISwitch alloc] init]; sw.on=on; sw.onTintColor=WAGR_ACCENT(); sw.tag=ip.row;
    [sw addTarget:self action:@selector(rowTog:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView = sw;
    return c;
}
- (void)rowTog:(UISwitch*)sw {
    NSDictionary *row = _cells[(NSUInteger)sw.tag];
    NSString *flag = row[@"flag"];
    if ([flag hasPrefix:@"wagr.context."]) {
        CtxSet(flag, sw.isOn); WAGRContextEnsureHooksInstalled();
    } else {
        FlagSet(flag, sw.isOn);
    }
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:sw.tag inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// Bundle factories (confirmed from binary analysis)
// ═══════════════════════════════════════════════════════════════════════════════
static WAGramBundleVC *LGBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Liquid Glass" icon:@"drop.fill" iconColor:WAGR_ACCENT() flags:@[
        @"ios_liquid_glass_enabled",@"ios_liquid_glass_launched",
        @"ios_liquid_glass_m1",@"ios_liquid_glass_m_1_5",@"ios_liquid_glass_m_1_5_context_menu",
        @"ios_liquid_glass_m_2_action_tile",@"ios_liquid_glass_m_2_chips",
        @"ios_liquid_glass_m_2_lightweight_dialogs",@"ios_liquid_glass_m_2_text_layout",
        @"ios_liquid_glass_media_m0",@"ios_liquid_glass_media_editor_enabled",
        @"ios_liquid_glass_larger_composer",@"ios_liquid_glass_chat_top_bar_m2_enabled",
        @"ios_liquid_glass_enable_new_chatbar_ux",@"ios_liquid_glass_chatbar_lower_bottom_padding",
        @"ios_liquid_glass_reduce_transparency",@"ios_liquid_glass_fixes_for_older_ios",
        @"ios_liquid_glass_fix_voip_mutex_priority_inversion",
        @"ios_liquid_glass_fix_status_dismiss_when_locked",
        @"ios_liquid_glass_fix_context_menu_on_disappear",
        @"ios_liquid_glass_fix_context_menu_transition_safety",
        @"ios_liquid_glass_fix_feedback_generator_retain",
        @"ios_liquid_glass_fix_forward_picker_share_extension_crash",
        @"ios_liquid_glass_fix_multisend_preview_dealloc",
        @"ios_liquid_glass_fix_tabbar_badge_offthread",
        @"ios_liquid_glass_fix_uiimage_trait_collection",
        @"ios_liquid_glass_fix_updates_table_dynamic_color",
        @"ios_liquid_glass_fix_weak_hashtable_snapshot",
        @"ios_liquid_glass_workaround_attachment_tray",
        @"ios_liquid_glass_workaround_hides_bottombar",
        @"ios_liquid_glass_workaround_topbar_appearance",
        @"status_viewer_redesign_enabled",
    ] killFlags:@[] desc:@"32 flags LiquidGlass confirmados em SM __objc_methname. WDSLiquidGlass + WAABProperties hooks via %hook Logos. Requer reinício."];
}

static WAGramBundleVC *AuraBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"WA Plus / Aura" icon:@"star.fill" iconColor:WAGR_ORANGE() flags:@[
        @"aura_enabled",@"aura_settings_row_enabled",@"aura_subscription_simulation_enabled",
        @"aura_logging_enabled",
        @"aura_app_icon_enabled",@"aura_app_icon_benefit_active",@"aura_app_icon_multi_account_support",
        @"aura_app_themes_enabled",@"aura_app_themes_benefit_active",
        @"aura_app_themes_chat_checkmark_themed_enabled",@"aura_app_themes_new_selection_flow_enabled",
        @"aura_app_themes_share_extension_themed_enabled",@"aura_app_themes_status_ring_enabled",
        @"aura_app_themes_illustration_lottie_enabled",@"aura_app_themes_illustration_coloring_mode",
        @"aura_apple_watch_app_theme_enabled",@"aura_apple_watch_app_themes_enabled",
        @"aura_pinned_chats_enabled",@"aura_pinned_chats_benefit_active",
        @"aura_pinned_chats_targeted_nux_force",
        @"aura_enhanced_lists_enabled",@"aura_enhanced_lists_benefit_active",
        @"aura_ringtones_enabled",@"aura_ringtones_benefit_active",@"aura_ringtones_per_chat_enabled",
        @"aura_stickers_enabled",@"aura_stickers_benefit_active",
        @"aura_stickers_overlay_animation_enabled",@"aura_painted_door_stickers_enabled",
        @"aura_media_offload_enabled",@"aura_vault_backups_enabled",@"aura_vault_backups_benefit_active",
        @"ai_subscription_enabled",@"ai_subscription_imagine_intent_enabled",
        @"isExpandedFormattingPlusEnabled",@"isEligibleForSubscriptions",
        @"isAppIconsBenefitActive",@"isAppThemesBenefitActive",
        @"isEnhancedListsBenefitActive",@"isExtendedPinnedChatBenefitActive",
        @"isRingtonesBenefitActive",@"isStickersBenefitActive",
        @"wa_subscriptions_entry_point_settings_enabled",@"wa_subscriptions_settings_green_dot_enabled",
    ] killFlags:@[@"aura_kill_switch",@"aura_premium_stickers_killswitch",@"aura_stickers_old_client_block_enabled"]
      desc:@"WAABProperties flags + WAAuraGating subscription hooks. Killswitches forçados OFF. Após ativar → reiniciar → Settings > Subscriptions."];
}

static WAGramBundleVC *PrivacyBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Privacy" icon:@"lock.shield.fill" iconColor:WAGR_GREEN() flags:@[
        @"defense_mode_available",@"passkey_login",@"multiple_passkeys_delete_v2_enabled",
        @"username_suggestions_enabled",@"username_key_redesign_enabled",
        @"username_enabled_on_companion",@"username_call_search_enabled",
        @"username_group_mutation_enabled",@"username_group_learning_enabled",
        @"allow_lid_contacts_privacy_settings",@"allow_lid_contacts_calling",
        @"allow_lid_contacts_status",@"allow_lid_contacts_broadcast",
        @"enable_calling_phone_number_privacy",@"enable_calling_username",
        @"ios_wabi_enable_username_migration",@"privacy_checkup",
        @"interop_client_ux_enabled",@"interop_contact_master_enabled",
        @"interop_group_messaging_enabled",@"interop_bootstrap_enabled",
        @"wa_interop_unified_inbox_enabled",@"is_interop_available_badge_banner_enabled",
        @"high_quality_link_preview_enabled",@"fb_experiment_for_link_preview_m3_enabled",
        @"non_anonymous_group_participation_enable",
    ] killFlags:@[] desc:@"Settings > Privacy: Defense Mode, Passkey, Username, Interop, Calling Privacy, Link Preview."];
}

static WAGramBundleVC *ChatBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Chat" icon:@"bubble.left.and.bubble.right.fill" iconColor:WAGR_INDIGO() flags:@[
        @"ai_translate_messages_enabled",@"evolve_about_m1_enabled",
        @"evolve_about_m1_receiver_enabled",@"ptt_transcription_manual_message_button_enabled",
        @"ai_imagine_intents_chat_themes_enabled",@"ai_imagine_intents_chat_wallpaper_enabled",
        @"ai_imagine_in_media_editor_enabled",@"chat_themes_selection_in_reg_flow_enabled",
        @"ios_chatlist_bundle_pinned_chat_move",@"ios_inbox_pinned_chats_in_context_menu_enabled",
        @"ios_chats_tab_null_state_search_bar_enabled",@"ai_chat_list_search_enabled",
        @"ios_disappearing_icon_chatlist_enabled",@"rename_other_contacts_to_contacts_enabled",
        @"ai_chat_thread_capability_enabled",@"ai_chat_threads_infra_enabled",
        @"ai_chat_threads_enabled",@"ai_chat_threads_multiplayer_enabled",
        @"ai_chat_threads_pin_enabled",@"ai_chat_threads_side_sheet_enabled",
        @"ai_chat_threads_search_enabled",@"ai_chat_threads_shy_header_enabled",
        @"ai_chat_threads_fuzzy_search_enabled",@"ai_chat_threads_recent_chats_widget_enabled",
        @"scheduled_messages_sender_enabled",@"scheduled_messages_receiver_enabled",
        @"channels_w_variant_enabled",@"channels_message_starring_enabled",
        @"non_contact_status_receiver_enabled",@"group_status_receiver_enabled",
        @"ptt_draft_enabled",@"ptt_lock_auto_cancel_improvements_enabled",
        @"ai_side_chat_enabled",@"ai_side_chat_summarization_enabled",
        @"ai_rewrite_in_context_menu_enabled",@"ai_rewrite_in_edit_message_enabled",
    ] killFlags:@[] desc:@"Chat: Translation, About redesign, AI Threads (todos 3 flags!), Scheduled, AI Side Chat, AI Rewrite."];
}

static WAGramBundleVC *TabBarBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Tab Bar" icon:@"square.grid.2x2.fill" iconColor:WAGR_TEAL() flags:@[
        @"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_in_tab_main_gate_enabled",
        @"ai_hatch_integration_tab_enabled",@"ai_tab_glyph_icon_enabled",
        @"ai_tab_perf_optimizations_enabled",@"community_tab_v2_enabled",
        @"communities_remove_from_app_tab_enabled",
        @"channels_creation_entrypoint_in_updates_tab_enabled",
        @"channels_pinning_nudge_updates_tab_enabled",@"updates_tab_filter_pills_enabled",
        @"status_archive_updates_tab_entryoint_enabled",
        @"group_status_creation_updates_tab_entrypoint_enabled",
        @"status_quick_replies_v2_stickers_tab_enabled",
    ] killFlags:@[] desc:@"TabBar: AI tab, Community v2, Updates pills, Channels in updates tab."];
}

static WAGramBundleVC *DogfoodBundle(void) {
    return [[WAGramBundleVC alloc]initWithTitle:@"Developer / Dogfood" icon:@"ant.fill" iconColor:WAGR_RED() flags:@[
        @"dogfooder_diagnostics",@"ios_internal_hall_enabled",@"isInternalUser",
        @"isMetaEmployeeOrInternalTester",@"is_internal",@"is_internal_tester",
        @"is_meta_employee_or_internal_tester",@"map_pages_internal",
        @"md_internal_app_log",@"md_syncd_dogfooding_feature",
        @"mobile_config_debug_internal",@"username_dogfooding_pn_privacy_enabled",
        @"visible_message_drop_placeholder_enabled_internal_only",
        @"sections_in_help_menu",@"enableEphemeralMessagesDebugOptions",
        @"callSpringAnimationDebugMenuEnabled",
    ] killFlags:@[@"graphQLEmployeeC1Disabled"] desc:@"Flags de developer: dogfood, internal, modo debug em chats e menus."];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramMenuVC — root (RyukGram style)
// ═══════════════════════════════════════════════════════════════════════════════
@implementation WAGramMenuVC
- (instancetype)init {
    if (!(self=[super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAGram";
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGR_BG();
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tv { return 6; }
- (NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s {
    NSInteger counts[] = {4, 7, 3, 1, 1, 2};
    return counts[s];
}
- (UIView*)tableView:(UITableView*)tv viewForHeaderInSection:(NSInteger)s {
    NSString *titles[] = {@"MASTERS",@"FEATURE BUNDLES",@"RUNTIME BROWSER",@"DEBUG BUILD GATES",@"SETTINGS ROWS",@"AÇÕES"};
    return [[WAGRSectionHeader alloc] initWithTitle:titles[s]];
}
- (CGFloat)tableView:(UITableView*)tv heightForHeaderInSection:(NSInteger)s { return 36; }
- (NSString*)tableView:(UITableView*)tv titleForFooterInSection:(NSInteger)s {
    if(s==0)return@"Masters: NSUserDefaults bool keys (wa_*). Bundles: wagr.waab.<flag>. Debug gates: wagr.context.*. NADA hardcoded.";
    if(s==1)return@"Cada bundle ativa/desativa TODOS os flags do grupo com persistência. Flags individuais editáveis dentro.";
    if(s==2)return@"Scan acontece APENAS quando você abre o VC — nunca no startup.";
    if(s==3)return@"Toggles com persistência em wagr.context.*. Hook instalado via scan runtime.";
    return nil;
}

// ── Section 0: Master switches ─────────────────────────────────────────────────
static const char kMasterKey = 0;
- (UITableViewCell*)masterCellForRow:(NSInteger)row {
    struct { NSString *title,*detail,*icon,*key; UIColor *clr; } m[] = {
        {@"Liquid Glass",     @"WDSLiquidGlass + 32 WAABProperties hooks", @"drop.fill",                  WA_PREF_LIQUID_GLASS,   WAGR_ACCENT()},
        {@"Employee Mode",    @"isMetaEmployee · isInternalUser · graphQL",  @"person.badge.key.fill",     WA_PREF_EMPLOYEE_MASTER,WAGR_PURPLE()},
        {@"WA Plus / Aura",   @"WAAuraGating + WAAB subscription hooks",   @"star.fill",                  kWAGRAuraSimKey,        WAGR_ORANGE()},
        {@"WAAB Observer",    @"Loga todas as chamadas WAABProperties",     @"eye.fill",                   WA_PREF_AB_OBSERVER,    WAGR_TEAL()},
    };
    NSString *key=m[row].key;
    UITableViewCell *c=WAGRIconCell(m[row].icon,m[row].clr,m[row].title,m[row].detail,UITableViewCellAccessoryNone);
    c.selectionStyle=UITableViewCellSelectionStyleNone;
    UISwitch *sw=[[UISwitch alloc]init]; sw.on=WAGRPref(key); sw.onTintColor=WAGR_ACCENT(); sw.tag=row;
    [sw addTarget:self action:@selector(masterTog:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView=sw; return c;
}
- (void)masterTog:(UISwitch*)sw {
    NSString *keys[]={WA_PREF_LIQUID_GLASS,WA_PREF_EMPLOYEE_MASTER,kWAGRAuraSimKey,WA_PREF_AB_OBSERVER};
    NSUserDefaults *ud=NSUserDefaults.standardUserDefaults;
    sw.isOn?[ud setBool:YES forKey:keys[sw.tag]]:[ud removeObjectForKey:keys[sw.tag]];
    [ud synchronize];
    switch(sw.tag){
        case 0: WAGRLGPrefsDidChange(); break;
        case 1: WAGRDogfoodEnsureHooksInstalled(); break;
        case 2: WAGRAuraGatingActivate(sw.isOn); sw.isOn?WAGRAuraActivateAllFlags():WAGRAuraDeactivateAllFlags(); break;
        case 3: WAGRWAABEnsureHooksInstalled(); break;
    }
}

// ── Section 1: Bundles ─────────────────────────────────────────────────────────
- (UITableViewCell*)bundleCellForRow:(NSInteger)row {
    NSArray *vcArr=@[LGBundle(),AuraBundle(),PrivacyBundle(),ChatBundle(),TabBarBundle(),DogfoodBundle(),
                     [[WAGRABFlagBrowserVC alloc]initWithTitle:@"AI & Meta AI" flags:@[
                         @"ai_meta_ai_in_app_tab_main_gate_enabled",@"ai_home_in_tab_main_gate_enabled",
                         @"ai_chat_threads_enabled",@"ai_chat_threads_infra_enabled",@"ai_chat_thread_capability_enabled",
                         @"ai_side_chat_enabled",@"ai_side_chat_summarization_enabled",
                         @"ai_translate_messages_enabled",@"ai_voice_image_input_enabled",
                         @"ai_incognito_mode_enabled",@"ai_subscription_enabled",
                         @"ai_llama_premium_model_main_gate_enabled",@"ai_hatch_integration_enabled",
                     ]]];
    struct{NSString*t,*i;UIColor*c;}info[]={
        {@"🌊 Liquid Glass",     @"drop.fill",                         WAGR_ACCENT()},
        {@"⭐ WA Plus / Aura",   @"star.fill",                         WAGR_ORANGE()},
        {@"🔐 Privacy",          @"lock.shield.fill",                  WAGR_GREEN()},
        {@"💬 Chat",             @"bubble.left.and.bubble.right.fill", WAGR_INDIGO()},
        {@"⊞ Tab Bar",          @"square.grid.2x2.fill",              WAGR_TEAL()},
        {@"🔧 Dogfood",          @"ant.fill",                          WAGR_RED()},
        {@"🤖 AI & Meta AI",     @"sparkles",                          WAGR_PURPLE()},
    };
    UIViewController *vc=(UIViewController*)vcArr[(NSUInteger)row];
    NSUInteger on=0,tot=0;
    if([vc isKindOfClass:WAGramBundleVC.class]){WAGramBundleVC*b=(WAGramBundleVC*)vc;on=[b onCount];tot=b.allFlags.count;}
    if([vc isKindOfClass:WAGRABFlagBrowserVC.class]){WAGRABFlagBrowserVC*b=(WAGRABFlagBrowserVC*)vc;for(NSString*f in b.allFlags)if(FlagOn(f))on++;tot=b.allFlags.count;}
    UITableViewCell *c=WAGRIconCell(info[row].i,info[row].c,info[row].t,
        on>0?[NSString stringWithFormat:@"%lu/%lu ativos",(unsigned long)on,(unsigned long)tot]:@"Sistema",
        UITableViewCellAccessoryDisclosureIndicator);
    c.detailTextLabel.textColor=on>0?WAGR_GREEN():WAGR_SEC();
    objc_setAssociatedObject(c,&kBundleAssoc,vc,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return c;
}

// ── Section 2: Runtime browsers ───────────────────────────────────────────────
- (UITableViewCell*)browserCellForRow:(NSInteger)row {
    struct{NSString*t,*d,*i;UIColor*c;}b[]={
        {@"WAABProperties",   @"~7000 flags — scan ao entrar",     @"magnifyingglass",      WAGR_ACCENT()},
        {@"Aura Gating",      @"WAAuraGating + subscription classes",@"star.circle.fill",   WAGR_ORANGE()},
        {@"Context / Debug",  @"isDebugBuild, isDebugMenuAllowed…",@"ant.circle.fill",      WAGR_RED()},
    };
    return WAGRIconCell(b[row].i,b[row].c,b[row].t,b[row].d,UITableViewCellAccessoryDisclosureIndicator);
}

// ── Cell dispatch ──────────────────────────────────────────────────────────────
- (UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    if(ip.section==0)return [self masterCellForRow:ip.row];
    if(ip.section==1)return [self bundleCellForRow:ip.row];
    if(ip.section==2)return [self browserCellForRow:ip.row];
    if(ip.section==3)return WAGRIconCell(@"hammer.fill",WAGR_ORANGE(),@"Debug Build Gates",@"isDebugBuild, RC, TestFlight, Beta — tudo toggleável",UITableViewCellAccessoryDisclosureIndicator);
    if(ip.section==4)return WAGRIconCell(@"square.grid.2x2",WAGR_ACCENT(),@"Settings Rows",@"31 células com gates — ligar e desligar",UITableViewCellAccessoryDisclosureIndicator);
    // Section 5: Actions
    struct{NSString*t,*i;UIColor*c;}a[]={
        {@"Reiniciar WhatsApp", @"arrow.counterclockwise.circle.fill", WAGR_RED()},
        {@"Reset completo (wagr.* + native)", @"trash.fill",           WAGR_ORANGE()},
    };
    UITableViewCell *c=WAGRIconCell(a[ip.row].i,a[ip.row].c,a[ip.row].t,@"",UITableViewCellAccessoryNone);
    c.textLabel.textAlignment=NSTextAlignmentCenter;
    return c;
}

// ── didSelectRow ──────────────────────────────────────────────────────────────
- (void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if(ip.section==1) {
        UITableViewCell *c=[tv cellForRowAtIndexPath:ip];
        UIViewController *vc=(UIViewController*)objc_getAssociatedObject(c,&kBundleAssoc);
        if(vc)[self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if(ip.section==2) {
        UIViewController *vc=nil;
        if(ip.row==0)vc=[WAGRRuntimeBrowserVC browserForWAABProperties];
        if(ip.row==1)vc=[WAGRRuntimeBrowserVC browserForAuraGating];
        if(ip.row==2)vc=[WAGRRuntimeBrowserVC browserForContextGates];
        if(vc)[self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if(ip.section==3)[self.navigationController pushViewController:[[WAGRContextToggleVC alloc]init] animated:YES];
    if(ip.section==4)[self.navigationController pushViewController:[[WAGRSettingsRowsVC alloc]init] animated:YES];
    if(ip.section==5) {
        if(ip.row==0) {
            UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Reiniciar?" message:nil preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Reiniciar" style:UIAlertActionStyleDestructive handler:^(id _){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{exit(0);});}]];
            [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
            [TopVC() presentViewController:a animated:YES completion:nil];
        } else {
            UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Reset completo?" message:@"Remove wagr.*, wagr.context.*, chaves nativas. CFPreferencesAppSynchronize. Reinicia após 1.5s." preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"Resetar" style:UIAlertActionStyleDestructive handler:^(id _){
                NSUserDefaults *ud=NSUserDefaults.standardUserDefaults;
                    for(NSString *k in [[ud dictionaryRepresentation] allKeys]) {
                        if ([k hasPrefix:@"wagr."]
                        || [k hasPrefix:@"ios_liquid_glass_"]
                        || [k hasPrefix:@"aura_"]) {
                        [ud removeObjectForKey:k];
                    }
                    }
                [ud synchronize]; WAGRLGPrefsDidChange();
                CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{exit(0);});
            }]];
            [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
            [TopVC() presentViewController:a animated:YES completion:nil];
        }
    }
}
@end
