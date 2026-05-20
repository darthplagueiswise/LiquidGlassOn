// WAGRNativeDeveloperRouter.xm
// Hooks the real native Developer gates, but the extra injected Settings row opens WATweaks.
// The real WhatsApp Developer row can appear by native gates/overrides; this file should not add
// a second fake Developer entry anymore.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../Menu/WAGRSurfaceListVC.h"

static BOOL (*origProviderDebugAllowed)(id, SEL) = NULL;
static BOOL (*origProviderShortcutAllowed)(id, SEL) = NULL;
static void (*origSettingsViewDidAppear)(id, SEL, BOOL) = NULL;

static BOOL gNativeDevHooksInstalled = NO;
static BOOL gSettingsFooterHookInstalled = NO;
static const void *kWAGRWATweaksFooterKey = &kWAGRWATweaksFooterKey;

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
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

static UIViewController *WAGRTopControllerFromResponder(id sender) {
    UIViewController *vc = [sender isKindOfClass:[UIResponder class]] ? WAGRNearestViewController(sender) : nil;
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

@interface WAGRWATweaksButtonTarget : NSObject
+ (instancetype)shared;
- (void)open:(id)sender;
@end

@implementation WAGRWATweaksButtonTarget
+ (instancetype)shared {
    static WAGRWATweaksButtonTarget *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}
- (void)open:(id)sender { WAGRPresentWATweaksMenu(sender); }
@end

static UITableView *WAGRFindTableView(UIView *view) {
    if ([view isKindOfClass:[UITableView class]]) return (UITableView *)view;
    for (UIView *sub in view.subviews) {
        UITableView *hit = WAGRFindTableView(sub);
        if (hit) return hit;
    }
    return nil;
}

static void WAGRInjectWATweaksFooter(id settingsVC) {
    if (![settingsVC isKindOfClass:[UIViewController class]]) return;
    UIViewController *vc = (UIViewController *)settingsVC;
    UITableView *table = nil;
    if ([settingsVC respondsToSelector:@selector(tableView)]) {
        table = ((UITableView *(*)(id, SEL))objc_msgSend)(settingsVC, @selector(tableView));
    }
    if (!table) table = WAGRFindTableView(vc.view);
    if (!table || objc_getAssociatedObject(table, kWAGRWATweaksFooterKey)) return;

    UIView *oldFooter = table.tableFooterView;
    CGFloat oldHeight = oldFooter ? MAX(oldFooter.frame.size.height, 1.0) : 0.0;
    CGFloat rowHeight = 58.0;
    CGFloat topPadding = 14.0;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, oldHeight + rowHeight + topPadding + 14.0)];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    container.backgroundColor = UIColor.clearColor;

    if (oldFooter) {
        oldFooter.frame = CGRectMake(0, 0, table.bounds.size.width, oldHeight);
        [container addSubview:oldFooter];
    }

    UIControl *row = [[UIControl alloc] initWithFrame:CGRectMake(0, oldHeight + topPadding, table.bounds.size.width, rowHeight)];
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    row.layer.cornerRadius = 20.0;
    row.clipsToBounds = YES;
    row.backgroundColor = [UIColor colorWithRed:0.105 green:0.105 blue:0.110 alpha:1.0];
    [row addTarget:[WAGRWATweaksButtonTarget shared]
            action:@selector(open:)
  forControlEvents:UIControlEventTouchUpInside];

    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(28, 0, 42, rowHeight)];
    icon.text = @"</>";
    icon.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    icon.textColor = [UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:1.0];
    icon.textAlignment = NSTextAlignmentCenter;
    [row addSubview:icon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(88, 0, row.bounds.size.width - 126, rowHeight)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.text = @"WATweaks";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    title.textColor = UIColor.labelColor;
    [row addSubview:title];

    UILabel *chev = [[UILabel alloc] initWithFrame:CGRectMake(row.bounds.size.width - 34, 0, 18, rowHeight)];
    chev.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    chev.text = @"›";
    chev.font = [UIFont systemFontOfSize:30 weight:UIFontWeightRegular];
    chev.textColor = UIColor.tertiaryLabelColor;
    chev.textAlignment = NSTextAlignmentCenter;
    [row addSubview:chev];

    [container addSubview:row];
    table.tableFooterView = container;
    objc_setAssociatedObject(table, kWAGRWATweaksFooterKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void hookSettingsViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (origSettingsViewDidAppear) origSettingsViewDidAppear(self, _cmd, animated);
    WAGRInjectWATweaksFooter(self);
}

extern "C" void WAGRNativeDeveloperEnsureHooksInstalled(void) {
    if (gNativeDevHooksInstalled) return;

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

    if (!gSettingsFooterHookInstalled) {
        Class settings = NSClassFromString(@"WASettingsViewController");
        SEL sel = @selector(viewDidAppear:);
        Method m = settings ? class_getInstanceMethod(settings, sel) : NULL;
        if (settings && m) {
            MSHookMessageEx(settings, sel, (IMP)hookSettingsViewDidAppear, (IMP *)&origSettingsViewDidAppear);
            gSettingsFooterHookInstalled = (origSettingsViewDidAppear != NULL);
        }
    }

    gNativeDevHooksInstalled = (origProviderDebugAllowed || origProviderShortcutAllowed || gSettingsFooterHookInstalled);
}

extern "C" NSString *WAGRNativeDeveloperDiagnostic(void) {
    return [NSString stringWithFormat:@"nativeDeveloperHooks=%@\nproviderAllowed=%@\nproviderShortcut=%@\nsettingsWATweaksRow=%@\npref=%@",
            gNativeDevHooksInstalled ? @"YES" : @"NO",
            origProviderDebugAllowed ? @"YES" : @"NO",
            origProviderShortcutAllowed ? @"YES" : @"NO",
            gSettingsFooterHookInstalled ? @"YES" : @"NO",
            WAGRNativeDeveloperEnabled() ? @"ON" : @"OFF"];
}

__attribute__((constructor))
static void WAGRNativeDeveloperCtor(void) {
    @autoreleasepool {
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
