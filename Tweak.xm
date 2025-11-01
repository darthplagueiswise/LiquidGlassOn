#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import <substrate.h>

static BOOL retYES(id self, SEL _cmd) { return YES; }

static void forceMetaKeyBoolYES(const char *selName) {
    Class cls = objc_getClass("SharedModules");
    if (!cls || !selName) return;
    SEL sel = sel_getUid(selName);
    if (class_respondsToSelector(cls, sel)) {
        NSString *key = ((NSString *(*)(id, SEL))objc_msgSend)(cls, sel);
        if ([key isKindOfClass:[NSString class]] && key.length) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
}

static void hookBoolSelectorOnClass(Class cls, SEL sel) {
    if (!cls || !sel) return;
    if (class_respondsToSelector(cls, sel)) {
        MSHookMessageEx(cls, sel, (IMP)retYES, NULL);
    }
    Class meta = object_getClass((id)cls);
    if (meta && class_respondsToSelector(meta, sel)) {
        MSHookMessageEx(meta, sel, (IMP)retYES, NULL);
    }
}

static void hookBoolSelectorEverywhere(const char *selName) {
    if (!selName) return;
    SEL sel = sel_getUid(selName);
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    count = objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        hookBoolSelectorOnClass(classes[i], sel);
    }
    free(classes);
}

%ctor {
    @autoreleasepool {
        const char *keys[] = {
            "_METAGetOverrideLiquidGlassEnabledKey",
            "_METAGetLiquidGlassSolariumKey",
            "_METAGetLiquidGlassCompatibilityKey",
        };
        for (unsigned i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
            forceMetaKeyBoolYES(keys[i]);
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (unsigned i = 0; i < sizeof(keys)/sizeof(keys[0]); i++) {
                forceMetaKeyBoolYES(keys[i]);
            }
        });
        const char *boolSels[] = {
            "_METAIsLiquidGlassEnabled",
            "isMediaLiquidGlassEnabled",
            "isLiquidGlassLayoutInMediaBrowserEnabled",
            "isNewLiquidGlassLayoutEnabled",
            "hasLiquidGlassLaunched",
        };
        for (unsigned j = 0; j < sizeof(boolSels)/sizeof(boolSels[0]); j++) {
            hookBoolSelectorEverywhere(boolSels[j]);
        }
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
                hookBoolSelectorOnClass(c, sel_getUid(swiftBoolSels[k]));
            }
        }
    }
}

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride {
    @try {
        forceMetaKeyBoolYES("_METAGetOverrideLiquidGlassEnabledKey");
        forceMetaKeyBoolYES("_METAGetLiquidGlassSolariumKey");
        forceMetaKeyBoolYES("_METAGetLiquidGlassCompatibilityKey");
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
