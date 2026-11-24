# Changelog

Entries are generated from [Changes](Changes/README.md). Existing release notes remain in their original locations.

## Unreleased
- Adopt the shared Release compile and link optimization profile for RedMonitor.
- Make the ETW shutdown fixture wait for actual worker retirement while keeping its callback context alive through detach.
- Apply the shared first-party compiler warning profile and retain the zero-warning build gate.
- Add the six-profile Visual Studio solution and enforce the selected MSVC 14.52 toolset in native builds.
- Exercise the pinned shared vcpkg checkout in the offline restore fixture.
- Include the full Unicode and WHATWG notices from the pinned DxUi source in portable packages.
- Use the shared changelog header while preserving the existing release history.
- Use the pinned engine to prepare vcpkg checkouts and validate native manifest install paths.
- Use the pinned shared Visual Studio and vcpkg triplet helpers for product builds and restores.
- Publish the canonical RedMonitor client update and verification commands with exact hashes and preserve the tooling pin during client refresh.
- Validate RedMonitor skills and guidance with the pinned shared CI engine and retain the product documentation and source checks.
- Adopt the shared scoped test runner while retaining RedMonitor's live ETW, contained installation and source-bound native gates.
- Exercise the formatter's wrong-engine refusal with a local mismatch commit, so the fixture works when hosted qualification supplies only the exact shallow pin.
- The winget block of `.ci/project.json` now declares a smoke test, `redmonitor --runtime-contract` with a
  120-second limit, as RedXe declares one (RedHome CV-6-07, register G-05). The engine runs it after a native winget
  install. The command is the headless check `package.ps1` already runs against every extracted Release package: it
  must exit 0 within 30 seconds with `PATH` limited to System32. Compiler-free checks pass.
- Moved the vcpkg tool pin in `vcpkg-tool.json` from `d53f25d5` to `aeb162b7`, the same commit as the baseline and
  as RedSalamander's pin (RedHome CV-4-07, register C-07). The managed checkout's scripts and triplets now come from
  that commit and its bootstrap downloads vcpkg-tool 2026-09-26 instead of 2026-07-27; package ABI hashes change, so
  the first restore rebuilds the dependencies. Compiler-free checks pass; native qualification runs on `main` after
  merge.
- RedMonitor restores vcpkg with the standard dynamic triplets (`x64-windows`, `arm64-windows`) instead of
  `*-windows-static-md`, the restore model and linkage every other scripted repository uses (RedHome CV-4-07,
  register C-07 and C-14, owner default of 2026-11-18). `yyjson` is now a DLL: every build copies `yyjson.dll`
  beside each executable (`Directory.Build.targets`, from `bin` or `debug\bin`), `build.ps1` lists it among the
  artifacts, `package.ps1` stages it beside `RedMonitor.exe` and no longer refuses it, and `Install-RedMonitor.ps1`
  requires it. **The Release package therefore ships `yyjson.dll` (about 260 KB) beside the executable.** Local x64
  Release and Debug builds pass; the Release package carries the DLL and its extracted `RedMonitor.exe` passes the
  runtime contract with `PATH` limited to System32. Native qualification of both architectures runs on `main` after
  merge.
- Moved the vcpkg `builtin-baseline` in `vcpkg.json` from `9eec002d` to `aeb162b7` (microsoft/vcpkg, 2026-10-22),
  RedSalamander's baseline, so every repository resolves ports from one baseline (RedHome CV-4-07, register C-06).
  Between the two baselines only `7zip` and `sqlite3` change, and this repository uses neither, so no dependency
  version changes. Compiler-free checks pass; native qualification runs on `main` after merge.
- Gave `Specs/Build/Build_UnifiedCI.md` the skeleton every RedSalamanders repository now shares (convergence
  CV-6-03, B-08): the same headings in the same order, one common text above `## Project adapter` built from the
  paragraphs the six files already shared, five stale statements corrected to the engine's `Specs/CI.md`, and every
  repository-specific sentence moved unchanged into the fixed adapter subsections. The WIP, Done and catalog headers also describe the index row format in words instead of a literal example link. Prose only; no CI
  behavior changed. Validated with the repository's specification validators and `Tools/Test-Changelog.ps1`.
