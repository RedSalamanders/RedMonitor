# RedMonitor extraction and Red-family adoption

Status: ACTIVE. Owner: RedMonitor. Started: 2026-10-21.

This is the single execution plan for extraction and adoption. Intended contracts live in
`Specs/Core/Core_Architecture.md`, `Specs/Core/Core_Transport.md`,
`Specs/Build/Build_Consumption.md` and `Specs/Testing/Testing_Validation.md`.
Update this checklist and the evidence table at every implementation checkpoint. A checked
delivery item does not close the independent runtime, platform, performance or release gates.

## Delivery checklist

- [x] S0: inspect the source, consumers, ownership, license and local working trees.
- [x] S0: record imported source commit and original SHA-256 values.
- [x] S1: create the standalone project, private support closure, pinned dependencies and scripts.
- [x] S1: build and run the unchanged extracted model as the retained baseline.
- [x] S2: add the minimal public client and prove its wire compatibility.
- [x] S2: run standalone behavioral tests and all six build configurations.
- [x] S3: create `RedSalamanders/RedMonitor` on GitHub with initial source and CI.
- [ ] S3: remove the owned monitor source from RedSalamander and consume an exact RedMonitor pin.
- [ ] S3: preserve legacy executable, satellites, schema, themes and installer behavior.
- [ ] S3: qualify the RedSalamander launch, preferences, selftests and clean package extraction.
- [ ] S4: migrate independent RedMonitor settings and remove the broad legacy support snapshot.
- [ ] S5: adopt the client and optional launch integration in RedPrism.
- [ ] S6: adopt the client and optional launch integration in RedXe, including plugin boundaries.
- [ ] S7: adopt the client and optional launch integration in RedTilde.
- [ ] S8: complete native/platform, performance, accessibility and release qualification.
- [ ] S8: reconcile contracts/docs/capabilities, move this plan to Done and update indexes.

## 1. Verified starting point and exclusions

| Repository | Inspected source | Initial state | Integration owner |
| --- | --- | --- | --- |
| RedSalamander | `95f7114b892484414dd9daac7f3a89c1d1fd68ae` | Clean, `master`; origin DualTail/RedSalamander | Dedicated `ej/extract-redmonitor-20261021` branch |
| RedPrism | `97dd25b70e83f81c339a4b4e7e7b7589268f2510` | Unrelated test evidence changes | Separate adoption change after coordinating its current owner |
| RedXe | `e46a04351680046f9f7dc85c2426e01c818f468c` | Unrelated test evidence changes | Separate adoption change after coordinating its current owner |
| RedTilde | `cfa1a18bc273877cf050e9baa21835624326391c` | Unrelated test evidence changes | Separate adoption change after coordinating its current owner |
| DxUi | `fa5821c87f563a1d5b24ced7832b9c4fb9c1dcab` | Unrelated test evidence changes | No shared-control changes required by extraction |

The requested organization spelling resolves to the existing `RedSalamanders` organization.
Use `Z:\src\RedMonitor`; never create a new drive-root scratch directory. New repository
visibility starts private, matching the inspected RedTilde repository. A later visibility
change requires an explicit owner instruction. MIT license/copyright and theme notices travel
with imported code. Preserve origin commit and file digests instead of inventing new authorship.

Source locations below refer to the starting RedSalamander tree; original paths remain in the
source-origin manifest after removal. Historical Done/review/test-run records remain history.
Extraction is not permission to refactor unrelated file operations, themes, DxUi or test tooling.

## 2. Inventory and concrete ownership cut

