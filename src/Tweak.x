// Tweak.x
// Entry point for WAGram.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Menu/WAGramMenuVC.h"
#import "WAGramPrefix.h"

// New v7 hooks
extern void WAGRAuraGatingEnsureHooksInstalled(void);
extern void WAGRAuraGatingActivate(BOOL on);
extern void WAGRContextEnsureHooksInstalled(void);
extern void WAGRContextSetSimulateDebug(BOOL on);
extern BOOL WAGRContextIsSimulatingDebug(void);
extern NSString *WAGRContextDiagnosticText(void);

static const char *kWAGRLPInstalledKey = "wagr.longpress.installed";
static IMP orig_settingsVDAppear = NULL;
static BOOL (*orig_isDebugMenuAllowed)(id, SEL) = NULL;
static BOOL gWAGRSettingsHookInstalled = NO;
static BOOL gWAGRDebugGateHookInstalled = NO;

static BOOL WAGRNativeDebugMasterEffective(void) {
    BOOL explicitValue = NO;
    if (WAGRBoolOverrideForKey(kWAGRDebugMenuNative, &explicitValue)) return explicitValue;
    // Default ON without registerDefaults, so Flex/NSUserDefaults does not fill with synthetic 0/1 keys.
    return YES;
}

static BOOL WAGRNativeDebugAllowed(void) {
    return WAGRNativeDebugMasterEffective() || WAGRPref(kWAGRInternalMaster) || WAGRPref(kWAGREmployeeMaster) || WAGRPref(kWAGRDebugMode);
}

static void WAGRPresentMenu(UIViewController *from) {
    if (!from) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = from;
        while (presenter.presentedViewController) presenter = presenter.presentedViewController;
        WAGramMenuVC *menu = [[WAGramMenuVC alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:menu];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            sheet.prefersGrabberVisible = YES;
            sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
        }
        [presenter presentViewController:nav animated:YES completion:nil];
    });
}

static UITableView *WAGRFindTableView(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:UITableView.class]) return (UITableView *)root;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    NSUInteger idx = 0;
    while (idx < queue.count) {
        UIView *v = queue[idx++];
        if ([v isKindOfClass:UITableView.class]) return (UITableView *)v;
        for (UIView *sub in v.subviews) if (sub) [queue addObject:sub];
        if (queue.count > 2048) break;
    }
    return nil;
}

static NSString *WAGRCellSearchText(UITableViewCell *cell) {
    if (!cell) return @"";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    void (^add)(id) = ^(id obj) {
        if ([obj isKindOfClass:NSString.class] && [obj length]) [parts addObject:[obj lowercaseString]];
    };
    add(cell.reuseIdentifier);
    add(cell.accessibilityIdentifier);
    add(cell.accessibilityLabel);
    add(cell.textLabel.text);
    add(cell.detailTextLabel.text);
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithArray:cell.contentView.subviews ?: @[]];
    NSUInteger idx = 0;
    while (idx < queue.count && idx < 256) {
        UIView *v = queue[idx++];
        add(v.accessibilityIdentifier);
        add(v.accessibilityLabel);
        if ([v isKindOfClass:UILabel.class]) add(((UILabel *)v).text);
        if ([v isKindOfClass:UIButton.class]) add([((UIButton *)v) titleForState:UIControlStateNormal]);
        for (UIView *sub in v.subviews) if (sub) [queue addObject:sub];
    }
    return [parts componentsJoinedByString:@" "];
}

static BOOL WAGRCellLooksLikeHelpFeedbackText(NSString *s) {
    if (!s.length) return NO;
    if ([s containsString:@"settingshelp"]) return YES;
    if ([s containsString:@"settingsview_helpcell"]) return YES;
    if ([s containsString:@"help and feedback"]) return YES;
    if ([s containsString:@"help & feedback"]) return YES;
    if ([s containsString:@"ajuda e feedback"]) return YES;
    if ([s containsString:@"ajuda"] && [s containsString:@"feedback"]) return YES;
    if ([s containsString:@"help"] && ([s containsString:@"settings"] || [s containsString:@"feedback"])) return YES;
    return NO;
}

