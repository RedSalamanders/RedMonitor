# Settings

Status: current normative contract
Last reviewed: 2026-11-25

RedMonitor owns its per-user viewer profile and settings writes. A RedSalamander installation or profile is
optional. The [extraction plan](../Plans/WIP/RedMonitorExtraction_2026-10-21.md) records the S4 cutover.

## Identity and files

- The settings app ID is `RedMonitor`. The folder is `%LOCALAPPDATA%\RedMonitor\Settings\`
  (`FOLDERID_LocalAppData`, then the `LOCALAPPDATA` environment variable). Release reads and writes
  `RedMonitor.settings.json`. Debug uses `RedMonitor-debug.settings.json`. The product version does not affect the name.
- **File > Open Settings File** opens the active profile in the system's associated editor.
- The version 16 document owns the `monitor` options, theme, the placement under `windows.MonitorWindow`, and
  the `ui` settings `language`, `compactMode`, `reducedMotion` and `windowBackdrop`.

## Cold migration

When the canonical profile is absent, Release tries `RedSalamanderMonitor-7.0.settings.json` and then
`RedSalamanderMonitor.settings.json` under `%LOCALAPPDATA%\RedSalamander\Settings\`. Debug first tries the
legacy Debug profile, then the independent Release profile, then the same legacy Release candidates.

If those profiles are absent, the matching legacy main RedSalamander profile can supply its historical `monitor`
section. Import from the main profile is limited to that section.

The viewer imports only settings it owns. It preserves source files byte for byte for rollback, including
malformed and read-only files. Missing or unusable inputs yield viewer defaults. The first write requires
a vacant canonical path and preserves a concurrent creation. A readable winning profile takes precedence.

## Schema and reading

- [SettingsStore.schema.json](../SettingsStore.schema.json) is the schema. It ships as `SettingsStore.schema.json` next to
  the executable, among the artifacts every build receipt records.
- The store reads settings with `yyjson` using `YYJSON_READ_JSON5 | YYJSON_READ_ALLOW_BOM`.
  Startup reads or initializes the canonical profile before creating the window.
- The setting ranges validated by the extraction source stay validated.

## Unusable files

- RedMonitor starts with default settings when the selected profile cannot be used and records the reason
  (`SettingsLoadRecoveryReason`). Readable JSON outside the settings contract stays at its path.
- Individual unusable viewer fields take their defaults. Unknown top-level members in the current canonical profile
  are retained across saves.
- A canonical file with malformed JSON is moved aside to `<file name>.bad.<UTC yyyyMMddTHHmmssZ>` in the same folder
  (with a numeric suffix when that name exists), guarded by the identity stamp read at load.
- A successful backup allows a defaults template at the canonical name. The write requires the name to still be absent.
- While the unusable canonical file is still in place, defaults require an explicit replacement. The replacement
  moves the accepted input to a backup before publishing.

## Live settings

A worker waits on the canonical profile's directory and a stop event. The parent-directory notification lets it
attach when the settings directory appears. It coalesces notifications into a single pending window message. The
UI thread checks the file's identity stamp and reads changed settings through the no-recovery loader. A failed
read keeps the current settings and the on-disk bytes. The watcher joins before the viewer saves or destroys its
window.

Accepted edits update the viewer's theme, toolbar, line numbers, always-on-top state, IDs, auto-scroll, filter and
retention limits. An edited or removed saved window placement takes effect on the next start and is preserved at
shutdown. Language also takes effect on the next start. The watcher follows the canonical profile throughout the session.

## Saving

- Settings are saved when the main window is destroyed, except in the chrome self-test. A live reload performs no
  save, backup or recovery.
- A save goes through `support/LocalFileTransaction.h`. It flushes a same-directory temporary and atomically replaces
  the previous file. A failed save preserves the target. [Architecture](Core_Architecture.md)
- A save compares the file's identity stamp (volume, file index, last write time, size) with the one recorded at
  load or at the last save. For an existing file, a delete-access guard denies writes while the transaction
  rechecks and replaces the accepted name. A different version or an unavailable guard returns a revision
  conflict. A new settings file uses non-replacing publication so a competing creation is preserved.
- The test-enabled viewer and settings support library honor the repository-local run directory assigned by
  `test.ps1`. Both canonical and legacy paths resolve within that run. The settings store validates ownership and
  rejects reparse points before it resolves a fixture path. A configured invalid test root refuses settings
  access. The legacy marked external root works when supplied without a repository-local root.