| Starting path | New owner and action | Acceptance witness |
| --- | --- | --- |
| `RedSalamanderMonitor/RedSalamanderMonitor.cpp`, `.h`, `.rc` | RedMonitor `src/RedMonitor.*`; retain window, commands and harness | Window/chrome, open/save/cancel and close stress |
| `ColorTextView.*`, `ColorTextScrollBars.h`, `InvalidRectVisualization.h` | RedMonitor private view | Retention, search, scrollbars, selection and device-loss cases |
| `Document.*`, `MonitorTextSnapshot.h` | RedMonitor private model; immutable snapshots remain independent of eviction | Batch/filter/retention/snapshot tests |
| `EtwListener.*`, `MonitorDiagnostics.h` | RedMonitor transport and self-diagnostic policy | Decoder, callback lifetime, bounded shutdown and live roundtrip |
| `MonitorFileReader.*`, `MonitorFileExporter.*` | RedMonitor file I/O | Strict Unicode, budgets, cancellation and transactional failure tests |
| `Configuration.*`, resources, icons and four `Lang/*` satellites | RedMonitor product assets | Independent build and resource/satellite smoke |
| `Tests/MonitorTest/*` | RedMonitor tests; preserve legacy flags for the transition | Model, diagnostics and scrollbar selftest entrypoints |
| Selected `Common/` includes and six implementation units | Private static `RedMonitorSupport.lib`, with origin records | No link/load of RedSalamander's Common.dll |
| `Common/Helpers.h` producer and `Common/Common/TraceProvider.cpp` | Remain RedSalamander-owned during compatibility phase | Existing producer still decoded without rebuilding a plugin ABI |
| `RedSalamander/Preferences.Monitor.*` | Remain application policy; later use documented RedMonitor settings interface | Preferences Apply and restart roundtrip |
| `RedSalamander/RedSalamander.cpp::QueueRedSalamanderMonitorLaunch` | Consumer adapter, never shared window code | Missing dependency, duplicate launch, enabled/disabled auto-launch |
| Solution, `Installer/*`, build/test orchestration | Import/stage exact external artifact through compatibility projects | Direct project, solution, installer and clean ZIP tests |

Do not copy all of Common or any plugin into RedMonitor. The initially imported, transitive
support closure preserves extraction behavior but still contains broad settings/theme types.
It is private migration debt, not a public shared library or the proposed DxTheme project.
S4 narrows it after S3 behavior is proved. Never make clients include `support/` or `src/`.

## 3. Architecture decisions

1. RedMonitor is an independent EXE and optional header-only native producer client. Applications
   do not load the viewer into their process or link its model/rendering code.
2. Keep the existing TraceLogging GUID `440c70f6-6c6b-4ff7-9a3f-0b7db411b31a`, provider name and
   `DebugMessage`/`PerfScope` field schema during compatibility. Preserve type values separately
   from filter-bit values (`Text=0` is not the text filter bit). Schema additions are additive.
3. One producer provider registration per EXE/DLL module; never pass an owning C++ object or
   TraceLogging handle through a plugin ABI. The small SDK owns neither a worker nor a timer.
   Explicit lifetime precedes producers and ends only after their callbacks/threads quiesce.
4. Existing producer absence/registration failure does not impair the application. Disabled
   diagnostics must return before formatting/allocation. Logs have an explicit size ceiling.
5. In the first cut, retain the legacy settings app ID, single-instance mutex and satellite owner
   names so RedSalamander preferences/launch/installers keep working. Product output is
   `RedMonitor.exe`; RedSalamander stages the same artifact as `RedSalamanderMonitor.exe`.
   The alias is packaging compatibility, not a second implementation.
6. RedMonitor owns its DxUi exact commit and private output fingerprint. The initial pin is
   RedSalamander's inspected API-4 commit `f65e4a4b9311370b3e3070088e2a8abe29adcb27`.
   Every consumer owns an exact RedMonitor lock and isolated outputs. No implicit sibling path.
7. Resource files, schema, themes, notices and sanitizer runtime are part of the staging closure.
   Restoring the pin is not executing tests; cross-compilation is not native runtime evidence.

## 4. S0: freeze and characterize

1. Record Git HEAD/status and dependency locks in each repository; preserve dirty unrelated work.
2. Inventory every reference with `rg RedSalamanderMonitor`, including solution GUID mappings,
   satellite projects, schemas, resource catalogs, selftests, build receipts, runtime manifests,
   symbol packaging, MSIX identities, MSI shortcuts and screenshots.
3. Retain unmodified source digests in `Specs/SourceImport/source-origin.json`, with explicit
   moved implementation versus independently owned support snapshots. Include MIT and third-party
   notices. Hash imported test and tool sources as well as application sources.
4. Build the imported baseline before client/transport behavior changes. Run memory-only model
   fixtures and measure Release batch append, retention, filter changes, export-snapshot capture,
   private bytes and handles. Keep the exact binary/source/toolchain/fixture identities.
5. Characterize launch command, session permissions, settings and resource resolution. Existing
   user settings must not be overwritten by an unattended test.

Exit: reproducible source manifest, baseline receipts, caller inventory and no unresolved ownership cut.

## 5. S1: standalone project and developer experience

