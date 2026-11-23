# RedMonitor development guidance

Read [Specs/README.md](Specs/README.md), the owning contract and [README.md](README.md) first.
RedMonitor is an independent EXE and small native producer SDK. RedSalamander, RedPrism, RedXe and
RedTilde are consumers; a change here never implicitly edits or qualifies them. Default branch: main.
Use focused `ej/` branches after the initial import.

## Engineering

- `src/` owns the viewer/model/listener/resources. `include/RedMonitor/` is the only producer interface.
- `support/` is a private, statically linked migration closure with recorded MIT origin. Never expose
  it to clients or link RedSalamander's Common.dll. Narrow broad settings/theme types under S4.
- DxUi is one exact pinned archive consumed through its supported imports. No enumerated DxUi sources,
  sibling fallback or dirty managed pin. Keep app policy here and shared controls in canonical DxUi.
- Use Unicode, `stdcpplatest`, `/W4 /WX /permissive- /sdl`, matching MD CRT, discovered VS and all six profiles.
  WIL owns Windows/COM resources. No manual destruction/release of an owned resource.
- No exception escapes Win32/COM/ETW callbacks. Catch named exceptions only with a documented fallback;
  allocation failure is fatal. Preserve bounded shutdown, callback state and stale-message draining.
- Queues, retention, matches and producer text are bounded. No worker/timer in the producer SDK; no
  formatting/allocation on its disabled path. No blocking I/O, layout or heap work in composition.
- Preserve wire GUID/name/field types and severity/filter mapping. Never stop a foreign ETW session.
  Module provider lifetimes end after worker/callback quiescence; no C++ ownership crosses plugin ABI.
- File reads validate Unicode and budgets before publication. Save snapshots are immutable and
  transactional; cancellation/failure preserves the previous target. Keep I/O off the UI thread.
- Preserve keyboard focus, Unicode, IME, selection, cancellation and accessibility. User strings live
  in resources. UI captures use deterministic non-activating app harnesses with synthetic data/provenance.
  Foreground/clipboard interaction requires the person's agreement to the time.
- Never edit/commit generated `.build` products, kill independently launched apps, or clean an unchecked
  path. Generated outputs stay below repository `.build`; validate canonical containment and reject
  reparse components. No new drive-root output without explicit authorization of that exact path.
- Keep one indexed WIP plan; durable behavior belongs in contracts. Record truthful capabilities and
  reviewed measurements. Move to Done only after all implementation/test/docs gates are actually closed.
- Use `Test-Changes.ps1 -Explain` then affected testing while editing; Full/PrePush are explicit.
  Require x64 Debug/Release/ASan tests and six builds for code qualification, a real ASan detection
  probe, native ARM64 execution for runtime claims and paired Release performance before non-regression.
  A successful compile or pending CI is not a runtime pass. Preserve failed receipts.
- Update docs and source provenance when moving ownership. Record the change as the Changes workflow below says.

## Drive-root output policy

Do not create scratch, caches, evidence, copied checkouts, or other output directories directly at a drive root.
Use repository-local generated outputs or an existing approved workspace. The only permitted new drive-root
output name is `<Project>.Perf`, named after the owning project (for example `RedSalamander.Perf` or
`RedPrism.Perf`), and the user must explicitly authorize the exact path before its first creation or
initialization. A matching name, environment variable, low disk space, or authorization for another drive or
project is not authorization. Keep outputs beneath the approved root; do not invent sibling root folders. Preserve
runner-specific ownership markers and authorization. Historical cleanup inventories and preserves useful evidence
and recovery data, checks process use, repairs live junction and worktree references, and verifies preservation
before removal. Never follow junctions during cleanup or leave compatibility junctions at forbidden old drive-root
paths.

## Skills

Shared skill index: `../RedHome/AGENTS.md`; packages: `../RedHome/.agents/skills/`. If `../RedHome` is missing, clone https://github.com/RedSalamanders/RedHome.git to that path. This repository's guidance and domain specs own product behavior and validation.

Read the relevant focused skill in `.agents/skills/`: transport-client, viewer-lifetime or consumer-adoption
(cross-repository C++/WIL and `spec-workflow` skills live in the sibling `RedHome` repository). Building, restoring
and packaging, file import and export, and tests and evidence are the shared `native-build`, `file-io-safety` and
`test-evidence` skills in `RedHome` (formerly build-redmonitor, file-safety and test-harness here), each with
RedMonitor's commands and rules in its `references/repository-facts.md`.

## Interactive desktop tests

A test that takes real foreground focus, the cursor or the clipboard runs only after the person at the desktop has
agreed to the time; silence never authorizes one. It warns before and while it runs, targets only windows the test
owns, and restores the foreground window, keyboard focus and pointer however it ends. Use the repository's
interactive entry point and desktop lease where it has one. Every other test and every harness capture stays hidden
and non-activating, and no scoped, CI or partial pass closes a focus-taking gate.

## Scoped testing policy

The user's accepted workflow replaces unconditional full-test iteration. While editing, run `Test-Changes.ps1 -Explain`
and then the affected default; use `-Mode PrePush` for the local six-profile matrix and explicit Full for one profile.
Required pull request checks have their own evidence. A pending CI check is never a
passed result. Reuse only exact successful evidence for the same source, pin, toolchain, binary and scenario. Native
test files use contextual `<Component>.Tests.<Subject>.h/.cpp` names, listed in the native file inventory where the
repository keeps one. Focus-taking work requires agreement to the time, and no scoped pass closes that gate. Build,
runtime and platform qualification still applies to changed behavior. [Specs/Testing/Testing_Validation.md](Specs/Testing/Testing_Validation.md) own the details.

## Changes workflow

Record each change as one dated Markdown fragment under `Changes/`; follow [Changes/README.md](Changes/README.md)
and [Specs/Core/Core_Changes.md](Specs/Core/Core_Changes.md). Do not hand-edit generated `CHANGELOG.md` entries.
Keep the fragment in the change: never fold it in a feature change and never edit `CHANGELOG.md`. Fragments are
folded on `main` after merge by `Tools/Submit-ChangelogFold.ps1`, which opens a fold pull request of its own. Run
`Tools/Test-Changelog.ps1` while editing; PrePush and CI run it with `-Base`, which refuses any `CHANGELOG.md` change
that is not an exact fold of fragments already on `main` or, where the repository releases through
`Tools/Release-Changelog.ps1`, the exact generated release transition. Validation is read-only.

## Unified CI policy

Use [Specs/Build/Build_UnifiedCI.md](Specs/Build/Build_UnifiedCI.md) for hosted CI. PRs run compiler-free checks and formatting feedback. Main native qualification starts after five continuous quiet minutes; both native Release test branches must pass before either production Release/ZIP branch starts. Scheduled dependency/security/status checks remain compiler-free. Formatting commits, extended qualification and any ZIP or winget publication are explicit manual actions. PR checks do not satisfy native acceptance or waive applicable local scoped tests. Shared-engine pins in .ci/project.json and workflow callers must agree. Preserve dependency pins, native toolchain, evidence and desktop ownership contracts.
