// WAGRContextHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Hooks WAContext / WASettingsViewController for build-type / debug-mode gates.
//
// Confirmed in WA binary (2.26.19.73):
//   -isDebugBuild               → gates AB Props section (WA:43263)
//   -isDebugMenuAllowed         → gates Developer cell in Settings
//   -isTestFlightApp            → gates TestFlight-only features
//   -isReleaseCandidateBuild    → (inverse) RC builds restrict AB Props
//   -isBetaOrMoreVerbose        → enables verbose debug UI
//   -isDebugMenuShortcutEnabled → enables debug menu shortcut
//
// Storage: individual NSUserDefaults bool flags (not wagr.waab.*)
//   wagr.context.simulateDebugBuild = YES/NO
//   wagr.context.debugMenuAllowed   = YES/NO (can be separate from debug build)
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

// Storage keys (not wagr.waab.* — these are distinct from WAAB flag overrides)
#define kWAGRContextSimulateDebug    @"wagr.context.simulateDebugBuild"
#define kWAGRContextDebugMenu        @"wagr.context.debugMenuAllowed"

static BOOL WAGRContextSimulateDebug(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWAGRContextSimulateDebug];
}
static BOOL WAGRContextDebugMenuAllowed(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWAGRContextDebugMenu] ||
           WAGRContextSimulateDebug() ||
           WAGRPref(kWAGREmployeeMaster) || WAGRPref(kWAGRInternalMaster) || WAGRPref(kWAGRDebugMode);
}

// ── Hook storage ──────────────────────────────────────────────────────────────
typedef BOOL (*ContextBoolIMP)(id, SEL);
static ContextBoolIMP origIsDebugBuild              = NULL;
static ContextBoolIMP origIsDebugMenuAllowed        = NULL;
static ContextBoolIMP origIsTestFlightApp           = NULL;
static ContextBoolIMP origIsReleaseCandidateBuild   = NULL;
static ContextBoolIMP origIsBetaOrMoreVerbose       = NULL;
static ContextBoolIMP origIsDebugMenuShortcut       = NULL;

static BOOL hookIsDebugBuild(id self, SEL _cmd) {
    if (WAGRContextSimulateDebug()) return YES;
    return origIsDebugBuild ? origIsDebugBuild(self, _cmd) : NO;
}
static BOOL hookIsDebugMenuAllowed(id self, SEL _cmd) {
    if (WAGRContextDebugMenuAllowed()) return YES;
    return origIsDebugMenuAllowed ? origIsDebugMenuAllowed(self, _cmd) : NO;
}
static BOOL hookIsTestFlightApp(id self, SEL _cmd) {
    // Reads wagr.context.testFlight OR falls back to simulate debug
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"wagr.context.testFlight"]) return YES;
    if (WAGRContextSimulateDebug()) return YES;
    return origIsTestFlightApp ? origIsTestFlightApp(self, _cmd) : YES;
}
static BOOL hookIsReleaseCandidateBuild(id self, SEL _cmd) {
    // RC returns NO when debug build is simulated (NO = not a release candidate = can use debug features)
    // Also flipped when testFlight or betaVerbose is enabled
    if (WAGRContextSimulateDebug() ||
        [[NSUserDefaults standardUserDefaults] boolForKey:@"wagr.context.testFlight"] ||
        [[NSUserDefaults standardUserDefaults] boolForKey:@"wagr.context.betaVerbose"])
        return NO;
    return origIsReleaseCandidateBuild ? origIsReleaseCandidateBuild(self, _cmd) : YES;
}
static BOOL hookIsBetaOrMoreVerbose(id self, SEL _cmd) {
    // Reads wagr.context.betaVerbose OR falls back to simulate debug
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"wagr.context.betaVerbose"]) return YES;
    if (WAGRContextSimulateDebug()) return YES;
    return origIsBetaOrMoreVerbose ? origIsBetaOrMoreVerbose(self, _cmd) : NO;
}
static BOOL hookIsDebugMenuShortcut(id self, SEL _cmd) {
    if (WAGRContextDebugMenuAllowed()) return YES;
    return origIsDebugMenuShortcut ? origIsDebugMenuShortcut(self, _cmd) : NO;
}

static NSUInteger gContextHooked = 0;
static BOOL gContextHooksInstalled = NO;

