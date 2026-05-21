// WAABPropsObserver.xm
// ─────────────────────────────────────────────────────────────────────────────
// Hooks ALL zero-argument BOOL methods on WAABProperties at startup.
// Storage: NSUserDefaults wagr.waab.<flag> = @"on" | @"off" | absent (system)
//
// Architecture (matches WALiquidGlass.dylib pattern):
//   • Scan WAABProperties class method list at %ctor time
//   • For each BOOL-returning, 0-arg method: MSHookMessageEx with generic hook
//   • Generic hook checks NSUserDefaults → returns YES/NO/original
//   • Also hooks boolForKey:defaultValue: as secondary fallback
//
// Confirmed: WAABProperties in SharedModules has ~2000 such methods.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

// ── Storage for original IMPs ─────────────────────────────────────────────────
static NSMutableDictionary<NSString *, NSValue *> *gWAABOrigImps  = nil;
static NSUInteger gWAABHookedCount = 0;
static BOOL gWAABHooksInstalled = NO;

// ── Ring-buffer log ───────────────────────────────────────────────────────────
#define WAGR_LOG_SIZE 300
static NSMutableArray<NSString *> *gWAABLog = nil;
static dispatch_queue_t gWAABQueue = nil;
static dispatch_once_t  gWAABStorageOnce = 0;

static void WAGRLogEnsure(void) {
    dispatch_once(&gWAABStorageOnce, ^{
        gWAABLog   = [NSMutableArray arrayWithCapacity:WAGR_LOG_SIZE];
        gWAABQueue = dispatch_queue_create("com.wagr.waab", DISPATCH_QUEUE_SERIAL);
        gWAABOrigImps = [NSMutableDictionary dictionaryWithCapacity:512];
    });
}
static void WAGRLogAppend(NSString *e) {
    if (!e) return;
    WAGRLogEnsure();
    dispatch_async(gWAABQueue, ^{
        if (gWAABLog.count >= WAGR_LOG_SIZE) [gWAABLog removeObjectAtIndex:0];
        [gWAABLog addObject:e];
    });
}

// ── Generic BOOL hook (every WAAB direct bool method shares this IMP) ─────────
static BOOL WAGRWAABGenericBoolHook(id self, SEL _cmd) {
    NSString *flag   = NSStringFromSelector(_cmd);
    NSString *udKey  = WAGRKey(flag);
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:udKey];
    if (!stored.length) {
        id b = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"wagr.override|waab|WAABProperties|inst|%@", flag]];
        if (b) stored = [b boolValue] ? @"on" : @"off";
    }

    BOOL result;
    BOOL overridden = NO;

    if ([stored isEqualToString:@"on"]) {
        result = YES; overridden = YES;
    } else if ([stored isEqualToString:@"off"]) {
        result = NO;  overridden = YES;
    } else {
        // Call original
        NSValue *origVal = gWAABOrigImps[flag];
        BOOL (*orig)(id, SEL) = origVal ? (BOOL (*)(id, SEL))[origVal pointerValue] : NULL;
        result = orig ? orig(self, _cmd) : NO;
    }

    if (WAGRPref(kWAGRABPropsObserver) || overridden) {
        WAGRLogAppend([NSString stringWithFormat:@"%@  %@ → %@",
                       overridden ? @"[OVERRIDE]" : @"[obs]",
                       flag, result ? @"YES" : @"NO"]);
    }
    return result;
}

// ── boolForKey:defaultValue: hook (secondary fallback / observer) ─────────────
static BOOL (*gOrigBoolForKey)(id, SEL, NSString *, BOOL) = NULL;

static BOOL WAGRBoolForKeyHook(id self, SEL _cmd, NSString *key, BOOL defaultVal) {
    BOOL original = gOrigBoolForKey ? gOrigBoolForKey(self, _cmd, key, defaultVal) : defaultVal;
    if (!key.length) return original;

    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(key)];
    if (!stored.length) {
        id b = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"wagr.override|waab|WAABProperties|inst|%@", key]];
        if (b) stored = [b boolValue] ? @"on" : @"off";
    }
    if ([stored isEqualToString:@"on"]) {
        WAGRLogAppend([NSString stringWithFormat:@"[OVERRIDE/boolKey] %@ → YES", key]);
        return YES;
    }
    if ([stored isEqualToString:@"off"]) {
        WAGRLogAppend([NSString stringWithFormat:@"[OVERRIDE/boolKey] %@ → NO", key]);
        return NO;
    }
    if (WAGRPref(kWAGRABPropsObserver))
        WAGRLogAppend([NSString stringWithFormat:@"[obs/boolKey] %@ → %@", key, original ? @"YES" : @"NO"]);
    return original;
}

// ── stringForKey:defaultValue: hook (string flags) ────────────────────────────
static id (*gOrigStringForKey)(id, SEL, NSString *, id) = NULL;

static id WAGRStringForKeyHook(id self, SEL _cmd, NSString *key, id defaultVal) {
    id original = gOrigStringForKey ? gOrigStringForKey(self, _cmd, key, defaultVal) : defaultVal;
    if (!key.length) return original;

    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(key)];
    if ([stored isEqualToString:@"on"])  return @"enabled";
    if ([stored isEqualToString:@"off"]) return @"";
    return original;
}