- Gave the specifications the same shape as every RedSalamanders repository (convergence CV-6-03): the common
  `Specs/README.md` structure and WIP index row format, a `Specs/UI/` folder with the viewer window contract, a
  `Core_PerformanceAndResources.md` contract, a `Testing_RunEvidence.md` contract, the common README
  "Recording changes" section and CODEOWNERS file, and one statement of the consumer contract in
  `Build_Consumption.md` for the four applications to link to. Rules moved between specs unchanged; no behavior,
  build input or test changed. Validated with `validate.ps1` and `Tools/Test-Changelog.ps1`.
- Retired three repository-local agent skills now folded into shared skills in `RedHome` (convergence CV-2-12):
  `build-redmonitor` into `native-build`, `file-safety` into `file-io-safety`, and `test-harness` into
  `test-evidence`. Every rule and code line of the three is in the shared skills, with RedMonitor's commands,
  budgets and rules in each one's `references/repository-facts.md`. Claude Code (the `redhome` plugin), Codex, and
  Copilot list the shared skills from this repository. `AGENTS.md` points at them. No build, test or product input
  changes.
- Agent guidance now matches the other RedSalamanders repositories (`RedHome` convergence step CV-6-02).
  `.github/copilot-instructions.md` is the identical pointer to `AGENTS.md` that every repository uses. `AGENTS.md`
  has `## Engineering` and `## Skills` headings, with the shared-skill pointer directly under `## Skills`. It gains
  the shared drive-root, interactive desktop, scoped-testing and Changes sections, and Unified CI takes the shared
  text. The shared native build policy waits for the build-profile step, because RedMonitor still builds with
  `/W4 /WX`. The common `.gitignore` block ignores `.claude/settings.local.json` and `.claude/scheduled_tasks.lock`,
  and `capabilities.json` says `supported` instead of `implemented`. Nothing compiles differently.
- The settings contract moves from a paragraph of `Specs/Core/Core_Architecture.md` to its own
  `Specs/Core/Core_Settings.md`, the contract name every RedSalamanders application uses (RedHome register H-26,
  CV-6-08). It records the app ID, folder, Release and Debug file names and their fallbacks, the schema, JSON5 reading,
  the unusable-file backup and explicit-replacement rule, and the stamped atomic save, as the code does today. The
  Release file stays `RedSalamanderMonitor-7.0.settings.json` until the S4 settings migration. Documentation only.
- Converged the root files with every RedSalamanders repository (convergence CV-6-03, owner decision D18 and the
  B-12 default): `LICENSE.txt` is now only the common MIT text naming RedSalamander, and the new
  `THIRD-PARTY-NOTICES.md` lists what the package actually ships (DxUi and the components that revision compiles
  in, WIL, yyjson, the Dracula and Catppuccin palettes and the Visual C++ runtime), replacing a copied list that named
  18 components RedMonitor never shipped. `package.ps1` stages the notices file beside `LICENSE.txt`. The common
  `CONTRIBUTING.md`, pull request template and `.vsconfig` are added. Consumers keep the licence their
  `RedMonitor.lock.json` pins until they next update the client. Validated with `validate.ps1` and
  `Tools/Test-Changelog.ps1`; native packaging runs in main qualification.
- Added a resource-string gate, `Tests/Tooling.Tests.ResourceStrings.ps1`, run by the tooling tests without native
  compilation (RedHome register H-08, CV-6-08). It fails on a bare `{}` or unindexed `{:...}`, a printf token, a
  placeholder index gap, a string id missing from `src/resource.h`, an `IDS_` id the viewer source uses without a
  base string, and a satellite string whose placeholders differ from the base. Today's 51 base strings and four
  satellites pass; no string changes.
- Moved the shared CI engine pin from `1357f9c` to `f965c79`, engine `main` today, with `Update-ProjectPin.ps1`:
  `.ci/project.json` and the workflow callers name the same full commit. This is this repository's step of the
  `RedHome` convergence wave (CV-4-04, CV-4-05) that puts every repository on one engine commit. Between the two
  commits the engine joins the RedSalamander and DxUi changelog variants into the shared changelog commands with
  their product shim templates (CV-5-01, CV-5-02) and changes no workflow template. Compiler-free checks pass;
  native qualification runs on `main` after merge.
