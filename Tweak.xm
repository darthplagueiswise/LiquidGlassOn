#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>
#import <substrate.h>

static BOOL yesBool(id self, SEL _cmd) { return YES; }
static BOOL yesBoolWithArg(id self, SEL _cmd, id arg) { (void)arg; return YES; }

static void setMetaKeys(void) {
    @autoreleasepool {
        id shared = objc_getClass("SharedModules");
        NSArray<NSString *> *selNames = @[
            @"_METAGetOverrideLiquidGlassEnabledKey",
            @"_METAGetLiquidGlassSolariumKey",
            @"_METAGetLiquidGlassCompatibilityKey"
        ];
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        for (NSString *s in selNames) {
            SEL sel = sel_getUid(s.UTF8String);
            if (shared && class_respondsToSelector((Class)shared, sel)) {
                NSString *key = ((NSString *(*)(id, SEL))objc_msgSend)(shared, sel);
                if (key.length) { [ud setBool:YES forKey:key]; }
            }
        }
        [ud synchronize];
    }
}

static void hookBoolSelector(Class c, SEL sel, BOOL isClassMethod) {
    if (!c || !sel) return;
    Class target = isClassMethod ? object_getClass(c) : c;
    Method m = isClassMethod ? class_getClassMethod(c, sel) : class_getInstanceMethod(c, sel);
    if (!m) return;
    const char *types = method_getTypeEncoding(m);
    IMP rep = (IMP)yesBool;
    // If method takes one arg (like -isBucketEnabled:) keep compatible signature
    if (types && strchr(types, ':') && strchr(strchr(types, ':')+1, ':')) {
        rep = (IMP)yesBoolWithArg;
    }
    MSHookMessageEx(target, sel, rep, NULL);
}

%ctor {
    setMetaKeys();

    // Broad scan for known selectors
    SEL sels[] = {
        sel_getUid("_METAIsLiquidGlassEnabled"),
        sel_getUid("isMediaLiquidGlassEnabled"),
        sel_getUid("isLiquidGlassLayoutInMediaBrowserEnabled"),
        sel_getUid("isNewLiquidGlassLayoutEnabled"),
        sel_getUid("hasLiquidGlassLaunched")
    };
    int numSels = sizeof(sels)/sizeof(SEL);

    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)calloc(numClasses, sizeof(Class));
    if (classes && numClasses > 0) {
        objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class c = classes[i];
            if (!c) continue;
            for (int j = 0; j < numSels; j++) {
                SEL s = sels[j];
                if (class_respondsToSelector((Class)c, s)) hookBoolSelector(c, s, true);
                if (class_getInstanceMethod(c, s)) hookBoolSelector(c, s, false);
            }
        }
    }
    if (classes) free(classes);

    // Swift bridge if visible to ObjC: WAUIKit.LiquidGlass
    Class swiftLG = NSClassFromString(@"WAUIKit.LiquidGlass");
    if (swiftLG) {
        SEL k0 = sel_getUid("isM0Enabled");
        SEL k1 = sel_getUid("isM1Enabled");
        SEL ke = sel_getUid("isEnabled");
        hookBoolSelector(swiftLG, k0, true);
        hookBoolSelector(swiftLG, k1, true);
        hookBoolSelector(swiftLG, ke, true);
    }

    // After launch, reinforce META keys in case remote overrides arrive late
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setMetaKeys();
    });
}

%hook WDSLiquidGlass
+ (BOOL)isNewLiquidGlassLayoutEnabled { return YES; }
- (BOOL)hasLiquidGlassLaunched { return YES; }
%end

%hook SharedModules
- (void)_WAApplyLiquidGlassOverride { setMetaKeys(); %orig; }
%end

%hook WAABExperimentManager
- (BOOL)isBucketEnabled:(id)bucket { return YES; }
%end
