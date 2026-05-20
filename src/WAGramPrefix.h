// WAGramPrefix.h — compatibility name, unified WATweaks storage.
// Public user-facing/state namespace is watweaks.* only.
// Legacy wagr.* / wa_* keys are migrated once at startup and removed.
//
// Canonical overrides:
//   watweaks.override.objc|ClassName|inst|selectorName   = BOOL
//   watweaks.override.objc|ClassName|class|selectorName  = BOOL
//   watweaks.override.waab|flag_name                     = BOOL
//   watweaks.observed.objc|ClassName|inst|selectorName   = BOOL
//   watweaks.observed.waab|flag_name                     = BOOL
//
// Function names remain WAGR* to avoid a risky project-wide class/symbol rename.

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#endif

#import "WAPrefix.h"

#ifndef WATWEAKS_PREFIX_CONSTANTS
#define WATWEAKS_PREFIX_CONSTANTS 1

static NSString * const kWATweaksPrefix                 = @"watweaks.";
static NSString * const kWATweaksOverrideObjCPrefix     = @"watweaks.override.objc|";
static NSString * const kWATweaksOverrideWAABPrefix     = @"watweaks.override.waab|";
static NSString * const kWATweaksObservedObjCPrefix     = @"watweaks.observed.objc|";
static NSString * const kWATweaksObservedWAABPrefix     = @"watweaks.observed.waab|";

static NSString * const kWATweaksPrefKeychainRewrite    = @"watweaks.pref.keychainRewrite";
static NSString * const kWATweaksPrefKeychainObserver   = @"watweaks.pref.keychainObserver";
static NSString * const kWATweaksPrefNativeDeveloper    = @"watweaks.pref.nativeDeveloper";
static NSString * const kWATweaksPrefDebugMode          = @"watweaks.pref.debugMode";
static NSString * const kWATweaksPrefInternalMaster     = @"watweaks.pref.internalMaster";
static NSString * const kWATweaksPrefEmployeeMaster     = @"watweaks.pref.employeeMaster";
static NSString * const kWATweaksMigrationV1            = @"watweaks.migration.v1.completed";

#endif

#define kWAGRKeychain          kWATweaksPrefKeychainRewrite
#define kWAGRKeychainObserver  kWATweaksPrefKeychainObserver
#define kWAGREmployeeMaster    kWATweaksPrefEmployeeMaster
#define kWAGRABPropsObserver   @"watweaks.pref.abPropsObserver"
#define kWAGRLiquidGlassMaster @"watweaks.pref.liquidGlass"
#define kWAGRDebugMode         kWATweaksPrefDebugMode
#define kWAGRInternalMaster    kWATweaksPrefInternalMaster
#define kWAGRDebugMenuNative   kWATweaksPrefNativeDeveloper

#define kWAGRDogfoodGateMetaEmployee      @"watweaks.pref.dogfood.isMetaEmployeeOrInternalTester"
#define kWAGRDogfoodGateMetaEmployeeSnake @"watweaks.pref.dogfood.is_meta_employee_or_internal_tester"
#define kWAGRDogfoodGateInternalUser      @"watweaks.pref.dogfood.isInternalUser"
#define kWAGRDogfoodGateGraphQLEmpC1      @"watweaks.pref.dogfood.graphQLEmployeeC1Disabled"

#define kWAGRLiquidGlassUserDefaults @"watweaks.pref.liquidGlass.userDefaults"
#define kWAGRLiquidGlassMethodHooks  @"watweaks.pref.liquidGlass.methodHooks"
#define kWAGRLG_enabled                      @"watweaks.override.waab|ios_liquid_glass_enabled"
#define kWAGRLG_launched                     @"watweaks.override.waab|ios_liquid_glass_launched"
#define kWAGRLG_m1                           @"watweaks.override.waab|ios_liquid_glass_m1"
#define kWAGRLG_m1_5                         @"watweaks.override.waab|ios_liquid_glass_m_1_5"
#define kWAGRLG_m1_5_context_menu            @"watweaks.override.waab|ios_liquid_glass_m_1_5_context_menu"
#define kWAGRLG_chat_top_bar_m2              @"watweaks.override.waab|ios_liquid_glass_chat_top_bar_m2_enabled"
#define kWAGRLG_new_chatbar_ux               @"watweaks.override.waab|ios_liquid_glass_enable_new_chatbar_ux"
#define kWAGRLG_larger_composer              @"watweaks.override.waab|ios_liquid_glass_larger_composer"
#define kWAGRLG_reduce_transparency          @"watweaks.override.waab|ios_liquid_glass_reduce_transparency"
#define kWAGRLG_workaround_attachment_tray   @"watweaks.override.waab|ios_liquid_glass_workaround_attachment_tray"
#define kWAGRLG_workaround_hides_bottombar   @"watweaks.override.waab|ios_liquid_glass_workaround_hides_bottombar"
#define kWAGRLG_workaround_topbar_appearance @"watweaks.override.waab|ios_liquid_glass_workaround_topbar_appearance"