1. Create Git `main`, focused subsequent branches, `.gitignore`, `.gitattributes`, formatter,
   MIT license, README, truthful capabilities, specs/docs indexes and this active plan.
2. Supply `AGENTS.md`; CLAUDE/Copilot files only point to it. Add focused skills for build,
   transport/client, viewer lifetime, file safety, consumer adoption, testing and specifications.
3. Build application, private static support, console tests and resource-only satellites through
   MSBuild. Use Unicode, `stdcpplatest`, `/W4 /WX /permissive- /sdl`, matching MD CRT families,
   x64/ARM64 Debug/Release/ASan Debug and discovered VS toolchain. Force real ASan instrumentation.
4. Pin vcpkg tool/manifest independently; restore only WIL/yyjson, not RedSalamander's plugin packages.
   Restore DxUi to `.build/dependencies` and use its public consumer imports and one archive.
5. Implement PowerShell build, restore, test, validate, format, package and affected-test entrypoints.
   Validate output containment/reparse points before any recursive cleanup. Never kill existing apps.
   Record source, dependency, binary, configuration, command, scenario and exit status in evidence.
6. A clean standalone clone builds without RedSalamander or any other sibling repository. Verify
   dependencies using PE imports and a clean portable package. Preserve symbols separately.

Exit: independent working project; no RedSalamander path, Common.dll or plugin-runtime dependency.

## 6. S2: reusable client and transport proof

1. Publish only `include/RedMonitor/Client.h`, the transport contract and a compiling example.
   Document registration, module/thread ownership, shutdown, type mapping and disabled behavior.
2. Match legacy event field names/types exactly. Capture `FileTime`, PID and TID; reject oversized
   payloads before ETW's event ceiling, validate severity and preserve counted Unicode strings.
3. Keep source/application identification additive; initially use PID/TID and an application-labelled
   message adapter. Do not claim current multi-provider or per-source filtering support.
4. Tests: client type/filter mapping, empty/non-ASCII/non-BMP text, maximum and over-budget text,
   disabled provider, registration failure, repeated lifecycle and module lifetime. Decode a real
   synthetic event and compare every metadata/text field. Capture privilege denial as an unmet gate.
5. Own a unique ETW session, stop only a session this process created, fail without taking over an
   existing session, and test simultaneous monitor attempts. Retain bounded shared callback lifetime.
6. Verify old producer/new viewer and new producer/new viewer in Debug/Release; add cross-process
   bursts, lost-event counters and no-monitor client microbenchmark. Retain failure receipts.

Exit: tested compatibility, a frozen minimal API fixture, explicit version/capability contract.

## 7. S3: GitHub and RedSalamander cutover

1. Create `RedSalamanders/RedMonitor`, push reviewed standalone source to `main`, confirm default
   branch/visibility/remote SHA. Add CI for validators, x64 runtime and all six build profiles.
   Pending/blocked hosted CI remains pending. Do not invent release artifacts or successful checks.
2. Commit an exact `Dependencies/RedMonitor.lock.json` in RedSalamander. Restore to the consumer's
   generated tree; validate repository/commit/API and dirty state. Fail before compilation for a bad pin.
3. Replace the old monitor and MonitorTest native projects with thin external-build compatibility
   projects at the documented legacy paths. Update solution, installer project references,
   build routing and source inventories. Consumers never enumerate RedMonitor `.cpp` files.
4. Stage external EXE as the old filename plus PDB, MonitorTest executable, four satellites, themes,
   schema, notices and ASan runtime where applicable. Include the external lock/artifact closure
   in build evidence. Reject unknown/missing outputs; avoid broad overwrite of consumer DLLs.
5. Remove the native implementation/resources from `RedSalamanderMonitor/` and MonitorTest only after the new pin is
   published and compatibility builds pass. Keep historical specs/reviews/test evidence intact.
   Change active monitor specs/docs to describe the external owner and remaining cutover gates.
6. Update tooling inventory/help/tests and normatively document compatibility names. Reconcile
   localization resource-root tests and source-shape guards against the new dependency boundary.
7. Qualify auto-launch on/off, duplicate instance, spaces/Unicode install path, absent executable,
   Preferences filter/mask Apply, restart, existing settings and window placement, language switching,
   portable ZIP, MSI/MSIX manifests, symbols and receipt tampering/missing-runtime cases.
8. Run affected testing during edits and PrePush accounting before merge. Full/real-focus gates
   remain separately required by RedSalamander; request the person's agreement before focus tests.

