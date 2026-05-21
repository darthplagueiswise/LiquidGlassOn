// WAGREmployeeHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Hooks the "is this user an employee / internal tester / dogfooder" gates
// that gate access to internal features inside WhatsApp.
//
// What this file owns
// ───────────────────
//   -isInternalUser                       (verified owner: WAServerProperties)
//   -isMetaEmployeeOrInternalTester       (no current owner confirmed in build;
//                                          trampoline kept for forward compat)
//   -is_meta_employee_or_internal_tester  (snake_case variant; same status)
//   -graphQLEmployeeC1Disabled            (no current owner confirmed)
//
// Evidence
// ────────
// Static analysis of __objc_classlist, __objc_methlist and __objc_catlist of
// both the WhatsApp main executable and the SharedModules dylib showed:
//
//   • isInternalUser is implemented as a +class method on WAServerProperties
//     (SharedModules). This is the only confirmed real implementation.
//   • The other three selectors appear in __objc_methname (because some
//     caller selrefs them) but no class — base methods or category — declares
//     them on either binary. They are Swift-only on this build.
//
// Why we keep the unfound selectors anyway
// ────────────────────────────────────────
// We retain their trampolines and the install loop entries so that, if a
// future WhatsApp build re-exposes any of them as @objc (or attaches them
// via a new category), unlocking the gate is a one-line edit: add the owning
// class name to candidateClasses[] below. No broad scan, no surprises.
//
// What changed from the previous version
// ──────────────────────────────────────
// • The broad scan via runtime-wide class scan was removed. It worked but it was
//   non-deterministic — different startups could hook different classes —
//   and it competed with WAGRObjCHookRouter for the same install rights.
// • The candidate class list now contains only classes that actually exist
//   in the WhatsApp/SharedModules binaries as of this build.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

// ── Original IMPs ────────────────────────────────────────────────────────────
typedef BOOL (*BoolIMP)(id, SEL);
static BoolIMP orig_isMetaEmployee       = NULL;
static BoolIMP orig_isMetaEmployeeSnake  = NULL;
static BoolIMP orig_isInternalUser       = NULL;
static BoolIMP orig_graphQLEmpC1         = NULL;

static BOOL    gEmpInstalled = NO;
static NSUInteger gEmpHookedCount = 0;

// ── Master gate ──────────────────────────────────────────────────────────────
// Two ways to force a given dogfood gate ON: either the global employee
// master switch, or the per-gate granular toggle. The per-gate toggle was
// kept from the previous design so users who want very specific control can
// flip just one selector instead of the whole bundle.
static BOOL WAGRDogfoodForce(NSString *granularKey) {
    return WAGRPref(kWAGREmployeeMaster) || WAGRPref(granularKey);
}

// ── Trampolines ──────────────────────────────────────────────────────────────
// Each gate is "positively forced" — when the user toggle is on we return
// YES. graphQLEmployeeC1Disabled is the one negative-polarity exception:
// it's a "disabled" gate, so forcing it ON means returning NO from the
// disabled-check to keep the feature enabled.
static BOOL h_isMetaEmployee(id s, SEL c) {
    if (WAGRDogfoodForce(kWAGRDogfoodGateMetaEmployee)) return YES;
    return orig_isMetaEmployee ? orig_isMetaEmployee(s, c) : NO;
}
static BOOL h_isMetaEmployeeSnake(id s, SEL c) {
    if (WAGRDogfoodForce(kWAGRDogfoodGateMetaEmployeeSnake)) return YES;
    return orig_isMetaEmployeeSnake ? orig_isMetaEmployeeSnake(s, c) : NO;
}
static BOOL h_isInternalUser(id s, SEL c) {
    if (WAGRDogfoodForce(kWAGRDogfoodGateInternalUser)) return YES;
    return orig_isInternalUser ? orig_isInternalUser(s, c) : NO;
}
static BOOL h_graphQLEmpC1(id s, SEL c) {
    // Inverted polarity: forcing the gate keeps employee C1 *enabled* by
    // returning NO from the "disabled?" check.
    if (WAGRDogfoodForce(kWAGRDogfoodGateGraphQLEmpC1)) return NO;
    return orig_graphQLEmpC1 ? orig_graphQLEmpC1(s, c) : YES;
}

