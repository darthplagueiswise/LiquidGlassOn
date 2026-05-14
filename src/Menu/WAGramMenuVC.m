// WAGramMenuVC.m
// ─────────────────────────────────────────────────────────────────────────────

#import "WAGramMenuVC.h"

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramRow
// ═══════════════════════════════════════════════════════════════════════════════
@implementation WAGramRow

+ (instancetype)switchWithTitle:(NSString *)title
                       subtitle:(NSString *)subtitle
                            key:(NSString *)key
                         action:(void (^)(BOOL))action {
    WAGramRow *r = [self new];
    r.title    = title;
    r.subtitle = subtitle;
    r.prefsKey = key;
    r.style    = WAGramRowStyleSwitch;
    r.action   = action;
    return r;
}

+ (instancetype)buttonWithTitle:(NSString *)title
                        subtitle:(NSString *)subtitle
                          action:(void (^)(BOOL))action {
    WAGramRow *r = [self new];
    r.title    = title;
    r.subtitle = subtitle;
    r.style    = WAGramRowStyleButton;
    r.action   = action;
    return r;
}

+ (instancetype)navWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       target:(UIViewController *)target {
    WAGramRow *r = [self new];
    r.title     = title;
    r.subtitle  = subtitle;
    r.style     = WAGramRowStyleNavigation;
    r.navTarget = target;
    return r;
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramSectionDef
// ═══════════════════════════════════════════════════════════════════════════════
@implementation WAGramSectionDef

+ (instancetype)sectionWithHeader:(NSString *)header
                           footer:(NSString *)footer
                             rows:(NSArray<WAGramRow *> *)rows {
    WAGramSectionDef *s = [self new];
    s.header = header;
    s.footer = footer;
    s.rows   = rows ?: @[];
    return s;
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════
static UIViewController *WAGRTopVC(void) {
    UIApplication *app = UIApplication.sharedApplication;
    UIViewController *root = nil;
    for (UIScene *sc in app.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows) {
            if (w.isKeyWindow && w.rootViewController) { root = w.rootViewController; break; }
        }
        if (root) break;
    }
    UIViewController *cur = root;
    while (YES) {
        if (cur.presentedViewController) { cur = cur.presentedViewController; continue; }
        if ([cur isKindOfClass:UINavigationController.class]) {
            UIViewController *v = ((UINavigationController *)cur).visibleViewController;
            if (v && v != cur) { cur = v; continue; }
        }
        if ([cur isKindOfClass:UITabBarController.class]) {
            UIViewController *v = ((UITabBarController *)cur).selectedViewController;
            if (v && v != cur) { cur = v; continue; }
        }
        break;
    }
    return cur;
}

static void WAGRShowAlert(UIViewController *from, NSString *title, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = WAGRTopVC();
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title ?: @"WAGram"
                                                                   message:msg ?: @""
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copy" style:UIAlertActionStyleDefault handler:^(UIAlertAction *__unused x){
            UIPasteboard.generalPasteboard.string = msg ?: @"";
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [top presentViewController:a animated:YES completion:nil];
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WAGramSubMenuVC
// ═══════════════════════════════════════════════════════════════════════════════
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)_sections[(NSUInteger)s].rows.count;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].header;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    NSString *rId = (row.style == WAGramRowStyleSwitch) ? @"SW" :
                    (row.style == WAGramRowStyleNavigation) ? @"NAV" : @"BTN";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:rId];
    if (!cell) {
        UITableViewCellStyle sty = row.subtitle.length ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
        cell = [[UITableViewCell alloc] initWithStyle:sty reuseIdentifier:rId];
    }
    cell.textLabel.text       = row.title;
    cell.detailTextLabel.text = row.subtitle;

    // Remove old accessory views
    cell.accessoryType  = UITableViewCellAccessoryNone;
    cell.accessoryView  = nil;

    if (row.style == WAGramRowStyleSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = row.prefsKey ? [[NSUserDefaults standardUserDefaults] boolForKey:row.prefsKey] : NO;
        sw.tag = (ip.section << 16) | ip.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (row.style == WAGramRowStyleNavigation) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.textColor = self.view.tintColor;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSInteger sec = sw.tag >> 16;
    NSInteger row = sw.tag & 0xFFFF;
    WAGramRow *r = _sections[(NSUInteger)sec].rows[(NSUInteger)row];
    if (r.prefsKey) {
        [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:r.prefsKey];
    }
    if (r.action) r.action(sw.isOn);
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style == WAGramRowStyleNavigation && row.navTarget) {
        [self.navigationController pushViewController:row.navTarget animated:YES];
    } else if (row.style == WAGramRowStyleButton && row.action) {
        row.action(NO);
    }
}
@end

