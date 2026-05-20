// WAGRSharedModulesCoreHooks.xm
// Focused hooks validated against SharedModules(7):
//   FOAWAABPropertiesImpl / WAPropertiesStore / WAProperties *ForKey:defaultValue:
//   WAABProperties category methods isMetaEmployeeOrInternalTester / is_meta_employee_or_internal_tester
//   WAServerProperties +isInternalUser
//   WAAuraGating known gates

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL gCoreHooksInstalled = NO;
static NSMutableDictionary<NSString *, NSValue *> *gBoolOrig = nil;
static NSMutableDictionary<NSString *, NSValue *> *gStringOrig = nil;
static NSMutableDictionary<NSString *, NSValue *> *gIntegerOrig = nil;
static NSMutableDictionary<NSString *, NSValue *> *gDoubleOrig = nil;
static NSMutableDictionary<NSString *, NSValue *> *gAuraOrig = nil;

static void WAGRCoreEnsureStorage(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gBoolOrig = [NSMutableDictionary dictionary];
        gStringOrig = [NSMutableDictionary dictionary];
        gIntegerOrig = [NSMutableDictionary dictionary];
        gDoubleOrig = [NSMutableDictionary dictionary];
        gAuraOrig = [NSMutableDictionary dictionary];
    });
}

static NSString *WAGRImpKey(id self, SEL _cmd) {
    return [NSString stringWithFormat:@"%@.%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

static BOOL WAGRNativeDeveloperCoreEnabled(void) {
    return WAGRPref(kWAGRDebugMenuNative) ||
           WAGRPref(kWAGRDebugMode) ||
           WAGRPref(kWAGRInternalMaster) ||
           WAGRPref(kWAGREmployeeMaster);
}

static NSString *WAGRKeyString(id key) {
    if ([key isKindOfClass:[NSString class]]) return (NSString *)key;
    if ([key respondsToSelector:@selector(description)]) return [key description];
    return nil;
}

static BOOL WAGRHasWAABOverrideForKey(NSString *key, NSString **storedOut) {
    if (!key.length) return NO;
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(key)];
    if (stored.length) {
        if (storedOut) *storedOut = stored;
        return YES;
    }
    return NO;
}

static BOOL hookBoolForKey(id self, SEL _cmd, id keyObj, BOOL defaultValue) {
    NSString *key = WAGRKeyString(keyObj);
    NSString *stored = nil;
    if (WAGRHasWAABOverrideForKey(key, &stored)) {
        if ([stored isEqualToString:@"on"]) return YES;
        if ([stored isEqualToString:@"off"]) return NO;
    }
    typedef BOOL (*Orig)(id, SEL, id, BOOL);
    Orig orig = (Orig)[gBoolOrig[WAGRImpKey(self, _cmd)] pointerValue];
    return orig ? orig(self, _cmd, keyObj, defaultValue) : defaultValue;
}

static id hookStringForKey(id self, SEL _cmd, id keyObj, id defaultValue) {
    NSString *key = WAGRKeyString(keyObj);
    NSString *stored = nil;
    if (WAGRHasWAABOverrideForKey(key, &stored)) {
        if ([stored isEqualToString:@"on"]) return @"enabled";
        if ([stored isEqualToString:@"off"]) return @"";
    }
    typedef id (*Orig)(id, SEL, id, id);
    Orig orig = (Orig)[gStringOrig[WAGRImpKey(self, _cmd)] pointerValue];
    return orig ? orig(self, _cmd, keyObj, defaultValue) : defaultValue;
}

static NSInteger hookIntegerForKey(id self, SEL _cmd, id keyObj, NSInteger defaultValue) {
    NSString *key = WAGRKeyString(keyObj);
    NSString *stored = nil;
    if (WAGRHasWAABOverrideForKey(key, &stored)) {
        if ([stored isEqualToString:@"on"]) return 1;
        if ([stored isEqualToString:@"off"]) return 0;
    }
    typedef NSInteger (*Orig)(id, SEL, id, NSInteger);
    Orig orig = (Orig)[gIntegerOrig[WAGRImpKey(self, _cmd)] pointerValue];
    return orig ? orig(self, _cmd, keyObj, defaultValue) : defaultValue;
}

static double hookDoubleForKey(id self, SEL _cmd, id keyObj, double defaultValue) {
    NSString *key = WAGRKeyString(keyObj);
    NSString *stored = nil;
    if (WAGRHasWAABOverrideForKey(key, &stored)) {
        if ([stored isEqualToString:@"on"]) return 1.0;
        if ([stored isEqualToString:@"off"]) return 0.0;
    }
    typedef double (*Orig)(id, SEL, id, double);
    Orig orig = (Orig)[gDoubleOrig[WAGRImpKey(self, _cmd)] pointerValue];
    return orig ? orig(self, _cmd, keyObj, defaultValue) : defaultValue;
}

static BOOL (*origServerInternalUser)(id, SEL) = NULL;
static BOOL hookServerInternalUser(id self, SEL _cmd) {
    if (WAGRNativeDeveloperCoreEnabled()) return YES;
    return origServerInternalUser ? origServerInternalUser(self, _cmd) : NO;
}

static BOOL (*origWAABMetaEmployee)(id, SEL) = NULL;
static BOOL hookWAABMetaEmployee(id self, SEL _cmd) {
    if (WAGRNativeDeveloperCoreEnabled()) return YES;
    return origWAABMetaEmployee ? origWAABMetaEmployee(self, _cmd) : NO;
}

static BOOL (*origWAABMetaEmployeeSnake)(id, SEL) = NULL;
static BOOL hookWAABMetaEmployeeSnake(id self, SEL _cmd) {
    if (WAGRNativeDeveloperCoreEnabled()) return YES;
    return origWAABMetaEmployeeSnake ? origWAABMetaEmployeeSnake(self, _cmd) : NO;
}

static BOOL WAGRAuraShouldOverride(SEL sel, BOOL *value) {
    NSString *name = NSStringFromSelector(sel);
    NSString *key = WAGROverrideKey(kWAGRSurfaceAura, @"WAAuraGating", NO, name);
    if (WAGRHasOverride(key)) {
        if (value) *value = WAGROverrideBool(key);
        return YES;
    }
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:WAGRKey(name)];
    if ([stored isEqualToString:@"on"] || [stored isEqualToString:@"off"]) {
        if (value) *value = [stored isEqualToString:@"on"];
        return YES;
    }
    return NO;
}