// ── Per-(class, selector) installer ──────────────────────────────────────────
// Tries instance method first, then class method. Records into gEmpHookedCount
// for the diagnostic. Idempotent via the *origSlot check.
static void hookSelectorOnClass(Class cls, const char *selCStr,
                                IMP replacement, BoolIMP *origSlot) {
    if (!cls || !selCStr || !replacement || !origSlot || *origSlot) return;
    SEL sel = sel_registerName(selCStr);

    for (int m = 0; m < 2; m++) {
        Method mth = m ? class_getClassMethod(cls, sel)
                       : class_getInstanceMethod(cls, sel);
        if (!mth) continue;

        // Strict signature check: must be zero-arg BOOL. Methods that take
        // arguments or return other types would crash if we plugged in our
        // trampoline.
        if (method_getNumberOfArguments(mth) != 2) continue;
        char ret[8] = {0};
        method_getReturnType(mth, ret, sizeof(ret));
        if (ret[0] != 'B' && ret[0] != 'c') continue;

        Class target = m ? object_getClass(cls) : cls;
        MSHookMessageEx(target, sel, replacement, (IMP *)origSlot);
        if (*origSlot) { gEmpHookedCount++; return; }
    }
}

// ── Deterministic installer ──────────────────────────────────────────────────
// Replaces the previous broad-scan approach with a small, audited candidate
// list. Each name here is justified in the file header.
static void installEmployeeHooks(void) {
    if (gEmpInstalled) return;

    // Single source of truth for which classes own the gates we care about.
    // Adding a new candidate is a one-line edit if a future WhatsApp build
    // moves these selectors onto a different class.
    NSArray<NSString *> *candidateClasses = @[
        // Primary confirmed owner: WAServerProperties +isInternalUser (SharedModules).
        @"WAServerProperties",
        // Forward-compat placeholders. None of these is confirmed to own any
        // of our gates on the current build, but they are plausible homes if
        // the gates resurface in a future refactor. Keeping the list short
        // avoids the noise of the legacy broad scan.
        @"WAContextMain",
        @"WAUserContext",
        @"WAAccountInfo",
    ];

    for (NSString *name in candidateClasses) {
        Class cls = NSClassFromString(name);
        if (!cls) continue;
        hookSelectorOnClass(cls, "isMetaEmployeeOrInternalTester",
                            (IMP)h_isMetaEmployee, &orig_isMetaEmployee);
        hookSelectorOnClass(cls, "is_meta_employee_or_internal_tester",
                            (IMP)h_isMetaEmployeeSnake, &orig_isMetaEmployeeSnake);
        hookSelectorOnClass(cls, "isInternalUser",
                            (IMP)h_isInternalUser, &orig_isInternalUser);
        hookSelectorOnClass(cls, "graphQLEmployeeC1Disabled",
                            (IMP)h_graphQLEmpC1, &orig_graphQLEmpC1);
    }

    // Installation is considered "complete" as soon as the primary gate
    // (isInternalUser, the only one with a confirmed owner) is hooked.
    // The other gates may legitimately stay un-hooked because they have
    // no owner in this WhatsApp build.
    gEmpInstalled = (orig_isInternalUser != NULL);

    NSLog(@"[WATweaks][Emp] install pass: hooked=%lu installed=%@ internal=%@",
          (unsigned long)gEmpHookedCount,
          gEmpInstalled ? @"YES" : @"NO",
          orig_isInternalUser ? @"YES" : @"NO");
}

// ── Public API ───────────────────────────────────────────────────────────────
extern "C" void WAGRDogfoodEnsureHooksInstalled(void) {
    installEmployeeHooks();
}

extern "C" NSString *WAGRDogfoodDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"master=%@\nhookedTotal=%lu\ninternalUser=%@\nmetaEmployee=%@\nsnakeVariant=%@\ngraphQLEmpC1=%@",
        WAGRPref(kWAGREmployeeMaster) ? @"ON" : @"OFF",
        (unsigned long)gEmpHookedCount,
        orig_isInternalUser      ? @"YES" : @"NO",
        orig_isMetaEmployee      ? @"YES" : @"NO",
        orig_isMetaEmployeeSnake ? @"YES" : @"NO",
        orig_graphQLEmpC1        ? @"YES" : @"NO"];
}

// ── Constructor ──────────────────────────────────────────────────────────────
// Retry policy identical to the dev-menu file: 0.2 / 1.0 / 3.0 / 6.0 s. The
// extra 6 s slot covers the case where SharedModules takes longer to fully
// register WAServerProperties on cold launches.
__attribute__((constructor))
static void WAGREmployeeHooksCtor(void) {
    @autoreleasepool {
        double delays[] = { 0.2, 1.0, 3.0, 6.0 };
        for (int i = 0; i < (int)(sizeof(delays)/sizeof(delays[0])); i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ installEmployeeHooks(); });
        }
    }
}