// ═══════════════════════════════════════════════════════════════════════════════
// Section builders
// ═══════════════════════════════════════════════════════════════════════════════

#pragma mark - LiquidGlass sections

static UIViewController *WAGRBuildLiquidGlassVC(void) {
    NSArray<WAGramRow *> *rows = @[
        [WAGramRow switchWithTitle:@"ios_liquid_glass_enabled"
                          subtitle:@"Master enable flag"
                               key:kWAGRLG_enabled
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_launched"
                          subtitle:@"Marks LG as launched"
                               key:kWAGRLG_launched
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_m1"
                          subtitle:@"M1 milestone"
                               key:kWAGRLG_m1
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_m_1_5"
                          subtitle:@"M1.5 milestone"
                               key:kWAGRLG_m1_5
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_m_1_5_context_menu"
                          subtitle:@"M1.5 context menus"
                               key:kWAGRLG_m1_5_context_menu
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_chat_top_bar_m2_enabled"
                          subtitle:@"Chat top bar M2"
                               key:kWAGRLG_chat_top_bar_m2
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_enable_new_chatbar_ux"
                          subtitle:@"New chatbar UX"
                               key:kWAGRLG_new_chatbar_ux
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_larger_composer"
                          subtitle:@"Larger message composer"
                               key:kWAGRLG_larger_composer
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_reduce_transparency"
                          subtitle:@"Reduce transparency"
                               key:kWAGRLG_reduce_transparency
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_workaround_attachment_tray"
                          subtitle:@"Workaround: attachment tray"
                               key:kWAGRLG_workaround_attachment_tray
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_workaround_hides_bottombar"
                          subtitle:@"Workaround: hides bottom bar"
                               key:kWAGRLG_workaround_hides_bottombar
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow switchWithTitle:@"ios_liquid_glass_workaround_topbar_appearance"
                          subtitle:@"Workaround: top bar appearance"
                               key:kWAGRLG_workaround_topbar_appearance
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
    ];

    NSArray<WAGramSectionDef *> *secs = @[
        [WAGramSectionDef sectionWithHeader:@"Sub-Flags"
                                     footer:@"Individual ABProp flags. Require LiquidGlass master to be ON."
                                       rows:rows]
    ];
    return [[WAGramSubMenuVC alloc] initWithSections:secs title:@"LiquidGlass Flags"];
}



#pragma mark - WAAB typed override catalog

static NSString *WAGRWAABPrefMode(NSString *key) { return [@"wagr.waab." stringByAppendingFormat:@"%@.mode", key ?: @""]; }
static NSString *WAGRWAABPrefNumber(NSString *key) { return [@"wagr.waab." stringByAppendingFormat:@"%@.number", key ?: @""]; }
static NSString *WAGRWAABPrefString(NSString *key) { return [@"wagr.waab." stringByAppendingFormat:@"%@.string", key ?: @""]; }
static NSString *WAGRWAABPrefRuntimeType(NSString *key) { return [@"wagr.waab.runtime." stringByAppendingFormat:@"%@.type", key ?: @""]; }
static NSString *WAGRWAABPrefRuntimeValue(NSString *key) { return [@"wagr.waab.runtime." stringByAppendingFormat:@"%@.value", key ?: @""]; }

static NSDictionary *WAGRWAABCatalogRoot(void) {
    static NSDictionary *root;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *paths = @[
            @"/Library/Application Support/WAGram/waab_selected_categories_getter_validated_catalog.json",
            [[NSBundle mainBundle] pathForResource:@"waab_selected_categories_getter_validated_catalog" ofType:@"json"] ?: @"",
            @"/var/mobile/Library/Application Support/WAGram/waab_selected_categories_getter_validated_catalog.json"
        ];
        for (NSString *path in paths) {
            if (!path.length) continue;
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (!data.length) continue;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:NSDictionary.class]) { root = json; break; }
        }
        if (!root) root = @{};
    });
    return root;
}

