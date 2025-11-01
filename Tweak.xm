#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import <substrate.h>

// Return YES for any BOOL selector
static BOOL eg_yes(id self, SEL _cmd) { return YES; }

static void eg_forceMetaKeyYES(const char *selName) {
    if (!selName) return;
    Class C = objc_getClass("SharedModules");
    if (!C) return;
    SEL s = sel_getUid(selName);
    if (class_respondsToSelector(C, s)) {
        NSString *key = ((NSString *(*)(id, SEL))objc_msgSend)(C, s);
        if ([key isKindOfClass:[NSString class]] && key.length) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

static void eg_hookBoolSelectorOn(Class cls, SEL sel) {
    if (!cls || !sel) return;
    if (class_respondsToSelector(cls, sel)) {
        MSHookMessageEx(cls, sel, (IMP)eg_yes, NULL);
    }
    Class meta = object_getClass((id)cls);
    if (meta && class_respondsToSelector(meta, sel)) {
        MSHookMessageEx(meta, sel, (IMP)eg_yes, NULL);
    }
}

static void eg_hookBoolSelectorEverywhere(const char *selName) {
    if (!selName) return;
    SEL s = sel_getUid(selName);
    int n = objc_getClassList(NULL, 0);
    if (n <= 0) return;
    Class *list = (Class *)malloc(sizeof(Class) * n);
    n = objc_getClassList(list, n);
    for (int i = 0; i < n; i++) {
        eg_hookBoolSelectorOn(list[i], s);
    }
    free(list);
}

%ctor {
    @autoreleasepool {
        const char *keys[] = {
            "_METAGetOverrideLiquidGlassEnabledKey",
            "_METAGetLiquidGlassSolariumKey",
            "_METAGetLiquidGlassCompatibilityKey",
        };
        for (unsigned i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) eg_forceMetaKeyYES(keys[i]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (unsigned i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) eg_forceMetaKeyYES(keys[i]);
        });
        const char *boolSels[] = {
            "_METAIsLiquidGlassEnabled",
            "isMediaLiquidGlassEnabled",
            "isLiquidGlassLayoutInMediaBrowserEnabled",
            "isNewLiquidGlassLayoutEnabled",
            "hasLiquidGlassLaunched",
        };
        for (unsigned j = 0; j < sizeof(boolSels)/sizeof(boolSels[0]); j++) eg_hookBoolSelectorEverywhere(boolSels[j]);
        const char *swiftCandidates[] = {
            "WAUIKit.LiquidGlass",
            "LiquidGlass",
            "_TtC7WAUIKit12LiquidGlass",
        };
        const char *swiftBoolSels[] = {
            "isM0Enabled",
            "isM1Enabled",
            "isEnabled",
        };
        for (unsigned i = 0; i < sizeof(swiftCandidates)/sizeof(swiftCandidates[0]); i++) {
            Class c = objc_getClass(swiftCandidates[i]);
            if (!c) continue;
            for (unsigned k = 0; k < sizeof(swiftBoolSels)/sizeof(swiftBoolSels[0]); k++) {
                eg_hookBoolSelectorOn(c, sel_getUid(swiftBoolSels[k]));
            }
        }
    }
}

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride {
    @try {
        eg_forceMetaKeyYES("_METAGetOverrideLiquidGlassEnabledKey");
        eg_forceMetaKeyYES("_METAGetLiquidGlassSolariumKey");
        eg_forceMetaKeyYES("_METAGetLiquidGlassCompatibilityKey");
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
