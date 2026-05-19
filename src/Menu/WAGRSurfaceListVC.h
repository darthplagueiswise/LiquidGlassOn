#pragma once
#import <UIKit/UIKit.h>
#ifdef __cplusplus
extern "C" {
#endif
void      WAGRWAABEnsureHooksInstalled(void);   // thin shim to router
void      WAGRDogfoodEnsureHooksInstalled(void);
NSString *WAGRDogfoodDiagnosticText(void);
void      WAInstallKeychainPatchIfNeeded(void);
NSString *WAKeychainAccessGroupDiagnostic(void);
void      WAGRLGPrefsDidChange(void);
NSString *WAGRLGDiagnosticText(void);
void      WAGRDebugMenuEnsureHooksInstalled(void);
NSString *WAGRDebugMenuDiagnosticText(void);
BOOL      WAGRInstallHookForEntry(id entry);
NSUInteger WAGRReinstallPersistedHooks(void);
NSString  *WAGRHookRouterDiagnostic(void);
NSUInteger WAGRInstalledHookCount(void);
#ifdef __cplusplus
}
#endif

// Compat alias expected by Tweak.x
#define WAGramMenuVC WAGRSurfaceListVC
@interface WAGRSurfaceListVC : UITableViewController
@end
