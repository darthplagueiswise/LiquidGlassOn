# LiquidGlassOn dev2 fixed package

This package was extracted from `LiquidGlassOndev2(1).zip`, inspected file-by-file, corrected, and repacked.

## Build-facing fixes applied

- `Makefile`
  - Removed `-include src/WAGramPrefix.h` from CFLAGS so `modules/fishhook/fishhook.c` is not compiled as if it imported UIKit/Foundation.
  - Kept `modules/fishhook/fishhook.c` as a normal C file.
  - Kept rootless staging of WAAB JSON catalogs and docs.
  - Set target to `iphone:clang:16.2:15.0` and package architecture to arm64/rootless compatible.

- `control`
  - Changed architecture to `iphoneos-arm64`.
  - Added firmware dependency for iOS 15+ rootless builds.

- `.github/workflows/build.yml`
  - Added `dev2` to push and pull_request branch triggers.

- `src/WAGramPrefix.h`
  - Completed all pref aliases used by `Tweak.x`, menu, and hook files:
    - `kWAGRKeychain`
    - `kWAGRKeychainObserver`
    - `kWAGRLiquidGlassUserDefaults`
    - `kWAGRLiquidGlassMethodHooks`
  - Added missing `WAGRWAABKeyRuntimeValue`.
  - Kept WAAB helper functions in one place to avoid duplicate definitions.

- `src/Menu/WAGramMenuVC.h`
  - Added `extern "C"` guards for symbols exported by `.xm` files and called from `.m`.

- `src/Menu/WAGramMenuVC.m`
  - Fixed `SW(key,...)` macro collision with Objective-C selector label `key:` by renaming the macro argument to `prefKey`.
  - Added explicit `WAGramPrefix.h` import.
  - Added safe WAAB mode clamping.

- `src/Tweak.x`
  - Added explicit `WAGramPrefix.h` and `WAUtils.h` imports.
  - Registered defaults through `WARegisterDefaults()` plus WAGram compatibility aliases.

- `src/Hooks/WAABPropsObserver.xm`
  - Removed duplicate local WAAB key helper functions; the prefix owns them.
  - Exported menu-called symbols with C linkage:
    - `WAGRWAABEnsureHooksInstalled`
    - `WAGRWAABDiagnosticText`
    - `WAGRABObsLog`
    - `WAGRABObsClear`
  - Removed unused `_wagrABInstallOnce`.
  - Added mode handling for string/integer/double overrides.
  - Prevented one-shot hook install failure from marking hooks installed when no class was hooked.

- `src/Hooks/WAEmployeeDogfoodHooks.xm`
  - Exported menu-called symbols with C linkage.
  - Removed duplicate `extern "C"` and unused once variable.
  - Startup remains inert unless employee master is ON.

- `src/Hooks/WALiquidGlassHooks.xm`
  - Exported `WAGRLGPrefsDidChange` with C linkage.
  - Startup remains inert if LiquidGlass master is OFF.
  - Method hooks only install when method hooks preference and master are ON.

- `src/WAKeychainPatch.xm`
  - Exported menu-called symbols with C linkage.
  - Removed unsafe `__builtin_return_address`/`Dl_info`/`dladdr` diagnostic path.
  - Kept SecItemDelete as observer-only/pass-through, no accessGroup rewrite.

- Public hook headers
  - Updated Keychain, Dogfood and LiquidGlass headers to match exported C-linkage symbols.

## Static checks performed

- Confirmed no Objective-C prefix include remains in Makefile CFLAGS.
- Confirmed no duplicate `WAGRWAABKey*` static functions remain in WAAB observer.
- Confirmed `WAGRWAABKeyRuntimeValue` is defined in the prefix and used by WAAB observer.
- Confirmed menu-called `.xm` symbols use `extern "C"`.
- Confirmed no `__builtin_return_address` or `Dl_info` remains in app code.
- Confirmed JSON resource files decompress and parse.

## Not performed

A full Theos build was not run in this sandbox because the Theos/macOS+iOS SDK toolchain is not available here. The package is prepared for the same GitHub Actions/Theos workflow already used by the repo.
