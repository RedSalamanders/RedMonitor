# Settings

Status: current normative contract
Last reviewed: 2026-11-24

RedMonitor's settings contract: where the file lives, what it is called, how it is read, what happens when it is
unusable, and how it is saved. It is the same contract name as in every RedSalamanders application (RedHome register
H-26). Until the independent-settings migration (S4 in the
[extraction plan](../Plans/WIP/RedMonitorExtraction_2026-10-21.md)), RedMonitor keeps the storage contract of
RedSalamander Preferences that it inherited with the private `support/` snapshot; see
[architecture](Core_Architecture.md).

## Identity and files

- The settings app ID is `RedSalamanderMonitor`, and the monitor window's placement is stored under window ID
  `MonitorWindow`.
- The folder is `%LOCALAPPDATA%\RedSalamander\Settings\` (`FOLDERID_LocalAppData`, then the `LOCALAPPDATA`
  environment variable).
- A Release build reads and writes `RedSalamanderMonitor-7.0.settings.json`. The `-7.0` part is the RedSalamander
  Preferences storage version, not RedMonitor's product version, so a new RedMonitor version never selects another
  file. A Debug build reads and writes `RedSalamanderMonitor-debug.settings.json`.
- When its own file is absent, a Release build reads the legacy `RedSalamanderMonitor.settings.json`, and a Debug
  build reads the Release file, then the legacy one. It then saves to its own file.
- Converging the Release name on `RedSalamanderMonitor.settings.json` (register H-26) changes which file existing
  users read, so it belongs to S4, which must preserve old files and rollback.

## Schema and reading

- [SettingsStore.schema.json](../SettingsStore.schema.json) is the schema. It ships as `SettingsStore.schema.json` next to
  the executable, among the artifacts every build receipt records.
- The store reads settings with `yyjson` using `YYJSON_READ_JSON5 | YYJSON_READ_ALLOW_BOM`.
  Startup reads the canonical profile or its documented legacy fallback before creating the window.
- The setting ranges validated by the extraction source stay validated.

## Unusable files

- RedMonitor starts with default settings when the selected profile cannot be used and records the reason
  (`SettingsLoadRecoveryReason`). Readable JSON outside the settings contract stays at its path.
- An invalid file-actions, user-menu or shortcuts section takes its defaults while the rest of the file applies, and
  its original member is kept unchanged across a save.
- A file with malformed JSON is moved aside to `<file name>.bad.<UTC yyyyMMddTHHmmssZ>` in the same folder (with a numeric
  suffix when that name exists), guarded by the identity stamp read at load, so a file changed since then is never
  moved.
- A successful backup of the canonical profile allows a defaults template at that name. The write requires the name
  to still be absent. A concurrent file wins, and a fallback profile keeps its separate path.
- While the unusable file is still in place, defaults are never saved over it: saving then requires an explicit
  replacement, which moves the file to such a backup first.

## Live settings

A worker waits on the canonical profile's directory and a stop event. The parent-directory notification lets it
attach when the settings directory appears. It coalesces notifications into a single pending window message. The
UI thread checks the file's identity stamp and reads changed settings through the no-recovery loader. A failed
read keeps the current settings and the on-disk bytes. The watcher joins before the viewer saves or destroys its
window.

Accepted edits update the viewer's theme, toolbar, line numbers, always-on-top state, IDs, auto-scroll, filter and
retention limits. An edited or removed saved window placement takes effect on the next start and is preserved at
shutdown. Language also takes effect at the next start. Legacy fallback files are used during startup.

## Saving

- Settings are saved when the main window is destroyed, except in the chrome self-test. A live reload performs no
  save, backup or recovery.
- A save goes through `support/LocalFileTransaction.h`: a temporary in the same folder, flushed, then published by
  atomically replacing the previous file (see [architecture](Core_Architecture.md)). A failed save leaves it as it
  was.
- A save compares the file's identity stamp (volume, file index, last write time, size) with the one recorded at
  load or at the last save. For an existing file, a delete-access guard denies writes while the transaction
  rechecks and replaces the accepted name. A different version or an unavailable guard returns a revision
  conflict. A new settings file uses non-replacing publication so a competing creation is preserved.
- The test-enabled viewer and settings support library honor the repository-local run directory assigned by
  `test.ps1`. The settings store validates ownership and rejects reparse points before it resolves a fixture path.
  A configured invalid test root refuses settings access. The legacy marked external root still works when the
  caller supplies it without a repository-local root.