static BOOL hookAuraBool(id self, SEL _cmd) {
    BOOL v = NO;
    if (WAGRAuraShouldOverride(_cmd, &v)) return v;
    typedef BOOL (*Orig)(id, SEL);
    Orig orig = (Orig)[gAuraOrig[NSStringFromSelector(_cmd)] pointerValue];
    return orig ? orig(self, _cmd) : NO;
}

static BOOL hookAuraKillSwitch(id self, SEL _cmd) {
    BOOL v = NO;
    if (WAGRAuraShouldOverride(_cmd, &v)) return v;
    if (WAGRNativeDeveloperCoreEnabled()) return NO;
    typedef BOOL (*Orig)(id, SEL);
    Orig orig = (Orig)[gAuraOrig[NSStringFromSelector(_cmd)] pointerValue];
    return orig ? orig(self, _cmd) : NO;
}

static void WAGRHookInstanceWithDict(Class cls, SEL sel, IMP hook, NSMutableDictionary<NSString *, NSValue *> *dict) {
    if (!cls || !sel || !hook || !dict) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    NSString *key = [NSString stringWithFormat:@"%@.%@", NSStringFromClass(cls), NSStringFromSelector(sel)];
    if (dict[key]) return;
    IMP orig = NULL;
    MSHookMessageEx(cls, sel, hook, &orig);
    if (orig) dict[key] = [NSValue valueWithPointer:reinterpret_cast<const void *>(orig)];
}

static void WAGRHookAura(Class cls, NSString *selName, IMP hook) {
    if (!cls || !selName.length) return;
    SEL sel = NSSelectorFromString(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m || gAuraOrig[selName]) return;
    IMP orig = NULL;
    MSHookMessageEx(cls, sel, hook, &orig);
    if (orig) gAuraOrig[selName] = [NSValue valueWithPointer:reinterpret_cast<const void *>(orig)];
}

static void WAGRHookInstanceOnce(Class cls, SEL sel, IMP hook, IMP *orig) {
    if (!cls || !sel || !hook || !orig || *orig) return;
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    MSHookMessageEx(cls, sel, hook, orig);
}

