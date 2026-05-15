// WAGramPrefix.h — WAGram unified prefix
// Storage: wagr.waab.<flag_key> = @"on" | @"off"  (absent = system/no override)
// No .mode suffix, no NSInteger — just plain strings.

#pragma once
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#endif
#import "WAPrefix.h"

// ── NSUserDefaults storage keys ───────────────────────────────────────────────
// WAAB flag override: wagr.waab.<flag> = @"on" | @"off"
static inline NSString *WAGRKey(NSString *flag) {
    return [NSString stringWithFormat:@"wagr.waab.%@", flag];
}
static inline BOOL WAGRIsOn(NSString *flag) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)] isEqualToString:@"on"];
}
static inline BOOL WAGRIsOff(NSString *flag) {
    return [[[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(flag)] isEqualToString:@"off"];
}
static inline void WAGRSet(NSString *flag, NSString *val) {
    if (!flag.length) return;
    if (!val) [[NSUserDefaults standardUserDefaults] removeObjectForKey:WAGRKey(flag)];
    else      [[NSUserDefaults standardUserDefaults] setObject:val forKey:WAGRKey(flag)];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// ── Master pref keys ──────────────────────────────────────────────────────────
#define kWAGRKeychain          WA_PREF_KEYCHAIN_REWRITE
#define kWAGRKeychainObserver  WA_PREF_KEYCHAIN_OBSERVER
#define kWAGREmployeeMaster    WA_PREF_EMPLOYEE_MASTER
#define kWAGRABPropsObserver   WA_PREF_AB_OBSERVER
#define kWAGRLiquidGlassMaster WA_PREF_LIQUID_GLASS
#define kWAGRDebugMode         @"wagr_debug_mode_enabled"
#define kWAGRInternalMaster    @"wagr_internal_master_enabled"
#define kWAGRDebugMenuNative   @"wagr_native_debug_menu_enabled"

// ── Dogfood gate individual keys ──────────────────────────────────────────────
#define kWAGRDogfoodGateMetaEmployee      @"wagr.dogfood.gate.isMetaEmployeeOrInternalTester"
#define kWAGRDogfoodGateMetaEmployeeSnake @"wagr.dogfood.gate.is_meta_employee_or_internal_tester"
#define kWAGRDogfoodGateInternalUser      @"wagr.dogfood.gate.isInternalUser"
#define kWAGRDogfoodGateGraphQLEmpC1      @"wagr.dogfood.gate.graphQLEmployeeC1Disabled"

// ── Quick bool read ───────────────────────────────────────────────────────────
#define WAGRPref(key) [[NSUserDefaults standardUserDefaults] boolForKey:(key)]
