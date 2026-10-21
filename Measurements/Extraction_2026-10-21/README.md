# Initial extraction evidence, 2026-10-21

Scope: standalone native source extraction and minimal producer implementation. The canonical WIP plan remains ACTIVE.

The baseline is source commit `f9819e708b3134e3c76e4cecf4d2ab092494fc31` with original source digests in
Specs/SourceImport. Its Release test receipt is retained here; baseline binaries/build receipt are kept locally
under `.build/baselines/extracted-release-20261021`. Later receipts name their exact source identity and
build-receipt digest. They are distinct snapshots, not interchangeable qualification.

- `delivery-debug-tests.json`: six non-activating scenarios passed, including settings-path compatibility and real ETW.
- `delivery-release-tests.json`: the same six scenarios passed.
- `delivery-asan-tests.json`: six functional scenarios passed; a seventh deliberate heap-overflow probe exited nonzero
  with the expected AddressSanitizer diagnostic. The diagnostic is an expected detection, not a product test failure.
- `failed-asan-roundtrip-tests.json`: original failed immediate enabled-state check is retained. EnableTraceEx2 with
  timeout zero is asynchronous; the corrected fixture requests a bounded 2000 ms provider callback barrier. Normal
  viewer startup remains asynchronous. [Windows API contract](https://learn.microsoft.com/en-us/windows/win32/api/evntrace/nf-evntrace-enabletraceex2).
- `standalone-release-imports.txt`: PE dependency inspection finds neither Common.dll nor yyjson.dll; JSON is statically linked.
- `diagnostic-paired-model.json`: five alternating Release pairs, all successful. Combined scenario mean was 107.81 ms
  baseline versus 116.35 ms candidate. Compiler work was running concurrently and the fixture includes test-path and
  file-I/O work; working-set data was unavailable. This is diagnostic evidence only, and establishes no performance
  non-regression. Controlled viewer/client resource and timing qualification remains open.
- Earlier baseline/client/static receipts preserve the history and their original outcomes.

Commands: `build.ps1` for x64/ARM64 Debug, Release and ASan Debug; `test.ps1 -SkipBuild -IncludeLiveEtw` for each x64
profile; `validate.ps1`, `format.ps1 -Check`, `Tests/Tooling.Tests.ps1`, and the two changelog gates. Changelog behavior
fixtures passed 22 cases, plus output-boundary assertions. `package.ps1 -Configuration Release` creates a source-bound
runtime manifest and verifies every packaged file after fresh extraction.

These console tests neither activate a window nor open the clipboard. No real-focus/physical IME/AT test was run.
ARM64 results are cross-build evidence only. Viewer UI/WARP/device-loss/clean-dirty-hidden resource tests, controlled
performance, native ARM64 execution, RedSalamander integrated Full/package/launch/preferences acceptance and the other
three application adapters remain separate gates. Hosted CI is never inferred from a local pass.

Hosted CI run [39678111476](https://github.com/RedSalamanders/RedMonitor/actions/runs/39678111476) failed before
any job step. GitHub's annotation says recent account payments failed or the spending limit must be increased.
This is an account scheduling block, not a successful CI run or a compiler/test result.

The first real nested consumer restore at pin b4025b4 exposed a Windows path-length failure in vcpkg's
DxUi baseline checkout. The complete log remains in RedSalamander `.build/logs/redmonitor-debug-consumption.log`.
The canonical restore now uses a 16-character output directory key, retains the full fingerprint in the
identity JSON, and rejects a mismatched existing directory stamp. A fresh exact-pin nested restore is the
acceptance witness; developer-root success alone did not establish consumer relocatability.
