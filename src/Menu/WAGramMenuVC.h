// WAGramMenuVC.h
// ─────────────────────────────────────────────────────────────────────────────
// Main WAGram menu, presented via a long-press on Settings > Help & Feedback.
// Modelled closely on RyukGram-Fork/dev2 SCITweakSettings pattern.
// ─────────────────────────────────────────────────────────────────────────────

#pragma once

#import <UIKit/UIKit.h>

// Forward declarations of hook diagnostics exposed by individual .xm files
NSString *WAGRKeychainDiagnosticText(void);
NSString *WAGRDogfoodDiagnosticText(void);
NSString *WAGRABObsLog(void);
void      WAGRABObsClear(void);
void      WAGRWAABEnsureHooksInstalled(void);
NSString *WAGRWAABDiagnosticText(void);
void      WAGRDogfoodEnsureHooksInstalled(void);
void      WAGRLGPrefsDidChange(void);

// ── WAGramRow ─────────────────────────────────────────────────────────────────
typedef NS_ENUM(NSInteger, WAGramRowStyle) {
    WAGramRowStyleSwitch,
    WAGramRowStyleButton,
    WAGramRowStyleNavigation,
};

@interface WAGramRow : NSObject
@property (nonatomic, copy)   NSString        *title;
@property (nonatomic, copy)   NSString        *subtitle;
@property (nonatomic, copy)   NSString        *prefsKey;        // nil for button/nav
@property (nonatomic, assign) WAGramRowStyle   style;
@property (nonatomic, copy)   void (^action)(BOOL isOn);        // switch: called on change; button: called on tap
@property (nonatomic, strong) UIViewController *navTarget;      // navigation row

+ (instancetype)switchWithTitle:(NSString *)title
                       subtitle:(NSString *)subtitle
                           key:(NSString *)key
                          action:(void (^)(BOOL isOn))action;

+ (instancetype)buttonWithTitle:(NSString *)title
                        subtitle:(NSString *)subtitle
                          action:(void (^)(BOOL unused))action;

+ (instancetype)navWithTitle:(NSString *)title
                     subtitle:(NSString *)subtitle
                       target:(UIViewController *)target;
@end

// ── WAGramSectionDef ──────────────────────────────────────────────────────────
@interface WAGramSectionDef : NSObject
@property (nonatomic, copy)   NSString            *header;
@property (nonatomic, copy)   NSString            *footer;
@property (nonatomic, strong) NSArray<WAGramRow *> *rows;
+ (instancetype)sectionWithHeader:(NSString *)header
                           footer:(NSString *)footer
                             rows:(NSArray<WAGramRow *> *)rows;
@end

// ── WAGramMenuVC (main) ───────────────────────────────────────────────────────
@interface WAGramMenuVC : UITableViewController
@end

// ── WAGramSubMenuVC (generic sub-screen) ─────────────────────────────────────
@interface WAGramSubMenuVC : UITableViewController
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *> *)sections
                           title:(NSString *)title;
@end
