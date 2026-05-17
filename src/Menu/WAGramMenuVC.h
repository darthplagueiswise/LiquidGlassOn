#pragma once
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
// WAAB Observer
void      WAGRWAABEnsureHooksInstalled(void);
NSString *WAGRWAABDiagnosticText(void);
NSString *WAGRABObsLog(void);
void      WAGRABObsClear(void);
// LiquidGlass
void      WAGRLGPrefsDidChange(void);
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
#ifdef __cplusplus
}
#endif

@interface WAGramMenuVC : UITableViewController
@end

@interface WAGRABFlagBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags;
- (void)reload;
- (void)updateTitle;
@end
