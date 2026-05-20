// WAGRNativeDeveloperRouter.xm
// Native WhatsApp Settings integration:
// - keep the real Developer gates hookable so WhatsApp can show its own Developer row.
// - inject WATweaks as a best-effort native WATableRow in the settings table.
// - if the private row API changes, fall back to a WhatsApp-sized table footer button so the entry never disappears.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../Menu/WAGRSurfaceListVC.h"

static BOOL (*origProviderDebugAllowed)(id, SEL) = NULL;
static BOOL (*origProviderShortcutAllowed)(id, SEL) = NULL;

static void (*origSetUp0)(id, SEL) = NULL;
static void (*origSetUp1)(id, SEL) = NULL;
static void (*origSetUp2)(id, SEL) = NULL;
static void (*origAppear0)(id, SEL, BOOL) = NULL;
static void (*origAppear1)(id, SEL, BOOL) = NULL;
static void (*origAppear2)(id, SEL, BOOL) = NULL;

static BOOL gNativeDevHooksInstalled = NO;
static BOOL gSettingsAnyHookInstalled = NO;
static const void *kWATweaksNativeRowInjectedKey = &kWATweaksNativeRowInjectedKey;
static const void *kWATweaksFooterInjectedKey = &kWATweaksFooterInjectedKey;
static const void *kWATweaksHandlerKey = &kWATweaksHandlerKey;

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

static UITableView *WAGRSettingsTableView(id settingsVC) {
    UITableView *table = nil;
    if ([settingsVC respondsToSelector:@selector(tableView)]) {
        table = ((UITableView *(*)(id, SEL))objc_msgSend)(settingsVC, @selector(tableView));
    }
    if (!table && [settingsVC isKindOfClass:UIViewController.class]) {
        table = WAGRFindTableView(((UIViewController *)settingsVC).view);
    }
    return table;
}

