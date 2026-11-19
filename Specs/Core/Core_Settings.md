# Settings

Status: current normative contract
Last reviewed: 2026-11-19

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
- The file is read with `yyjson` using `YYJSON_READ_JSON5 | YYJSON_READ_ALLOW_BOM`, once at startup, before the main
  window is created. There is no settings watcher: an edit made while RedMonitor runs applies at the next start
  (register H-15 does not move RedMonitor).
- The setting ranges validated by the extraction source stay validated.

## Unusable files

- A file that cannot be read or parsed, or has no or an unsupported schema version, is not applied: RedMonitor starts
  with default settings and records the reason (`SettingsLoadRecoveryReason`).
- An invalid file-actions, user-menu or shortcuts section takes its defaults while the rest of the file applies, and
  its original member is kept unchanged across a save.
- The unusable file is moved aside to `<file name>.bad.<UTC yyyyMMddTHHmmssZ>` in the same folder (with a numeric
  suffix when that name exists), guarded by the identity stamp read at load, so a file changed since then is never
  moved.
- While the unusable file is still in place, defaults are never saved over it: saving then requires an explicit
  replacement, which moves the file to such a backup first.

## Saving

- Settings are saved when the main window is destroyed, except in the chrome self-test.
- A save goes through `support/LocalFileTransaction.h`: a temporary in the same folder, flushed, then published by
  atomically replacing the previous file (see [architecture](Core_Architecture.md)). A failed save leaves it as it
  was.
- A save compares the file's identity stamp (volume, file index, last write time, size) with the one recorded at
  load or at the last save. A file changed by another program in between is not overwritten
  (`ERROR_REVISION_MISMATCH`).
- A test-enabled build running under an authorized test root uses a settings folder below that root, so harness runs
  never touch the user's file.
