// WAEmployeeDogfoodHooks.xm
// Hooks the four validated employee/dogfood gates found in SharedModules.
// Toggle: kWAGREmployeeMaster (default OFF). Hooks are only scheduled when ON.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL (*orig_isMetaEmployeeOrInternalTester)(id, SEL) = NULL;
static BOOL (*orig_is_meta_employee_getter)(id, SEL) = NULL;
static BOOL (*orig_isInternalUser)(id, SEL) = NULL;
static BOOL (*orig_graphQLEmployeeC1Disabled)(id, SEL) = NULL;

static BOOL _wagrDFHooksInstalled = NO;

static BOOL hook_isMetaEmployeeOrInternalTester(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return YES;
    return orig_isMetaEmployeeOrInternalTester ? orig_isMetaEmployeeOrInternalTester(self, _cmd) : NO;
}

static BOOL hook_is_meta_employee_getter(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return YES;
    return orig_is_meta_employee_getter ? orig_is_meta_employee_getter(self, _cmd) : NO;
}

static BOOL hook_isInternalUser(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return YES;
    return orig_isInternalUser ? orig_isInternalUser(self, _cmd) : NO;
}

static BOOL hook_graphQLEmployeeC1Disabled(id self, SEL _cmd) {
    if (WAGRPref(kWAGREmployeeMaster)) return NO;
    return orig_graphQLEmployeeC1Disabled ? orig_graphQLEmployeeC1Disabled(self, _cmd) : YES;
}

static void WAGRDFInstallOnClass(Class cls) {
    if (!cls) return;

    struct {
        const char *sel_name;
        IMP hook;
        IMP *orig;
    } entries[] = {
        { "isMetaEmployeeOrInternalTester", (IMP)hook_isMetaEmployeeOrInternalTester, (IMP *)&orig_isMetaEmployeeOrInternalTester },
        { "is_meta_employee_or_internal_tester", (IMP)hook_is_meta_employee_getter, (IMP *)&orig_is_meta_employee_getter },
        { "isInternalUser", (IMP)hook_isInternalUser, (IMP *)&orig_isInternalUser },
        { "graphQLEmployeeC1Disabled", (IMP)hook_graphQLEmployeeC1Disabled, (IMP *)&orig_graphQLEmployeeC1Disabled },
    };

    for (size_t i = 0; i < sizeof(entries) / sizeof(entries[0]); i++) {
        SEL sel = sel_registerName(entries[i].sel_name);
        if (!class_getInstanceMethod(cls, sel)) continue;
        if (*entries[i].orig) continue;
        MSHookMessageEx(cls, sel, entries[i].hook, entries[i].orig);
        NSLog(@"[WAGram][Dogfood] hooked -%s on %@", entries[i].sel_name, NSStringFromClass(cls));
    }
}

static void WAGRDFInstallHooks(void) {
    if (_wagrDFHooksInstalled) return;
    if (!WAGRPref(kWAGREmployeeMaster)) return;

    NSArray<NSString *> *targetClasses = @[
        @"WAUserContext",
        @"WAAccountInfo",
        @"WAAccountManager",
        @"WADeviceInfo",
        @"WAUserPreferences",
        @"WAEmployeeGating",
    ];

    for (NSString *name in targetClasses) {
        WAGRDFInstallOnClass(NSClassFromString(name));
    }

    unsigned int mainCount = 0;
    const char **mainNames = objc_copyClassNamesForImage([[NSBundle mainBundle] executablePath].UTF8String, &mainCount);
    if (mainNames) {
        for (unsigned int i = 0; i < mainCount && i < 2000; i++) {
            WAGRDFInstallOnClass(objc_getClass(mainNames[i]));
        }
        free(mainNames);
    }

    NSString *sharedPath = nil;
    for (NSBundle *b in [NSBundle allFrameworks]) {
        NSString *name = b.executablePath.lastPathComponent ?: @"";
        NSString *bid = b.bundleIdentifier ?: @"";
        if ([name containsString:@"SharedModules"] || [bid containsString:@"SharedModules"]) {
            sharedPath = b.executablePath;
            break;
        }
    }

    if (sharedPath.length) {
        unsigned int smCount = 0;
        const char **smNames = objc_copyClassNamesForImage(sharedPath.UTF8String, &smCount);
        if (smNames) {
            for (unsigned int i = 0; i < smCount && i < 2000; i++) {
                WAGRDFInstallOnClass(objc_getClass(smNames[i]));
            }
            free(smNames);
        }
    }

    _wagrDFHooksInstalled = YES;
    NSLog(@"[WAGram][Dogfood] hook installation pass complete");
}

__attribute__((constructor))
static void WAGRDogfoodInit(void) {
    @autoreleasepool {
        if (!WAGRPref(kWAGREmployeeMaster)) {
            NSLog(@"[WAGram][Dogfood] inert startup: employee master OFF");
            return;
        }
        double delays[] = { 0.5, 2.0, 5.0 };
        for (size_t i = 0; i < 3; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (!_wagrDFHooksInstalled && WAGRPref(kWAGREmployeeMaster)) WAGRDFInstallHooks();
            });
        }
        NSLog(@"[WAGram][Dogfood] scheduled hook install passes because toggle is ON");
    }
}

extern "C" void WAGRDogfoodEnsureHooksInstalled(void) {
    if (WAGRPref(kWAGREmployeeMaster) && !_wagrDFHooksInstalled) WAGRDFInstallHooks();
}

extern "C" NSString *WAGRDogfoodDiagnosticText(void) {
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
        orig_is_meta_employee_getter ? @"found" : @"missing",
        orig_isInternalUser ? @"found" : @"missing",
        orig_graphQLEmployeeC1Disabled ? @"found" : @"missing"];
}
