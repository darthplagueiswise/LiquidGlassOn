// WAGramPrefix.h
// Unified Prefix Header — WAGram + LiquidGlassOn v2.0
// Clean, reviewed, production-ready

#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import <Security/Security.h>
#endif

// ── Master Preference Keys ───────────────────────────────────────────────────────────────────
#define kWAGRLiquidGlassMaster          @"wagr_liquidglass_master"
#define kWAGREmployeeMaster             @"wagr_employee_master"
#define kWAGRABPropsObserver            @"wagr_abprops_observer"
#define kWAGRKeychainObserver           @"wagr_keychain_observer"
#define kWAGRDebugMode                  @"wagr_debug_mode"

// Liquid Glass Sub-Flags (validated against SharedModules)
#define kWAGRLG_enabled                 @"wagr_lg_ios_liquid_glass_enabled"
#define kWAGRLG_launched                @"wagr_lg_ios_liquid_glass_launched"
#define kWAGRLG_m1                      @"wagr_lg_ios_liquid_glass_m1"
#define kWAGRLG_m1_5                    @"wagr_lg_ios_liquid_glass_m_1_5"
#define kWAGRLG_m1_5_context_menu       @"wagr_lg_ios_liquid_glass_m_1_5_context_menu"
#define kWAGRLG_chat_top_bar_m2         @"wagr_lg_ios_liquid_glass_chat_top_bar_m2_enabled"
#define kWAGRLG_new_chatbar_ux          @"wagr_lg_ios_liquid_glass_enable_new_chatbar_ux"
#define kWAGRLG_larger_composer         @"wagr_lg_ios_liquid_glass_larger_composer"
#define kWAGRLG_reduce_transparency     @"wagr_lg_ios_liquid_glass_reduce_transparency"
#define kWAGRLG_workaround_attachment_tray   @"wagr_lg_ios_liquid_glass_workaround_attachment_tray"
#define kWAGRLG_workaround_hides_bottombar   @"wagr_lg_ios_liquid_glass_workaround_hides_bottombar"
#define kWAGRLG_workaround_topbar_appearance @"wagr_lg_ios_liquid_glass_workaround_topbar_appearance"

// Convenience
#define WAGRPref(key) [[NSUserDefaults standardUserDefaults] boolForKey:(key)]
#define WALog(...)    if (WAGRPref(kWAGRDebugMode)) NSLog(@"[WAGram] " __VA_ARGS__)

