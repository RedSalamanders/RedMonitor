# Validation and evidence

Local source snapshots and build receipts bind the actual ignored `.ci-engine`
through the shared `Get-CiPinnedEngineInputsIdentity`. The generated checkout must
be ordinary, independent, clean and at `.ci/project.json`'s exact pin. Fresh raw
engine bytes participate; generated engine `.build` output does not. This input
is separate from product file/affected discovery, grants no qualification or CI
delegation, and preserves the current local and main gates.

`Test-Changes.ps1` records Validation, Format and Tooling separately immediately
after each command succeeds and the original source/tool/environment identity is
reverified. That identity includes full product source bytes, actual pinned engine
inputs, selected formatter/Git/PowerShell host and automation-assembly bytes, runtime,
OS, architecture and the declared discovery/CI environment. The formatter in that
identity is the one `format.ps1` uses, from the same helper (`Get-RedMonitorClangFormat`).

Receipts, independent attempt records and their retention are owned by the
[run-evidence contract](Testing_RunEvidence.md).

Use Test-Changes.ps1 -Explain and affected testing during edits; Full/PrePush explicitly account for
x64 Debug/Release/ASan runtime and six builds. validate.ps1 checks script syntax, links, pins, source
boundaries and required repository surfaces. format.ps1 -Check verifies native formatting.

Affected selection compares the branch merge base with origin/main and independently includes committed,
staged, working, deleted, rename-side and untracked paths. A missing comparison retains Debug work. Only
owned Markdown guides and prose in Specs, docs, Changes and agent skill folders omit native execution;
runtime/test/fixture/schema/build inputs and unknown paths remain native. Prose still runs real changelog
validation, validate.ps1, formatting and all tooling controls. Malformed fragments or nonzero child exits fail.
Source bytes must remain unchanged across planning/independent validation before prose success is reported.
No-work reports NOTHING_SELECTED; prose reports PROSE_CHECKS_PASSED; neither qualifies the repository.
Full/PrePush retain all local native profiles, live ETW, ARM64 cross-builds and contained installation controls.
They never claim native ARM64 execution or separate manual/viewer/performance gates.

`test.ps1` also accepts an explicit local SDK Release record and independently retained SHA-256 through
`-LocalSdkBuildReceipt` and `-LocalSdkBuildSha256`, with `-SkipBuild`. The shared live runtime reader must
accept the original complete output catalog, source/engine/dependency/API/ABI and native architecture;
the actual viewer must carry its ENABLE_TESTS resource marker. The same declared Release console scenarios,
including optional explicitly required live ETW and the installed-viewer metadata check, run against those
held binaries. No ordinary build is invoked or ordinary build receipt created. Output operations remain
exclusive through the shared candidate lease; unrelated ordinary profiles need no lock for this route.

Tests/Tooling.Tests.ScopedTesting.ps1 exercises the actual public wrapper in owned Git/child-process fixtures,
using recording native entrypoints. It covers cumulative code followed by docs, staged reversals, Unicode,
rename sides, missing bases, malformed fragments, nonzero command exits, source mutation and retained Full/
PrePush obligations. These routing fixtures do not compile or qualify a native application.

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

`validate.ps1` uses `Build/AgentGuidance.psm1` for skill structure, declared local references and active-plan
index checks. These checks are read-only and dependency-free. They do not execute skill examples or establish
instruction quality, command binding, policy consistency, native behavior or qualification.

