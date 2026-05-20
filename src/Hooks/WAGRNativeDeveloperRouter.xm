// WAGRNativeDeveloperRouter.xm
// Native WhatsApp Settings integration:
// - Native Developer gates remain hooked so WhatsApp can show/open its own Developer row.
// - Our injected row is WATweaks, and it is inserted as a real WATableSection/WATableRow,
//   not as a custom tableFooterView. This lets WhatsApp draw the default row style.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../Menu/WAGRSurfaceListVC.h"

static BOOL (*origProviderDebugAllowed)(id, SEL) = NULL;
static BOOL (*origProviderShortcutAllowed)(id, SEL) = NULL;
static void (*origSettingsSetUpTableView)(id, SEL) = NULL;
static void (*origSettingsViewDidAppear)(id, SEL, BOOL) = NULL;

static BOOL gNativeDevHooksInstalled = NO;
static BOOL gSettingsTableHookInstalled = NO;
static BOOL gSettingsAppearHookInstalled = NO;
static const void *kWATweaksNativeRowInjectedKey = &kWATweaksNativeRowInjectedKey;

static BOOL WAGRNativeDeveloperEnabled(void) {
    return WAGRPref(kWAGRDebugMenuNative) ||
           WAGRPref(kWAGRDebugMode) ||
           WAGRPref(kWAGRInternalMaster) ||
           WAGRPref(kWAGREmployeeMaster);
}

static BOOL hookProviderDebugAllowed(id self, SEL _cmd) {
    if (WAGRNativeDeveloperEnabled()) return YES;
    return origProviderDebugAllowed ? origProviderDebugAllowed(self, _cmd) : NO;
}

static BOOL hookProviderShortcutAllowed(id self, SEL _cmd) {
    if (WAGRNativeDeveloperEnabled()) return YES;
    return origProviderShortcutAllowed ? origProviderShortcutAllowed(self, _cmd) : NO;
}

static UIViewController *WAGRNearestViewController(UIResponder *r) {
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

static UIViewController *WAGRTopControllerFromResponder(id sender) {
    UIViewController *vc = [sender isKindOfClass:UIResponder.class] ? WAGRNearestViewController(sender) : nil;
    if (vc) return vc;

    UIViewController *c = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) { c = w.rootViewController; break; }
        }
        if (c) break;
    }

    UIViewController *last = nil;
    while (c && c != last) {
        last = c;
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

static void WAGRPresentWATweaksMenu(id sender) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *from = WAGRTopControllerFromResponder(sender);
        if (!from) return;
        if ([from isKindOfClass:NSClassFromString(@"WAGRSurfaceListVC")]) return;

        WAGRSurfaceListVC *root = [WAGRSurfaceListVC new];
        root.title = @"WATweaks";
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        [from presentViewController:nav animated:YES completion:nil];
    });
}

static UITableView *WAGRFindTableView(UIView *view) {
    if ([view isKindOfClass:UITableView.class]) return (UITableView *)view;
    for (UIView *sub in view.subviews) {
        UITableView *hit = WAGRFindTableView(sub);
        if (hit) return hit;
    }
    return nil;
}

