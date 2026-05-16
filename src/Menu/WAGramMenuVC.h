#pragma once
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
void      WAGRWAABEnsureHooksInstalled(void);
NSString *WAGRWAABDiagnosticText(void);
NSString *WAGRABObsLog(void);
void      WAGRABObsClear(void);
void      WAGRDogfoodEnsureHooksInstalled(void);
NSString *WAGRDogfoodDiagnosticText(void);
void      WAInstallKeychainPatchIfNeeded(void);
NSString *WAKeychainAccessGroupDiagnostic(void);
void      WAGRLGPrefsDidChange(void);
NSString *WAGRLGDiagnosticText(void);
void      WAGRDebugMenuEnsureHooksInstalled(void);
NSString *WAGRDebugMenuDiagnosticText(void);
void      WAGRAuraEnsureHooksInstalled(void);
void      WAGRAuraActivateAllFlags(void);
void      WAGRAuraDeactivateAllFlags(void);
BOOL      WAGRPushAuraThemesVC(UIViewController *from);
BOOL      WAGRPushAuraIconsVC(UIViewController *from);
BOOL      WAGRPushAuraRingtonesVC(UIViewController *from);
NSString *WAGRAuraDiagnostic(void);
void      WAGRBundleHooksInstall(void);
void      WAGRNativeSurfaceEnsureHooksInstalled(void);
NSString *WAGRNativeSurfaceDiagnosticText(void);
void      WAGRNativeBoolOverrideSet(NSString *className, BOOL meta, NSString *selectorName, NSString *value);
NSString *WAGRNativeBoolOverrideGet(NSString *className, BOOL meta, NSString *selectorName);
NSUInteger WAGRNativeBoolOverrideInstallPersisted(void);
#ifdef __cplusplus
}
#endif

// ─── Bundle activation (writes all flags for a feature at once) ───────────────
// Same pattern as LiquidGlass master toggle.
static inline void WAGRActivateBundle(NSArray<NSString *> *flags) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in flags)
        [ud setObject:@"on" forKey:[NSString stringWithFormat:@"wagr.waab.%@", f]];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    WAGRNativeSurfaceEnsureHooksInstalled();
}
static inline void WAGRDeactivateBundle(NSArray<NSString *> *flags) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in flags)
        [ud removeObjectForKey:[NSString stringWithFormat:@"wagr.waab.%@", f]];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    WAGRNativeSurfaceEnsureHooksInstalled();
}
static inline NSUInteger WAGRBundleActiveCount(NSArray<NSString *> *flags) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    NSUInteger n = 0;
    for (NSString *f in flags)
        if ([[ud stringForKey:[NSString stringWithFormat:@"wagr.waab.%@", f]] isEqualToString:@"on"]) n++;
    return n;
}
static inline BOOL WAGRBundleAllActive(NSArray<NSString *> *flags) {
    return WAGRBundleActiveCount(flags) == flags.count;
}

@interface WAGRABFlagBrowserVC : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, strong, readonly) NSArray<NSString *> *allFlags;
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags;
+ (NSArray<NSString *> *)runtimeFlags;
- (void)reload;
@end

@interface WAGramMenuVC : UITableViewController
@end

@interface WAGramWAABRuntimeCategoriesVC : UITableViewController
@end

// Non-WAAB runtime method browser — tri-state exact override for bool-ish methods outside WAABProperties.
@interface WAGRRuntimeMethodBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
+ (NSArray<NSString *> *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
@end
