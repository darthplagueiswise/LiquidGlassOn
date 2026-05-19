// WAGramNativeSurfaceHooks.xm
// Exact native boolean override backend.
// No runtime-wide startup hook scan. Browser discovery happens only inside the browser UI.
// Startup only reinstalls exact persisted class+selector overrides.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../WAUtils.h"

typedef BOOL (*WAGRBoolIMP)(id, SEL);
typedef id   (*WAGRIdIMP)(id, SEL, id);
typedef NSString *(*WAGRStringFn)(void);

static NSMutableDictionary<NSString *, NSValue *> *gWAGRNativeOrig = nil;
static BOOL gWAGRNativeVersionHooksInstalled = NO;

static WAGRStringFn orig_WAAppVersion = NULL;
static WAGRStringFn orig_WABuildNumber = NULL;
static WAGRStringFn orig_FBBuildAppVersion = NULL;
static WAGRStringFn orig_FBBuildNumber = NULL;
static WAGRIdIMP orig_NSBundleObjectForInfoDictionaryKey = NULL;

static NSString * const kWAGRNativeRegistryKey = @"wagr.native.registry";

static NSString *WAGRNativeStoreKey(NSString *className, BOOL meta, NSString *selectorName) {
    return [NSString stringWithFormat:@"wagr.native.%@.%@.%@", className ?: @"", meta ? @"c" : @"i", selectorName ?: @""];
}

static NSString *WAGRNativeOrigKey(NSString *className, BOOL meta, NSString *selectorName) {
    return [NSString stringWithFormat:@"%@%@%@", className ?: @"", meta ? @"+" : @"-", selectorName ?: @""];
}

extern "C" NSString *WAGRNativeBoolOverrideGet(NSString *className, BOOL meta, NSString *selectorName) {
    if (!className.length || !selectorName.length) return nil;
    return [[NSUserDefaults standardUserDefaults] stringForKey:WAGRNativeStoreKey(className, meta, selectorName)];
}

static BOOL WAGRNativeRegistryEntryMatches(NSDictionary *d, NSString *className, BOOL meta, NSString *selectorName) {
    if (![d isKindOfClass:NSDictionary.class]) return NO;
    return [[d objectForKey:@"class"] isEqualToString:className] &&
           [[d objectForKey:@"selector"] isEqualToString:selectorName] &&
           [[d objectForKey:@"meta"] boolValue] == meta;
}

static NSMutableArray *WAGRNativeRegistryMutable(void) {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:kWAGRNativeRegistryKey];
    return arr ? [arr mutableCopy] : [NSMutableArray array];
}

static void WAGRNativeRegistrySave(NSArray *arr) {
    [[NSUserDefaults standardUserDefaults] setObject:arr ?: @[] forKey:kWAGRNativeRegistryKey];
}

static BOOL WAGRNativeInstallExact(NSString *className, BOOL meta, NSString *selectorName);

extern "C" void WAGRNativeBoolOverrideSet(NSString *className, BOOL meta, NSString *selectorName, NSString *value) {
    if (!className.length || !selectorName.length) return;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *storeKey = WAGRNativeStoreKey(className, meta, selectorName);

    NSMutableArray *registry = WAGRNativeRegistryMutable();
    NSMutableArray *newRegistry = [NSMutableArray array];

    for (NSDictionary *d in registry) {
        if (!WAGRNativeRegistryEntryMatches(d, className, meta, selectorName)) [newRegistry addObject:d];
    }

    if ([value isEqualToString:@"on"] || [value isEqualToString:@"off"]) {
        [ud setObject:value forKey:storeKey];
        [newRegistry addObject:@{@"class": className, @"meta": @(meta), @"selector": selectorName}];
        WAGRNativeInstallExact(className, meta, selectorName);
    } else {
        [ud removeObjectForKey:storeKey];
    }

    WAGRNativeRegistrySave(newRegistry);
    [ud synchronize];
}

static BOOL WAGRDebugSurfaceEnabled(void) {
    return WAEnabled(kWAGRDebugMenuNative) || WAEnabled(kWAGRDebugMode) || WAEnabled(kWAGRInternalMaster) || WAEnabled(kWAGREmployeeMaster);
}

static BOOL WAGREmployeeSurfaceEnabled(void) {
    return WAEnabled(kWAGREmployeeMaster) || WAEnabled(kWAGRInternalMaster) || WAEnabled(kWAGRDebugMenuNative);
}

