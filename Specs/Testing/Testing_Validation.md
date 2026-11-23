# Validation and evidence

Local source snapshots and build receipts bind the actual ignored `.ci-engine`
through the shared `Get-CiPinnedEngineInputsIdentity`. The generated checkout must
be ordinary, independent, clean and at `.ci/project.json`'s exact pin. Fresh raw
engine bytes participate; generated engine `.build` output does not. This input
is separate from product file/affected discovery, grants no qualification or CI
delegation, and preserves the current local and main gates.

## Scoped iteration

The exact engine pin runs the public `Test-Changes.ps1` shim. `Tests/test-scopes.json` owns
the affected rules, native inventory, scope commands and profiles. The engine compares the
local branch merge base and includes staged, working, deleted, renamed and untracked paths.
An unavailable comparison requires a valid base or an explicit Full run. No network fetch
is implicit. An ordinary affected success may seed a 24-hour profile baseline.

Owned prose selects Validation, Format and Tooling. Scenario data, unknown inputs, schemas
and build code also select Regression. The independent run records immutable attempts and
verifies the actual formatter, tools, source and environment. The shared runner reuses
exact completed independent receipts and owns the per-profile build and iteration receipts.
An empty plan reports `NOTHING_SELECTED`. Scoped success reports `repository NOT_EVALUATED`.

Use `./Test-Changes.ps1 -Explain` to review the plan. `-Mode Full` covers one profile.
`-Mode PrePush` covers x64 Debug, Release and ASan Debug runtime plus three ARM64
cross-builds. Full and PrePush select LiveEtw for each runnable profile. Release also selects
ContainedInstallation after the ordinary regression and live transport checks. Direct
`test.ps1 -IncludeLiveEtw` continues to require that roundtrip explicitly. Native ARM64
runtime requires its own matching host. The hosted six-scenario regression and both production
lanes retain their own evidence and authorization.

The product test command retains the exact direct build receipt and output checks. The
shared profile lease coordinates scoped builds and tests, and individual artifact
operations keep their existing lock. Details of the attempt records are in the
[run-evidence contract](Testing_RunEvidence.md).

`test.ps1` also accepts an explicit local SDK Release record and independently retained SHA-256 through
`-LocalSdkBuildReceipt` and `-LocalSdkBuildSha256`, with `-SkipBuild`. The shared live runtime reader must
accept the original complete output catalog, source/engine/dependency/API/ABI and native architecture;
the actual viewer must carry its ENABLE_TESTS resource marker. The same declared Release console scenarios,
including optional explicitly required live ETW and the installed-viewer metadata check, run against those
held binaries. No ordinary build is invoked or ordinary build receipt created. Output operations remain
exclusive through the shared candidate lease; unrelated ordinary profiles need no lock for this route.

`Tests/Tooling.Tests.ScopedTesting.ps1` exercises the real scoped shim and native scope routing in
owned Git and recording fixtures. It covers prose, runtime data, malformed fragments, independent
attempt retention, live ETW and Release installation selection, and child failures. The shared
engine tests cover Git changes and receipt corruption. The routing fixtures establish orchestration.

`Tests/Tooling.Tests.Build.ps1`, included by the tooling suite, uses fresh owned `.build` Git fixtures
to check receipt identity against ignored CI cache/Git metadata churn, timestamp-only changes, tracked
and untracked edits/additions/deletions/renames, tracked ignored inputs and Unicode paths. It also checks
the ASCII banner, color/plain modes, safe launch links and refusal to print success for warnings/errors.
These controls do not invoke a compiler, launch an application or establish native runtime qualification.

`Tests/Tooling.Tests.Vcpkg.ps1`, included by the tooling suite, runs `Build/VcpkgToolCheckout.psm1`
against an owned offline `file://` registry fixture: fresh, repeated, completing a partial shallow
checkout and refusing a foreign origin or a non-Git path. Each prepared checkout extracts an older tree
the way vcpkg does, in an environment that holds only `GIT_INDEX_FILE`, with lazy fetch disabled; the
unprepared partial checkout must fail that extraction. It also checks the complete clone of
`vcpkg-install.ps1`, the prepare-before-install order in `restore-dxui.ps1`, and that the module is ASCII
and parses in Windows PowerShell 5.1. It restores no package and runs no compiler.

`Tests/Test-SdkInputs.Native.ps1 -Descriptor <absolute .build descriptor>` is an explicit MSBuild-dependent
SDK policy control, excluded from compiler-free PR tooling. It holds the actual verified SDK reader while
executing the actual imported admission targets. The accepted profile passes; incompatible CRT, language,
global/per-file ASan, Debug/STL/vector/string annotations, missing NDEBUG and opaque ABI overrides refuse.
After close, the same direct MSBuild settings refuse. Each case retains its log and a separate policy receipt.
Expected negative native exits reset to zero only after every control and integrity close succeeds; exceptions
remain fatal. These controls do not replace application build/runtime, architecture or performance acceptance.

