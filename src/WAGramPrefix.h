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


// ─────────────────────────────────────────────────────────────
// WAGram gama runtime surface ids
// Required by src/Runtime/WAGRSurface.m
// ─────────────────────────────────────────────────────────────
#ifndef WAGR_GAMA_SURFACE_IDS
#define WAGR_GAMA_SURFACE_IDS 1
static NSString * const kWAGRSurfaceWAAB     = @"waab";
static NSString * const kWAGRSurfaceContext  = @"context";
static NSString * const kWAGRSurfaceGateKeep = @"gatekeep";
static NSString * const kWAGRSurfaceAura     = @"aura";
static NSString * const kWAGRSurfaceSettings = @"settings";
static NSString * const kWAGRSurfaceEmployee = @"employee";
#endif


// ─────────────────────────────────────────────────────────────
// WAGram gama runtime override helpers
// Required by WAGRSurfaceBrowserVC.m and WAGRSurface.m
// ─────────────────────────────────────────────────────────────
#ifndef WAGR_GAMA_OVERRIDE_HELPERS
#define WAGR_GAMA_OVERRIDE_HELPERS 1

static inline NSString *WAGROverrideKey(NSString *surfaceID, NSString *className,
                                         BOOL isClassMethod, NSString *sel) {
    return [NSString stringWithFormat:@"wagr.override|%@|%@|%@|%@",
            surfaceID ?: @"runtime",
            className ?: @"",
            isClassMethod ? @"class" : @"inst",
            sel ?: @""];
}

static inline NSString *WAGRObservedKey(NSString *overrideKey) {
    if (!overrideKey.length) return @"";
    if ([overrideKey hasPrefix:@"wagr.override|"]) {
        return [overrideKey stringByReplacingOccurrencesOfString:@"wagr.override|"
                                                      withString:@"wagr.observed|"];
    }
    return [overrideKey stringByReplacingOccurrencesOfString:@"wagr.override."
                                                  withString:@"wagr.observed."];
}

static inline BOOL WAGRHasOverride(NSString *key) {
    if (!key.length) return NO;
    return [[NSUserDefaults standardUserDefaults] objectForKey:key] != nil;
}

static inline BOOL WAGROverrideBool(NSString *key) {
    if (!key.length) return NO;
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static inline void WAGRSetOverride(NSString *key, BOOL value) {
    if (!key.length) return;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static inline void WAGRClearOverride(NSString *key) {
    if (!key.length) return;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static inline void WAGRRecordObserved(NSString *overrideKey, BOOL value) {
    NSString *k = WAGRObservedKey(overrideKey);
    if (!k.length) return;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:k];
}

static inline BOOL WAGRObservedValue(NSString *overrideKey, BOOL *known) {
    NSString *k = WAGRObservedKey(overrideKey);
    id obj = k.length ? [[NSUserDefaults standardUserDefaults] objectForKey:k] : nil;
    if (known) *known = obj != nil;
    return obj ? [obj boolValue] : NO;
}

#endif