static BOOL WAGRCellLooksLikeNativeDeveloperText(NSString *s) {
    if (!s.length) return NO;
    if ([s containsString:@"settingsview_developercell"]) return YES;
    if ([s containsString:@"developer menu"]) return YES;
    if ([s containsString:@"developer"] && [s containsString:@"settings"]) return YES;
    if ([s containsString:@"desenvolvedor"] && [s containsString:@"ajustes"]) return YES;
    return NO;
}

static BOOL WAGRCellLooksLikeWAGramTrigger(UITableViewCell *cell, NSString **reasonOut) {
    NSString *s = WAGRCellSearchText(cell);
    if (WAGRCellLooksLikeHelpFeedbackText(s)) {
        if (reasonOut) *reasonOut = @"Help/Feedback";
        return YES;
    }
    if (WAGRCellLooksLikeNativeDeveloperText(s)) {
        if (reasonOut) *reasonOut = @"native Developer cell";
        return YES;
    }
    return NO;
}

static UIViewController *WAGRViewControllerForView(UIView *view) {
    UIResponder *r = view;
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

static void WAGRLongPressFired(UILongPressGestureRecognizer *gr) {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    UITableView *tv = (UITableView *)gr.view;
    if (![tv isKindOfClass:UITableView.class]) return;
    CGPoint pt = [gr locationInView:tv];
    NSIndexPath *ip = [tv indexPathForRowAtPoint:pt];
    if (!ip) return;
    UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
    NSString *reason = nil;
    if (!WAGRCellLooksLikeWAGramTrigger(cell, &reason)) return;
    UIViewController *vc = WAGRViewControllerForView(tv);
    if (!vc) return;
    NSLog(@"[WAGram] long-press on %@ — presenting WAGram menu", reason ?: @"trigger cell");
    WAGRPresentMenu(vc);
}

@interface WAGRGestureTarget : NSObject
+ (instancetype)shared;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr;
@end

@implementation WAGRGestureTarget
+ (instancetype)shared { static WAGRGestureTarget *s; static dispatch_once_t once; dispatch_once(&once, ^{ s = [self new]; }); return s; }
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr { WAGRLongPressFired(gr); }
@end

static void WAGRAttachLongPress(UITableView *tv) {
    if (!tv) return;
    if ([objc_getAssociatedObject(tv, kWAGRLPInstalledKey) boolValue]) return;
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:[WAGRGestureTarget shared] action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.65;
    lp.cancelsTouchesInView = NO;
    lp.delaysTouchesBegan = NO;
    lp.delaysTouchesEnded = NO;
    objc_setAssociatedObject(tv, kWAGRLPInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tv addGestureRecognizer:lp];
    NSLog(@"[WAGram] Settings long-press attached to %@", NSStringFromClass(tv.class));
}

static void hook_settingsVDAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_settingsVDAppear) ((void (*)(id, SEL, BOOL))orig_settingsVDAppear)(self, _cmd, animated);
    if (![self isKindOfClass:UIViewController.class]) return;
    UITableView *tv = WAGRFindTableView(((UIViewController *)self).view);
    WAGRAttachLongPress(tv);
    if (tv && WAGRNativeDebugAllowed()) [tv reloadData];
}

static BOOL hook_isDebugMenuAllowed(id self, SEL _cmd) {
    if (WAGRNativeDebugAllowed()) return YES;
    return orig_isDebugMenuAllowed ? orig_isDebugMenuAllowed(self, _cmd) : NO;
}

