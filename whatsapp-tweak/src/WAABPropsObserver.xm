#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static BOOL wa_abprops_observer_enabled = NO;
static NSString * const kWAABPropsObserverKey = @"wa_abprops_observer_enabled";

%ctor {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
    wa_abprops_observer_enabled = [prefs[kWAABPropsObserverKey] boolValue] ?: NO;
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
        NSDictionary *newPrefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.darthplagueiswise.waliquidglassryuk.plist"];
        wa_abprops_observer_enabled = [newPrefs[kWAABPropsObserverKey] boolValue] ?: NO;
    }, CFSTR("com.darthplagueiswise.waliquidglassryuk/prefsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}

// Observer for WAABProperties / ABProperties / MobileConfig / MetaConfig
%hook WAABProperties

- (id)abProperties {
    id orig = %orig;
    if (wa_abprops_observer_enabled && orig) {
        NSLog(@"[WAABPropsObserver] abProperties called | value=%@", orig);
    }
    return orig;
}

- (id)abPropertiesPreChatd {
    id orig = %orig;
    if (wa_abprops_observer_enabled && orig) {
        NSLog(@"[WAABPropsObserver] abPropertiesPreChatd called");
    }
    return orig;
}

%end

%hook MobileConfig

- (BOOL)isMobileConfigRollout:(NSString *)key {
    BOOL orig = %orig;
    if (wa_abprops_observer_enabled) {
        NSLog(@"[WAABPropsObserver] isMobileConfigRollout:%@ = %@", key, orig ? @"YES" : @"NO");
    }
    return orig;
}

%end

// Add more observers as you discover (getMobileConfigInitPhase, MetaConfigFetchMutation, etc.)
%hook WAXWAMetaConfigRequestInput

- (id)init {
    id orig = %orig;
    if (wa_abprops_observer_enabled) {
        NSLog(@"[WAABPropsObserver] WAXWAMetaConfigRequestInput init");
    }
    return orig;
}

%end