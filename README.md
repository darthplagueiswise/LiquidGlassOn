# LiquidGlassOn / WAGram

Feature research tweak for WhatsApp on iOS, based on [RyukGram-Fork/dev2](https://github.com/darthplagueiswise/Ryukgram-Fork/tree/dev2).

---

## Requirements

| Requirement | Value |
|---|---|
| Theos | Latest (SDK 16.2) |
| Target | iphone:clang:16.2 |
| Architecture | arm64 |
| WhatsApp | Any recent build (SharedModules confirmed) |

---

## Building

```bash
# Normal device install (jailbreak)
./build.sh

# Sideload variant (SideStore / AltStore) — includes WASideloadPatch
./build-sideload.sh
```

---

## Activating the Menu

**Long-press** the **Help** / **Help and Feedback** row inside WhatsApp **Settings**.

A bottom sheet will appear with four sub-menus:

---

## Sub-Menus

### 🔵 LiquidGlass (master toggle)

Enable the full LiquidGlass design system. Uses two strategies:

1. **UserDefaults override** — writes `WALiquidGlassOverrideMethodUserDefaults` immediately (no restart needed).
2. **Method hooks** — hooks `shouldUseLiquidGlassConfiguration`, `hasLiquidGlassLaunched`, `usesGlassMaterial`, `glassEffectEnabled`, `useLiquidGlassDesign/Style`.

Sub-flags (each maps to one ABProp validated in SharedModules):

| Sub-flag | ABProp key |
|---|---|
| LiquidGlass Enabled | `ios_liquid_glass_enabled` |
| LiquidGlass Launched | `ios_liquid_glass_launched` |
| M1 | `ios_liquid_glass_m1` |
| M1.5 | `ios_liquid_glass_m_1_5` |
| M1.5 Context Menu | `ios_liquid_glass_m_1_5_context_menu` |
| Chat Top Bar M2 | `ios_liquid_glass_chat_top_bar_m2_enabled` |
| New Chatbar UX | `ios_liquid_glass_enable_new_chatbar_ux` |
| Larger Composer | `ios_liquid_glass_larger_composer` |
| Reduce Transparency | `ios_liquid_glass_reduce_transparency` |
| Workaround Attachment Tray | `ios_liquid_glass_workaround_attachment_tray` |
| Workaround Hides Bottombar | `ios_liquid_glass_workaround_hides_bottombar` |
| Workaround Topbar Appearance | `ios_liquid_glass_workaround_topbar_appearance` |

---

### 🟣 Feature Flags

- **ABProps Observer** — read-only swizzle on `WAABProperties` / `ABProperties` / `WAMobileConfig` / `FBMobileConfig` / `LiquidGlassProvider` selectors. Logs selector name + return value (no forcing). Ring buffer: last 200 entries.
- **View Observation Log** — shows captured calls + return values.
- **Known Identifiers** — full list of WA AB/MC identifiers from SharedModules.

---

### 🟠 Dogfood / Employee

Hooks validated against `SharedModules` binary:

| Selector | Override |
|---|---|
| `isMetaEmployeeOrInternalTester` | → `YES` |
| `is_meta_employee_or_internal_tester` | → `YES` |
| `isInternalUser` | → `YES` |
| `graphQLEmployeeC1Disabled` | → `NO` |

- **Diagnostics** — shows which orig pointers were resolved.

---

### 🔴 Debug

- **Keychain Observer** — fishhook-based. Logs `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete` metadata (class, service, account, accessGroup, OSStatus). **Never logs `kSecValueData`.**
  - Also rewrites `kSecAttrAccessGroup` on Add/Copy/Update if a real app-group was resolved (sideload compat). Delete is never rewritten.
- **Keychain Diagnostics** — shows bundleId, resolved accessGroup, hook status.
- **Debug Mode** — verbose `NSLog` from all hooks. Filter Console.app by `[WAGram]`.

---

## Architecture

```
WAGram/
├── Makefile
├── control
├── WAGram.plist                    → injects into net.whatsapp.WhatsApp
├── build.sh
├── build-sideload.sh
├── src/
│   ├── WAGramPrefix.h              → precompiled header (prefs keys, macros)
│   ├── Tweak.x                     → %ctor + long-press hook on Settings Help
│   ├── Hooks/
│   │   ├── WASideloadKeychainPatch.xm
│   │   ├── WAEmployeeDogfoodHooks.xm
│   │   ├── WAABPropsObserver.xm
│   │   └── WALiquidGlassHooks.xm
│   └── Menu/
│       ├── WAGramMenuVC.h
│       └── WAGramMenuVC.m
└── modules/
    ├── fishhook/
    │   ├── fishhook.h
    │   └── fishhook.c
    └── SideloadPatch/
        └── WASideloadPatch.xm      → built only with SIDESTORE=1
```

---

## Credits

- **@darthplagueiswise (Radan)** — architecture, binary research, this tweak
- **RyukGram-Fork/dev2** — base patterns (SCIDogfoodingMainLauncher, SideloadPatch, SCIExperimentalMenu)
- **fishhook** — Facebook fishhook for SecItem interposition
