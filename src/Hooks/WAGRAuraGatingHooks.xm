// WAGRAuraGatingHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Hooks WAAuraGating — the subscription-state object that gates Aura BEYOND
// the WAABProperties bool flags.
//
// Architecture:
//   WAABProperties (bool flags) ─► already hooked by WAABPropsObserver
//   WAAuraGating (subscription state) ─► THIS FILE
//
// WAAuraGating is injected into Aura VCs as a parameter. It has methods like:
//   isEnabled / isThemesEnabled / isIconsEnabled / isRingtonesEnabled
//   hasActivePlan / isSubscriptionActive / isBenefitActive
// These are NOT AB flags — they check payment/subscription state.
//
// When wagr_aura_simulation_enabled = YES, all these return YES.
// Individual flag overrides: wagr.waab.<selector> = "on"/"off" as usual.
//
// Also hooks checkSubscriptionsEligibilityAndInsertRowIfNeeded to force-insert
// the Subscriptions row in Settings without needing a real subscription.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

#define kWAGRAuraSimulation @"wagr_aura_simulation_enabled"

static BOOL WAGRAuraSimulationActive(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWAGRAuraSimulation];
}

// ── Generic hook for all BOOL-returning 0-arg methods on WAAuraGating ─────────
static NSMutableDictionary<NSString *, NSValue *> *gAuraGatingOrig = nil;

typedef BOOL (*AuraBoolIMP)(id, SEL);

static BOOL WAGRAuraGatingBoolHook(id self, SEL _cmd) {
    NSString *sel = NSStringFromSelector(_cmd);
    // Check individual override first
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(sel)];
    if ([stored isEqualToString:@"on"])  return YES;
    if ([stored isEqualToString:@"off"]) return NO;
    // Then simulation master
    if (WAGRAuraSimulationActive()) {
        // kill switches must return NO
        if ([sel containsString:@"illswitch"] || [sel containsString:@"kill_switch"] ||
            [sel hasPrefix:@"disable"] || [sel containsString:@"blocked"]) return NO;
        return YES;
    }
    AuraBoolIMP orig = nil;
    NSValue *v = gAuraGatingOrig[sel];
    if (v) orig = (AuraBoolIMP)[v pointerValue];
    return orig ? orig(self, _cmd) : NO;
}

static void WAGRHookAuraGatingClass(Class cls) {
    if (!cls || !gAuraGatingOrig) return;
    unsigned int n = 0;
    Method *ms = class_copyMethodList(cls, &n);
    if (!ms) return;
    for (unsigned int i = 0; i < n; i++) {
        Method m = ms[i];
        if (method_getNumberOfArguments(m) != 2) continue;
        char ret[8] = {0}; method_getReturnType(m, ret, 8);
        if (ret[0] != 'B' && ret[0] != 'c') continue;
        NSString *sel = NSStringFromSelector(method_getName(m));
        if ([sel containsString:@":"]) continue;
        if (gAuraGatingOrig[sel]) continue;
        IMP orig = NULL;
        MSHookMessageEx(cls, method_getName(m), (IMP)WAGRAuraGatingBoolHook, &orig);
        if (orig) gAuraGatingOrig[sel] = [NSValue valueWithPointer:(void *)orig];
    }
    free(ms);
}

// ── checkSubscriptionsEligibilityAndInsertRowIfNeeded → force insert ───────────
// Makes the Subscriptions row appear in Settings without a real subscription.
static void (*origCheckSubsEligibility)(id, SEL) = NULL;

static void hookCheckSubsEligibility(id self, SEL _cmd) {
    if (origCheckSubsEligibility) origCheckSubsEligibility(self, _cmd);
    if (!WAGRAuraSimulationActive() && !WAGRIsOn(@"aura_settings_row_enabled")) return;
    SEL insertSel = NSSelectorFromString(@"insertSubscriptionsRow");
    if ([self respondsToSelector:insertSel])
        ((void(*)(id,SEL))objc_msgSend)(self, insertSel);
}

// ── isSubscriptionsRowPresentInTable → NO to force re-insert ──────────────────
static BOOL (*origSubsRowPresent)(id, SEL) = NULL;

