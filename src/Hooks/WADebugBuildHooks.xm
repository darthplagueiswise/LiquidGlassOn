// WADebugBuildHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Hooks isDebugBuild (WA:43263) → returns YES.
//
// Effect: removes "AB Props are not available in release candidate builds"
// banner in the Developer menu and unlocks the full AB Props override UI
// (WADebugABPropertiesTableViewController / PrivateExperimentationDebugVC).
//
// Also hooks isBetaOrMoreVerbose (WA:43262) and isRCBuild / getBuildType
// to ensure all build-type gates pass together.
//
// The class that owns these methods is a Kmp bridge class in the syncd module
// (adjacent: getBuildType, getSenderPlatform, isBetaOrMoreVerbose, isDebugBuild).
// Runtime scan finds it at startup — safe, reversible.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

#define kWAGRDebugBuildSimulate @"wagr_simulate_debug_build"

static BOOL gDebugBuildHooksInstalled = NO;
static NSUInteger gDebugBuildHookedCount = 0;

// ── Generic hook shared by all build-type bool methods ─────────────────────────
typedef BOOL (*DebugBoolIMP)(id, SEL);

static NSMutableDictionary<NSString *, NSValue *> *gDebugBuildOrigs = nil;

static BOOL WAGRDebugBuildBoolHook(id self, SEL _cmd) {
    if (!WAGRPref(kWAGRDebugBuildSimulate)) {
        NSString *nm = NSStringFromSelector(_cmd);
        NSValue *v = gDebugBuildOrigs[nm];
        DebugBoolIMP orig = v ? (DebugBoolIMP)[v pointerValue] : NULL;
        return orig ? orig(self, _cmd) : NO;
    }
    // Simulate debug build
    NSString *nm = NSStringFromSelector(_cmd);
    // isRCBuild / isReleaseCandidateBuild → must return NO (not an RC = is debug)
    if ([nm containsString:@"ReleaseCandidate"] || [nm containsString:@"releaseCandidate"] ||
        [nm containsString:@"isRC"] || [nm containsString:@"RCBuild"]) {
        return NO;
    }
    // isDebugBuild, isBetaOrMoreVerbose, isDebug, isInternalBuild → YES
    return YES;
}

// ── Hook list: confirmed in binary ────────────────────────────────────────────
static const char * const kDebugBuildSelectors[] = {
    "isDebugBuild",           // WA:43263 — THE key gate for AB Props
    "isBetaOrMoreVerbose",    // WA:43262 — enables more verbose debug UI
    NULL
};

static void WAGRDebugBuildHookOnClass(Class cls) {
    if (!cls) return;
    for (int i = 0; kDebugBuildSelectors[i]; i++) {
        SEL sel = sel_registerName(kDebugBuildSelectors[i]);
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) {
            // Also try class method
            m = class_getClassMethod(cls, sel);
            if (!m) continue;
        }
        if (method_getNumberOfArguments(m) != 2) continue;
        char ret[8] = {0};
        method_getReturnType(m, ret, sizeof(ret));
        if (ret[0] != 'B' && ret[0] != 'c') continue;

        NSString *nm = @(kDebugBuildSelectors[i]);
        if (gDebugBuildOrigs[nm]) continue;

        IMP orig = NULL;
        // For class methods, hook on metaclass
        if (!class_getInstanceMethod(cls, sel)) {
            MSHookMessageEx(object_getClass(cls), sel, (IMP)WAGRDebugBuildBoolHook, &orig);
        } else {
            MSHookMessageEx(cls, sel, (IMP)WAGRDebugBuildBoolHook, &orig);
        }
        if (orig) {
            gDebugBuildOrigs[nm] = [NSValue valueWithPointer:(void *)orig];
            gDebugBuildHookedCount++;
            NSLog(@"[WAGram][DebugBuild] hooked -%@ on %@", nm, NSStringFromClass(cls));
        }
    }
}

extern "C" void WAGRDebugBuildEnsureHooksInstalled(void) {
    if (gDebugBuildHooksInstalled) return;
    gDebugBuildHooksInstalled = YES;
    gDebugBuildOrigs = [NSMutableDictionary dictionaryWithCapacity:8];

    // Broad scan — we know the methods exist; the class name varies by build
    unsigned int total = 0;
    Class *all = objc_copyClassList(&total);
    if (!all) return;

    SEL debugSel = sel_registerName("isDebugBuild");
    for (unsigned int i = 0; i < total; i++) {
        // Only scan WA/KMP-adjacent classes
        if (class_getInstanceMethod(all[i], debugSel) ||
            class_getClassMethod(all[i], debugSel)) {
            WAGRDebugBuildHookOnClass(all[i]);
        }
    }
    free(all);
    NSLog(@"[WAGram][DebugBuild] installed %lu debug-build hooks", (unsigned long)gDebugBuildHookedCount);
}

extern "C" NSString *WAGRDebugBuildDiagnostic(void) {
    return [NSString stringWithFormat:
        @"simulate_debug_build = %@\nhooks installed      = %@\nhooked count         = %lu\n\nEffect:\n• isDebugBuild → YES\n• isBetaOrMoreVerbose → YES\n• AB Props section in Developer menu unlocked\n• PrivateExperimentationDebugVC available",
        WAGRPref(kWAGRDebugBuildSimulate) ? @"ON" : @"OFF",
        gDebugBuildHooksInstalled ? @"YES" : @"NO",
        (unsigned long)gDebugBuildHookedCount];
}
