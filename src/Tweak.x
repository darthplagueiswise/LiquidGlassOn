// Tweak.x — entry point. Zero Logos hooks here.
// Preserves the working long-press trigger, but removes the crashy viewDidAppear: hook.
// Crash reason from IPS: LiquidGlassOn.dylib recursively re-entered hookVDA/orig_vda
// during UIViewController appearance. We now attach the recognizer from UITableView
// didMoveToWindow instead of UIViewController viewDidAppear:.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Menu/WAGRSurfaceListVC.h"
#import "WAGramPrefix.h"

extern NSUInteger WAGRReinstallPersistedHooks(void);
extern void WAGRDogfoodEnsureHooksInstalled(void);
extern void WAGRLGPrefsDidChange(void);
extern NSString *WAGRHookRouterDiagnostic(void);

static const char *kLP = "wagr.lp.ok";
static BOOL (*orig_debugMenuAllowed)(id,SEL) = NULL;
static void (*orig_tableDidMoveToWindow)(id,SEL) = NULL;
static BOOL gSettingsHooked = NO;
static BOOL gTableHooked = NO;

static BOOL WAGRNativeDebugAllowed(void) {
    return WAGRPref(kWAGRDebugMenuNative) || WAGRPref(kWAGRInternalMaster) ||
           WAGRPref(kWAGREmployeeMaster) || WAGRPref(kWAGRDebugMode);
}

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
           [s containsString:@"desenvolvedor"];
}

static UIViewController *vcForView(UIView *v) {
    UIResponder *r = v;
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) return (UIViewController *)r;
        r = r.nextResponder;
    }
    return nil;
}

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

static void hookTableDidMoveToWindow(id self, SEL _cmd) {
    if (orig_tableDidMoveToWindow) orig_tableDidMoveToWindow(self, _cmd);

    if (![self isKindOfClass:UITableView.class]) return;
    UITableView *tv = (UITableView *)self;

    // Attach only when the table is on-screen. No reloadData here; this hook must be passive.
    if (tv.window) attachLP(tv);
}

static BOOL hookDebug(id self, SEL _cmd) {
    if (WAGRNativeDebugAllowed()) return YES;
    return orig_debugMenuAllowed ? orig_debugMenuAllowed(self, _cmd) : NO;
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

static BOOL classDeclaresInstanceMethod(Class cls, SEL sel) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;

    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == sel) {
            found = YES;
            break;
        }
    }

    if (methods) free(methods);
    return found;
}

static BOOL classDeclaresClassMethod(Class cls, SEL sel) {
    Class meta = object_getClass(cls);
    return meta ? classDeclaresInstanceMethod(meta, sel) : NO;
}

static void installSettingsHooks(void) {
    installLongPressTableHook();

    if (gSettingsHooked) return;

    NSArray *names = @[
        @"WASettingsViewController",
        @"WASettingsTableViewController",
        @"WANewSettingsViewController",
        @"WASettingsNavTableViewController",
        @"WASettingsNavigationController"
    ];

    SEL dbgSel = NSSelectorFromString(@"isDebugMenuAllowed");

    for (NSString *n in names) {
        Class cls = NSClassFromString(n);
        if (!cls) continue;

        if (!orig_debugMenuAllowed && classDeclaresInstanceMethod(cls, dbgSel)) {
            MSHookMessageEx(cls, dbgSel, (IMP)hookDebug, (IMP *)&orig_debugMenuAllowed);
        }

        if (!orig_debugMenuAllowed && classDeclaresClassMethod(cls, dbgSel)) {
            MSHookMessageEx(object_getClass(cls), dbgSel, (IMP)hookDebug, (IMP *)&orig_debugMenuAllowed);
        }

        if (orig_debugMenuAllowed) {
            gSettingsHooked = YES;
            break;
        }
    }
}

void WAGRDebugMenuEnsureHooksInstalled(void) {
    installSettingsHooks();
}

NSString *WAGRDebugMenuDiagnosticText(void) {
    return [NSString stringWithFormat:@"nativeDebug=%@\nsettingsHook=%@\ntableHook=%@\nrouter=%@",
            WAGRNativeDebugAllowed() ? @"ON" : @"OFF",
            gSettingsHooked ? @"YES" : @"NO",
            gTableHooked ? @"YES" : @"NO",
            WAGRHookRouterDiagnostic()];
}

static void startup(void) {
    @autoreleasepool {
        // Keep LiquidGlass state refresh, but keep menu activation passive.
        WAGRLGPrefsDidChange();

        // Safe longpress activation path. No UIViewController viewDidAppear: hook.
        installLongPressTableHook();

        // Native debug selector hook is cheap and does not reload UI.
        installSettingsHooks();

        // Do not install dynamic/runtime hooks at startup unless the user explicitly asked.
        if (WAGRPref(@"wagr.startupHooksEnabled")) {
            WAGRReinstallPersistedHooks();
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            installSettingsHooks();
            if (WAGRPref(@"wagr.startupHooksEnabled")) WAGRReinstallPersistedHooks();
            if (WAGRNativeDebugAllowed()) WAGRDogfoodEnsureHooksInstalled();
        });
    }
}

%ctor {
    startup();
}