#ifndef WAGR_GAMA_SURFACE_IDS
#define WAGR_GAMA_SURFACE_IDS 1
static NSString * const kWAGRSurfaceWAAB     = @"waab";
static NSString * const kWAGRSurfaceContext  = @"context";
static NSString * const kWAGRSurfaceGateKeep = @"gatekeep";
static NSString * const kWAGRSurfaceAura     = @"aura";
static NSString * const kWAGRSurfaceSettings = @"settings";
static NSString * const kWAGRSurfaceEmployee = @"employee";
#endif

static inline BOOL WAGRPref(NSString *key) {
    return key.length ? [[NSUserDefaults standardUserDefaults] boolForKey:key] : NO;
}

static inline void WATweaksSetPref(NSString *key, BOOL value) {
    if (!key.length) return;
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static inline NSString *WATweaksWAABOverrideKey(NSString *flag) {
    if ([flag hasPrefix:kWATweaksOverrideWAABPrefix]) return flag;
    return [kWATweaksOverrideWAABPrefix stringByAppendingString:flag ?: @""];
}

static inline NSString *WATweaksWAABObservedKey(NSString *flag) {
    if ([flag hasPrefix:kWATweaksObservedWAABPrefix]) return flag;
    return [kWATweaksObservedWAABPrefix stringByAppendingString:flag ?: @""];
}

static inline NSString *WAGRKey(NSString *flag) {
    return WATweaksWAABOverrideKey(flag);
}

static inline BOOL WAGRIsOn(NSString *flag) {
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:WATweaksWAABOverrideKey(flag)];
    return obj ? [obj boolValue] : NO;
}

static inline BOOL WAGRIsOff(NSString *flag) {
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:WATweaksWAABOverrideKey(flag)];
    return obj ? ![obj boolValue] : NO;
}

static inline void WAGRSet(NSString *flag, NSString *val) {
    if (!flag.length) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = WATweaksWAABOverrideKey(flag);
    if (!val) {
        [ud removeObjectForKey:key];
    } else {
        BOOL b = [val isEqualToString:@"on"] || [val isEqualToString:@"YES"] || [val isEqualToString:@"1"];
        [ud setBool:b forKey:key];
    }
    [ud synchronize];
}

static inline BOOL WATweaksIsObjCOverrideKey(NSString *key) {
    return [key hasPrefix:kWATweaksOverrideObjCPrefix];
}

static inline BOOL WATweaksIsWAABOverrideKey(NSString *key) {
    return [key hasPrefix:kWATweaksOverrideWAABPrefix];
}

static inline NSString *WAGROverrideKey(NSString *surfaceID, NSString *className,
                                         BOOL isClassMethod, NSString *sel) {
    (void)surfaceID;
    NSString *c = className ?: @"";
    NSString *s = sel ?: @"";
    if ([c isEqualToString:@"WAABProperties"] ||
        [c isEqualToString:@"FOAWAABPropertiesImpl"] ||
        [c containsString:@"WAABProperties"] ||
        [c containsString:@"ABProperties"]) {
        return WATweaksWAABOverrideKey(s);
    }
    return [NSString stringWithFormat:@"%@%@|%@|%@",
            kWATweaksOverrideObjCPrefix,
            c,
            isClassMethod ? @"class" : @"inst",
            s];
}

static inline NSString *WAGRObservedKey(NSString *overrideKey) {
    if (!overrideKey.length) return @"";
    if ([overrideKey hasPrefix:kWATweaksOverrideObjCPrefix]) {
        return [kWATweaksObservedObjCPrefix stringByAppendingString:
                [overrideKey substringFromIndex:kWATweaksOverrideObjCPrefix.length]];
    }
    if ([overrideKey hasPrefix:kWATweaksOverrideWAABPrefix]) {
        return [kWATweaksObservedWAABPrefix stringByAppendingString:
                [overrideKey substringFromIndex:kWATweaksOverrideWAABPrefix.length]];
    }
    return [overrideKey stringByAppendingString:@".observed"];
}

static inline BOOL WAGRHasOverride(NSString *key) {
    if (!key.length) return NO;
    return [[NSUserDefaults standardUserDefaults] objectForKey:key] != nil;
}