// ── Check if a method is a BOOL no-arg getter ─────────────────────────────────
static BOOL WAGRIsBoolNoArgMethod(Method m) {
    if (!m) return NO;
    if (method_getNumberOfArguments(m) != 2) return NO; // self + _cmd only
    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    return ret[0] == 'B' || ret[0] == 'c'; // BOOL or char
}

// ── Install hooks on WAABProperties ──────────────────────────────────────────
static void WAGRHookWAABProperties(Class cls) {
    if (!cls) return;

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    if (!methods) return;

    SEL boolKeySel    = NSSelectorFromString(@"boolForKey:defaultValue:");
    SEL stringKeySel  = NSSelectorFromString(@"stringForKey:defaultValue:");

    for (unsigned int i = 0; i < count; i++) {
        Method m   = methods[i];
        SEL sel    = method_getName(m);
        NSString *selName = NSStringFromSelector(sel);

        // Hook generic getter methods
        if (sel == boolKeySel) {
            if (!gOrigBoolForKey)
                MSHookMessageEx(cls, sel, (IMP)WAGRBoolForKeyHook, (IMP *)&gOrigBoolForKey);
            continue;
        }
        if (sel == stringKeySel) {
            if (!gOrigStringForKey)
                MSHookMessageEx(cls, sel, (IMP)WAGRStringForKeyHook, (IMP *)&gOrigStringForKey);
            continue;
        }

        // Hook all zero-arg bool methods
        if (!WAGRIsBoolNoArgMethod(m)) continue;
        if (gWAABOrigImps[selName]) continue; // already hooked

        IMP orig = NULL;
        MSHookMessageEx(cls, sel, (IMP)WAGRWAABGenericBoolHook, &orig);
        if (orig) gWAABOrigImps[selName] = [NSValue valueWithPointer:(const void *)orig];
        gWAABHookedCount++;
    }
    free(methods);
}

// Internal installer only. The public WAGRWAABEnsureHooksInstalled shim is owned
// by the menu/router layer in this branch; exporting it here too creates a
// duplicate linker symbol when the real observer is compiled.
static void WAGRWAABObserverEnsureHooksInstalled(void) {
    WAGRLogEnsure();
    if (gWAABHooksInstalled) return;
    gWAABHooksInstalled = YES;

    // Primary class
    Class waab = NSClassFromString(@"WAABProperties");
    WAGRHookWAABProperties(waab);

    // Scan for any subclasses / alternate implementations
    unsigned int total = 0;
    Class *all = objc_copyClassList(&total);
    if (all) {
        for (unsigned int i = 0; i < total; i++) {
            NSString *name = NSStringFromClass(all[i]);
            if ([name containsString:@"WAABProperties"] ||
                [name containsString:@"ABProperties"] ||
                [name isEqualToString:@"FOAWAABPropertiesImpl"]) {
                WAGRHookWAABProperties(all[i]);
            }
        }
        free(all);
    }
    NSLog(@"[WAGram][WAAB] hooked %lu direct bool methods on WAABProperties", (unsigned long)gWAABHookedCount);
}

// ── Public API ────────────────────────────────────────────────────────────────
extern "C" NSString *WAGRABObsLog(void) {
    WAGRLogEnsure();
    __block NSArray *snap = nil;
    dispatch_sync(gWAABQueue, ^{ snap = [gWAABLog copy]; });
    return snap.count ? [snap componentsJoinedByString:@"\n"] : @"(sem observações ainda)";
}
extern "C" void WAGRABObsClear(void) {
    WAGRLogEnsure();
    dispatch_async(gWAABQueue, ^{ [gWAABLog removeAllObjects]; });
}
extern "C" NSString *WAGRWAABDiagnosticText(void) {
    WAGRLogEnsure();
    NSUInteger active = 0;
    for (NSString *k in [[NSUserDefaults standardUserDefaults] dictionaryRepresentation])
        if ([k hasPrefix:@"wagr.waab."]) active++;
    return [NSString stringWithFormat:
        @"hooks installed = %@\ndirect bool hooks = %lu\nboolForKey hook = %@\nstringForKey hook = %@\nactive overrides = %lu\nobserver = %@",
        gWAABHooksInstalled ? @"YES" : @"NO",
        (unsigned long)gWAABHookedCount,
        gOrigBoolForKey ? @"YES" : @"NO",
        gOrigStringForKey ? @"YES" : @"NO",
        (unsigned long)active,
        WAGRPref(kWAGRABPropsObserver) ? @"ON" : @"OFF"];
}

// ── Constructor ───────────────────────────────────────────────────────────────
__attribute__((constructor))
static void WAGRABInit(void) {
    @autoreleasepool {
        WAGRLogEnsure();
        // Install immediately for pre-loaded classes
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WAGRWAABObserverEnsureHooksInstalled(); });
        // Retry after app fully loads
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WAGRWAABObserverEnsureHooksInstalled(); });
    }
}
