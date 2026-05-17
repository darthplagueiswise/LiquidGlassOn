// WAGRRuntimeBrowserVC.m
// On-demand runtime bool method scanner — same override storage as WAGram menus.
// Scans only when opened, never at startup. No MSHookMessageEx in this file.
// All overrides use wagr.waab.<flag> = "on"/"off" in NSUserDefaults.

#import "WAGRRuntimeBrowserVC.h"
#import <objc/runtime.h>
#import "../WAGramPrefix.h"

static UIColor *BRAccent(void)    { return UIColor.systemBlueColor; }
static UIColor *BRBG(void)        { return UIColor.systemGroupedBackgroundColor; }
static UIColor *BRCellBG(void)    { return UIColor.secondarySystemGroupedBackgroundColor; }
static UIColor *BRGreen(void)     { return UIColor.systemGreenColor; }
static UIColor *BROrange(void)    { return UIColor.systemOrangeColor; }
static UIColor *BRSecondary(void) { return UIColor.secondaryLabelColor; }

// ── Scanned method entry ───────────────────────────────────────────────────────
@interface WAGRMethodEntry : NSObject
@property NSString *name;
@property NSString *className;
@property BOOL isClassMethod;
@property NSString *overrideState; // "on", "off", or nil (system)
@end
@implementation WAGRMethodEntry
@end

static const char kSwAssocKey = 0;

@interface WAGRRuntimeBrowserVC () <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<WAGRMethodEntry *> *allEntries;
@property (nonatomic, strong) NSArray<WAGRMethodEntry *> *filtered;
@property (nonatomic, strong) UISearchController *search;
@property (nonatomic, assign) BOOL hasScanned;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation WAGRRuntimeBrowserVC

- (instancetype)initWithStyle:(UITableViewStyle)style {
    if (!(self = [super initWithStyle:style])) return nil;
    _targetClassNames = @[@"WAABProperties"];
    _browserTitle     = @"Runtime Browser";
    _autoScanOnAppear = NO;
    _allEntries       = @[];
    _filtered         = @[];
    return self;
}

+ (instancetype)browserForWAABProperties {
    WAGRRuntimeBrowserVC *vc = [[self alloc] initWithStyle:UITableViewStylePlain];
    vc.targetClassNames = @[@"WAABProperties", @"FOAWAABPropertiesImpl"];
    vc.browserTitle     = @"WAABProperties";
    vc.autoScanOnAppear = YES;
    return vc;
}
+ (instancetype)browserForAuraGating {
    WAGRRuntimeBrowserVC *vc = [[self alloc] initWithStyle:UITableViewStylePlain];
    vc.targetClassNames = @[@"WAAuraGating",@"WAAuraPreferences",@"WAAuraSubscriptionManager",@"WAAuraAppThemesGating",@"WAAuraAppIconsGating",@"WAAuraRingtonesGating",@"WAAuraPinnedChatsGating",@"WAAuraEnhancedListsGating",@"WAAuraStickersGating"];
    vc.browserTitle     = @"Aura Gating";
    vc.autoScanOnAppear = YES;
    return vc;
}
+ (instancetype)browserForContextGates {
    WAGRRuntimeBrowserVC *vc = [[self alloc] initWithStyle:UITableViewStylePlain];
    vc.targetClassNames = @[@"WAContext",@"WASettingsViewController",@"WADebugMenuMain",@"WADebugViewController",@"WAUserContext",@"WAAccountInfo"];
    vc.browserTitle     = @"Context / Debug Gates";
    vc.autoScanOnAppear = YES;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = _browserTitle;
    self.tableView.backgroundColor = BRBG();
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 56;

    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar método…";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    UIBarButtonItem *scan = [[UIBarButtonItem alloc]
        initWithTitle:@"Scan" style:UIBarButtonItemStylePlain
               target:self action:@selector(startScan)];
    UIBarButtonItem *clearAll = [[UIBarButtonItem alloc]
        initWithTitle:@"Clear All" style:UIBarButtonItemStylePlain
               target:self action:@selector(clearAllOverrides)];
    clearAll.tintColor = UIColor.systemRedColor;
    self.navigationItem.rightBarButtonItems = @[scan, clearAll];

    // Status label
    _statusLabel = [[UILabel alloc] init];
    _statusLabel.font = [UIFont systemFontOfSize:12];
    _statusLabel.textColor = BRSecondary();
    _statusLabel.text = @"Tap Scan to discover methods at runtime";
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.numberOfLines = 0;
    _statusLabel.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 48);
    self.tableView.tableHeaderView = _statusLabel;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_autoScanOnAppear && !_hasScanned) [self startScan];
}