static BOOL hookSubsRowPresent(id self, SEL _cmd) {
    if (WAGRAuraSimulationActive() || WAGRIsOn(@"aura_settings_row_enabled"))
        return NO;
    return origSubsRowPresent ? origSubsRowPresent(self, _cmd) : NO;
}

static BOOL gAuraGatingHooksInstalled = NO;

static BOOL WAGRAuraGatingHasAnyHook(void) {
    return (gAuraGatingOrig.count > 0) || origCheckSubsEligibility || origSubsRowPresent;
}

extern "C" void WAGRAuraGatingEnsureHooksInstalled(void) {
    if (gAuraGatingHooksInstalled) return;
    if (!gAuraGatingOrig) gAuraGatingOrig = [NSMutableDictionary dictionaryWithCapacity:32];

    // Hook WAAuraGating and all related classes
    NSArray *auraClasses = @[
        @"WAAuraGating", @"WAAuraPreferences", @"WAAuraSubscriptionManager",
        @"WAAuraAppThemesGating", @"WAAuraAppIconsGating", @"WAAuraRingtonesGating",
        @"WAAuraPinnedChatsGating", @"WAAuraEnhancedListsGating", @"WAAuraStickersGating",
    ];
    for (NSString *name in auraClasses) {
        WAGRHookAuraGatingClass(NSClassFromString(name));
    }

    // Runtime scan for any other Aura* bool classes
    unsigned int total = 0;
    Class *all = objc_copyClassList(&total);
    if (all) {
        for (unsigned int i = 0; i < total; i++) {
            NSString *name = NSStringFromClass(all[i]);
            if ([name hasPrefix:@"WAAura"] || [name containsString:@"AuraGating"] ||
                [name containsString:@"AuraBenefit"] || [name containsString:@"AuraSubs"])
                WAGRHookAuraGatingClass(all[i]);
        }
        free(all);
    }

    // Hook Settings row methods
    SEL checkSel  = NSSelectorFromString(@"checkSubscriptionsEligibilityAndInsertRowIfNeeded");
    SEL presentSel = NSSelectorFromString(@"isSubscriptionsRowPresentInTable");
    Class *all2 = objc_copyClassList(&total);
    if (all2) {
        for (unsigned int i = 0; i < total; i++) {
            if (class_getInstanceMethod(all2[i], checkSel) && !origCheckSubsEligibility) {
                MSHookMessageEx(all2[i], checkSel, (IMP)hookCheckSubsEligibility, (IMP*)&origCheckSubsEligibility);
            }
            if (class_getInstanceMethod(all2[i], presentSel) && !origSubsRowPresent) {
                MSHookMessageEx(all2[i], presentSel, (IMP)hookSubsRowPresent, (IMP*)&origSubsRowPresent);
            }
        }
        free(all2);
    }
    gAuraGatingHooksInstalled = WAGRAuraGatingHasAnyHook();
    NSLog(@"[WAGram][AuraGating] installed=%@; aura gating classes hooked=%lu rowHooks=%@/%@",
          gAuraGatingHooksInstalled ? @"YES" : @"NO",
          (unsigned long)gAuraGatingOrig.count,
          origCheckSubsEligibility ? @"YES" : @"NO",
          origSubsRowPresent ? @"YES" : @"NO");
}

extern "C" void WAGRAuraGatingActivate(BOOL on) {
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (on) [ud setBool:YES forKey:kWAGRAuraSimulation];
    else    [ud removeObjectForKey:kWAGRAuraSimulation];
    [ud synchronize];
    WAGRAuraGatingEnsureHooksInstalled();
}

static BOOL WAGRAuraGatingHasStartupReason(void) {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kWAGRAuraSimulation]) return YES;
    NSDictionary *all = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *k in all) {
        if (![k hasPrefix:@"wagr.waab."]) continue;
        if ([k containsString:@"aura_"] || [k containsString:@"Benefit"] || [k containsString:@"benefit"] || [k containsString:@"subscription"]) return YES;
    }
    return NO;
}

__attribute__((constructor))
static void WAGRAuraGatingCtor(void) {
    @autoreleasepool {
        if (!WAGRAuraGatingHasStartupReason()) {
            NSLog(@"[WAGram][AuraGating] startup inert; no aura override active");
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ WAGRAuraGatingEnsureHooksInstalled(); });
    }
}