static BOOL WAGRMultiAccountSurfaceEnabled(void) {
    return WAGRIsOn(@"sg_ios_multi_account_enabled") ||
           WAGRIsOn(@"wa_xfam_ios_switcher_multiaccount_enabled") ||
           WAGRIsOn(@"foa_bridges_account_switcher_ios_enabled") ||
           WAGRIsOn(@"deletion_reason_multi_account_enabled") ||
           WAEnabled(kWAGRDebugMenuNative) ||
           WAEnabled(kWAGREmployeeMaster);
}

static BOOL WAGRNativeBoolHook(id self, SEL _cmd) {
    BOOL meta = class_isMetaClass(object_getClass(self));
    Class owner = meta ? (Class)self : object_getClass(self);

    NSString *className = NSStringFromClass(owner);
    NSString *selectorName = NSStringFromSelector(_cmd);

    NSString *forced = WAGRNativeBoolOverrideGet(className, meta, selectorName);
    if ([forced isEqualToString:@"on"]) return YES;
    if ([forced isEqualToString:@"off"]) return NO;

    if ([selectorName isEqualToString:@"graphQLEmployeeC1Disabled"]) {
        if (WAGREmployeeSurfaceEnabled()) return NO;
    }

    if ([selectorName isEqualToString:@"isDebugMenuAllowed"] ||
        [selectorName isEqualToString:@"isDebugBuild"] ||
        [selectorName isEqualToString:@"isTestFlightApp"] ||
        [selectorName isEqualToString:@"isInternalBuild"]) {
        if (WAGRDebugSurfaceEnabled()) return YES;
    }

    if ([selectorName isEqualToString:@"isReleaseCandidateBuild"]) {
        if (WAGRDebugSurfaceEnabled()) return NO;
    }

    if ([selectorName isEqualToString:@"isMetaEmployeeOrInternalTester"] ||
        [selectorName isEqualToString:@"is_meta_employee_or_internal_tester"] ||
        [selectorName isEqualToString:@"isInternalUser"]) {
        if (WAGREmployeeSurfaceEnabled()) return YES;
    }

    if ([selectorName isEqualToString:@"isPAAEligibleForWaffle"]) {
        if (WAGRIsOn(@"waffle_mobile_companions_enabled") || WAGRIsOn(@"waffle_enabled_for_unlinked_users") || WAGREmployeeSurfaceEnabled()) return YES;
    }

    if ([selectorName isEqualToString:@"isMultiAccountEnabled"] ||
        [selectorName isEqualToString:@"shouldSurfaceMultiAccount"] ||
        [selectorName isEqualToString:@"hasRegisteredMultiAccounts"]) {
        if (WAGRMultiAccountSurfaceEnabled()) return YES;
    }

    NSString *origKey = WAGRNativeOrigKey(className, meta, selectorName);
    WAGRBoolIMP orig = NULL;
    NSValue *v = [gWAGRNativeOrig objectForKey:origKey];
    if (v) orig = (WAGRBoolIMP)[v pointerValue];
    return orig ? orig(self, _cmd) : NO;
}

static BOOL WAGRNativeInstallExact(NSString *className, BOOL meta, NSString *selectorName) {
    if (!className.length || !selectorName.length) return NO;

    Class cls = NSClassFromString(className);
    if (!cls) return NO;

    SEL sel = sel_registerName(selectorName.UTF8String);
    Class target = meta ? object_getClass(cls) : cls;
    Method m = meta ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!m || !target) return NO;
    if (method_getNumberOfArguments(m) != 2) return NO;

    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    if (ret[0] != 'B' && ret[0] != 'c') return NO;

    if (!gWAGRNativeOrig) gWAGRNativeOrig = [NSMutableDictionary dictionary];

    NSString *origKey = WAGRNativeOrigKey(className, meta, selectorName);
    if ([gWAGRNativeOrig objectForKey:origKey]) return YES;

    IMP orig = NULL;
    MSHookMessageEx(target, sel, (IMP)WAGRNativeBoolHook, &orig);
    if (orig) {
        [gWAGRNativeOrig setObject:[NSValue valueWithPointer:(void *)orig] forKey:origKey];
        return YES;
    }
    return NO;
}

