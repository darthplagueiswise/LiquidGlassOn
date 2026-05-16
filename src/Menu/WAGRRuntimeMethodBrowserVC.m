// WAGRRuntimeMethodBrowserVC.m — read-only runtime catalog outside WAABProperties
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "WAGramMenuVC.h"

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
    if ([l containsString:@"enabled"] || [l containsString:@"eligible"] || [l containsString:@"benefit"] || [l containsString:@"killswitch"] || [l containsString:@"kill_switch"]) return YES;
    return NO;
}
+ (NSArray<NSString *> *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSArray<NSString *> *effective = tokens.count ? tokens : @[@"aura",@"subscription",@"benefit",@"premium",@"liquid",@"theme",@"icon",@"ringtone",@"sticker",@"business",@"smb",@"ai",@"plus",@"debug",@"internal",@"dogfood",@"multiaccount",@"accountswitcher"];
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
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = UIColor.systemBackgroundColor;
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Buscar método/classe…";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.title = [NSString stringWithFormat:@"%@ (%lu)", self.title ?: @"Runtime", (unsigned long)self.allItems.count];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text ?: @"";
    self.filtered = q.length ? [self.allItems filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[c] %@", q]] : self.allItems;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)self.filtered.count; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 58; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"rt"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"rt"];
    cell.backgroundColor = UIColor.secondarySystemBackgroundColor;
    cell.textLabel.text = self.filtered[(NSUInteger)ip.row];
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines = 2;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}
@end
