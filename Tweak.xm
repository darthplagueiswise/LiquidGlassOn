// EnableLiquidGlass — no-substrate, type-safe hooks
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dispatch/dispatch.h>

// ---- Helpers (BOOL shims) ----
static BOOL eg_yes0(id self, SEL _cmd) { return YES; }
static BOOL eg_yes1(id self, SEL _cmd, id a1) { (void)a1; return YES; }

static BOOL eg_isBoolReturn(Method m) {
    if (!m) return NO;
    char rt[8] = {0};
    method_getReturnType(m, rt, sizeof(rt));
    return (rt[0] == 'B' || rt[0] == 'c');
}

static void eg_tryHookMethod(Method m) {
    if (!m) return;
    if (!eg_isBoolReturn(m)) return;
    unsigned nargs = method_getNumberOfArguments(m);
    IMP newImp = NULL;
    if (nargs == 2) newImp = (IMP)eg_yes0;
    else if (nargs == 3) newImp = (IMP)eg_yes1;
    else return;
    method_setImplementation(m, newImp);
}

static void eg_safeHookSelectorOnClass(Class cls, SEL sel) {
    if (!cls || !sel) return;
    Method inst = class_getInstanceMethod(cls, sel);
    if (inst) eg_tryHookMethod(inst);
    Class meta = object_getClass((id)cls);
    if (meta) {
        Method clz = class_getClassMethod(cls, sel);
        if (clz) eg_tryHookMethod(clz);
    }
}

static void eg_hookBoolSelectorEverywhere(const char *selName) {
    if (!selName) return;
    SEL s = sel_getUid(selName);
    int n = objc_getClassList(NULL, 0);
    if (n <= 0) return;
    Class *list = (Class *)malloc(sizeof(Class)*n);
    n = objc_getClassList(list, n);
    for (int i = 0; i < n; i++) eg_safeHookSelectorOnClass(list[i], s);
    free(list);
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

static const char *const kMetaKeys[] = {
    "_METAGetOverrideLiquidGlassEnabledKey",
    "_METAGetLiquidGlassSolariumKey",
    "_METAGetLiquidGlassCompatibilityKey",
};
static const unsigned kMetaKeysCount = (unsigned)(sizeof(kMetaKeys)/sizeof(kMetaKeys[0]));

__attribute__((constructor)) static void eg_boot(void) {
    @autoreleasepool {
        for (unsigned i = 0; i < kMetaKeysCount; i++) eg_forceMetaKeyYES(kMetaKeys[i]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            for (unsigned i = 0; i < kMetaKeysCount; i++) eg_forceMetaKeyYES(kMetaKeys[i]);
        });

        const char *boolSels[] = {
            "_METAIsLiquidGlassEnabled",
            "isMediaLiquidGlassEnabled",
            "isLiquidGlassLayoutInMediaBrowserEnabled",
            "isNewLiquidGlassLayoutEnabled",
            "hasLiquidGlassLaunched",
        };
        for (unsigned j = 0; j < sizeof(boolSels)/sizeof(boolSels[0]); j++) eg_hookBoolSelectorEverywhere(boolSels[j]);

        const char *swiftCandidates[] = { "WAUIKit.LiquidGlass", "LiquidGlass", "_TtC7WAUIKit12LiquidGlass" };
        const char *swiftBools[] = { "isM0Enabled", "isM1Enabled", "isEnabled" };
        for (unsigned i = 0; i < sizeof(swiftCandidates)/sizeof(swiftCandidates[0]); i++) {
            Class c = objc_getClass(swiftCandidates[i]);
            if (!c) continue;
            for (unsigned k = 0; k < sizeof(swiftBools)/sizeof(swiftBools[0]); k++)
                eg_safeHookSelectorOnClass(c, sel_getUid(swiftBools[k]));
        }
    }
}
