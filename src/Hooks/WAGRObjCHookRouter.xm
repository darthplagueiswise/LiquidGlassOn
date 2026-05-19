// WAGRObjCHookRouter.xm — Zero Logos. MSHookMessageEx only.
// Install ONE generic hook per class. All entries for the same class share it.
// Toggle = NSUserDefaults setBool/removeObject. No uninstall.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"
#import "../Runtime/WAGRSurface.h"

// ── Installed hooks registry ──────────────────────────────────────────────────
// key: "ClassName.inst/class.selector" → NSValue(orig IMP)
static NSMutableDictionary<NSString*,NSValue*> *gOriginals  = nil;
static NSMutableDictionary<NSString*,NSString*> *gKeyMap    = nil; // selName→overrideKey
static NSMutableSet<NSString*>                  *gInstalled = nil;
static dispatch_once_t gOnce;

static void WAGRHookEnsureStorage(void) {
    dispatch_once(&gOnce, ^{
        gOriginals = [NSMutableDictionary dictionaryWithCapacity:256];
        gKeyMap    = [NSMutableDictionary dictionaryWithCapacity:256];
        gInstalled = [NSMutableSet setWithCapacity:64];
    });
}

// ── Generic BOOL hook — shared IMP for all hookable methods ──────────────────
static BOOL WAGRGenericBoolHook(id self, SEL _cmd) {
    NSString *cname = NSStringFromClass(
        class_isMetaClass(object_getClass(self))
            ? (Class)self
            : [self class]
    );
    BOOL isMeta = class_isMetaClass(object_getClass(self));
    NSString *sel = NSStringFromSelector(_cmd);

    // Build storage key — search registry for a matching surface
    NSString *hookID = [NSString stringWithFormat:@"%@.%@.%@", cname, isMeta?@"class":@"inst", sel];
    NSString *overrideKey = gKeyMap[hookID];

    // Call original first — record observed
    typedef BOOL (*BoolIMP)(id, SEL);
    BoolIMP orig = NULL;
    NSValue *v = gOriginals[hookID];
    if (v) orig = reinterpret_cast<BoolIMP>([v pointerValue]);
    BOOL original = orig ? orig(self, _cmd) : NO;
    if (overrideKey) WAGRRecordObserved(overrideKey, original);

    if (overrideKey && WAGRHasOverride(overrideKey))
        return WAGROverrideBool(overrideKey);
    return original;
}

// ── Install hook for one entry ─────────────────────────────────────────────────
extern "C" BOOL WAGRInstallHookForEntry(WAGREntry *e) {
    WAGRHookEnsureStorage();
    if (!e) return NO;
    NSString *hookID = [NSString stringWithFormat:@"%@.%@.%@",
                        e.className, e.isClassMethod?@"class":@"inst", e.selectorName];
    if ([gInstalled containsObject:hookID]) {
        // Already hooked — just make sure key map has it
        gKeyMap[hookID] = e.overrideKey;
        return YES;
    }
    Class cls = NSClassFromString(e.className);
    if (!cls) return NO;
    SEL sel = NSSelectorFromString(e.selectorName);
    Class target = e.isClassMethod ? object_getClass(cls) : cls;
    Method m = e.isClassMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!m) return NO;
    char ret[8]={0}; method_getReturnType(m, ret, 8);
    if (ret[0]!='B' && ret[0]!='c') return NO;
    IMP orig = NULL;
    MSHookMessageEx(target, sel, (IMP)WAGRGenericBoolHook, &orig);
    if (!orig) return NO;
    gOriginals[hookID] = [NSValue valueWithPointer:reinterpret_cast<const void *>(orig)];
    gKeyMap[hookID] = e.overrideKey;
    [gInstalled addObject:hookID];
    return YES;
}

// ── Reinstall all persisted overrides ─────────────────────────────────────────
// Called on startup — scans NSUserDefaults for wagr.override.* and hooks those classes.
extern "C" NSUInteger WAGRReinstallPersistedHooks(void) {
    WAGRHookEnsureStorage();
    NSDictionary *all = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSUInteger installed = 0;
    for (NSString *key in all) {
        if (![key hasPrefix:@"wagr.override"]) continue;

        NSString *surfaceID = nil;
        NSString *className = nil;
        NSString *mode = nil;
        NSString *selName = nil;

        if ([key hasPrefix:@"wagr.override|"]) {
            NSArray<NSString *> *parts = [key componentsSeparatedByString:@"|"];
            if (parts.count < 5) continue;
            surfaceID = parts[1];
            className = parts[2];
            mode = parts[3];
            selName = [[parts subarrayWithRange:NSMakeRange(4, parts.count - 4)] componentsJoinedByString:@"|"];
        } else {
            // Legacy dot-separated key. Kept only for old installs.
            NSArray<NSString *> *parts = [key componentsSeparatedByString:@"."];
            if (parts.count < 6) continue;
            surfaceID = parts[2];
            className = parts[3];
            mode = parts[4];
            selName = [[parts subarrayWithRange:NSMakeRange(5, parts.count - 5)] componentsJoinedByString:@"."];
        }

        if (!className.length || !selName.length) continue;
        WAGREntry *e = [WAGREntry new];
        e.surfaceID = surfaceID ?: @"runtime";
        e.className = className;
        e.isClassMethod = [mode isEqualToString:@"class"];
        e.selectorName = selName;
        e.displayName = selName;
        e.category = WAGRCategoryForSelector(selName);
        e.returnType = @"BOOL";
        e.overrideKey = key;
        if (WAGRInstallHookForEntry(e)) installed++;
    }
    NSLog(@"[WAGram][Router] reinstalled %lu persisted hooks", (unsigned long)installed);
    return installed;
}

extern "C" NSUInteger WAGRInstalledHookCount(void) {
    WAGRHookEnsureStorage();
    return gInstalled.count;
}
extern "C" NSString *WAGRHookRouterDiagnostic(void) {
    WAGRHookEnsureStorage();
    NSUInteger overrides=0;
    for(NSString*k in [[NSUserDefaults standardUserDefaults]dictionaryRepresentation])
        if([k hasPrefix:@"wagr.override."])overrides++;
    return [NSString stringWithFormat:@"installed hooks = %lu\nactive overrides = %lu",
        (unsigned long)gInstalled.count, (unsigned long)overrides];
}
