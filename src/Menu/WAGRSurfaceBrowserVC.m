// WAGRSurfaceBrowserVC.m — compact runtime scanner. UISwitch only.
// Raw SYS/OFF/ON segmented control is intentionally removed from visual UI.

#import "WAGRSurfaceBrowserVC.h"
#import "../WAGramPrefix.h"
#import "../Runtime/WAGRSurface.h"
#import <objc/runtime.h>

extern BOOL WAGRInstallHookForEntry(WAGREntry *e);

static const void *kEntryKey = &kEntryKey;

static UITableViewCell *WAGRCellForControl(UIControl *control) {
    UIView *v = control;
    while (v && ![v isKindOfClass:UITableViewCell.class]) v = v.superview;
    return (UITableViewCell *)v;
}

@interface WAGRSurfaceBrowserVC () <UISearchResultsUpdating>
@property(nonatomic, strong) WAGRSurfaceSpec *spec;
@property(nonatomic, strong) NSArray<WAGREntry *> *all;
@property(nonatomic, strong) NSArray<NSString *> *cats;
@property(nonatomic, strong) NSDictionary<NSString *, NSArray<WAGREntry *> *> *byCat;
@property(nonatomic, strong) UISearchController *search;
@property(nonatomic, assign) BOOL hasScanned;
@end

@implementation WAGRSurfaceBrowserVC

- (instancetype)initWithSpec:(WAGRSurfaceSpec *)spec {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    _spec = spec;
    _all = @[];
    _byCat = @{};
    _cats = @[];
    self.title = spec.title;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 50.0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 56, 0, 0);

    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar features";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;

    UIBarButtonItem *scan = [[UIBarButtonItem alloc] initWithTitle:@"Scan"
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(scan)];
    UIBarButtonItem *reset = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.counterclockwise"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(resetVisibleOverrides)];
    self.navigationItem.rightBarButtonItems = @[scan, reset];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_hasScanned) [self scan];
}

- (void)scan {
    _hasScanned = YES;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<WAGREntry *> *entries = [WAGRScanner scanSurface:self.spec];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.all = entries ?: @[];
            [self applyFilter:self.search.searchBar.text ?: @""];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    [self applyFilter:sc.searchBar.text ?: @""];
}

- (void)applyFilter:(NSString *)query {
    NSString *lo = query.lowercaseString ?: @"";
    NSArray<WAGREntry *> *base = lo.length ? [_all filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WAGREntry *e, NSDictionary *_) {
        NSString *hay = [NSString stringWithFormat:@"%@ %@ %@ %@", e.className ?: @"", e.displayName ?: @"", e.selectorName ?: @"", e.category ?: @""].lowercaseString;
        return [hay containsString:lo];
    }]] : _all;

    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    for (WAGREntry *e in base) {
        NSString *cat = e.category.length ? e.category : @"Other";
        if (!map[cat]) map[cat] = [NSMutableArray array];
        [(NSMutableArray *)map[cat] addObject:e];
    }
    _cats = [map.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    _byCat = map;
    self.title = [NSString stringWithFormat:@"%@ (%lu)", _spec.title ?: @"WAGram", (unsigned long)base.count];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return (NSInteger)_cats.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *rows = _byCat[_cats[(NSUInteger)section]];
    return (NSInteger)rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _cats[(NSUInteger)section];
}

- (WAGREntry *)entryAtIndexPath:(NSIndexPath *)ip {
    if (ip.section >= (NSInteger)_cats.count) return nil;
    NSArray *rows = _byCat[_cats[(NSUInteger)ip.section]];
    if (ip.row >= (NSInteger)rows.count) return nil;
    return rows[(NSUInteger)ip.row];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"entry"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"entry"];

    WAGREntry *e = [self entryAtIndexPath:ip];
    if (!e) return cell;
    cell.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    BOOL hasOverride = WAGRHasOverride(e.overrideKey);
    BOOL known = NO;
    BOOL observed = WAGRObservedValue(e.overrideKey, &known);
    BOOL effective = hasOverride ? WAGROverrideBool(e.overrideKey) : (known ? observed : NO);

    NSString *prefix = e.isProperty ? @"@prop" : (e.isClassMethod ? @"+" : @"-");
    NSString *name = e.displayName.length ? e.displayName : e.selectorName;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", prefix, name ?: @""];
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.textColor = hasOverride ? (effective ? UIColor.systemGreenColor : UIColor.systemRedColor) : UIColor.labelColor;

    NSString *state = hasOverride ? (effective ? @"override 1" : @"override 0") : (known ? (observed ? @"sys 1" : @"sys 0") : @"sys");
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · %@", e.className ?: @"", e.returnType ?: @"BOOL", state];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 1;

    UIImage *img = [UIImage systemImageNamed:e.isProperty ? @"doc.plaintext" : @"switch.2"
                           withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular]];
    cell.imageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = UIColor.labelColor;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = effective;
    sw.onTintColor = UIColor.systemBlueColor;
    objc_setAssociatedObject(sw, kEntryKey, e, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    WAGREntry *e = objc_getAssociatedObject(sw, kEntryKey);
    if (!e) return;

    if (sw.isOn) {
        WAGRSetOverride(e.overrideKey, YES);
        WAGRInstallHookForEntry(e);
    } else {
        // Visual switch OFF means "back to system" by default.
        // Force FALSE remains available from row actions.
        WAGRClearOverride(e.overrideKey);
    }

    UITableViewCell *cell = WAGRCellForControl(sw);
    NSIndexPath *ip = cell ? [self.tableView indexPathForCell:cell] : nil;
    if (ip) [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGREntry *e = [self entryAtIndexPath:ip];
    if (!e) return;

    UIAlertController *a = [UIAlertController alertControllerWithTitle:e.displayName ?: e.selectorName
                                                               message:e.className
                                                        preferredStyle:UIAlertControllerStyleActionSheet];

    [a addAction:[UIAlertAction actionWithTitle:@"Force TRUE"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused id _) {
        WAGRSetOverride(e.overrideKey, YES);
        WAGRInstallHookForEntry(e);
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Force FALSE"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused id _) {
        WAGRSetOverride(e.overrideKey, NO);
        WAGRInstallHookForEntry(e);
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear / SYS"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused id _) {
        WAGRClearOverride(e.overrideKey);
        [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Install hook now"
                                          style:UIAlertActionStyleDefault
                                        handler:^(__unused id _) {
        BOOL ok = WAGRInstallHookForEntry(e);
        UIAlertController *r = [UIAlertController alertControllerWithTitle:ok ? @"OK" : @"Failed"
                                                                   message:ok ? @"Hook installed." : @"Could not install hook."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [r addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:r animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)resetVisibleOverrides {
    NSUInteger n = 0;
    for (NSString *cat in _cats) {
        for (WAGREntry *e in _byCat[cat]) {
            if (WAGRHasOverride(e.overrideKey)) {
                WAGRClearOverride(e.overrideKey);
                n++;
            }
        }
    }
    [self.tableView reloadData];

    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset"
                                                               message:[NSString stringWithFormat:@"%lu overrides cleared.", (unsigned long)n]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
