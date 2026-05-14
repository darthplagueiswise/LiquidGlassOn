// WAGramPrefix.h
// Precompiled prefix imported into every translation unit.
// Keep this minimal — only headers that are cheap and always needed.

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#endif

// ── Preference keys ──────────────────────────────────────────────────────────
// Keychain observer
#define kWAGRKeychain          @"wagr_sideload_keychain_enabled"
// Employee / Dogfood
#define kWAGREmployeeMaster    @"wagr_employee_master"
// AB Props observer
#define kWAGRABPropsObserver   @"wagr_abprops_observer_enabled"
// Liquid Glass master toggle
#define kWAGRLiquidGlassMaster @"wagr_liquidglass_enabled"
// Liquid Glass sub-flags
#define kWAGRLG_enabled                        @"wagr_lg_ios_liquid_glass_enabled"
#define kWAGRLG_launched                       @"wagr_lg_ios_liquid_glass_launched"
#define kWAGRLG_m1                             @"wagr_lg_ios_liquid_glass_m1"
#define kWAGRLG_m1_5                           @"wagr_lg_ios_liquid_glass_m_1_5"
#define kWAGRLG_m1_5_context_menu              @"wagr_lg_ios_liquid_glass_m_1_5_context_menu"
#define kWAGRLG_chat_top_bar_m2                @"wagr_lg_ios_liquid_glass_chat_top_bar_m2_enabled"
#define kWAGRLG_new_chatbar_ux                 @"wagr_lg_ios_liquid_glass_enable_new_chatbar_ux"
#define kWAGRLG_larger_composer                @"wagr_lg_ios_liquid_glass_larger_composer"
#define kWAGRLG_reduce_transparency            @"wagr_lg_ios_liquid_glass_reduce_transparency"
#define kWAGRLG_workaround_attachment_tray     @"wagr_lg_ios_liquid_glass_workaround_attachment_tray"
#define kWAGRLG_workaround_hides_bottombar     @"wagr_lg_ios_liquid_glass_workaround_hides_bottombar"
#define kWAGRLG_workaround_topbar_appearance   @"wagr_lg_ios_liquid_glass_workaround_topbar_appearance"
// Debug mode
#define kWAGRDebugMode         @"wagr_debug_mode_enabled"
// ─────────────────────────────────────────────────────────────────────────────

// Convenience macro — reads a BOOL pref from NSUserDefaults
#define WAGRPref(key)  [[NSUserDefaults standardUserDefaults] boolForKey:(key)]
