// Tweak.x
// ─────────────────────────────────────────────────────────────────────────────
// Entry point for WAGram.
//
// Trigger: LONG-PRESS on the "Help" / "Help and Feedback" row in WhatsApp
//          Settings, identical to how RyukGram-Fork/dev2 works on IG
//          (long-press in Settings > Help and Support).
//
// How it works:
//   • Hook WASettingsViewController (or whatever Settings table VC WA uses)
//   • In -viewDidLoad, attach a UILongPressGestureRecognizer
//   • On long-press fired: hit-test the cell at the touch point, check its
//     reuse identifier or text for "help" / "settingsHelp", then present
//     WAGramMenuVC wrapped in a UINavigationController.
//
// WA uses a VC whose class name contains "SettingsTableViewController" or
// "WASettingsViewController". We hook a few candidates at load time and
// use the first one that responds to the view lifecycle.
// ─────────────────────────────────────────────────────────────────────────────

#import "WAGramPrefix.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Menu/WAGramMenuVC.h"
#import "WAUtils.h"

// ── Constant ──────────────────────────────────────────────────────────────────
static const char *kWAGRLPInstalledKey = "wagr.longpress.installed";

// ── Present WAGram menu ───────────────────────────────────────────────────────
static void WAGRPresentMenu(UIViewController *from) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WAGramMenuVC *menu = [[WAGramMenuVC alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:menu];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            sheet.prefersGrabberVisible = YES;
            sheet.detents = @[UISheetPresentationControllerDetent.largeDetent];
        }
        [from presentViewController:nav animated:YES completion:nil];
    });
}

// ── Gesture handler ───────────────────────────────────────────────────────────
static void WAGRLongPressFired(UILongPressGestureRecognizer *gr) {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    UITableView *tv = (UITableView *)gr.view;
    if (![tv isKindOfClass:UITableView.class]) return;

    CGPoint pt = [gr locationInView:tv];
    NSIndexPath *ip = [tv indexPathForRowAtPoint:pt];
    if (!ip) return;

    UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
    NSString *text = [cell.textLabel.text lowercaseString] ?: @"";
    NSString *reuseId = [cell.reuseIdentifier lowercaseString] ?: @"";

    // Match "help" cells — identifiers validated from WhatsApp binary:
    //   settingsHelp  (strings hit in WhatsApp executable)
    BOOL isHelpCell = [reuseId containsString:@"settingshelp"] ||
                      [reuseId containsString:@"help"] ||
                      [text    containsString:@"help"];
    if (!isHelpCell) return;

    UIViewController *vc = (UIViewController *)tv.nextResponder;
    while (vc && ![vc isKindOfClass:UIViewController.class])
        vc = (UIViewController *)[vc nextResponder];
    if (!vc) return;

    NSLog(@"[WAGram] long-press on help cell — presenting menu");
    WAGRPresentMenu(vc);
}

// ── WAGRGestureTarget — minimal target object ─────────────────────────────────
@interface WAGRGestureTarget : NSObject
+ (instancetype)shared;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr;
@end
@implementation WAGRGestureTarget
+ (instancetype)shared { static WAGRGestureTarget *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [self new]; }); return s; }
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr { WAGRLongPressFired(gr); }
@end

// ── Attach recognizer to a table view ────────────────────────────────────────
static void WAGRAttachLongPress(UITableView *tv) {
    if (!tv) return;
    if ([objc_getAssociatedObject(tv, kWAGRLPInstalledKey) boolValue]) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[WAGRGestureTarget shared] action:@selector(handleLongPress:)];
    lp.minimumPressDuration = 0.6;
    objc_setAssociatedObject(tv, kWAGRLPInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tv addGestureRecognizer:lp];
    NSLog(@"[WAGram] LongPressGestureRecognizer attached to %@", NSStringFromClass([tv class]));
}

// ── Hook candidates ───────────────────────────────────────────────────────────
// WA's Settings VC class names vary across builds. We hook -viewDidAppear: on
// any class whose name contains "Settings" and is a UITableViewController, then
// attach the long-press to its tableView.

static IMP orig_settingsVDAppear = NULL;

static void hook_settingsVDAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_settingsVDAppear)
        ((void (*)(id, SEL, BOOL))orig_settingsVDAppear)(self, _cmd, animated);
    if ([self isKindOfClass:UITableViewController.class]) {
        UITableView *tv = ((UITableViewController *)self).tableView;
        WAGRAttachLongPress(tv);
    }
}

static void WAGRInstallSettingsHook(void) {
    NSArray<NSString *> *candidates = @[
        @"WASettingsViewController",
        @"WASettingsTableViewController",
        @"WANewSettingsViewController",
        @"WASettingsNavTableViewController",
    ];
    for (NSString *name in candidates) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        SEL sel = @selector(viewDidAppear:);
        if (!class_getInstanceMethod(cls, sel)) continue;
        MSHookMessageEx(cls, sel, (IMP)hook_settingsVDAppear, &orig_settingsVDAppear);
        NSLog(@"[WAGram] hooked viewDidAppear: on %@", name);
        return; // hook only the first found class
    }

    // Broad fallback: scan for UITableViewController subclasses with "Settings" in name
    unsigned int count = 0;
    Class *all = objc_copyClassList(&count);
    if (!all) return;
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(all[i]);
        if (![name containsString:@"Settings"]) continue;
        if (![all[i] isSubclassOfClass:UITableViewController.class]) continue;
        SEL sel = @selector(viewDidAppear:);
        if (!class_getInstanceMethod(all[i], sel)) continue;
        MSHookMessageEx(all[i], sel, (IMP)hook_settingsVDAppear, &orig_settingsVDAppear);
        NSLog(@"[WAGram] broad fallback: hooked viewDidAppear: on %@", name);
        free(all);
        return;
    }
    free(all);
}

// ── %ctor ─────────────────────────────────────────────────────────────────────
%ctor {
    @autoreleasepool {
        NSLog(@"[WAGram] loading — bundle=%@",
              [[NSBundle mainBundle] bundleIdentifier]);

        // Register defaults (all OFF)
        WARegisterDefaults();
        NSDictionary *defs = @{
            kWAGRKeychain          : @NO,
            kWAGRKeychainObserver  : @NO,
            kWAGREmployeeMaster    : @NO,
            kWAGRABPropsObserver   : @NO,
            kWAGRLiquidGlassMaster : @NO,
            kWAGRLiquidGlassUserDefaults : @YES,
            kWAGRLiquidGlassMethodHooks  : @YES,
            kWAGRLG_enabled        : @NO,
            kWAGRLG_launched       : @NO,
            kWAGRLG_m1             : @NO,
            kWAGRLG_m1_5           : @NO,
            kWAGRLG_m1_5_context_menu            : @NO,
            kWAGRLG_chat_top_bar_m2              : @NO,
            kWAGRLG_new_chatbar_ux               : @NO,
            kWAGRLG_larger_composer              : @NO,
            kWAGRLG_reduce_transparency          : @NO,
            kWAGRLG_workaround_attachment_tray   : @NO,
            kWAGRLG_workaround_hides_bottombar   : @NO,
            kWAGRLG_workaround_topbar_appearance : @NO,
            kWAGRDebugMode         : @NO,
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];

        // Install Settings hook
        WAGRInstallSettingsHook();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WAGRInstallSettingsHook(); });
    }
}
