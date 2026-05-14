// WALiquidGlassHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Liquid Glass enablement for WhatsApp.
//
// Strategy (in order of preference):
//   1. WALiquidGlassOverrideMethodUserDefaults — write the native WA UserDefaults
//      key that _WAApplyLiquidGlassOverride reads (safest, no method hooks).
//   2. Targeted method hooks on the symbols validated in SharedModules:
//      - shouldUseLiquidGlassConfiguration
//      - hasLiquidGlassLaunched
//      - usesGlassMaterial
//      - glassEffectEnabled
//      - useLiquidGlassDesign / useLiquidGlassStyle
//      - Per-flag accessors: ios_liquid_glass_* (via WAABProperties)
//
// Master toggle: kWAGRLiquidGlassMaster
// Individual sub-flags: kWAGRLG_* (each maps to one ABProp)
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

// ── Native UserDefaults key (from SharedModules enum) ─────────────────────────
//  WALiquidGlassOverrideMethodUserDefaults is an enum case whose raw-value string
//  we write as a UserDefaults key. WA reads this in _WAApplyLiquidGlassOverride.
static NSString *const kWANativeLGOverrideKey = @"WALiquidGlassOverrideMethodUserDefaults";

// ── Sub-flag key → ABProp selector name mapping ───────────────────────────────
static NSDictionary<NSString *, NSString *> *WAGRLGFlagMap(void) {
    static NSDictionary *map = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            kWAGRLG_enabled             : @"ios_liquid_glass_enabled",
            kWAGRLG_launched            : @"ios_liquid_glass_launched",
            kWAGRLG_m1                  : @"ios_liquid_glass_m1",
            kWAGRLG_m1_5                : @"ios_liquid_glass_m_1_5",
            kWAGRLG_m1_5_context_menu   : @"ios_liquid_glass_m_1_5_context_menu",
            kWAGRLG_chat_top_bar_m2     : @"ios_liquid_glass_chat_top_bar_m2_enabled",
            kWAGRLG_new_chatbar_ux      : @"ios_liquid_glass_enable_new_chatbar_ux",
            kWAGRLG_larger_composer     : @"ios_liquid_glass_larger_composer",
            kWAGRLG_reduce_transparency : @"ios_liquid_glass_reduce_transparency",
            kWAGRLG_workaround_attachment_tray   : @"ios_liquid_glass_workaround_attachment_tray",
            kWAGRLG_workaround_hides_bottombar   : @"ios_liquid_glass_workaround_hides_bottombar",
            kWAGRLG_workaround_topbar_appearance : @"ios_liquid_glass_workaround_topbar_appearance",
        };
    });
    return map;
}

// ── Determine if a given ABProp flag is requested ON ─────────────────────────
static BOOL WAGRLGFlagEnabled(NSString *abPropName) {
    if (!WAGRPref(kWAGRLiquidGlassMaster)) return NO;
    NSDictionary *map = WAGRLGFlagMap();
    for (NSString *prefKey in map) {
        if ([map[prefKey] isEqualToString:abPropName])
            return WAGRPref(prefKey);
    }
    return NO;
}

// ── Strategy 1: write the native UserDefaults override key ───────────────────
static void WAGRLGApplyUserDefaultsOverride(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (WAGRPref(kWAGRLiquidGlassMaster)) {
        [ud setObject:@"enabled" forKey:kWANativeLGOverrideKey];
        [ud synchronize];
        NSLog(@"[WAGram][LiquidGlass] wrote native UserDefaults override key");
    } else {
        [ud removeObjectForKey:kWANativeLGOverrideKey];
        [ud synchronize];
        NSLog(@"[WAGram][LiquidGlass] removed native UserDefaults override key");
    }
}

// ── Strategy 2: targeted ObjC method hooks ───────────────────────────────────
static BOOL (*orig_shouldUseLiquidGlassConfiguration)(id, SEL) = NULL;
static BOOL (*orig_hasLiquidGlassLaunched)(id, SEL)            = NULL;
static BOOL (*orig_usesGlassMaterial)(id, SEL)                 = NULL;
static BOOL (*orig_glassEffectEnabled)(id, SEL)                = NULL;
static BOOL (*orig_useLiquidGlassDesign)(id, SEL)              = NULL;
static BOOL (*orig_useLiquidGlassStyle)(id, SEL)               = NULL;

static BOOL hook_shouldUseLiquidGlassConfiguration(id self, SEL _cmd) {
    if (WAGRPref(kWAGRLiquidGlassMaster) && WAGRPref(kWAGRLG_enabled)) return YES;
    return orig_shouldUseLiquidGlassConfiguration
        ? orig_shouldUseLiquidGlassConfiguration(self, _cmd) : NO;
}
static BOOL hook_hasLiquidGlassLaunched(id self, SEL _cmd) {
    if (WAGRPref(kWAGRLiquidGlassMaster) && WAGRPref(kWAGRLG_launched)) return YES;
    return orig_hasLiquidGlassLaunched
        ? orig_hasLiquidGlassLaunched(self, _cmd) : NO;
}
static BOOL hook_usesGlassMaterial(id self, SEL _cmd) {
    if (WAGRPref(kWAGRLiquidGlassMaster)) return YES;
    return orig_usesGlassMaterial
        ? orig_usesGlassMaterial(self, _cmd) : NO;
}
static BOOL hook_glassEffectEnabled(id self, SEL _cmd) {
    if (WAGRPref(kWAGRLiquidGlassMaster)) return YES;
    return orig_glassEffectEnabled
        ? orig_glassEffectEnabled(self, _cmd) : NO;
}
static BOOL hook_useLiquidGlassDesign(id self, SEL _cmd) {
    if (WAGRPref(kWAGRLiquidGlassMaster)) return YES;
    return orig_useLiquidGlassDesign
        ? orig_useLiquidGlassDesign(self, _cmd) : NO;
}
static BOOL hook_useLiquidGlassStyle(id self, SEL _cmd) {
    if (WAGRPref(kWAGRLiquidGlassMaster)) return YES;
    return orig_useLiquidGlassStyle
        ? orig_useLiquidGlassStyle(self, _cmd) : NO;
}

