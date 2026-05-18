# AGENTS.md — LiquidGlassOn / WAGram Compile-Safe Engineering Guide

This file explains **how to implement code in this repository without breaking the v191 hook architecture or causing recurring Theos/ObjC build errors**.

It is not a Git/branch-management document. Do not reset branches, force-push, discard work, rewrite history, or choose a base branch because of this file. Work on the branch/state the user provides.

UI may be improved at any time. The only requirement is that UI continues to write the exact preferences that hooks read, and that every visible toggle maps to a real hook path.

---

## 1. Critical compile rules

### 1.1 `.x` and `.m` are Objective-C, not Objective-C++

`src/Tweak.x` is preprocessed by Theos into Objective-C `.m`. Treat it like `.m`.

Never write this in `.x` or `.m`:

```objc
extern "C" void Foo(void);
extern "C" NSString *FooDiagnostic(void);
```

That causes:

```text
error: expected identifier or '('
```

Correct for `.x` / `.m`:

```objc
extern void Foo(void);
extern NSString *FooDiagnostic(void);
```

Correct for `.xm` / `.mm`:

```objc
extern "C" void Foo(void);
extern "C" NSString *FooDiagnostic(void);
```

Correct for shared headers imported by both `.m/.x` and `.xm/.mm`:

```objc
#ifdef __cplusplus
extern "C" {
#endif

void Foo(void);
NSString *FooDiagnostic(void);

#ifdef __cplusplus
}
#endif
```

Preferred pattern: put cross-file declarations in a header with the `#ifdef __cplusplus` guard, then import the header from `.x`, `.m`, and `.xm`. Do not scatter raw `extern "C"` declarations in `Tweak.x`.

---

### 1.2 Every imported header must exist

If a file imports:

```objc
#import "WAGRRuntimeMethodBrowserVC.h"
```

then this exact file must exist in the same include path, usually:

```text
src/Menu/WAGRRuntimeMethodBrowserVC.h
```

If the implementation exists but no header exists, create a minimal header.

Example:

```objc
#pragma once
#import <UIKit/UIKit.h>

@interface WAGRRuntimeMethodBrowserVC : UITableViewController
+ (BOOL)methodNameLooksFeatureLike:(NSString *)name;
+ (NSArray *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
@end
```

Do not import non-existent headers. Do not assume Objective-C can see a class just because the `.m` exists.

Before commit, run:

```sh
python3 - <<'PY'
from pathlib import Path
import re, sys

errors = []
for p in list(Path("src").rglob("*.m")) + list(Path("src").rglob("*.x")) + list(Path("src").rglob("*.xm")):
    s = p.read_text(errors="ignore")
    for inc in re.findall(r'#import\s+"([^"]+)"', s):
        candidates = [
            p.parent / inc,
            Path("src") / inc,
            Path(inc),
        ]
        if not any(c.exists() for c in candidates):
            errors.append(f"{p}: missing import {inc}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY
```

---

### 1.3 Source extension rules

Use the right extension for the code style.

```text
.m   = Objective-C only. No Logos syntax. No extern "C".
.x   = Logos/Objective-C, generated as Objective-C. No extern "C".
.xm  = Logos/Objective-C++, OK for extern "C".
.mm  = Objective-C++, OK for extern "C".
.c   = C only.
```

If a file needs C++ linkage syntax, make it `.xm/.mm` or move declarations to a guarded header.

---

## 2. Functional hook architecture

The working v191 dylib behavior is the technical reference for hook style and persistence.

Functional binary identity:

```text
LiquidGlassOn.dylib
Mach-O arm64 dylib
size: 214,912 bytes
sha256: 692171b6c462ae36a4464de4a34d0c2c3265dc662c618680a821a22096bc4587
```

Architecture:

```text
LiquidGlass               = Logos hooks + native defaults
WAAB generic              = dynamic MSHookMessageEx gateway
WAAB bundle categories    = dynamic MSHookMessageEx over fixed selector list
NativeSurface             = exact class+selector registry; no runtime-wide startup scan
Employee/Dogfood          = dynamic MSHookMessageEx on ObjC selectors with retries
Developer menu            = dynamic MSHookMessageEx on Settings/debug selectors
Keychain                  = fishhook/rebind_symbols for SecItem* functions, optional/inert when disabled
UI browsers               = Objective-C UITableViewControllers that write prefs and call installers
```

A toggle is valid only if a hook actually reads the same preference key.

---

## 3. Export declarations

Centralize exported function declarations in a header such as `WAGramExports.h` or `WAGramPrefix.h`.

Correct header format:

