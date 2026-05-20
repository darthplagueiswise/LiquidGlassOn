// WAGRSurfaceListVC.m — RyukGram-style WAGram root menu.
// Long-press activation is kept in Tweak.x. This file only changes the UI hierarchy:
// feature bundles first, raw runtime browser only under Avançado.

#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <stdlib.h>
#import "WAGRSurfaceListVC.h"
#import "WAGRSurfaceBrowserVC.h"
#import "../WAGramPrefix.h"
#import "../WAUtils.h"
#import "../Runtime/WAGRSurface.h"

void WAGRWAABEnsureHooksInstalled(void) { WAGRReinstallPersistedHooks(); }

static UIColor *WAGRBG(void)     { return UIColor.systemGroupedBackgroundColor; }
static UIColor *WAGRCell(void)   { return UIColor.secondarySystemGroupedBackgroundColor; }
static UIColor *WAGRText(void)   { return UIColor.labelColor; }
static UIColor *WAGRSub(void)    { return UIColor.secondaryLabelColor; }
static UIColor *WAGRBlue(void)   { return UIColor.systemBlueColor; }
static UIColor *WAGRRed(void)    { return UIColor.systemRedColor; }

static UIViewController *WAGRTopController(void) {
    UIViewController *c = nil;
    for (UIScene *sc in UIApplication.sharedApplication.connectedScenes) {
        if (![sc isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)sc).windows) {
            if (w.isKeyWindow) { c = w.rootViewController; break; }
        }
        if (c) break;
    }
    UIViewController *p = nil;
    while (c && c != p) {
        p = c;
        if (c.presentedViewController) { c = c.presentedViewController; continue; }
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

static void WAGRAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title ?: @"WAGram"
                                                                   message:message ?: @""
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault handler:^(__unused id _) {
            UIPasteboard.generalPasteboard.string = message ?: @"";
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [WAGRTopController() presentViewController:a animated:YES completion:nil];
    });
}

static NSUInteger WAGROverrideCountForSurfaceID(NSString *sid) {
    if (!sid.length) return 0;
    NSString *prefix = [NSString stringWithFormat:@"wagr.override|%@|", sid];
    NSString *legacy = [NSString stringWithFormat:@"wagr.override.%@.", sid];
    NSUInteger n = 0;
    for (NSString *k in NSUserDefaults.standardUserDefaults.dictionaryRepresentation.allKeys)
        if ([k hasPrefix:prefix] || [k hasPrefix:legacy]) n++;
    return n;
}

@interface WAGRRawSurfaceListVC : UITableViewController
@property(nonatomic, strong) NSArray<WAGRSurfaceSpec *> *surfaces;
@end

@implementation WAGRRawSurfaceListVC
- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Runtime Avançado";
    _surfaces = [WAGRSurfaceSpec allSurfaces];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithRed:.07 green:.07 blue:.08 alpha:1];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)_surfaces.count; }
- (void)tableView:(UITableView *)tv willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *h = (UITableViewHeaderFooterView *)view;
        h.textLabel.font = [UIFont boldSystemFontOfSize:11];
        h.textLabel.textColor = [UIColor colorWithWhite:.5 alpha:1];
    }
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section { return @"Surfaces técnicas"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    return @"Browser bruto para debug. A UI principal usa bundles compactos.";
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGRSurfaceSpec *s = _surfaces[(NSUInteger)ip.row];
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = [UIColor colorWithRed:.13 green:.13 blue:.14 alpha:1];
    c.textLabel.text = s.title;
    c.textLabel.textColor = WAGRText();
    c.detailTextLabel.text = s.subtitle ?: @"";
    c.detailTextLabel.textColor = WAGRSub();
    c.imageView.image = [[UIImage systemImageNamed:s.icon ?: @"circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WAGRText();
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGRSurfaceBrowserVC *vc = [[WAGRSurfaceBrowserVC alloc] initWithSpec:_surfaces[(NSUInteger)ip.row]];
    [self.navigationController pushViewController:vc animated:YES];
}
@end

typedef NS_ENUM(NSInteger, WAGRRootSection) {
    WAGRRootSectionAbout = 0,
    WAGRRootSectionBundles,
    WAGRRootSectionAdvanced,
    WAGRRootSectionSystem,
};

typedef NS_ENUM(NSInteger, WAGRAdvancedRow) {
    WAGRAdvancedRowRawRuntime = 0,
    WAGRAdvancedRowInstallPersisted,
    WAGRAdvancedRowDiagnostics,
};

typedef NS_ENUM(NSInteger, WAGRSystemRow) {
    WAGRSystemRowRestart = 0,
    WAGRSystemRowResetOverrides,
    WAGRSystemRowResetWAGramPrefs,
};

@interface WAGRSurfaceListVC () <UISearchResultsUpdating>
@property(nonatomic, strong) NSArray<WAGRSurfaceSpec *> *bundles;
@property(nonatomic, strong) NSArray<WAGRSurfaceSpec *> *filteredBundles;
@property(nonatomic, strong) UISearchController *search;
@end

@implementation WAGRSurfaceListVC

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WAGram";
    _bundles = [WAGRSurfaceSpec featureBundles];
    _filteredBundles = _bundles;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithRed:.07 green:.07 blue:.08 alpha:1];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(done)];

    _search = [[UISearchController alloc] initWithSearchResultsController:nil];
    _search.searchResultsUpdater = self;
    _search.obscuresBackgroundDuringPresentation = NO;
    _search.searchBar.placeholder = @"Buscar configurações";
    self.navigationItem.searchController = _search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
}

