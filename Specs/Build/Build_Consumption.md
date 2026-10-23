# Build and consumption

Build with PowerShell 7 and discovered Visual Studio 2026 C++ tools. Targets are x64/ARM64 and
Debug/Release/ASan Debug. Source is Unicode in stdcpplatest mode with /W4 /WX /permissive- /sdl.
ASan configurations require compiler instrumentation, matching runtime and a real detection probe.

`restore.ps1` restores the pinned vcpkg manifest/tool and exact DxUi lock into `.build`.
No source lookup falls back to Z:\src or another consumer. DxUi uses its public consumer imports,
one archive and isolated source/compiler/SDK/CRT fingerprint outputs. No consumer enumerates its sources.
The viewer support library is static; yyjson is linked statically through the windows-static-md triplets. Only the selected ASan runtime is staged application-local.

`build.ps1` builds RedMonitor.proj, which owns the viewer, model tests and four resource-only satellites.
Generated outputs stay under `.build/<platform>/<configuration>` and are never committed. Build receipts
bind source/dependency/profile/tool/artifact identities and never claim runtime execution.

Consumers pin RedMonitor by repository URL, exact 40-character commit and API revision. Restore rejects
dirty managed sources and mismatched pins. Headers come only from include/RedMonitor. Optional viewer
packaging carries the full reviewed closure: executable, satellites, schema, themes/notices and
ASan runtime where selected. Client SDK use does not require installing or starting the viewer.

RedSalamander initially uses thin compatibility build projects under Build, stages the pinned artifact
under its historical name and preserves installer IDs. Source ownership stays in this repository.
Independent app adapters and application qualification belong to their respective repositories.

Consumer SDK resolution and optional viewer staging are owned by Tools/Restore-Consumer.ps1, invoked from an exact clean managed checkout. Producer convenience headers and cross-process/runtime probes are described in [application adoption](../../docs/Consumers.md). Release packages include the architecture-matched app-local VC CRT, WIL/yyjson/DxUi notices and the existing resource/data closure.
