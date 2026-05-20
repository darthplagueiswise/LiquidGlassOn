# Native Developer / SharedModules validation

This patch is based on local Mach-O analysis of `/mnt/data/WhatsApp(3)` and `/mnt/data/SharedModules(7)` using LIEF 0.17.6 and Capstone 5.0.7.

## Confirmed ObjC class presence

`WhatsApp(3)` contains:

- `WAContextMain`
- `WASettingsViewController`
- `WASettingsNavigationController`
- `WADebugViewController`
- `WAFeatureControlGateKeeper`
- `_TtC15WADebugMenuMain17DebugMenuProvider`

`SharedModules(7)` contains:

- `WAContext`
- `WAServerProperties`
- `WAABProperties`
- `FOAWAABPropertiesImpl`
- `WAAuraGating`
- `WACustomBehaviorsTableView`
- `MobileConfigGating`

## Confirmed category discoveries in WhatsApp exec

The native Developer provider is not exposed only by the base Swift class. The relevant selectors are added through Objective-C categories in `__objc_catlist`.

`_TtC15WADebugMenuMain17DebugMenuProvider (WADebugMenuMain)` adds:

- `appDidFinishLaunchingSetup`
- `isDebugMenuShortcutEnabled`
- `isDebugMenuAllowed`
- `debugViewController`
- `debugShortcutContainerView`
- `presentDebugControllerIfNeeded`

`WAContextMain (WADependencyProviderMain3)` adds:

- `isVerifiedChannelFeatureFlagEnabled`
- `isBlueSubscriptionActive`
- `verifiedChannelFeatureFlagLimit`

`WAContext` from SharedModules receives categories from the WhatsApp exec:

- `WADebugMenuBase`: `resolveDebugMenuProviding`
- `WADebugMenuBase1`: `debugMenuProvider`

LIEF binding resolution for the category class slot showed the external class bind as `_OBJC_CLASS_$_WAContext` from `@rpath/SharedModules.framework/SharedModules`.

## Confirmed SharedModules hooks

`FOAWAABPropertiesImpl` implements:

- `boolForKey:defaultValue:`
- `stringForKey:defaultValue:`
- `integerForKey:defaultValue:`
- `doubleForKey:defaultValue:`

`WAPropertiesStore (WAPropertiesShared)` also has category implementations for the same `*ForKey:defaultValue:` accessors.

`WAServerProperties` has the class method:

- `+isInternalUser`

`WAABProperties` has category methods:

- `-isMetaEmployeeOrInternalTester`
- `-is_meta_employee_or_internal_tester`

`WAAuraGating` has the relevant gates:

- `isEnabled`
- `isUserEligible`
- `isSettingsRowEnabled`
- `isKillSwitchActive`

## Code changes in this patch

`src/Hooks/WAGRNativeDeveloperRouter.xm` adds the native developer path. It hooks the validated provider selectors on `_TtC15WADebugMenuMain17DebugMenuProvider`, injects a Settings footer row labelled `</> Developer`, resolves `debugMenuProvider` from `WAContext`/`WAContextMain`, and opens the original native Developer menu through `presentDebugControllerIfNeeded` or `debugViewController`.

`src/Hooks/WAGRSharedModulesCoreHooks.xm` adds focused SharedModules hooks for FOA WAAB lookup methods, `WAServerProperties +isInternalUser`, WAAB employee/tester selectors, and exact `WAAuraGating` methods.

`src/Runtime/WAGRSurface.m` restricts runtime scanning to classes and method IMPs that belong to either the WhatsApp executable or `SharedModules.framework`. This removes UIKit, Metal, CoreUI, GameController, FaceTime and other non-WhatsApp noise from the runtime browser.

`src/Hooks/WAGREmployeeHooks.xm` is now a compatibility shim only. It forwards old Dogfood entrypoints to the validated Native Developer / SharedModules core hooks.

`src/Hooks/WAEmployeeDogfoodHooks.xm` is intentionally empty to avoid duplicate symbols and broad employee hook behavior.
