// WAGRSurfaceListVC.m — WATweaks root menu.
// User-facing state is watweaks.* only. WAGR symbol names are kept for source compatibility.

#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <stdlib.h>
#import "WAGRSurfaceListVC.h"
#import "WAGRSurfaceBrowserVC.h"
#import "../WAGramPrefix.h"
#import "../WAUtils.h"
#import "../Runtime/WAGRSurface.h"

extern void WAGRWAABEnsureHooksInstalled(void);

static const void *kWATweaksPrefSwitchKey = &kWATweaksPrefSwitchKey;

static UIColor *WTText(void) { return UIColor.labelColor; }
static UIColor *WTSub(void) { return UIColor.secondaryLabelColor; }
static UIColor *WTRed(void) { return UIColor.systemRedColor; }
static UIColor *WTCell(void) { return [UIColor colorWithRed:.13 green:.13 blue:.14 alpha:1]; }
static UIColor *WTBG(void) { return [UIColor colorWithRed:.055 green:.055 blue:.060 alpha:1]; }

static UIViewController *WTTopController(void) {
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

static void WTAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *a = [UIAlertController alertControllerWithTitle:title ?: @"WATweaks"
                                                                   message:message ?: @""
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Copiar" style:UIAlertActionStyleDefault handler:^(__unused id _) {
            UIPasteboard.generalPasteboard.string = message ?: @"";
        }]];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [WTTopController() presentViewController:a animated:YES completion:nil];
    });
}

@interface WTRawSurfaceListVC : UITableViewController
@property(nonatomic, strong) NSArray<WAGRSurfaceSpec *> *surfaces;
@end

@implementation WTRawSurfaceListVC
- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"Runtime Avançado";
    _surfaces = [WAGRSurfaceSpec allSurfaces];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WTBG();
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section { return (NSInteger)_surfaces.count; }
- (void)tableView:(UITableView *)tv willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *h = (UITableViewHeaderFooterView *)view;
        h.textLabel.font = [UIFont boldSystemFontOfSize:11];
        h.textLabel.textColor = [UIColor colorWithWhite:.55 alpha:1];
    }
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section { return @"Surfaces técnicas"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    return @"Browser bruto para debug. Os overrides usam a mesma chave canônica do menu principal.";
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    WAGRSurfaceSpec *s = _surfaces[(NSUInteger)ip.row];
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = WTCell();
    c.textLabel.text = s.title;
    c.textLabel.textColor = WTText();
    c.detailTextLabel.text = s.subtitle ?: @"";
    c.detailTextLabel.textColor = WTSub();
    c.imageView.image = [[UIImage systemImageNamed:s.icon ?: @"circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WTText();
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    WAGRSurfaceBrowserVC *vc = [[WAGRSurfaceBrowserVC alloc] initWithSpec:_surfaces[(NSUInteger)ip.row]];
    [self.navigationController pushViewController:vc animated:YES];
}
@end

typedef NS_ENUM(NSInteger, WTRootSection) {
    WTRootSectionAbout = 0,
    WTRootSectionPreferences,
    WTRootSectionBundles,
    WTRootSectionAdvanced,
    WTRootSectionSystem,
};

typedef NS_ENUM(NSInteger, WTPrefRow) {
    WTPrefRowNativeDeveloper = 0,
    WTPrefRowDebugMode,
    WTPrefRowKeychainRewrite,
    WTPrefRowKeychainObserver,
};

typedef NS_ENUM(NSInteger, WTAdvancedRow) {
    WTAdvancedRowRawRuntime = 0,
    WTAdvancedRowInstallPersisted,
    WTAdvancedRowDiagnostics,
};

typedef NS_ENUM(NSInteger, WTSystemRow) {
    WTSystemRowRestart = 0,
    WTSystemRowResetOverrides,
    WTSystemRowResetAll,
};

@interface WAGRSurfaceListVC () <UISearchResultsUpdating>
@property(nonatomic, strong) NSArray<WAGRSurfaceSpec *> *bundles;
@property(nonatomic, strong) NSArray<WAGRSurfaceSpec *> *filteredBundles;
@property(nonatomic, strong) UISearchController *search;
@end

@implementation WAGRSurfaceListVC

- (instancetype)init {
    if (!(self = [super initWithStyle:UITableViewStyleInsetGrouped])) return nil;
    self.title = @"WATweaks";
    _bundles = [WAGRSurfaceSpec featureBundles];
    _filteredBundles = _bundles;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = WTBG();
    self.navigationItem.title = @"WATweaks";
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"WATweaks";
    [self.tableView reloadData];
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 5; }

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    switch ((WTRootSection)section) {
        case WTRootSectionAbout: return 1;
        case WTRootSectionPreferences: return 4;
        case WTRootSectionBundles: return (NSInteger)_filteredBundles.count;
        case WTRootSectionAdvanced: return 3;
        case WTRootSectionSystem: return 3;
    }
    return 0;
}

- (void)tableView:(UITableView *)tv willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *h = (UITableViewHeaderFooterView *)view;
        h.textLabel.font = [UIFont boldSystemFontOfSize:11];
        h.textLabel.textColor = [UIColor colorWithWhite:.55 alpha:1];
    }
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    switch ((WTRootSection)section) {
        case WTRootSectionAbout: return nil;
        case WTRootSectionPreferences: return @"Preferências";
        case WTRootSectionBundles: return @"Categorias";
        case WTRootSectionAdvanced: return @"Avançado";
        case WTRootSectionSystem: return @"Sistema";
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)section {
    if (section == WTRootSectionPreferences)
        return @"Overrides salvos são reaplicados automaticamente. Não existe mais startupHooksEnabled escondido.";
    if (section == WTRootSectionBundles)
        return @"Os bundles e o Runtime Avançado usam a mesma chave canônica watweaks.override.*.";
    if (section == WTRootSectionAdvanced)
        return @"Runtime bruto fica aqui, separado do menu normal.";
    return nil;
}

