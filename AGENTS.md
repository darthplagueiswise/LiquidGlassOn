# AGENTS.md — LiquidGlassOn / WAGram v191 Functional Dylib Base

## Read this first

This repository must use the **functional standalone `LiquidGlassOn.dylib` v191/dev2** as the source-of-truth contract.

Functional binary identity:

```text
file: LiquidGlassOn.dylib
type: Mach-O 64-bit arm64 dylib
size: 214,912 bytes
sha256: 692171b6c462ae36a4464de4a34d0c2c3265dc662c618680a821a22096bc4587
```

The current goal is **not** to redesign the core. The goal is to reconstruct source code that behaves like the functional dylib, then improve UI around it.

The functional dylib is incomplete and visually rough, but its hook/persistence architecture works. Preserve that behavior.

Do not import v8/v7 UI code that changes storage or hook semantics unless it is explicitly adapted to the v191 contract.

---

## Non-negotiable rules

1. **Do not change the persistence contract while reconstructing v191.**
2. **Do not replace working hooks with illustrative UI-only toggles.**
3. **Do not remove `WAGRABFlagBrowserVC`, `WAGRWAABTriStateBrowserVC`, `WAGramWAABRuntimeCategoriesVC`, `WAGRRuntimeMethodBrowserVC`, `WAGRNativeSurface`, or Bundle hooks.**
4. **Do not add broad runtime scans at startup.**
5. **Do not set an “installed” flag before at least one real hook has been installed.**
6. **Do not mix old and new menu model names.**
7. **Do not convert WAAB `on/off` storage to boolean storage in this reconstruction phase.**
8. **Do not use `.mode` integer storage for WAAB flags.**
9. **Do not use `extern "C"` inside `.m` files. Use it only in `.xm`/`.mm` or inside `#ifdef __cplusplus` guards in headers.**
10. **Every change must preserve the exported API names listed below.**

---

## Extracted functional exports that must remain available

The functional dylib exports these key symbols and UI classes. Source reconstruction must preserve them or provide compatible equivalents.

```text
OBJC_CLASS_$_WAGRABFlagBrowserVC
OBJC_CLASS_$_WAGRGestureTarget
OBJC_CLASS_$_WAGRHeader
OBJC_CLASS_$_WAGRRuntimeMethodBrowserVC
OBJC_CLASS_$_WAGRWAABCategoryBundleVC
OBJC_CLASS_$_WAGRWAABCategorySpec
OBJC_CLASS_$_WAGRWAABTriStateBrowserVC
OBJC_CLASS_$_WAGramBundleVC
OBJC_CLASS_$_WAGramMenuVC
OBJC_CLASS_$_WAGramWAABRuntimeCategoriesVC

WAClassRespondsTo
WAClassesMatchingFragments
WAEnabled
WAFindClassByNameFragment
WAGRABObsClear
WAGRABObsLog
WAGRAuraActivateAllFlags
WAGRAuraDeactivateAllFlags
WAGRAuraDiagnostic
WAGRAuraEnsureHooksInstalled
WAGRBundleEnsureHooksInstalled
WAGRDebugMenuDiagnosticText
WAGRDebugMenuEnsureHooksInstalled
WAGRDogfoodDiagnosticText
WAGRDogfoodEnsureHooksInstalled
WAGRLGDiagnosticText
WAGRLGPrefsDidChange
WAGRNativeBoolOverrideGet
WAGRNativeBoolOverrideInstallPersisted
WAGRNativeBoolOverrideSet
WAGRNativeSurfaceDiagnosticText
WAGRNativeSurfaceEnsureHooksInstalled
WAGROpenSubscriptionsNative
WAGRPushAuraIconsVC
WAGRPushAuraRingtonesVC
WAGRPushAuraThemesVC
WAGRWAABDiagnosticText
WAGRWAABEnsureHooksInstalled
WAInstallKeychainPatchIfNeeded
WAInstanceRespondsTo
WAKeychainAccessGroupDiagnostic
WAPresentAlert
WARegisterDefaults
WASetEnabled
WAStringFromObject
```

Expected constructor/init order from the functional dylib:

```text
0: 0x4bac  settings/debug/menu ctor
1: 0x7258  bundle WAAB hooks ctor
2: 0x7460  LiquidGlass Logos ctor
3: 0x9598  NativeSurface ctor
4: 0x9d44  Dogfood/Employee ctor
5: 0xaff0  WAAB observer ctor
```

The source does not need identical addresses, but it must preserve the same functional order.

---

## Persistence contract

### 1. Tweak master preferences

Master prefs are boolean `NSUserDefaults` keys.

Examples:

```text
wa_employee_master
wagr_native_debug_menu_enabled
wagr_internal_master_enabled
wagr_debug_mode_enabled
wa_abprops_observer_enabled
wa_liquid_glass_enabled
wa_liquid_glass_userdefaults_overrides
wa_liquid_glass_method_hooks
wa_sideload_keychain_rewrite_enabled
wa_keychain_observer_enabled
```

Use:

```objc
static inline BOOL WAGRPref(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static inline void WAGRSetPref(NSString *key, BOOL value) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:value forKey:key];
    [ud synchronize];
}
```

### 2. WAAB override preferences

The functional v191 dylib uses:

```text
wagr.waab.<flag> = "on"   -> force YES
wagr.waab.<flag> = "off"  -> force NO
key absent                -> call original/framework
```

This must be preserved in the v191 reconstruction phase.

