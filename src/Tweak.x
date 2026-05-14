// Tweak.x — WAGram Unified Entry Point (menu temporarily disabled)

#import "WAGramPrefix.h"

%ctor {
    @autoreleasepool {
        NSLog(@"[WAGram] Unified v2.0 loading");
        NSDictionary *defs = @{ kWAGRLiquidGlassMaster : @NO, kWAGRDebugMode : @NO };
        [NSUserDefaults.standardUserDefaults registerDefaults:defs];
        NSLog(@"[WAGram] Loaded successfully");
    }
}