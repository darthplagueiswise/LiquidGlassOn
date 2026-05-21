// WAGRWATweaksSettingsRow.xm
// ─────────────────────────────────────────────────────────────────────────────
// Adds a native-looking "WATweaks" entry at the bottom of WhatsApp's
// Settings screen, visually styled to match an inset-grouped section with a
// single row (the same style used by the WhatsApp "Developer" row).
//
// Design decisions
// ────────────────
// • We do NOT modify the WhatsApp settings table data source. Doing so would
//   require interposing the dataSource/delegate, which is risky on a Swift
//   provider-based pipeline. Instead we install a `tableFooterView` — a
//   UIKit property that paints below the last data-source section without
//   any further involvement from the table's data source.
//
// • Activation reuses the existing UITableView -didMoveToWindow hook in
//   Tweak.x. When that hook fires for a UITableView whose owning view
//   controller is a WASettingsViewController, we attach the footer (once).
//   This avoids opening a second hook surface and keeps install behavior
//   in a single, already-validated code path.
//
// • The footer is associated with the table view via objc_setAssociatedObject
//   so it never gets installed twice on the same table instance, and gets
//   released along with the table view automatically.
//
// • Tap handling is wired through a shared target object so we never retain
//   the presenting view controller; we look it up live from the tap-time
//   responder chain instead, which keeps memory clean.
//
// Visual layout
// ─────────────
// The footer is one view (footerHeight ≈ 115pt) that contains an empty top
// padding (~35pt, matching iOS inset-grouped section gap), a single rounded
// 12pt-radius row container 60pt tall, and bottom padding ~20pt. The row
// inside the container has: a 28×22pt "</>" icon (blue tint, matching the
// reference screenshot the user provided), the "WATweaks" label in regular
// system 17pt, and a trailing chevron indicating it's tappable.
// ─────────────────────────────────────────────────────────────────────────────

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "../WAGramPrefix.h"
#import "../Menu/WAGRSurfaceListVC.h"

// Single associated-object marker so the same table never gets two footers.
// Using a static const void * gives us a unique-by-address key without any
// allocation, which is the idiomatic ObjC pattern for this.
static const void *kWAGRFooterMarker = &kWAGRFooterMarker;

// ── The row "button" view ────────────────────────────────────────────────────
// We use a UIControl subclass instead of a plain UIView+tap recognizer so
// touch-down/up visual feedback is automatic via setHighlighted:. This makes
// the row feel native without us having to manage state manually.
@interface WAGRSettingsFooterButton : UIControl {
    UIImageView *_iconView;
    UILabel     *_label;
    UIImageView *_chevron;
}
@end

@implementation WAGRSettingsFooterButton

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;

    // Match iOS inset-grouped cell background. secondarySystemGroupedBackgroundColor
    // automatically respects light/dark mode without us hard-coding values.
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.layer.cornerRadius = 12;
    self.layer.cornerCurve  = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;

    // Icon: SF Symbol "chevron.left.forwardslash.chevron.right" gives us the
    // </> glyph from the reference screenshot. The blue tint distinguishes
    // the row from the white-tinted "Developer" row above it.
    _iconView = [[UIImageView alloc] init];
    UIImage *icon = [UIImage systemImageNamed:@"chevron.left.forwardslash.chevron.right"];
    if (!icon) icon = [UIImage systemImageNamed:@"curlybraces"];
    _iconView.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _iconView.tintColor = UIColor.systemBlueColor;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_iconView];

    _label = [[UILabel alloc] init];
    _label.text = @"WATweaks";
    _label.textColor = UIColor.labelColor;
    _label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    [self addSubview:_label];

    // Trailing chevron indicates the row is tappable, matching WhatsApp's
    // own settings row visual contract.
    _chevron = [[UIImageView alloc] init];
    UIImage *chevImg = [UIImage systemImageNamed:@"chevron.right"];
    _chevron.image = [chevImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _chevron.tintColor = [UIColor tertiaryLabelColor];
    _chevron.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_chevron];

    self.isAccessibilityElement = YES;
    self.accessibilityLabel = @"WATweaks";
    self.accessibilityTraits = UIAccessibilityTraitButton;

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    _iconView.frame = CGRectMake(20, (h - 22) / 2.0, 28, 22);
    _chevron.frame  = CGRectMake(w - 28, (h - 14) / 2.0, 14, 14);
    _label.frame    = CGRectMake(60, 0, w - 60 - 28 - 12, h);
}

// Touch-down highlight feedback. Using a 0.95 alpha is subtle and matches
// the muted feedback iOS uses on system cells.
- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1.0;
}
@end

