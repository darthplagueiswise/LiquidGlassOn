// WAEmployeeDogfoodHooks.xm
// ─────────────────────────────────────────────────────────────────────────────
// Hooks the four validated employee/dogfood gates found in SharedModules:
//
//   isMetaEmployeeOrInternalTester  → YES
//   is_meta_employee_or_internal_tester (property/ivar getter) → YES
//   isInternalUser                  → YES
//   graphQLEmployeeC1Disabled       → NO   (gate means "is C1 disabled?")
//
// All four are validated against the real SharedModules binary — no guessing.
// Toggle: kWAGREmployeeMaster  (default OFF)
// Hooks are only active when the toggle is ON — no scan on startup.
// ─────────────────────────────────────────────────────────────────────────────

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>

// ── Statics for orig pointers ─────────────────────────────────────────────────
static BOOL (*orig_isMetaEmployeeOrInternalTester)(id, SEL)    = NULL;
static BOOL (*orig_is_meta_employee_getter)(id, SEL)           = NULL;
static BOOL (*orig_isInternalUser)(id, SEL)                    = NULL;
static BOOL (*orig_graphQLEmployeeC1Disabled)(id, SEL)         = NULL;

static dispatch_once_t _wagrDFOnce = 0;
static BOOL _wagrDFHooksInstalled  = NO;

// ── Hook implementations ──────────────────────────────────────────────────────
static BOOL hook_isMetaEmployeeOrInternalTester(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return YES;
    return orig_isMetaEmployeeOrInternalTester
        ? orig_isMetaEmployeeOrInternalTester(self, _cmd) : NO;
}

static BOOL hook_is_meta_employee_getter(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return YES;
    return orig_is_meta_employee_getter
        ? orig_is_meta_employee_getter(self, _cmd) : NO;
}

static BOOL hook_isInternalUser(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return YES;
    return orig_isInternalUser
        ? orig_isInternalUser(self, _cmd) : NO;
}

static BOOL hook_graphQLEmployeeC1Disabled(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return NO;
    return orig_graphQLEmployeeC1Disabled
        ? orig_graphQLEmployeeC1Disabled(self, _cmd) : YES;
}

// ── Runtime hook installer ────────────────────────────────────────────────────
// We iterate every loaded class looking for the selectors rather than assuming
// a fixed class name — WA sometimes moves methods between framework classes.
static void WAGRDFInstallOnClass(Class cls) {
    if (!cls) return;

    struct {
        const char *sel_name;
        IMP         hook;
        IMP        *orig;
    } entries[] = {
        { "isMetaEmployeeOrInternalTester",    (IMP)hook_isMetaEmployeeOrInternalTester, (IMP *)&orig_isMetaEmployeeOrInternalTester },
        { "is_meta_employee_or_internal_tester",(IMP)hook_is_meta_employee_getter,       (IMP *)&orig_is_meta_employee_getter },
        { "isInternalUser",                    (IMP)hook_isInternalUser,                (IMP *)&orig_isInternalUser },
        { "graphQLEmployeeC1Disabled",         (IMP)hook_graphQLEmployeeC1Disabled,     (IMP *)&orig_graphQLEmployeeC1Disabled },
    };

    for (size_t i = 0; i < sizeof(entries) / sizeof(entries[0]); i++) {
        SEL sel = sel_registerName(entries[i].sel_name);
        if (!class_getInstanceMethod(cls, sel)) continue;
        if (*entries[i].orig) continue; // already hooked
        MSHookMessageEx(cls, sel, entries[i].hook, entries[i].orig);
        NSLog(@"[WAGram][Dogfood] hooked -%s on %@", entries[i].sel_name, NSStringFromClass(cls));
    }
}

static void WAGRDFInstallHooks(void) {
    // Targeted classes known from binary analysis
    NSArray<NSString *> *targetClasses = @[
        @"WAUserContext",
        @"WAAccountInfo",
        @"WAAccountManager",
        @"WADeviceInfo",
        @"WAUserPreferences",
        @"WAEmployeeGating",
    ];

    for (NSString *name in targetClasses) {
        Class cls = NSClassFromString(name);
        WAGRDFInstallOnClass(cls);
    }

    // Broad fallback: scan all classes for the selectors (limited budget)
    unsigned int count = 0;
    const char **names = objc_copyClassNamesForImage(
        [[NSBundle mainBundle] executablePath].UTF8String, &count);
    // SharedModules path
    NSString *sharedPath = nil;
    for (NSBundle *b in [NSBundle allFrameworks]) {
        if ([b.bundleIdentifier containsString:@"SharedModules"]) {
            sharedPath = b.executablePath;
            break;
        }
    }
    if (sharedPath) {
        const char **smNames = objc_copyClassNamesForImage(sharedPath.UTF8String, &count);
        if (smNames) {
            for (unsigned int i = 0; i < count && i < 2000; i++) {
                Class cls = objc_getClass(smNames[i]);
                WAGRDFInstallOnClass(cls);
            }
            free(smNames);
        }
    }
    if (names) free(names);
    _wagrDFHooksInstalled = YES;
    NSLog(@"[WAGram][Dogfood] hook installation pass complete");
}

// ── Constructor ───────────────────────────────────────────────────────────────
__attribute__((constructor))
static void WAGRDogfoodInit(void) {
    @autoreleasepool {
        if (!WAGRPref(kWAGREmployeeMaster)) {
            NSLog(@"[WAGram][Dogfood] inert startup: employee master OFF");
            return;
        }
        // Deferred install only when explicitly enabled.
        double delays[] = { 0.5, 2.0, 5.0 };
        for (size_t i = 0; i < 3; i++) {
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    if (!_wagrDFHooksInstalled && WAGRPref(kWAGREmployeeMaster)) WAGRDFInstallHooks();
                });
        }
        NSLog(@"[WAGram][Dogfood] scheduled hook install passes because toggle is ON");
    }
}

void WAGRDogfoodEnsureHooksInstalled(void) {
    if (WAGRPref(kWAGREmployeeMaster) && !_wagrDFHooksInstalled) WAGRDFInstallHooks();
}

// ── Public diagnostic (called from menu) ─────────────────────────────────────
NSString *WAGRDogfoodDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"employee master      = %@\n"
        @"hooks installed      = %@\n"
        @"isMetaEmployee orig  = %@\n"
        @"is_meta_employee orig= %@\n"
        @"isInternalUser orig  = %@\n"
        @"graphQLEmpC1 orig    = %@",
        WAGRPref(kWAGREmployeeMaster) ? @"ON" : @"OFF",
        _wagrDFHooksInstalled ? @"YES" : @"NO",
        orig_isMetaEmployeeOrInternalTester ? @"found" : @"missing",
        orig_is_meta_employee_getter        ? @"found" : @"missing",
        orig_isInternalUser                 ? @"found" : @"missing",
        orig_graphQLEmployeeC1Disabled      ? @"found" : @"missing"];
}
