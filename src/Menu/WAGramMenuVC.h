#pragma once
#import <UIKit/UIKit.h>

@interface WAGramMenuVC : UITableViewController
@end

@interface WAGRABFlagBrowserVC : UITableViewController
- (instancetype)initWithTitle:(NSString *)t flags:(NSArray<NSString *> *)flags;
- (void)reload;
- (void)updateTitle;
@end

@interface WAGRRuntimeMethodBrowserVC : UITableViewController
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
@end

@interface WAGRWAABCatalogBrowserVC : UITableViewController
@end

#ifdef __cplusplus
extern "C" {
#endif

// WAAB Observer
void      WAGRWAABEnsureHooksInstalled(void);
BOOL      WAGRWAABOriginalBoolForFlag(NSString *flag, BOOL *knownOut);
NSString *WAGRWAABDiagnosticText(void);
NSString *WAGRABObsLog(void);
void      WAGRABObsClear(void);

// LiquidGlass
void      WAGRLGPrefsDidChange(void);
BOOL      WAGRLGSystemDefaultEnabled(void);
BOOL      WAGRLGEffectiveEnabled(void);
NSString *WAGRLGDiagnosticText(void);

// Dogfood / Employee
void      WAGRDogfoodEnsureHooksInstalled(void);
NSString *WAGRDogfoodDiagnosticText(void);

// Aura
void      WAGRAuraEnsureHooksInstalled(void);
void      WAGRAuraActivateAllFlags(void);
void      WAGRAuraDeactivateAllFlags(void);
NSString *WAGRAuraDiagnostic(void);
BOOL      WAGRPushAuraThemesVC(UIViewController *from);
BOOL      WAGRPushAuraIconsVC(UIViewController *from);
BOOL      WAGRPushAuraRingtonesVC(UIViewController *from);

// Aura Gating (subscription-state hooks)
void      WAGRAuraGatingEnsureHooksInstalled(void);
void      WAGRAuraGatingActivate(BOOL on);

// Context / Debug
void      WAGRContextEnsureHooksInstalled(void);
void      WAGRContextSetSimulateDebug(BOOL on);
BOOL      WAGRContextIsSimulatingDebug(void);
BOOL      WAGRContextIsDebugMenuForced(void);
NSString *WAGRContextDiagnosticText(void);

// Runtime exact BOOL getter hooks
void      WAGRRuntimeRestorePersistedOverrides(void);
NSString *WAGRRuntimeBoolDiagnosticText(void);

#ifdef __cplusplus
}
#endif