static void WAGRHookClassOnce(Class cls, SEL sel, IMP hook, IMP *orig) {
    if (!cls || !sel || !hook || !orig || *orig) return;
    Class meta = object_getClass(cls);
    Method m = meta ? class_getInstanceMethod(meta, sel) : NULL;
    if (!m) return;
    MSHookMessageEx(meta, sel, hook, orig);
}

static void WAGRInstallWAABKeyHooksForClass(NSString *className) {
    Class cls = NSClassFromString(className);
    WAGRHookInstanceWithDict(cls, @selector(boolForKey:defaultValue:), (IMP)hookBoolForKey, gBoolOrig);
    WAGRHookInstanceWithDict(cls, @selector(stringForKey:defaultValue:), (IMP)hookStringForKey, gStringOrig);
    WAGRHookInstanceWithDict(cls, @selector(integerForKey:defaultValue:), (IMP)hookIntegerForKey, gIntegerOrig);
    WAGRHookInstanceWithDict(cls, @selector(doubleForKey:defaultValue:), (IMP)hookDoubleForKey, gDoubleOrig);
}

extern "C" void WAGRSharedModulesCoreEnsureHooksInstalled(void) {
    WAGRCoreEnsureStorage();
    if (gCoreHooksInstalled) return;

    WAGRInstallWAABKeyHooksForClass(@"FOAWAABPropertiesImpl");
    WAGRInstallWAABKeyHooksForClass(@"WAProperties");
    WAGRInstallWAABKeyHooksForClass(@"WAPropertiesStore");

    Class server = NSClassFromString(@"WAServerProperties");
    WAGRHookClassOnce(server, NSSelectorFromString(@"isInternalUser"), (IMP)hookServerInternalUser, (IMP *)&origServerInternalUser);

    Class waab = NSClassFromString(@"WAABProperties");
    WAGRHookInstanceOnce(waab, NSSelectorFromString(@"isMetaEmployeeOrInternalTester"), (IMP)hookWAABMetaEmployee, (IMP *)&origWAABMetaEmployee);
    WAGRHookInstanceOnce(waab, NSSelectorFromString(@"is_meta_employee_or_internal_tester"), (IMP)hookWAABMetaEmployeeSnake, (IMP *)&origWAABMetaEmployeeSnake);

    Class aura = NSClassFromString(@"WAAuraGating");
    NSArray<NSString *> *positive = @[
        @"isEnabled", @"isUserEligible", @"isSettingsRowEnabled", @"isLoggingEnabled",
        @"isAppearanceSettingsEnabled", @"isAppIconsEnabled", @"isAppIconsBenefitActive",
        @"isAppThemesEnabled", @"isAppThemesBenefitActive", @"isRingtonesEnabled",
        @"isRingtonesBenefitActive", @"isExtendedPinnedChatEnabled", @"isEnhancedListsEnabled",
        @"isStickersEnabled", @"isStickersBenefitActive"
    ];
    for (NSString *s in positive) WAGRHookAura(aura, s, (IMP)hookAuraBool);
    WAGRHookAura(aura, @"isKillSwitchActive", (IMP)hookAuraKillSwitch);

    gCoreHooksInstalled = YES;
}

extern "C" NSString *WAGRSharedModulesCoreDiagnostic(void) {
    WAGRCoreEnsureStorage();
    return [NSString stringWithFormat:@"coreHooks=%@\nboolForKey=%lu\nserverInternal=%@\nwaabMeta=%@\naura=%lu",
            gCoreHooksInstalled ? @"YES" : @"NO",
            (unsigned long)gBoolOrig.count,
            origServerInternalUser ? @"YES" : @"NO",
            (origWAABMetaEmployee || origWAABMetaEmployeeSnake) ? @"YES" : @"NO",
            (unsigned long)gAuraOrig.count];
}

__attribute__((constructor))
static void WAGRSharedModulesCoreCtor(void) {
    @autoreleasepool {
        WAGRCoreEnsureStorage();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRSharedModulesCoreEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRSharedModulesCoreEnsureHooksInstalled(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRSharedModulesCoreEnsureHooksInstalled(); });
    }
}
