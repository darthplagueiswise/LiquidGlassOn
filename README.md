# EnableLiquidGlass (WhatsApp Liquid Glass Toggle)

This Theos tweak forces WhatsApp's "Liquid Glass" UI on iOS 26 by:

- Forcing the remote override key in `NSUserDefaults` via `SharedModules _METAGetOverrideLiquidGlassEnabledKey`
- Returning `YES` for status checks in `SharedModules` and `WDSLiquidGlass`

## Build
```sh
make package
```
Artifacts are under `packages/` (.deb) and the raw `.dylib` is inside the build output. Our CI uploads both.

## Inject into IPA
- Jailbreak: install the `.deb` normally (MobileSubstrate will load it).
- Sideload/patch IPA: place the `.dylib` and the generated `.plist` into
  `Payload/WhatsApp.app/Library/MobileSubstrate/DynamicLibraries/`, repackage and re-sign.

**Filter**: `EnableLiquidGlass.plist` filters bundle `net.whatsapp.WhatsApp`.

## Notes
- Tested against IPA 25.31.74; symbols found in main binary and `SharedModules.framework`.
- If WhatsApp changes symbols, update the selectors in `Tweak.xm`.