- Moved the shared CI engine pin from `d6a33c5` to `1357f9c`, engine `main` today, with `Update-ProjectPin.ps1`:
  `.ci/project.json` and the workflow callers name the same full commit. This is this repository's step of the
  `RedHome` convergence wave (CV-4-04, CV-4-05) that puts every repository on one engine commit. Between the two commits the engine adds local SDK build and binding guards, the shared changelog commands with their product shim templates (CV-5-01, CV-5-02) and the harness exclusions below, and changes no workflow template.
  The pin also adds the agent harness paths `.codex/**`, `.github/agents/**` and
  `.github/copilot-instructions.md` (and any other missing one) to the prose exclusions, so editing them no longer
  changes native inputs (CV-6-01). Compiler-free checks pass; native qualification runs on `main` after merge.
- Named the workflows and the Dependabot configuration on their own lines in the common CODEOWNERS file, which
  every RedSalamanders repository shares (convergence CV-6-03, B-12); `/.github/` already owned both, so no owner
  changes. Prose only. Validated with `Tools/Test-Changelog.ps1`.
- Planned the code-convention rows of the RedHome convergence register (CV-6-08) that move RedMonitor, one pull
  request per row, in `Specs/Plans/WIP/CodeConventionsConvergence_2026-11-19.md`. Plan only; no code changes.
- Run the changelog commands from the pinned shared CI engine (convergence CV-5-01, CV-5-02). `Tools/Test-Changelog.ps1`,
  `Fold-Changelog.ps1`, `Submit-ChangelogFold.ps1`, `Test-ChangelogWorkflow.ps1` and the new `Release-Changelog.ps1`
  are now copies of the engine's shims (`Templates/Project/Tools` at `f965c79`): the same names and parameters, running
  the engine implementation in `.ci-engine`, and refusing with one message when that checkout is missing, at another
  commit or changed. `Tools/Modules/Documentation/Changelog.psm1` is removed. The behavior suite now also proves these
  shims equal the pinned templates and that `Test-Changes.ps1 -Mode PrePush` checks the changelog first. Two engine
  changes reach this repository: two pending fragments with the same new text are refused by the fold, and a Git error
  while reading the base changelog fails `-Base` instead of skipping it. The scoped-testing fixture gets its own
  manifest and `.ci-engine` clone; `Specs/Core/Core_Changes.md` now points to the engine contract, and
  `source-origin.json` records the engine origin. Tooling-only; native runtime coverage is unchanged.
- Import the build console from the pinned shared CI engine (convergence CV-5-03). `Build/BuildConsole.psm1` is now the
  engine's module shim (`Templates/Project/Build/BuildConsole.psm1`): `build.ps1` and the tooling tests keep importing
  the same path and get the same four functions from `.ci-engine/Tools/Modules/Ci.BuildConsole.psm1`, and the import
  refuses with one message when that checkout is missing, at another commit or changed. The zero-warning gate also
  refuses a structured native tool exception dump (`ExceptionCode = <nonzero>`) despite a green MSBuild footer, as
  RedTilde's did. `build-console-origin.json` records the engine origin. Tooling-only; no compiler or linker setting
  changes.
- Both vcpkg restores now use a complete clone of the pinned vcpkg repository instead of a `--filter=blob:none`
  partial clone. vcpkg 2026-07-27 extracts each versioned port with `git read-tree` and `git checkout-index` in an
  environment that holds only `GIT_INDEX_FILE`; without `SystemRoot` that Git resolves no host, so a blob the
  partial clone left on the server failed the restore with "Could not resolve host: github.com". It started on
  2026-11-18, when upstream `master` (microsoft/vcpkg de36db0455) stopped carrying the `vcpkg-cmake` tree the
  baseline selects, and stopped every fresh restore. `vcpkg-install.ps1` clones completely, fetches the pinned
  commit without `--depth` only when it is missing, and completes an earlier partial checkout in place. The pinned
  DxUi installer still makes a partial clone, so `restore-dxui.ps1` first prepares its `<output>/vcpkg-tool` as a
  complete checkout at DxUi's pinned vcpkg commit (`Build/VcpkgToolCheckout.psm1`, the same file in every DxUi
  consumer), which that installer reuses. `Tests/Tooling.Tests.Vcpkg.ps1` checks the preparation offline against a
  `file://` registry, extracting an older tree the way vcpkg does, and pins both scripts. Native compile: the
  post-merge qualification.