static void WAGRContextHookOne(Class cls, BOOL meta, const char *selStr, IMP hook, IMP *orig) {
    if (*orig || !cls) return;
    SEL sel = sel_registerName(selStr);
    Class target = meta ? object_getClass(cls) : cls;
    Method m = class_getInstanceMethod(target, sel);
    if (!m) return;
    char ret[8] = {0}; method_getReturnType(m, ret, 8);
    if (ret[0] != 'B' && ret[0] != 'c') return;
    if (method_getNumberOfArguments(m) != 2) return;
    MSHookMessageEx(target, sel, hook, orig);
    gContextHooked++;
    NSLog(@"[WAGram][Context] hooked %@[%@ %s]", meta?@"+":@"-", NSStringFromClass(cls), selStr);
}

extern "C" void WAGRContextEnsureHooksInstalled(void) {
    if (gContextHooksInstalled) return;
    gContextHooksInstalled = YES;

    struct { const char *sel; IMP hook; IMP *orig; } entries[] = {
        { "isDebugBuild",              (IMP)hookIsDebugBuild,           (IMP *)&origIsDebugBuild },
        { "isDebugMenuAllowed",        (IMP)hookIsDebugMenuAllowed,     (IMP *)&origIsDebugMenuAllowed },
        { "isTestFlightApp",           (IMP)hookIsTestFlightApp,        (IMP *)&origIsTestFlightApp },
        { "isReleaseCandidateBuild",   (IMP)hookIsReleaseCandidateBuild,(IMP *)&origIsReleaseCandidateBuild },
        { "isBetaOrMoreVerbose",       (IMP)hookIsBetaOrMoreVerbose,    (IMP *)&origIsBetaOrMoreVerbose },
        { "isDebugMenuShortcutEnabled",(IMP)hookIsDebugMenuShortcut,    (IMP *)&origIsDebugMenuShortcut },
    };
    NSUInteger nEntries = sizeof(entries)/sizeof(entries[0]);

    unsigned int total = 0;
    Class *all = objc_copyClassList(&total);
    if (!all) return;

    for (unsigned int i = 0; i < total; i++) {
        Class cls = all[i];
        for (NSUInteger e = 0; e < nEntries; e++) {
            WAGRContextHookOne(cls, NO,  entries[e].sel, entries[e].hook, entries[e].orig);
            WAGRContextHookOne(cls, YES, entries[e].sel, entries[e].hook, entries[e].orig);
        }
    }
    free(all);
    NSLog(@"[WAGram][Context] hooks installed, count=%lu", (unsigned long)gContextHooked);
}

extern "C" void WAGRContextSetSimulateDebug(BOOL on) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (on) [ud setBool:YES forKey:kWAGRContextSimulateDebug];
    else    [ud removeObjectForKey:kWAGRContextSimulateDebug];
    [ud synchronize];
    WAGRContextEnsureHooksInstalled();
}
extern "C" BOOL WAGRContextIsSimulatingDebug(void) { return WAGRContextSimulateDebug(); }
extern "C" BOOL WAGRContextIsDebugMenuForced(void) { return WAGRContextDebugMenuAllowed(); }

extern "C" NSString *WAGRContextDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"simulate debug build  = %@\ndebug menu allowed    = %@\nisDebugBuild hooked   = %@\nisDebugMenuAllowed hk = %@\nRC build hooked       = %@\nBetaOrMoreVerbose hk  = %@\ntotal context hooks   = %lu",
        WAGRContextSimulateDebug() ? @"YES" : @"NO",
        WAGRContextDebugMenuAllowed() ? @"YES" : @"NO",
        origIsDebugBuild ? @"YES" : @"NO",
        origIsDebugMenuAllowed ? @"YES" : @"NO",
        origIsReleaseCandidateBuild ? @"YES" : @"NO",
        origIsBetaOrMoreVerbose ? @"YES" : @"NO",
        (unsigned long)gContextHooked];
}

__attribute__((constructor))
static void WAGRContextCtor(void) {
    @autoreleasepool {
        double delays[] = { 0.3, 1.0, 3.0 };
        for (int i = 0; i < 3; i++)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i]*NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ WAGRContextEnsureHooksInstalled(); });
    }
}
