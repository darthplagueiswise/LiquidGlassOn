#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define WALog(fmt, ...) NSLog(@"[LiquidGlassOn] " fmt, ##__VA_ARGS__)

#define WA_PREF_KEYCHAIN_REWRITE @"wa_sideload_keychain_rewrite_enabled"
#define WA_PREF_EMPLOYEE_MASTER @"wa_employee_master"
#define WA_PREF_AB_OBSERVER @"wa_abprops_observer_enabled"
#define WA_PREF_LIQUID_GLASS @"wa_liquid_glass_enabled"
