// WAGramNativeSurfaceHooks.xm
// Runtime hooks for native, non-WAAB gates that control Developer menu,
// debug build AB Props availability, Waffle/PAA, and Multi Account tabbar surfaces.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../WAUtils.h"

typedef BOOL (*WAGRBoolIMP)(id, SEL);
typedef id   (*WAGRIdIMP)(id, SEL, id);
typedef NSString *(*WAGRStringFn)(void);

static NSMutableDictionary<NSString *, NSValue *> *gWAGRNativeOrig = nil;
static BOOL gWAGRNativeInstalled = NO;

static WAGRStringFn orig_WAAppVersion = NULL;
static WAGRStringFn orig_WABuildNumber = NULL;
static WAGRStringFn orig_FBBuildAppVersion = NULL;
static WAGRStringFn orig_FBBuildNumber = NULL;
static WAGRIdIMP orig_NSBundleObjectForInfoDictionaryKey = NULL;

static BOOL WAGRDebugSurfaceEnabled(void) {
    return WAEnabled(kWAGRDebugMenuNative) || WAEnabled(kWAGRDebugMode) || WAEnabled(kWAGRInternalMaster) || WAEnabled(kWAGREmployeeMaster);
}

static BOOL WAGREmployeeSurfaceEnabled(void) {
    return WAEnabled(kWAGREmployeeMaster) || WAEnabled(kWAGRInternalMaster) || WAEnabled(kWAGRDebugMenuNative);
}

static BOOL WAGRMultiAccountSurfaceEnabled(void) {
    return WAGRIsOn(@"sg_ios_multi_account_enabled") ||
           WAGRIsOn(@"wa_xfam_ios_switcher_multiaccount_enabled") ||
           WAGRIsOn(@"foa_bridges_account_switcher_ios_enabled") ||
           WAEnabled(kWAGRDebugMenuNative) ||
           WAEnabled(kWAGREmployeeMaster);
}

static NSString *WAGRNativeKey(Class cls, BOOL meta, SEL sel) {
    return [NSString stringWithFormat:@"%s%c%@", class_getName(cls), meta ? '+' : '-', NSStringFromSelector(sel)];
}

static BOOL WAGRNativeBoolHook(id self, SEL _cmd) {
    NSString *name = NSStringFromSelector(_cmd);

    if ([name isEqualToString:@"graphQLEmployeeC1Disabled"]) {
        if (WAGREmployeeSurfaceEnabled()) return NO;
    }

    if ([name isEqualToString:@"isDebugMenuAllowed"] ||
        [name isEqualToString:@"isDebugBuild"] ||
        [name isEqualToString:@"isTestFlightApp"]) {
        if (WAGRDebugSurfaceEnabled()) return YES;
    }

    if ([name isEqualToString:@"isMetaEmployeeOrInternalTester"] ||
        [name isEqualToString:@"is_meta_employee_or_internal_tester"] ||
        [name isEqualToString:@"isInternalUser"]) {
        if (WAGREmployeeSurfaceEnabled()) return YES;
    }

    if ([name isEqualToString:@"isPAAEligibleForWaffle"]) {
        if (WAGRIsOn(@"waffle_mobile_companions_enabled") || WAGRIsOn(@"waffle_enabled_for_unlinked_users") || WAGREmployeeSurfaceEnabled()) return YES;
    }

    if ([name isEqualToString:@"isMultiAccountEnabled"] ||
        [name isEqualToString:@"shouldSurfaceMultiAccount"]) {
        if (WAGRMultiAccountSurfaceEnabled()) return YES;
    }

    Class cls = object_getClass(self);
    BOOL meta = class_isMetaClass(cls);
    Class real = meta ? (Class)self : cls;
    NSString *key = WAGRNativeKey(real, meta, _cmd);
    WAGRBoolIMP orig = NULL;
    NSValue *v = [gWAGRNativeOrig objectForKey:key];
    if (v) orig = (WAGRBoolIMP)[v pointerValue];
    return orig ? orig(self, _cmd) : NO;
}

static void WAGRNativeHookBoolMethod(Class cls, BOOL meta, const char *selName) {
    if (!cls || !selName || !*selName) return;
    Class target = meta ? object_getClass(cls) : cls;
    SEL sel = sel_registerName(selName);
    Method m = meta ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!m) return;
    if (method_getNumberOfArguments(m) != 2) return;
    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    if (ret[0] != 'B' && ret[0] != 'c') return;

    NSString *key = WAGRNativeKey(cls, meta, sel);
    if ([gWAGRNativeOrig objectForKey:key]) return;

    IMP orig = NULL;
    MSHookMessageEx(target, sel, (IMP)WAGRNativeBoolHook, &orig);
    if (orig) [gWAGRNativeOrig setObject:[NSValue valueWithPointer:(void *)orig] forKey:key];
}

static void WAGRNativeScanAndHookSelector(const char *selName) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return;
    Class *classes = (Class *)calloc((NSUInteger)count, sizeof(Class));
    if (!classes) return;
    objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        WAGRNativeHookBoolMethod(classes[i], NO, selName);
        WAGRNativeHookBoolMethod(classes[i], YES, selName);
    }
    free(classes);
}