Use this helper format:

```objc
static inline NSString *WAGRKey(NSString *flag) {
    return flag.length ? [NSString stringWithFormat:@"wagr.waab.%@", flag] : @"";
}

static inline NSString *WAGRStoredFlagState(NSString *flag) {
    if (!flag.length) return nil;
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:WAGRKey(flag)];
    return [v isKindOfClass:NSString.class] ? (NSString *)v : nil;
}

static inline BOOL WAGRFlagForceOn(NSString *flag) {
    return [WAGRStoredFlagState(flag) isEqualToString:@"on"];
}

static inline BOOL WAGRFlagForceOff(NSString *flag) {
    return [WAGRStoredFlagState(flag) isEqualToString:@"off"];
}

static inline void WAGRSetFlagState(NSString *flag, NSString *state) {
    if (!flag.length) return;

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    if ([state isEqualToString:@"on"] || [state isEqualToString:@"off"]) {
        [ud setObject:state forKey:WAGRKey(flag)];
    } else {
        [ud removeObjectForKey:WAGRKey(flag)];
    }

    [ud synchronize];
}
```

Do not use:

```objc
@"true"
@"false"
@YES / @NO for WAAB overrides
.mode
.number
.string
setInteger:
WAGRWAABKeyMode
```

Those are not part of the functional v191 storage contract.

A future boolean migration is allowed only as a separate explicit migration phase, and only if all readers/writers are migrated together:

```text
WAGRABFlagBrowserVC
WAGRWAABTriStateBrowserVC
WAGRWAABCategoryBundleVC
WAGramWAABRuntimeCategoriesVC
WAGramBundleVC
WAABPropsObserver
WAGramBundleHooks
WAAuraHooks
WAGRNativeSurface
diagnostics
reset logic
counters
```

Do not do partial migration.

### 3. LiquidGlass native defaults

LiquidGlass also writes native WhatsApp defaults. These are separate from `wagr.waab.*`.

Keys:

```text
wa_lg_ios_liquid_glass_enabled
wa_lg_ios_liquid_glass_launched
wa_lg_ios_liquid_glass_m1
wa_lg_ios_liquid_glass_m_1_5
wa_lg_ios_liquid_glass_m_1_5_context_menu
wa_lg_ios_liquid_glass_chat_top_bar_m2_enabled
wa_lg_ios_liquid_glass_enable_new_chatbar_ux
wa_lg_ios_liquid_glass_larger_composer
wa_lg_ios_liquid_glass_reduce_transparency
wa_lg_ios_liquid_glass_workaround_attachment_tray
wa_lg_ios_liquid_glass_workaround_hides_bottombar
wa_lg_ios_liquid_glass_workaround_topbar_appearance
```

Format:

```objc
static void WAGRLGApplyNativeDefaults(void) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BOOL enabled = WAGRPref(kWAGRLiquidGlassMaster);

    for (NSString *key in WAGRLGNativeDefaultKeys()) {
        if (enabled) [ud setBool:YES forKey:key];
        else [ud removeObjectForKey:key];
    }

    [ud synchronize];
}
```

### 4. NativeSurface persistence

NativeSurface uses exact class+selector registry.

Observed contract strings:

```text
wagr.native.registry
wagr.native.%@.%@.%@
runtime-wide-scan=NO
browser scan=ON-DEMAND only
mode=exact class+selector registry
```

Do not replace this with a broad runtime-wide scan. The browser may discover methods on demand; startup must reinstall persisted exact entries only.

---

## Hook architecture by module

## 1. `src/Tweak.x` — menu entry + debug menu gate

Type: `MSHookMessageEx`.

Responsibilities:

- register master defaults;
- hook Settings `viewDidAppear:`;
- attach long press gesture on Help/Feedback/Developer cells;
- hook `isDebugMenuAllowed`;
- present `WAGramMenuVC`;
- retry Settings hook after `1.0s` and `3.0s`.

Candidate Settings classes:

```objc
@"WASettingsViewController"
@"WASettingsTableViewController"
@"WANewSettingsViewController"
@"WASettingsNavTableViewController"
```

Required pattern:

```objc
static BOOL (*orig_isDebugMenuAllowed)(id, SEL) = NULL;
static IMP orig_settingsVDAppear = NULL;

static BOOL hook_isDebugMenuAllowed(id self, SEL _cmd) {
    if (WAGRPref(kWAGRDebugMenuNative)) return YES;
    return orig_isDebugMenuAllowed ? orig_isDebugMenuAllowed(self, _cmd) : NO;
}

static void hook_settingsVDAppear(id self, SEL _cmd, BOOL animated) {
    if (orig_settingsVDAppear) {
        ((void (*)(id, SEL, BOOL))orig_settingsVDAppear)(self, _cmd, animated);
    }

    if (![self isKindOfClass:UIViewController.class]) return;

    UITableView *tv = WAGRFindTableView(((UIViewController *)self).view);
    WAGRAttachLongPress(tv);

    if (tv && WAGRPref(kWAGRDebugMenuNative)) {
        [tv reloadData];
    }
}

static void WAGRHookDebugGateOnClass(Class cls) {
    if (!cls) return;

    SEL sel = NSSelectorFromString(@"isDebugMenuAllowed");

    Method im = class_getInstanceMethod(cls, sel);
    if (im) {
        MSHookMessageEx(cls, sel, (IMP)hook_isDebugMenuAllowed, (IMP *)&orig_isDebugMenuAllowed);
        return;
    }

    Method cm = class_getClassMethod(cls, sel);
    if (cm) {
        MSHookMessageEx(object_getClass(cls), sel, (IMP)hook_isDebugMenuAllowed, (IMP *)&orig_isDebugMenuAllowed);
    }
}
```

