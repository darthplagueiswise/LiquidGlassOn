#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

%ctor {
    @autoreleasepool {
        Class cls = objc_getClass("SharedModules");
        SEL sel = sel_getUid("_METAGetOverrideLiquidGlassEnabledKey");
        if (cls && class_respondsToSelector(cls, sel)) {
            NSString *key = ((NSString *(*)(id, SEL))objc_msgSend)(cls, sel);
            if ([key isKindOfClass:[NSString class]] && key.length) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    }
}

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride {
    @try {
        Class cls = objc_getClass("SharedModules");
        SEL sel = sel_getUid("_METAGetOverrideLiquidGlassEnabledKey");
        if (cls && class_respondsToSelector(cls, sel)) {
            NSString *key = ((NSString *(*)(id, SEL))objc_msgSend)(cls, sel);
            if ([key isKindOfClass:[NSString class]] && key.length) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
- (BOOL)_METAIsLiquidGlassEnabled { return YES; }
%end

%hook WDSLiquidGlass
+ (BOOL)isNewLiquidGlassLayoutEnabled { return YES; }
- (BOOL)hasLiquidGlassLaunched { return YES; }
%end

%hook WAABExperimentManager
- (BOOL)isBucketEnabled:(id)bucket { return YES; }
%end
