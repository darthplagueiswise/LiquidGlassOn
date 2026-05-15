// WAGramMenuVC.m — WAGram v3
// Professional dark-mode UI with:
//   • UISwitch for all flags (ON = @"on", OFF removes override)
//   • Dynamic WAGRABFlagBrowserVC: shows ALL WAABProperties bool methods at runtime
//   • Search in dynamic browser
//   • Featured curated sections
//   • Restart WhatsApp button

#import "WAGramMenuVC.h"
#import "../WAUtils.h"
#import "../WAGramPrefix.h"

// ── Accent colour ─────────────────────────────────────────────────────────────
static UIColor *WAGRAccent(void)  { return [UIColor systemBlueColor]; }
static UIColor *WAGRBG(void)      { return [UIColor systemGroupedBackgroundColor]; }
static UIColor *WAGRCellBG(void)  { return [UIColor secondarySystemGroupedBackgroundColor]; }

// ── NSUserDefaults helpers (on/off strings) ───────────────────────────────────
static BOOL WAGRFlagIsOn(NSString *flag) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)] isEqualToString:@"on"];
}
static void WAGRFlagSet(NSString *flag, BOOL on) {
    if (on) [[NSUserDefaults standardUserDefaults] setObject:@"on" forKey:WAGRKey(flag)];
    else    [[NSUserDefaults standardUserDefaults] removeObjectForKey:WAGRKey(flag)];
    [[NSUserDefaults standardUserDefaults] synchronize];
    WAGRWAABEnsureHooksInstalled();
    // Cascade for LiquidGlass
    if ([flag containsString:@"liquid_glass"] || [flag isEqualToString:@"status_viewer_redesign_enabled"])
        WAGRLGPrefsDidChange();
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
        if (c.presentedViewController)              { c = c.presentedViewController; continue; }
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

// ── Row / Section models ──────────────────────────────────────────────────────
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

// ── Section header view ───────────────────────────────────────────────────────
@interface WAGRHeaderView : UIView
- (instancetype)initWithTitle:(NSString *)title;
@end
@implementation WAGRHeaderView {
    UILabel *_lbl;
}
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

// ── Cell IDs ──────────────────────────────────────────────────────────────────
static NSString *const kIDSW  = @"sw";
static NSString *const kIDNAV = @"nav";
static NSString *const kIDBTN = @"btn";
static NSString *const kIDAB  = @"ab";

// ═════════════════════════════════════════════════════════════════════════════
// WAGRABFlagBrowserVC — Dynamic WAAB flag browser
// Scans WAABProperties methods at runtime, shows all bool flags with current state.
// ═════════════════════════════════════════════════════════════════════════════
@interface WAGRABFlagBrowserVC () <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSString *> *allFlags;
@property (nonatomic, strong) NSArray<NSString *> *filtered;
@property (nonatomic, strong) UISearchController  *searchCtrl;
@end

@implementation WAGRABFlagBrowserVC

- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags {
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title  = title;
    _allFlags   = [flags sortedArrayUsingSelector:@selector(compare:)] ?: @[];
    _filtered   = _allFlags;
    return self;
}

// Scan WAABProperties at runtime to get all bool methods
+ (NSArray<NSString *> *)runtimeFlags {
    Class cls = NSClassFromString(@"WAABProperties");
    if (!cls) return @[];
    NSMutableArray *out = [NSMutableArray array];
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        Method m = methods[i];
        if (method_getNumberOfArguments(m) != 2) continue;
        char ret[8] = {0};
        method_getReturnType(m, ret, sizeof(ret));
        if (ret[0] != 'B' && ret[0] != 'c') continue;
        NSString *name = NSStringFromSelector(method_getName(m));
        if ([name containsString:@":"])  continue;
        if (name.length < 4 || name.length > 120) continue;
        [out addObject:name];
    }
    free(methods);
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WAGRBG();

    _searchCtrl = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchCtrl.searchResultsUpdater = self;
    _searchCtrl.obscuresBackgroundDuringPresentation = NO;
    _searchCtrl.searchBar.placeholder = @"Buscar flag…";
    self.navigationItem.searchController = _searchCtrl;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    // Active count badge
    [self updateTitle];

    // Reload button
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                             target:self action:@selector(reloadFlags)];
}

