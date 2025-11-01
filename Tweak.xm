#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride {
    @try {
        if ([SharedModules respondsToSelector:@selector(_METAGetOverrideLiquidGlassEnabledKey)]) {
            NSString *key = [SharedModules performSelector:@selector(_METAGetOverrideLiquidGlassEnabledKey)];
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
