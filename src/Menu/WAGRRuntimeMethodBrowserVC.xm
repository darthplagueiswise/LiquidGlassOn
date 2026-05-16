// WAGRRuntimeMethodBrowserVC.xm
// On-demand runtime BOOL getter browser for non-WAAB/native framework surfaces.
// Storage intentionally mirrors the working WAGram override model:
//   wagr.runtime.bool.<Class>|<i|c>|<selector> = @"on" | @"off" | absent
//   wagr.runtime.bool.registry = @[entry, ...]
// No broad startup scan. Startup only re-installs exact persisted entries.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "WAGramMenuVC.h"
#import "../WAGramPrefix.h"

static NSString * const kWAGRRuntimeRegistryKey = @"wagr.runtime.bool.registry";
static NSMutableDictionary<NSString *, NSValue *> *gWAGRRuntimeOrig = nil;
static NSMutableSet<NSString *> *gWAGRRuntimeInstalled = nil;
static NSUInteger gWAGRRuntimeInstalledCount = 0;

static void WAGRRuntimeEnsureStore(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gWAGRRuntimeOrig = [NSMutableDictionary dictionary];
        gWAGRRuntimeInstalled = [NSMutableSet set];
    });
}

static NSString *WAGRRuntimeEntry(NSString *cls, BOOL isClassMethod, NSString *sel) {
    return [NSString stringWithFormat:@"%@|%@|%@", cls ?: @"", isClassMethod ? @"c" : @"i", sel ?: @""];
}
static NSArray<NSString *> *WAGRRuntimeParts(NSString *entry) {
    return [entry componentsSeparatedByString:@"|"];
}
static NSString *WAGRRuntimePrefKey(NSString *entry) {
    return [@"wagr.runtime.bool." stringByAppendingString:entry ?: @""];
}
static NSString *WAGRRuntimeState(NSString *entry) {
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRRuntimePrefKey(entry)];
    if ([v isEqualToString:@"on"] || [v isEqualToString:@"off"]) return v;
    return nil;
}
static void WAGRRuntimeSetState(NSString *entry, NSString *state) {
    if (!entry.length) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableArray *reg = [[ud arrayForKey:kWAGRRuntimeRegistryKey] mutableCopy] ?: [NSMutableArray array];
    if (state.length) {
        [ud setObject:state forKey:WAGRRuntimePrefKey(entry)];
        if (![reg containsObject:entry]) [reg addObject:entry];
    } else {
        [ud removeObjectForKey:WAGRRuntimePrefKey(entry)];
        [reg removeObject:entry];
    }
    [ud setObject:reg forKey:kWAGRRuntimeRegistryKey];
    [ud synchronize];
}

static BOOL WAGRRuntimeBoolMethodLooksSafe(Method m) {
    if (!m) return NO;
    if (method_getNumberOfArguments(m) != 2) return NO;
    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    return ret[0] == 'B' || ret[0] == 'c';
}

static BOOL WAGRRuntimeClassNameAllowed(NSString *name) {
    if (!name.length) return NO;
    static NSArray<NSString *> *deny;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ deny = @[@"NS", @"UI", @"CA", @"CF", @"WK", @"Web", @"AV", @"CN", @"CL", @"PK", @"MT", @"SwiftUI"]; });
    for (NSString *p in deny) if ([name hasPrefix:p]) return NO;
    return YES;
}

static BOOL WAGRRuntimeMatchesTokens(NSString *clsName, NSString *selName, NSArray<NSString *> *tokens) {
    if (!tokens.count) return YES;
    NSString *hay = [[NSString stringWithFormat:@"%@ %@", clsName ?: @"", selName ?: @""] lowercaseString];
    for (NSString *t in tokens) if ([hay containsString:[t lowercaseString]]) return YES;
    return NO;
}

static void WAGRRuntimeInstallEntry(NSString *entry) {
    WAGRRuntimeEnsureStore();
    if (!entry.length || [gWAGRRuntimeInstalled containsObject:entry]) return;
    NSArray<NSString *> *p = WAGRRuntimeParts(entry);
    if (p.count != 3) return;
    NSString *clsName = p[0];
    BOOL isClassMethod = [p[1] isEqualToString:@"c"];
    SEL sel = NSSelectorFromString(p[2]);
    Class cls = NSClassFromString(clsName);
    if (!cls || !sel) return;
    Class target = isClassMethod ? object_getClass(cls) : cls;
    Method m = isClassMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!WAGRRuntimeBoolMethodLooksSafe(m)) return;

    __block BOOL (*orig)(id, SEL) = NULL;
    NSString *captured = [entry copy];
    IMP hook = imp_implementationWithBlock(^BOOL(id obj) {
        NSString *state = WAGRRuntimeState(captured);
        if ([state isEqualToString:@"on"]) return YES;
        if ([state isEqualToString:@"off"]) return NO;
        return orig ? orig(obj, sel) : NO;
    });
    MSHookMessageEx(target, sel, hook, (IMP *)&orig);
    if (orig) {
        gWAGRRuntimeOrig[entry] = [NSValue valueWithPointer:(void *)orig];
        [gWAGRRuntimeInstalled addObject:entry];
        gWAGRRuntimeInstalledCount++;
    }
}