Do not present UI from background queue. Always present on main queue.

---

## 2. `src/Hooks/WALiquidGlassHooks.xm` — LiquidGlass direct hooks

Type: Logos `%hook`.

This module is known, stable, and functional. Do not convert it into runtime browser code.

Classes:

```text
WDSLiquidGlass
WAABProperties
WALiquidGlassOverrideMethodUserDefaults
IGLiquidGlassExperimentHelper
```

Selectors to implement or preserve:

```text
+hasLiquidGlassLaunched
+isM0Enabled
+isM1Enabled
+isM1_5Enabled
+isM1_5ContextMenuEnabled
+isLargerComposerEnabled
+isNativeSidebarEnabled
+shouldUseNativeSwipeActions

-ios_liquid_glass_enabled
-ios_liquid_glass_launched
-ios_liquid_glass_m1
-ios_liquid_glass_m_1_5
-ios_liquid_glass_m_1_5_context_menu
-ios_liquid_glass_media_m0
-ios_liquid_glass_larger_composer
-ios_liquid_glass_media_editor_enabled
-ios_liquid_glass_calling_improvement_enabled
-ios_liquid_glass_workaround_attachment_tray
-ios_liquid_glass_reduce_transparency
-ios_liquid_glass_fixes_for_older_ios
-status_viewer_redesign_enabled
-isEnabled
+isEnabled
```

Code format:

```objc
static BOOL WAGRLGEnabled(void) {
    return WAGRPref(kWAGRLiquidGlassMaster);
}

static BOOL WAGRLGMethodHooksEnabled(void) {
    return WAGRPref(kWAGRLiquidGlassMethodHooks);
}

%hook WDSLiquidGlass

+ (BOOL)isM1Enabled {
    if (WAGRLGEnabled() && WAGRLGMethodHooksEnabled()) return YES;
    return %orig;
}

+ (BOOL)isM1_5Enabled {
    if (WAGRLGEnabled() && WAGRLGMethodHooksEnabled()) return YES;
    return %orig;
}

+ (BOOL)shouldUseNativeSwipeActions {
    if (WAGRLGEnabled() && WAGRLGMethodHooksEnabled()) return YES;
    return %orig;
}

%end

%hook WAABProperties

- (BOOL)ios_liquid_glass_enabled {
    if (WAGRLGEnabled()) return YES;
    return %orig;
}

- (BOOL)ios_liquid_glass_m1 {
    if (WAGRLGEnabled()) return YES;
    return %orig;
}

%end
```

Ctor format:

```objc
%ctor {
    @autoreleasepool {
        WAGRLGApplyNativeDefaults();

        %init(WDSLiquidGlass=objc_getClass("WDSLiquidGlass"),
              WAABProperties=objc_getClass("WAABProperties"),
              WALiquidGlassOverrideMethodUserDefaults=objc_getClass("WALiquidGlassOverrideMethodUserDefaults"),
              IGLiquidGlassExperimentHelper=objc_getClass("IGLiquidGlassExperimentHelper"));
    }
}
```

`WAGRLGPrefsDidChange()` must:

1. apply native defaults;
2. call the dynamic `WALiquidGlassOverrideMethodUserDefaults.sharedInstance setEnabled:`;
3. avoid crashing if the class/selector is absent.

Use `objc_msgSend` or `NSInvocation` carefully; never hard-link unavailable private headers.

---

## 3. `src/Hooks/WAABPropsObserver.xm` — central WAAB gateway

Type: dynamic `MSHookMessageEx`.

Responsibilities:

- hook `WAABProperties`;
- hook `FOAWAABPropertiesImpl`;
- hook any class containing `WAABProperties` or `ABProperties`;
- hook BOOL zero-argument getters;
- hook `boolForKey:defaultValue:`;
- hook `stringForKey:defaultValue:`;
- keep a ring buffer observer log;
- export diagnostics.

Do not use Logos here; selectors are dynamic and numerous.

Required hook logic:

```objc
typedef BOOL (*WAGRBoolGetterIMP)(id, SEL);
static NSMutableDictionary<NSString *, NSValue *> *gWAABOrigBool;

static BOOL WAGRWAABGenericBoolHook(id self, SEL _cmd) {
    NSString *flag = NSStringFromSelector(_cmd);

    if (WAGRFlagForceOn(flag)) return YES;
    if (WAGRFlagForceOff(flag)) return NO;

    WAGRBoolGetterIMP orig = NULL;
    NSValue *v = gWAABOrigBool[flag];
    if (v) orig = (WAGRBoolGetterIMP)[v pointerValue];

    return orig ? orig(self, _cmd) : NO;
}
```

`boolForKey:defaultValue:` hook:

```objc
typedef BOOL (*WAGRBoolForKeyIMP)(id, SEL, NSString *, BOOL);
static WAGRBoolForKeyIMP gOrigBoolForKey = NULL;

static BOOL WAGRBoolForKeyHook(id self, SEL _cmd, NSString *key, BOOL defaultValue) {
    BOOL original = gOrigBoolForKey ? gOrigBoolForKey(self, _cmd, key, defaultValue) : defaultValue;

    if (WAGRFlagForceOn(key)) return YES;
    if (WAGRFlagForceOff(key)) return NO;

    return original;
}
```

