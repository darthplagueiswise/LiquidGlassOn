# LiquidGlassOn v6 + WAGram_final merge

Base: `LiquidGlassOn-v6.zip` / `WAGram_v6`.
Integrated from `WAGram_final.zip`:

- Added `src/Menu/WAGRRuntimeMethodBrowserVC.m` read-only runtime browser for non-WAAB bool-ish methods (`is*`, `has*`, `should*`, `can*`, `supports*`, `*enabled*`, `*eligible*`, `*benefit*`, `*killswitch*`).
- Exposed the non-WAAB runtime browser from root menu under `Mais Features`.
- Added `WAGram Final Extras` bundle containing flags present in `WAGram_final` but absent from v6 curated bundles.
- Preserved v6 `WAGramBundleHooks.xm`, Aura crash-safe flow, and bundle UI.
- Updated Aura activation to mirror every force-on/force-off flag into both:
  - `wagr.waab.<flag>` string override
  - native `NSUserDefaults` bool key `<flag>`.

Important:

- `src/Hooks/WAGramDirectFlagHooks.xm` from WAGram_final was not copied because it uses the older `.mode` integer storage model (`WAGRWAABKeyMode`) that v6 intentionally replaced with `wagr.waab.<flag> = on/off`. v6 already has generic WAAB bool hooks plus direct bundle hooks in `WAGramBundleHooks.xm`, so copying the old file would reintroduce storage mismatch/build risk.
- The non-WAAB runtime browser is read-only on purpose. It catalogs methods outside WAABProperties; it does not hook arbitrary Swift/ObjC classes to avoid lag/crash.

Sanity checks run:

- `kSubKey`, `kMKey`, `kRootFlagKey` absent from `WAGramMenuVC.m`.
- `WAGRRuntimeMethodBrowserVC` declared in `WAGramMenuVC.h` and referenced from root menu.
- `WAGramFinalExtraFlags` exists and is exposed as a bundle row.
