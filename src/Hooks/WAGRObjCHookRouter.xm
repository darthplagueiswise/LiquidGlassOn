// WAGRObjCHookRouter.xm — dynamic ObjC BOOL hook router.
// Uses the unified WATweaks persistence namespace.
// Only installs exact saved/toggled selectors; no broad runtime scan.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../Runtime/WAGRSurface.h"

typedef BOOL (*WAGRBoolIMP)(id, SEL);

static NSMutableDictionary<NSString *, NSValue *> *gOriginals;
static NSMutableDictionary<NSString *, NSString *> *gKeyMap;
static NSMutableSet<NSString *> *gInstalled;
static NSUInteger gSkippedMissingClass = 0;
static NSUInteger gSkippedMissingMethod = 0;
static NSUInteger gSkippedBadSignature = 0;
static NSUInteger gSkippedBadImage = 0;

static void WAGRRouterInit(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gOriginals = [NSMutableDictionary dictionary];
        gKeyMap = [NSMutableDictionary dictionary];
        gInstalled = [NSMutableSet set];
    });
}

static BOOL WAGRPathIsAllowed(NSString *path) {
    if (!path.length) return NO;
    NSString *p = path.lowercaseString;
    return [p containsString:@"/whatsapp.app/whatsapp"] ||
           [p containsString:@"/frameworks/sharedmodules.framework/sharedmodules"];
}

static BOOL WAGRMethodImageAllowed(Method m) {
    if (!m) return NO;
    IMP imp = method_getImplementation(m);
    if (!imp) return NO;
    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (!dladdr((const void *)imp, &info) || !info.dli_fname) return NO;
    return WAGRPathIsAllowed(@(info.dli_fname));
}

static BOOL WAGRReturnIsBool(Method m) {
    if (!m) return NO;
    char ret[16] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    return ret[0] == 'B' || ret[0] == 'c';
}

static NSString *WAGRHookIDForParts(NSString *className, NSString *kind, NSString *selectorName) {
    return [NSString stringWithFormat:@"%@.%@.%@", className ?: @"", kind ?: @"inst", selectorName ?: @""];
}

static BOOL WAGRParseObjCOverrideKey(NSString *key, NSString **className, BOOL *isClassMethod, NSString **selectorName) {
    if (![key hasPrefix:kWATweaksOverrideObjCPrefix]) return NO;
    NSString *suffix = [key substringFromIndex:kWATweaksOverrideObjCPrefix.length];
    NSArray<NSString *> *parts = [suffix componentsSeparatedByString:@"|"];
    if (parts.count < 3) return NO;
    NSString *cls = parts[0];
    NSString *kind = parts[1];
    NSString *sel = [[parts subarrayWithRange:NSMakeRange(2, parts.count - 2)] componentsJoinedByString:@"|"];
    if (!cls.length || !sel.length) return NO;
    if (className) *className = cls;
    if (isClassMethod) *isClassMethod = [kind isEqualToString:@"class"];
    if (selectorName) *selectorName = sel;
    return YES;
}

static NSString *WAGRFindHookID(id self, SEL _cmd) {
    WAGRRouterInit();
    NSString *sel = NSStringFromSelector(_cmd);
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];

    Class runtimeClass = object_getClass(self);
    if (runtimeClass && class_isMetaClass(runtimeClass)) {
        Class realClass = (Class)self;
        [candidates addObject:WAGRHookIDForParts(NSStringFromClass(realClass), @"class", sel)];
    }

    Class instanceClass = [self class];
    if (instanceClass) {
        [candidates addObject:WAGRHookIDForParts(NSStringFromClass(instanceClass), @"inst", sel)];
        [candidates addObject:WAGRHookIDForParts(NSStringFromClass(instanceClass), @"class", sel)];
    }

    for (NSString *hookID in candidates) {
        if (gKeyMap[hookID].length) return hookID;
    }
    return nil;
}

static BOOL WAGRGenericBoolHook(id self, SEL _cmd) {
    WAGRRouterInit();
    NSString *hookID = WAGRFindHookID(self, _cmd);
    NSString *overrideKey = hookID.length ? gKeyMap[hookID] : nil;

    WAGRBoolIMP orig = NULL;
    NSValue *v = hookID.length ? gOriginals[hookID] : nil;
    if (v) orig = reinterpret_cast<WAGRBoolIMP>([v pointerValue]);

    BOOL original = orig ? orig(self, _cmd) : NO;
    if (overrideKey.length) WAGRRecordObserved(overrideKey, original);

    if (overrideKey.length && WAGRHasOverride(overrideKey)) return WAGROverrideBool(overrideKey);
    return original;
}