extern "C" NSUInteger WAGRNativeBoolOverrideInstallPersisted(void) {
    if (!gWAGRNativeOrig) gWAGRNativeOrig = [NSMutableDictionary dictionary];

    NSArray *registry = [[NSUserDefaults standardUserDefaults] arrayForKey:kWAGRNativeRegistryKey];
    NSUInteger installed = 0;

    for (NSDictionary *d in registry) {
        if (![d isKindOfClass:NSDictionary.class]) continue;
        NSString *className = [d objectForKey:@"class"];
        NSString *selectorName = [d objectForKey:@"selector"];
        BOOL meta = [[d objectForKey:@"meta"] boolValue];

        NSString *v = WAGRNativeBoolOverrideGet(className, meta, selectorName);
        if (![v isEqualToString:@"on"] && ![v isEqualToString:@"off"]) continue;
        if (WAGRNativeInstallExact(className, meta, selectorName)) installed++;
    }
    return installed;
}

static NSString *repl_WAAppVersion(void) {
    return WAGRDebugSurfaceEnabled() ? @"2.26.19.69" : (orig_WAAppVersion ? orig_WAAppVersion() : nil);
}
static NSString *repl_FBBuildAppVersion(void) {
    return WAGRDebugSurfaceEnabled() ? @"2.26.19.69" : (orig_FBBuildAppVersion ? orig_FBBuildAppVersion() : nil);
}
static NSString *repl_WABuildNumber(void) {
    return WAGRDebugSurfaceEnabled() ? @"69" : (orig_WABuildNumber ? orig_WABuildNumber() : nil);
}
static NSString *repl_FBBuildNumber(void) {
    return WAGRDebugSurfaceEnabled() ? @"69" : (orig_FBBuildNumber ? orig_FBBuildNumber() : nil);
}

static id repl_NSBundleObjectForInfoDictionaryKey(NSBundle *self, SEL _cmd, id key) {
    if (WAGRDebugSurfaceEnabled() && self == [NSBundle mainBundle] && [key isKindOfClass:NSString.class]) {
        NSString *k = (NSString *)key;
        if ([k isEqualToString:@"CFBundleShortVersionString"]) return @"2.26.19.69";
        if ([k isEqualToString:@"CFBundleVersion"]) return @"69";
    }
    return orig_NSBundleObjectForInfoDictionaryKey ? orig_NSBundleObjectForInfoDictionaryKey(self, _cmd, key) : nil;
}

static void WAGRHookVersionFunction(const char *symbol, void *replacement, void **origOut) {
    void *sym = dlsym(RTLD_DEFAULT, symbol);
    if (sym && origOut && !*origOut) MSHookFunction(sym, replacement, origOut);
}

static void WAGRNativeInstallVersionHooksIfNeeded(void) {
    if (gWAGRNativeVersionHooksInstalled) return;
    if (!WAGRDebugSurfaceEnabled()) return;
    gWAGRNativeVersionHooksInstalled = YES;

    WAGRHookVersionFunction("WAAppVersion", (void *)repl_WAAppVersion, (void **)&orig_WAAppVersion);
    WAGRHookVersionFunction("_WAAppVersion", (void *)repl_WAAppVersion, (void **)&orig_WAAppVersion);
    WAGRHookVersionFunction("FBBuildAppVersion", (void *)repl_FBBuildAppVersion, (void **)&orig_FBBuildAppVersion);
    WAGRHookVersionFunction("_FBBuildAppVersion", (void *)repl_FBBuildAppVersion, (void **)&orig_FBBuildAppVersion);
    WAGRHookVersionFunction("WABuildNumber", (void *)repl_WABuildNumber, (void **)&orig_WABuildNumber);
    WAGRHookVersionFunction("_WABuildNumber", (void *)repl_WABuildNumber, (void **)&orig_WABuildNumber);
    WAGRHookVersionFunction("FBBuildNumber", (void *)repl_FBBuildNumber, (void **)&orig_FBBuildNumber);
    WAGRHookVersionFunction("_FBBuildNumber", (void *)repl_FBBuildNumber, (void **)&orig_FBBuildNumber);

    IMP orig = NULL;
    MSHookMessageEx(NSBundle.class, @selector(objectForInfoDictionaryKey:), (IMP)repl_NSBundleObjectForInfoDictionaryKey, &orig);
    if (orig && !orig_NSBundleObjectForInfoDictionaryKey) orig_NSBundleObjectForInfoDictionaryKey = (WAGRIdIMP)orig;
}

