// WAGramMenuVC.h
#pragma once
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif

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
void      WAGRLGPrefsDidChange(void);
NSString *WAGRLGDiagnosticText(void);

// Tweak.x
void      WAGRDebugMenuEnsureHooksInstalled(void);
NSString *WAGRDebugMenuDiagnosticText(void);

// WAAuraHooks.xm
void      WAGRAuraEnsureHooksInstalled(void);
void      WAGRAuraActivateAllFlags(void);
void      WAGRAuraDeactivateAllFlags(void);
BOOL      WAGRPushAuraThemesVC(UIViewController *from);
BOOL      WAGRPushAuraIconsVC(UIViewController *from);
BOOL      WAGRPushAuraRingtonesVC(UIViewController *from);
NSString *WAGRAuraDiagnostic(void);

#ifdef __cplusplus
}
#endif

typedef NS_ENUM(NSInteger, WAGramRowStyle) {
    WAGramRowStyleSwitch,
    WAGramRowStyleButton,
    WAGramRowStyleNavigation,
    WAGramRowStyleWAABFlag,
};

@interface WAGramRow : NSObject
@property (nonatomic, copy)   NSString        *title;
@property (nonatomic, copy)   NSString        *subtitle;
@property (nonatomic, copy)   NSString        *prefsKey;
@property (nonatomic, copy)   NSString        *waabKey;
@property (nonatomic, assign) WAGramRowStyle   style;
@property (nonatomic, copy)   void (^action)(BOOL isOn);
@property (nonatomic, strong) UIViewController *navTarget;
+ (instancetype)switchWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key action:(void (^)(BOOL))action;
+ (instancetype)waabWithTitle:(NSString *)title key:(NSString *)waabKey;
+ (instancetype)buttonWithTitle:(NSString *)title action:(void (^)(BOOL))action;
+ (instancetype)navWithTitle:(NSString *)title subtitle:(NSString *)subtitle target:(UIViewController *)target;
@end

@interface WAGramSectionDef : NSObject
@property (nonatomic, copy)   NSString            *header;
@property (nonatomic, copy)   NSString            *footer;
@property (nonatomic, strong) NSArray<WAGramRow *> *rows;
+ (instancetype)sectionWithHeader:(NSString *)h footer:(NSString *)f rows:(NSArray<WAGramRow *> *)rows;
@end

@interface WAGramMenuVC : UITableViewController
@end

@interface WAGramSubMenuVC : UITableViewController
- (instancetype)initWithSections:(NSArray<WAGramSectionDef *> *)sections title:(NSString *)title;
@end

// Dynamic WAAB flag browser — shows ALL flags from binary with current state
@interface WAGRABFlagBrowserVC : UITableViewController
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags;
+ (NSArray<NSString *> *)runtimeFlags;
@end

// On-demand runtime BOOL getter browser for non-WAAB/framework surfaces.
@interface WAGRRuntimeMethodBrowserVC : UITableViewController
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
@end

// JSON-backed WAAB category browser; reads staged WAGram catalog if present.
@interface WAGRWAABCatalogBrowserVC : UITableViewController
@end

#ifdef __cplusplus
extern "C" {
#endif
NSString *WAGRRuntimeBoolDiagnosticText(void);
void WAGRRuntimeRestorePersistedOverrides(void);
#ifdef __cplusplus
}
#endif
