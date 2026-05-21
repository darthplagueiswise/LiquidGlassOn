// WAGRNativeDevMenuHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Single, authoritative owner of the hooks that unlock WhatsApp's native
// Developer Menu (the entry that appears between Beta and the rest of the
// Settings screen when WhatsApp's own gates allow it).
//
// What the file hooks and why
// ───────────────────────────
// Two instance methods on the Swift class WADebugMenuMain.DebugMenuProvider
// (exposed to the ObjC runtime under its mangled name
//   _TtC15WADebugMenuMain17DebugMenuProvider
// ) are intercepted:
//
//   -isDebugMenuAllowed         decides whether the Developer entry surfaces
//   -isDebugMenuShortcutEnabled decides whether the in-app shortcut chip shows
//
// Both methods are added to that Swift class at dyld-load time by the
// "WADebugMenuMain" Objective-C category. Walking __objc_catlist of the
// WhatsApp binary confirmed this is the only class that actually owns these
// gates on the current build; the legacy candidates the project used to scan
// (WASettingsViewController, WAContextMain, etc.) do not declare them. That
// is why the previous hook attempts silently failed for "settingsHook=NO".
//
// Why this lives in its own file
// ──────────────────────────────
// Moving the dev-menu hooks out of Tweak.x cleans up Tweak.x to keep only
// the long-press table-view activation it has always owned, and gives the
// dev menu surface a single, documented place to evolve. No other file in
// this project hooks these two selectors, so there is no risk of double-hook
// or trampoline chaining.
//
// Failure modes worth understanding
// ─────────────────────────────────
// • The Swift class may be late-loaded. We retry installation at +0.2s, +1s,
//   and +3s after %ctor to cover dyld bring-up.
// • Each gate has its own original-IMP pointer so the trampolines are
//   independent. This matters in case a future build splits the selectors
//   across two classes; the install loop is structured to handle that.
// • If neither selector is found, the diagnostic exposes the partial state
//   ("dmAllowed=NO dmShortcut=NO") so testers can see why nothing changed.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

// ── Original IMPs ────────────────────────────────────────────────────────────
// One per gate so we never chain calls between them. Both are typed BoolIMP
// since both selectors return BOOL with no arguments beyond self/_cmd.
typedef BOOL (*BoolIMP)(id, SEL);
static BoolIMP orig_dmAllowed = NULL;
static BoolIMP orig_dmShortcutEnabled = NULL;

// Install-state booleans. We use simple flags instead of one merged state
// because the two gates can legitimately end up on different classes in
// future builds, and the diagnostic should reflect each independently.
static BOOL gDevMenuHooked  = NO;
static BOOL gShortcutHooked = NO;

// ── Master gate ──────────────────────────────────────────────────────────────
// Returns YES if any of the relevant preference toggles is on. We OR several
// historical keys together so flipping any of them in the WAGram menu UI is
// enough to unlock the native developer menu.
static BOOL WAGRNativeDevAllowed(void) {
    return WAGRPref(kWAGRDebugMenuNative)
        || WAGRPref(kWAGRInternalMaster)
        || WAGRPref(kWAGREmployeeMaster)
        || WAGRPref(kWAGRDebugMode);
}

// ── Trampolines ──────────────────────────────────────────────────────────────
// Standard "force YES when user opts in, else delegate to original" pattern.
// Keeping the trampolines tiny avoids reentrancy surprises.
static BOOL hookDevAllowed(id self, SEL _cmd) {
    if (WAGRNativeDevAllowed()) return YES;
    return orig_dmAllowed ? orig_dmAllowed(self, _cmd) : NO;
}

static BOOL hookDevShortcut(id self, SEL _cmd) {
    if (WAGRNativeDevAllowed()) return YES;
    return orig_dmShortcutEnabled ? orig_dmShortcutEnabled(self, _cmd) : NO;
}

// ── Method presence probes ───────────────────────────────────────────────────
// We use class_copyMethodList rather than respondsToSelector so we only
// match methods that are actually declared (or category-attached) on the
// class itself, never on a superclass. This matters because the Swift
// DebugMenuProvider inherits from NSObject, and NSObject happens to declare
// a generic respondsToSelector path that would lie if we used it directly.
static BOOL classHasInstanceMethod(Class cls, SEL sel) {
    if (!cls || !sel) return NO;
    unsigned int n = 0;
    Method *ms = class_copyMethodList(cls, &n);
    BOOL found = NO;
    for (unsigned int i = 0; i < n; i++) {
        if (method_getName(ms[i]) == sel) { found = YES; break; }
    }
    if (ms) free(ms);
    return found;
}

