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
// Absent = system/default. Numeric/boolean legacy values are normalized on read.
static inline NSString *WAGRKey(NSString *flag) {
    return [NSString stringWithFormat:@"wagr.waab.%@", flag];
}
static inline id WAGRPersistentObjectForKey(NSString *key) {
    if (!key.length) return nil;
    NSString *domain = NSBundle.mainBundle.bundleIdentifier;
    NSDictionary *persistent = domain.length ? [[NSUserDefaults standardUserDefaults] persistentDomainForName:domain] : nil;
    return persistent[key];
}
static inline NSString *WAGRStateStringFromObject(id obj) {
    if (!obj || obj == (id)kCFNull) return nil;
    if ([obj isKindOfClass:NSString.class]) {
        NSString *s = [(NSString *)obj lowercaseString];
        if ([s isEqualToString:@"on"] || [s isEqualToString:@"true"] || [s isEqualToString:@"yes"] || [s isEqualToString:@"1"]) return @"on";
        if ([s isEqualToString:@"off"] || [s isEqualToString:@"false"] || [s isEqualToString:@"no"] || [s isEqualToString:@"0"]) return @"off";
        return nil;
    }
    if ([obj isKindOfClass:NSNumber.class]) return [(NSNumber *)obj boolValue] ? @"on" : @"off";
    return nil;
}
static inline NSString *WAGRStoredStateForFlag(NSString *flag) {
    return WAGRStateStringFromObject(WAGRPersistentObjectForKey(WAGRKey(flag)));
}
static inline BOOL WAGRIsOn(NSString *flag) {
    return [WAGRStoredStateForFlag(flag) isEqualToString:@"on"];
}
static inline BOOL WAGRIsOff(NSString *flag) {
    return [WAGRStoredStateForFlag(flag) isEqualToString:@"off"];
}
static inline void WAGRSet(NSString *flag, NSString *val) {
    if (!flag.length) return;
    if (!val.length) [[NSUserDefaults standardUserDefaults] removeObjectForKey:WAGRKey(flag)];
    else             [[NSUserDefaults standardUserDefaults] setObject:val forKey:WAGRKey(flag)];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
static inline BOOL WAGRBoolOverrideForKey(NSString *key, BOOL *valueOut) {
    NSString *state = WAGRStateStringFromObject(WAGRPersistentObjectForKey(key));
    if (!state) return NO;
    if (valueOut) *valueOut = [state isEqualToString:@"on"];
    return YES;
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

// ── LiquidGlass sub-prefs ─────────────────────────────────────────────────────
#define kWAGRLiquidGlassUserDefaults @"wa_liquid_glass_userdefaults_overrides"
#define kWAGRLiquidGlassMethodHooks  @"wa_liquid_glass_method_hooks"
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
