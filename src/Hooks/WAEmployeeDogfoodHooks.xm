// WAEmployeeDogfoodHooks.xm
// Persistent selector hooks for WhatsApp employee/dogfood/internal gates.
// Hooks are always installed; return value is controlled by persisted toggles.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "../WAGramPrefix.h"

static BOOL (*orig_isMetaEmployeeOrInternalTester)(id, SEL) = NULL;
static BOOL (*orig_is_meta_employee_getter)(id, SEL) = NULL;
static BOOL (*orig_isInternalUser)(id, SEL) = NULL;
static BOOL (*orig_graphQLEmployeeC1Disabled)(id, SEL) = NULL;

static BOOL _wagrDFHooksInstalled = NO;
static NSUInteger _wagrDFHookedCount = 0;

static BOOL WAGRDogfoodMasterEnabled(void) {
    return WAGRPref(kWAGREmployeeMaster) || WAGRPref(kWAGRInternalMaster) || WAGRPref(kWAGRDebugMode);
}

static BOOL WAGRDogfoodGateEnabled(NSString *gateKey) {
    return WAGRDogfoodMasterEnabled() || WAGRPref(gateKey);
}

static BOOL hook_isMetaEmployeeOrInternalTester(id self, SEL _cmd) {
    if (WAGRDogfoodGateEnabled(kWAGRDogfoodGateMetaEmployee)) return YES;
    return orig_isMetaEmployeeOrInternalTester ? orig_isMetaEmployeeOrInternalTester(self, _cmd) : NO;
}

static BOOL hook_is_meta_employee_getter(id self, SEL _cmd) {
    if (WAGRDogfoodGateEnabled(kWAGRDogfoodGateMetaEmployeeSnake)) return YES;
    return orig_is_meta_employee_getter ? orig_is_meta_employee_getter(self, _cmd) : NO;
}

static BOOL hook_isInternalUser(id self, SEL _cmd) {
    if (WAGRDogfoodGateEnabled(kWAGRDogfoodGateInternalUser)) return YES;
    return orig_isInternalUser ? orig_isInternalUser(self, _cmd) : NO;
}

static BOOL hook_graphQLEmployeeC1Disabled(id self, SEL _cmd) {
    if (WAGRDogfoodGateEnabled(kWAGRDogfoodGateGraphQLEmpC1)) return NO;
    return orig_graphQLEmployeeC1Disabled ? orig_graphQLEmployeeC1Disabled(self, _cmd) : YES;
}

static void WAGRDFHookOne(Class cls, BOOL classMethod, const char *selName, IMP hook, IMP *orig) {
    if (!cls || !selName || !hook || !orig || *orig) return;
    SEL sel = sel_registerName(selName);
    Method m = classMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!m) return;
    Class target = classMethod ? object_getClass(cls) : cls;
    if (!target) return;
    MSHookMessageEx(target, sel, hook, orig);
    _wagrDFHookedCount++;
    NSLog(@"[WAGram][Dogfood] hooked %@[%@ %s]", classMethod ? @"+" : @"-", NSStringFromClass(cls), selName);
}

static void WAGRDFInstallOnClass(Class cls) {
    if (!cls) return;
    struct { const char *sel_name; IMP hook; IMP *orig; } entries[] = {
        { "isMetaEmployeeOrInternalTester", (IMP)hook_isMetaEmployeeOrInternalTester, (IMP *)&orig_isMetaEmployeeOrInternalTester },
        { "is_meta_employee_or_internal_tester", (IMP)hook_is_meta_employee_getter, (IMP *)&orig_is_meta_employee_getter },
        { "isInternalUser", (IMP)hook_isInternalUser, (IMP *)&orig_isInternalUser },
        { "graphQLEmployeeC1Disabled", (IMP)hook_graphQLEmployeeC1Disabled, (IMP *)&orig_graphQLEmployeeC1Disabled },
    };
    for (size_t i = 0; i < sizeof(entries) / sizeof(entries[0]); i++) {
        WAGRDFHookOne(cls, NO, entries[i].sel_name, entries[i].hook, entries[i].orig);
        WAGRDFHookOne(cls, YES, entries[i].sel_name, entries[i].hook, entries[i].orig);
    }
}