Rollback: restore the previous RedSalamander commit or revert its cutover commit and rebuild the
matching dependency closure. Do not mix an old producer/schema with an unreviewed new viewer.
The standalone import and original digests preserve recovery without keeping a second live source tree.

## 8. S4: independent settings, naming and support reduction

1. Introduce a versioned RedMonitor settings document containing only viewer, retention, filters,
   source selection, theme and window state. Remove file-manager tabs/plugins/terminal types.
2. Migrate legacy monitor settings by read-once import when the new profile does not exist. Write
   atomically to a new RedMonitor path; preserve the old file for rollback. Never copy application
   credentials or unrelated settings. Test corrupt, missing, read-only and simultaneous migration.
3. Replace RedSalamander Preferences' direct storage coupling with a documented owned settings
   adapter or command. Choose one canonical writer and notification/version policy before coding.
4. Adopt `RedMonitor` resource/mutex/registry/class/perf identities with explicit compatibility
   aliases/removal conditions. Ensure old and new launches cannot consume/stop each other's sessions.
5. Replace private broad helper/settings snapshots with small RedMonitor-owned services. Shared
   theme evolution coordinates with RedSalamander I46/DxTheme; extraction does not close that plan.

Exit: no runtime settings dependency on RedSalamander and no public legacy Common surface.

## 9. S5-S7: per-application adoption steps

Each app gets its own feature branch, exact SDK pin, origin/update documentation, affected tests,
perf pair and release gate. Inspect its current owner/dirty state again; the table above is historical.

### RedPrism (S5)

1. Inventory `Common/PipelineTrace.h/.cpp`, `RedPrism/Application.cpp`,
   `ApplicationChromeSync.cpp`, `ApplicationSettings.cpp`, startup, renderer/device-loss and crash paths.
2. Preserve the existing `RedPrism.Pipeline` ETW provider and performance schemas. Add the RedMonitor
   diagnostic adapter alongside it; do not rename or double-count pipeline performance events.
3. Register the client in the EXE before owned workers, route severity-bearing diagnostic boundaries,
   retain current local/debug output policy and dispose after workers stop. Avoid logging per-pixel work.
4. Add an explicit optional monitor command/setting and exact runtime staging only if bundling is chosen.
   Disabled/missing monitor must not block editing, save, startup, recovery or rendering.
5. Test synthetic startup/error/Unicode/device-loss messages, disabled path, no monitor, simultaneous
   RedPrism/RedSalamander sources, session permission failure, portable launch and shutdown stress.
6. Benchmark image/selection/render workloads with diagnostics disabled and enabled under bounded bursts.

### RedXe (S6)

1. Inventory `RedXe/Application.cpp`, `Main.cpp`, `PluginManager.cpp`, `PluginHost.cpp`,
   `Renderer.cpp`, existing bounded log writer and all plugin logging callbacks.
2. Add the client to the host logging boundary; avoid one provider instance shared by EXE and DLLs.
   Host-forwarded plugin messages carry copied text/source identity; no owning SDK object crosses ABI.
3. Preserve existing file-log/crash fallback, bounded drain and device-loss behavior. Never open the
   monitor synchronously from frame composition, a device callback or a plugin unload callback.
4. Add optional launch/staging and settings schema/docs through RedXe's existing runtime dependency flow.
5. Test plugin failure/unload/reload, cancelled work, missing monitor, write bursts, log queue overflow,
   simultaneous dashboard sources, shutdown and portable extraction. Exercise real renderer paths.
6. Compare same-machine Release frame p95/p99, private bytes, allocations and worker wakeups.

### RedTilde (S7)

1. Inventory `RedTilde/Main.cpp`, `Application.cpp`, `UiControls.h`, document I/O, recovery/crash
   ownership and existing diagnostics. Preserve the exact pinned DxUi dependency independently.
2. Register before application workers; route diagnostic boundaries through a small app adapter.
   Log operation outcome/IDs, not document contents, personal paths or credentials by default.
3. Keep crash handling's local emergency path independent of ETW/client lifetime; avoid allocation,
   registration or monitor launch in an exception handler.
4. Add optional launch/staging and settings docs; do not change authoritative Markdown/history semantics.
5. Test failed save/open, Unicode text, stale image completion, diagram fallback, recovery startup,
   absent monitor, concurrent Red-family instances, shutdown and clean portable package.
