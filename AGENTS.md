# RedMonitor development guidance

Read [Specs/README.md](Specs/README.md), the owning contract and [README.md](README.md) first.
RedMonitor is an independent EXE and small native producer SDK. RedSalamander, RedPrism, RedXe and
RedTilde are consumers; a change here never implicitly edits or qualifies them. Default branch: main.
Use focused `ej/` branches after the initial import.

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
- Update docs and source provenance when moving ownership. Add a dated Changes fragment; run
  `Tools/Test-Changelog.ps1`, then `Tools/Fold-Changelog.ps1` and `-Check` before final handoff/PrePush.

Read the relevant focused skill in `.agents/skills/`: build-redmonitor, transport-client,
viewer-lifetime, file-safety, consumer-adoption, test-harness or spec-workflow.
