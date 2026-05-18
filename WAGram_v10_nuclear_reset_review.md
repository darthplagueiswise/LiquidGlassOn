# WAGram v10 Nuclear Reset Review

Applied crash-safety patch:

- Added Reset button in root navigation.
- Reset TOTAL now removes the whole app NSUserDefaults domain, not only prefixes.
- Reset does not call hook installers. It synchronizes and exits.
- WAAB flag toggles now write preferences only by default.
- Master toggles now write preferences only by default.
- Heavy hook install from switch is gated by `wagr_immediate_apply_hooks_enabled`.
- Updated coding guidelines and CLAUDE.md.
- Ran `python3 scripts/wagr_validate_sources.py`.
- Ran `git diff --check HEAD`.

Use Reset TOTAL after installing over older builds that wrote incompatible NSUserDefaults types.