Formatting prefers the repository's exact pinned install, followed by the discovered Visual Studio C++
Clang bundle and then standalone PATH LLVM. Every selected tool must match the pin. The command reports the executable/version
and parses the unchanged repository style before checking or rewriting source. An incompatible formatter
fails with its identity; CI must install compatible tools rather than weakening formatting policy.

## Agent guidance checks

`validate-skills.ps1` checks this repository's skill packages, guidance, instruction pointers and plan indexes
through the pinned CI engine. The engine's Agent guidance contract in `Specs/ProjectCommands.md` owns rules G1
through G13 and their fixture coverage. RedMonitor declares its root guidance in `.agents/guidance.json`.

`validate.ps1` calls the same entry point and checks the project's source, dependency pins and ordinary
documentation. The product documentation checker resolves declared local links and refuses missing or out-of-repository
targets. It accepts fenced illustrations and ordinary Markdown links with encoded paths, balanced parentheses and titles.

`Tests/Tooling.Tests.DocumentationValidation.ps1` exercises the actual full validator against an owned fixture,
checking the documentation contract, propagation of guidance errors and read-only behavior.

## Native and performance evidence

Formatting: the root `.clang-format` is the one style. `format.ps1` formats, and `format.ps1 -Check`
verifies without writing and lists every file that needs formatting. Both take clang-format from
`Install-CiFormatter` in the pinned `.ci-engine`, which installs the build that the engine's
`Policy/clang-format.json` pins (22.1.3 today) under `.build/shared-format` and verifies its SHA-256 and
version; no Visual Studio, `PATH` or repository-pinned formatter is used. Both cover the files CI formats:
`.c`, `.cc`, `.cpp`, `.cxx`, `.h`, `.hh`, `.hpp` and `.hxx` files under the `formatRoots` of
`.ci/project.json` that its `formatExclude` does not match. Pull-request checks run the same formatter over
the files the pull request changes, or over every file when `.clang-format` or `.clang-format-ignore`
changes; drift fails the check and retains the patch. The manual `Commit PR formatting` workflow commits
that formatting to an open same-repository pull request with an ordinary push and requests fresh checks for
the new head.

The imported MonitorTest flags cover diagnostics opt-in, scrollbar model, document batching/filtering,
non-dirtying filter changes, bounded visible-range queries, incremental retention eviction (offset deque,
dirty range, visible-line shifting, and bounded width-candidate sampling), filtered and unfiltered tail-text
assembly, in-place search/colorize helpers, immutable snapshots, strict/bounded file read, atomic
export/fault/cancel, clipboard rejection without opening the clipboard, and bounded ETW consumer lifetime.
test.ps1 supplies a unique repository-local test root and never cleans existing data. A failed native process
must produce a failed receipt.

The standalone project owns the former consumer's viewer coverage obligations: ETW provider
compatibility, self-originated event suppression, runtime diagnostic gating, bounded ingestion/display
and stable ColorTextView interaction. Preserve decoded expansion limits, split UTF-8/UTF-16 boundaries,
malformed/truncated input, mid-decode cancellation, move-publication without UI reparsing, repeated
search-cap eviction/refill and F3 order, Show IDs coordinate reset/rebuild, and exact canonical
read/export/read records including empty, terminal, blank, Unicode and line-budget boundaries.
Cover start-snapshot asynchronous export across later append/retention/clear/replacement,
zero-text-copy immutable capture, open/save thread-admission rollback and retry, cancellation/fault
target preservation, bounded worker close, registered payload drain, three-size/five-repeat Release
scaling and selftest fixture cleanup. Richer clipboard formats and additional filter semantics require
an explicit RedMonitor decision. These obligations are distinct from the implemented console subset
and the still-open viewer qualification gates.

User strings live in the `STRINGTABLE` of `src/RedMonitor.rc` and its four satellites under `src/Lang/`.
`Tests/Tooling.Tests.ResourceStrings.ps1`, part of the tooling tests, checks them without native compilation: every
string id is defined in `src/resource.h` and every `IDS_` id the viewer source uses has a base string; a placeholder is
positional (`{0}`, `{1:...}`) with no gap in its indexes, never bare `{}`, `{:...}` or a printf token; and every
satellite string has a base string with the same placeholders.

Headless console cases do not take desktop focus. UI keyboard/clipboard/IME/AT fixtures require agreement
to the time and a desktop lease with verified restoration. Screenshots are deterministic application
harness captures with invented data and source/build/scenario provenance; never desktop screenshots.

Release performance uses paired/alternating baseline and candidate on the same fixture and machine.
Record append/filter/retention/export snapshot latency, frame p95/p99, private bytes, working set,
handles, CPU, wakeups and event loss. An unpaired measurement is diagnostic only. Investigate repeatable
>5% regressions before advice; never silently change the baseline. Required viewer gates include WARP,
device loss and clean/dirty/hidden resource behavior. The WIP matrix owns remaining execution.

Full and PrePush run real ETW roundtrips on the current native host. The Release profile also runs contained production installer controls. The >2 GiB
file-size boundary fixture uses FSCTL_SET_SPARSE before extending its logical size, so retained
test evidence does not reserve gigabytes. A failed filesystem control fails the scenario.
Consumer local-client controls run with system-only PATH and require no Git/network or viewer.