- (void)startScan {
    _hasScanned = YES;
    _statusLabel.text = @"Scanning…";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray *entries = [NSMutableArray array];
        for (NSString *clsName in self.targetClassNames) {
            Class cls = NSClassFromString(clsName);
            if (!cls) continue;
            for (int meta = 0; meta <= 1; meta++) {
                Class target = meta ? object_getClass(cls) : cls;
                unsigned int n = 0;
                Method *ms = class_copyMethodList(target, &n);
                if (!ms) continue;
                for (unsigned int i = 0; i < n; i++) {
                    if (method_getNumberOfArguments(ms[i]) != 2) continue;
                    char ret[8]={0}; method_getReturnType(ms[i],ret,8);
                    if (ret[0]!='B' && ret[0]!='c') continue;
                    NSString *sel = NSStringFromSelector(method_getName(ms[i]));
                    if ([sel containsString:@":"]) continue;
                    WAGRMethodEntry *e = [WAGRMethodEntry new];
                    e.name = sel;
                    e.className = clsName;
                    e.isClassMethod = (BOOL)meta;
                    e.overrideState = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(sel)];
                    [entries addObject:e];
                }
                free(ms);
            }
        }
        // Sort: overridden first, then alpha
        [entries sortUsingComparator:^NSComparisonResult(WAGRMethodEntry *a, WAGRMethodEntry *b) {
            if (a.overrideState && !b.overrideState) return NSOrderedAscending;
            if (!a.overrideState && b.overrideState) return NSOrderedDescending;
            return [a.name compare:b.name];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allEntries = entries;
            [self applyFilter:self.search.searchBar.text];
            NSUInteger on = 0;
            for (WAGRMethodEntry *e in entries) if ([e.overrideState isEqualToString:@"on"]) on++;
            self.statusLabel.text = [NSString stringWithFormat:@"%lu métodos (%lu overrides ativos)", (unsigned long)entries.count, (unsigned long)on];
        });
    });
}

- (void)clearAllOverrides {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Limpar overrides?" message:@"Remove todas as sobreposições neste browser. Não afeta outros menus." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Limpar" style:UIAlertActionStyleDestructive handler:^(id _){
        NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
        for (WAGRMethodEntry *e in self.allEntries) {
            [ud removeObjectForKey:WAGRKey(e.name)];
            e.overrideState = nil;
        }
        [ud synchronize];
        [self.tableView reloadData];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    [self applyFilter:sc.searchBar.text];
}
- (void)applyFilter:(NSString *)q {
    _filtered = q.length
        ? [_allEntries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name contains[c] %@", q]]
        : _allEntries;
    [self.tableView reloadData];
    NSUInteger on = 0;
    for (WAGRMethodEntry *e in _filtered) if ([e.overrideState isEqualToString:@"on"]) on++;
    self.title = [NSString stringWithFormat:@"%@ (%lu ✓)", _browserTitle, (unsigned long)on];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return (NSInteger)_filtered.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"br"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"br"];
    WAGRMethodEntry *e = _filtered[(NSUInteger)ip.row];
    c.backgroundColor = BRCellBG();
    c.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *prefix = e.isClassMethod ? @"+" : @"-";
    c.textLabel.text = [NSString stringWithFormat:@"%@[%@ %@]", prefix, e.className, e.name];
    c.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    c.textLabel.numberOfLines = 2;
    c.textLabel.textColor = [e.overrideState isEqualToString:@"on"] ? BRGreen() :
                            [e.overrideState isEqualToString:@"off"] ? BROrange() :
                            UIColor.labelColor;

    c.detailTextLabel.text = e.overrideState ? [NSString stringWithFormat:@"override = %@", e.overrideState] : @"system";
    c.detailTextLabel.textColor = BRSecondary();

    // 3-state segmented control: System / OFF / ON
    UISegmentedControl *seg = (UISegmentedControl *)objc_getAssociatedObject(c, &kSwAssocKey);
    if (!seg) {
        seg = [[UISegmentedControl alloc] initWithItems:@[@"Sys", @"OFF", @"ON"]];
        seg.apportionsSegmentWidthsByContent = YES;
        [seg addTarget:self action:@selector(segChanged:) forControlEvents:UIControlEventValueChanged];
        objc_setAssociatedObject(c, &kSwAssocKey, seg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        c.accessoryView = seg;
    }
    seg.tag = ip.row;
    seg.selectedSegmentIndex = [e.overrideState isEqualToString:@"on"]  ? 2 :
                               [e.overrideState isEqualToString:@"off"] ? 1 : 0;
    return c;
}

- (void)segChanged:(UISegmentedControl *)seg {
    WAGRMethodEntry *e = _filtered[(NSUInteger)seg.tag];
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (seg.selectedSegmentIndex == 2) {
        e.overrideState = @"on";
        [ud setObject:@"on" forKey:WAGRKey(e.name)];
    } else if (seg.selectedSegmentIndex == 1) {
        e.overrideState = @"off";
        [ud setObject:@"off" forKey:WAGRKey(e.name)];
    } else {
        e.overrideState = nil;
        [ud removeObjectForKey:WAGRKey(e.name)];
    }
    [ud synchronize];
    NSIndexPath *ip = [NSIndexPath indexPathForRow:seg.tag inSection:0];
    [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    NSUInteger on = 0;
    for (WAGRMethodEntry *entry in _filtered) if ([entry.overrideState isEqualToString:@"on"]) on++;
    self.title = [NSString stringWithFormat:@"%@ (%lu ✓)", _browserTitle, (unsigned long)on];
}
@end