static void WAGRHookViewDidAppearOnClass(Class cls) {
    if (!cls || gWAGRSettingsHookInstalled) return;
    SEL sel = @selector(viewDidAppear:);
    if (!class_getInstanceMethod(cls, sel)) return;
    MSHookMessageEx(cls, sel, (IMP)hook_settingsVDAppear, &orig_settingsVDAppear);
    gWAGRSettingsHookInstalled = YES;
    NSLog(@"[WAGram] hooked safe viewDidAppear: on %@", NSStringFromClass(cls));
}

static void WAGRHookDebugGateOnClass(Class cls) {
    if (!cls || gWAGRDebugGateHookInstalled) return;
    SEL sel = NSSelectorFromString(@"isDebugMenuAllowed");
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        MSHookMessageEx(cls, sel, (IMP)hook_isDebugMenuAllowed, (IMP *)&orig_isDebugMenuAllowed);
        gWAGRDebugGateHookInstalled = YES;
        NSLog(@"[WAGram] hooked -isDebugMenuAllowed on %@", NSStringFromClass(cls));
        return;
    }
    Class meta = object_getClass(cls);
    Method cm = class_getClassMethod(cls, sel);
    if (meta && cm) {
        MSHookMessageEx(meta, sel, (IMP)hook_isDebugMenuAllowed, (IMP *)&orig_isDebugMenuAllowed);
        gWAGRDebugGateHookInstalled = YES;
        NSLog(@"[WAGram] hooked +isDebugMenuAllowed on %@", NSStringFromClass(cls));
    }
}

static void WAGRInstallSettingsHooks(void) {
    NSArray<NSString *> *candidates = @[@"WASettingsViewController", @"WASettingsTableViewController", @"WANewSettingsViewController", @"WASettingsNavTableViewController"];
    for (NSString *name in candidates) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        WAGRHookDebugGateOnClass(cls);
        WAGRHookViewDidAppearOnClass(cls);
    }
    if (!gWAGRSettingsHookInstalled || !gWAGRDebugGateHookInstalled) {
        unsigned int count = 0;
        Class *all = objc_copyClassList(&count);
        if (all) {
            SEL debugSel = NSSelectorFromString(@"isDebugMenuAllowed");
            for (unsigned int i = 0; i < count; i++) {
                Class cls = all[i];
                NSString *name = NSStringFromClass(cls);
                if (![name containsString:@"Settings"]) continue;
                if (class_getInstanceMethod(cls, debugSel) || class_getClassMethod(cls, debugSel)) {
                    WAGRHookDebugGateOnClass(cls);
                    WAGRHookViewDidAppearOnClass(cls);
                }
                if (gWAGRSettingsHookInstalled && gWAGRDebugGateHookInstalled) break;
            }
            free(all);
        }
    }
}

void WAGRDebugMenuEnsureHooksInstalled(void) {
    WAGRInstallSettingsHooks();
}

NSString *WAGRDebugMenuDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"nativeDebug=%@\ninternal=%@\ndogfood=%@\nhooks: settings=%@ debugGate=%@\nlocation: WhatsApp Settings → Developer\nWAGram: long-press Developer or Help/Feedback",
        WAGRNativeDebugMasterEffective() ? @"ON" : @"OFF",
        WAGRPref(kWAGRInternalMaster) ? @"ON" : @"OFF",
        WAGRPref(kWAGREmployeeMaster) ? @"ON" : @"OFF",
        gWAGRSettingsHookInstalled ? @"YES" : @"NO",
        gWAGRDebugGateHookInstalled ? @"YES" : @"NO"];
}

%ctor {
    @autoreleasepool {
        NSLog(@"[WAGram] loading — bundle=%@", [[NSBundle mainBundle] bundleIdentifier]);
        // Do not call registerDefaults here. Registered defaults appear in Flex/NSUserDefaults
        // as synthetic 0/1 rows and created the exact pollution this branch is fixing.
        // Absent key = system/default everywhere; explicit keys are written only by user action.
        WAGRInstallSettingsHooks();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRInstallSettingsHooks(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRInstallSettingsHooks();
        });
    }
}