// Per ABProp flag hooks (generic — installed dynamically)
typedef BOOL (*WAGRLGFlagIMP)(id, SEL);
static NSMutableDictionary<NSString *, NSValue *> *_wagrLGOrigFlagImps = nil;

static BOOL WAGRLGGenericFlagHook(id self, SEL _cmd) {
    NSString *sname = NSStringFromSelector(_cmd);
    if (WAGRLGFlagEnabled(sname)) return YES;
    NSString *key = [NSString stringWithFormat:@"%@|%@",
                     NSStringFromClass([self class]), sname];
    NSValue *val = _wagrLGOrigFlagImps[key];
    WAGRLGFlagIMP orig = val ? (WAGRLGFlagIMP)[val pointerValue] : NULL;
    return orig ? orig(self, _cmd) : NO;
}

// ── Hook installer ────────────────────────────────────────────────────────────
static BOOL _wagrLGHooksInstalled = NO;

static void WAGRLGInstallHooksOnClass(Class cls) {
    if (!cls) return;
    struct {
        const char *sel_name;
        IMP         hook;
        IMP        *orig;
    } fixed[] = {
        {"shouldUseLiquidGlassConfiguration", (IMP)hook_shouldUseLiquidGlassConfiguration, (IMP *)&orig_shouldUseLiquidGlassConfiguration},
        {"hasLiquidGlassLaunched",            (IMP)hook_hasLiquidGlassLaunched,            (IMP *)&orig_hasLiquidGlassLaunched},
        {"usesGlassMaterial",                 (IMP)hook_usesGlassMaterial,                 (IMP *)&orig_usesGlassMaterial},
        {"glassEffectEnabled",                (IMP)hook_glassEffectEnabled,                (IMP *)&orig_glassEffectEnabled},
        {"useLiquidGlassDesign",              (IMP)hook_useLiquidGlassDesign,              (IMP *)&orig_useLiquidGlassDesign},
        {"useLiquidGlassStyle",               (IMP)hook_useLiquidGlassStyle,               (IMP *)&orig_useLiquidGlassStyle},
    };
    for (size_t i = 0; i < sizeof(fixed)/sizeof(fixed[0]); i++) {
        SEL sel = sel_registerName(fixed[i].sel_name);
        if (!class_getInstanceMethod(cls, sel)) continue;
        if (*fixed[i].orig) continue;
        MSHookMessageEx(cls, sel, fixed[i].hook, fixed[i].orig);
        NSLog(@"[WAGram][LiquidGlass] hooked -%s on %@", fixed[i].sel_name, NSStringFromClass(cls));
    }

    // Per-flag selectors
    NSSet<NSString *> *flagSelectors = [NSSet setWithArray:WAGRLGFlagMap().allValues];
    unsigned int mcount = 0;
    Method *methods = class_copyMethodList(cls, &mcount);
    for (unsigned int i = 0; i < mcount; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *sname = NSStringFromSelector(sel);
        if (![flagSelectors containsObject:sname]) continue;
        NSString *key = [NSString stringWithFormat:@"%@|%@", NSStringFromClass(cls), sname];
        if (_wagrLGOrigFlagImps[key]) continue;
        IMP origImp = method_getImplementation(methods[i]);
        _wagrLGOrigFlagImps[key] = [NSValue valueWithPointer:(void *)origImp];
        MSHookMessageEx(cls, sel, (IMP)WAGRLGGenericFlagHook, NULL);
        NSLog(@"[WAGram][LiquidGlass] flag-hooked -%@ on %@", sname, NSStringFromClass(cls));
    }
    if (methods) free(methods);
}

static void WAGRLGInstallAllHooks(void) {
    if (_wagrLGHooksInstalled) return;
    unsigned int count = 0;
    Class *all = objc_copyClassList(&count);
    if (!all) return;
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(all[i]);
        if ([name containsString:@"LiquidGlass"]   ||
            [name containsString:@"ABProperties"]  ||
            [name containsString:@"WAABProp"]      ||
            [name containsString:@"LiquidGlassProv"]) {
            WAGRLGInstallHooksOnClass(all[i]);
        }
    }
    free(all);
    _wagrLGHooksInstalled = YES;
}

// ── Constructor ───────────────────────────────────────────────────────────────
__attribute__((constructor))
static void WAGRLiquidGlassInit(void) {
    @autoreleasepool {
        _wagrLGOrigFlagImps = [NSMutableDictionary dictionary];

        // Strategy 1 immediately
        WAGRLGApplyUserDefaultsOverride();

        if (!WAGRPref(kWAGRLiquidGlassMaster)) {
            NSLog(@"[WAGram][LiquidGlass] inert startup: master OFF");
            return;
        }

        // Strategy 2: hook after frameworks load, only when explicitly enabled.
        double delays[] = { 0.8, 2.5 };
        for (size_t i = 0; i < 2; i++) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    WAGRLGInstallAllHooks();
                });
        }
    }
}

/// Called from menu when user changes any LiquidGlass toggle.
extern "C" void WAGRLGPrefsDidChange(void) {
    WAGRLGApplyUserDefaultsOverride();
    if (WAGRPref(kWAGRLiquidGlassMaster)) {
        WAGRLGInstallAllHooks();
    }
}