static NSArray<NSDictionary *> *WAGRWAABAllFlags(void) {
    id flags = WAGRWAABCatalogRoot()[@"flags"];
    return [flags isKindOfClass:NSArray.class] ? flags : @[];
}

static NSArray<NSString *> *WAGRWAABCategories(void) {
    id cats = WAGRWAABCatalogRoot()[@"selected_categories"];
    return [cats isKindOfClass:NSArray.class] ? cats : @[];
}

static NSString *WAGRWAABTitleForFlag(NSDictionary *flag) {
    NSString *title = [flag[@"title"] isKindOfClass:NSString.class] ? flag[@"title"] : nil;
    NSString *key = [flag[@"key"] isKindOfClass:NSString.class] ? flag[@"key"] : @"(missing key)";
    return title.length ? title : key;
}

static NSString *WAGRWAABCurrentState(NSString *key, NSString *type) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSInteger mode = [ud integerForKey:WAGRWAABPrefMode(key)];
    if ([type isEqualToString:@"bool"]) {
        if (mode == 1) return @"OFF";
        if (mode == 2) return @"ON";
        return @"System";
    }
    if ([type isEqualToString:@"number"]) {
        if (mode == 1) return [NSString stringWithFormat:@"Override %@", [ud objectForKey:WAGRWAABPrefNumber(key)] ?: @"0"];
        return @"System";
    }
    if ([type isEqualToString:@"string"]) {
        if (mode == 1) return [NSString stringWithFormat:@"Override %@", [ud stringForKey:WAGRWAABPrefString(key)] ?: @"\""];
        return @"System";
    }
    return @"Observe only";
}

@interface WAGramWAABFlagListVC : UITableViewController
@property (nonatomic, copy) NSString *category;
@property (nonatomic, strong) NSArray<NSDictionary *> *flags;
@end

@implementation WAGramWAABFlagListVC
- (instancetype)initWithCategory:(NSString *)category {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _category = [category copy];
    self.title = category;
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *flag in WAGRWAABAllFlags()) {
        NSString *section = [flag[@"menu_section"] isKindOfClass:NSString.class] ? flag[@"menu_section"] : @"uncategorized";
        if ([section isEqualToString:category]) [items addObject:flag];
    }
    [items sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [WAGRWAABTitleForFlag(a) caseInsensitiveCompare:WAGRWAABTitleForFlag(b)];
    }];
    _flags = items;
    return self;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.flags.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"bool: tap cycles System → ON → OFF. number/string: tap to enter typed override. unknown: observe-only until runtime confirms a getter.";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WAABFlag"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"WAABFlag"];
    NSDictionary *flag = self.flags[(NSUInteger)indexPath.row];
    NSString *key = flag[@"key"] ?: @"";
    NSString *type = flag[@"value_type"] ?: @"unknown";
    NSString *policy = flag[@"override_policy"] ?: @"";
    NSString *runtimeType = [NSUserDefaults.standardUserDefaults stringForKey:WAGRWAABPrefRuntimeType(key)] ?: @"not seen";
    NSString *runtimeValue = [NSUserDefaults.standardUserDefaults stringForKey:WAGRWAABPrefRuntimeValue(key)] ?: @"";
    cell.textLabel.text = [NSString stringWithFormat:@"[%@] %@", WAGRWAABCurrentState(key, type), WAGRWAABTitleForFlag(flag)];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · runtime=%@%@", type, policy, runtimeType, runtimeValue.length ? [NSString stringWithFormat:@"/%@", runtimeValue] : @""];
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType = [type isEqualToString:@"unknown"] ? UITableViewCellAccessoryDetailButton : UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *flag = self.flags[(NSUInteger)indexPath.row];
    NSString *key = flag[@"key"] ?: @"";
    NSString *type = flag[@"value_type"] ?: @"unknown";
    if (!key.length) return;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if ([type isEqualToString:@"bool"]) {
        NSInteger mode = [ud integerForKey:WAGRWAABPrefMode(key)];
        NSInteger next = (mode == 0) ? 2 : ((mode == 2) ? 1 : 0);
        [ud setInteger:next forKey:WAGRWAABPrefMode(key)];
        [ud synchronize];
        WAGRWAABEnsureHooksInstalled();
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        return;
    }
    if ([type isEqualToString:@"number"] || [type isEqualToString:@"string"]) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:WAGRWAABTitleForFlag(flag)
                                                                   message:[NSString stringWithFormat:@"%@ override. Leave empty to clear and use System.", type]
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = [type isEqualToString:@"number"] ? @"number" : @"string";
            tf.text = [type isEqualToString:@"number"] ? [[ud objectForKey:WAGRWAABPrefNumber(key)] description] : [ud stringForKey:WAGRWAABPrefString(key)];
            tf.keyboardType = [type isEqualToString:@"number"] ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDefault;
        }];
        [a addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *x) {
            [ud removeObjectForKey:WAGRWAABPrefMode(key)];
            [ud removeObjectForKey:[type isEqualToString:@"number"] ? WAGRWAABPrefNumber(key) : WAGRWAABPrefString(key)];
            [ud synchronize];
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *x) {
            NSString *text = a.textFields.firstObject.text ?: @"";
            if (!text.length) {
                [ud removeObjectForKey:WAGRWAABPrefMode(key)];
            } else if ([type isEqualToString:@"number"]) {
                [ud setInteger:1 forKey:WAGRWAABPrefMode(key)];
                [ud setDouble:text.doubleValue forKey:WAGRWAABPrefNumber(key)];
            } else {
                [ud setInteger:1 forKey:WAGRWAABPrefMode(key)];
                [ud setObject:text forKey:WAGRWAABPrefString(key)];
            }
            [ud synchronize];
            WAGRWAABEnsureHooksInstalled();
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    WAGRShowAlert(self, @"Observe first", @"This static candidate has unknown type. Enable ABProps Observer, use the app, and return after runtime confirms which getter is used.");
}
@end

