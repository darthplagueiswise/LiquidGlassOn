// WAGRNativeDeveloperRouter.xm
// Native WhatsApp Settings integration, model-level version.
// Watusi's IPA shows the correct pattern: hook WASettingsViewController setSections:
// and inject a WATableSection/WATableRow before WhatsApp commits the model.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../Menu/WAGRSurfaceListVC.h"

static BOOL (*origProviderDebugAllowed)(id, SEL) = NULL;
static BOOL (*origProviderShortcutAllowed)(id, SEL) = NULL;
static void (*origSettingsSetSections)(id, SEL, id) = NULL;
static void (*origSettingsViewDidAppear)(id, SEL, BOOL) = NULL;

static BOOL gNativeDevHooksInstalled = NO;
static BOOL gSettingsSetSectionsHookInstalled = NO;
static BOOL gSettingsAppearHookInstalled = NO;
static const void *kWATweaksNativeSectionKey = &kWATweaksNativeSectionKey;

static BOOL WAGRNativeDeveloperEnabled(void) {
    return WAGRPref(kWAGRDebugMenuNative) || WAGRPref(kWAGRDebugMode) || WAGRPref(kWAGRInternalMaster) || WAGRPref(kWAGREmployeeMaster);
}
static BOOL hookProviderDebugAllowed(id self, SEL _cmd) { return WAGRNativeDeveloperEnabled() ? YES : (origProviderDebugAllowed ? origProviderDebugAllowed(self, _cmd) : NO); }
static BOOL hookProviderShortcutAllowed(id self, SEL _cmd) { return WAGRNativeDeveloperEnabled() ? YES : (origProviderShortcutAllowed ? origProviderShortcutAllowed(self, _cmd) : NO); }

static UIViewController *WAGRNearestViewController(UIResponder *r) {
    while (r) { if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r; r = r.nextResponder; }
    return nil;
}
static UIViewController *WAGRTopControllerFromResponder(id sender) {
    UIViewController *vc = [sender isKindOfClass:UIResponder.class] ? WAGRNearestViewController(sender) : nil;
    if (vc) return vc;
    UIViewController *c = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) { c = w.rootViewController; break; }
        if (c) break;
    }
    UIViewController *last = nil;
    while (c && c != last) {
        last = c;
        if (c.presentedViewController) { c = c.presentedViewController; continue; }
        if ([c isKindOfClass:UINavigationController.class]) { UIViewController *v = ((UINavigationController *)c).visibleViewController; if (v && v != c) { c = v; continue; } }
        if ([c isKindOfClass:UITabBarController.class]) { UIViewController *v = ((UITabBarController *)c).selectedViewController; if (v && v != c) { c = v; continue; } }
        break;
    }
    return c;
}
static void WAGRPresentWATweaksMenu(id sender) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *from = WAGRTopControllerFromResponder(sender);
        if (!from || [from isKindOfClass:NSClassFromString(@"WAGRSurfaceListVC")]) return;
        WAGRSurfaceListVC *root = [WAGRSurfaceListVC new];
        root.title = @"WATweaks";
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [from presentViewController:nav animated:YES completion:nil];
    });
}

