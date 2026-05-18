# WAGram Coding Guidelines — compile-safe tweak workflow

## 1. No half-patches

Do not ship a zip that still needs a script to edit source files after extraction. A delivery zip must contain complete, already-edited files in their final repository paths.

Acceptable upload command behavior:

```sh
unzip reviewed.zip -d /tmp/reviewed
cp -a /tmp/reviewed/. .
git diff --check
git add ...
git commit ...
git push ...
```

Unacceptable upload command behavior:

```sh
python3 - <<'PY'
# rewrites Objective-C after extraction
PY
```

Scripts may copy and validate. They must not finish unfinished code unless the user explicitly asked for a patch script.

## 2. Objective-C class contract

If code sends a selector on `self`, the visible interface for that class must declare that selector or a private class extension in the same file must declare it.

Bad:

```objc
@implementation WAGRABFlagBrowserVC
- (void)resetFiltered {
    [self confirmNuclearReset];
}
@end
```

Correct:

```objc
@interface WAGRABFlagBrowserVC ()
- (void)confirmNuclearReset;
@end

@implementation WAGRABFlagBrowserVC
- (void)resetFiltered {
    [self confirmNuclearReset];
}
- (void)confirmNuclearReset {
    // implementation
}
@end
```

Do not implement a method in a category if that same selector is declared by the primary class interface. With `-Werror`, this can become a hard build failure.

## 3. Class extension rule

If a file contains:

```objc
@interface SomeClass ()
```

then `SomeClass` must already have a primary interface:

```objc
@interface SomeClass : UITableViewController
@end
```

The primary interface may be in the same file above the extension, or in a header imported before the extension.

## 4. `Tweak.x`, `.m`, `.xm`

`Tweak.x` and `.m` compile as Objective-C. Do not put raw C++ linkage there.

Bad in `.x`/`.m`:

```objc
extern "C" void Foo(void);
```

Correct in `.x`/`.m`:

```objc
extern void Foo(void);
```

Correct in shared headers:

```objc
#ifdef __cplusplus
extern "C" {
#endif
void Foo(void);
#ifdef __cplusplus
}
#endif
```

Raw `extern "C"` is acceptable in `.xm`/`.mm` implementation files.

## 5. Crash-safe startup

The app must open and the WAGram menu must remain usable before heavy hooks install.

Heavy hook families stay inert at startup unless an explicit debug/default key enables them:

```text
wagr_startup_hooks_enabled = YES
```

Default must be OFF.

Do not install broad WAAB, BundleHooks, Dogfood, NativeSurface, or DebugBuild scans unconditionally at constructor time.

## 6. Toggle behavior

Normal toggles should write preferences only. They should not synchronously install heavy hooks unless the explicit advanced key is enabled:

```text
wagr_immediate_apply_hooks_enabled = YES
```

Safe flow:

```text
toggle -> persist -> user relaunches / explicit diagnostic action applies hooks
```

Unsafe flow:

```text
toggle -> immediate broad runtime scan -> crash before user can reset
```

## 7. NSUserDefaults emergency reset

Emergency reset must clear the entire standard `NSUserDefaults` domain, not only WAGram prefixes. Old builds may have written incompatible values using string `on/off`, boolean `1/0`, `.mode`, native `wa_*`, `aura_*`, `ios_*`, or keys with no prefix.

Correct pattern:

```objc
NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
NSDictionary *before = [ud dictionaryRepresentation] ?: @{};
NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
if (bundleID.length) [ud removePersistentDomainForName:bundleID];
for (NSString *key in before.allKeys) [ud removeObjectForKey:key];
[ud synchronize];
if (bundleID.length) CFPreferencesAppSynchronize((__bridge CFStringRef)bundleID);
CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
```

During emergency reset: do not call hook installers. Clean, sync, close.

## 8. WAAB storage contract

Current v10/v191-compatible storage:

```text
wagr.waab.<flag> = "on"   -> force YES
wagr.waab.<flag> = "off"  -> force NO
absent                    -> system/original
```

Do not mix `.mode`, boolean, and string formats in the same reader/writer set.

## 9. Compatibility headers

Headers like these are wrappers only:

```text
src/Menu/WAGRRuntimeMethodBrowserVC.h
src/Menu/WAGramWAABRuntimeCategoriesVC.h
```

They must import `WAGramMenuVC.h` and must not redefine interfaces already owned by `WAGramMenuVC.h`.

## 10. Required validation before every zip/commit

Run:

```sh
python3 scripts/wagr_validate_sources.py
git diff --check
```

Also inspect:

```sh
grep -R 'extern "C"' -n src --include='*.m' --include='*.x' && exit 1 || true
grep -R 'PLACEHOLDER' -n src && exit 1 || true
```

A delivery is not acceptable if these validations fail.