static BOOL WAGRInstallObjCOverrideByParts(NSString *overrideKey, NSString *className, BOOL isClassMethod, NSString *selectorName) {
    WAGRRouterInit();

    Class cls = NSClassFromString(className);
    if (!cls) { gSkippedMissingClass++; return NO; }

    SEL sel = NSSelectorFromString(selectorName);
    Class target = isClassMethod ? object_getClass(cls) : cls;
    Method m = class_getInstanceMethod(target, sel);
    if (!m) { gSkippedMissingMethod++; return NO; }

    if (method_getNumberOfArguments(m) != 2 || !WAGRReturnIsBool(m)) {
        gSkippedBadSignature++;
        return NO;
    }

    if (!WAGRMethodImageAllowed(m)) {
        gSkippedBadImage++;
        return NO;
    }

    NSString *kind = isClassMethod ? @"class" : @"inst";
    NSString *hookID = WAGRHookIDForParts(className, kind, selectorName);
    gKeyMap[hookID] = overrideKey ?: @"";

    if ([gInstalled containsObject:hookID]) return YES;

    IMP old = NULL;
    MSHookMessageEx(target, sel, (IMP)WAGRGenericBoolHook, &old);
    if (!old) return NO;

    gOriginals[hookID] = [NSValue valueWithPointer:reinterpret_cast<const void *>(old)];
    [gInstalled addObject:hookID];
    return YES;
}

extern "C" BOOL WAGRInstallHookForEntry(WAGREntry *entry) {
    if (!entry || !entry.overrideKey.length) return NO;
    if (WATweaksIsWAABOverrideKey(entry.overrideKey)) return YES; // handled by FOAWAABPropertiesImpl core hook
    NSString *className = entry.className ?: @"";
    NSString *selectorName = entry.selectorName ?: @"";
    return WAGRInstallObjCOverrideByParts(entry.overrideKey, className, entry.isClassMethod, selectorName);
}

extern "C" NSUInteger WAGRReinstallPersistedHooks(void) {
    WAGRRouterInit();
    WATweaksMigrateLegacyDefaults();

    NSUInteger installed = 0;
    NSDictionary *all = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *key in all.allKeys) {
        NSString *className = nil;
        NSString *selectorName = nil;
        BOOL isClassMethod = NO;
        if (!WAGRParseObjCOverrideKey(key, &className, &isClassMethod, &selectorName)) continue;
        if (WAGRInstallObjCOverrideByParts(key, className, isClassMethod, selectorName)) installed++;
    }
    return installed;
}

extern "C" NSString *WAGRHookRouterDiagnostic(void) {
    WAGRRouterInit();
    NSUInteger objcOverrides = WATweaksObjCOverrideCount();
    NSUInteger waabOverrides = WATweaksWAABOverrideCount();
    NSUInteger legacy = 0;
    for (NSString *k in [NSUserDefaults standardUserDefaults].dictionaryRepresentation.allKeys) {
        if ([k hasPrefix:@"wagr."] || [k hasPrefix:@"wagr_"]) legacy++;
    }

    return [NSString stringWithFormat:
            @"dynamic router hooks installed = %lu\n"
             "unique overrides = %lu\n"
             "objc overrides = %lu\n"
             "waab overrides = %lu\n"
             "legacy keys = %lu\n"
             "auto startup apply = automatic\n"
             "skipped missing class = %lu\n"
             "skipped missing method = %lu\n"
             "skipped bad signature = %lu\n"
             "skipped bad image = %lu",
            (unsigned long)gInstalled.count,
            (unsigned long)(objcOverrides + waabOverrides),
            (unsigned long)objcOverrides,
            (unsigned long)waabOverrides,
            (unsigned long)legacy,
            (unsigned long)gSkippedMissingClass,
            (unsigned long)gSkippedMissingMethod,
            (unsigned long)gSkippedBadSignature,
            (unsigned long)gSkippedBadImage];
}