The repository's supported header format has exactly one single-line `name` and `description`, using plain,
single-quoted or JSON-compatible double-quoted string scalars between `---` delimiters. Blank lines and standalone
comments are supported. Folder/name mismatch, duplicate keys, empty descriptions/bodies and unsupported header
syntax fail. Quote numeric/boolean/date-looking text (including hex, infinity and exponent forms) when it is
intended as a description string. This is a bounded repository format, not a general YAML parser; extend its grammar and tests before
introducing optional keys or multiline metadata. Declared inline Markdown links in skill packages, including
supporting Markdown files, must resolve within this repository without reparse files or ancestors. Local absolute
paths and file URIs are validated as local paths; URI-looking drive names cannot bypass the check. Network URLs,
protocol-relative external URLs and section-only links are not fetched. Balanced parentheses in destinations are
supported; fenced illustrations and inline-code pseudo-links are not treated as required resources. Backtick prose
paths and target anchors are not covered by this check. Full/collapsed reference links resolve normalized,
case-insensitive labels and check their definition destinations; the first definition wins, and an undefined
explicit reference label fails. Full/collapsed references require adjacent brackets; space, tab or newline
separation leaves independent shortcut/text spans. A bracket-only shortcut without a definition remains ordinary text.
The bounded inline-code scanner ends at blank paragraphs (including whitespace-only blank lines); soft line
breaks within a paragraph remain supported. Single-line titles may use single quotes, double quotes or
parentheses, and a reference destination may continue onto the immediately following line. These forms do not
claim a general CommonMark parser. File URI escapes are decoded once, preserving encoded `#` and literal
percent sequences in filenames. Quoted ISO dates/timestamps retain their exact string text rather than receiving
automatic date conversion. Hidden direct skill directories receive the same metadata and package checks.
Temporal type detection matches a complete scalar. Plain date-prefixed prose such as
`2026-10-28 migration guidance` remains a string; complete unquoted dates/timestamps still require quotes.
Backtick fence opening info cannot contain backticks: line-leading same-line code such as
`` ```literal``` `` remains inline prose; tilde-fence info may contain backticks.
Recognized fence openers and closers have zero to three leading spaces before the optional list marker.
Four-space or tab indentation does not open or close a fence in this bounded scanner.

The public `validate.ps1` documentation check reuses this same Markdown/path helper. It rejects reparse files and
ancestors before source reads, parsing or traversal; skill headers must not be opened by an earlier, weaker reader.

Every direct WIP plan other than README must have exactly one active-index link. Indexed local targets must
exist. Count actual inline or resolved full/collapsed/shortcut reference uses, not definition declarations:
a definition alone is not an index link, two uses of one definition are two links, and an unused second definition
does not duplicate an actual use. Validate all declared destinations separately, including unused definitions.
A completed plan may move to Done after its own implementation/test/docs gates close; update the active
and Done indexes and inbound links in that change. No particular unfinished plan filename is a permanent
validation prerequisite. The ordinary link check still rejects references left pointing at the old location.

`Tests/Tooling.Tests.AgentGuidance.ps1`, included by `Tests/Tooling.Tests.ps1`, exercises malformed/duplicate
headers, wrong names, missing entrypoints/contracts, supporting reference boundaries and actual WIP-to-Done
movement. Snapshots check that accepted and refused validation leave fixture bytes, write times and directory
contents unchanged. Fixtures are fresh, retained, caller-owned directories beneath `.build/agent-guidance-tests`.
Checkout-shaped controls run the actual public entrypoint for encoded paths, fenced/inline examples, balanced
destinations, local URI boundaries and reparse headers. Synthetic link targets stay inside the same owned fixture;
hosts without symbolic-link privilege report those controls as skipped, not passed.

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

Headless console cases do not take desktop focus. UI keyboard/clipboard/IME/AT fixtures require agreement
to the time and a desktop lease with verified restoration. Screenshots are deterministic application
harness captures with invented data and source/build/scenario provenance; never desktop screenshots.

Release performance uses paired/alternating baseline and candidate on the same fixture and machine.
Record append/filter/retention/export snapshot latency, frame p95/p99, private bytes, working set,
handles, CPU, wakeups and event loss. An unpaired measurement is diagnostic only. Investigate repeatable
>5% regressions before advice; never silently change the baseline. Required viewer gates include WARP,
device loss and clean/dirty/hidden resource behavior. The WIP matrix owns remaining execution.

Full/PrePush also run real ETW roundtrips and contained production installer controls. The >2 GiB
file-size boundary fixture uses FSCTL_SET_SPARSE before extending its logical size, so retained
test evidence does not reserve gigabytes. A failed filesystem control fails the scenario.
Consumer local-client controls run with system-only PATH and require no Git/network or viewer.