- Every local skill description now says what the skill does and then when to use it ("Use when ..."), the form
  the shared `RedHome` skills already use, because an agent picks a skill from its description alone (`RedHome`
  convergence step CV-2-13). All six skills gain the clause, taken from each skill's own body; only their
  front-matter descriptions change. `validate.ps1` and the tooling tests pass; no build, test or product input
  changes.
- `format.ps1` now formats with the formatter CI uses and over the files CI formats. It takes clang-format from
  `Install-CiFormatter` in the pinned `.ci-engine` (22.1.3 today, under `.build/shared-format`) and selects the
  eight C and C++ extensions under the `formatRoots` of `.ci/project.json`, minus `formatExclude`; `-Check` still
  verifies without writing and now lists every file that needs formatting. Every source already conforms.
  `Build/clang-format.json`, `Tools/Install-ClangFormat.ps1`, and the Visual Studio and `PATH` lookups are
  removed; `Get-RedMonitorClangFormat` returns the engine install, so Test-Changes identity still hashes the
  formatter `format.ps1` uses. The formatter test now uses an owned Git fixture with its own engine clone, the
  selection-order test of the removed lookup is deleted, and the native CI adapter no longer runs the installer.
  `Testing_Validation.md` and the README describe the new command.
  This is step CV-6-05 of the `RedHome` convergence plan (register D-02, D-05, D-06).
- `.gitattributes` and `.gitignore` start with the common blocks that every RedSalamanders repository now
  shares, and `.editorconfig` is the shared file. The `.gitattributes` block stores text with LF and checks out
  C and C++ sources, PowerShell, and Visual Studio files with CRLF and Markdown, JSON, and YAML with LF; the
  repository's own lines follow it unchanged and still take precedence. No tracked file needs renormalizing:
  every file with CRLF or mixed line endings in the index is already `-text`.
  This is step CV-6-05 of the `RedHome` convergence plan (register D-03, D-04, and the `.editorconfig` part of B-12).
- Aligned agent guidance and dependency automation with the other RedSalamanders repositories (convergence step 1,
  planned in `RedHome`): `CLAUDE.md` is the same thin pointer to `AGENTS.md` in every repository,
  `.claude/settings.json` enables the shared `redhome` Claude Code skill plugin from the `RedHome` marketplace, and
  Dependabot now ignores `RedSalamanders/.github/*` so it stops opening one notice per shared-workflow caller; engine
  pins keep moving through `Update-ProjectPin.ps1` only. No build, test or product input changes.
- Consolidated the shared `spec-workflow` agent skill into the organization `RedHome` repository, retaining the six
  RedMonitor-specific skills under `.agents/skills/` and validating with `validate.ps1` and `Tools/Test-Changelog.ps1`
  (documentation/tooling only; native qualification unchanged).
  Shared-skill discovery names `../RedHome/AGENTS.md`, the package directory, and the clone URL while preserving
  local product authority.
  Guidance fixtures also recognize Windows error 1314 as unavailable symbolic-link privilege and report the
  documented capability skip; other I/O errors still fail.
- Build the existing viewer, satellite and console-test union for explicit local SDK candidates and run the normal Release scenarios through a complete held-payload reader, retaining separate runtime evidence without replacing pinned local or main gates.
- Classify the selected app dependency include directory through the compiler's external-include property for both viewer and support builds. Preserve first-party warnings and zero-warning acceptance; a real metadata control covers the isolated local SDK package path.
- Restored Find Bar window-procedure slots through the existing Win32 callback-data wrapper, preserving teardown behavior and the zero-warning build policy in SDK builds.
- Isolate each native build's compiler metadata service through the pinned shared launcher while preserving live output, literal arguments, exit codes and build acceptance checks.
- Limit overlapping native work to one job per architecture and recheck queued
  candidate inputs before compilation. Preserve active jobs and existing local,
  native, production and review obligations; candidate acceptance remains separate.
- Add an explicit local SDK viewer/support build with isolated output and dependency roots, live ownership
  and ABI guards, actual linker evidence and unchanged managed pins and normal acceptance gates.
