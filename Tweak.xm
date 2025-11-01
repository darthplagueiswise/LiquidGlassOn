#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import <substrate.h>

// ---- helpers ----
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
    // instance
    if (class_respondsToSelector(cls, sel)) {
        MSHookMessageEx(cls, sel, (IMP)eg_yes, NULL);
    }
    // class
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
        // -- META keys (do early, and again after 1s)
        static const char *const kKeys[] = {
            "_METAGetOverrideLiquidGlassEnabledKey",
            "_METAGetLiquidGlassSolariumKey",
            "_METAGetLiquidGlassCompatibilityKey",
        };
        const size_t keysCount = sizeof(kKeys)/sizeof(kKeys[0]);
        const char *const *keysPtr = kKeys;
        for (size_t i = 0; i < keysCount; i++) eg_forceMetaKeyYES(keysPtr[i]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (size_t i = 0; i < keysCount; i++) eg_forceMetaKeyYES(keysPtr[i]);
        });

        // -- generic bool selectors everywhere
        static const char *const boolSels[] = {
            "_METAIsLiquidGlassEnabled",
            "isMediaLiquidGlassEnabled",
            "isLiquidGlassLayoutInMediaBrowserEnabled",
            "isNewLiquidGlassLayoutEnabled",
            "hasLiquidGlassLaunched",
        };
        const size_t bcnt = sizeof(boolSels)/sizeof(boolSels[0]);
        for (size_t j = 0; j < bcnt; j++) eg_hookBoolSelectorEverywhere(boolSels[j]);

        // -- Swift bridge candidates (if ObjC-visible)
        static const char *const swiftCandidates[] = {
            "WAUIKit.LiquidGlass",
            "LiquidGlass",
            "_TtC7WAUIKit12LiquidGlass",
        };
        static const char *const swiftSels[] = {
            "isM0Enabled", "isM1Enabled", "isEnabled",
        };
        const size_t scnt = sizeof(swiftCandidates)/sizeof(swiftCandidates[0]);
        const size_t sscnt = sizeof(swiftSels)/sizeof(swiftSels[0]);
        for (size_t i = 0; i < scnt; i++) {
            Class c = objc_getClass(swiftCandidates[i]);
            if (!c) continue;
            for (size_t k = 0; k < sscnt; k++) { eg_hookBoolSelectorOn(c, sel_getUid(swiftSels[k])); }
        }
    }
}

// reinforce when remote overrides apply
%hook SharedModules
- (void)_WAApplyLiquidGlassOverride {
    eg_forceMetaKeyYES("_METAGetOverrideLiquidGlassEnabledKey");
    eg_forceMetaKeyYES("_METAGetLiquidGlassSolariumKey");
    eg_forceMetaKeyYES("_METAGetLiquidGlassCompatibilityKey");
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