- (void)updateTitle {
    NSUInteger active = 0;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in _allFlags)
        if ([[ud stringForKey:WAGRKey(f)] isEqualToString:@"on"]) active++;
    self.navigationItem.title = active > 0
        ? [NSString stringWithFormat:@"%@ (%lu on)", self.title, (unsigned long)active]
        : self.title;
}

- (void)reloadFlags {
    // If no flags provided, scan runtime
    if (_allFlags.count == 0) {
        _allFlags = [WAGRABFlagBrowserVC runtimeFlags];
    }
    [self updateSearchResults:_searchCtrl.searchBar.text];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    [self updateSearchResults:sc.searchBar.text];
}
- (void)updateSearchResults:(NSString *)query {
    if (!query.length) {
        _filtered = _allFlags;
    } else {
        NSString *q = [query lowercaseString];
        _filtered = [_allFlags filteredArrayUsingPredicate:
                     [NSPredicate predicateWithFormat:@"SELF contains[c] %@", q]];
    }
    [self.tableView reloadData];
    [self updateTitle];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)_filtered.count;
}

static const char kBrowserFlagKey = 0;

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:kIDAB];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kIDAB];

    NSString *flag = _filtered[(NSUInteger)ip.row];
    BOOL isOn = WAGRFlagIsOn(flag);

    cell.backgroundColor = WAGRCellBG();
    cell.textLabel.text  = flag;
    cell.textLabel.font  = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    cell.textLabel.textColor = UIColor.labelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Show system value if known
    Class cls = NSClassFromString(@"WAABProperties");
    if (cls && !isOn) {
        // Try to read the current system value (if WAABProperties is accessible)
        cell.detailTextLabel.text = @"";
        cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    } else {
        cell.detailTextLabel.text = isOn ? @"force ON" : @"";
        cell.detailTextLabel.textColor = UIColor.systemGreenColor;
    }

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = isOn;
    sw.onTintColor = WAGRAccent();
    objc_setAssociatedObject(sw, &kBrowserFlagKey, flag, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [sw addTarget:self action:@selector(flagSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)flagSwitchChanged:(UISwitch *)sw {
    NSString *flag = objc_getAssociatedObject(sw, &kBrowserFlagKey);
    WAGRFlagSet(flag, sw.isOn);
    // Find the cell and update its detail
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        if ([objc_getAssociatedObject(cell.accessoryView, &kBrowserFlagKey) isEqualToString:flag]) {
            cell.detailTextLabel.text = sw.isOn ? @"force ON" : @"";
        }
    }
    [self updateTitle];
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 58; }
@end

// ═════════════════════════════════════════════════════════════════════════════
// WAGramSubMenuVC — Curated sub-menus
// ═════════════════════════════════════════════════════════════════════════════
static const char kSubFlagKey = 0;

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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return (NSInteger)_sections.count; }
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

    if (row.style == WAGramRowStyleWAABFlag) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:kIDAB];
        if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kIDAB];
        c.backgroundColor = WAGRCellBG();
        c.textLabel.text = row.title;
        c.textLabel.textColor = UIColor.labelColor;
        c.detailTextLabel.text = row.waabKey;
        c.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        c.detailTextLabel.textColor = UIColor.secondaryLabelColor;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = WAGRFlagIsOn(row.waabKey);
        sw.onTintColor = WAGRAccent();
        objc_setAssociatedObject(sw, &kSubFlagKey, row.waabKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [sw addTarget:self action:@selector(waabSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        c.accessoryView = sw;
        return c;
    }
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
        [sw addTarget:self action:@selector(prefSwitchChanged:) forControlEvents:UIControlEventValueChanged];
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

- (void)waabSwitchChanged:(UISwitch *)sw {
    NSString *flag = objc_getAssociatedObject(sw, &kSubFlagKey);
    WAGRFlagSet(flag, sw.isOn);
}
- (void)prefSwitchChanged:(UISwitch *)sw {
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
// Sub-menu builders
// ═════════════════════════════════════════════════════════════════════════════
#define WAAB(k,t)     [WAGramRow waabWithTitle:(t) key:(k)]
#define SW(k,t,s,a)   [WAGramRow switchWithTitle:(t) subtitle:(s) key:(k) action:(a)]
#define BTN(t,a)      [WAGramRow buttonWithTitle:(t) action:(a)]
#define NAV(t,s,vc)   [WAGramRow navWithTitle:(t) subtitle:(s) target:(vc)]
#define SEC(h,f,...)  [WAGramSectionDef sectionWithHeader:(h) footer:(f) rows:@[__VA_ARGS__]]

// Helper: make a runtime flag browser from token filters.
// Uses the exact same source as “ALL WAABProperties Flags”: WAGRABFlagBrowserVC runtimeFlags.
// Category menus are filtered views of the live WAABProperties selector list.
static NSArray<NSString *> *WAGRRuntimeFlagsMatchingTokens(NSArray<NSString *> *tokens) {
    NSArray<NSString *> *all = [WAGRABFlagBrowserVC runtimeFlags];
    if (!tokens.count) return all;
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (NSString *flag in all) {
        NSString *lower = flag.lowercaseString;
        for (NSString *tok in tokens) {
            if ([lower containsString:tok.lowercaseString]) {
                [out addObject:flag];
                break;
            }
        }
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}

static UIViewController *browserVC(NSString *title, NSArray<NSString *> *tokens) {
    WAGRABFlagBrowserVC *vc = [[WAGRABFlagBrowserVC alloc] initWithTitle:title
                                                                   flags:WAGRRuntimeFlagsMatchingTokens(tokens)];
    return vc;
}

// ── Liquid Glass (exact mirror of working dylib) ──────────────────────────────
static UIViewController *LGSubVC(void) {
    NSArray *wdsFlags = @[
        @"WDSLiquidGlass.hasLiquidGlassLaunched",
        @"WDSLiquidGlass.isM0Enabled",
        @"WDSLiquidGlass.isM1Enabled",
        @"WDSLiquidGlass.isM1_5Enabled",
        @"WDSLiquidGlass.isM1_5ContextMenuEnabled",
        @"WDSLiquidGlass.isLargerComposerEnabled",
        @"WDSLiquidGlass.isNativeSidebarEnabled",
        @"WDSLiquidGlass.shouldUseNativeSwipeActions",
    ];
    // Build WDS rows as info-only (controlled by LiquidGlass master switch)
    NSMutableArray *wdsRows = [NSMutableArray array];
    for (NSString *f in wdsFlags) {
        [wdsRows addObject:BTN(f, ^(BOOL _){
            WAGRAlert(@"WDSLiquidGlass", @"This class method is hooked at startup via %hook WDSLiquidGlass in WALiquidGlassHooks.xm — always returns YES when LiquidGlass Master is ON. Controlado pelo master toggle na tela principal.");
        })];
    }
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"LiquidGlass Master",
            @"Liga/desliga via o toggle na tela principal. Estas 3 camadas trabalham juntas: NSUserDefaults keys + WDSLiquidGlass class method hooks + WAABProperties direct method hooks.",
            SW(WA_PREF_LIQUID_GLASS, @"LiquidGlass Master", @"Ativa todas as camadas LG", ^(BOOL _){ WAGRLGPrefsDidChange(); })
        ),
        SEC(@"WAABProperties direct methods",
            @"Cada método é hookado diretamente em WAABProperties. Toggle ON = retorna YES independente do servidor.",
            WAAB(@"ios_liquid_glass_enabled",              @"LG Enabled"),
            WAAB(@"ios_liquid_glass_launched",             @"LG Launched"),
            WAAB(@"ios_liquid_glass_media_m0",             @"LG Media M0"),
            WAAB(@"ios_liquid_glass_m1",                   @"LG M1"),
            WAAB(@"ios_liquid_glass_m_1_5",                @"LG M1.5"),
            WAAB(@"ios_liquid_glass_m_1_5_context_menu",   @"LG M1.5 Context Menu"),
            WAAB(@"ios_liquid_glass_larger_composer",      @"LG Larger Composer"),
            WAAB(@"ios_liquid_glass_media_editor_enabled", @"LG Media Editor"),
            WAAB(@"ios_liquid_glass_calling_improvement_enabled", @"LG Calling"),
            WAAB(@"ios_liquid_glass_reduce_transparency",  @"LG Reduce Transparency"),
            WAAB(@"ios_liquid_glass_fixes_for_older_ios",  @"LG Fixes (older iOS)"),
            WAAB(@"ios_liquid_glass_workaround_attachment_tray", @"LG Fix: Attachment Tray"),
            WAAB(@"ios_liquid_glass_chat_top_bar_m2_enabled", @"LG Chat Top Bar M2"),
            WAAB(@"ios_liquid_glass_media_editor_enabled", @"LG Media Editor"),
            WAAB(@"status_viewer_redesign_enabled",        @"Status Viewer Redesign")
        ),
        [WAGramSectionDef sectionWithHeader:@"WDSLiquidGlass class methods"
                                     footer:@"Controlados pelo master toggle. Não configurable individualmente."
                                       rows:wdsRows],
        SEC(@"WAAB Runtime — LiquidGlass",
            @"Lista dinâmica baseada no mesmo ALL WAABProperties FLAGS.",
            NAV(@"Todas flags LiquidGlass reais", @"liquid_glass, status_viewer_redesign", browserVC(@"LiquidGlass Runtime", @[@"liquid_glass", @"status_viewer_redesign"]))
        ),
        SEC(@"Diagnóstico",@"",
            BTN(@"LiquidGlass Diagnostic", ^(BOOL _){ WAGRAlert(@"LiquidGlass", WAGRLGDiagnosticText()); })
        ),
    ] title:@"Liquid Glass"];
}

// ── About / Evolve About (recado redesign) ────────────────────────────────────
static UIViewController *AboutSubVC(void) {
    return browserVC(@"About / Recado", @[@"about", @"evolve_about", @"recado"]);
}

// ── Translation ───────────────────────────────────────────────────────────────
static UIViewController *TranslationSubVC(void) {
    return browserVC(@"Translation", @[@"translate", @"translation"]);
}

// ── Debug / Developer Menu ────────────────────────────────────────────────────
static UIViewController *DebugMenuSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Native Debug Menu Gate",
            @"isDebugMenuAllowed em WASettingsViewController (WA:107333). ON = Developer cell aparece nas Settings → acessa WADebugMenuMain nativo do WA.",
            SW(kWAGRDebugMenuNative, @"isDebugMenuAllowed = YES",
               @"Mostra SettingsView_DeveloperCell → WADebugMenuMain",
               ^(BOOL on){ WAGRDebugMenuEnsureHooksInstalled(); }),
            BTN(@"Debug Menu Diagnostic", ^(BOOL _){ WAGRAlert(@"Debug Menu", WAGRDebugMenuDiagnosticText()); })
        ),
    ] title:@"Debug / Developer Menu"];
}