```objc
#pragma once
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void WAGRWAABEnsureHooksInstalled(void);
NSString *WAGRWAABDiagnosticText(void);

void WAGRBundleEnsureHooksInstalled(void);

void WAGRNativeSurfaceEnsureHooksInstalled(void);
void WAGRNativeBoolOverrideInstallPersisted(void);
NSString *WAGRNativeSurfaceDiagnosticText(void);

void WAGRDogfoodEnsureHooksInstalled(void);
NSString *WAGRDogfoodDiagnosticText(void);

void WAGRDebugMenuEnsureHooksInstalled(void);
NSString *WAGRDebugMenuDiagnosticText(void);

void WAGRLGPrefsDidChange(void);
NSString *WAGRLGDiagnosticText(void);

void WAGRAuraEnsureHooksInstalled(void);
void WAGRAuraActivateAllFlags(void);
void WAGRAuraDeactivateAllFlags(void);
NSString *WAGRAuraDiagnostic(void);

void WAInstallKeychainPatchIfNeeded(void);
NSString *WAKeychainAccessGroupDiagnostic(void);

#ifdef __cplusplus
}
#endif
```

Then, in `.x` / `.m`:

```objc
#import "WAGramExports.h"
```

Do not write raw `extern "C"` lines in `Tweak.x`.

---

## 4. Persistence model

### 4.1 Master preferences

Master preferences are boolean `NSUserDefaults` keys:

```text
wa_employee_master
wa_abprops_observer_enabled
wa_liquid_glass_enabled
wa_liquid_glass_userdefaults_overrides
wa_liquid_glass_method_hooks
wa_sideload_keychain_rewrite_enabled
wa_keychain_observer_enabled
wagr_native_debug_menu_enabled
wagr_internal_master_enabled
wagr_debug_mode_enabled
```

Helper:

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

### 4.2 WAAB feature override preferences

The v191 functional WAAB contract uses:

```text
wagr.waab.<flag> = "on"   -> force YES
wagr.waab.<flag> = "off"  -> force NO
absent                    -> call original/framework
```

Shared helper:

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

Do not use `.mode`, `setInteger:`, `WAGRWAABKeyMode`, or partial boolean migrations for WAAB overrides unless every reader/writer is migrated in the same patch.

### 4.3 LiquidGlass native defaults

LiquidGlass also writes native WhatsApp defaults:

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

Pattern:

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

---

## 5. Hook style matrix

| Area | Hook type | Notes |
|---|---|---|
| LiquidGlass known classes/selectors | Logos `%hook` | Stable classes/selectors |
| WAABProperties zero-arg getters | `MSHookMessageEx` | Dynamic and numerous |
| `boolForKey:defaultValue:` | `MSHookMessageEx` | String-keyed config path |
| `stringForKey:defaultValue:` | `MSHookMessageEx` | String-keyed config path |
| WAAB fixed bundle flags | `MSHookMessageEx` over fixed selector list | Required for category menus |
| NativeSurface exact class+selector | `MSHookMessageEx` registry | No runtime-wide startup scan |
| Dogfood/Employee | `MSHookMessageEx` | Owner classes vary |
| Developer menu | `MSHookMessageEx` | Settings/debug selectors vary |
| Keychain | fishhook `rebind_symbols` | C functions |
| UI browsers | Objective-C `UITableViewController` | Write prefs and call installers |

---

## 6. Tweak.x

`Tweak.x` must be compile-safe as Objective-C.

Allowed:

```objc
extern void WAGRDebugBuildEnsureHooksInstalled(void);
extern NSString *WAGRDebugBuildDiagnostic(void);
```

Forbidden:

```objc
extern "C" void WAGRDebugBuildEnsureHooksInstalled(void);
extern "C" NSString *WAGRDebugBuildDiagnostic(void);
```

Responsibilities:

- register defaults;
- hook Settings `viewDidAppear:`;
- attach long press gesture;
- hook `isDebugMenuAllowed`;
- present `WAGramMenuVC`;
- retry Settings/debug hook installation after finite delays.

Candidate Settings classes:

```objc
@"WASettingsViewController"
@"WASettingsTableViewController"
@"WANewSettingsViewController"
@"WASettingsNavTableViewController"
```

Pattern:

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
}
```

---

## 7. LiquidGlass hooks

File: `src/Hooks/WALiquidGlassHooks.xm`  
Type: Logos `%hook`.

Classes:

```text
WDSLiquidGlass
WAABProperties
WALiquidGlassOverrideMethodUserDefaults
IGLiquidGlassExperimentHelper
```

Pattern:

```objc
%hook WDSLiquidGlass

+ (BOOL)isM1Enabled {
    if (WAGRPref(kWAGRLiquidGlassMaster)) return YES;
    return %orig;
}

%end

%hook WAABProperties

- (BOOL)ios_liquid_glass_enabled {
    if (WAGRPref(kWAGRLiquidGlassMaster)) return YES;
    return %orig;
}