@interface WAGramWAABCategoryListVC : UITableViewController
@property (nonatomic, strong) NSArray<NSString *> *categories;
@end

@implementation WAGramWAABCategoryListVC
- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAAB Overrides";
    _categories = WAGRWAABCategories();
    return self;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.categories.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    NSDictionary *root = WAGRWAABCatalogRoot();
    NSDictionary *summary = root[@"summary_by_category"];
    NSNumber *total = root[@"total"] ?: @0;
    return [NSString stringWithFormat:@"%@ catalog entries. Unknown items are observe-only. Hooks are installed only when Observer is ON or at least one override is active. Categories=%lu summaries=%lu", total, (unsigned long)self.categories.count, (unsigned long)([summary isKindOfClass:NSDictionary.class] ? summary.count : 0)];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WAABCat"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"WAABCat"];
    NSString *cat = self.categories[(NSUInteger)indexPath.row];
    NSDictionary *summary = WAGRWAABCatalogRoot()[@"summary_by_category"];
    NSDictionary *s = [summary isKindOfClass:NSDictionary.class] ? summary[cat] : nil;
    cell.textLabel.text = cat;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"total=%@ · bool=%@ · number=%@ · string=%@ · unknown=%@ · exe=%@",
                                 s[@"total"] ?: @"?",
                                 s[@"value_types"][@"bool"] ?: @0,
                                 s[@"value_types"][@"number"] ?: @0,
                                 s[@"value_types"][@"string"] ?: @0,
                                 s[@"value_types"][@"unknown"] ?: @0,
                                 s[@"main_executable_present"] ?: @0];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *cat = self.categories[(NSUInteger)indexPath.row];
    [self.navigationController pushViewController:[[WAGramWAABFlagListVC alloc] initWithCategory:cat] animated:YES];
}
@end

static UIViewController *WAGRBuildWAABOverridesVC(void) {
    return [[WAGramWAABCategoryListVC alloc] init];
}

#pragma mark - Feature Flags section

