// WAGramPrefix.h
// Shared compatibility header imported by Objective-C/Logos files that use WAGram aliases.
// Compatible with WAKeychainPatch.xm, WAEmployeeDogfoodHooks.xm,
// WAABPropsObserver.xm, WALiquidGlassHooks.xm.

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#endif

// ── WAPrefix compat (WAUtils.m uses WA_PREF_* defines from WAPrefix.h) ────────
#import "WAPrefix.h"

// ── Master pref keys (kWAGR* = new unified keys) ──────────────────────────────
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

// ── Liquid Glass sub-flag pref keys (legacy, still used by WALiquidGlassHooks) ─
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

// ── WAAB override storage (used by WAABPropsObserver.xm) ─────────────────────
// wagr.waab.<key>.mode   = NSInteger  0=system  1=force-OFF  2=force-ON
// wagr.waab.<key>.number = NSNumber   typed override for integer/double keys
// wagr.waab.<key>.string = NSString   typed override for string keys
static inline NSString *WAGRWAABKeyMode(NSString *key) {
    return key.length ? [@"wagr.waab." stringByAppendingFormat:@"%@.mode", key] : @"";
}
static inline NSString *WAGRWAABKeyNumber(NSString *key) {
    return key.length ? [@"wagr.waab." stringByAppendingFormat:@"%@.number", key] : @"";
}
static inline NSString *WAGRWAABKeyString(NSString *key) {
    return key.length ? [@"wagr.waab." stringByAppendingFormat:@"%@.string", key] : @"";
}
static inline NSString *WAGRWAABKeyRuntimeType(NSString *key) {
    return key.length ? [@"wagr.waab.runtime." stringByAppendingFormat:@"%@.type", key] : @"";
}
static inline NSString *WAGRWAABKeyRuntimeValue(NSString *key) {
    return key.length ? [@"wagr.waab.runtime." stringByAppendingFormat:@"%@.value", key] : @"";
}

// ── Convenience: read a BOOL pref ─────────────────────────────────────────────
#define WAGRPref(key) [[NSUserDefaults standardUserDefaults] boolForKey:(key)]
