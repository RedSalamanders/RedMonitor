# Build and header-only consumption

RedMonitor is an independent EXE. Only this repository builds, tests and packages it.
Build with PowerShell 7 and discovered Visual Studio 2026 C++ tools, x64/ARM64 and
Debug/Release/ASan Debug, Unicode stdcpplatest and /W4 /WX /permissive- /sdl.
Pinned vcpkg and DxUi restores, outputs and exact source/profile receipts remain local under .build.
No RedSalamander Common.dll or sibling build is required.

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

Release packages include the full CRT/data/language/license closure plus Install-RedMonitor.ps1.
The installer validates every manifest entry and production metadata before atomic directory
replacement in a standard per-user or machine folder. Running installations block replacement;
no process is killed. Previous installations remain recoverable. Harness installation is confined
below source .build and never modifies real standard locations.

Viewer test hooks default on in Debug/ASan Debug and off in Release. The explicit ViewerTests mode
is receipt-bound. Release packaging refuses test-enabled builds. Diagnostic images carry the
RedSalamander.TestSurface=ENABLE_TESTS marker; native test executables have independent definitions.