static inline BOOL WAGROverrideBool(NSString *key) {
    if (!key.length) return NO;
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    return obj ? [obj boolValue] : NO;
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

static inline void WATweaksMigrateBool(NSUserDefaults *ud, NSMutableArray<NSString *> *removeKeys, NSString *oldKey, NSString *newKey) {
    if (!oldKey.length || !newKey.length || [oldKey isEqualToString:newKey]) return;
    id obj = [ud objectForKey:oldKey];
    if (!obj) return;
    if ([ud objectForKey:newKey] == nil) [ud setBool:[obj boolValue] forKey:newKey];
    [removeKeys addObject:oldKey];
}

static inline void WATweaksMigrateLegacyDefaults(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary *all = [ud dictionaryRepresentation];
    NSMutableArray<NSString *> *removeKeys = [NSMutableArray array];

    for (NSString *key in all.allKeys) {
        id obj = all[key];

        if ([key hasPrefix:@"wagr.override|objc|"]) {
            NSString *suffix = [key substringFromIndex:[@"wagr.override|objc|" length]];
            NSString *newKey = [kWATweaksOverrideObjCPrefix stringByAppendingString:suffix];
            if ([ud objectForKey:newKey] == nil) [ud setBool:[obj boolValue] forKey:newKey];
            [removeKeys addObject:key];
            continue;
        }

        if ([key hasPrefix:@"wagr.waab."]) {
            NSString *flag = [key substringFromIndex:[@"wagr.waab." length]];
            NSString *newKey = WATweaksWAABOverrideKey(flag);
            if ([ud objectForKey:newKey] == nil) {
                BOOL b = NO;
                if ([obj isKindOfClass:NSString.class]) {
                    b = [(NSString *)obj isEqualToString:@"on"] || [(NSString *)obj isEqualToString:@"YES"] || [(NSString *)obj isEqualToString:@"1"];
                } else {
                    b = [obj boolValue];
                }
                [ud setBool:b forKey:newKey];
            }
            [removeKeys addObject:key];
            continue;
        }

        if ([key hasPrefix:@"wagr.observed|objc|"]) {
            NSString *suffix = [key substringFromIndex:[@"wagr.observed|objc|" length]];
            NSString *newKey = [kWATweaksObservedObjCPrefix stringByAppendingString:suffix];
            if ([ud objectForKey:newKey] == nil) [ud setBool:[obj boolValue] forKey:newKey];
            [removeKeys addObject:key];
            continue;
        }

        if ([key hasPrefix:@"wagr.override."] || [key hasPrefix:@"wagr.observed."]) {
            [removeKeys addObject:key];
            continue;
        }
    }

    WATweaksMigrateBool(ud, removeKeys, @"wagr_native_debug_menu_enabled", kWATweaksPrefNativeDeveloper);
    WATweaksMigrateBool(ud, removeKeys, @"wagr_debug_mode_enabled", kWATweaksPrefDebugMode);
    WATweaksMigrateBool(ud, removeKeys, @"wagr_internal_master_enabled", kWATweaksPrefInternalMaster);
    WATweaksMigrateBool(ud, removeKeys, @"wagr_employee_master_enabled", kWATweaksPrefEmployeeMaster);

#ifdef WA_PREF_KEYCHAIN_REWRITE
    WATweaksMigrateBool(ud, removeKeys, WA_PREF_KEYCHAIN_REWRITE, kWATweaksPrefKeychainRewrite);
#endif
#ifdef WA_PREF_KEYCHAIN_OBSERVER
    WATweaksMigrateBool(ud, removeKeys, WA_PREF_KEYCHAIN_OBSERVER, kWATweaksPrefKeychainObserver);
#endif

    for (NSString *key in removeKeys) [ud removeObjectForKey:key];
    [ud setBool:YES forKey:kWATweaksMigrationV1];
    [ud synchronize];
}

static inline NSUInteger WATweaksCountKeysWithPrefix(NSString *prefix) {
    NSUInteger n = 0;
    for (NSString *k in [NSUserDefaults standardUserDefaults].dictionaryRepresentation.allKeys)
        if ([k hasPrefix:prefix]) n++;
    return n;
}

static inline NSUInteger WATweaksUniqueOverrideCount(void) {
    return WATweaksCountKeysWithPrefix(kWATweaksOverrideObjCPrefix) +
           WATweaksCountKeysWithPrefix(kWATweaksOverrideWAABPrefix);
}

static inline NSUInteger WATweaksObjCOverrideCount(void) {
    return WATweaksCountKeysWithPrefix(kWATweaksOverrideObjCPrefix);
}

static inline NSUInteger WATweaksWAABOverrideCount(void) {
    return WATweaksCountKeysWithPrefix(kWATweaksOverrideWAABPrefix);
}

static inline BOOL WATweaksHasSavedObjCOverrides(void) {
    return WATweaksObjCOverrideCount() > 0;
}

#ifdef __cplusplus
extern "C" {
#endif
extern NSUInteger WAGRReinstallPersistedHooks(void);
extern NSString *WAGRHookRouterDiagnostic(void);
extern NSString *WAGRLGDiagnosticText(void);
extern NSString *WAGRDogfoodDiagnosticText(void);
extern NSString *WAKeychainAccessGroupDiagnostic(void);
#ifdef __cplusplus
}
#endif