// ── Dogfood / Employee ────────────────────────────────────────────────────────
static UIViewController *DogfoodSubVC(void) {
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"Direct ObjC Selector Hooks",
            @"MSHookMessageEx em runtime scan. A lógica: primeiro hookamos estas funções. Quando o app chama 'sou employee?', o hook responde SIM. Aí as features que checam isso funcionam.",
            SW(kWAGREmployeeMaster, @"Employee Master",
               @"Força todos os 4 gates abaixo ao mesmo tempo",
               ^(BOOL on){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRInternalMaster, @"Internal Master",
               @"Força paths internal/debug complementares usados por WAAB e menus nativos",
               ^(BOOL on){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateMetaEmployee, @"isMetaEmployeeOrInternalTester",
               @"WA:136909 / SM:94927 → YES",
               ^(BOOL on){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateMetaEmployeeSnake, @"is_meta_employee_or_internal_tester",
               @"SM:73827 → YES",
               ^(BOOL on){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateInternalUser, @"isInternalUser",
               @"WA:94156 → YES",
               ^(BOOL on){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDogfoodGateGraphQLEmpC1, @"graphQLEmployeeC1Disabled",
               @"WA:94150 → NO (= C1 enabled)",
               ^(BOOL on){ WAGRDogfoodEnsureHooksInstalled(); }),
            BTN(@"Dogfood Diagnostic", ^(BOOL _){ WAGRAlert(@"Dogfood", WAGRDogfoodDiagnosticText()); })
        ),
        SEC(@"WAAB Runtime — Debug/Dogfood/Internal",
            @"Lista dinâmica baseada no mesmo ALL WAABProperties FLAGS. Essas são as flags reais que existem no runtime.",
            NAV(@"Todas flags Debug/Dogfood/Internal reais", @"internal, dogfood, employee, debug, tester, diagnostics", browserVC(@"Debug/Dogfood/Internal Runtime", @[@"internal", @"dogfood", @"employee", @"debug", @"tester", @"diagnostic", @"diagnostics"]))
        ),
        SEC(@"WAAB Bool Flags — via method hook",
            @"Via WAABProperties direct method hook.",
            WAAB(@"is_internal_tester",          @"is_internal_tester"),
            WAAB(@"mobile_config_debug_internal", @"mobile_config_debug_internal"),
            WAAB(@"dogfooder_diagnostics",        @"dogfooder_diagnostics"),
            WAAB(@"ios_internal_hall_enabled",    @"ios_internal_hall_enabled"),
            WAAB(@"defense_mode_available",       @"defense_mode_available"),
            WAAB(@"ios_optic_debug_indicator_enabled", @"ios_optic_debug_indicator_enabled"),
            WAAB(@"visible_message_drop_placeholder_enabled_internal_only", @"Message Drop Placeholder")
        ),
    ] title:@"Dogfood / Internal"];
}

// ── AI & Meta AI (dynamic browser for the full AI set) ───────────────────────
static UIViewController *AISubVC(void) {
    // Curated important ones + dynamic runtime browser
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        SEC(@"WAAB Runtime — AI",
            @"Lista dinâmica baseada no mesmo ALL WAABProperties FLAGS.",
            NAV(@"Todas flags AI reais", @"ai_, meta_ai, incognito, side_chat, hatch", browserVC(@"AI Runtime", @[@"ai_", @"meta_ai", @"incognito", @"side_chat", @"hatch"]))
        ),
        SEC(@"Meta AI — Main Gate",
            @"Flags que controlam a aba/tab Meta AI.",
            WAAB(@"ai_meta_ai_in_app_tab_main_gate_enabled", @"Meta AI Tab Main Gate"),
            WAAB(@"ai_home_redesign_enabled",                @"AI Home Redesign"),
            WAAB(@"ai_psi_ux_enabled",                       @"AI PSI UX"),
            WAAB(@"ai_search_bar_2025_redesign_enabled",     @"AI Search Bar 2025"),
            WAAB(@"ai_tab_glyph_icon_enabled",               @"AI Tab Glyph Icon"),
            WAAB(@"ai_tab_perf_optimizations_enabled",       @"AI Tab Perf Optimizations")
        ),
        SEC(@"Incognito AI Chat",
            @"Feature anunciada pelo Zuckerberg.",
            WAAB(@"ai_incognito_mode_enabled",               @"Incognito AI Chat"),
            WAAB(@"ai_incognito_mode_disappearing_messages_enabled", @"Incognito Disappearing Msgs"),
            WAAB(@"ai_incognito_mode_personalization_enabled",@"Incognito Personalization"),
            WAAB(@"ai_incognito_media_input_enabled",        @"Incognito Media Input")
        ),
        SEC(@"Translation",
            @"Feature de tradução de mensagens.",
            WAAB(@"ai_translate_messages_enabled",           @"Translate Messages")
        ),
        SEC(@"Side Chat",
            @"",
            WAAB(@"ai_side_chat_enabled",                    @"AI Side Chat"),
            WAAB(@"ai_side_chat_search_starter_enabled",     @"Side Chat Search"),
            WAAB(@"ai_side_chat_summarization_enabled",      @"Side Chat Summarize"),
            WAAB(@"ai_side_chat_writing_help_enabled",       @"Side Chat Writing Help"),
            WAAB(@"ai_side_chat_image_creation_enabled",     @"Side Chat Image Create"),
            WAAB(@"ai_side_chat_media_input_enabled",        @"Side Chat Media Input"),
            WAAB(@"ai_side_chat_contextual_suggestions_enabled", @"Side Chat Suggestions"),
            WAAB(@"ai_side_chat_animation_enabled",          @"Side Chat Animation")
        ),
        SEC(@"Hatch",
            @"",
            WAAB(@"ai_hatch_integration_enabled",            @"AI Hatch Integration"),
            WAAB(@"ai_hatch_integration_tab_enabled",        @"AI Hatch Tab"),
            WAAB(@"ai_hatch_commands_enabled",               @"AI Hatch Commands"),
            WAAB(@"ai_hatch_video_upload_enabled",           @"AI Hatch Video Upload")
        ),
        SEC(@"Threads & Chat",
            @"",
            WAAB(@"ai_chat_threads_enabled",                 @"AI Chat Threads"),
            WAAB(@"ai_chat_threads_side_sheet_enabled",      @"AI Threads Side Sheet"),
            WAAB(@"ai_chat_threads_multiplayer_enabled",     @"AI Threads Multiplayer"),
            WAAB(@"ai_chat_threads_pin_enabled",             @"AI Threads Pin"),
            WAAB(@"ai_chat_list_search_enabled",             @"AI Chat List Search"),
            WAAB(@"ai_rewrite_in_edit_message_enabled",      @"AI Rewrite in Edit"),
            WAAB(@"ai_rich_response_tables_enabled",         @"AI Rich Response Tables")
        ),
        SEC(@"Ver todos os 325+ flags AI",
            @"",
            [WAGramRow navWithTitle:@"Browser AI flags"
                          subtitle:@"Lista dinâmica com search"
                            target:browserVC(@"AI Flags", @[
                @"ai_meta_ai_in_app_tab_main_gate_enabled", @"ai_home_redesign_enabled",
                @"ai_incognito_mode_enabled", @"ai_incognito_mode_disappearing_messages_enabled",
                @"ai_incognito_mode_personalization_enabled", @"ai_incognito_media_input_enabled",
                @"ai_translate_messages_enabled", @"ai_side_chat_enabled",
                @"ai_side_chat_search_starter_enabled", @"ai_side_chat_summarization_enabled",
                @"ai_side_chat_writing_help_enabled", @"ai_side_chat_image_creation_enabled",
                @"ai_side_chat_media_input_enabled", @"ai_side_chat_contextual_suggestions_enabled",
                @"ai_hatch_integration_enabled", @"ai_hatch_integration_tab_enabled",
                @"ai_hatch_commands_enabled", @"ai_chat_threads_enabled",
                @"ai_chat_threads_side_sheet_enabled", @"ai_chat_threads_multiplayer_enabled",
                @"ai_chat_threads_pin_enabled", @"ai_chat_list_search_enabled",
                @"ai_rewrite_in_edit_message_enabled", @"ai_rich_response_tables_enabled",
                @"ai_psi_ux_enabled", @"ai_bot_imagine_me_enabled",
                @"ai_bot_imagine_me_auto_capture_enabled", @"ai_bot_integration_enabled",
                @"ai_genai_imagine_intent_status_v3_enabled",
                @"ai_genai_imagine_intent_ar_effects_v3_enabled",
                @"ai_genai_imagine_intent_attachment_tray_enabled",
                @"ai_group_participation_enabled", @"ai_group_participation_send_enabled",
                @"ai_group_multi_modal_enabled",
                @"ai_voice_image_input_enabled", @"ai_voice_live_video_input_enabled",
                @"ai_voice_live_video_pip_enabled", @"ai_voice_ptt_coexistence_enabled",
                @"ai_fab_chat_list_refactor_enabled",
                @"ai_dynamic_mode_selector_enabled", @"ai_dynamic_model_branding_enabled",
                @"ai_tab_glyph_icon_enabled", @"ai_tab_perf_optimizations_enabled",
                @"ai_search_bar_2025_redesign_enabled",
                @"ai_ask_meta_ai_in_media_viewer", @"ai_ask_metai_in_message_long_press",
                @"ai_stickers_rebranding_enabled", @"ai_account_linking_enabled",
            ])]
        ),
    ] title:@"AI & Meta AI"];
}