static void WAGRConfigureNativeWATweaksCell(UITableViewCell *cell) {
    if (!cell) return;
    cell.textLabel.text = @"WATweaks";
    cell.textLabel.textColor = UIColor.labelColor;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    UIImage *img = nil;
    if (@available(iOS 13.0, *)) {
        img = [UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right"];
        if (!img) img = [UIImage systemImageNamed:@"terminal"];
    }
    cell.imageView.image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = UIColor.systemBlueColor;
}

static BOOL WAGRInjectWATweaksNativeSection(id settingsVC) {
    if (!settingsVC || objc_getAssociatedObject(settingsVC, kWATweaksNativeRowInjectedKey)) return NO;

    Class sectionClass = NSClassFromString(@"WATableSection");
    if (!sectionClass || ![settingsVC respondsToSelector:NSSelectorFromString(@"addSection:")]) return NO;

    id section = [[sectionClass alloc] init];
    if (!section || ![section respondsToSelector:NSSelectorFromString(@"addDefaultTableRow")]) return NO;

    id row = ((id (*)(id, SEL))objc_msgSend)(section, NSSelectorFromString(@"addDefaultTableRow"));
    if (!row || ![row respondsToSelector:NSSelectorFromString(@"cell")]) return NO;

    UITableViewCell *cell = ((UITableViewCell *(*)(id, SEL))objc_msgSend)(row, NSSelectorFromString(@"cell"));
    WAGRConfigureNativeWATweaksCell(cell);

    if ([row respondsToSelector:NSSelectorFromString(@"setHandler:")]) {
        void (^handler)(void) = ^{
            WAGRPresentWATweaksMenu(settingsVC);
        };
        ((void (*)(id, SEL, id))objc_msgSend)(row, NSSelectorFromString(@"setHandler:"), [handler copy]);
    }

    ((void (*)(id, SEL, id))objc_msgSend)(settingsVC, NSSelectorFromString(@"addSection:"), section);
    objc_setAssociatedObject(settingsVC, kWATweaksNativeRowInjectedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UITableView *table = nil;
    if ([settingsVC respondsToSelector:@selector(tableView)]) {
        table = ((UITableView *(*)(id, SEL))objc_msgSend)(settingsVC, @selector(tableView));
    }
    if (!table && [settingsVC isKindOfClass:UIViewController.class]) table = WAGRFindTableView(((UIViewController *)settingsVC).view);
    [table reloadData];
    return YES;
}

static void hookSettingsSetUpTableView(id self, SEL _cmd) {
    if (origSettingsSetUpTableView) origSettingsSetUpTableView(self, _cmd);
    WAGRInjectWATweaksNativeSection(self);
}

static void hookSettingsViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (origSettingsViewDidAppear) origSettingsViewDidAppear(self, _cmd, animated);
    WAGRInjectWATweaksNativeSection(self);
}

extern "C" void WAGRNativeDeveloperEnsureHooksInstalled(void) {
    if (gNativeDevHooksInstalled && gSettingsTableHookInstalled) return;

    Class provider = NSClassFromString(@"_TtC15WADebugMenuMain17DebugMenuProvider");
    if (provider) {
        SEL allowed = NSSelectorFromString(@"isDebugMenuAllowed");
        SEL shortcut = NSSelectorFromString(@"isDebugMenuShortcutEnabled");
        Method ma = class_getInstanceMethod(provider, allowed);
        Method ms = class_getInstanceMethod(provider, shortcut);
        if (ma && !origProviderDebugAllowed) {
            MSHookMessageEx(provider, allowed, (IMP)hookProviderDebugAllowed, (IMP *)&origProviderDebugAllowed);
        }
        if (ms && !origProviderShortcutAllowed) {
            MSHookMessageEx(provider, shortcut, (IMP)hookProviderShortcutAllowed, (IMP *)&origProviderShortcutAllowed);
        }
    }

    Class settings = NSClassFromString(@"WASettingsViewController");
    if (settings && !gSettingsTableHookInstalled) {
        SEL sel = NSSelectorFromString(@"setUpTableView");
        Method m = class_getInstanceMethod(settings, sel);
        if (m) {
            MSHookMessageEx(settings, sel, (IMP)hookSettingsSetUpTableView, (IMP *)&origSettingsSetUpTableView);
            gSettingsTableHookInstalled = (origSettingsSetUpTableView != NULL);
        }
    }

    if (settings && !gSettingsAppearHookInstalled) {
        SEL sel = @selector(viewDidAppear:);
        Method m = class_getInstanceMethod(settings, sel);
        if (m) {
            MSHookMessageEx(settings, sel, (IMP)hookSettingsViewDidAppear, (IMP *)&origSettingsViewDidAppear);
            gSettingsAppearHookInstalled = (origSettingsViewDidAppear != NULL);
        }
    }

    gNativeDevHooksInstalled = (origProviderDebugAllowed || origProviderShortcutAllowed || gSettingsTableHookInstalled || gSettingsAppearHookInstalled);
}

extern "C" NSString *WAGRNativeDeveloperDiagnostic(void) {
    return [NSString stringWithFormat:
            @"nativeDeveloperHooks=%@\n"
             "providerAllowed=%@\n"
             "providerShortcut=%@\n"
             "nativeWATweaksRow=setUp:%@ appear:%@\n"
             "pref=%@",
            gNativeDevHooksInstalled ? @"YES" : @"NO",
            origProviderDebugAllowed ? @"YES" : @"NO",
            origProviderShortcutAllowed ? @"YES" : @"NO",
            gSettingsTableHookInstalled ? @"YES" : @"NO",
            gSettingsAppearHookInstalled ? @"YES" : @"NO",
            WAGRNativeDeveloperEnabled() ? @"ON" : @"OFF"];
}

__attribute__((constructor))
static void WAGRNativeDeveloperCtor(void) {
    @autoreleasepool {
        WATweaksMigrateLegacyDefaults();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRNativeDeveloperEnsureHooksInstalled();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRNativeDeveloperEnsureHooksInstalled();
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRNativeDeveloperEnsureHooksInstalled();
        });
    }
}
