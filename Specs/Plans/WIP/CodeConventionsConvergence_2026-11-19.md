# Code conventions convergence (RedHome CV-6-08)

Status: ACTIVE — the viewer changes have merged. API 6 adoption, the settings name migration and
source-bound replays remain with their owning plans.
Owner: RedMonitor maintainers.
Prepared: 2026-11-19.
Planned-at commit: `0fbe8a7` (`RedSalamanders/RedMonitor` `main`).

- **Origin**: step CV-6-08 of the cross-repository
  [convergence plan](https://github.com/RedSalamanders/RedHome/blob/main/Specs/Plans/WIP/Convergence_2026-11-17.md)
  and section H of its
  [divergence register](https://github.com/RedSalamanders/RedHome/blob/main/Specs/Plans/WIP/Convergence_2026-11-17/DivergenceRegister.md).
  Each register row names one target for every repository; this plan lists the rows that move RedMonitor.
- **Owning contracts**: [repository guidance](../../../AGENTS.md), [architecture](../../Core/Core_Architecture.md),
  [validation](../../Testing/Testing_Validation.md) and [changes workflow](../../Core/Core_Changes.md). The shared
  skills in `../RedHome/.agents/skills/` (`wil-raii`, `d3d11-win32-host`, `file-io-safety`, `test-evidence`,
  `localization`, `app-settings`, `crash-dumps`) state the target rules once.
- **Coordinated plans**: [explicit state machines](ExplicitStateMachines_2026-11-10.md) owns the `ColorTextView`
  presentation and capture states and the `g_monitorFile*` tuples; [extraction](RedMonitorExtraction_2026-10-21.md)
  owns the S4 settings migration. Rows here change neither `Client.h` nor `Dependencies/DxUi.lock.json`.

## Rules

- One register row per pull request, with its `Changes/` fragment. A style or flag change never shares a pull
  request with a functional change.
- Merge gate (RedHome plan decision D21): the pull request checks pass and the six profiles (x64 and ARM64 ×
  Debug, Release, ASan Debug) build with zero warnings. Tests run where they can and are otherwise recorded as
  "tests deferred (D21)" for the later global test pass. A compile is not a runtime pass.
- No user-visible behavior changes beyond the row's target.

## Rows

- [x] **H-19 Device-loss results.** `ColorTextView` uses the common device-loss predicate at its draw and present
  boundaries. [#153](https://github.com/RedSalamanders/RedMonitor/pull/153)
- [x] **H-03 COM smart pointer.** The viewer's graphics owners use `wil::com_ptr_nothrow<T>` and propagate query
  failures through their existing result boundary. [#155](https://github.com/RedSalamanders/RedMonitor/pull/155)
- [x] **H-21 Top-level window ownership.** `MonitorWindow` owns its HWND and binds and detaches the window owner
  in `WM_NCCREATE` and `WM_NCDESTROY`. [#157](https://github.com/RedSalamanders/RedMonitor/pull/157)
- [x] **H-17 Direct3D adapter selection.** The viewer follows the adapter driving its monitor and retains the
  default hardware and WARP fallbacks. [#159](https://github.com/RedSalamanders/RedMonitor/pull/159)
- [x] **H-22 Test-process failure reports.** The selected test runner exercises the native suites'
  `--failure-report-self-test` entry points. [#161](https://github.com/RedSalamanders/RedMonitor/pull/161)
- [x] **H-25 Guarded saves.** Settings writes and confirmed text exports preserve a competing destination change
  under D23. [#125](https://github.com/RedSalamanders/RedMonitor/pull/125) · [#135](https://github.com/RedSalamanders/RedMonitor/pull/135)
- [x] **H-15 Settings reload.** The worker coalesces canonical profile changes and posts them to the UI thread.
  The [settings contract](../../Core/Core_Settings.md) owns the profile identity and legacy startup fallback.
  [#163](https://github.com/RedSalamanders/RedMonitor/pull/163)
- [x] **H-08 Resource-string gate.** The base and satellite resource files use the product's resource validation
  for identifiers and positional formatting.
- [x] **H-16 and H-24 Crash handling.** The viewer installs the five fault routes, owns a local pending report
  and one interactive restart notice, and retains ten new report pairs under D24.
  [Crash contract](../../Core/Core_CrashHandling.md) · [#123](https://github.com/RedSalamanders/RedMonitor/pull/123)
- [x] **H-27 Member naming.** The root `.clang-tidy` enforces the common member names. The published source
  passed six builds and 17 Clang Release translation units. [#166](https://github.com/RedSalamanders/RedMonitor/pull/166)
- [x] **H-26 Settings contract name.** The settings contract was a paragraph of
  [architecture](../../Core/Core_Architecture.md); it is now [Core_Settings.md](../../Core/Core_Settings.md), which
  owns the file names, location, schema, recovery and save. The Debug file already is
  `RedSalamanderMonitor-debug.settings.json`, but the Release file is `RedSalamanderMonitor-7.0.settings.json`, not the
  register's `<Product>.settings.json`: renaming it changes which file existing users read, so it moves with the S4
  settings migration of the [extraction plan](RedMonitorExtraction_2026-10-21.md), not here.

## Rows that wait

- **H-05 Logging helpers** and **H-14 Posted-payload helper.** The owner's target is `DxUi::Debug` and `DxUi`'s
  `PostedPayload.h`. Both live in `DxUi`'s private `src/Support/`, not in `include/DxUi/`, so a consumer cannot use
  them at any pinned commit. They wait until `DxUi` publishes them and RedMonitor adopts that `DxUi` revision, which
  under RedHome decision D20 is the API 6 adoption.
- **H-18 and H-19 library-owned HWND behavior.** The log viewer owns its device and swap chain. The toolbar
  and status bar use the pinned DxUi `ControlHost`. Apply and verify its Alt+Enter association and device
  recovery changes at the qualified API 6 consumer lock. [DxUi #331](https://github.com/RedSalamanders/DxUi/pull/331)
- **H-23 Keyboard state under hidden self-tests.** No RedMonitor self-test drives keyboard input
  (`ColorTextView` reads `GetKeyState` only for real input), so the row does not apply until one does.
- **H-01, H-02 and consumer tooling** wait for API 6 (D20). The pin review owns the ABI and failure-host migration,
  restore and provenance, compatible native policy and the native and package replays in the
  [consumption contract](../../Build/Build_Consumption.md).
- The [cross-repository test ledger](https://github.com/RedSalamanders/RedHome/blob/main/Specs/Plans/WIP/Convergence_2026-11-17/DeferredTests.md)
  preserves the D21 replay outcomes at their own source revisions.
