#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static BOOL wa_employee_master = NO;
static NSString * const kWAEmployeeMasterKey = @"wa_employee_master";

%ctor {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
    wa_employee_master = [prefs[kWAEmployeeMasterKey] boolValue] ?: NO;
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
        NSDictionary *newPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
        wa_employee_master = [newPrefs[kWAEmployeeMasterKey] boolValue] ?: NO;
    }, CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

// Targeted hooks - only when master toggle is ON
%hook WAEmployeeDogfood  // Adjust class name if different in your WA version (use class-dump or Frida to confirm)

- (BOOL)isMetaEmployeeOrInternalTester {
    return wa_employee_master ? YES : %orig;
}

- (BOOL)is_meta_employee_or_internal_tester {
    return wa_employee_master ? YES : %orig;
}

- (BOOL)isInternalUser {
    return wa_employee_master ? YES : %orig;
}

- (BOOL)graphQLEmployeeC1Disabled {
    return wa_employee_master ? NO : %orig;
}

%end

// Additional real gates from SharedModules(2) - add more as you discover
%hook WADogfoodManager

- (BOOL)wamo_is_employee {
    return wa_employee_master ? YES : %orig;
}

- (void)setWamo_is_employee:(BOOL)arg1 {
    if (wa_employee_master) {
        %orig(YES);
    } else {
        %orig;
    }
}

%end