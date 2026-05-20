// WAGRSurfaceBrowserVC.m — compact runtime scanner. UISwitch only.
// Raw SYS/OFF/ON segmented control is intentionally removed from visual UI.
// Long feature/getter names use a custom cell with char wrapping instead of truncation.

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

@interface WAGRFeatureEntryCell : UITableViewCell
@property(nonatomic, strong) UIImageView *glyphView;
@property(nonatomic, strong) UILabel *featureLabel;
@property(nonatomic, strong) UILabel *metaLabel;
@property(nonatomic, strong) UISwitch *toggle;
- (void)configureWithEntry:(WAGREntry *)entry effective:(BOOL)effective hasOverride:(BOOL)hasOverride state:(NSString *)state;
@end

@implementation WAGRFeatureEntryCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (!(self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) return nil;

    self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;

    _glyphView = [[UIImageView alloc] initWithFrame:CGRectZero];
    _glyphView.translatesAutoresizingMaskIntoConstraints = NO;
    _glyphView.contentMode = UIViewContentModeScaleAspectFit;
    _glyphView.tintColor = UIColor.labelColor;
    [self.contentView addSubview:_glyphView];

    _toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
    _toggle.translatesAutoresizingMaskIntoConstraints = NO;
    _toggle.onTintColor = UIColor.systemBlueColor;
    [_toggle setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [_toggle setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.contentView addSubview:_toggle];

    _featureLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _featureLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _featureLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    _featureLabel.numberOfLines = 0;
    _featureLabel.lineBreakMode = NSLineBreakByCharWrapping;
    _featureLabel.adjustsFontForContentSizeCategory = YES;
    [_featureLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_featureLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.contentView addSubview:_featureLabel];

    _metaLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _metaLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _metaLabel.textColor = UIColor.secondaryLabelColor;
    _metaLabel.numberOfLines = 2;
    _metaLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_metaLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_metaLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.contentView addSubview:_metaLabel];

    UILayoutGuide *margins = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_glyphView.leadingAnchor constraintEqualToAnchor:margins.leadingAnchor],
        [_glyphView.topAnchor constraintEqualToAnchor:margins.topAnchor constant:4.0],
        [_glyphView.widthAnchor constraintEqualToConstant:18.0],
        [_glyphView.heightAnchor constraintEqualToConstant:18.0],

        [_toggle.trailingAnchor constraintEqualToAnchor:margins.trailingAnchor],
        [_toggle.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],

        [_featureLabel.leadingAnchor constraintEqualToAnchor:_glyphView.trailingAnchor constant:12.0],
        [_featureLabel.trailingAnchor constraintEqualToAnchor:_toggle.leadingAnchor constant:-12.0],
        [_featureLabel.topAnchor constraintEqualToAnchor:margins.topAnchor],

        [_metaLabel.leadingAnchor constraintEqualToAnchor:_featureLabel.leadingAnchor],
        [_metaLabel.trailingAnchor constraintEqualToAnchor:_featureLabel.trailingAnchor],
        [_metaLabel.topAnchor constraintEqualToAnchor:_featureLabel.bottomAnchor constant:3.0],
        [_metaLabel.bottomAnchor constraintEqualToAnchor:margins.bottomAnchor],
    ]];

    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [_toggle removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    objc_setAssociatedObject(_toggle, kEntryKey, nil, OBJC_ASSOCIATION_ASSIGN);
    _featureLabel.text = nil;
    _metaLabel.text = nil;
    _glyphView.image = nil;
}

- (void)configureWithEntry:(WAGREntry *)entry effective:(BOOL)effective hasOverride:(BOOL)hasOverride state:(NSString *)state {
    NSString *prefix = entry.isProperty ? @"@prop" : (entry.isClassMethod ? @"+" : @"-");
    NSString *name = entry.displayName.length ? entry.displayName : entry.selectorName;
    _featureLabel.text = [NSString stringWithFormat:@"%@ %@", prefix, name ?: @""];
    _featureLabel.textColor = hasOverride ? (effective ? UIColor.systemGreenColor : UIColor.systemRedColor) : UIColor.labelColor;

    _metaLabel.text = [NSString stringWithFormat:@"%@ · %@ · %@", entry.className ?: @"", entry.returnType ?: @"BOOL", state ?: @"sys"];

    NSString *iconName = entry.isProperty ? @"doc.plaintext" : @"switch.2";
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightRegular];
    UIImage *img = [UIImage systemImageNamed:iconName withConfiguration:cfg];
    _glyphView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _glyphView.tintColor = UIColor.labelColor;

    _toggle.on = effective;
}

@end

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
    self.tableView.estimatedRowHeight = 76.0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 56, 0, 0);
    [self.tableView registerClass:WAGRFeatureEntryCell.class forCellReuseIdentifier:@"entry"];

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
    WAGRFeatureEntryCell *cell = [tv dequeueReusableCellWithIdentifier:@"entry" forIndexPath:ip];

    WAGREntry *e = [self entryAtIndexPath:ip];
    if (!e) return cell;

    BOOL hasOverride = WAGRHasOverride(e.overrideKey);
    BOOL known = NO;
    BOOL observed = WAGRObservedValue(e.overrideKey, &known);
    BOOL effective = hasOverride ? WAGROverrideBool(e.overrideKey) : (known ? observed : NO);
    NSString *state = hasOverride ? (effective ? @"override 1" : @"override 0") : (known ? (observed ? @"sys 1" : @"sys 0") : @"sys");

    [cell configureWithEntry:e effective:effective hasOverride:hasOverride state:state];
    objc_setAssociatedObject(cell.toggle, kEntryKey, e, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [cell.toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
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
