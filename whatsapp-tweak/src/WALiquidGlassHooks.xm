#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static BOOL wa_liquid_glass_enabled = NO;
static NSString * const kWALiquidGlassKey = @"wa_liquid_glass_enabled";

%ctor {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
    wa_liquid_glass_enabled = [prefs[kWALiquidGlassKey] boolValue] ?: NO;
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
        NSDictionary *newPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
        wa_liquid_glass_enabled = [newPrefs[kWALiquidGlassKey] boolValue] ?: NO;
    }, CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

// First: Native UserDefaults override (preferred method)
%hook NSUserDefaults

- (BOOL)boolForKey:(NSString *)key {
    if (wa_liquid_glass_enabled && [key hasPrefix:@"ios_liquid_glass_"] || [key isEqualToString:@"WALiquidGlassOverrideMethodUserDefaults"]) {
        return YES;
    }
    return %orig;
}

%end

// Targeted hooks if UserDefaults not enough
%hook WALiquidGlassProvider

- (BOOL)ios_liquid_glass_enabled {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)ios_liquid_glass_launched {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)ios_liquid_glass_m1 {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)ios_liquid_glass_m_1_5 {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)ios_liquid_glass_chat_top_bar_m2_enabled {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)shouldUseLiquidGlassConfiguration {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)hasLiquidGlassLaunched {
    return wa_liquid_glass_enabled ? YES : %orig;
}

%end

// Additional Liquid Glass methods from your list
%hook WDSLiquidGlass

- (BOOL)glassEffectEnabled {
    return wa_liquid_glass_enabled ? YES : %orig;
}

- (BOOL)useLiquidGlassDesign {
    return wa_liquid_glass_enabled ? YES : %orig;
}

%end