static NSString *repl_WAAppVersion(void) {
    return WAGRDebugSurfaceEnabled() ? @"2.26.19.69" : (orig_WAAppVersion ? orig_WAAppVersion() : nil);
}
static NSString *repl_FBBuildAppVersion(void) {
    return WAGRDebugSurfaceEnabled() ? @"2.26.19.69" : (orig_FBBuildAppVersion ? orig_FBBuildAppVersion() : nil);
}
static NSString *repl_WABuildNumber(void) {
    return WAGRDebugSurfaceEnabled() ? @"69" : (orig_WABuildNumber ? orig_WABuildNumber() : nil);
}
static NSString *repl_FBBuildNumber(void) {
    return WAGRDebugSurfaceEnabled() ? @"69" : (orig_FBBuildNumber ? orig_FBBuildNumber() : nil);
}

static id repl_NSBundleObjectForInfoDictionaryKey(NSBundle *self, SEL _cmd, id key) {
    if (WAGRDebugSurfaceEnabled() && self == [NSBundle mainBundle] && [key isKindOfClass:NSString.class]) {
        NSString *k = (NSString *)key;
        if ([k isEqualToString:@"CFBundleShortVersionString"]) return @"2.26.19.69";
        if ([k isEqualToString:@"CFBundleVersion"]) return @"69";
    }
    return orig_NSBundleObjectForInfoDictionaryKey ? orig_NSBundleObjectForInfoDictionaryKey(self, _cmd, key) : nil;
}

static void WAGRHookVersionFunction(const char *symbol, void *replacement, void **origOut) {
    void *sym = dlsym(RTLD_DEFAULT, symbol);
    if (sym) MSHookFunction(sym, replacement, origOut);
}

extern "C" void WAGRNativeSurfaceEnsureHooksInstalled(void) {
    if (gWAGRNativeInstalled) return;
    gWAGRNativeInstalled = YES;
    if (!gWAGRNativeOrig) gWAGRNativeOrig = [NSMutableDictionary dictionary];

    const char *selectors[] = {
        "isDebugMenuAllowed",
        "isDebugBuild",
        "isTestFlightApp",
        "isMetaEmployeeOrInternalTester",
        "is_meta_employee_or_internal_tester",
        "isInternalUser",
        "graphQLEmployeeC1Disabled",
        "isPAAEligibleForWaffle",
        "isMultiAccountEnabled",
        "shouldSurfaceMultiAccount",
        NULL
    };
    for (int i = 0; selectors[i]; i++) WAGRNativeScanAndHookSelector(selectors[i]);

    WAGRHookVersionFunction("WAAppVersion", (void *)repl_WAAppVersion, (void **)&orig_WAAppVersion);
    WAGRHookVersionFunction("_WAAppVersion", (void *)repl_WAAppVersion, (void **)&orig_WAAppVersion);
    WAGRHookVersionFunction("FBBuildAppVersion", (void *)repl_FBBuildAppVersion, (void **)&orig_FBBuildAppVersion);
    WAGRHookVersionFunction("_FBBuildAppVersion", (void *)repl_FBBuildAppVersion, (void **)&orig_FBBuildAppVersion);
    WAGRHookVersionFunction("WABuildNumber", (void *)repl_WABuildNumber, (void **)&orig_WABuildNumber);
    WAGRHookVersionFunction("_WABuildNumber", (void *)repl_WABuildNumber, (void **)&orig_WABuildNumber);
    WAGRHookVersionFunction("FBBuildNumber", (void *)repl_FBBuildNumber, (void **)&orig_FBBuildNumber);
    WAGRHookVersionFunction("_FBBuildNumber", (void *)repl_FBBuildNumber, (void **)&orig_FBBuildNumber);

    IMP orig = NULL;
    MSHookMessageEx(NSBundle.class,
                    @selector(objectForInfoDictionaryKey:),
                    (IMP)repl_NSBundleObjectForInfoDictionaryKey,
                    &orig);
    if (orig) orig_NSBundleObjectForInfoDictionaryKey = (WAGRIdIMP)orig;

    NSLog(@"[WAGram][NativeSurface] installed: %lu bool methods", (unsigned long)gWAGRNativeOrig.count);
}

extern "C" NSString *WAGRNativeSurfaceDiagnosticText(void) {
    return [NSString stringWithFormat:
            @"native hooks installed=%@\n"
             "hooked bool methods=%lu\n"
             "debug surface=%@\n"
             "employee/internal surface=%@\n"
             "multiaccount surface=%@\n"
             "debug version override=%@\n"
             "forced app version=2.26.19.69 / build 69",
            gWAGRNativeInstalled ? @"YES" : @"NO",
            (unsigned long)gWAGRNativeOrig.count,
            WAGRDebugSurfaceEnabled() ? @"ON" : @"OFF",
            WAGREmployeeSurfaceEnabled() ? @"ON" : @"OFF",
            WAGRMultiAccountSurfaceEnabled() ? @"ON" : @"OFF",
            WAGRDebugSurfaceEnabled() ? @"ON" : @"OFF"];
}

__attribute__((constructor))
static void WAGRNativeSurfaceCtor(void) {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            WAGRNativeSurfaceEnsureHooksInstalled();
        });
    }
}