static void WAGRConfigureNativeWATweaksCell(UITableViewCell *cell) {
    if (!cell) return;
    cell.textLabel.text = @"WATweaks";
    cell.textLabel.textColor = UIColor.labelColor;
    cell.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
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

static void WAGRCallVoidSetterBool(id obj, NSString *selName, BOOL value) {
    SEL sel = NSSelectorFromString(selName);
    if (obj && [obj respondsToSelector:sel]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(obj, sel, value);
    }
}

static BOOL WAGRAttachHandlerToRow(id row, id settingsVC) {
    if (!row) return NO;
    WAGRCallVoidSetterBool(row, @"setEnabled:", YES);
    WAGRCallVoidSetterBool(row, @"setHidden:", NO);
    WAGRCallVoidSetterBool(row, @"setSelectable:", YES);

    if (![row respondsToSelector:NSSelectorFromString(@"setHandler:")]) return NO;
    id block = [^{ WAGRPresentWATweaksMenu(settingsVC); } copy];
    objc_setAssociatedObject(row, kWATweaksHandlerKey, block, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(row, NSSelectorFromString(@"setHandler:"), block);
    return YES;
}

static id WAGRCreateWATweaksRow(id section, id settingsVC) {
    if (!section) return nil;
    SEL addDefault = NSSelectorFromString(@"addDefaultTableRow");
    SEL addStyle = NSSelectorFromString(@"addTableRowWithCellStyle:");
    id row = nil;
    if ([section respondsToSelector:addDefault]) {
        row = ((id (*)(id, SEL))objc_msgSend)(section, addDefault);
    } else if ([section respondsToSelector:addStyle]) {
        row = ((id (*)(id, SEL, NSInteger))objc_msgSend)(section, addStyle, UITableViewCellStyleDefault);
    }
    if (!row) return nil;

    if ([row respondsToSelector:NSSelectorFromString(@"cell")]) {
        UITableViewCell *cell = ((UITableViewCell *(*)(id, SEL))objc_msgSend)(row, NSSelectorFromString(@"cell"));
        WAGRConfigureNativeWATweaksCell(cell);
    }
    WAGRAttachHandlerToRow(row, settingsVC);
    return row;
}

static id WAGRValueForIvarName(id obj, NSString *ivarName) {
    if (!obj || !ivarName.length) return nil;
    @try { return [obj valueForKey:ivarName]; } @catch (__unused NSException *e) { return nil; }
}

static BOOL WAGRInjectIntoExistingSettingsSection(id settingsVC) {
    if (objc_getAssociatedObject(settingsVC, kWATweaksNativeRowInjectedKey)) return YES;

    id section = WAGRValueForIvarName(settingsVC, @"_sectionSettings");
    if (!section) section = WAGRValueForIvarName(settingsVC, @"sectionSettings");
    if (!section) return NO;

    id row = WAGRCreateWATweaksRow(section, settingsVC);
    if (!row) return NO;

    objc_setAssociatedObject(settingsVC, kWATweaksNativeRowInjectedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [WAGRSettingsTableView(settingsVC) reloadData];
    return YES;
}

static BOOL WAGRInjectAsNativeSection(id settingsVC) {
    if (objc_getAssociatedObject(settingsVC, kWATweaksNativeRowInjectedKey)) return YES;

    Class sectionClass = NSClassFromString(@"WATableSection");
    if (!sectionClass) return NO;

    id section = [[sectionClass alloc] init];
    if (!section) return NO;
    id row = WAGRCreateWATweaksRow(section, settingsVC);
    if (!row) return NO;

    BOOL added = NO;
    SEL addSection = NSSelectorFromString(@"addSection:");
    if ([settingsVC respondsToSelector:addSection]) {
        ((void (*)(id, SEL, id))objc_msgSend)(settingsVC, addSection, section);
        added = YES;
    }
    if (!added) return NO;

    objc_setAssociatedObject(settingsVC, kWATweaksNativeRowInjectedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [WAGRSettingsTableView(settingsVC) reloadData];
    return YES;
}

@interface WATweaksFooterButtonTarget : NSObject
+ (instancetype)shared;
- (void)open:(id)sender;
@end
@implementation WATweaksFooterButtonTarget
+ (instancetype)shared { static id s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [self new]; }); return s; }
- (void)open:(id)sender { WAGRPresentWATweaksMenu(sender); }
@end

static BOOL WAGRInjectFooterFallback(id settingsVC) {
    UITableView *table = WAGRSettingsTableView(settingsVC);
    if (!table || objc_getAssociatedObject(table, kWATweaksFooterInjectedKey)) return NO;

    UIView *oldFooter = table.tableFooterView;
    CGFloat oldHeight = oldFooter ? MAX(oldFooter.frame.size.height, 1.0) : 0.0;
    CGFloat rowHeight = 54.0;
    CGFloat width = table.bounds.size.width ?: UIScreen.mainScreen.bounds.size.width;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, oldHeight + rowHeight + 18.0)];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    container.backgroundColor = UIColor.clearColor;
    if (oldFooter) {
        oldFooter.frame = CGRectMake(0, 0, width, oldHeight);
        [container addSubview:oldFooter];
    }

    UIControl *row = [[UIControl alloc] initWithFrame:CGRectMake(16, oldHeight + 8.0, width - 32.0, rowHeight)];
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    row.layer.cornerRadius = 12.0;
    row.clipsToBounds = YES;
    row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    [row addTarget:[WATweaksFooterButtonTarget shared] action:@selector(open:) forControlEvents:UIControlEventTouchUpInside];

    UILabel *icon = [[UILabel alloc] initWithFrame:CGRectMake(18, 0, 38, rowHeight)];
    icon.text = @"</>";
    icon.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    icon.textColor = UIColor.systemBlueColor;
    icon.textAlignment = NSTextAlignmentCenter;
    [row addSubview:icon];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(72, 0, row.bounds.size.width - 110, rowHeight)];
    title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    title.text = @"WATweaks";
    title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    title.textColor = UIColor.labelColor;
    [row addSubview:title];

    UILabel *chev = [[UILabel alloc] initWithFrame:CGRectMake(row.bounds.size.width - 32, 0, 18, rowHeight)];
    chev.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    chev.text = @"›";
    chev.font = [UIFont systemFontOfSize:28 weight:UIFontWeightRegular];
    chev.textColor = UIColor.tertiaryLabelColor;
    chev.textAlignment = NSTextAlignmentCenter;
    [row addSubview:chev];

    [container addSubview:row];
    table.tableFooterView = container;
    objc_setAssociatedObject(table, kWATweaksFooterInjectedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

static BOOL WAGRInjectWATweaksSettingsEntry(id settingsVC) {
    if (!settingsVC) return NO;
    if (WAGRInjectIntoExistingSettingsSection(settingsVC)) return YES;
    if (WAGRInjectAsNativeSection(settingsVC)) return YES;
    return WAGRInjectFooterFallback(settingsVC);
}

static void hookSetUp0(id self, SEL _cmd) { if (origSetUp0) origSetUp0(self, _cmd); WAGRInjectWATweaksSettingsEntry(self); }
static void hookSetUp1(id self, SEL _cmd) { if (origSetUp1) origSetUp1(self, _cmd); WAGRInjectWATweaksSettingsEntry(self); }
static void hookSetUp2(id self, SEL _cmd) { if (origSetUp2) origSetUp2(self, _cmd); WAGRInjectWATweaksSettingsEntry(self); }
static void hookAppear0(id self, SEL _cmd, BOOL animated) { if (origAppear0) origAppear0(self, _cmd, animated); WAGRInjectWATweaksSettingsEntry(self); }
static void hookAppear1(id self, SEL _cmd, BOOL animated) { if (origAppear1) origAppear1(self, _cmd, animated); WAGRInjectWATweaksSettingsEntry(self); }
static void hookAppear2(id self, SEL _cmd, BOOL animated) { if (origAppear2) origAppear2(self, _cmd, animated); WAGRInjectWATweaksSettingsEntry(self); }

static void WAGRHookSettingsClass(const char *name, IMP setUpHook, IMP *setUpOrig, IMP appearHook, IMP *appearOrig) {
    Class cls = NSClassFromString(@(name));
    if (!cls) return;
    SEL setup = NSSelectorFromString(@"setUpTableView");
    Method mSetup = class_getInstanceMethod(cls, setup);
    if (mSetup && setUpOrig && !*setUpOrig) {
        MSHookMessageEx(cls, setup, setUpHook, setUpOrig);
        if (*setUpOrig) gSettingsAnyHookInstalled = YES;
    }
    SEL appear = @selector(viewDidAppear:);
    Method mAppear = class_getInstanceMethod(cls, appear);
    if (mAppear && appearOrig && !*appearOrig) {
        MSHookMessageEx(cls, appear, appearHook, appearOrig);
        if (*appearOrig) gSettingsAnyHookInstalled = YES;
    }
}

extern "C" void WAGRNativeDeveloperEnsureHooksInstalled(void) {
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

    WAGRHookSettingsClass("WASettingsViewController", (IMP)hookSetUp0, (IMP *)&origSetUp0, (IMP)hookAppear0, (IMP *)&origAppear0);
    WAGRHookSettingsClass("WANewSettingsViewController", (IMP)hookSetUp1, (IMP *)&origSetUp1, (IMP)hookAppear1, (IMP *)&origAppear1);
    WAGRHookSettingsClass("WASettingsTableViewController", (IMP)hookSetUp2, (IMP *)&origSetUp2, (IMP)hookAppear2, (IMP *)&origAppear2);

    gNativeDevHooksInstalled = (origProviderDebugAllowed || origProviderShortcutAllowed || gSettingsAnyHookInstalled);
}

extern "C" NSString *WAGRNativeDeveloperDiagnostic(void) {
    return [NSString stringWithFormat:
            @"nativeDeveloperHooks=%@\n"
             "providerAllowed=%@\n"
             "providerShortcut=%@\n"
             "watweaksRowHooks=%@\n"
             "settingsClasses=setUp:%@/%@/%@ appear:%@/%@/%@\n"
             "pref=%@",
            gNativeDevHooksInstalled ? @"YES" : @"NO",
            origProviderDebugAllowed ? @"YES" : @"NO",
            origProviderShortcutAllowed ? @"YES" : @"NO",
            gSettingsAnyHookInstalled ? @"YES" : @"NO",
            origSetUp0 ? @"WA" : @"-", origSetUp1 ? @"New" : @"-", origSetUp2 ? @"Table" : @"-",
            origAppear0 ? @"WA" : @"-", origAppear1 ? @"New" : @"-", origAppear2 ? @"Table" : @"-",
            WAGRNativeDeveloperEnabled() ? @"ON" : @"OFF"];
}

__attribute__((constructor))
static void WAGRNativeDeveloperCtor(void) {
    @autoreleasepool {
        WATweaksMigrateLegacyDefaults();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRNativeDeveloperEnsureHooksInstalled(); });
    }
}
