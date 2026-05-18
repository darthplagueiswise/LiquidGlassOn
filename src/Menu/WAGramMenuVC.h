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
void      WAGRBundleEnsureHooksInstalled(void);
void      WAGRAuraGatingSwiftHooksInstall(void);
void      WAGRAuraActivateAllFlags(void);
void      WAGRAuraDeactivateAllFlags(void);
BOOL      WAGRPushAuraThemesVC(UIViewController *from);
BOOL      WAGRPushAuraIconsVC(UIViewController *from);
BOOL      WAGRPushAuraRingtonesVC(UIViewController *from);
NSString *WAGRAuraDiagnostic(void);
void      WAGRNativeSurfaceEnsureHooksInstalled(void);
NSString *WAGRNativeSurfaceDiagnosticText(void);
void      WAGRNativeBoolOverrideSet(NSString *className, BOOL meta, NSString *selectorName, NSString *value);
NSString *WAGRNativeBoolOverrideGet(NSString *className, BOOL meta, NSString *selectorName);
NSUInteger WAGRNativeBoolOverrideInstallPersisted(void);
void      WAGRDebugBuildEnsureHooksInstalled(void);
NSString *WAGRDebugBuildDiagnostic(void);
#ifdef __cplusplus
}
#endif

static inline void WAGRActivateBundle(NSArray<NSString *> *flags) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in flags) [ud setObject:@"on" forKey:[NSString stringWithFormat:@"wagr.waab.%@", f]];
    [ud synchronize];
    WAGRWAABEnsureHooksInstalled();
    WAGRNativeSurfaceEnsureHooksInstalled();
}
static inline void WAGRDeactivateBundle(NSArray<NSString *> *flags) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *f in flags) [ud removeObjectForKey:[NSString stringWithFormat:@"wagr.waab.%@", f]];
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

#ifndef WAGR_V10_MENU_BROWSER_PRIMARY_INTERFACES
#define WAGR_V10_MENU_BROWSER_PRIMARY_INTERFACES

@interface WAGRABFlagBrowserVC : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, strong, readonly) NSArray<NSString *> *allFlags;
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags;
+ (NSArray<NSString *> *)runtimeFlags;
- (void)reload;
- (void)confirmNuclearReset;
@end

@interface WAGRWAABTriStateBrowserVC : UITableViewController <UISearchResultsUpdating>
@property (nonatomic, assign) BOOL negativeMode;
- (instancetype)initWithTitle:(NSString *)title flags:(NSArray<NSString *> *)flags negativeMode:(BOOL)negativeMode;
- (void)updateTitle;
@end

@interface WAGramBundleVC : UITableViewController
- (instancetype)initWithTitle:(NSString *)title
                        flags:(NSArray<NSString *> *)flags
                     negFlags:(NSArray<NSString *> *)negativeFlags
                         icon:(NSString *)icon
                    iconColor:(UIColor *)iconColor
                         desc:(NSString *)desc;
@end

@interface WAGramMenuVC : UITableViewController
@end

@interface WAGramWAABRuntimeCategoriesVC : UITableViewController
@end

@interface WAGRRuntimeMethodBrowserVC : UITableViewController <UISearchResultsUpdating>
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
+ (BOOL)methodNameLooksFeatureLike:(NSString *)name;
+ (NSArray<NSString *> *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
@end

#endif