static UITableViewCell *WATMakeFallbackCell(void) {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text = @"WATweaks";
    cell.textLabel.textColor = UIColor.labelColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right"] ?: [UIImage systemImageNamed:@"terminal"];
        cell.imageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = UIColor.systemBlueColor;
    }
    return cell;
}
static void WATConfigureCell(UITableViewCell *cell) {
    if (!cell) return;
    cell.textLabel.text = @"WATweaks";
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right"] ?: [UIImage systemImageNamed:@"terminal"];
        cell.imageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = UIColor.systemBlueColor;
    }
}
static id WATCreateNativeSection(id settingsVC) {
    id existing = objc_getAssociatedObject(settingsVC, kWATweaksNativeSectionKey);
    if (existing) return existing;

    Class sectionClass = NSClassFromString(@"WATableSection");
    if (!sectionClass) return nil;
    id section = [[sectionClass alloc] init];
    if (!section) return nil;

    id row = nil;
    if ([section respondsToSelector:NSSelectorFromString(@"addDefaultTableRow")]) {
        row = ((id (*)(id, SEL))objc_msgSend)(section, NSSelectorFromString(@"addDefaultTableRow"));
        if ([row respondsToSelector:NSSelectorFromString(@"cell")]) {
            UITableViewCell *cell = ((UITableViewCell *(*)(id, SEL))objc_msgSend)(row, NSSelectorFromString(@"cell"));
            WATConfigureCell(cell);
        }
    } else if ([settingsVC respondsToSelector:NSSelectorFromString(@"settingsTableRowFromCell:")] && [section respondsToSelector:NSSelectorFromString(@"addRow:")]) {
        UITableViewCell *cell = WATMakeFallbackCell();
        row = ((id (*)(id, SEL, id))objc_msgSend)(settingsVC, NSSelectorFromString(@"settingsTableRowFromCell:"), cell);
        if (row) ((void (*)(id, SEL, id))objc_msgSend)(section, NSSelectorFromString(@"addRow:"), row);
    }
    if (!row) return nil;
    if ([row respondsToSelector:NSSelectorFromString(@"setHandler:")]) {
        void (^handler)(void) = ^{ WAGRPresentWATweaksMenu(settingsVC); };
        ((void (*)(id, SEL, id))objc_msgSend)(row, NSSelectorFromString(@"setHandler:"), [handler copy]);
    }
    objc_setAssociatedObject(settingsVC, kWATweaksNativeSectionKey, section, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return section;
}
static BOOL WATArrayContainsPointer(NSArray *arr, id obj) {
    if (!arr || !obj) return NO;
    for (id x in arr) if (x == obj) return YES;
    return NO;
}
static id WATSectionsByAddingWATweaks(id settingsVC, id sections) {
    if (![sections isKindOfClass:NSArray.class]) return sections;
    id section = WATCreateNativeSection(settingsVC);
    if (!section || WATArrayContainsPointer((NSArray *)sections, section)) return sections;
    NSMutableArray *mutable = [(NSArray *)sections mutableCopy];
    [mutable addObject:section];
    return mutable;
}
static id WATReadSections(id settingsVC) {
    id sections = nil;
    if ([settingsVC respondsToSelector:NSSelectorFromString(@"sections")]) sections = ((id (*)(id, SEL))objc_msgSend)(settingsVC, NSSelectorFromString(@"sections"));
    if (!sections) { @try { sections = [settingsVC valueForKey:@"_sections"]; } @catch (__unused NSException *e) {} }
    return sections;
}
static void WATRefreshSectionsIfPossible(id settingsVC) {
    id sections = WATReadSections(settingsVC);
    id updated = WATSectionsByAddingWATweaks(settingsVC, sections);
    if (updated && updated != sections && origSettingsSetSections) origSettingsSetSections(settingsVC, NSSelectorFromString(@"setSections:"), updated);
}
static void hookSettingsSetSections(id self, SEL _cmd, id sections) {
    id updated = WATSectionsByAddingWATweaks(self, sections);
    if (origSettingsSetSections) origSettingsSetSections(self, _cmd, updated ?: sections);
}
static void hookSettingsViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (origSettingsViewDidAppear) origSettingsViewDidAppear(self, _cmd, animated);
    WATRefreshSectionsIfPossible(self);
}

extern "C" void WAGRNativeDeveloperEnsureHooksInstalled(void) {
    if (gNativeDevHooksInstalled && gSettingsSetSectionsHookInstalled && gSettingsAppearHookInstalled) return;

    Class provider = NSClassFromString(@"_TtC15WADebugMenuMain17DebugMenuProvider");
    if (provider) {
        SEL allowed = NSSelectorFromString(@"isDebugMenuAllowed");
        SEL shortcut = NSSelectorFromString(@"isDebugMenuShortcutEnabled");
        if (class_getInstanceMethod(provider, allowed) && !origProviderDebugAllowed) MSHookMessageEx(provider, allowed, (IMP)hookProviderDebugAllowed, (IMP *)&origProviderDebugAllowed);
        if (class_getInstanceMethod(provider, shortcut) && !origProviderShortcutAllowed) MSHookMessageEx(provider, shortcut, (IMP)hookProviderShortcutAllowed, (IMP *)&origProviderShortcutAllowed);
    }

    Class settings = NSClassFromString(@"WASettingsViewController");
    if (settings && !gSettingsSetSectionsHookInstalled) {
        SEL sel = NSSelectorFromString(@"setSections:");
        if (class_getInstanceMethod(settings, sel)) {
            MSHookMessageEx(settings, sel, (IMP)hookSettingsSetSections, (IMP *)&origSettingsSetSections);
            gSettingsSetSectionsHookInstalled = (origSettingsSetSections != NULL);
        }
    }
    if (settings && !gSettingsAppearHookInstalled) {
        SEL sel = @selector(viewDidAppear:);
        if (class_getInstanceMethod(settings, sel)) {
            MSHookMessageEx(settings, sel, (IMP)hookSettingsViewDidAppear, (IMP *)&origSettingsViewDidAppear);
            gSettingsAppearHookInstalled = (origSettingsViewDidAppear != NULL);
        }
    }
    gNativeDevHooksInstalled = (origProviderDebugAllowed || origProviderShortcutAllowed || gSettingsSetSectionsHookInstalled || gSettingsAppearHookInstalled);
}

extern "C" NSString *WAGRNativeDeveloperDiagnostic(void) {
    return [NSString stringWithFormat:@"nativeDeveloperHooks=%@\nproviderAllowed=%@\nproviderShortcut=%@\nwatweaksRow=setSections:%@ appear:%@\npref=%@",
            gNativeDevHooksInstalled ? @"YES" : @"NO",
            origProviderDebugAllowed ? @"YES" : @"NO",
            origProviderShortcutAllowed ? @"YES" : @"NO",
            gSettingsSetSectionsHookInstalled ? @"YES" : @"NO",
            gSettingsAppearHookInstalled ? @"YES" : @"NO",
            WAGRNativeDeveloperEnabled() ? @"ON" : @"OFF"];
}

__attribute__((constructor))
static void WAGRNativeDeveloperCtor(void) {
    @autoreleasepool {
        WATweaksMigrateLegacyDefaults();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.00 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.00 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
    }
}