- Preserve each completed independent validation, formatting and tooling result across later native failures, reusing only exact local inputs while keeping every native, ETW, packaging and installation gate.
- Bind local build and validation reuse to the actual clean pinned CI engine inputs while preserving the current local and main gates.
- Share the canonical SDK application/ABI guards and retain precise hosted SDK recipe-miss evidence. Exact mismatches still use source without accepting SDK bytes; native regression and production/package gates remain required.
- Support the separately authenticated qualified SDK reader with actual compiler/tool binding and exact package reopening, preserving legacy SDK/source paths and all native regression, ETW and package gates.
  Select the native MSBuild host explicitly and refuse a missing native host rather than substituting the legacy executable.
- Add the optional isolated native shadow caller and exact shared-engine admission tooling while retaining current required checks, local coverage and production qualification.
- Enable authenticated qualified DxUi SDK reuse for eligible hosted Release builds, preserving the existing dependency pin and all native regression, detector and package checks.
- Prepare authenticated exact-pin DxUi SDK bytes for admitted main Release build roles, with source fallback on a verified input miss and the same reader descriptor retained for production notices. Preserve every native regression and package gate; static, local and manual qualification retain their existing source recipe.
- Record the `ExplicitStateMachines_2026-11-10.md` active WIP plan covering `ColorTextView` `PresentPlan` scroll accumulation, filter layout sequence invalidation, `WM_CAPTURECHANGED` cleanup, `IDM_FILE_NEW` async-open cancellation, `Document` lock-scoped color ranges, and `EtwListener` session phases while keeping `include/RedMonitor/Client.h` unchanged.
  Validation: `validate.ps1` and `Tools/Test-Changelog.ps1 -Base origin/main` pass; plan only, no runtime source changed.
- Fix viewer UI freezes, ETW shutdown stalls, and auto-scroll/filter rendering regressions: maintain `Document` line offsets as a `std::deque<uint64_t>` with an incremental base and update retention eviction, visible-line indices, dirty ranges, and UI width/layout caches incrementally without full-document invalidation; stop marking retained lines dirty on severity filter changes; bound background width measurement to at most 32 candidate lines per pass and remove synchronous UI-thread DirectWrite fallback on threadpool admission failure; coalesce `kColorTextViewEtwBatch` posts and pace `UpdateWindow` repaints to 60 Hz (16 ms) during sustained ETW arrival; unify `AUTO_SCROLL` tail rendering, viewport scroll alignment, keyboard/caret navigation, and hit-testing across filtered and unfiltered views with per-line severity and user color spans without `WM_PAINT` fallback layouts or stale slice invalidations; stop the kernel trace session (`EVENT_TRACE_CONTROL_STOP`) before waiting on the ETW worker thread; eliminate full-vector `Lines()`/`VisibleLines()` copies in search, colorize, filtered clipboard copy (`GetFilteredTextRange`), and paint paths; gate status-bar and menu updates on state changes; and defer FindBar creation until requested while destroying it cleanly at teardown. Validated with `Tools/Test-Changelog.ps1`, `validate.ps1`, `format.ps1 -Check`, `Tests/Tooling.Tests.ps1`, x64 Debug/Release/ASan Debug `test.ps1 -IncludeLiveEtw`, and ARM64 Debug/Release/ASan Debug builds; native ARM64 execution and paired Release performance remain separate gates.
- Add explicit pinned Release DxUi SDK consumption with complete input/byte verification, live reader and per-translation-unit ABI guards, source fallback on exact misses, dependency-bound receipts and matching leased package notices. Guard Windows feature macros against SDK definitions and add actual MSBuild rejection controls; full runtime and overall acceleration acceptance remain separate.
- Adopt the shared guard and explicit owned-prose exclusions so new runtime Markdown and notice inputs retain native qualification; preserve existing native gates and historical artifact identity.
- Keep prose-only affected edits on changelog, validation, formatting and tooling checks, while cumulative code, test data and unknown inputs retain Debug execution. Preserve Full/PrePush profile, live transport and installation coverage, reject concurrent edits and nonzero child exits, and limit hosted Markdown exclusions to owned documentation.
- Adopt the shared engine's ABI-indexed vcpkg fallback cache and manual native dependency caching; keep compiler-free PRs, exact dependency pins and every native qualification gate.
- Restore winget availability during hosted Windows 11 ARM64 install validation by registering the image's inbox App Installer when winget is absent. The current shared CI engine includes this behavior; native installation checks and the explicit publication gates remain required.
- Adopt shared CI engine `1a42715`, whose native winget proof accepts validate's succeeded-with-warnings
  code (`0x8A150028`), records the hosted winget version and prints the log of any failing owned command.
  The hosted runners' winget still reported that code for `v0.1.82` after schema headers were added, so no
  submission occurred. Only the engine pin and generated callers change; publication still requires a fresh
  main qualification under this engine.
