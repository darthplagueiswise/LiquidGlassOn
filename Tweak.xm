#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>

// ---- Config --------------------------------------------------------------
// Selectors we want to force to YES (instance or class, depending on where they exist)
static const char *const kBoolSelectors[] = {
    "_METAIsLiquidGlassEnabled",
    "isMediaLiquidGlassEnabled",
    "isLiquidGlassLayoutInMediaBrowserEnabled",
    "isNewLiquidGlassLayoutEnabled",
    "hasLiquidGlassLaunched",
};
static const unsigned kBoolSelectorsCount = (unsigned)(sizeof(kBoolSelectors)/sizeof(kBoolSelectors[0]));

// Meta-key providers exposed by SharedModules we want to force to YES in NSUserDefaults
static const char *const kMetaKeys[] = {
    "_METAGetOverrideLiquidGlassEnabledKey",
    "_METAGetLiquidGlassSolariumKey",
    "_METAGetLiquidGlassCompatibilityKey",
};
static const unsigned kMetaKeysCount = (unsigned)(sizeof(kMetaKeys)/sizeof(kMetaKeys[0]));

// Swift-exposed candidates (if bridged to ObjC) where we might find simple BOOL getters
static const char *const kSwiftCandidates[] = { "WAUIKit.LiquidGlass", "LiquidGlass", "_TtC7WAUIKit12LiquidGlass" };
static const char *const kSwiftBoolProps[] = { "isM0Enabled", "isM1Enabled", "isEnabled" };

// ---- Helpers -------------------------------------------------------------
static BOOL eg_yes_0(id self, SEL _cmd) { return YES; }
static BOOL eg_yes_1(id self, SEL _cmd, id a0) { (void)a0; return YES; }

static BOOL eg_isBOOLReturn(Method m) {
    if (!m) return NO;
    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    return (ret[0] == 'B'); // ObjC BOOL
}

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

static void eg_tryHook(Class cls, SEL sel) {
    if (!cls || !sel) return;
    // Instance method
    Method m = class_getInstanceMethod(cls, sel);
    if (m && eg_isBOOLReturn(m)) {
        unsigned nargs = method_getNumberOfArguments(m);
        if (nargs == 2) { // (id, SEL)
            method_setImplementation(m, (IMP)eg_yes_0);
        } else if (nargs == 3) { // (id, SEL, id) — e.g., isBucketEnabled:
            method_setImplementation(m, (IMP)eg_yes_1);
        }
    }
    // Class method
    Method cm = class_getClassMethod(cls, sel);
    if (cm && eg_isBOOLReturn(cm)) {
        unsigned nargs = method_getNumberOfArguments(cm);
        Class meta = object_getClass(cls);
        if (meta) {
            if (nargs == 2) {
                method_setImplementation(cm, (IMP)eg_yes_0);
            } else if (nargs == 3) {
                method_setImplementation(cm, (IMP)eg_yes_1);
            }
        }
    }
}

static void eg_hookSelectorEverywhere(const char *selName) {
    if (!selName) return;
    SEL s = sel_getUid(selName);
    int n = objc_getClassList(NULL, 0);
    if (n <= 0) return;
    Class *list = (Class *)malloc(sizeof(Class)*n);
    n = objc_getClassList(list, n);
    for (int i = 0; i < n; i++) {
        eg_tryHook(list[i], s);
    }
    free(list);
}

static void eg_hookSwiftCandidates(void) {
    for (unsigned i = 0; i < sizeof(kSwiftCandidates)/sizeof(kSwiftCandidates[0]); i++) {
        Class c = objc_getClass(kSwiftCandidates[i]);
        if (!c) continue;
        for (unsigned j = 0; j < sizeof(kSwiftBoolProps)/sizeof(kSwiftBoolProps[0]); j++) {
            eg_tryHook(c, sel_getUid(kSwiftBoolProps[j]));
        }
    }
}

__attribute__((constructor)) static void EGInit(void) {
    @autoreleasepool {
        // Force meta keys immediately
        for (unsigned i = 0; i < kMetaKeysCount; i++) eg_forceMetaKeyYES(kMetaKeys[i]);
        // Re-apply shortly after launch (override remoto tardio)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (unsigned i = 0; i < kMetaKeysCount; i++) eg_forceMetaKeyYES(kMetaKeys[i]);
        });

        // Broad, but type-safe, only for BOOL-returning selectors
        for (unsigned j = 0; j < kBoolSelectorsCount; j++) eg_hookSelectorEverywhere(kBoolSelectors[j]);

        // Specific one-arg BOOL selectors
        Class AB = objc_getClass("WAABExperimentManager");
        if (AB) eg_tryHook(AB, sel_getUid("isBucketEnabled:"));

        // Swift bridges (if any)
        eg_hookSwiftCandidates();
    }
}
