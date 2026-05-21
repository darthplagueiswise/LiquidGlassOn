#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define WALog(fmt, ...) NSLog(@"[WATweaks] " fmt, ##__VA_ARGS__)

#define WA_PREF_KEYCHAIN_REWRITE @"wa_sideload_keychain_rewrite_enabled"
#define WA_PREF_KEYCHAIN_OBSERVER @"wa_keychain_observer_enabled"
#define WA_PREF_EMPLOYEE_MASTER @"wa_employee_master"
#define WA_PREF_AB_OBSERVER @"wa_abprops_observer_enabled"
#define WA_PREF_LIQUID_GLASS @"wa_liquid_glass_enabled"
#define WA_PREF_LIQUID_GLASS_USERDEFAULTS @"wa_liquid_glass_userdefaults_overrides"
#define WA_PREF_LIQUID_GLASS_METHOD_HOOKS @"wa_liquid_glass_method_hooks"
