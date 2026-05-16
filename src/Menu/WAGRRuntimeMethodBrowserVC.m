// WAGRRuntimeMethodBrowserVC.m
// Runtime browser for non-WAAB boolean methods.
// Discovery is on-demand when this VC opens.
// Override is exact: class + instance/class method + selector.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "WAGramMenuVC.h"

NSString *WAGRNativeBoolOverrideGet(NSString *className, BOOL meta, NSString *selectorName);
void WAGRNativeBoolOverrideSet(NSString *className, BOOL meta, NSString *selectorName, NSString *value);
NSUInteger WAGRNativeBoolOverrideInstallPersisted(void);

static char kWAGRRTItemKey;

@interface WAGRRuntimeMethodBrowserVC ()
@property (nonatomic, strong) NSArray<NSString *> *allItems;
@property (nonatomic, strong) NSArray<NSString *> *filtered;
@property (nonatomic, strong) NSArray<NSString *> *tokens;
@property (nonatomic, strong) UISearchController *search;
@end

@implementation WAGRRuntimeMethodBrowserVC

- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens {
    if (!(self=[super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = title ?: @"Runtime";
    _tokens = tokens ?: @[];
    _allItems = [[self class] runtimeMethodsMatchingTokens:_tokens];
    _filtered = _allItems;
    return self;
}

+ (BOOL)methodNameLooksFeatureLike:(NSString *)name {
    if (!name.length || [name containsString:@":"]) return NO;
    NSString *l = name.lowercaseString;
    if ([l hasPrefix:@"is"] || [l hasPrefix:@"has"] || [l hasPrefix:@"should"] || [l hasPrefix:@"can"] || [l hasPrefix:@"supports"]) return YES;
    return [l containsString:@"enabled"] || [l containsString:@"eligible"] || [l containsString:@"benefit"] || [l containsString:@"debug"] || [l containsString:@"internal"] || [l containsString:@"dogfood"] || [l containsString:@"employee"] || [l containsString:@"multiaccount"] || [l containsString:@"accountswitcher"] || [l containsString:@"killswitch"] || [l containsString:@"kill_switch"];
}

+ (NSArray<NSString *> *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSArray<NSString *> *effective = tokens.count ? tokens : @[@"aura", @"subscription", @"benefit", @"premium", @"liquid", @"theme", @"icon", @"ringtone", @"sticker", @"business", @"smb", @"ai", @"plus", @"debug", @"internal", @"dogfood", @"multiaccount", @"accountswitcher", @"waffle", @"paa"];

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) return @[];

    for (unsigned int ci=0; ci<count; ci++) {
        Class cls = classes[ci];
        NSString *cn = NSStringFromClass(cls);
        if (!cn.length || [cn containsString:@"WAABProperties"]) continue;

        for (int meta=0; meta<2; meta++) {
            Class target = meta ? object_getClass(cls) : cls;
            unsigned int mc = 0;
            Method *methods = class_copyMethodList(target, &mc);
            if (!methods) continue;

            for (unsigned int mi=0; mi<mc; mi++) {
                Method m = methods[mi];
                if (method_getNumberOfArguments(m) != 2) continue;
                char ret[8]={0}; method_getReturnType(m, ret, sizeof(ret));
                if (ret[0] != 'B' && ret[0] != 'c') continue;
                NSString *mn = NSStringFromSelector(method_getName(m));
                if (![self methodNameLooksFeatureLike:mn]) continue;
                NSString *hay = [[cn stringByAppendingFormat:@" %@", mn] lowercaseString];
                BOOL hit = NO;
                for (NSString *t in effective) if ([hay containsString:t.lowercaseString]) { hit = YES; break; }
                if (!hit) continue;
                [out addObject:[NSString stringWithFormat:@"%@ %@%@", cn, meta ? @"+" : @"-", mn]];
            }
            free(methods);
        }
    }
    free(classes);
    return [[NSSet setWithArray:out].allObjects sortedArrayUsingSelector:@selector(compare:)];
}

static BOOL WAGRRTParseItem(NSString *item, NSString **className, BOOL *meta, NSString **selectorName) {
    NSRange plus = [item rangeOfString:@" +" options:NSBackwardsSearch];
    NSRange minus = [item rangeOfString:@" -" options:NSBackwardsSearch];
    NSRange sep = plus.location != NSNotFound ? plus : minus;
    if (sep.location == NSNotFound) return NO;
    BOOL isMeta = plus.location != NSNotFound;
    NSString *cls = [item substringToIndex:sep.location];
    NSString *sel = [item substringFromIndex:sep.location + 2];
    if (!cls.length || !sel.length) return NO;
    if (className) *className = cls;
    if (meta) *meta = isMeta;
    if (selectorName) *selectorName = sel;
    return YES;
}

static NSInteger WAGRRTIndexForState(NSString *state) {
    if ([state isEqualToString:@"off"]) return 1;
    if ([state isEqualToString:@"on"]) return 2;
    return 0;
}

static NSString *WAGRRTStateForIndex(NSInteger index) {
    if (index == 1) return @"off";
    if (index == 2) return @"on";
    return nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemBackgroundColor;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 16, 0, 0);
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Buscar método/classe…";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.title = [NSString stringWithFormat:@"%@ (%lu)", self.title ?: @"Runtime", (unsigned long)self.allItems.count];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Reinstall" style:UIBarButtonItemStylePlain target:self action:@selector(reinstall)];
}

- (void)reinstall {
    NSUInteger n = WAGRNativeBoolOverrideInstallPersisted();
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Runtime" message:[NSString stringWithFormat:@"%lu persisted exact hooks reinstalled.", (unsigned long)n] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text ?: @"";
    self.filtered = q.length ? [self.allItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@", q]] : self.allItems;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.filtered.count; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 64; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"rt"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rt"];

    NSString *item = self.filtered[(NSUInteger)ip.row];
    NSString *className = nil;
    NSString *selectorName = nil;
    BOOL meta = NO;
    WAGRRTParseItem(item, &className, &meta, &selectorName);
    NSString *state = WAGRNativeBoolOverrideGet(className, meta, selectorName);

    cell.backgroundColor = UIColor.secondarySystemBackgroundColor;
    cell.textLabel.text = item;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.text = [state isEqualToString:@"on"] ? @"force ON" : ([state isEqualToString:@"off"] ? @"force OFF" : @"system");
    cell.detailTextLabel.textColor = [state isEqualToString:@"on"] ? UIColor.systemGreenColor : ([state isEqualToString:@"off"] ? UIColor.systemOrangeColor : UIColor.secondaryLabelColor);

    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"System", @"Off", @"On"]];
    seg.selectedSegmentIndex = WAGRRTIndexForState(state);
    seg.apportionsSegmentWidthsByContent = YES;
    objc_setAssociatedObject(seg, &kWAGRRTItemKey, item, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [seg addTarget:self action:@selector(segChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = seg;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)segChanged:(UISegmentedControl *)seg {
    NSString *item = objc_getAssociatedObject(seg, &kWAGRRTItemKey);
    NSString *className = nil;
    NSString *selectorName = nil;
    BOOL meta = NO;
    if (!WAGRRTParseItem(item, &className, &meta, &selectorName)) return;
    WAGRNativeBoolOverrideSet(className, meta, selectorName, WAGRRTStateForIndex(seg.selectedSegmentIndex));
    [self.tableView reloadData];
}

@end
