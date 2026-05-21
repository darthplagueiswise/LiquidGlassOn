// WAGRContextHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Narrow WAContextMain hook owner. The older version tried to hook a broad set
// of debug/settings selectors and then fell back to runtime-wide class scan. That
// made startup order non-deterministic and could collide with the dedicated
// native developer menu hooks. This file now owns only the verified, confirmed
// WAContextMain BOOL surface: isVerifiedChannelFeatureFlagEnabled.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

#define kWAGRCtxVerified @"wagr.ctx.isVerifiedChannelFeatureFlagEnabled"

typedef BOOL (*BoolIMP)(id, SEL);
static BoolIMP orig_verified = NULL;
static BOOL gCtxDone = NO;
static NSUInteger gCtxN = 0;

static BOOL h_verified(id self, SEL _cmd) {
    if (WAGRPref(kWAGRCtxVerified)) return YES;
    return orig_verified ? orig_verified(self, _cmd) : NO;
}

static BOOL methodReturnsBool(Method m) {
    if (!m) return NO;
    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    return ret[0] == 'B' || ret[0] == 'c';
}

static void hookSelectorOnClass(Class cls, const char *selName, IMP replacement, BoolIMP *origSlot) {
    if (!cls || !selName || !replacement || !origSlot || *origSlot) return;

    SEL sel = sel_registerName(selName);

    Method inst = class_getInstanceMethod(cls, sel);
    if (methodReturnsBool(inst)) {
        MSHookMessageEx(cls, sel, replacement, (IMP *)origSlot);
        if (*origSlot) { gCtxN++; return; }
    }

    Method klass = class_getClassMethod(cls, sel);
    if (methodReturnsBool(klass)) {
        MSHookMessageEx(object_getClass(cls), sel, replacement, (IMP *)origSlot);
        if (*origSlot) { gCtxN++; return; }
    }
}

static void installContextHooks(void) {
    if (gCtxDone) return;

    Class cls = NSClassFromString(@"WAContextMain");
    hookSelectorOnClass(cls,
                        "isVerifiedChannelFeatureFlagEnabled",
                        (IMP)h_verified,
                        &orig_verified);

    gCtxDone = (orig_verified != NULL);
    NSLog(@"[WATweaks][Ctx] installed=%@ hooked=%lu verified=%@",
          gCtxDone ? @"YES" : @"NO",
          (unsigned long)gCtxN,
          orig_verified ? @"YES" : @"NO");
}

static BOOL anyContextPrefEnabled(void) {
    return WAGRPref(kWAGRCtxVerified);
}

__attribute__((constructor))
static void WAGRContextHooksCtor(void) {
    @autoreleasepool {
        if (!anyContextPrefEnabled()) {
            NSLog(@"[WATweaks][Ctx] inert");
            return;
        }
        double delays[] = { 0.2, 1.0, 3.0, 6.0 };
        for (int i = 0; i < (int)(sizeof(delays)/sizeof(delays[0])); i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ installContextHooks(); });
        }
    }
}

extern "C" void WAGRContextHooksEnsureInstalled(void) {
    installContextHooks();
}

extern "C" NSString *WAGRContextHooksDiagnostic(void) {
    return [NSString stringWithFormat:@"ctxDone=%@\nhooked=%lu\nverified=%@\nprefVerified=%@",
            gCtxDone ? @"YES" : @"NO",
            (unsigned long)gCtxN,
            orig_verified ? @"YES" : @"NO",
            WAGRPref(kWAGRCtxVerified) ? @"ON" : @"OFF"];
}
