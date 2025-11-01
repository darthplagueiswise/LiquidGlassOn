#import "LGFeatureFlags+Preview.h"
#import <objc/message.h>

@implementation LGFeatureFlags (Preview)

- (BOOL)lg_isLiquidGlassEnabledPreviewAware {
#if LIQUID_GLASS_PREVIEW
    // 1) NSUserDefaults override
    id forced = [[NSUserDefaults standardUserDefaults] objectForKey:@"LiquidGlassForcedEnabled"];
    if (forced) return [forced boolValue];

    // 2) Plist override bundled with internal builds
    NSString *path = [[NSBundle mainBundle] pathForResource:@"FeatureOverrides" ofType:@"plist"];
    if (path) {
        NSDictionary *over = [NSDictionary dictionaryWithContentsOfFile:path];
        id v = over[@"LiquidGlassForcedEnabled"];
        if ([v respondsToSelector:@selector(boolValue)]) return [v boolValue];
    }
#endif
    // 3) Fall back to your existing remote/exp flag
    // Replace the call below with your real flag source.
    return [self respondsToSelector:@selector(isLiquidGlassEnabled)]
           ? ((BOOL (*)(id, SEL))objc_msgSend)(self, @selector(isLiquidGlassEnabled))
           : NO;
}

@end
