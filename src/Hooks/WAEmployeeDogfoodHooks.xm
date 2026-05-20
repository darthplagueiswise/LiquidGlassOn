#import <Foundation/Foundation.h>

extern "C" void WAGRDogfoodEnsureHooksInstalled(void) {
    // Disabled in gama. Old broad dogfood hooks can affect keyboard/Meta onboarding.
}

extern "C" NSString *WAGRDogfoodDiagnosticText(void) {
    return @"Dogfood hooks disabled in gama";
}