%end
```

`WAGRLGPrefsDidChange()` must apply native defaults and call dynamic `WALiquidGlassOverrideMethodUserDefaults.sharedInstance setEnabled:` if available, without hard-linking private headers.

---

## 8. WAABPropsObserver hooks

File: `src/Hooks/WAABPropsObserver.xm`  
Type: dynamic `MSHookMessageEx`.

Responsibilities:

- hook `WAABProperties`;
- hook `FOAWAABPropertiesImpl`;
- hook classes containing `WAABProperties` or `ABProperties`;
- hook BOOL zero-argument getters;
- hook `boolForKey:defaultValue:`;
- hook `stringForKey:defaultValue:`;
- keep diagnostics honest.

BOOL getter hook:

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

`boolForKey:defaultValue:`:

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

`stringForKey:defaultValue:`:

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

---

## 9. BundleHooks

File: `src/Hooks/WAGramBundleHooks.xm`  
Type: dynamic `MSHookMessageEx` over fixed selectors.

This module is required for categorized menus.

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
```

Hook one flag:

```objc
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

---

## 10. NativeSurface

File: `src/Hooks/WAGRNativeSurface.xm` or `src/Hooks/WAGramNativeSurfaceHooks.xm`  
Type: exact `MSHookMessageEx` registry.

Rules:

```text
runtime-wide-scan=NO
browser scan=ON-DEMAND only
```

Public API:

```objc
extern "C" NSNumber *WAGRNativeBoolOverrideGet(NSString *className, NSString *selectorName, BOOL classMethod);
extern "C" void WAGRNativeBoolOverrideSet(NSString *className, NSString *selectorName, BOOL classMethod, NSNumber *valueOrNil);
extern "C" void WAGRNativeBoolOverrideInstallPersisted(void);
extern "C" void WAGRNativeSurfaceEnsureHooksInstalled(void);
extern "C" NSString *WAGRNativeSurfaceDiagnosticText(void);
```

If these declarations are needed in `.m` / `.x`, include a guarded header; do not paste `extern "C"` into `.m` / `.x`.

---

## 11. Dogfood/Employee

File: `src/Hooks/WAEmployeeDogfoodHooks.xm`  
Type: dynamic `MSHookMessageEx`.

Selectors:

```text
isMetaEmployeeOrInternalTester
is_meta_employee_or_internal_tester
isInternalUser
graphQLEmployeeC1Disabled
```

Rules:

```text
first three return YES when gate/master active
graphQLEmployeeC1Disabled returns NO when gate/master active
```

Retry schedule:

```objc
double delays[] = {0.2, 1.0, 3.0, 6.0};
```

Do not set `installed = YES` before actual hooks are found.

---

## 12. Aura / WA Plus

File: `src/Hooks/WAAuraHooks.xm`  
Type: mixed WAAB + native selector hooks.

Positive flags write `"on"`:

```text
aura_enabled
aura_settings_row_enabled
aura_subscription_simulation_enabled
aura_app_icon_enabled
aura_app_themes_enabled
aura_ringtones_enabled
aura_stickers_enabled
ai_subscription_enabled
isEligibleForSubscriptions
wa_subscriptions_entry_point_settings_enabled
```

Negative/kill flags write `"off"`:

```text
aura_kill_switch
aura_premium_stickers_killswitch
```

Activation:

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

---

## 13. Keychain patch

File: `src/WAKeychainPatch.xm`  
Type: fishhook / `rebind_symbols`.

Functions:

```text
SecItemAdd
SecItemCopyMatching
SecItemUpdate
SecItemDelete
```

Rules:

- inert when rewrite and observer are both disabled;
- detect access group through guarded probe;
- use atomic guard to avoid recursion;
- observer logs metadata only.

---

## 14. UI browser contracts

### `WAGRABFlagBrowserVC`

Expected methods:

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

Simple switch browser:

```objc
- (void)tog:(UISwitch *)sw {
    NSString *flag = objc_getAssociatedObject(sw, @selector(tog:));
    WAGRSetFlagState(flag, sw.isOn ? @"on" : nil);
    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}
```

### `WAGRWAABTriStateBrowserVC`

Expected methods:

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

Tri-state mapping:

```text
0 = SYS
1 = OFF
2 = ON
```

```objc
- (void)segChanged:(UISegmentedControl *)seg {
    NSString *flag = objc_getAssociatedObject(seg, @selector(segChanged:));

    if (seg.selectedSegmentIndex == 2) WAGRSetFlagState(flag, @"on");
    else if (seg.selectedSegmentIndex == 1) WAGRSetFlagState(flag, @"off");
    else WAGRSetFlagState(flag, nil);

    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}
```

### `WAGRRuntimeMethodBrowserVC`

If `WAGramMenuVC.m` imports `WAGRRuntimeMethodBrowserVC.h`, create the header. Minimal compile-safe header:

```objc
#pragma once
#import <UIKit/UIKit.h>

