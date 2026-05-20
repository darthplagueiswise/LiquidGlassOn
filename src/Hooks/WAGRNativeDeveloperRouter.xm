// WAGRNativeDeveloperRouter.xm
// Native Developer router validated from WhatsApp(3) ObjC category scan.
// Real hook points:
//   _TtC15WADebugMenuMain17DebugMenuProvider (WADebugMenuMain category)
//     -isDebugMenuAllowed
//     -isDebugMenuShortcutEnabled
//     -presentDebugControllerIfNeeded
//     -debugViewController
//   WAContext / WAContextMain via WADebugMenuBase category
//     -resolveDebugMenuProviding
//     -debugMenuProvider
// This file does not use broad Employee/Dogfood runtime scanning.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL (*origProviderDebugAllowed)(id, SEL) = NULL;
static BOOL (*origProviderShortcutAllowed)(id, SEL) = NULL;
static void (*origSettingsViewDidAppear)(id, SEL, BOOL) = NULL;

static BOOL gNativeDevHooksInstalled = NO;
static BOOL gSettingsFooterHookInstalled = NO;
static BOOL gOpeningNativeDeveloper = NO;
static const void *kWAGRNativeDeveloperFooterKey = &kWAGRNativeDeveloperFooterKey;

static BOOL WAGRNativeDeveloperEnabled(void) {
    return WAGRPref(kWAGRDebugMenuNative) ||
           WAGRPref(kWAGRDebugMode) ||
           WAGRPref(kWAGRInternalMaster) ||
           WAGRPref(kWAGREmployeeMaster) ||
           gOpeningNativeDeveloper;
}

static BOOL hookProviderDebugAllowed(id self, SEL _cmd) {
    if (WAGRNativeDeveloperEnabled()) return YES;
    return origProviderDebugAllowed ? origProviderDebugAllowed(self, _cmd) : NO;
}

static BOOL hookProviderShortcutAllowed(id self, SEL _cmd) {
    if (WAGRNativeDeveloperEnabled()) return YES;
    return origProviderShortcutAllowed ? origProviderShortcutAllowed(self, _cmd) : NO;
}

static id WAGRCallID0(id obj, SEL sel) {
    if (!obj || !sel || ![obj respondsToSelector:sel]) return nil;
    return ((id (*)(id, SEL))objc_msgSend)(obj, sel);
}

static void WAGRCallVoid0(id obj, SEL sel) {
    if (!obj || !sel || ![obj respondsToSelector:sel]) return;
    ((void (*)(id, SEL))objc_msgSend)(obj, sel);
}

static id WAGRUserContextFromSettings(id settingsVC) {
    if (!settingsVC) return nil;
    SEL userContextSel = NSSelectorFromString(@"userContext");
    id ctx = WAGRCallID0(settingsVC, userContextSel);
    if (ctx) return ctx;
    @try { ctx = [settingsVC valueForKey:@"_userContext"]; } @catch (__unused NSException *e) {}
    if (ctx) return ctx;

    // WASettingsNavigationController also owns _userContext.  Walk parents/nav.
    if ([settingsVC isKindOfClass:[UIViewController class]]) {
        UIViewController *vc = (UIViewController *)settingsVC;
        ctx = WAGRCallID0(vc.navigationController, userContextSel);
        if (ctx) return ctx;
        @try { ctx = [vc.navigationController valueForKey:@"_userContext"]; } @catch (__unused NSException *e) {}
    }
    return ctx;
}

static id WAGRDebugProviderFromContext(id userContext) {
    if (!userContext) return nil;
    SEL providerSel = NSSelectorFromString(@"debugMenuProvider");
    SEL resolveSel = NSSelectorFromString(@"resolveDebugMenuProviding");

    id provider = WAGRCallID0(userContext, providerSel);
    if (provider) return provider;

    // In the binary this selector is added to WAContext by WADebugMenuBase.
    // Some builds return the provider, others lazily populate debugMenuProvider.
    provider = WAGRCallID0(userContext, resolveSel);
    if (provider) return provider;

    provider = WAGRCallID0(userContext, providerSel);
    return provider;
}

