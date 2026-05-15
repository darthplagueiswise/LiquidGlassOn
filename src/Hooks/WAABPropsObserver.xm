// WAABPropsObserver.xm
// ─────────────────────────────────────────────────────────────────────────────
// Typed observer + override layer for WAABProperties getters.
//
// Confirmed getter surface from SharedModules(3) + WhatsApp main executable:
//   boolForKey:defaultValue:
//   stringForKey:defaultValue:
//   integerForKey:defaultValue:
//   doubleForKey:defaultValue:
//
// mode: 0=System, 1=Force OFF/0/empty, 2=Force ON/1/enabled.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

#define WAGR_ABOBS_RINGSIZE 200

static NSMutableArray<NSString *> *_wagrABLog = nil;
static dispatch_queue_t _wagrABQueue = nil;
static dispatch_once_t _wagrABInitOnce = 0;
static BOOL _wagrABHooksInstalled = NO;
static dispatch_once_t _wagrABInstallOnce = 0;

static BOOL (*orig_WAABBool)(id, SEL, NSString *, BOOL) = NULL;
static id (*orig_WAABString)(id, SEL, NSString *, id) = NULL;
static NSInteger (*orig_WAABInteger)(id, SEL, NSString *, NSInteger) = NULL;
static double (*orig_WAABDouble)(id, SEL, NSString *, double) = NULL;

static void WAGRABEnsureStorage(void) {
    dispatch_once(&_wagrABInitOnce, ^{
        _wagrABLog = [NSMutableArray arrayWithCapacity:WAGR_ABOBS_RINGSIZE];
        _wagrABQueue = dispatch_queue_create("com.wagr.waab.observer", DISPATCH_QUEUE_SERIAL);
    });
}

static void WAGRABAppend(NSString *entry) {
    if (!entry) return;
    WAGRABEnsureStorage();
    dispatch_async(_wagrABQueue, ^{
        if (_wagrABLog.count >= WAGR_ABOBS_RINGSIZE) [_wagrABLog removeObjectAtIndex:0];
        [_wagrABLog addObject:entry];
    });
}

static BOOL WAGRWAABHasActiveOverrides(void) {
    NSDictionary *dict = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (NSString *k in dict) {
        if (![k hasPrefix:@"wagr.waab."] || ![k hasSuffix:@".mode"]) continue;
        NSInteger mode = [dict[k] respondsToSelector:@selector(integerValue)] ? [dict[k] integerValue] : 0;
        if (mode != 0) return YES;
    }
    return NO;
}

static void WAGRWAABRememberRuntime(NSString *key, NSString *type, id value) {
    if (!key.length || !type.length) return;
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    [ud setObject:type forKey:WAGRWAABKeyRuntimeType(key)];
    if (value) [ud setObject:[value description] forKey:WAGRWAABKeyRuntimeValue(key)];
}

static void WAGRABLogGetter(NSString *type, id self, SEL _cmd, NSString *key, id value, BOOL overridden) {
    if (!WAGRPref(kWAGRABPropsObserver) && !overridden) return;
    NSString *entry = [NSString stringWithFormat:@"[WAAB] %@ -[%@ %@] key=%@ value=%@%@",
                       type ?: @"?",
                       NSStringFromClass([self class]),
                       NSStringFromSelector(_cmd),
                       key ?: @"(nil)",
                       value ?: @"nil",
                       overridden ? @" OVERRIDDEN" : @""];
    WAGRABAppend(entry);
    if (WAGRPref(kWAGRDebugMode)) NSLog(@"[WAGram]%@", entry);
}

static BOOL hook_WAABBool(id self, SEL _cmd, NSString *key, BOOL defaultValue) {
    BOOL original = orig_WAABBool ? orig_WAABBool(self, _cmd, key, defaultValue) : defaultValue;
    WAGRWAABRememberRuntime(key, @"bool", @(original));
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:WAGRWAABKeyMode(key)];
    if (mode == 1) { WAGRABLogGetter(@"bool", self, _cmd, key, @NO, YES); return NO; }
    if (mode == 2) { WAGRABLogGetter(@"bool", self, _cmd, key, @YES, YES); return YES; }
    WAGRABLogGetter(@"bool", self, _cmd, key, @(original), NO);
    return original;
}

static id hook_WAABString(id self, SEL _cmd, NSString *key, id defaultValue) {
    id original = orig_WAABString ? orig_WAABString(self, _cmd, key, defaultValue) : defaultValue;
    WAGRWAABRememberRuntime(key, @"string", original ?: @"");
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:WAGRWAABKeyMode(key)];
    if (mode == 1) {
        WAGRABLogGetter(@"string", self, _cmd, key, @"", YES);
        return @"";
    }
    if (mode == 2) {
        NSString *forced = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRWAABKeyString(key)] ?: @"enabled";
        WAGRABLogGetter(@"string", self, _cmd, key, forced, YES);
        return forced;
    }
    WAGRABLogGetter(@"string", self, _cmd, key, original ?: @"nil", NO);
    return original;
}

