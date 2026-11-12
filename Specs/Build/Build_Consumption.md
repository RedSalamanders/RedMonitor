# Build and header-only consumption

RedMonitor is an independent EXE. Only this repository builds, tests and packages it.
Build with PowerShell 7 and discovered Visual Studio 2026 C++ tools, x64/ARM64 and
Debug/Release/ASan Debug, Unicode stdcpplatest and /Wall with /WX disabled, /permissive- /sdl.
Pinned vcpkg and DxUi restores, outputs and exact source/profile receipts remain local under .build.
No RedSalamander Common.dll or sibling build is required.

The selected app package include directory is an `ExternalIncludePath` MSBuild property,
so the actual compiler classifies vcpkg headers as external in both viewer and support
projects, including isolated local SDK dependencies. It is not a per-source item metadata
field. First-party diagnostics and the zero-warning acceptance check remain enforced.

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
files and ignored generated caches (including `.build`, `.vs` and `.ci-engine`) do not enter the product file inventory; the actual engine is bound separately below. Reparse source
paths, failed Git inventories and unreadable inputs fail closed. Build, test and package commands share
this implementation. Older receipts require a new build after an identity algorithm change.

The snapshot also binds the actual ignored CI engine through the shared pinned-input
reader. Its separate `EngineInputsIdentity` is included in the source digest, without
adding fictional product file rows. Missing, dirty, foreign or wrong-pin engines fail
before reuse. Generated engine output is excluded and Windows casing aliases preserve
the same physical checkout identity.

An actual source change during compilation still prevents receipt publication. The error lists changed
paths and retains before/after source snapshots beneath the selected profile output for diagnosis.
Compiler success alone never establishes runtime or Full qualification.

MSBuild runs through the exact pinned shared engine's `Invoke-CiNativeCommand`.
Its child PowerShell host assigns a fresh private MSVC metadata-service endpoint
without changing the calling process's environment or location. Output remains live,
arguments remain literal, and the original native exit code feeds the existing
zero-warning, source and receipt gates. Compiler/linker switches and runtime ownership
are unchanged. This keeps concurrent owned builds from sharing a metadata service
whose lifetime can end when one build retires. Restore `.ci-engine` at the exact
`.ci/project.json` engine commit before local native builds, as hosted CI already does.

## Explicit pinned Release SDK inputs

`build.ps1 -Configuration Release -DxUiSdkInputDescriptor <absolute .build descriptor>` selects the shared
engine's local pinned SDK recipe. The independent descriptor lives below this repository's `.build`, outside
the immutable byte store. It names existing full canonical source/tooling/storage-engine checkouts, the exact
lock/API/platform and an independently retained manifest SHA-256. The pinned shared controller checks raw
checkout bytes before importing producer tools, independently acquires the complete native SDK input key,
verifies every stored byte and holds its reader lease through MSBuild. The existing lock is never advanced.

Only Release/MD/stdcpplatest/enabled-annotation/full-LTCG SDK inputs are supported. Debug/ASan use the existing
source recipe. Exact misses fall back to source restore/build; malformed, changed or incompatible inputs fail.
The SDK recipe imports packaged public headers/library/compiler-PDB/integration policy and adds no source
DxUi project reference. MSBuild checks the actual live parent reader handle, project, payload and profile
before compilation. A leftover witness or stale property file cannot authorize later direct MSBuild use.
Per-translation-unit definitions and effective metadata reject custom iterator-layout macros, packing,
wchar_t and calling-convention changes. Opaque compiler switches cannot override these settings or undefine
the required profile macros. Unsupported ABI variants must use the governed source recipe.

All existing product warning/error, version/test-surface, source-change and artifact checks remain. SDK close
must recheck inputs/bytes successfully before a build receipt is published. Its `dxuiRecipe` records the actual
`PinnedReleaseSdkV1` key, manifest, complete native identity and storage-engine identity; this is distinct from
the source wrapper recipe and is never a product test verdict. Default builds retain their source recipe.

The separately authenticated `HostedQualifiedDependencyInput` descriptor selects
`PinnedQualifiedReleaseSdkV2`. It retains the original producer key/manifest and
SDK receipt, checks the consumer's actual complete tool/header/library byte
reference, and requires its selected native MSBuild, per-project tool/search
settings and per-file ABI profile to match the live reader. It does not recompute
the producer's checkout-bound v1 environment recipe in the application. Open and
close reauthenticate the retained original archive and input bytes. Unknown SDK
recipes cannot be packaged. Live hosted-origin acceptance is a separate gate
from controlled-origin local application validation.

`package.ps1 -DxUiSdkInputDescriptor <descriptor>` reopens the same key/manifest when the build used SDK
inputs and copies the complete notices from that verified payload under a reader lease. Missing or another
SDK refuses packaging. Original source builds preserve their existing notice closure. Runtime, extraction,
architecture, sanitizer, performance and Full qualification remain required under their owning contracts.
Hosted artifact authentication and automatic cross-repository SDK selection are separate rollout work.
Ordinary Debug enables incremental linking to match the pinned DxUi library's Edit and Continue
objects. Release and ASan Debug retain non-incremental linking. A linker compatibility warning is
a failed build, not a warning to suppress in the success summary.

## Header-only consumption

The explicit Tools/Build-LocalSdkCandidate.ps1 command consumes a frozen local-only SDK descriptor and its
independent SHA-256 without changing the managed lock. It builds the real viewer project and its support
archive into a fresh operation below .build/local-unpinned. Both projects import the existing live local
SDK/output guard; the support archive still does not link a second DxUi library. The final application link
must name the held immutable archive. Ordinary source, pinned SDK, custom measurement and production roles
retain their existing behavior.

App dependency restoration for this role uses .build/local-sdk-dependencies, never ordinary profile package
inputs. Same-platform local operations hold their dedicated native/dependency lease. The local cache's shared
bootstrap/restore uses a separate lease, released before native compilation; different platforms can compile
independently. Failed operations retain diagnostics. The local build record grants no runtime, test,
repository, native-platform, production or publication acceptance.

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
The license closure carries the pinned DxUi license, its third-party notices and the notices of
components compiled into DxUi.lib, beside the WIL and yyjson copyrights.
The installer validates every manifest entry and production metadata before atomic directory
replacement in a standard per-user or machine folder. Running installations block replacement;
no process is killed. Previous installations remain recoverable. Harness installation is confined
below source .build and never modifies real standard locations.

## Viewer test hooks

Viewer test hooks default on in Debug/ASan Debug and off in Release. The explicit ViewerTests mode
is receipt-bound. Release packaging refuses test-enabled builds. Diagnostic images carry the
RedSalamander.TestSurface=ENABLE_TESTS marker; native test executables have independent definitions.
