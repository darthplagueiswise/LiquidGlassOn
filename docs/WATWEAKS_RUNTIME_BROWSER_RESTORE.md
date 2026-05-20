# WATweaks runtime browser restore

This patch restores the useful behavior from commit 349bd: broad runtime discovery of hookable boolean methods. It keeps the safety model from gama.

The runtime scanner now has two raw image browsers:

- `runtime.exec` / `WhatsApp Exec BOOL Browser`
- `runtime.sharedmodules` / `SharedModules BOOL Browser`

Both scan all loaded Objective-C classes in their image, but only emit entries when the method/property is patchable:

- class image is `WhatsApp.app/WhatsApp` or `SharedModules.framework/SharedModules`
- method IMP belongs to the same allowed image scope
- method has exactly 2 arguments (`self`, `_cmd`)
- return type is BOOL-compatible (`B` or `c`)
- selector has no explicit arguments

This keeps UIKit/CoreUI/Metal/GameController/FaceTime out of the menus while bringing back complete FLEX-like runtime discovery for the two binaries that matter.

The WATweaks Settings row is also changed to be more robust. It first tries to add a real `WATableRow` into the existing `_sectionSettings`, then falls back to a new native `WATableSection`, then falls back to a WhatsApp-sized footer row if the private row API changed.

No `wagr.startupHooksEnabled` dependency is reintroduced.
