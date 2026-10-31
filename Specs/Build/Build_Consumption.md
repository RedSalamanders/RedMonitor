# Build and header-only consumption

RedMonitor is an independent EXE. Only this repository builds, tests and packages it.
Build with PowerShell 7 and discovered Visual Studio 2026 C++ tools, x64/ARM64 and
Debug/Release/ASan Debug, Unicode stdcpplatest and /W4 /WX /permissive- /sdl.
Pinned vcpkg and DxUi restores, outputs and exact source/profile receipts remain local under .build.
No RedSalamander Common.dll or sibling build is required.

## Command-line build output and source receipts

`build.ps1` prints the RedMonitor ASCII wordmark and target profile before restore/compilation.
Interactive terminals receive color; redirected output retains readable text, and `NO_COLOR` disables
automatic color. The shared Red-family `Build/BuildConsole.psm1` formats the final green summary with
entrypoint elapsed time, zero-warning/error status, artifact/log/receipt paths and a quoted PowerShell
launch command. Supported terminals receive local file hyperlinks; ARM64 outputs on x64 are labelled
for execution on ARM64. Printing a command or hyperlink never launches an application.
The independent helper's [import provenance](../SourceImport/build-console-origin.json) records its source.

Success is published only after MSBuild exits successfully, its log has zero warnings and errors,
viewer version/test metadata matches, the source snapshot still matches and the receipt has been written.
The Git checkout is required even with `-SkipRestore`. Source identity uses NUL-delimited UTF-8
`git ls-files --cached --others --exclude-standard` paths in ordinal order, binding each path and current
SHA-256 file content. Missing tracked files have an explicit marker. Tracked ignored files remain inputs;
non-ignored untracked additions, edits, deletions and renames change identity. Timestamps, Git administrative
files and ignored generated caches (including `.build`, `.vs` and `.ci-engine`) do not. Reparse source
paths, failed Git inventories and unreadable inputs fail closed. Build, test and package commands share
this implementation. Older receipts require a new build after an identity algorithm change.

An actual source change during compilation still prevents receipt publication. The error lists changed
paths and retains before/after source snapshots beneath the selected profile output for diagnosis.
Compiler success alone never establishes runtime or Full qualification.
Ordinary Debug enables incremental linking to match the pinned DxUi library's Edit and Continue
objects. Release and ASan Debug retain non-incremental linking. A linker compatibility warning is
a failed build, not a warning to suppress in the success summary.

## Header-only consumption

Consumers vendor only `include/RedMonitor/Client.h` and `LICENSE.txt` in ThirdParty/RedMonitor.
Their lock records the immutable upstream commit, API revision and SHA-256 of each Git blob.
The vendored subtree uses `-text` to preserve exact Git bytes on Windows. Ordinary builds verify
local files without Git, network, a RedMonitor checkout, library or executable. Only the explicit
Update-RedMonitorClient tool fetches a newly reviewed header/license. ClientSdk/ tools are the
canonical source of the consumer update/verify adapters.

The single header owns normalized counted UTF-16/strict UTF-8 messages, app labels, severity and
PID/TID/FILETIME metadata. Disabled writes return before conversion, formatting or heap work.
An existing module provider can call WriteNormalizedEvent without changing registration or ABI.
Other consumers own one Application provider, created before workers and destroyed after teardown.
Windows SDK and the consumers' existing WIL dependency provide Windows resource ownership.

The helper is optional at runtime. Installed production Release images are discovered only at
LocalAppData/Programs/RedMonitor/RedMonitor.exe and ProgramFiles/RedMonitor/RedMonitor.exe.
The single header checks product/version flags, rejecting diagnostic/test-enabled builds. Explicit
--redmonitor launches through a fixed absolute path, without a shell or wait. Debug bare startup may
queue the same best-effort launch; Release, help, tests and synthetic probes never auto-launch it.
Missing helpers and ETW privilege denial cannot block normal application work. Applications never
own the independent helper's teardown and never package or rebuild its executable.

## Installation and packaging

Release packages include the full CRT/data/language/license closure plus Install-RedMonitor.ps1.
The installer validates every manifest entry and production metadata before atomic directory
replacement in a standard per-user or machine folder. Running installations block replacement;
no process is killed. Previous installations remain recoverable. Harness installation is confined
below source .build and never modifies real standard locations.

## Viewer test hooks

Viewer test hooks default on in Debug/ASan Debug and off in Release. The explicit ViewerTests mode
is receipt-bound. Release packaging refuses test-enabled builds. Diagnostic images carry the
RedSalamander.TestSurface=ENABLE_TESTS marker; native test executables have independent definitions.