static UIViewController *WAGRBuildFeatureFlagsVC(void) {
    // These are read-only observation helpers; we re-use the ABProps observer log.
    NSArray<WAGramRow *> *obsRows = @[
        [WAGramRow switchWithTitle:@"ABProps Observer"
                          subtitle:@"Log WAABProperties typed getters. Does not force values by itself."
                               key:kWAGRABPropsObserver
                            action:^(BOOL on){ if (on) WAGRWAABEnsureHooksInstalled(); }],
        [WAGramRow navWithTitle:@"WAAB Overrides Catalog"
                       subtitle:@"6,772 selected static candidates: bool, number, string and observe-only unknown"
                         target:WAGRBuildWAABOverridesVC()],
        [WAGramRow buttonWithTitle:@"WAAB Diagnostics"
                          subtitle:@"Getter hook state and active override status"
                            action:^(BOOL __unused x){
            UIViewController *top = WAGRTopVC();
            WAGRShowAlert(top, @"WAAB Diagnostics", WAGRWAABDiagnosticText());
        }],
        [WAGramRow buttonWithTitle:@"View Observation Log"
                          subtitle:@"Last 200 selector calls captured"
                            action:^(BOOL __unused x){
            UIViewController *top = WAGRTopVC();
            WAGRShowAlert(top, @"ABProps Log", WAGRABObsLog());
        }],
        [WAGramRow buttonWithTitle:@"Clear Log"
                          subtitle:@"Erase ring buffer"
                            action:^(BOOL __unused x){ WAGRABObsClear(); }],
    ];

    // Known WA ABProp / MobileConfig identifiers (informational display)
    NSArray<WAGramRow *> *infoRows = @[
        [WAGramRow buttonWithTitle:@"WAABProperties classes"
                          subtitle:@"WAABProperties · abProperties · abPropertiesPreChatd · getMobileConfigInitPhase …"
                            action:^(BOOL __unused x){
            NSString *info =
                @"WAABProperties\n"
                @"abProperties\n"
                @"abPropertiesPreChatd\n"
                @"getMobileConfigInitPhase\n"
                @"getMobileConfigInitPhaseForShadowTesting\n"
                @"isMobileConfigRollout\n"
                @"mobileConfig\n"
                @"logComparisonWithContext:mobileConfig:\n"
                @"MetaConfigFetchMutation_xwaWaMetaConfigFetchResponse\n"
                @"WAXWAMetaConfigRequestInput\n"
                @"doesABPropExperimentKey:matchMCExperimentKey:\n"
                @"privateExperimentationLastSyncTimestamp\n"
                @"privateExperimentationSalt\n"
                @"waAnalyticsExperimentsEnableRecommendedConfigs\n"
                @"waAnalyticsExperimentsOverriddenRecommendedConfigs\n"
                @"FeatureFlag / experiment / mc_experiment_key / abprop_experiment_key";
            UIViewController *top = WAGRTopVC();
            WAGRShowAlert(top, @"WA Feature Flag Identifiers", info);
        }],
    ];

    return [[WAGramSubMenuVC alloc] initWithSections:@[
        [WAGramSectionDef sectionWithHeader:@"Observer"
                                     footer:@"Observer OFF by default. The catalog respects type: bool uses tri-state, number/string use typed overrides, unknown is observe-only until runtime confirms a getter."
                                       rows:obsRows],
        [WAGramSectionDef sectionWithHeader:@"Known Identifiers"
                                     footer:@"Tap to view the full list of known WA AB / MC experiment identifiers from SharedModules."
                                       rows:infoRows],
    ] title:@"Feature Flags"];
}

#pragma mark - Dogfood section

static UIViewController *WAGRBuildDogfoodVC(void) {
    NSArray<WAGramRow *> *rows = @[
        [WAGramRow switchWithTitle:@"Enable Employee / Dogfood Mode"
                          subtitle:@"Spoof: isMetaEmployeeOrInternalTester · is_meta_employee_or_internal_tester · isInternalUser → YES · graphQLEmployeeC1Disabled → NO"
                               key:kWAGREmployeeMaster
                            action:^(BOOL on){ if (on) WAGRDogfoodEnsureHooksInstalled(); }],
        [WAGramRow buttonWithTitle:@"Dogfood Diagnostics"
                          subtitle:@"Shows hook status and orig pointer availability"
                            action:^(BOOL __unused x){
            UIViewController *top = WAGRTopVC();
            WAGRShowAlert(top, @"Dogfood Diagnostics", WAGRDogfoodDiagnosticText());
        }],
    ];
    return [[WAGramSubMenuVC alloc] initWithSections:@[
        [WAGramSectionDef sectionWithHeader:@"Identity"
                                     footer:@"Gates validated against SharedModules binary. Hooks are installed at launch with deferred retries — no broad startup scan."
                                       rows:rows],
    ] title:@"Dogfood / Employee"];
}

#pragma mark - Debug section