`stringForKey:defaultValue:` hook:

```objc
typedef id (*WAGRStringForKeyIMP)(id, SEL, NSString *, id);
static WAGRStringForKeyIMP gOrigStringForKey = NULL;

static id WAGRStringForKeyHook(id self, SEL _cmd, NSString *key, id defaultValue) {
    id original = gOrigStringForKey ? gOrigStringForKey(self, _cmd, key, defaultValue) : defaultValue;

    if (WAGRFlagForceOn(key)) return @"enabled";
    if (WAGRFlagForceOff(key)) return @"";

    return original;
}
```

Method validator:

```objc
static BOOL WAGRMethodIsBoolNoArg(Method m) {
    if (!m) return NO;
    if (method_getNumberOfArguments(m) != 2) return NO;

    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));

    return ret[0] == 'B' || ret[0] == 'c';
}
```

Hook one class:

```objc
static void WAGRHookWAABPropertiesClass(Class cls) {
    if (!cls) return;

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    if (!methods) return;

    for (unsigned int i = 0; i < count; i++) {
        Method m = methods[i];
        SEL sel = method_getName(m);
        NSString *name = NSStringFromSelector(sel);

        if ([name isEqualToString:@"boolForKey:defaultValue:"]) {
            if (!gOrigBoolForKey) {
                MSHookMessageEx(cls, sel, (IMP)WAGRBoolForKeyHook, (IMP *)&gOrigBoolForKey);
            }
            continue;
        }

        if ([name isEqualToString:@"stringForKey:defaultValue:"]) {
            if (!gOrigStringForKey) {
                MSHookMessageEx(cls, sel, (IMP)WAGRStringForKeyHook, (IMP *)&gOrigStringForKey);
            }
            continue;
        }

        if (!WAGRMethodIsBoolNoArg(m)) continue;

        if (gWAABOrigBool[name]) continue;

        IMP orig = NULL;
        MSHookMessageEx(cls, sel, (IMP)WAGRWAABGenericBoolHook, &orig);
        if (orig) {
            gWAABOrigBool[name] = [NSValue valueWithPointer:(void *)orig];
        }
    }

    free(methods);
}
```

Installer:

```objc
extern "C" void WAGRWAABEnsureHooksInstalled(void) {
    if (gWAABHooksInstalled) return;

    NSUInteger before = gWAABOrigBool.count;

    WAGRHookWAABPropertiesClass(NSClassFromString(@"WAABProperties"));
    WAGRHookWAABPropertiesClass(NSClassFromString(@"FOAWAABPropertiesImpl"));

    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);

    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if ([name containsString:@"WAABProperties"] ||
            [name containsString:@"ABProperties"] ||
            [name isEqualToString:@"FOAWAABPropertiesImpl"]) {
            WAGRHookWAABPropertiesClass(classes[i]);
        }
    }

    if (classes) free(classes);

    gWAABHooksInstalled = (gWAABOrigBool.count > 0 || gOrigBoolForKey || gOrigStringForKey);

    NSLog(@"[WAGram][WAAB] installed=%@ hooked=%lu delta=%lu",
          gWAABHooksInstalled ? @"YES" : @"NO",
          (unsigned long)gWAABOrigBool.count,
          (unsigned long)(gWAABOrigBool.count - before));
}
```

Ctor:

```objc
__attribute__((constructor))
static void WAGRWAABCtor(void) {
    @autoreleasepool {
        if (!WAGRPref(kWAGRABPropsObserver) && !WAGRHasAnyWAABOverride()) {
            // functional dylib still schedules WAAB; keep behavior unless optimizing later
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRWAABEnsureHooksInstalled();
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRWAABEnsureHooksInstalled();
        });
    }
}
```

When optimizing, do not remove this until functional equivalence is proven.

---

## 4. `src/Hooks/WAGramBundleHooks.xm` — fixed WAAB selector list

Type: dynamic `MSHookMessageEx`, exact flag list.

This module is essential. Many categorized menu flags do not work if only the UI writes preferences. This module directly hooks the fixed selectors used by the menu.

Export:

```objc
extern "C" void WAGRBundleEnsureHooksInstalled(void);
```

Pattern:

```objc
typedef BOOL (*WAGRBundleBoolIMP)(id, SEL);
static NSMutableDictionary<NSString *, NSValue *> *gBundleOrig;

static BOOL WAGRBundleBoolHook(id self, SEL _cmd) {
    NSString *flag = NSStringFromSelector(_cmd);

    if (WAGRFlagForceOn(flag)) return YES;
    if (WAGRFlagForceOff(flag)) return NO;

    WAGRBundleBoolIMP orig = NULL;
    NSValue *v = gBundleOrig[flag];
    if (v) orig = (WAGRBundleBoolIMP)[v pointerValue];

    return orig ? orig(self, _cmd) : NO;
}

static void WAGRHookOneWAABBundleFlag(Class cls, const char *name) {
    if (!cls || !name) return;

    SEL sel = sel_registerName(name);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    if (method_getNumberOfArguments(m) != 2) return;

    char ret[8] = {0};
    method_getReturnType(m, ret, sizeof(ret));
    if (ret[0] != 'B' && ret[0] != 'c') return;

    NSString *key = NSStringFromSelector(sel);
    if (gBundleOrig[key]) return;

    IMP orig = NULL;
    MSHookMessageEx(cls, sel, (IMP)WAGRBundleBoolHook, &orig);

    if (orig) {
        gBundleOrig[key] = [NSValue valueWithPointer:(void *)orig];
    }
}
```