// ── Calls ─────────────────────────────────────────────────────────────────────
static UIViewController *CallsSubVC(void) {
    return browserVC(@"Calls", @[@"call", @"calling", @"callkit", @"scheduled_call"]);
}

// ── Status ────────────────────────────────────────────────────────────────────
static UIViewController *StatusSubVC(void) {
    return browserVC(@"Status / Stories", @[@"status", @"story", @"stories"]);
}

// ── Channels ──────────────────────────────────────────────────────────────────
static UIViewController *ChannelsSubVC(void) {
    return browserVC(@"Channels", @[@"channel", @"newsletter", @"broadcast"]);
}

// ── Groups & Interop ──────────────────────────────────────────────────────────
static UIViewController *GroupsSubVC(void) {
    return browserVC(@"Groups & Interop", @[@"group", @"community", @"interop", @"poll", @"scheduled", @"recall"]);
}

// ── Privacy & Username ────────────────────────────────────────────────────────
static UIViewController *PrivacySubVC(void) {
    return browserVC(@"Privacy & Username", @[@"privacy", @"username", @"passkey", @"defense", @"secure"]);
}

// ── Premium & Business ────────────────────────────────────────────────────────
static UIViewController *PremiumSubVC(void) {
    return browserVC(@"Premium & Business", @[@"premium", @"business", @"smb", @"subscription", @"catalog", @"verified", @"waffle"]);
}

