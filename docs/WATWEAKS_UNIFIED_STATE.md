# WATweaks unified state

This patch removes the hidden `wagr.startupHooksEnabled` dependency and unifies persistence under `watweaks.*`.

Canonical keys:

```text
watweaks.override.objc|ClassName|inst|selectorName   = BOOL
watweaks.override.objc|ClassName|class|selectorName  = BOOL
watweaks.override.waab|flag_name                     = BOOL
watweaks.observed.objc|ClassName|inst|selectorName   = BOOL
watweaks.observed.waab|flag_name                     = BOOL

watweaks.pref.keychainRewrite  = BOOL
watweaks.pref.keychainObserver = BOOL
watweaks.pref.nativeDeveloper  = BOOL
watweaks.pref.debugMode        = BOOL
```

Startup behavior:

- Legacy keys are migrated once and removed.
- Saved ObjC overrides are reinstalled automatically.
- No global runtime scan is performed at startup.
- Every dynamic hook is validated before installation:
  - class exists
  - selector exists
  - method has two arguments: `self`, `_cmd`
  - return type is BOOL/char
  - IMP image is `WhatsApp.app/WhatsApp` or `SharedModules.framework/SharedModules`

Native Settings row:

- The injected WATweaks row is now a real `WATableSection`/`WATableRow`, not a custom footer.
- It uses WhatsApp's own static table rendering path.
