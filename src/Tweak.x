// Tweak.x — stable entry point.
// Startup must be inert: no dynamic/runtime override reinstall, no Settings row mutation,
// no broad developer/native hooks. The only startup hook kept here is the proven
// passive long-press UITableView trigger.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "Menu/WAGRSurfaceListVC.h"
#import "WAGramPrefix.h"

extern NSString *WAGRHookRouterDiagnostic(void);

static const char *kLP = "wagr.lp.ok";
static void (*orig_tableDidMoveToWindow)(id, SEL) = NULL;
static BOOL gTableHooked = NO;

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
    dispatch_once(&once, ^{ s = [self new]; });
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
    if (tv.window) attachLP(tv);
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

void WAGRDebugMenuEnsureHooksInstalled(void) {
    installLongPressTableHook();
}

NSString *WAGRDebugMenuDiagnosticText(void) {
    return [NSString stringWithFormat:@"startup=inert\ntableHook=%@\nautoRuntimeHooks=OFF\nrouter=%@",
            gTableHooked ? @"YES" : @"NO",
            WAGRHookRouterDiagnostic() ?: @"n/a"];
}

static void startup(void) {
    @autoreleasepool {
        WATweaksMigrateLegacyDefaults();
        installLongPressTableHook();
    }
}

%ctor {
    startup();
}