static UIViewController *WAGRNearestViewController(UIResponder *r) {
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

static void WAGROpenNativeDeveloperMenuFromSettings(id settingsVC) {
    if (!settingsVC) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        gOpeningNativeDeveloper = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ gOpeningNativeDeveloper = NO; });

        id userContext = WAGRUserContextFromSettings(settingsVC);
        id provider = WAGRDebugProviderFromContext(userContext);

        SEL presentSel = NSSelectorFromString(@"presentDebugControllerIfNeeded");
        if (provider && [provider respondsToSelector:presentSel]) {
            WAGRCallVoid0(provider, presentSel);
            return;
        }

        SEL debugVCSel = NSSelectorFromString(@"debugViewController");
        id debugVC = provider ? WAGRCallID0(provider, debugVCSel) : nil;
        if (!debugVC && userContext) {
            Class dbg = NSClassFromString(@"WADebugViewController");
            SEL initSel = @selector(initWithUserContext:);
            if (dbg && [dbg instancesRespondToSelector:initSel]) {
                debugVC = ((id (*)(id, SEL, id))objc_msgSend)([dbg alloc], initSel, userContext);
            }
        }

        UIViewController *from = nil;
        if ([settingsVC isKindOfClass:[UIViewController class]]) from = (UIViewController *)settingsVC;
        if (!from && [settingsVC isKindOfClass:[UIResponder class]]) from = WAGRNearestViewController(settingsVC);

        if ([debugVC isKindOfClass:[UIViewController class]]) {
            UINavigationController *nav = from.navigationController;
            if (nav) [nav pushViewController:(UIViewController *)debugVC animated:YES];
            else [from presentViewController:(UIViewController *)debugVC animated:YES completion:nil];
        }
    });
}

@interface WAGRNativeDeveloperButtonTarget : NSObject
+ (instancetype)shared;
- (void)open:(id)sender;
@end

@implementation WAGRNativeDeveloperButtonTarget
+ (instancetype)shared {
    static WAGRNativeDeveloperButtonTarget *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [self new]; });
    return s;
}
- (void)open:(id)sender {
    UIViewController *vc = [sender isKindOfClass:[UIResponder class]] ? WAGRNearestViewController(sender) : nil;
    WAGROpenNativeDeveloperMenuFromSettings(vc);
}
@end

static UITableView *WAGRFindTableView(UIView *view) {
    if ([view isKindOfClass:[UITableView class]]) return (UITableView *)view;
    for (UIView *sub in view.subviews) {
        UITableView *hit = WAGRFindTableView(sub);
        if (hit) return hit;
    }
    return nil;
}

static void WAGRInjectNativeDeveloperFooter(id settingsVC) {
    if (![settingsVC isKindOfClass:[UIViewController class]]) return;
    UIViewController *vc = (UIViewController *)settingsVC;
    UITableView *table = nil;
    if ([settingsVC respondsToSelector:@selector(tableView)]) {
        table = ((UITableView *(*)(id, SEL))objc_msgSend)(settingsVC, @selector(tableView));
    }
    if (!table) table = WAGRFindTableView(vc.view);
    if (!table || objc_getAssociatedObject(table, kWAGRNativeDeveloperFooterKey)) return;

    UIView *oldFooter = table.tableFooterView;
    CGFloat oldHeight = oldFooter ? MAX(oldFooter.frame.size.height, 1.0) : 0.0;
    CGFloat rowHeight = 64.0;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, oldHeight + rowHeight + 12.0)];
    container.backgroundColor = UIColor.clearColor;

    if (oldFooter) {
        oldFooter.frame = CGRectMake(0, 0, table.bounds.size.width, oldHeight);
        [container addSubview:oldFooter];
    }

    UIControl *row = [[UIControl alloc] initWithFrame:CGRectMake(16, oldHeight + 8, table.bounds.size.width - 32, 54)];
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    row.layer.cornerRadius = 14.0;
    row.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    [row addTarget:[WAGRNativeDeveloperButtonTarget shared]
            action:@selector(open:)
  forControlEvents:UIControlEventTouchUpInside];

    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(16, 0, 42, 54)];
    icon.text = @"</>";
    icon.font = [UIFont boldSystemFontOfSize:16];
    icon.textColor = [UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:1.0];
    [row addSubview:icon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(60, 8, row.bounds.size.width - 90, 22)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.text = @"Developer";
    title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    title.textColor = UIColor.labelColor;
    [row addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(60, 29, row.bounds.size.width - 90, 18)];
    sub.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    sub.text = @"Menu nativo do WhatsApp";
    sub.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    sub.textColor = UIColor.secondaryLabelColor;
    [row addSubview:sub];

    UILabel *chev = [[UILabel alloc] initWithFrame:CGRectMake(row.bounds.size.width - 28, 0, 16, 54)];
    chev.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    chev.text = @"›";
    chev.font = [UIFont systemFontOfSize:30 weight:UIFontWeightRegular];
    chev.textColor = UIColor.tertiaryLabelColor;
    [row addSubview:chev];

    [container addSubview:row];
    table.tableFooterView = container;
    objc_setAssociatedObject(table, kWAGRNativeDeveloperFooterKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void hookSettingsViewDidAppear(id self, SEL _cmd, BOOL animated) {
    if (origSettingsViewDidAppear) origSettingsViewDidAppear(self, _cmd, animated);
    WAGRInjectNativeDeveloperFooter(self);
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
    return [NSString stringWithFormat:@"nativeDeveloperHooks=%@\nproviderAllowed=%@\nproviderShortcut=%@\nsettingsFooter=%@\npref=%@",
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