// ── System / Debug ────────────────────────────────────────────────────────────
static UIViewController *SystemSubVC(void) {
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
            @"Logs all WAABProperties calls.",
            SW(WA_PREF_AB_OBSERVER, @"WAAB Observer",
               @"Log todas as getter calls", ^(BOOL _){ WAGRWAABEnsureHooksInstalled(); }),
            BTN(@"Ver WAAB Log",      ^(BOOL _){ WAGRAlert(@"WAAB Log",     WAGRABObsLog()); }),
            BTN(@"Limpar WAAB Log",   ^(BOOL _){ WAGRABObsClear(); }),
            BTN(@"WAAB Diagnostic",   ^(BOOL _){ WAGRAlert(@"WAAB",         WAGRWAABDiagnosticText()); })
        ),
        SEC(@"Overrides",
            @"",
            SW(@"wagr_debug_mode_enabled", @"Debug Logging",
               @"NSLog [LiquidGlassOn] no Console.app", nil),
            BTN(@"Reset TODOS os overrides WAAB", ^(BOOL _){
                NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
                NSDictionary *all = [ud dictionaryRepresentation];
                NSUInteger n = 0;
                for (NSString *k in all)
                    if ([k hasPrefix:@"wagr.waab."]) { [ud removeObjectForKey:k]; n++; }
                [ud synchronize];
                WAGRAlert(@"Reset", [NSString stringWithFormat:@"Removidas %lu entradas.", (unsigned long)n]);
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
    // Dynamic browser: all WAABProperties bool methods from runtime
    WAGRABFlagBrowserVC *runtimeBrowser = [[WAGRABFlagBrowserVC alloc] initWithTitle:@"Todos os Flags" flags:@[]];
    [runtimeBrowser reloadFlags]; // scan at init

    _sections = @[
        // ── Masters ──────────────────────────────────────────────────────────
        SEC(@"Masters",
            @"LiquidGlass: Logos %hook direto em WDSLiquidGlass + WAABProperties. Employee/Dogfood: MSHookMessageEx nos selectors ObjC. Quando uma feature pergunta 'sou internal?', o hook já está lá para responder SIM. Persistência via NSUserDefaults + restart.",
            SW(WA_PREF_LIQUID_GLASS, @"🔵  Liquid Glass",
               @"WDSLiquidGlass + WAABProperties Logos hooks",
               ^(BOOL _){ WAGRLGPrefsDidChange(); }),
            SW(kWAGREmployeeMaster, @"👤  Employee / Dogfood Gates",
               @"isMetaEmployee · isInternalUser · graphQLEmpC1",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRInternalMaster, @"🧪  Internal Master",
               @"Força gates internal/debug/dogfood complementares",
               ^(BOOL _){ WAGRDogfoodEnsureHooksInstalled(); }),
            SW(kWAGRDebugMenuNative, @"🐛  Native Debug Menu",
               @"isDebugMenuAllowed = YES → Developer cell nas Settings",
               ^(BOOL _){ WAGRDebugMenuEnsureHooksInstalled(); }),
            SW(WA_PREF_AB_OBSERVER, @"🔍  WAAB Observer",
               @"Log all WAABProperties method calls",
               ^(BOOL _){ WAGRWAABEnsureHooksInstalled(); })
        ),
        // ── Feature Flags ─────────────────────────────────────────────────────
        SEC(@"Feature Flags",
            @"Toggle ON persiste em NSUserDefaults. Hook lê o valor e retorna YES/NO para a app. Para features que inicializam em ViewController, use Restart após ativar.",
            NAV(@"🔵  Liquid Glass",        @"WDSLiquidGlass + WAABProperties — mirror exato do dylib",    LGSubVC()),
            NAV(@"📝  About / Recado",      @"evolve_about_m1_receiver_enabled",                           AboutSubVC()),
            NAV(@"🌐  Translation",         @"ai_translate_messages_enabled",                              TranslationSubVC()),
            NAV(@"🐛  Debug / Dev Menu",    @"isDebugMenuAllowed · WADebugMenuMain",                        DebugMenuSubVC()),
            NAV(@"👤  Dogfood / Internal",  @"4 direct hooks + WAAB flags",                                DogfoodSubVC()),
            NAV(@"🤖  AI & Meta AI",        @"35+ flags: incognito, side chat, hatch, imagine, voice",     AISubVC()),
            NAV(@"📞  Calls",               @"20 flags",                                                   CallsSubVC()),
            NAV(@"✅  Status",              @"25 flags",                                                   StatusSubVC()),
            NAV(@"📢  Channels",            @"20 flags",                                                   ChannelsSubVC()),
            NAV(@"👥  Groups & Interop",    @"20 flags incl. polls, recall, scheduled",                    GroupsSubVC()),
            NAV(@"🔐  Privacy & Username",  @"18 flags incl. passkey, defense mode",                       PrivacySubVC()),
            NAV(@"⭐  Premium & Business",  @"16 flags",                                                   PremiumSubVC()),
            NAV(@"⚙️  Sistema & Debug",     @"Keychain, WAAB log, reset",                                 SystemSubVC())
        ),
        // ── Browser dinâmico ─────────────────────────────────────────────────
        SEC(@"All WAABProperties Flags",
            @"Lista dinâmica: escaneia WAABProperties em runtime e mostra TODOS os métodos booleanos com seu estado atual. Use search para encontrar qualquer flag.",
            NAV(@"🔎  Browser — Todos os flags",
                @"Runtime scan + search",
                runtimeBrowser)
        ),
        // ── Actions ───────────────────────────────────────────────────────────
        SEC(@"",
            @"Restart fecha o WhatsApp. Necessário para features que inicializam em viewDidLoad (não apenas lêem flag em runtime).",
            BTN(@"Reiniciar WhatsApp", ^(BOOL _){
                UIAlertController *a = [UIAlertController
                    alertControllerWithTitle:@"Reiniciar WhatsApp?"
                                     message:@"Fecha o app. Reabra para aplicar os hooks de startup."
                              preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"Reiniciar"
                                                     style:UIAlertActionStyleDestructive
                                                   handler:^(id _){
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3*NSEC_PER_SEC)),
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
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSelf)];
}
- (void)dismissSelf { [self dismissViewControllerAnimated:YES completion:nil]; }

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
        [sw addTarget:self action:@selector(prefSwitchChanged:) forControlEvents:UIControlEventValueChanged];
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
    // Button
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

- (void)prefSwitchChanged:(UISwitch *)sw {
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
