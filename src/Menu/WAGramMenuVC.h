// WAGramMenuVC.h
#pragma once
#import <UIKit/UIKit.h>

// ── Functions exposed by hook files ──────────────────────────────────────────
// WAABPropsObserver.xm
void      WAGRWAABEnsureHooksInstalled(void);
NSString *WAGRWAABDiagnosticText(void);
NSString *WAGRABObsLog(void);
void      WAGRABObsClear(void);

// WAEmployeeDogfoodHooks.xm
void      WAGRDogfoodEnsureHooksInstalled(void);
NSString *WAGRDogfoodDiagnosticText(void);

// WAKeychainPatch.xm
void      WAInstallKeychainPatchIfNeeded(void);
NSString *WAKeychainAccessGroupDiagnostic(void);

// WALiquidGlassHooks.xm
void      WAGRLGPrefsDidChange(void);  // call after any LG pref change

// ── Row / Section model ────────────────────────────────────────────────────────
typedef NS_ENUM(NSInteger, WAGramRowStyle) {
    WAGramRowStyleSwitch,
    WAGramRowStyleButton,
    WAGramRowStyleNavigation,
    WAGramRowStyleWAABFlag,    // tri-state WAAB flag (mode 0/1/2)
};

@interface WAGramRow : NSObject
@property (nonatomic, copy)   NSString        *title;
@property (nonatomic, copy)   NSString        *subtitle;
@property (nonatomic, copy)   NSString        *prefsKey;   // for Switch rows (direct bool pref)
@property (nonatomic, copy)   NSString        *waabKey;    // for WAGRFlagTypeBool rows (WAAB flag key)
@property (nonatomic, assign) WAGramRowStyle   style;
@property (nonatomic, copy)   void (^action)(BOOL isOn);
@property (nonatomic, strong) UIViewController *navTarget;

+ (instancetype)switchWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key action:(void (^)(BOOL))action;
+ (instancetype)waabFlagWithTitle:(NSString *)title subtitle:(NSString *)subtitle waabKey:(NSString *)waabKey;
+ (instancetype)buttonWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(BOOL))action;
+ (instancetype)navWithTitle:(NSString *)title subtitle:(NSString *)subtitle target:(UIViewController *)target;
@end

@interface WAGramSectionDef : NSObject
@property (nonatomic, copy)   NSString            *header;
@property (nonatomic, copy)   NSString            *footer;
@property (nonatomic, strong) NSArray<WAGramRow *> *rows;
+ (instancetype)sectionWithHeader:(NSString *)header footer:(NSString *)footer rows:(NSArray<WAGramRow *> *)rows;
@end

@interface WAGramMenuVC : UITableViewController
@end

@interface WAGramSubMenuVC : UITableViewController
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *> *)sections title:(NSString *)title;
@end