Installer skeleton:

```objc
extern "C" void WAGRBundleEnsureHooksInstalled(void) {
    if (gBundleInstalled) return;

    if (!gBundleOrig) gBundleOrig = [NSMutableDictionary dictionary];

    Class cls = NSClassFromString(@"WAABProperties");
    if (!cls) return;

    const char *flags[] = {
        "aura_enabled",
        "aura_settings_row_enabled",
        "ai_subscription_enabled",
        "isEligibleForSubscriptions",
        "wa_subscriptions_entry_point_settings_enabled",
        "wa_subscriptions_settings_green_dot_enabled",
        "ios_liquid_glass_enabled",
        "ios_liquid_glass_m1",
        "ios_liquid_glass_m_1_5",
        "lists_feature_enabled",
        "call_favorites_enabled_companions",
        "events_global_list",
        "waffle_mobile_companions_enabled",
        "sg_ios_multi_account_enabled",
        "wa_interop_unified_inbox_enabled",
        // keep adding fixed known selectors from extraction/categories
    };

    for (size_t i = 0; i < sizeof(flags)/sizeof(flags[0]); i++) {
        WAGRHookOneWAABBundleFlag(cls, flags[i]);
    }

    gBundleInstalled = gBundleOrig.count > 0;

    NSLog(@"[WAGram][BundleHooks] installed %lu direct WAAB bundle hooks",
          (unsigned long)gBundleOrig.count);
}
```

Ctor:

```objc
__attribute__((constructor))
static void WAGRBundleCtor(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WAGRBundleEnsureHooksInstalled();
    });
}
```

---

## 5. `src/Hooks/WAGRNativeSurface.xm` — exact native class+selector registry

Type: `MSHookMessageEx`, exact registry only.

Never do runtime-wide scan at startup.

Required strings/diagnostics:

```text
runtime-wide-scan=NO
browser scan=ON-DEMAND only
mode=exact class+selector registry
```

Data model:

```objc
@interface WAGRNativeEntry : NSObject
@property(nonatomic, copy) NSString *className;
@property(nonatomic, copy) NSString *selectorName;
@property(nonatomic, assign) BOOL classMethod;
@end
```

Storage:

```text
wagr.native.registry
wagr.native.<class>.<selector>.<kind>
```

Public API:

```objc
extern "C" NSNumber *WAGRNativeBoolOverrideGet(NSString *className, NSString *selectorName, BOOL classMethod);
extern "C" void WAGRNativeBoolOverrideSet(NSString *className, NSString *selectorName, BOOL classMethod, NSNumber *valueOrNil);
extern "C" void WAGRNativeBoolOverrideInstallPersisted(void);
extern "C" void WAGRNativeSurfaceEnsureHooksInstalled(void);
extern "C" NSString *WAGRNativeSurfaceDiagnosticText(void);
```

Hook pattern:

```objc
typedef BOOL (*WAGRNativeBoolIMP)(id, SEL);

static BOOL WAGRNativeBoolHook(id self, SEL _cmd) {
    NSString *className = NSStringFromClass([self class]);
    NSString *selectorName = NSStringFromSelector(_cmd);

    NSNumber *forced = WAGRNativeBoolOverrideGet(className, selectorName, NO);
    if (forced) return forced.boolValue;

    WAGRNativeBoolIMP orig = WAGRNativeOrigFor(className, selectorName, NO);
    return orig ? orig(self, _cmd) : NO;
}
```

Install persisted:

```objc
extern "C" void WAGRNativeBoolOverrideInstallPersisted(void) {
    NSArray *registry = [[NSUserDefaults standardUserDefaults] objectForKey:@"wagr.native.registry"];
    if (![registry isKindOfClass:NSArray.class]) return;

    for (NSDictionary *entry in registry) {
        NSString *clsName = entry[@"class"];
        NSString *selName = entry[@"selector"];
        BOOL meta = [entry[@"classMethod"] boolValue];

        Class cls = NSClassFromString(clsName);
        SEL sel = NSSelectorFromString(selName);

        if (!cls || !sel) continue;

        Method m = meta ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
        if (!m) continue;

        Class target = meta ? object_getClass(cls) : cls;
        MSHookMessageEx(target, sel, (IMP)WAGRNativeBoolHook, &orig);
    }
}
```

Ctor:

```objc
__attribute__((constructor))
static void WAGRNativeSurfaceCtor(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WAGRNativeBoolOverrideInstallPersisted();
    });
}
```

---

## 6. `src/Hooks/WAEmployeeDogfoodHooks.xm` — employee/dogfood gates

Type: dynamic `MSHookMessageEx`.

Selectors:

```text
isMetaEmployeeOrInternalTester
is_meta_employee_or_internal_tester
isInternalUser
graphQLEmployeeC1Disabled
```

Target classes:

```text
WAABProperties
WAUserContext
WAAccountInfo
WAAccountManager
WADeviceInfo
WAUserPreferences
WAEmployeeGating
WADebugMenuMain
WADebugViewController
WASettingsViewController
```

Fallback class fragments:

```text
WA
Debug
Employee
Dogfood
ABProperties
```

Rules:

- First three selectors return `YES` when master/gate is active.
- `graphQLEmployeeC1Disabled` returns `NO` when master/gate is active.
- Try instance methods and class methods.
- Retry at `0.2s`, `1.0s`, `3.0s`, `6.0s`.
- Do not permanently block retries if classes are not loaded yet.

Code pattern:

```objc
static BOOL WAGRDogfoodMasterEnabled(void) {
    return WAGRPref(kWAGREmployeeMaster) ||
           WAGRPref(kWAGRInternalMaster) ||
           WAGRPref(kWAGRDebugMode);
}

static BOOL WAGRDogfoodGateEnabled(NSString *gateKey) {
    return WAGRDogfoodMasterEnabled() || WAGRPref(gateKey);
}

static BOOL hook_isInternalUser(id self, SEL _cmd) {
    if (WAGRDogfoodGateEnabled(kWAGRDogfoodGateInternalUser)) return YES;
    return orig_isInternalUser ? orig_isInternalUser(self, _cmd) : NO;
}

static BOOL hook_graphQLEmployeeC1Disabled(id self, SEL _cmd) {
    if (WAGRDogfoodGateEnabled(kWAGRDogfoodGateGraphQLEmpC1)) return NO;
    return orig_graphQLEmployeeC1Disabled ? orig_graphQLEmployeeC1Disabled(self, _cmd) : YES;
}
```

Installer pattern:

```objc
static void WAGRDFHookOne(Class cls, BOOL meta, const char *selName, IMP hook, IMP *orig) {
    if (!cls || !selName || !hook || !orig || *orig) return;

    SEL sel = sel_registerName(selName);
    Method m = meta ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (!m) return;

    Class target = meta ? object_getClass(cls) : cls;
    MSHookMessageEx(target, sel, hook, orig);

    if (*orig) {
        gWAGRDogfoodHooked++;
        NSLog(@"[WAGram][Dogfood] hooked %@[%@ %s]",
              meta ? @"+" : @"-", NSStringFromClass(cls), selName);
    }
}
```

Ctor:

```objc
__attribute__((constructor))
static void WAGRDogfoodCtor(void) {
    double delays[] = {0.2, 1.0, 3.0, 6.0};

    for (int i = 0; i < 4; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delays[i] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WAGRDogfoodEnsureHooksInstalled();
        });
    }

    NSLog(@"[WAGram][Dogfood] scheduled persistent hook install passes");
}
```

---

## 7. `src/Hooks/WAAuraHooks.xm` — WA Plus/Aura

Type: mixed.

Responsibilities:

- activate/deactivate all Aura WAAB flags;
- hook/push native subscription/settings VCs where available;
- install Aura gating before enabling dependent flags.

Exports to preserve:

```text
WAGRAuraEnsureHooksInstalled
WAGRAuraActivateAllFlags
WAGRAuraDeactivateAllFlags
WAGRAuraDiagnostic
WAGROpenSubscriptionsNative
WAGRPushAuraThemesVC
WAGRPushAuraIconsVC
WAGRPushAuraRingtonesVC
```

Known Aura/Subscription flags:

```text
aura_enabled
aura_settings_row_enabled
aura_subscription_simulation_enabled
aura_logging_enabled
aura_app_icon_enabled
aura_app_icon_benefit_active
aura_app_themes_enabled
aura_app_themes_benefit_active
aura_app_themes_chat_checkmark_themed_enabled
aura_app_themes_new_selection_flow_enabled
aura_pinned_chats_enabled
aura_pinned_chats_benefit_active
aura_enhanced_lists_enabled
aura_enhanced_lists_benefit_active
aura_ringtones_enabled
aura_ringtones_benefit_active
aura_stickers_enabled
aura_stickers_benefit_active
aura_stickers_overlay_animation_enabled
aura_apple_watch_app_theme_enabled
ai_subscription_enabled
ai_subscription_imagine_intent_enabled
isStickersBenefitActive
isEligibleForSubscriptions
isExpandedFormattingPlusEnabled
wa_subscriptions_entry_point_settings_enabled
wa_subscriptions_settings_green_dot_enabled
```

Negative/kill flags:

```text
aura_kill_switch
aura_premium_stickers_killswitch
```

Native row selectors:

```text
checkSubscriptionsEligibilityAndInsertRowIfNeeded
isSubscriptionsRowPresentInTable
insertSubscriptionsRow
openSettingsAndSubscriptionManagementWithUserInfo:
```

Activation pattern:

```objc
extern "C" void WAGRAuraActivateAllFlags(void) {
    WAGRAuraEnsureHooksInstalled();

    for (NSString *flag in WAGRAuraPositiveFlags()) {
        WAGRSetFlagState(flag, @"on");
    }

    for (NSString *flag in WAGRAuraNegativeFlags()) {
        WAGRSetFlagState(flag, @"off");
    }

    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}
```

Deactivation pattern:

```objc
extern "C" void WAGRAuraDeactivateAllFlags(void) {
    for (NSString *flag in WAGRAuraPositiveFlags()) {
        WAGRSetFlagState(flag, nil);
    }

    for (NSString *flag in WAGRAuraNegativeFlags()) {
        WAGRSetFlagState(flag, nil);
    }

    WAGRWAABEnsureHooksInstalled();
}
```

Row insertion hook sketch:

```objc
static void hook_checkSubscriptionsEligibilityAndInsertRowIfNeeded(id self, SEL _cmd) {
    if (orig_checkSubscriptionsEligibility) orig_checkSubscriptionsEligibility(self, _cmd);

    if (WAGRFlagForceOn(@"aura_settings_row_enabled")) {
        SEL ins = NSSelectorFromString(@"insertSubscriptionsRow");
        if ([self respondsToSelector:ins]) {
            ((void (*)(id, SEL))objc_msgSend)(self, ins);
        }
    }
}

static BOOL hook_isSubscriptionsRowPresentInTable(id self, SEL _cmd) {
    if (WAGRFlagForceOn(@"aura_settings_row_enabled")) return NO;
    return orig_isSubscriptionsRowPresent ? orig_isSubscriptionsRowPresent(self, _cmd) : NO;
}
```

---

## 8. `src/WAKeychainPatch.xm` — keychain patch

Type: fishhook / `rebind_symbols`.

Functions:

```text
SecItemAdd
SecItemCopyMatching
SecItemUpdate
SecItemDelete
```

Preferences:

```text
wa_sideload_keychain_rewrite_enabled
wa_keychain_observer_enabled
wa_keychain_access_group_detected
```

Rules:

- If rewrite and observer are both OFF, return inert.
- Detect access group through a guarded probe.
- Use atomic guard to avoid recursive keychain calls.
- Never permanently write arbitrary keychain payloads.
- Observer logs metadata only.

Code format:

```objc
static OSStatus (*orig_SecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result) = NULL;
static OSStatus (*orig_SecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result) = NULL;
static OSStatus (*orig_SecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) = NULL;
static OSStatus (*orig_SecItemDelete)(CFDictionaryRef query) = NULL;

extern "C" void WAInstallKeychainPatchIfNeeded(void) {
    if (!WAKeychainRewriteEnabled() && !WAKeychainObserverEnabled()) {
        WALog(@"keychain hooks disabled; inert");
        return;
    }

    bool expected = false;
    if (!atomic_compare_exchange_strong(&gWAKeychainHooksInstalled, &expected, true)) return;

    WADetectAccessGroup();

    struct rebinding binds[] = {
        {"SecItemAdd", (void *)replaced_SecItemAdd, (void **)&orig_SecItemAdd},
        {"SecItemCopyMatching", (void *)replaced_SecItemCopyMatching, (void **)&orig_SecItemCopyMatching},
        {"SecItemUpdate", (void *)replaced_SecItemUpdate, (void **)&orig_SecItemUpdate},
        {"SecItemDelete", (void *)replaced_SecItemDelete, (void **)&orig_SecItemDelete},
    };

    rebind_symbols(binds, sizeof(binds) / sizeof(binds[0]));
}
```

---

## UI architecture to preserve

Functional dylib UI classes and method names extracted from ObjC metadata:

### `WAGRABFlagBrowserVC`

Methods:

```text
+ runtimeFlags
- initWithTitle:flags:
- viewDidLoad
- updateBadge
- reload
- updateSearchResultsForSearchController:
- tableView:numberOfRowsInSection:
- tableView:heightForRowAtIndexPath:
- tableView:cellForRowAtIndexPath:
- tog:
```

Use for simple flag browser.

Expected behavior:

```text
Switch ON  -> set "on" for WAGRKey(flag)
Switch OFF -> either set "off" or remove depending current browser mode
```

For v191, preserve exactly how the browser uses `on/off/system`.

### `WAGRWAABTriStateBrowserVC`

Methods:

```text
- initWithTitle:flags:negativeMode:
- viewDidLoad
- updateTitle
- updateSearchResultsForSearchController:
- tableView:numberOfRowsInSection:
- tableView:heightForRowAtIndexPath:
- tableView:cellForRowAtIndexPath:
- segChanged:
```

Use for tri-state:

```text
Sys | OFF | ON
```

Mapping:

```objc
if (seg.selectedSegmentIndex == 2) WAGRSetFlagState(flag, @"on");
else if (seg.selectedSegmentIndex == 1) WAGRSetFlagState(flag, @"off");
else WAGRSetFlagState(flag, nil);
```

### `WAGRWAABCategoryBundleVC`

Methods:

```text
- initWithSpec:flags:
- viewDidLoad
- numberOfSectionsInTableView:
- tableView:numberOfRowsInSection:
- tableView:titleForFooterInSection:
- activeCount
- setAll:
- tableView:cellForRowAtIndexPath:
- master:
- tableView:didSelectRowAtIndexPath:
```

Use for categorized bundles. `setAll:` must call WAAB installers after writing prefs.

### `WAGramWAABRuntimeCategoriesVC`

Methods:

```text
+ categorySpecs
- init
- viewDidLoad
- refresh
- rebuild
- tableView:cellForRowAtIndexPath:
- tableView:didSelectRowAtIndexPath:
```

Use for runtime category overview.

### `WAGRRuntimeMethodBrowserVC`

Methods:

```text
+ methodNameLooksFeatureLike:
+ runtimeMethodsMatchingTokens:
- initWithTitle:tokens:
- viewDidLoad
- reinstall
- updateSearchResultsForSearchController:
- tableView:numberOfRowsInSection:
- tableView:heightForRowAtIndexPath:
- tableView:cellForRowAtIndexPath:
- segChanged:
```

Rules:

- Scan on demand only.
- Do not scan all classes at launch.
- Persist exact NativeSurface hooks.
- Reinstall persisted hooks via `WAGRNativeBoolOverrideInstallPersisted`.
- UI can be redesigned later, but keep class/export contract.

---

## UI modernization rules