static UIViewController *WAGRBuildDebugVC(void) {
    NSArray<WAGramRow *> *keychainRows = @[
        [WAGramRow switchWithTitle:@"Keychain Observer"
                          subtitle:@"Log SecItemAdd / Copy / Update / Delete metadata (no kSecValueData)"
                               key:kWAGRKeychain
                            action:nil],
        [WAGramRow buttonWithTitle:@"Keychain Diagnostics"
                          subtitle:@"bundleId · accessGroup · hook status"
                            action:^(BOOL __unused x){
            UIViewController *top = WAGRTopVC();
            WAGRShowAlert(top, @"Keychain Diagnostics", WAGRKeychainDiagnosticText());
        }],
    ];
    NSArray<WAGramRow *> *debugRows = @[
        [WAGramRow switchWithTitle:@"Debug Mode"
                          subtitle:@"Enable verbose NSLog output from all WAGram hooks"
                               key:kWAGRDebugMode
                            action:nil],
    ];

    return [[WAGramSubMenuVC alloc] initWithSections:@[
        [WAGramSectionDef sectionWithHeader:@"Keychain"
                                     footer:@"fishhook-based observer. SecItemDelete is never rewritten — observer only."
                                       rows:keychainRows],
        [WAGramSectionDef sectionWithHeader:@"Logging"
                                     footer:@"Verbose logging to Console.app / Xcode. Filter by [WAGram]."
                                       rows:debugRows],
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
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAGram";
    [self buildSections];
    return self;
}

- (void)buildSections {
    // Top section: master toggles
    NSArray<WAGramRow *> *masterRows = @[
        [WAGramRow switchWithTitle:@"LiquidGlass"
                          subtitle:@"Enable LiquidGlass design system (writes native UserDefaults override + method hooks)"
                               key:kWAGRLiquidGlassMaster
                            action:^(BOOL on){ WAGRLGPrefsDidChange(); }],
        [WAGramRow navWithTitle:@"LiquidGlass Flags"
                       subtitle:@"Individual ios_liquid_glass_* sub-flag toggles"
                         target:WAGRBuildLiquidGlassVC()],
        [WAGramRow navWithTitle:@"Feature Flags"
                       subtitle:@"ABProps / MobileConfig observer and identifiers"
                         target:WAGRBuildFeatureFlagsVC()],
        [WAGramRow navWithTitle:@"Dogfood / Employee"
                       subtitle:@"isMetaEmployee · isInternalUser · graphQLEmployeeC1Disabled"
                         target:WAGRBuildDogfoodVC()],
        [WAGramRow navWithTitle:@"Debug"
                       subtitle:@"Keychain observer, verbose logging"
                         target:WAGRBuildDebugVC()],
    ];

    _sections = @[
        [WAGramSectionDef sectionWithHeader:@"WAGram"
                                     footer:@"All toggles default OFF. Changes take effect immediately for UserDefaults-based overrides; method hooks require respring/restart."
                                       rows:masterRows],
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)_sections[(NSUInteger)s].rows.count;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].header;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return _sections[(NSUInteger)s].footer;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    NSString *rId = (row.style == WAGramRowStyleSwitch) ? @"SW" :
                    (row.style == WAGramRowStyleNavigation) ? @"NAV" : @"BTN";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:rId];
    if (!cell) {
        UITableViewCellStyle sty = row.subtitle.length ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
        cell = [[UITableViewCell alloc] initWithStyle:sty reuseIdentifier:rId];
    }
    cell.textLabel.text       = row.title;
    cell.detailTextLabel.text = row.subtitle;
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType  = UITableViewCellAccessoryNone;
    cell.accessoryView  = nil;

    if (row.style == WAGramRowStyleSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = row.prefsKey ? [[NSUserDefaults standardUserDefaults] boolForKey:row.prefsKey] : NO;
        sw.tag = (ip.section << 16) | ip.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (row.style == WAGramRowStyleNavigation) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.textLabel.textColor = self.view.tintColor;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSInteger sec = sw.tag >> 16;
    NSInteger row = sw.tag & 0xFFFF;
    WAGramRow *r = _sections[(NSUInteger)sec].rows[(NSUInteger)row];
    if (r.prefsKey) [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:r.prefsKey];
    if (r.action) r.action(sw.isOn);
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGramRow *row = _sections[(NSUInteger)ip.section].rows[(NSUInteger)ip.row];
    if (row.style == WAGramRowStyleNavigation && row.navTarget) {
        [self.navigationController pushViewController:row.navTarget animated:YES];
    } else if (row.style == WAGramRowStyleButton && row.action) {
        row.action(NO);
    }
}
@end
