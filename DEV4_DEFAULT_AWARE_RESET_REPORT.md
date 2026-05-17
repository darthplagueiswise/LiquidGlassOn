# DEV4 default-aware reset cleanup

This revision focuses only on runtime/UI/reset behavior, not git metadata.

## Fixed behavior

- Removed `registerDefaults` pollution. Older builds registered dozens of `@NO/@YES` defaults, which makes Flex/NSUserDefaults show synthetic `0/1` rows even when nothing was explicitly saved.
- Added default-aware visual state:
  - absent override = system/default value
  - `on` is written only when the user wants ON and the real default is OFF/unknown
  - `off`/`NO` is written only when the real default is known ON and the user wants OFF
- Liquid Glass master now displays ON when the app/system already says Liquid Glass is ON, without forcing hooks or writing all native keys.
- Liquid Glass hooks only force when the master has an explicit ON override.
- Runtime Browser now shows `effective`, `system`, and `override` states and removes old raw direct keys when clearing/changing rows.
- Full reset now removes WAGram overrides, old raw Runtime Browser keys, and legacy LiquidGlass/Aura direct keys.

## Startup safety

- WAAB hooks no longer scan at launch unless persisted WAAB overrides or observer are present.
- Aura gating no longer scans at launch unless Aura simulation/overrides are active.
- Context/debug broad scan no longer runs at launch unless context overrides are active.
- Settings hook still installs for the menu trigger/native Developer row path, but it is constrained to settings classes.

## Workflow

- `.github/workflows/build-enableliquidglass.yml` is set to `dev4`.

## Static validation performed

- Verified workflow branch/name = dev4.
- Verified no `registerDefaults:@{` call remains in `Tweak.x`.
- Verified reset helper exists and removes legacy raw/direct keys.
- Verified runtime browser cleans raw `e.name` keys from old builds.
- Verified false overrides are only written from default-aware paths.
- Verified WAAB/Aura/Context constructors are startup-inert without active persisted state.

Build/package was not run here because this environment does not include Theos/iPhoneOS SDK/Substrate.
