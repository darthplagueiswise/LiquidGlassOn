# WATweaks Watusi/native Settings + runtime browser analysis

## What was extracted

The uploaded IPA was extracted locally. It contains Watusi/WatusiTools resources:

- `Payload/WhatsApp.app/Watusi.dylib`
- `Payload/WhatsApp.app/Watusi.bundle/Settings.bundle`
- `Payload/WhatsApp.app/WatusiTools.bundle`

The important part is not a normal iOS Settings.app plist. `Watusi.bundle/Settings.bundle` is used as an in-app resource bundle for icons/assets. The insertion into WhatsApp Settings is done by runtime hooks in `Watusi.dylib`.

## How Watusi injects its Settings row

Disassembly around Watusi's WASettings hook shows this flow:

- `objc_getClass("WASettingsViewController")`
- `class_addProperty(..., "w_tableSection", T@"WATableSection", &, N)`
- adds getter/setter methods for `w_tableSection`
- hooks/adds methods around `setSections:` and related settings lifecycle selectors
- uses native WhatsApp model classes such as `WATableSection` and `WATableRow`

This means the reliable/native way is not `tableFooterView` and not calling `addSection:` after setup. The row must be injected into the section model before WhatsApp commits the Settings table, especially through `setSections:`.

## What changed in this patch

1. `WAGRNativeDeveloperRouter.xm` now hooks `WASettingsViewController -setSections:` and appends a native `WATableSection` containing one native row named `WATweaks`.
2. The old post-facto `addSection:` approach is removed.
3. `WAGRSurface.m` restores the old broad listing behavior from commit `349bd`, but keeps gama's safety rule: only classes/methods whose image is `WhatsApp.app/WhatsApp` or `SharedModules.framework/SharedModules` are accepted.
4. Runtime Advanced now has two true browsers:
   - `WhatsApp Exec BOOL Browser`
   - `SharedModules BOOL Browser`
5. WAAB is no longer limited to runtime methods. It also loads the decompressed WAAB bool catalog from `/Library/Application Support/WAGram/waab_selected_categories_bool_only_catalog.json` and exposes those flags as patchable `WAABFlag` entries.
6. `WAGRSharedModulesCoreHooks.xm` now reads WAAB overrides as canonical `BOOL` objects under `watweaks.override.waab|flag_name`. It no longer expects legacy string values `on/off`.

## Expected behavior

The WATweaks row should appear in WhatsApp Settings as a native table row/section.

The Advanced Runtime Browser should list complete BOOL surfaces in two parts: main executable and SharedModules. WAAB should include catalog flags plus runtime getters.