- Adopt shared CI engine `891b3bb`, whose generated winget manifests carry schema headers. winget 1.29
  `validate` previously exited with a warning code and failed the first Winget publication before any
  submission. Only the engine pin and generated callers change; publication still requires a fresh main
  qualification under this engine.
- Advance the exact DxUi API-4 pin from `f65e4a4b` to main `f2e328a0` (the 2 November delivery `6df17007` plus its
  upgrade guide and production review) and rebuild the full viewer/test closure. Release packages also carry DxUi's
  third-party notices and the toml++, rapidyaml and KaTeX notices now compiled into DxUi.lib. DxUi's open production
  review (embedded `TextField` P0, P1 defects, missing Unicode/WHATWG notices) and its planned history rewrite remain
  upstream gates; native ARM64 execution and paired performance are not run.
- Align the CI publication contract with the verified organization token policy and read-only credential check. Native qualification and exact-artifact Prepare remain separate acceptance gates; no product publication is selected.
- Adopt shared CI v1.0.7 with separate sandbox and workspace evidence uploads. Preserve paired native regression, production and archive validation; no product publication is performed.
- Adopt shared CI v1.0.6: DxUi SDK ZIPs stay internal with no publication workflow; application publication remains manual and artifact-only. Document the organization token route and separate implementation closeout from source-bound hosted acceptance; no product or winget publication is performed.
- Add a colored RedMonitor ASCII build banner and checked green result summary; keep ignored CI checkout/Git metadata out of source receipts while detecting real source edits, retain changed-path snapshots when a build's source changes, and enable incremental Debug linking to match the pinned DxUi Edit and Continue objects.
- Pin the common CI engine to v1.0.5: verify native portable winget registration, every installed command alias, declared smoke probes and owned cleanup; retain the compiler-free custom dependency status observer and recorded owner-only emergency PR merge route. Publication remains an explicit action requiring both matching native Release regression and production ZIP receipts.
- Document the explicit organization-owner, PR-only emergency merge route with a recorded reason and exact-head match; preserve actual checks and native publication qualification.
- Retain stdout/stderr and real exit codes for windowless hosted native commands through the common pinned CI engine v1.0.4.
- Upgrade shared CI to v1.0.3: fix literal-path formatting commits and separate archive/receipt/publication workflow outputs; preserve failed pilot evidence and the native test-to-production gate.
- Upgrade the shared CI engine to v1.0.2 so explicit formatting commits trigger fresh formatting/tooling, CodeQL and dependency-review checks on the exact new PR head. Native batching, toolchain and immutable ZIP publication contracts are preserved.
- Introduce the pinned organization CI adapter: compiler-free PR feedback, quiet-window main admission, native Release test-to-production gates, ZIP qualification and explicit publication. Preserve canonical project test, dependency, toolchain and evidence contracts; hosted rollout acceptance remains in progress.
- Adopt the shared fold-on-main Changes workflow used by DxUi, RedSalamander, RedXe, RedPrism and RedTilde: a change adds only a dated `Changes/` fragment and never edits `CHANGELOG.md`, so parallel branches no longer conflict on the changelog, and `Tools/Submit-ChangelogFold.ps1` folds the default branch in a temporary worktree and opens a fold pull request without touching the caller's checkout. `Tools/Test-Changelog.ps1 -Base` refuses any `CHANGELOG.md` change that is not an exact fold of fragments already on the base; `Test-Changes.ps1 -Mode PrePush` runs it against `origin/main` (Full validates fragments read-only), the CI tooling job runs it against `HEAD^1` for a pull request and the replaced tip for a push, AGENTS.md, the Changes contract and README and the tool index state the rule, and Git ignores the fold's lease and staged files. Validation: `Tests/Tooling.Tests.ps1` passed, including 27 shared changelog behavior cases with the PrePush runner, exact-fold and bare-remote submission fixtures; `validate.ps1` passed; `Tools/Test-Changelog.ps1` passed with and without `-Base origin/main`; and a rehearsal in throwaway clones (feature merge, depth-2 `-Base HEAD^1` check, fold branch, fold merge) passed on this repository's real changelog. No native build, hosted CI run or live fold pull request was exercised; the first fold of this repository's fragments remains to be run on `main` after merge.
- Close the hosted formatter repair after PR #2 and merged main passed tooling and all six native profiles; retain the separate extraction, viewer and consumer qualification gates.
- Pin the compatible native formatter and checksum-verified PowerShell installation for local and hosted checks, preserving the existing style, strict formatting errors and all native matrix jobs.
- Limit recognized Markdown fence openers and closers to zero to three leading spaces, preserving required-resource checks across four-space and tab-indented markers; add module and public-entrypoint boundary controls.
- Keep line-leading same-line backtick spans as inline prose so they cannot hide following required resources; retain tilde-fence info handling and cover module and public-entrypoint behavior.
- Recognize only complete unquoted date/timestamp metadata scalars so date-prefixed guidance stays valid prose; retain quoted strings and typed temporal rejection through header and public-entrypoint controls.
- Validate hidden skill packages and preserve quoted ISO metadata strings; keep inline-code spans within paragraphs and validate continued Markdown references and parenthesized titles through module and public-entrypoint controls, preserving literal file-URI filenames and exact plan-index counts.
- Prefer the selected Visual Studio Clang formatter over unrelated PATH LLVM, report its identity and reject incompatible style before source processing; preserve standalone fallback and cover selection with six read-only fixture controls.
- Count actual resolved Markdown link uses in the active-plan index separately from reference definitions, preserving resource validation while rejecting definition-only and duplicate-use indexes; cover full, collapsed and shortcut forms through module and public-entrypoint controls.
- Make public documentation and skill validation share local-link semantics, reject reparse headers before reads and validate drive/file-URI targets; cover balanced destinations, inline examples, typed descriptions and the actual public entrypoint with bounded fixtures.
- Validate skill headers, declared local references and active-plan indexing without requiring an extraction plan to remain in WIP; add build/test scope examples and focused read-only/lifecycle regression controls. Tooling validation does not imply native viewer qualification.
- Transfer the former consumer's detailed viewer validation obligations into the standalone contract, retaining Unicode, bounded decoding, snapshots, export/cancellation, lifetime, interaction and Release scaling requirements separately from the console subset already qualified.
- Reconcile the architecture contract with the implemented minimal client boundary: consumers vendor the pinned header and MIT notice, verify locally, and use the separately installed production Release helper without staging its executable or satellites.
- Use the independent RedMonitor product name in the French viewer title, matching the embedded and other localized titles; retain legacy resource-owner filenames for compatibility.
- Record the completed single-header integrations in RedSalamander, RedPrism, RedXe and RedTilde, with independent helper installation and explicit source-bound qualification gates; retain RedSalamander Release deferral, broader failed suites, native/platform, settings and performance work as unfinished.
- Mark the retained >2 GiB file boundary fixture as sparse before extension, and report the failing document-model subscenario; preserve its exact large-file rejection assertions without allocating 2 GiB per run.
- Make Client.h the complete normalized producer and installed Release-helper SDK; add local client verification, explicit header-only updates and standalone atomic installation. Consumer builds no longer own the viewer.
- Default Release viewers to production mode, bind explicit viewer-test settings in build receipts and stamp version/test-surface resources so consumer packaging cannot confuse test-enabled diagnostics with distributable artifacts.
- Add bounded application-labelled producer and optional adjacent viewer helpers, a clean pinned consumer SDK restore, cross-process ETW probes and an isolated runtime/resource contract; carry CRT and dependency notices in Release viewer packages while retaining separate consumer and platform qualification gates.
- Extract the Windows log viewer and its native model tests into independent RedMonitor with exact dependencies, developer scripts and focused skills; add the compatible native producer API and owned ETW sessions. Consumer adoption and full qualification remain in WIP.