static void WAGRNativeInstallKnownSeeds(void) {
    if (!gWAGRNativeOrig) gWAGRNativeOrig = [NSMutableDictionary dictionary];

    if (WAGRDebugSurfaceEnabled()) {
        WAGRNativeInstallExact(@"WASettingsViewController", NO, @"isDebugMenuAllowed");
        WAGRNativeInstallExact(@"WASettingsViewController", YES, @"isDebugMenuAllowed");
        WAGRNativeInstallExact(@"WAContext", NO, @"isDebugBuild");
        WAGRNativeInstallExact(@"WAContext", YES, @"isDebugBuild");
        WAGRNativeInstallExact(@"WAContext", NO, @"isTestFlightApp");
        WAGRNativeInstallExact(@"WAContext", YES, @"isTestFlightApp");
        WAGRNativeInstallExact(@"WAContext", NO, @"isReleaseCandidateBuild");
        WAGRNativeInstallExact(@"WAContext", YES, @"isReleaseCandidateBuild");
        WAGRNativeInstallVersionHooksIfNeeded();
    }

    if (WAGREmployeeSurfaceEnabled()) {
        WAGRNativeInstallExact(@"WAABProperties", NO, @"isMetaEmployeeOrInternalTester");
        WAGRNativeInstallExact(@"WAABProperties", NO, @"is_meta_employee_or_internal_tester");
        WAGRNativeInstallExact(@"WAABProperties", NO, @"isInternalUser");
        WAGRNativeInstallExact(@"WAABProperties", NO, @"graphQLEmployeeC1Disabled");
    }

    if (WAGRMultiAccountSurfaceEnabled()) {
        NSArray *classes = @[@"WAMultiAccountABProps",
                             @"WAAccountSwitcherObjCABProps",
                             @"WAAccountSwitcherEligibilityManager",
                             @"_TtC17WAAccountSwitcher22AccountSwitcherABProps",
                             @"_TtC17WAAccountSwitcher33AccountSwitcherEligibilityManager",
                             @"_TtC17WAAccountSwitcher21AccountSwitcherHelper",
                             @"_TtC17WAAccountSwitcher24AccountSwitcherPresenter"];
        for (NSString *c in classes) {
            WAGRNativeInstallExact(c, NO, @"isMultiAccountEnabled");
            WAGRNativeInstallExact(c, YES, @"isMultiAccountEnabled");
            WAGRNativeInstallExact(c, NO, @"shouldSurfaceMultiAccount");
            WAGRNativeInstallExact(c, YES, @"shouldSurfaceMultiAccount");
            WAGRNativeInstallExact(c, NO, @"hasRegisteredMultiAccounts");
            WAGRNativeInstallExact(c, YES, @"hasRegisteredMultiAccounts");
        }
    }

    if (WAGRIsOn(@"waffle_mobile_companions_enabled") || WAGRIsOn(@"waffle_enabled_for_unlinked_users") || WAGREmployeeSurfaceEnabled()) {
        WAGRNativeInstallExact(@"WAABProperties", NO, @"isPAAEligibleForWaffle");
    }
}

extern "C" void WAGRNativeSurfaceEnsureHooksInstalled(void) {
    WAGRNativeBoolOverrideInstallPersisted();
    WAGRNativeInstallKnownSeeds();
    NSLog(@"[WAGram][NativeSurface] exact hooks=%lu persisted=%lu runtime-wide-scan=NO",
          (unsigned long)gWAGRNativeOrig.count,
          (unsigned long)[[[NSUserDefaults standardUserDefaults] arrayForKey:kWAGRNativeRegistryKey] count]);
}

extern "C" NSString *WAGRNativeSurfaceDiagnosticText(void) {
    NSArray *registry = [[NSUserDefaults standardUserDefaults] arrayForKey:kWAGRNativeRegistryKey];
    return [NSString stringWithFormat:@"native exact hooks=%lu\npersisted overrides=%lu\ndebug surface=%@\nemployee/internal surface=%@\nmultiaccount surface=%@\nversion hook=%@\nruntime-wide scan=NO\nbrowser scan=ON-DEMAND only\nmode=exact class+selector registry",
            (unsigned long)gWAGRNativeOrig.count,
            (unsigned long)registry.count,
            WAGRDebugSurfaceEnabled() ? @"ON" : @"OFF",
            WAGREmployeeSurfaceEnabled() ? @"ON" : @"OFF",
            WAGRMultiAccountSurfaceEnabled() ? @"ON" : @"OFF",
            gWAGRNativeVersionHooksInstalled ? @"ON" : @"OFF"];
}

__attribute__((constructor))
static void WAGRNativePersistedExactCtor(void) {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRNativeBoolOverrideInstallPersisted();
        });
    }
}