- (UITableViewCell *)baseCellWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(NSString *)icon {
    UITableViewCell *c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    c.backgroundColor = WTCell();
    c.textLabel.text = title;
    c.textLabel.textColor = WTText();
    c.detailTextLabel.text = subtitle ?: @"";
    c.detailTextLabel.textColor = WTSub();
    c.imageView.image = [[UIImage systemImageNamed:icon ?: @"circle"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    c.imageView.tintColor = WTText();
    c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return c;
}

- (UITableViewCell *)aboutCell {
    return [self baseCellWithTitle:@"WATweaks"
                          subtitle:[NSString stringWithFormat:@"%lu overrides únicos", (unsigned long)WATweaksUniqueOverrideCount()]
                              icon:@"bolt.horizontal.circle"];
}

- (NSString *)prefKeyForRow:(NSInteger)row {
    switch ((WTPrefRow)row) {
        case WTPrefRowNativeDeveloper: return kWATweaksPrefNativeDeveloper;
        case WTPrefRowDebugMode: return kWATweaksPrefDebugMode;
        case WTPrefRowKeychainRewrite: return kWATweaksPrefKeychainRewrite;
        case WTPrefRowKeychainObserver: return kWATweaksPrefKeychainObserver;
    }
    return @"";
}

- (UITableViewCell *)prefCellForRow:(NSInteger)row {
    NSString *titles[] = { @"Developer nativo", @"Debug mode", @"Keychain rewrite", @"Keychain observer" };
    NSString *subs[] = {
        @"Libera gates do Developer real do WhatsApp",
        @"Ativa auxiliares internos da tweak",
        @"Reescreve access-group quando ativado",
        @"Loga SecItemAdd/Copy/Update/Delete via fishhook"
    };
    NSString *icons[] = { @"chevron.left.forwardslash.chevron.right", @"ladybug", @"key", @"eye" };
    NSString *key = [self prefKeyForRow:row];

    UITableViewCell *c = [self baseCellWithTitle:titles[row] subtitle:subs[row] icon:icons[row]];
    c.accessoryType = UITableViewCellAccessoryNone;

    UISwitch *sw = [UISwitch new];
    sw.on = WAGRPref(key);
    objc_setAssociatedObject(sw, kWATweaksPrefSwitchKey, key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sw addTarget:self action:@selector(prefSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    c.accessoryView = sw;
    return c;
}

- (void)prefSwitchChanged:(UISwitch *)sw {
    NSString *key = objc_getAssociatedObject(sw, kWATweaksPrefSwitchKey);
    if (!key.length) return;
    WATweaksSetPref(key, sw.isOn);
}

- (UITableViewCell *)bundleCellForRow:(NSInteger)row {
    WAGRSurfaceSpec *s = _filteredBundles[(NSUInteger)row];
    UITableViewCell *c = [self baseCellWithTitle:s.title subtitle:s.subtitle ?: @"" icon:s.icon ?: @"circle"];
    return c;
}

- (UITableViewCell *)advancedCellForRow:(NSInteger)row {
    NSString *titles[] = { @"Runtime Browser Avançado", @"Instalar hooks salvos", @"Diagnóstico" };
    NSString *subs[] = {
        @"WAABProperties, WAContextMain, WAAuraGating etc.",
        @"Reinstala overrides ObjC persistidos agora",
        @"Router, core hooks, WATweaks prefs, Keychain"
    };
    NSString *icons[] = { @"terminal", @"arrow.triangle.2.circlepath", @"doc.text.magnifyingglass" };
    UITableViewCell *c = [self baseCellWithTitle:titles[row] subtitle:subs[row] icon:icons[row]];
    c.accessoryType = row == WTAdvancedRowRawRuntime ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    return c;
}

- (UITableViewCell *)systemCellForRow:(NSInteger)row {
    NSString *titles[] = { @"Reiniciar WhatsApp", @"Reset overrides", @"Reset WATweaks prefs" };
    NSString *subs[] = {
        @"Fecha o app",
        @"Remove watweaks.override.* e watweaks.observed.*",
        @"Remove todas as preferências watweaks.*"
    };
    NSString *icons[] = { @"power", @"arrow.counterclockwise", @"trash" };

    UITableViewCell *c = [self baseCellWithTitle:titles[row] subtitle:subs[row] icon:icons[row]];
    c.textLabel.textColor = row == WTSystemRowRestart ? WTRed() : WTText();
    c.accessoryType = UITableViewCellAccessoryNone;
    return c;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    switch ((WTRootSection)ip.section) {
        case WTRootSectionAbout: return [self aboutCell];
        case WTRootSectionPreferences: return [self prefCellForRow:ip.row];
        case WTRootSectionBundles: return [self bundleCellForRow:ip.row];
        case WTRootSectionAdvanced: return [self advancedCellForRow:ip.row];
        case WTRootSectionSystem: return [self systemCellForRow:ip.row];
    }
    return [UITableViewCell new];
}

- (void)showDiagnostics {
    NSString *msg = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\nKeychain=%@\n\nprefs: nativeDeveloper=%@ debugMode=%@ keychainRewrite=%@ keychainObserver=%@",
                     WAGRHookRouterDiagnostic() ?: @"Router n/a",
                     WAGRLGDiagnosticText() ?: @"LiquidGlass n/a",
                     WAGRDogfoodDiagnosticText() ?: @"Developer n/a",
                     WAKeychainAccessGroupDiagnostic() ?: @"n/a",
                     WAGRPref(kWATweaksPrefNativeDeveloper) ? @"ON" : @"OFF",
                     WAGRPref(kWATweaksPrefDebugMode) ? @"ON" : @"OFF",
                     WAGRPref(kWATweaksPrefKeychainRewrite) ? @"ON" : @"OFF",
                     WAGRPref(kWATweaksPrefKeychainObserver) ? @"ON" : @"OFF"];
    WTAlert(@"Diagnóstico", msg);
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
        WTAlert(@"Reset", [NSString stringWithFormat:@"%lu chaves removidas.", (unsigned long)n]);
        if (restart) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];

    if (ip.section == WTRootSectionAbout) {
        WTAlert(@"WATweaks", @"Menu da tweak. A row Developer nativa do WhatsApp continua sendo do próprio app; a row WATweaks abre este menu.");
        return;
    }

    if (ip.section == WTRootSectionBundles) {
        WAGRSurfaceSpec *spec = _filteredBundles[(NSUInteger)ip.row];
        WAGRSurfaceBrowserVC *vc = [[WAGRSurfaceBrowserVC alloc] initWithSpec:spec];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    if (ip.section == WTRootSectionAdvanced) {
        if (ip.row == WTAdvancedRowRawRuntime) {
            [self.navigationController pushViewController:[WTRawSurfaceListVC new] animated:YES];
        } else if (ip.row == WTAdvancedRowInstallPersisted) {
            NSUInteger n = WAGRReinstallPersistedHooks();
            WTAlert(@"Hooks", [NSString stringWithFormat:@"%lu hooks ObjC reinstalados.", (unsigned long)n]);
        } else {
            [self showDiagnostics];
        }
        return;
    }

    if (ip.section == WTRootSectionSystem) {
        if (ip.row == WTSystemRowRestart) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
        } else if (ip.row == WTSystemRowResetOverrides) {
            [self resetKeysMatching:^BOOL(NSString *key) {
                return [key hasPrefix:@"watweaks.override."] || [key hasPrefix:@"watweaks.observed."];
            } title:@"Reset overrides" restart:NO];
        } else {
            [self resetKeysMatching:^BOOL(NSString *key) {
                return [key hasPrefix:@"watweaks."] || [key hasPrefix:@"wagr."] || [key hasPrefix:@"wagr_"];
            } title:@"Reset WATweaks prefs" restart:YES];
        }
    }
}
@end
