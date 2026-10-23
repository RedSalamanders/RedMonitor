# RedMonitor

Independent Windows-native diagnostics viewer extracted from RedSalamander. Receives the compatible
Red-family TraceLogging stream, displays bounded colored logs, and opens/exports Unicode text files.
The view uses Direct2D/DirectWrite/D3D11 and an exact pinned DxUi library.

```powershell
./build.ps1 -Configuration Debug
./test.ps1 -Configuration Debug
./validate.ps1
./format.ps1 -Check
./package.ps1 -Configuration Release
```

Requires Windows 11 build 22000.2600+, Visual Studio 2026 Desktop C++ tools, a Windows SDK,
Git and PowerShell 7. The build discovers Visual Studio. x64 and ARM64 each support Debug,
Release and ASan Debug; cross-builds do not establish native ARM64 runtime support.

Source, dependencies and generated outputs stay independent of sibling repositories. Run the viewer
from `.build/<platform>/<configuration>/RedMonitor.exe`. ETW session permissions may require
Performance Log Users membership or elevation; opening text files does not require ETW access.

This is an active extraction. Legacy settings app ID, single-instance identity and resource-owner
names are retained for RedSalamander compatibility. Other applications still need their explicit
adoption changes. See [capabilities](capabilities.json), [usage](docs/README.md),
[specifications](Specs/README.md), and the [complete WIP plan](Specs/Plans/WIP/RedMonitorExtraction_2026-10-21.md).
MIT source origin and private support imports are recorded in [SourceImport](Specs/SourceImport/source-origin.json).

See [application adoption](docs/Consumers.md) for the labelled SDK, optional viewer and consumer validation contracts.
