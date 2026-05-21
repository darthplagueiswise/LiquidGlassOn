// Tweak.x — entry point. Zero Logos hooks here.
// ─────────────────────────────────────────────────────────────────────────────
// What this file owns now (post-refactor):
//
//   • The long-press gesture recognizer attached to every UITableView, which
//     is the activation path for the WATweaks (formerly WAGram) menu when
//     the user presses-and-holds the Help / Developer / WATweaks cells in
//     Settings. This must stay here because the wagr_validate_sources.py
//     script enforces the presence of UILongPressGestureRecognizer, WAGRLP,
//     attachLP, isTrigger and WAGRPresent tokens in this file.
//
//   • The UITableView -didMoveToWindow swizzle, which is the single hook
//     surface used to:
//       (a) attach the long-press recognizer (existing behavior);
//       (b) ask WAGRWATweaksSettingsRow.xm whether to attach the native
//           "WATweaks" footer row to this table (new behavior).
//
//   • Diagnostic and ensure-installed shim functions that delegate to the
//     dedicated hook files. Tweak.x is the orchestrator; specific hooks
//     live in src/Hooks/.
//
// Crash-history note: the previous viewDidAppear: swizzle on UIViewController
// caused recursive reentry into a global hook. That code path was removed in
// favor of the table-centric didMoveToWindow path you see below. Do not
// reintroduce a base-class viewDidAppear: hook here.
// ─────────────────────────────────────────────────────────────────────────────

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Menu/WAGRSurfaceListVC.h"
#import "WAGramPrefix.h"

// ── External entry points provided by dedicated hook files ──────────────────
extern NSUInteger WAGRReinstallPersistedHooks(void);
extern void       WAGRDogfoodEnsureHooksInstalled(void);
extern void       WAGRLGPrefsDidChange(void);
extern NSString  *WAGRHookRouterDiagnostic(void);

// Native developer menu surface — moved out of Tweak.x into a dedicated file.
extern void       WAGRNativeDevMenuEnsureHooksInstalled(void);
extern NSString  *WAGRNativeDevMenuDiagnosticText(void);

// "WATweaks" native settings row — the new entry below the Developer row.
extern void       WAGRMaybeAttachWATweaksFooter(UITableView *tv);
extern NSString  *WAGRWATweaksRowDiagnosticText(void);

// ── Long-press setup ─────────────────────────────────────────────────────────
// kLP is the associated-object key used to mark a UITableView as "long-press
// already attached", so we never double-attach when -didMoveToWindow fires
// repeatedly during the table's lifetime.
static const char *kLP = "wagr.lp.ok";

static void (*orig_tableDidMoveToWindow)(id, SEL) = NULL;
static BOOL gTableHooked = NO;

// Master gate: any of these prefs being ON is enough to unlock all the
// "native developer menu" gating behavior throughout the tweak. The list is
// historical — older builds used different keys — and we OR them so users
// who already had any one of them set don't need to reconfigure.
static BOOL WAGRNativeDebugAllowed(void) {
    return WAGRPref(kWAGRDebugMenuNative) || WAGRPref(kWAGRInternalMaster) ||
           WAGRPref(kWAGREmployeeMaster)  || WAGRPref(kWAGRDebugMode);
}

// ── Modal presentation of the WATweaks menu ──────────────────────────────────
// Used by the long-press path. The settings-row path uses its own internal
// presenter in WAGRWATweaksSettingsRow.xm; both end up presenting the same
// WAGRSurfaceListVC.
static void WAGRPresent(UIViewController *from) {
    if (!from) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *p = from;
        while (p.presentedViewController) p = p.presentedViewController;

        WAGRSurfaceListVC *menu = [[WAGRSurfaceListVC alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:menu];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;

        if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sh = nav.sheetPresentationController;
            sh.prefersGrabberVisible = YES;
            sh.detents = @[UISheetPresentationControllerDetent.largeDetent];
        }

        [p presentViewController:nav animated:YES completion:nil];
    });
}

// ── Long-press trigger detection ────────────────────────────────────────────
// We accept several cell texts as triggers: the user-facing "Ajuda" / "Help"
// or "Developer" cells, plus the new "WATweaks" cell. Lowercase comparison
// avoids locale surprises.
static NSString *cellText(UITableViewCell *c) {
    NSMutableArray *parts = [NSMutableArray array];

    void (^add)(id) = ^(id o) {
        if ([o isKindOfClass:NSString.class] && [o length]) {
            [parts addObject:[o lowercaseString]];
        }
    };

    add(c.reuseIdentifier);
    add(c.accessibilityIdentifier);
    add(c.accessibilityLabel);
    add(c.textLabel.text);
    add(c.detailTextLabel.text);

    return [parts componentsJoinedByString:@" "];
}

static BOOL isTrigger(UITableViewCell *c) {
    NSString *s = cellText(c);
    return [s containsString:@"help"] ||
           [s containsString:@"ajuda"] ||
           [s containsString:@"developer"] ||
           [s containsString:@"desenvolvedor"] ||
           [s containsString:@"watweaks"];
}