// ── Tap target ───────────────────────────────────────────────────────────────
// One shared object holds the action. We resolve the presenting VC live at
// tap time from the chain, so this object never retains a UI controller and
// can stay alive for the whole process lifetime safely.
@interface WAGRWATweaksRowTarget : NSObject
+ (instancetype)shared;
- (void)tapped:(WAGRSettingsFooterButton *)btn;
@end

@implementation WAGRWATweaksRowTarget
+ (instancetype)shared {
    static WAGRWATweaksRowTarget *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [WAGRWATweaksRowTarget new]; });
    return s;
}

// Find the nearest view controller in the responder chain. If we hit a
// presenting controller chain, descend to the topmost presented one so the
// modal we're about to show stacks correctly.
static UIViewController *wagr_top_vc_from(UIView *view) {
    UIResponder *r = view;
    UIViewController *vc = nil;
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) { vc = (UIViewController *)r; break; }
        r = r.nextResponder;
    }
    if (!vc) return nil;
    UIViewController *p = vc;
    while (p.presentedViewController) p = p.presentedViewController;
    return p;
}

- (void)tapped:(WAGRSettingsFooterButton *)btn {
    UIViewController *host = wagr_top_vc_from(btn);
    if (!host) return;

    // Build the WATweaks (formerly WAGram) menu fresh each time. The
    // controller is lightweight; the table rebuilds its data on viewDidLoad.
    WAGRSurfaceListVC *menu = [[WAGRSurfaceListVC alloc] init];
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:menu];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sh = nav.sheetPresentationController;
        sh.prefersGrabberVisible = YES;
        sh.detents = @[UISheetPresentationControllerDetent.largeDetent];
    }

    [host presentViewController:nav animated:YES completion:nil];
}
@end

// ── Footer construction ──────────────────────────────────────────────────────
// Builds the full UIView that will be assigned as tableFooterView. The view
// includes section-gap padding above the row container, matching how iOS
// renders an extra inset-grouped section after the last data-source one.
static UIView *wagr_build_footer(CGFloat width) {
    const CGFloat sectionTop  = 35;
    const CGFloat rowHeight   = 60;
    const CGFloat sideInset   = 16;
    const CGFloat bottomInset = 20;
    const CGFloat totalHeight = sectionTop + rowHeight + bottomInset;

    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, totalHeight)];
    footer.backgroundColor = UIColor.clearColor;
    footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    WAGRSettingsFooterButton *row =
        [[WAGRSettingsFooterButton alloc] initWithFrame:
            CGRectMake(sideInset, sectionTop, width - sideInset * 2, rowHeight)];
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [row addTarget:[WAGRWATweaksRowTarget shared]
            action:@selector(tapped:)
  forControlEvents:UIControlEventTouchUpInside];

    [footer addSubview:row];
    return footer;
}

// ── Public attach API ────────────────────────────────────────────────────────
// Called from Tweak.x's UITableView -didMoveToWindow hook for every table
// view that comes on-screen. The cost when the table is not a settings
// table is two associated-object reads and a string compare, well below
// noise level for a hook of this frequency.
extern "C" void WAGRMaybeAttachWATweaksFooter(UITableView *tv) {
    if (!tv || ![tv isKindOfClass:UITableView.class]) return;
    if (!tv.window) return;
    if (objc_getAssociatedObject(tv, kWAGRFooterMarker)) return;

    // Find the owning view controller via the responder chain. We require
    // the *immediate* settings view controller, not any ancestor: a chat
    // screen embedded inside a sheet can have a settings VC in its chain
    // and we don't want to attach there.
    UIResponder *r = tv;
    UIViewController *owner = nil;
    while (r) {
        if ([r isKindOfClass:UIViewController.class]) { owner = (UIViewController *)r; break; }
        r = r.nextResponder;
    }
    if (!owner) return;

    NSString *cls = NSStringFromClass(owner.class);
    BOOL isSettingsHost =
        [cls isEqualToString:@"WASettingsViewController"]    ||
        [cls isEqualToString:@"WANewSettingsViewController"] ||
        [cls isEqualToString:@"WASettingsTableViewController"];
    if (!isSettingsHost) return;

    UIView *footer = wagr_build_footer(tv.bounds.size.width);
    tv.tableFooterView = footer;
    objc_setAssociatedObject(tv, kWAGRFooterMarker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSLog(@"[WATweaks][SettingsRow] footer attached to %@", cls);
}

// ── Diagnostic ──────────────────────────────────────────────────────────────
// Used by the menu's diagnostic alert.
extern "C" NSString *WAGRWATweaksRowDiagnosticText(void) {
    Class settingsCls = NSClassFromString(@"WASettingsViewController");
    return [NSString stringWithFormat:@"settingsClass=%@\nrowVisible=on-demand (attaches when Settings table appears)",
            settingsCls ? @"found" : @"missing"];
}