static BOOL classHasClassMethod(Class cls, SEL sel) {
    Class meta = object_getClass(cls);
    return meta ? classHasInstanceMethod(meta, sel) : NO;
}

// ── Installer ────────────────────────────────────────────────────────────────
// Walks a tight, deterministic list of candidate classes (Swift class first,
// legacy ObjC fallbacks after) and installs each gate where it actually
// exists. Stops looking for a given gate as soon as it is in place; this is
// what makes the function idempotent and cheap to call from retry timers.
static void installNativeDevMenuHooks(void) {
    if (gDevMenuHooked && gShortcutHooked) return;

    // PRIMARY target: the Swift DebugMenuProvider class.
    // FALLBACK targets: settings VC classes that older WhatsApp builds (pre
    // dependency-provider refactor) used to declare these methods on. None
    // of them declare it on the current build, but keeping them costs us
    // nothing and protects against version drift.
    NSArray *candidates = @[
        @"_TtC15WADebugMenuMain17DebugMenuProvider",
        @"WASettingsViewController",
        @"WASettingsTableViewController",
        @"WANewSettingsViewController",
        @"WASettingsNavTableViewController",
        @"WASettingsNavigationController",
    ];

    SEL allowedSel  = NSSelectorFromString(@"isDebugMenuAllowed");
    SEL shortcutSel = NSSelectorFromString(@"isDebugMenuShortcutEnabled");

    for (NSString *n in candidates) {
        Class cls = NSClassFromString(n);
        if (!cls) continue;

        // Install -isDebugMenuAllowed (instance form preferred; class-method
        // form preserved for legacy fallbacks).
        if (!gDevMenuHooked) {
            if (classHasInstanceMethod(cls, allowedSel)) {
                MSHookMessageEx(cls, allowedSel, (IMP)hookDevAllowed, (IMP *)&orig_dmAllowed);
                gDevMenuHooked = (orig_dmAllowed != NULL);
            } else if (classHasClassMethod(cls, allowedSel)) {
                MSHookMessageEx(object_getClass(cls), allowedSel, (IMP)hookDevAllowed, (IMP *)&orig_dmAllowed);
                gDevMenuHooked = (orig_dmAllowed != NULL);
            }
        }

        // Install -isDebugMenuShortcutEnabled. Independent of the previous
        // hook so that a partial success still produces a diagnostic.
        if (!gShortcutHooked) {
            if (classHasInstanceMethod(cls, shortcutSel)) {
                MSHookMessageEx(cls, shortcutSel, (IMP)hookDevShortcut, (IMP *)&orig_dmShortcutEnabled);
                gShortcutHooked = (orig_dmShortcutEnabled != NULL);
            } else if (classHasClassMethod(cls, shortcutSel)) {
                MSHookMessageEx(object_getClass(cls), shortcutSel, (IMP)hookDevShortcut, (IMP *)&orig_dmShortcutEnabled);
                gShortcutHooked = (orig_dmShortcutEnabled != NULL);
            }
        }

        if (gDevMenuHooked && gShortcutHooked) break;
    }

    NSLog(@"[WATweaks][NativeDevMenu] install pass: allowed=%@ shortcut=%@",
          gDevMenuHooked  ? @"YES" : @"NO",
          gShortcutHooked ? @"YES" : @"NO");
}

// ── Public API (consumed by Tweak.x for menu open / diagnostics) ─────────────
extern "C" void WAGRNativeDevMenuEnsureHooksInstalled(void) {
    installNativeDevMenuHooks();
}

extern "C" NSString *WAGRNativeDevMenuDiagnosticText(void) {
    // Each gate reported independently so a partial install is obvious.
    Class swiftCls = NSClassFromString(@"_TtC15WADebugMenuMain17DebugMenuProvider");
    return [NSString stringWithFormat:
            @"swiftClassLoaded=%@\nallowedHook=%@\nshortcutHook=%@",
            swiftCls ? @"YES" : @"NO",
            gDevMenuHooked  ? @"YES" : @"NO",
            gShortcutHooked ? @"YES" : @"NO"];
}

// ── Constructor ──────────────────────────────────────────────────────────────
// Three retries chosen empirically to cover (a) classes already loaded at
// %ctor time, (b) classes loaded during Swift runtime bring-up around 1s, and
// (c) classes loaded lazily by the dependency provider around 3s. The work
// itself is cheap: each retry only installs what is missing thanks to the
// gDevMenuHooked / gShortcutHooked guards.
__attribute__((constructor))
static void WAGRNativeDevMenuCtor(void) {
    @autoreleasepool {
        double delays[] = { 0.2, 1.0, 3.0 };
        for (int i = 0; i < (int)(sizeof(delays)/sizeof(delays[0])); i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ installNativeDevMenuHooks(); });
        }
    }
}