extern "C" void WAGRRuntimeRestorePersistedOverrides(void) {
    @autoreleasepool {
        NSArray<NSString *> *reg = [[NSUserDefaults standardUserDefaults] arrayForKey:kWAGRRuntimeRegistryKey];
        for (NSString *entry in reg) WAGRRuntimeInstallEntry(entry);
    }
}

extern "C" NSString *WAGRRuntimeBoolDiagnosticText(void) {
    NSArray<NSString *> *reg = [[NSUserDefaults standardUserDefaults] arrayForKey:kWAGRRuntimeRegistryKey] ?: @[];
    return [NSString stringWithFormat:@"runtime exact hooks=%lu\npersisted runtime overrides=%lu\nstartup scan=NO\nmode=on-demand scan + exact persisted registry", (unsigned long)gWAGRRuntimeInstalledCount, (unsigned long)reg.count];
}

@interface WAGRRuntimeBoolItem : NSObject
@property(nonatomic,copy) NSString *entry;
@property(nonatomic,copy) NSString *className;
@property(nonatomic,copy) NSString *selectorName;
@property(nonatomic,assign) BOOL classMethod;
@end
@implementation WAGRRuntimeBoolItem @end

@interface WAGRRuntimeMethodBrowserVC () <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<NSString *> *tokens;
@property(nonatomic,strong) NSMutableArray<WAGRRuntimeBoolItem *> *items;
@property(nonatomic,strong) NSArray<WAGRRuntimeBoolItem *> *filtered;
@property(nonatomic,strong) UISearchController *search;
@end

@implementation WAGRRuntimeMethodBrowserVC
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens {
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = title ?: @"Runtime BOOL";
    _tokens = tokens ?: @[];
    _items = [NSMutableArray array];
    _filtered = @[];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 58;
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"classe ou selector…";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Scan" style:UIBarButtonItemStylePlain target:self action:@selector(scanNow)];
    [self scanNow];
}
- (void)scanNow {
    NSMutableDictionary<NSString *, WAGRRuntimeBoolItem *> *seen = [NSMutableDictionary dictionary];
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        NSString *clsName = NSStringFromClass(cls);
        if (!WAGRRuntimeClassNameAllowed(clsName)) continue;
        for (int pass = 0; pass < 2; pass++) {
            BOOL classMethod = pass == 1;
            Class target = classMethod ? object_getClass(cls) : cls;
            unsigned int mc = 0;
            Method *methods = class_copyMethodList(target, &mc);
            for (unsigned int j = 0; j < mc; j++) {
                Method m = methods[j];
                if (!WAGRRuntimeBoolMethodLooksSafe(m)) continue;
                NSString *selName = NSStringFromSelector(method_getName(m));
                if ([selName containsString:@":"]) continue;
                if (!WAGRRuntimeMatchesTokens(clsName, selName, self.tokens)) continue;
                NSString *entry = WAGRRuntimeEntry(clsName, classMethod, selName);
                if (seen[entry]) continue;
                WAGRRuntimeBoolItem *it = [WAGRRuntimeBoolItem new];
                it.entry = entry; it.className = clsName; it.selectorName = selName; it.classMethod = classMethod;
                seen[entry] = it;
            }
            free(methods);
        }
    }
    free(classes);
    self.items = [[[seen allValues] sortedArrayUsingComparator:^NSComparisonResult(WAGRRuntimeBoolItem *a, WAGRRuntimeBoolItem *b) {
        return [a.entry compare:b.entry];
    }] mutableCopy];
    [self updateSearchResultsForSearchController:self.search];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = [sc.searchBar.text lowercaseString] ?: @"";
    self.filtered = q.length ? [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WAGRRuntimeBoolItem *it, NSDictionary *_) {
        return [[it.entry lowercaseString] containsString:q];
    }]] : self.items;
    self.title = [NSString stringWithFormat:@"Runtime BOOL (%lu)", (unsigned long)self.filtered.count];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.filtered.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"rt"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rt"];
    WAGRRuntimeBoolItem *it = self.filtered[(NSUInteger)ip.row];
    NSString *state = WAGRRuntimeState(it.entry);
    c.textLabel.text = [NSString stringWithFormat:@"%@%@", it.classMethod ? @"+" : @"-", it.selectorName];
    c.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    c.detailTextLabel.text = [NSString stringWithFormat:@"%@  •  %@", it.className, state ?: @"system"];
    c.detailTextLabel.font = [UIFont systemFontOfSize:11];
    c.detailTextLabel.numberOfLines = 2;
    if ([state isEqualToString:@"on"]) c.accessoryType = UITableViewCellAccessoryCheckmark;
    else c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGRRuntimeBoolItem *it = self.filtered[(NSUInteger)ip.row];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:it.selectorName message:it.className preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Force ON" style:UIAlertActionStyleDefault handler:^(__unused id _) { WAGRRuntimeSetState(it.entry, @"on"); WAGRRuntimeInstallEntry(it.entry); [self.tableView reloadData]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Force OFF" style:UIAlertActionStyleDefault handler:^(__unused id _) { WAGRRuntimeSetState(it.entry, @"off"); WAGRRuntimeInstallEntry(it.entry); [self.tableView reloadData]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"System / remover override" style:UIAlertActionStyleDestructive handler:^(__unused id _) { WAGRRuntimeSetState(it.entry, nil); [self.tableView reloadData]; }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}
@end

__attribute__((constructor))
static void WAGRRuntimeBoolInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRRuntimeRestorePersistedOverrides(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRRuntimeRestorePersistedOverrides(); });
}
