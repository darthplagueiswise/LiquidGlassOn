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
    NSString *native = WAGRNativeDeveloperDiagnostic ? WAGRNativeDeveloperDiagnostic() : @"native developer unavailable";
    NSString *core = WAGRSharedModulesCoreDiagnostic ? WAGRSharedModulesCoreDiagnostic() : @"shared core unavailable";
    return [NSString stringWithFormat:@"%@\n%@", native, core];
}
