// Tweak.x — WAGram Unified Entry Point (Reviewed)
// Long-press on "Help" in Settings to open menu

#import "WAGramPrefix.h"
#import "Menu/WAGramMenuVC.h"

static const NSInteger kWAGRLongPressTag = 0x7A6EA1;

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

static void WAGRLongPressFired(UILongPressGestureRecognizer *gr) {
    if (gr.state != UIGestureRecognizerStateBegan) return;
    UITableView *tv = (UITableView *)gr.view;
    if (![tv isKindOfClass:UITableView.class]) return;

    CGPoint pt = [gr locationInView:tv];
    NSIndexPath *ip = [tv indexPathForRowAtPoint:pt];
    if (!ip) return;

    UITableViewCell *cell = [tv cellForRowAtIndexPath:ip];
    NSString *text = [cell.textLabel.text lowercaseString] ?: @"";
    NSString *reuse = [cell.reuseIdentifier lowercaseString] ?: @"";

    BOOL isHelp = [reuse containsString:@"help"] || [text containsString:@"help"];
    if (!isHelp) return;

    UIViewController *vc = (UIViewController *)tv.nextResponder;
    while (vc && ![vc isKindOfClass:UIViewController.class]) vc = (UIViewController *)[vc nextResponder];
    if (vc) WAGRPresentMenu(vc);
}

static void WAGRAttachLongPress(UITableView *tv) {
    if (!tv) return;
    for (UIGestureRecognizer *gr in tv.gestureRecognizers)
        if (gr.tag == kWAGRLongPressTag) return;

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:nil action:nil];
    lp.minimumPressDuration = 0.6;
    lp.tag = kWAGRLongPressTag;

    [lp addTarget:[WAGRGestureTarget shared] action:@selector(handle:)];
    [tv addGestureRecognizer:lp];
}

@interface WAGRGestureTarget : NSObject
+ (instancetype)shared;
- (void)handle:(UILongPressGestureRecognizer *)gr;
@end

@implementation WAGRGestureTarget
+ (instancetype)shared { static WAGRGestureTarget *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [self new]; }); return s; }
- (void)handle:(UILongPressGestureRecognizer *)gr { WAGRLongPressFired(gr); }
@end

// Hook Settings ViewControllers
static IMP orig_vda = NULL;

static void hook_vda(id self, SEL _cmd, BOOL animated) {
    if (orig_vda) ((void(*)(id,SEL,BOOL))orig_vda)(self, _cmd, animated);
    if ([self isKindOfClass:UITableViewController.class]) {
        WAGRAttachLongPress(((UITableViewController *)self).tableView);
    }
}

%ctor {
    @autoreleasepool {
        NSLog(@"[WAGram] Unified v2.0 loading — bundle=%@", NSBundle.mainBundle.bundleIdentifier);

        // Register all defaults (OFF)
        NSDictionary *defs = @{
            kWAGRLiquidGlassMaster : @NO,
            kWAGREmployeeMaster    : @NO,
            kWAGRABPropsObserver   : @NO,
            kWAGRKeychainObserver  : @NO,
            kWAGRDebugMode         : @NO,
            kWAGRLG_enabled        : @NO,
            kWAGRLG_launched       : @NO,
            kWAGRLG_m1             : @NO,
            kWAGRLG_m1_5           : @NO,
            kWAGRLG_chat_top_bar_m2: @NO,
            // ... (add all LG keys)
        };
        [NSUserDefaults.standardUserDefaults registerDefaults:defs];

        // Install Settings hook
        NSArray *candidates = @[ @"WASettingsViewController", @"WASettingsTableViewController", @"WANewSettingsViewController" ];
        for (NSString *name in candidates) {
            Class cls = NSClassFromString(name);
            if (cls && class_getInstanceMethod(cls, @selector(viewDidAppear:))) {
                MSHookMessageEx(cls, @selector(viewDidAppear:), (IMP)hook_vda, &orig_vda);
                NSLog(@"[WAGram] Hooked %@", name);
                break;
            }
        }
    }
}