- (void)done { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *q = sc.searchBar.text.lowercaseString ?: @"";
    if (!q.length) {
        _filteredBundles = _bundles;
    } else {
        _filteredBundles = [_bundles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(WAGRSurfaceSpec *s, NSDictionary *_) {
            NSString *hay = [NSString stringWithFormat:@"%@ %@", s.title ?: @"", s.subtitle ?: @""].lowercaseString;
            return [hay containsString:q];
        }]];
    }
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    switch ((WAGRRootSection)section) {
        case WAGRRootSectionAbout: return 1;
        case WAGRRootSectionBundles: return (NSInteger)_filteredBundles.count;
        case WAGRRootSectionAdvanced: return 3;
        case WAGRRootSectionSystem: return 3;
    }
    return 0;
}

- (void)tableView:(UITableView *)tv willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *h = (UITableViewHeaderFooterView *)view;
        h.textLabel.font = [UIFont boldSystemFontOfSize:11];
        h.textLabel.textColor = [UIColor colorWithWhite:.5 alpha:1];
    }
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    switch ((WAGRRootSection)section) {
        case WAGRRootSectionAbout: return nil;
        case WAGRRootSectionBundles: return @"Categorias";
        case WAGRRootSectionAdvanced: return @"Avançado";
        case WAGRRootSectionSystem: return @"Sistema";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == WAGRRootSectionBundles)
        return @"Os bundles usam scan direcionado por tokens/classes e exibem apenas features compactas.";
    if (section == WAGRRootSectionAdvanced)
        return @"Runtime bruto fica aqui, separado do menu normal.";
    return nil;
}