Allowed:

- improve colors, grouping, icons, typography;
- add reset buttons;
- add diagnostics buttons;
- add search;
- add clearer labels;
- add category descriptions.

Not allowed during reconstruction:

- rename exported UI classes;
- replace `WAGRABFlagBrowserVC` logic with unrelated v8 row model;
- change `on/off/system` contract;
- remove `WAGRWAABTriStateBrowserVC`;
- move Runtime Browser to startup scanning;
- make toggles purely visual;
- write different keys from what hooks read.

Every category must call the same helpers:

```objc
WAGRKey(flag)
WAGRSetFlagState(flag, @"on"/@"off"/nil)
WAGRWAABEnsureHooksInstalled()
WAGRBundleEnsureHooksInstalled()
```

For Aura:

```objc
WAGRAuraEnsureHooksInstalled()
```

For Dogfood:

```objc
WAGRDogfoodEnsureHooksInstalled()
```

For LiquidGlass:

```objc
WAGRLGPrefsDidChange()
```

---

## Reset requirements

Every categorized menu must have a reset action.

Category reset:

```objc
static void WAGRResetFlags(NSArray<NSString *> *flags) {
    for (NSString *flag in flags) {
        WAGRSetFlagState(flag, nil);
    }

    [[NSUserDefaults standardUserDefaults] synchronize];

    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}
```

Aura reset must also reset negative flags.

Runtime browser reset:

```text
Reset visible
Reset all discovered native entries
```

WAAB browser reset:

```text
Reset visible filtered flags
Reset all wagr.waab.* flags
```

Global reset should be in Debug/System only, not per-category.

---

## Build/validation checklist

Before commit:

```sh
git diff --check
```

No placeholders:

```sh
grep -R "PLACEHOLDER" -n src && exit 1 || true
```

No v8-only broken row model names unless aliases are intentionally defined:

```sh
grep -R "WAGramSectionDef" -n src && exit 1 || true
grep -R "WAGramRowStyle" -n src && exit 1 || true
```

Verify functional exports exist in source:

```sh
grep -R "WAGRWAABEnsureHooksInstalled" -n src
grep -R "WAGRBundleEnsureHooksInstalled" -n src
grep -R "WAGRNativeSurfaceEnsureHooksInstalled" -n src
grep -R "WAGRDogfoodEnsureHooksInstalled" -n src
grep -R "WAGRLGPrefsDidChange" -n src
grep -R "WAInstallKeychainPatchIfNeeded" -n src
```

Verify storage helpers:

```sh
grep -R "wagr.waab.%@" -n src
grep -R 'isEqualToString:@"on"' -n src
grep -R 'isEqualToString:@"off"' -n src
```

Verify no accidental `.mode` migration:

```sh
grep -R "\.mode" -n src && exit 1 || true
grep -R "setInteger:.*WAGRWAAB" -n src && exit 1 || true
```

Verify no C++ extern in `.m`:

```sh
grep -R 'extern "C"' -n src/*.m src/Menu/*.m && exit 1 || true
```

Expected logs to preserve:

```text
[WAGram][BundleHooks] installed %lu direct WAAB bundle hooks
[WAGram][NativeSurface] exact hooks=%lu persisted=%lu runtime-wide-scan=NO
[WAGram][Dogfood] scheduled persistent hook install passes
[WAGram][Dogfood] hook installation complete; hooked=%lu
[WAGram][WAAB] hooked %lu direct bool methods on WAABProperties
```

Expected classes after build:

```text
WAGRABFlagBrowserVC
WAGRWAABTriStateBrowserVC
WAGRWAABCategoryBundleVC
WAGramWAABRuntimeCategoriesVC
WAGRRuntimeMethodBrowserVC
WAGramBundleVC
WAGramMenuVC
```

---

## Required reconstruction order

1. `src/WAGramPrefix.h`
2. `src/WAUtils.h/.m`
3. `src/Tweak.x`
4. `src/Hooks/WALiquidGlassHooks.xm`
5. `src/Hooks/WAABPropsObserver.xm`
6. `src/Hooks/WAGramBundleHooks.xm`
7. `src/Hooks/WAGRNativeSurface.xm`
8. `src/Hooks/WAEmployeeDogfoodHooks.xm`
9. `src/Hooks/WAAuraHooks.xm`
10. `src/WAKeychainPatch.xm`
11. `src/Menu/WAGRABFlagBrowserVC.*`
12. `src/Menu/WAGRWAABTriStateBrowserVC.*`
13. `src/Menu/WAGRWAABCategoryBundleVC.*`
14. `src/Menu/WAGramWAABRuntimeCategoriesVC.*`
15. `src/Menu/WAGRRuntimeMethodBrowserVC.*`
16. `src/Menu/WAGramMenuVC.*`
17. UI beautification only after functional parity.

Do not beautify before functional parity.

---

## Parity target

A build is considered a valid v191 reconstruction only when it has:

- the same important exported functions;
- the same important ObjC UI class names;
- working LiquidGlass;
- working Developer/Debug menu;
- working WAAB browser and categorized bundles;
- working Dogfood/Employee selectors;
- working NativeSurface exact registry;
- optional/inert Keychain patch behavior;
- no launch-time runtime-wide scan from NativeSurface;
- WAAB storage using `wagr.waab.<flag> = "on"/"off"/absent`;
- long press Settings/Help/Developer opens WAGram.

After parity, new UI may be layered on top without altering the hook contract.
