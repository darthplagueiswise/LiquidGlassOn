// WALiquidGlassHooks.xm
#import "../WAGramPrefix.h"

static BOOL wa_lg_master = NO;

%ctor { wa_lg_master = WAGRPref(kWAGRLiquidGlassMaster); }

%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)key {
    if (wa_lg_master && [key hasPrefix:@"ios_liquid_glass_"]) return YES;
    return %orig;
}
%end

%hook WALiquidGlassProvider
- (BOOL)ios_liquid_glass_enabled { return wa_lg_master ? YES : %orig; }
%end