@interface WAGRRuntimeMethodBrowserVC : UITableViewController
+ (BOOL)methodNameLooksFeatureLike:(NSString *)name;
+ (NSArray *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
@end
```

Rules:

- scan on demand only;
- no launch-time runtime-wide scan;
- persist exact NativeSurface entries;
- reinstall persisted hooks via `WAGRNativeBoolOverrideInstallPersisted()`.

---

## 15. Reset requirements

Every category/browser should provide reset actions.

Category reset:

```objc
static void WAGRResetFlags(NSArray<NSString *> *flags) {
    for (NSString *flag in flags) {
        WAGRSetFlagState(flag, nil);
    }

    [[NSUserDefaults standardUserDefaults] synchronize();

    WAGRWAABEnsureHooksInstalled();
    WAGRBundleEnsureHooksInstalled();
}
```

WAAB browser reset modes:

```text
Reset visible filtered flags
Reset all wagr.waab.* flags
```

Runtime browser reset modes:

```text
Reset visible exact native entries
Reset all persisted native entries
```

---

## 16. Build validation checklist

Run before every commit.

```sh
git diff --check
```

No placeholders:

```sh
grep -R "PLACEHOLDER" -n src && exit 1 || true
```

No `extern "C"` in `.m` or `.x`:

```sh
grep -R 'extern "C"' -n src --include='*.m' --include='*.x' && exit 1 || true
```

No missing imported project headers:

```sh
python3 - <<'PY'
from pathlib import Path
import re, sys

errors = []
for p in list(Path("src").rglob("*.m")) + list(Path("src").rglob("*.x")) + list(Path("src").rglob("*.xm")):
    s = p.read_text(errors="ignore")
    for inc in re.findall(r'#import\s+"([^"]+)"', s):
        candidates = [
            p.parent / inc,
            Path("src") / inc,
            Path(inc),
        ]
        if not any(c.exists() for c in candidates):
            errors.append(f"{p}: missing import {inc}")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY
```

No accidental `.mode` WAAB storage:

```sh
grep -R "\.mode" -n src && exit 1 || true
grep -R "setInteger:.*WAGRWAAB" -n src && exit 1 || true
```

Expected WAAB storage language:

```sh
grep -R "wagr.waab.%@" -n src
grep -R 'isEqualToString:@"on"' -n src
grep -R 'isEqualToString:@"off"' -n src
```

Expected key functions:

```sh
grep -R "WAGRWAABEnsureHooksInstalled" -n src
grep -R "WAGRBundleEnsureHooksInstalled" -n src
grep -R "WAGRNativeSurfaceEnsureHooksInstalled" -n src
grep -R "WAGRDogfoodEnsureHooksInstalled" -n src
grep -R "WAGRLGPrefsDidChange" -n src
grep -R "WAInstallKeychainPatchIfNeeded" -n src
```

---

## 17. Common errors and exact fixes

### Error: `extern "C"` in `Tweak.x`

Error:

```text
src/Tweak.x:12:8: error: expected identifier or '('
extern "C" void WAGRDebugBuildEnsureHooksInstalled(void);
```

Fix:

```objc
extern void WAGRDebugBuildEnsureHooksInstalled(void);
extern NSString *WAGRDebugBuildDiagnostic(void);
```

Better fix: move declarations into a guarded header and import it.

### Error: missing browser header

Error:

```text
fatal error: 'WAGRRuntimeMethodBrowserVC.h' file not found
```

Fix: create `src/Menu/WAGRRuntimeMethodBrowserVC.h` or remove the import and use a correct existing header. Minimal header:

```objc
#pragma once
#import <UIKit/UIKit.h>

@interface WAGRRuntimeMethodBrowserVC : UITableViewController
+ (BOOL)methodNameLooksFeatureLike:(NSString *)name;
+ (NSArray *)runtimeMethodsMatchingTokens:(NSArray<NSString *> *)tokens;
- (instancetype)initWithTitle:(NSString *)title tokens:(NSArray<NSString *> *)tokens;
@end
```

### Error: incomplete implementation

If a header declares:

```objc
+ (instancetype)section:(NSString *)header footer:(NSString *)footer rows:(NSArray *)rows;
```

the `.m` must implement the same selector. If the `.m` implements `sec:footer:rows:`, either change the header or add a compatibility method.

### Error: old/new UI model mismatch

Do not mix these without aliases:

```text
WAGramRow / WAGramSectionDef
WAGRow / WAGSection
```

Use the model that the current headers declare.

---

## 18. Final principle

The project can change UI freely, but the core rule never changes:

```text
UI writes exactly what hooks read.
Hooks call original when no override exists.
Runtime browsers scan only when opened.
NativeSurface uses exact registry, not launch-time global scan.
Diagnostics must match reality.
All imported headers must exist.
Tweak.x is not C++.
```
