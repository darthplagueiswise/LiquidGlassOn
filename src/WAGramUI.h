// WAGramUI.h — RyukGram-inspired UI primitives for WAGram
// Icon cells with colored rounded squares, same visual language as RyukGram/SCI

#pragma once
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ── Color system ──────────────────────────────────────────────────────────────
static inline UIColor *WAGR_BG(void)      { return UIColor.systemGroupedBackgroundColor; }
static inline UIColor *WAGR_CELL(void)    { return UIColor.secondarySystemGroupedBackgroundColor; }
static inline UIColor *WAGR_ACCENT(void)  { return [UIColor colorWithRed:.2 green:.5 blue:1 alpha:1]; }
static inline UIColor *WAGR_GREEN(void)   { return UIColor.systemGreenColor; }
static inline UIColor *WAGR_ORANGE(void)  { return UIColor.systemOrangeColor; }
static inline UIColor *WAGR_RED(void)     { return UIColor.systemRedColor; }
static inline UIColor *WAGR_PURPLE(void)  { return UIColor.systemPurpleColor; }
static inline UIColor *WAGR_TEAL(void)    { return UIColor.systemTealColor; }
static inline UIColor *WAGR_INDIGO(void)  { return UIColor.systemIndigoColor; }
static inline UIColor *WAGR_SEC(void)     { return UIColor.secondaryLabelColor; }
static inline UIColor *WAGR_LABEL(void)   { return UIColor.labelColor; }
static inline UIColor *WAGR_MINT(void)    {
    if (@available(iOS 15, *)) return UIColor.systemMintColor;
    return [UIColor colorWithRed:.0 green:.78 blue:.74 alpha:1];
}

// ── Icon view (colored rounded square with SF Symbol — RyukGram style) ────────
static inline UIView *WAGRIconView(NSString *sfsymbol, UIColor *bgColor) {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0,0,29,29)];
    box.backgroundColor = bgColor;
    box.layer.cornerRadius = 6;
    box.layer.masksToBounds = YES;
    UIImageView *img = [[UIImageView alloc] initWithFrame:CGRectMake(5,5,19,19)];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightMedium];
    img.image = [UIImage systemImageNamed:sfsymbol withConfiguration:cfg];
    img.tintColor = UIColor.whiteColor;
    img.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:img];
    return box;
}

// ── Section header view ───────────────────────────────────────────────────────
@interface WAGRSectionHeader : UIView
- (instancetype)initWithTitle:(NSString *)title;
@end

// ── Standard cell factory ─────────────────────────────────────────────────────
// Returns a pre-configured UITableViewCell with icon, title, and optional detail.
UITableViewCell *WAGRIconCell(NSString *sfsymbol, UIColor *iconBG, NSString *title, NSString *detail, UITableViewCellAccessoryType acc);