- (UITableViewCell *)aboutCell {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = [UIColor colorWithRed:.13 green:.13 blue:.14 alpha:1];
    c.textLabel.text = @"WAGram";
    c.textLabel.textColor = WAGRText();
    c.detailTextLabel.text = @"Runtime router · MSHookMessageEx · UI compacta";
    c.detailTextLabel.textColor = WAGRSub();
    c.imageView.image = [[UIImage systemImageNamed:@"bolt.horizontal.circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WAGRText();
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

- (UITableViewCell *)bundleCellForRow:(NSInteger)row {
    WAGRSurfaceSpec *s = _filteredBundles[(NSUInteger)row];
    NSUInteger count = WAGROverrideCountForSurfaceID(s.surfaceID);
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = [UIColor colorWithRed:.13 green:.13 blue:.14 alpha:1];
    c.textLabel.text = s.title;
    c.textLabel.textColor = WAGRText();
    c.detailTextLabel.text = count ? [NSString stringWithFormat:@"%lu overrides", (unsigned long)count] : (s.subtitle ?: @"");
    c.detailTextLabel.textColor = WAGRSub();
    c.imageView.image = [[UIImage systemImageNamed:s.icon ?: @"circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WAGRText();
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

- (UITableViewCell *)advancedCellForRow:(NSInteger)row {
    NSString *titles[] = { @"Runtime Browser Avançado", @"Instalar hooks salvos", @"Diagnóstico" };
    NSString *subs[] = { @"WAABProperties, WAContextMain, WAAuraGating etc.", @"Reinstala overrides persistidos", @"Router, LiquidGlass, Dogfood, Keychain" };
    NSString *icons[] = { @"terminal", @"arrow.triangle.2.circlepath", @"doc.text.magnifyingglass" };

    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = [UIColor colorWithRed:.13 green:.13 blue:.14 alpha:1];
    c.textLabel.text = titles[row];
    c.textLabel.textColor = WAGRText();
    c.detailTextLabel.text = subs[row];
    c.detailTextLabel.textColor = WAGRSub();
    c.imageView.image = [[UIImage systemImageNamed:icons[row]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WAGRText();
    c.accessoryType = row == WAGRAdvancedRowRawRuntime ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return c;
}

- (UITableViewCell *)systemCellForRow:(NSInteger)row {
    NSString *titles[] = { @"Reiniciar WhatsApp", @"Reset overrides", @"Reset WAGram prefs" };
    NSString *subs[] = { @"Fecha o app", @"Remove wagr.override.* e wagr.observed.*", @"Remove preferências wagr*/wa* do tweak" };
    NSString *icons[] = { @"power", @"arrow.counterclockwise", @"trash" };

    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = [UIColor colorWithRed:.13 green:.13 blue:.14 alpha:1];
    c.textLabel.text = titles[row];
    c.textLabel.textColor = row == WAGRSystemRowRestart ? WAGRRed() : WAGRText();
    c.detailTextLabel.text = subs[row];
    c.detailTextLabel.textColor = WAGRSub();
    c.imageView.image = [[UIImage systemImageNamed:icons[row]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WAGRText();
    return c;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    switch ((WAGRRootSection)ip.section) {
        case WAGRRootSectionAbout: return [self aboutCell];
        case WAGRRootSectionBundles: return [self bundleCellForRow:ip.row];
        case WAGRRootSectionAdvanced: return [self advancedCellForRow:ip.row];
        case WAGRRootSectionSystem: return [self systemCellForRow:ip.row];
    }
    return [UITableViewCell new];
}

- (void)showDiagnostics {
    NSString *msg = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\nKeychain=%@",
                     WAGRHookRouterDiagnostic() ?: @"Router n/a",
                     WAGRLGDiagnosticText() ?: @"LiquidGlass n/a",
                     WAGRDogfoodDiagnosticText() ?: @"Dogfood n/a",
                     WAKeychainAccessGroupDiagnostic() ?: @"n/a"];
    WAGRAlert(@"Diagnóstico", msg);
}

- (void)resetKeysMatching:(BOOL (^)(NSString *key))match title:(NSString *)title restart:(BOOL)restart {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
                                                               message:@"Confirmar limpeza?"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(__unused id _) {
        NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
        NSUInteger n = 0;
        for (NSString *k in ud.dictionaryRepresentation.allKeys) {
            if (match(k)) { [ud removeObjectForKey:k]; n++; }
        }
        [ud synchronize];
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
        WAGRAlert(@"Reset", [NSString stringWithFormat:@"%lu chaves removidas.", (unsigned long)n]);
        if (restart) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == WAGRRootSectionAbout) {
        WAGRAlert(@"WAGram", @"Long press no item Ajuda/Developer do WhatsApp abre este menu. Esta build mantém o longpress original do router.");
        return;
    }

    if (ip.section == WAGRRootSectionBundles) {
        WAGRSurfaceSpec *spec = _filteredBundles[(NSUInteger)ip.row];
        WAGRSurfaceBrowserVC *vc = [[WAGRSurfaceBrowserVC alloc] initWithSpec:spec];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if (ip.section == WAGRRootSectionAdvanced) {
        if (ip.row == WAGRAdvancedRowRawRuntime) {
            [self.navigationController pushViewController:[WAGRRawSurfaceListVC new] animated:YES];
        } else if (ip.row == WAGRAdvancedRowInstallPersisted) {
            NSUInteger n = WAGRReinstallPersistedHooks();
            WAGRAlert(@"Hooks", [NSString stringWithFormat:@"%lu hooks reinstalados.", (unsigned long)n]);
        } else {
            [self showDiagnostics];
        }
        return;
    }

    if (ip.section == WAGRRootSectionSystem) {
        if (ip.row == WAGRSystemRowRestart) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
        } else if (ip.row == WAGRSystemRowResetOverrides) {
            [self resetKeysMatching:^BOOL(NSString *key) {
                return [key hasPrefix:@"wagr.override"] || [key hasPrefix:@"wagr.observed"];
            } title:@"Reset overrides" restart:NO];
        } else {
            [self resetKeysMatching:^BOOL(NSString *key) {
                return [key hasPrefix:@"wagr"] || [key hasPrefix:@"wa_"] || [key hasPrefix:@"WA"];
            } title:@"Reset WAGram prefs" restart:YES];
        }
    }
}

@end
