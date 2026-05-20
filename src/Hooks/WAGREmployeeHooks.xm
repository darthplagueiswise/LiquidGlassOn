#import <Foundation/Foundation.h>

extern "C" void WAGRNativeDeveloperEnsureHooksInstalled(void);
extern "C" NSString *WAGRNativeDeveloperDiagnostic(void);
extern "C" void WAGRSharedModulesCoreEnsureHooksInstalled(void);
extern "C" NSString *WAGRSharedModulesCoreDiagnostic(void);

extern "C" void WAGRDogfoodEnsureHooksInstalled(void) {
    WAGRNativeDeveloperEnsureHooksInstalled();
    WAGRSharedModulesCoreEnsureHooksInstalled();
}

extern "C" NSString *WAGRDogfoodDiagnosticText(void) {
    NSString *native = WAGRNativeDeveloperDiagnostic();
    NSString *core = WAGRSharedModulesCoreDiagnostic();
    return [NSString stringWithFormat:@"%@\n%@", native ?: @"native developer unavailable", core ?: @"shared core unavailable"];
}