static UIViewController *vcForView(UIView *v) {
    UIResponder *r = v;
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

// ── Long-press target object ────────────────────────────────────────────────
@interface WAGRLP : NSObject
+ (instancetype)shared;
- (void)lp:(UILongPressGestureRecognizer *)g;
@end

@implementation WAGRLP
+ (instancetype)shared {
    static WAGRLP *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [self new];
    });
    return s;
}

- (void)lp:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;

    UITableView *tv = (UITableView *)g.view;
    if (![tv isKindOfClass:UITableView.class]) return;

    NSIndexPath *ip = [tv indexPathForRowAtPoint:[g locationInView:tv]];
    if (!ip) return;

    UITableViewCell *c = [tv cellForRowAtIndexPath:ip];
    if (!isTrigger(c)) return;

    WAGRPresent(vcForView(tv));
}
@end

// ── Long-press attachment ───────────────────────────────────────────────────
// 0.65s press duration matches the iOS system "long press" feel. We set
// cancelsTouchesInView to NO so normal taps on the cell still work.
static void attachLP(UITableView *tv) {
    if (!tv) return;
    if ([objc_getAssociatedObject(tv, kLP) boolValue]) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[WAGRLP shared]
                action:@selector(lp:)];

    lp.minimumPressDuration = 0.65;
    lp.cancelsTouchesInView = NO;

    objc_setAssociatedObject(tv, kLP, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [tv addGestureRecognizer:lp];
}

// ── The single hook surface ──────────────────────────────────────────────────
// Every UITableView calls -didMoveToWindow when it lands on screen (and when
// it's removed). We use that one moment to:
//   1) attach the long-press recognizer (so the WATweaks menu opens on long
//      press of Help/Developer/WATweaks cells), and
//   2) ask the settings-row helper whether to attach the native footer that
//      shows the WATweaks entry below the Developer row.
//
// Both operations are idempotent (each guarded by its own associated-object
// flag), so repeated -didMoveToWindow firings cost only a few pointer reads.
static void hookTableDidMoveToWindow(id self, SEL _cmd) {
    if (orig_tableDidMoveToWindow) orig_tableDidMoveToWindow(self, _cmd);

    if (![self isKindOfClass:UITableView.class]) return;
    UITableView *tv = (UITableView *)self;

    if (tv.window) {
        attachLP(tv);
        WAGRMaybeAttachWATweaksFooter(tv);
    }
}

static void installLongPressTableHook(void) {
    if (gTableHooked) return;

    Class cls = UITableView.class;
    SEL sel = @selector(didMoveToWindow);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    MSHookMessageEx(cls, sel, (IMP)hookTableDidMoveToWindow, (IMP *)&orig_tableDidMoveToWindow);
    gTableHooked = (orig_tableDidMoveToWindow != NULL);
}

// ── Diagnostic shim ──────────────────────────────────────────────────────────
// Tweak.x doesn't own any gating hooks anymore, so its diagnostic just
// summarizes the table-level state and forwards to the specialized files.
void WAGRDebugMenuEnsureHooksInstalled(void) {
    // Convenience: ensure both the dev-menu gates and the WATweaks row hook
    // are in place. Each ensure-call is idempotent so this is safe to call
    // multiple times (e.g. when the menu is opened).
    installLongPressTableHook();
    WAGRNativeDevMenuEnsureHooksInstalled();
}

NSString *WAGRDebugMenuDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"nativeDebug=%@\ntableHook=%@\n\n[NativeDevMenu]\n%@\n\n[WATweaksRow]\n%@\n\n[Router]\n%@",
        WAGRNativeDebugAllowed() ? @"ON" : @"OFF",
        gTableHooked ? @"YES" : @"NO",
        WAGRNativeDevMenuDiagnosticText() ?: @"n/a",
        WAGRWATweaksRowDiagnosticText()   ?: @"n/a",
        WAGRHookRouterDiagnostic()        ?: @"n/a"];
}

// ── Startup ──────────────────────────────────────────────────────────────────
// Stays intentionally light. Heavy initializations live inside the dedicated
// hook files' own __attribute__((constructor)) blocks, which run after this
// %ctor in dyld order. The work here is the part Tweak.x specifically owns:
// the table hook, plus a delayed nudge so any late-loaded Swift classes get
// picked up.
static void startup(void) {
    @autoreleasepool {
        WAGRLGPrefsDidChange();
        installLongPressTableHook();
        WAGRNativeDevMenuEnsureHooksInstalled();

        if (WAGRPref(@"wagr.startupHooksEnabled")) {
            WAGRReinstallPersistedHooks();
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WAGRNativeDevMenuEnsureHooksInstalled();
            if (WAGRPref(@"wagr.startupHooksEnabled")) WAGRReinstallPersistedHooks();
            if (WAGRNativeDebugAllowed()) WAGRDogfoodEnsureHooksInstalled();
        });
    }
}

%ctor {
    startup();
}
