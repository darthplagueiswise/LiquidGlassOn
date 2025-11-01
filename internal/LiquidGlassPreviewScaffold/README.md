# LiquidGlass Preview Scaffold (Dev-only)

This package lets your internal/dev builds enable the *Liquid Glass* UI without patching or redistributing the production IPA.

## What it adds

- An `xcconfig` flag (`LIQUID_GLASS_PREVIEW=1`) for **Debug/Internal** builds.
- A small Objective‑C category that lets your flag layer read a local override (NSUserDefaults or a bundled `FeatureOverrides.plist`) only when the preview flag is on.
- A sample `FeatureOverrides.plist` (`LiquidGlassForcedEnabled = true`).
- An optional shell script to toggle the override with `defaults write` during development.

> **No binary patching, no app re-packaging, no jailbreak:** this is source‑level scaffolding meant for your internal branches only.

## How to integrate

1. Drop the contents of this folder into a new group in your Xcode project (e.g. `InternalPreview/`).  
2. Add `xcconfigs/Internal.xcconfig` to your project and set it as the base configuration for **Debug** (or a new *Internal* configuration).  
3. In your flag accessor for Liquid Glass (e.g., `-[LGFeatureFlags isLiquidGlassEnabled]`), wrap the remote/exp check with the preview macro:

```objc
#if LIQUID_GLASS_PREVIEW
    // 1) UserDefaults override (highest priority)
    NSNumber *forced = [[NSUserDefaults standardUserDefaults] objectForKey:@"LiquidGlassForcedEnabled"];
    if (forced != nil) { return forced.boolValue; }

    // 2) Plist override (bundled with internal builds)
    NSString *path = [[NSBundle mainBundle] pathForResource:@"FeatureOverrides" ofType:@"plist"];
    if (path) {
        NSDictionary *over = [NSDictionary dictionaryWithContentsOfFile:path];
        id v = over[@"LiquidGlassForcedEnabled"];
        if ([v respondsToSelector:@selector(boolValue)]) return [v boolValue];
    }
#endif

    // 3) Default: remote flag
    return [self remoteLiquidGlassEnabled]; // your existing logic
```

4. (Optional) Run the script below to flip the flag at runtime:
```sh
./Scripts/set_liquidglass_enabled.sh on   # or: off
```

## Notes

- Keep this code under `#if LIQUID_GLASS_PREVIEW` so it **never** ships to production.  
- The public method/selector names used here are placeholders; wire them to your actual feature‑flag class.  
- You can extend the pattern to other experiments safely.
