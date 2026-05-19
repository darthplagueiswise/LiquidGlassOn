#pragma once
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#endif
#import "WAPrefix.h"

// ── Surface IDs ───────────────────────────────────────────────────────────────
#define kWAGRSurfaceWAAB      @"waab"
#define kWAGRSurfaceContext   @"context"
#define kWAGRSurfaceAura      @"aura"
#define kWAGRSurfaceGateKeep  @"gatekeep"
#define kWAGRSurfaceEmployee  @"employee"
#define kWAGRSurfaceSettings  @"settings"

// ── Master pref keys (NSUserDefaults boolForKey) ───────────────────────────────
#define kWAGREmployeeMaster    WA_PREF_EMPLOYEE_MASTER
#define kWAGRABPropsObserver   WA_PREF_AB_OBSERVER
#define kWAGRLiquidGlassMaster WA_PREF_LIQUID_GLASS
#define kWAGRDebugMode         @"wagr_debug_mode_enabled"
#define kWAGRInternalMaster    @"wagr_internal_master_enabled"
#define kWAGRDebugMenuNative   @"wagr_native_debug_menu_enabled"
#define kWAGRDogfoodGateMetaEmployee      @"wagr.dogfood.gate.isMetaEmployeeOrInternalTester"
#define kWAGRDogfoodGateMetaEmployeeSnake @"wagr.dogfood.gate.is_meta_employee_or_internal_tester"
#define kWAGRDogfoodGateInternalUser      @"wagr.dogfood.gate.isInternalUser"
#define kWAGRDogfoodGateGraphQLEmpC1      @"wagr.dogfood.gate.graphQLEmployeeC1Disabled"

// ── Override storage (AGENTS.md §: setBool / objectForKey presence) ──────────
// Key: wagr.override.<surfaceID>.<className>.<inst|class>.<selector>
// objectForKey == nil → no override (system)
// objectForKey != nil + boolForKey YES → force YES
// objectForKey != nil + boolForKey NO  → force NO
static inline NSString *WAGROverrideKey(NSString *surfaceID, NSString *className,
                                         BOOL isClassMethod, NSString *sel) {
    // Pipe-separated to avoid breaking Swift/ObjC class names that contain dots,
    // e.g. WAAIStickers.AiStickersGating.
    return [NSString stringWithFormat:@"wagr.override|%@|%@|%@|%@",
            surfaceID ?: @"runtime", className ?: @"", isClassMethod ? @"class" : @"inst", sel ?: @""];
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

// ── Observed value storage ────────────────────────────────────────────────────
// Key: wagr.observed.<same suffix>
static inline NSString *WAGRObservedKey(NSString *overrideKey) {
    if (!overrideKey.length) return @"";
    if ([overrideKey hasPrefix:@"wagr.override|"])
        return [overrideKey stringByReplacingOccurrencesOfString:@"wagr.override|"
                                                      withString:@"wagr.observed|"];
    return [overrideKey stringByReplacingOccurrencesOfString:@"wagr.override."
                                                  withString:@"wagr.observed."];
}

static inline void WAGRRecordObserved(NSString *overrideKey, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:WAGRObservedKey(overrideKey)];
    // No synchronize — performance; written only from hook path
}
static inline BOOL WAGRObservedValue(NSString *overrideKey, BOOL *knownOut) {
    NSString *k = WAGRObservedKey(overrideKey);
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:k];
    if (knownOut) *knownOut = (obj != nil);
    return [[NSUserDefaults standardUserDefaults] boolForKey:k];
}

// ── Quick read ────────────────────────────────────────────────────────────────
#define WAGRPref(key) [[NSUserDefaults standardUserDefaults] boolForKey:(key)]
