// WAGramPrefix.h — WAGram unified prefix
// Storage: wagr.waab.<flag_key> = @"on" | @"off"  (absent = system/no override)
// Compatibility aliases kept for older Tweak.x defaults and LiquidGlass hooks.

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
    return [NSString stringWithFormat:@"wagr.waab.%@", flag ?: @""];
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

// Compatibility with old 0/1/2 WAAB-mode code still referenced by some files.
static inline NSString *WAGRWAABKeyMode(NSString *flag) {
    return WAGRKey(flag);
}
static inline NSString *WAGRWAABKeyRuntimeType(NSString *flag) {
    return [NSString stringWithFormat:@"wagr.waab.runtime.%@.type", flag ?: @""];
}
static inline NSString *WAGRWAABKeyRuntimeValue(NSString *flag) {
    return [NSString stringWithFormat:@"wagr.waab.runtime.%@.value", flag ?: @""];
}
static inline NSString *WAGRWAABKeyNumber(NSString *flag) {
    return [NSString stringWithFormat:@"wagr.waab.%@.number", flag ?: @""];
}
static inline NSString *WAGRWAABKeyString(NSString *flag) {
    return [NSString stringWithFormat:@"wagr.waab.%@.string", flag ?: @""];
}

// ── Master pref keys ──────────────────────────────────────────────────────────
#define kWAGRKeychain          WA_PREF_KEYCHAIN_REWRITE
#define kWAGRKeychainObserver  WA_PREF_KEYCHAIN_OBSERVER
#define kWAGREmployeeMaster    WA_PREF_EMPLOYEE_MASTER
#define kWAGRABPropsObserver   WA_PREF_AB_OBSERVER
#define kWAGRLiquidGlassMaster WA_PREF_LIQUID_GLASS
#define kWAGRLiquidGlassUserDefaults WA_PREF_LIQUID_GLASS_USERDEFAULTS
#define kWAGRLiquidGlassMethodHooks  WA_PREF_LIQUID_GLASS_METHOD_HOOKS
#define kWAGRDebugMode         @"wagr_debug_mode_enabled"
#define kWAGRInternalMaster    @"wagr_internal_master_enabled"
#define kWAGRDebugMenuNative   @"wagr_native_debug_menu_enabled"
#define kWAGRDogfoodMaster     kWAGREmployeeMaster

// ── Dogfood gate individual keys ──────────────────────────────────────────────
#define kWAGRDogfoodGateMetaEmployee      @"wagr.dogfood.gate.isMetaEmployeeOrInternalTester"
#define kWAGRDogfoodGateMetaEmployeeSnake @"wagr.dogfood.gate.is_meta_employee_or_internal_tester"
#define kWAGRDogfoodGateInternalUser      @"wagr.dogfood.gate.isInternalUser"
#define kWAGRDogfoodGateGraphQLEmpC1      @"wagr.dogfood.gate.graphQLEmployeeC1Disabled"

// ── LiquidGlass legacy pref keys used by Tweak.x defaults ─────────────────────
#define kWAGRLG_enabled                      @"wa_lg_ios_liquid_glass_enabled"
#define kWAGRLG_launched                     @"wa_lg_ios_liquid_glass_launched"
#define kWAGRLG_m1                           @"wa_lg_ios_liquid_glass_m1"
#define kWAGRLG_m1_5                         @"wa_lg_ios_liquid_glass_m_1_5"
#define kWAGRLG_m1_5_context_menu            @"wa_lg_ios_liquid_glass_m_1_5_context_menu"
#define kWAGRLG_chat_top_bar_m2              @"wa_lg_ios_liquid_glass_chat_top_bar_m2_enabled"
#define kWAGRLG_new_chatbar_ux               @"wa_lg_ios_liquid_glass_enable_new_chatbar_ux"
#define kWAGRLG_larger_composer              @"wa_lg_ios_liquid_glass_larger_composer"
#define kWAGRLG_reduce_transparency          @"wa_lg_ios_liquid_glass_reduce_transparency"
#define kWAGRLG_workaround_attachment_tray   @"wa_lg_ios_liquid_glass_workaround_attachment_tray"
#define kWAGRLG_workaround_hides_bottombar   @"wa_lg_ios_liquid_glass_workaround_hides_bottombar"
#define kWAGRLG_workaround_topbar_appearance @"wa_lg_ios_liquid_glass_workaround_topbar_appearance"

// ── Quick bool read ───────────────────────────────────────────────────────────
#define WAGRPref(key) [[NSUserDefaults standardUserDefaults] boolForKey:(key)]
