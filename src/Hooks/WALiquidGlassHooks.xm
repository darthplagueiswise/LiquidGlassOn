// WALiquidGlassHooks.xm
// Unified & Reviewed — Best of LiquidGlassOn + WAGram
// Strategy: UserDefaults override (fast) + Targeted method hooks (reliable)

#import "../../WAGramPrefix.h"
#import <UIKit/UIKit.h>

static BOOL wa_lg_master = NO;

%ctor {
    @autoreleasepool {
        wa_lg_master = WAGRPref(kWAGRLiquidGlassMaster);
        
        // Listen for preference changes
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            (CFNotificationCallback)^(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
                wa_lg_master = WAGRPref(kWAGRLiquidGlassMaster);
                WALog(@"LiquidGlass master changed → %@", wa_lg_master ? @"ON" : @"OFF");
            },
            CFSTR("com.wagr.prefsChanged"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
    }
}

// ── Primary: Global NSUserDefaults Override (fastest path) ───────────────────────────────────────────────────────────
%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)key {
    if (wa_lg_master && 
        ([key hasPrefix:@"ios_liquid_glass_"] || 
         [key containsString:@"LiquidGlass"] ||
         [key isEqualToString:@"WALiquidGlassOverrideMethodUserDefaults"])) {
        return YES;
    }
    return %orig;
}
%end

// ── Secondary: Targeted Class Hooks (more reliable for some builds) ───────────────────────────────────────────────────────────────
%hook WALiquidGlassProvider
- (BOOL)ios_liquid_glass_enabled               { return wa_lg_master ? YES : %orig; }
- (BOOL)ios_liquid_glass_launched              { return wa_lg_master ? YES : %orig; }
- (BOOL)ios_liquid_glass_m1                    { return wa_lg_master ? YES : %orig; }
- (BOOL)ios_liquid_glass_m_1_5                 { return wa_lg_master ? YES : %orig; }
- (BOOL)ios_liquid_glass_chat_top_bar_m2_enabled { return wa_lg_master ? YES : %orig; }
- (BOOL)shouldUseLiquidGlassConfiguration      { return wa_lg_master ? YES : %orig; }
- (BOOL)hasLiquidGlassLaunched                 { return wa_lg_master ? YES : %orig; }
%end

%hook WDSLiquidGlass
- (BOOL)glassEffectEnabled  { return wa_lg_master ? YES : %orig; }
- (BOOL)useLiquidGlassDesign { return wa_lg_master ? YES : %orig; }
%end

// ── Workarounds (optional granular control) ──────────────────────────────────────────────────────────
%hook WALiquidGlassWorkarounds
- (BOOL)attachmentTrayWorkaround   { return WAGRPref(kWAGRLG_workaround_attachment_tray)   ? YES : %orig; }
- (BOOL)hidesBottomBarWorkaround   { return WAGRPref(kWAGRLG_workaround_hides_bottombar)   ? YES : %orig; }
- (BOOL)topBarAppearanceWorkaround { return WAGRPref(kWAGRLG_workaround_topbar_appearance) ? YES : %orig; }
%end

// Public API for menu
void WAGRLGPrefsDidChange(void) {
    wa_lg_master = WAGRPref(kWAGRLiquidGlassMaster);
    WALog(@"LiquidGlass prefs updated (master=%@)", wa_lg_master ? @"YES" : @"NO");
}