6. Compare typing/caret/frame and open/save p95, memory and diagnostics-disabled startup on the same corpus.

## 10. Acceptance matrix, budgets and evidence

| Area | Required coverage | Gate |
| --- | --- | --- |
| Tooling | Parse/help, exact pins, dirty pin, traversal/reparse, no external process termination, staging closure | Every affected edit |
| Native | x64 Debug/Release/ASan tests; x64/ARM64 all three builds | S2 and changed consumer qualification |
| Sanitizer | Known-invalid owned probe actually detected, production tests clean | ASan acceptance; a build alone fails |
| Protocol | Real old/new producer roundtrip, metadata/severity, Unicode, bounds, denied access | S2/S3 |
| Model/I/O | Retention, filters/search, immutable snapshots, malformed/oversized files, atomic replacement and cancel | S1-S4 |
| UI/resources | Four satellites, DPI/themes, hidden idle, WARP/device loss, selection/clipboard, keyboard/accessibility | Viewer release |
| Distribution | Standalone clone, dependency imports, extracted ZIP, legacy staged package, symbols/notices | S3/S8 |
| Platform/manual | Native ARM64 execution, physical IME/AT and consented foreground fixtures | Explicit independent gates |

Keep queue defaults 4096, retained lines 100000, text 64 MiB and search matches 100000 unless
independently reviewed. Stop remains bounded at five seconds; shutdown test has a strict timeout.
Public client payload ceiling is 16000 UTF-16 code units including an application prefix, leaving
ETW metadata headroom; oversized input returns an explicit failure rather than silently truncating.
No-monitor writes do no formatting, I/O, waits or heap allocation. Performance fixtures use at least
five paired/alternating Release runs, identical source inputs and source-bound binaries; record samples,
medians, p95/p99, private bytes/working set, handles, CPU and event loss. Target disabled overhead
below 1 microsecond per call and no allocation; treat unmeasured targets as unmeasured. Compare viewer
append/retention/search/frame metrics against S0, investigate a repeatable >5% time/memory regression,
and present optimize/scope/defer options before changing a budget. Never silently rebaseline.

Evidence lives in repository-local generated run directories; retain reviewed summaries under
`Measurements/` with exact source/dependency/toolchain/artifact/scenario identity and commands.
No foreground or clipboard capture runs without agreement to the time. Application images come from
the deterministic harness with invented data, provenance and non-activating windows.

## 11. Checkpoint evidence

| Date | Scope | Result | Remaining |
| --- | --- | --- | --- |
| 2026-10-21 | Initial inventory | Source/license/consumer working trees inspected; origin digests recorded | Implementation and qualification below remain open |

Closeout requires successful source-bound evidence, updated active contracts/docs, generated changelog
folding, all per-consumer acceptance rows and release handoff. GitHub creation, a successful compile or
a focused test is never the completion criterion for the full migration.

### Initial implementation checkpoint (2026-10-21)

The source import has a retained Release baseline at commit `f9819e7`. Standalone native builds passed in
all six profiles; x64 Debug/Release/ASan console suites and real ETW roundtrips passed, with the deliberate
ASan overflow detected. A failed asynchronous-enable ASan roundtrip is preserved beside later corrected
receipts; the test now requests a bounded synchronous provider-enable barrier. Normal viewer startup keeps
its asynchronous behavior. Static yyjson linkage avoids a measured binary mismatch with RedSalamander's DLL.
The legacy settings filename is explicitly fixed at 7.0 independently of RedMonitor's 0.1 product version;
Debug keeps the existing debug filename. A no-write settings contract fixture protects that boundary.

Only source-free compatibility vcxproj files remain at the old RedSalamander monitor paths. This is a
narrower transition than physically removing those directories, because the paths are public solution,
IDE and installer entrypoints. The detailed plan preserves the same native source ownership goal.
The other applications' unrelated dirty work was not edited. Consumer cutover, native ARM64 runtime,
UI/focus/IME/AT, controlled performance and release gates remain open. Hosted CI is currently account-blocked before any steps; its initial run is failed, not passed. Qualification remains pending until an actual
successful run exists. See `Measurements/Extraction_2026-10-21/README.md` for scope and receipts.
Nested consumer restore exposed a long vcpkg baseline path at the first published pin. Source restore now keeps a short output key with the full fingerprint retained and collision-checked. Fresh nested consumption remains a required witness.
