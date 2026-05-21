# GAMA / WAGram router rebuild checklist

Base used: uploaded `WATweaks-router.zip`.

This rebuild keeps the existing working long-press activation from `src/Tweak.x`. The long-press code was not replaced with the later broken activation scheme.

## Preserved

### `src/Tweak.x`
- Kept the original long-press activation path:
  - `WAGRLP`
  - `attachLP`
  - `isTrigger`
  - `WAGRPresent`
  - hook on settings `viewDidAppear:`
- Only changed the return declaration of `WAGRReinstallPersistedHooks` from `void` to `NSUInteger`, matching the real exported function.

## Fixed / changed

### `src/Menu/WAGRSurfaceListVC.m`
- Replaced the raw technical surface root menu with a RyukGram-style category root.
- Menu now shows user-facing categories first:
  - Geral
  - LiquidGlass
  - WA Plus / Aura
  - Status
  - Channels
  - Calls
  - Mensagens
  - AI / Meta AI
  - Privacy & Username
  - Premium & Business
  - Settings Rows
  - Developer / Dogfood / Internal
- Moved the raw runtime browser into `Avançado > Runtime Browser Avançado`.
- Removed colored category icons. Icons are monochrome using `UIColor.labelColor`.
- Added actions:
  - Install persisted hooks
  - Diagnostics
  - Restart WhatsApp
  - Reset overrides
  - Reset WAGram prefs
- Kept longpress behavior outside this file, exactly as the base router designed it.

### `src/Menu/WAGRSurfaceBrowserVC.m`
- Removed the `UISegmentedControl` visual UI (`SYS / OFF / ON`).
- Replaced row accessory with a simple `UISwitch`, matching the visual contract from RyukGram.
- Made cells compact:
  - one-line selector
  - small subtitle
  - smaller SF Symbol icon
- Removed raw huge technical display from the normal UX.
- Row tap still exposes advanced actions:
  - Force TRUE
  - Force FALSE
  - Clear / SYS
  - Install hook now
- Switch behavior:
  - ON = override true + install hook
  - OFF = clear override back to system
  - Force FALSE remains available from the action sheet.

### `src/Runtime/WAGRSurface.h`
- Expanded `WAGREntry`:
  - `displayName`
  - `isProperty`
  - `returnType`
- Expanded `WAGRSurfaceSpec`:
  - `subtitle`
  - `selectorTokens`
  - `categoryAllowList`
  - `scanProperties`
  - `advancedOnly`
- Added `+featureBundles`.
- Added C-linkage declarations for runtime helper functions.

### `src/Runtime/WAGRSurface.m`
- Added user-facing feature bundles.
- Kept raw surfaces for advanced browser only.
- Scanner now supports:
  - targeted class fragments
  - selector token filtering
  - BOOL property scanning
  - BOOL method scanning
  - property/getter dedupe
- Removed the display-name pattern that produced `@property @property`.
- Added richer categories:
  - Liquid Glass
  - WA Plus / Aura
  - AI / Meta AI
  - Debug / Internal
  - Settings Rows
  - Multi Account
  - Privacy / Username
  - Premium / Business
  - Calls
  - Messaging
  - Status
  - Status / Channels

### `src/Runtime/WAGRObjectGraphScanner.h`
- Added basic object graph model for settings/context exploration.

### `src/Runtime/WAGRObjectGraphScanner.m`
- Added targeted metadata scan for:
  - `WASettingsNavigationController`
  - `WASettingsViewController`
  - `WANewSettingsViewController`
  - `WAContextMain`
- Looks for ivars/properties like:
  - `_userContext`
  - `featureControlGateKeeper`
  - `usernameGatingService`
  - `aiIncognitoManager`
  - debug/developer/gating/settings-related members

### `src/Hooks/WAGRObjCHookRouter.xm`
- Fixed Objective-C++ IMP pointer bridging:
  - `reinterpret_cast<BoolIMP>([v pointerValue])`
  - `reinterpret_cast<const void *>(orig)` for `NSValue`
- Updated persisted hook parsing to support the new pipe-separated override keys.
- Kept legacy dot-separated key support for old installs.

### `src/WAGramPrefix.h`
- Changed override key format from dot-separated to pipe-separated:
  - old: `wagr.override.surface.Class.inst.selector`
  - new: `wagr.override|surface|Class.With.Dots|inst|selector`
- Reason: Swift/ObjC class names can contain dots, which broke parsing.
- Added nil guards to:
  - `WAGRHasOverride`
  - `WAGROverrideBool`
  - `WAGRSetOverride`
  - `WAGRClearOverride`
  - `WAGRObservedKey`
- Updated observed key generation for the new pipe-separated format.

### `src/Menu/WAGRSurfaceListVC.h`
- Fixed the exported type of `WAGRInstallHookForEntry` from `NSUInteger` to `BOOL`.

### `scripts/wagr_validate_sources.py`
- Added source validation for:
  - longpress tokens still present
  - no segmented `SYS/OFF/ON` UI
  - root menu categories present
  - runtime bundles present
  - no duplicated `@property` display pattern
  - ObjC++ function pointer bridging
  - local imports
  - required source files

## Validation run

```text
python3 scripts/wagr_validate_sources.py
OK: WAGram router Ryuk-style bundle validation passed

git diff --cached --check
OK
```

The sandbox does not include macOS/Theos/iPhoneOS SDK, so a real Theos build was not executed here. The package was validated statically against the errors seen in the GitHub Actions logs and the UI contract described by the screenshots.
