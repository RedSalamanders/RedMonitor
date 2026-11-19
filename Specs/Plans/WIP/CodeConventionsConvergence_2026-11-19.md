# Code conventions convergence (RedHome CV-6-08)

Status: ACTIVE — plan written; each row lands in its own pull request.
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

- [ ] **H-19 Device-loss results.** `ColorTextView` treats `D2DERR_RECREATE_TARGET`, `DXGI_ERROR_DEVICE_REMOVED` and
  `DXGI_ERROR_DEVICE_RESET` as device loss (three sites). Target: the union `DXGI_ERROR_DEVICE_REMOVED`,
  `DXGI_ERROR_DEVICE_RESET`, `DXGI_ERROR_DEVICE_HUNG`, `DXGI_ERROR_DRIVER_INTERNAL_ERROR`, and
  `D2DERR_RECREATE_TARGET` where Direct2D draws to the swap chain, through one predicate.
- [ ] **H-03 COM smart pointer.** `ColorTextView` holds its Direct3D, DXGI, Direct2D and DirectWrite interfaces in
  `wil::com_ptr<T>` (about 50 uses), and RedMonitor has no `wil::com_ptr_nothrow<T>`. Target:
  `wil::com_ptr_nothrow<T>` in `noexcept` and `HRESULT` code; every throwing `query` or `query_to` becomes a checked
  `try_query` or `query_to` result.
- [ ] **H-21 Top-level window ownership.** The main window is created without `lpCreateParams`, its
  `wil::unique_hwnd` is released into the global `g_hMainWindow`, and the window procedure reads globals. Target:
  one owner object bound in `WM_NCCREATE`, holding the `wil::unique_hwnd`. The other process-wide state moves with
  the explicit state-machine plan, which owns it.
- [ ] **H-17 Direct3D adapter selection.** `ColorTextView` creates its device on the default adapter through
  `DxUi::CreateD3D11DeviceWithWarpFallback`. Target: the adapter whose output owns the window's monitor, then the
  default hardware adapter, then WARP, and a device rebuilt when the window moves to a monitor of another adapter.
- [ ] **H-22 Test-process failure reports.** Every native test entry point already routes failure reports away
  from dialogs (`Tests/TestSupport/TestSupport.Tests.FailureReports.h`). Target: each also answers
  `--failure-report-self-test`, and a tooling test runs that switch for every native suite.
- [ ] **H-25 Replace sequence of a file save.** `support/LocalFileTransaction.h` publishes with a handle rename
  (`FileRenameInfoEx`, POSIX semantics), then `MoveFileExW`. Target: `ReplaceFileW` over an existing destination
  after its identity check, `MoveFileExW(MOVEFILE_WRITE_THROUGH)` for a new one, with one fault-injection hook per
  step (the hooks already exist for write, flush and publish).
- [x] **H-08 Resource-string gate.** `src/RedMonitor.rc` and the four satellites have a `STRINGTABLE` and no gate.
  Target: a gate that fails on bare `{}`, printf tokens and unresolved ids.
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
- **H-24 Crash handler and contract.** RedMonitor has no crash handler. The handler's artifacts, retention and
  next-start prompt are register row H-16, which has no chosen shape yet; the handler and
  `Specs/Core/Core_CrashHandling.md` wait for it.
- **H-15 Settings reload.** RedMonitor has no settings watcher, and the register does not list it as moving; adding
  live reload would be new behavior. Unchanged here.
- **H-23 Keyboard state under hidden self-tests.** No RedMonitor self-test drives keyboard input
  (`ColorTextView` reads `GetKeyState` only for real input), so the row does not apply until one does.
- **H-01, H-02** wait for API 6 (D20).
