// WAGramDirectFlagHooks.xm
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static NSMutableDictionary<NSString *, NSNumber *> *gWAGDirectOrig = nil;
static NSMutableSet<NSString *> *gWAGDirectInstalled = nil;
static dispatch_queue_t gWAGDirectQueue = nil;
static BOOL gWAGDirectDidInit = NO;
static NSUInteger gWAGDirectHookCount = 0;

static void WAGDirectInitStorage(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gWAGDirectOrig = [NSMutableDictionary dictionary];
        gWAGDirectInstalled = [NSMutableSet set];
        gWAGDirectQueue = dispatch_queue_create("com.wagr.direct.flags", DISPATCH_QUEUE_SERIAL);
    });
}

static NSString *WAGDirectKeyFromModePref(NSString *pref) {
    NSString *prefix = @"wagr.waab.";
    NSString *suffix = @".mode";
    if (![pref hasPrefix:prefix] || ![pref hasSuffix:suffix]) return nil;
    NSUInteger len = pref.length - prefix.length - suffix.length;
    return len ? [pref substringWithRange:NSMakeRange(prefix.length, len)] : nil;
}

static NSInteger WAGDirectModeForSelector(SEL sel) {
    NSString *key = NSStringFromSelector(sel);
    return [NSUserDefaults.standardUserDefaults integerForKey:WAGRWAABKeyMode(key)];
}

static BOOL WAGDirectBoolHook(id self, SEL _cmd) {
    NSInteger mode = WAGDirectModeForSelector(_cmd);
    if (mode == 1) return NO;
    if (mode == 2) return YES;

    NSString *sig = [NSString stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    NSNumber *stored = gWAGDirectOrig[sig];
    BOOL (*orig)(id, SEL) = stored ? (BOOL (*)(id, SEL))(uintptr_t)[stored unsignedLongLongValue] : NULL;
    return orig ? orig(self, _cmd) : NO;
}

static BOOL WAGDirectClassLooksRelevant(Class cls) {
    if (!cls) return NO;
    NSString *n = NSStringFromClass(cls);
    return [n containsString:@"WAABProperties"] ||
           [n containsString:@"ABProperties"] ||
           [n containsString:@"MetaConfig"] ||
           [n containsString:@"MobileConfig"] ||
           [n containsString:@"Experiment"] ||
           [n containsString:@"Gating"] ||
           [n containsString:@"Debug"] ||
           [n containsString:@"Dogfood"] ||
           [n containsString:@"Feature"];
}

static BOOL WAGDirectMethodLooksBoolNoArg(Method m) {
    if (!m) return NO;
    if (method_getNumberOfArguments(m) != 2) return NO;
    char ret[32] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    return ret[0] == 'B' || ret[0] == 'c';
}

static void WAGDirectTryHook(Class cls, SEL sel, BOOL classMethod) {
    if (!cls || !sel) return;
    Method m = classMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!WAGDirectMethodLooksBoolNoArg(m)) return;
    Class target = classMethod ? object_getClass(cls) : cls;
    if (!target) return;

    NSString *sig = [NSString stringWithFormat:@"%@/%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
    if ([gWAGDirectInstalled containsObject:sig]) return;

    IMP orig = NULL;
    MSHookMessageEx(target, sel, (IMP)WAGDirectBoolHook, &orig);
    if (orig) gWAGDirectOrig[sig] = @((unsigned long long)(uintptr_t)orig);
    [gWAGDirectInstalled addObject:sig];
    gWAGDirectHookCount++;
    NSLog(@"[WAGram][DirectFlags] hooked %@[%@ %@]", classMethod ? @"+" : @"-", NSStringFromClass(cls), NSStringFromSelector(sel));
}

static NSArray<NSString *> *WAGDirectActiveKeys(void) {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    NSDictionary *dict = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (NSString *pref in dict) {
        NSString *key = WAGDirectKeyFromModePref(pref);
        if (!key.length) continue;
        NSInteger mode = [dict[pref] respondsToSelector:@selector(integerValue)] ? [dict[pref] integerValue] : 0;
        if (mode == 1 || mode == 2) [out addObject:key];
    }
    return out;
}

static void WAGDirectPersistDefaultsForActiveKeys(void) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    for (NSString *key in WAGDirectActiveKeys()) {
        NSInteger mode = [ud integerForKey:WAGRWAABKeyMode(key)];
        if (mode == 2) [ud setBool:YES forKey:key];
        else if (mode == 1) [ud setBool:NO forKey:key];
    }
    [ud synchronize];
}

static void WAGDirectInstallForActiveKeys(void) {
    WAGDirectInitStorage();
    WAGDirectPersistDefaultsForActiveKeys();
    NSArray<NSString *> *keys = WAGDirectActiveKeys();
    if (!keys.count) return;

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) return;

    for (NSString *key in keys) {
        SEL sel = NSSelectorFromString(key);
        for (unsigned int i = 0; i < count; i++) {
            Class cls = classes[i];
            if (!WAGDirectClassLooksRelevant(cls)) continue;
            WAGDirectTryHook(cls, sel, NO);
            WAGDirectTryHook(cls, sel, YES);
        }
    }

    free(classes);
    gWAGDirectDidInit = YES;
}

extern "C" void WAGRDirectFlagsEnsureHooksInstalled(void) {
    WAGDirectInitStorage();
    dispatch_async(gWAGDirectQueue, ^{ WAGDirectInstallForActiveKeys(); });
}

extern "C" NSString *WAGRDirectFlagsDiagnosticText(void) {
    WAGDirectInitStorage();
    return [NSString stringWithFormat:@"direct runtime=%@\nactive keys=%lu\nhooked selectors=%lu\nmodel=NSUserDefaults + direct bool selectors",
            gWAGDirectDidInit ? @"ON" : @"IDLE",
            (unsigned long)WAGDirectActiveKeys().count,
            (unsigned long)gWAGDirectHookCount];
}

__attribute__((constructor))
static void WAGDirectFlagsInit(void) {
    @autoreleasepool {
        WAGDirectInitStorage();
        double delays[] = {0.2, 1.0, 3.0, 6.0};
        for (size_t i = 0; i < 4; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGDirectInstallForActiveKeys(); });
        }
    }
}