static NSInteger hook_WAABInteger(id self, SEL _cmd, NSString *key, NSInteger defaultValue) {
    NSInteger original = orig_WAABInteger ? orig_WAABInteger(self, _cmd, key, defaultValue) : defaultValue;
    WAGRWAABRememberRuntime(key, @"integer", @(original));
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:WAGRWAABKeyMode(key)];
    if (mode == 1) {
        WAGRABLogGetter(@"integer", self, _cmd, key, @0, YES);
        return 0;
    }
    if (mode == 2) {
        id stored = [NSUserDefaults.standardUserDefaults objectForKey:WAGRWAABKeyNumber(key)];
        NSInteger forced = stored ? [stored integerValue] : 1;
        WAGRABLogGetter(@"integer", self, _cmd, key, @(forced), YES);
        return forced;
    }
    WAGRABLogGetter(@"integer", self, _cmd, key, @(original), NO);
    return original;
}

static double hook_WAABDouble(id self, SEL _cmd, NSString *key, double defaultValue) {
    double original = orig_WAABDouble ? orig_WAABDouble(self, _cmd, key, defaultValue) : defaultValue;
    WAGRWAABRememberRuntime(key, @"double", @(original));
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:WAGRWAABKeyMode(key)];
    if (mode == 1) {
        WAGRABLogGetter(@"double", self, _cmd, key, @0, YES);
        return 0.0;
    }
    if (mode == 2) {
        id stored = [NSUserDefaults.standardUserDefaults objectForKey:WAGRWAABKeyNumber(key)];
        double forced = stored ? [stored doubleValue] : 1.0;
        WAGRABLogGetter(@"double", self, _cmd, key, @(forced), YES);
        return forced;
    }
    WAGRABLogGetter(@"double", self, _cmd, key, @(original), NO);
    return original;
}

static BOOL WAGRABClassLooksRelevant(Class cls) {
    if (!cls) return NO;
    NSString *name = NSStringFromClass(cls);
    return [name containsString:@"WAABProperties"] ||
           [name containsString:@"ABProperties"] ||
           [name containsString:@"MetaConfig"] ||
           [name containsString:@"MobileConfig"];
}

static void WAGRABTryHook(Class cls, SEL sel, IMP hook, IMP *orig) {
    if (!cls || !sel || !hook || !orig || *orig) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    MSHookMessageEx(cls, sel, hook, orig);
    NSLog(@"[WAGram][WAAB] hooked -[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(sel));
}

extern "C" void WAGRWAABEnsureHooksInstalled(void) {
    WAGRABEnsureStorage();
    dispatch_once(&_wagrABInstallOnce, ^{
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        if (!classes) return;
        SEL boolSel = NSSelectorFromString(@"boolForKey:defaultValue:");
        SEL stringSel = NSSelectorFromString(@"stringForKey:defaultValue:");
        SEL integerSel = NSSelectorFromString(@"integerForKey:defaultValue:");
        SEL doubleSel = NSSelectorFromString(@"doubleForKey:defaultValue:");
        for (unsigned int i = 0; i < count; i++) {
            Class cls = classes[i];
            if (!WAGRABClassLooksRelevant(cls)) continue;
            WAGRABTryHook(cls, boolSel, (IMP)hook_WAABBool, (IMP *)&orig_WAABBool);
            WAGRABTryHook(cls, stringSel, (IMP)hook_WAABString, (IMP *)&orig_WAABString);
            WAGRABTryHook(cls, integerSel, (IMP)hook_WAABInteger, (IMP *)&orig_WAABInteger);
            WAGRABTryHook(cls, doubleSel, (IMP)hook_WAABDouble, (IMP *)&orig_WAABDouble);
        }
        free(classes);
        _wagrABHooksInstalled = YES;
        NSLog(@"[WAGram][WAAB] install pass complete");
    });
}

extern "C" NSString *WAGRABObsLog(void) {
    WAGRABEnsureStorage();
    __block NSArray<NSString *> *snap = nil;
    dispatch_sync(_wagrABQueue, ^{ snap = [_wagrABLog copy]; });
    return snap.count ? [snap componentsJoinedByString:@"\n"] : @"(no WAAB observations yet)";
}

extern "C" void WAGRABObsClear(void) {
    WAGRABEnsureStorage();
    dispatch_async(_wagrABQueue, ^{ [_wagrABLog removeAllObjects]; });
}

extern "C" NSString *WAGRWAABDiagnosticText(void) {
    return [NSString stringWithFormat:@"observer=%@\nhasActiveOverrides=%@\nhooksInstalled=%@\norig bool=%@\norig string=%@\norig integer=%@\norig double=%@",
            WAGRPref(kWAGRABPropsObserver) ? @"ON" : @"OFF",
            WAGRWAABHasActiveOverrides() ? @"YES" : @"NO",
            _wagrABHooksInstalled ? @"YES" : @"NO",
            orig_WAABBool ? @"found" : @"missing",
            orig_WAABString ? @"found" : @"missing",
            orig_WAABInteger ? @"found" : @"missing",
            orig_WAABDouble ? @"found" : @"missing"];
}

__attribute__((constructor))
static void WAGRABObsInit(void) {
    @autoreleasepool {
        WAGRABEnsureStorage();
        if (!WAGRPref(kWAGRABPropsObserver) && !WAGRWAABHasActiveOverrides()) {
            NSLog(@"[WAGram][WAAB] inert startup: observer OFF and no active overrides");
            return;
        }
        double delays[] = { 1.0, 3.0 };
        for (size_t i = 0; i < 2; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                WAGRWAABEnsureHooksInstalled();
            });
        }
    }
}