static BOOL WAGRDFAllCoreHooksReady(void) {
    return orig_isMetaEmployeeOrInternalTester &&
           orig_is_meta_employee_getter &&
           orig_isInternalUser &&
           orig_graphQLEmployeeC1Disabled;
}

static void WAGRDFInstallHooks(void) {
    if (_wagrDFHooksInstalled && WAGRDFAllCoreHooksReady()) return;
    NSArray<NSString *> *targetClasses = @[
        @"WAABProperties",
        @"WAUserContext",
        @"WAAccountInfo",
        @"WAAccountManager",
        @"WADeviceInfo",
        @"WAUserPreferences",
        @"WAEmployeeGating",
        @"WADebugMenuMain",
        @"WADebugViewController",
        @"WASettingsViewController",
    ];
    for (NSString *name in targetClasses) WAGRDFInstallOnClass(NSClassFromString(name));

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (classes) {
        for (unsigned int i = 0; i < count; i++) {
            Class cls = classes[i];
            NSString *name = NSStringFromClass(cls);
            if (![name containsString:@"WA"] && ![name containsString:@"Debug"] && ![name containsString:@"Employee"] && ![name containsString:@"Dogfood"] && ![name containsString:@"ABProperties"]) continue;
            WAGRDFInstallOnClass(cls);
            if (orig_isMetaEmployeeOrInternalTester && orig_is_meta_employee_getter && orig_isInternalUser && orig_graphQLEmployeeC1Disabled) break;
        }
        free(classes);
    }
    _wagrDFHooksInstalled = WAGRDFAllCoreHooksReady();
    NSLog(@"[WAGram][Dogfood] hook installation pass complete; installed=%@ hooked=%lu",
          _wagrDFHooksInstalled ? @"YES" : @"NO",
          (unsigned long)_wagrDFHookedCount);
}

__attribute__((constructor))
static void WAGRDogfoodInit(void) {
    @autoreleasepool {
        double delays[] = { 0.2, 1.0, 3.0, 6.0 };
        for (size_t i = 0; i < 4; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ WAGRDFInstallHooks(); });
        }
        NSLog(@"[WAGram][Dogfood] scheduled persistent hook install passes");
    }
}

extern "C" void WAGRDogfoodEnsureHooksInstalled(void) { WAGRDFInstallHooks(); }

extern "C" NSString *WAGRDogfoodDiagnosticText(void) {
    return [NSString stringWithFormat:
        @"employee master      = %@\n"
        @"internal master      = %@\n"
        @"debug mode           = %@\n"
        @"effective force      = %@\n"
        @"gate meta employee   = %@\n"
        @"gate meta snake      = %@\n"
        @"gate internal user   = %@\n"
        @"gate graphQL C1      = %@\n"
        @"hooks installed      = %@\n"
        @"hooked count         = %lu\n"
        @"isMetaEmployee orig  = %@\n"
        @"is_meta_employee orig= %@\n"
        @"isInternalUser orig  = %@\n"
        @"graphQLEmpC1 orig    = %@",
        WAGRPref(kWAGREmployeeMaster) ? @"ON" : @"OFF",
        WAGRPref(kWAGRInternalMaster) ? @"ON" : @"OFF",
        WAGRPref(kWAGRDebugMode) ? @"ON" : @"OFF",
        WAGRDogfoodMasterEnabled() ? @"ON" : @"OFF",
        WAGRPref(kWAGRDogfoodGateMetaEmployee) ? @"ON" : @"OFF",
        WAGRPref(kWAGRDogfoodGateMetaEmployeeSnake) ? @"ON" : @"OFF",
        WAGRPref(kWAGRDogfoodGateInternalUser) ? @"ON" : @"OFF",
        WAGRPref(kWAGRDogfoodGateGraphQLEmpC1) ? @"ON" : @"OFF",
        _wagrDFHooksInstalled ? @"YES" : @"NO",
        (unsigned long)_wagrDFHookedCount,
        orig_isMetaEmployeeOrInternalTester ? @"found" : @"missing",
        orig_is_meta_employee_getter ? @"found" : @"missing",
        orig_isInternalUser ? @"found" : @"missing",
        orig_graphQLEmployeeC1Disabled ? @"found" : @"missing"];
}
