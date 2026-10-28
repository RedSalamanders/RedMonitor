# Validation and evidence

Use Test-Changes.ps1 -Explain and affected testing during edits; Full/PrePush explicitly account for
x64 Debug/Release/ASan runtime and six builds. validate.ps1 checks script syntax, links, pins, source
boundaries and required repository surfaces. format.ps1 -Check verifies native formatting.
Formatting prefers the discovered Visual Studio C++ Clang bundle over unrelated LLVM executables on PATH,
with standalone PATH LLVM supported when no bundle is installed. The command reports the executable/version
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

The imported MonitorTest flags cover diagnostics opt-in, scrollbar model, document batching/filtering,
retention, immutable snapshots, strict/bounded file read, atomic export/fault/cancel, clipboard rejection
without opening the clipboard, and bounded ETW consumer lifetime. test.ps1 supplies a unique repository-local
test root and never cleans existing data. A failed native process must produce a failed receipt.

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

Keep build and runtime results separate; cross-builds cannot close native ARM64 runtime. A successful
artifact identity is necessary for evidence reuse. Source/pin/binary/toolchain/environment/scenario must
all match; pending CI, private repair receipts and focused runs cannot be promoted to Full acceptance.

Release performance uses paired/alternating baseline and candidate on the same fixture and machine.
Record append/filter/retention/export snapshot latency, frame p95/p99, private bytes, working set,
handles, CPU, wakeups and event loss. An unpaired measurement is diagnostic only. Investigate repeatable
>5% regressions before advice; never silently change the baseline. Required viewer gates include WARP,
device loss and clean/dirty/hidden resource behavior. The WIP matrix owns remaining execution.

Full/PrePush also run real ETW roundtrips and contained production installer controls. The >2 GiB
file-size boundary fixture uses FSCTL_SET_SPARSE before extending its logical size, so retained
test evidence does not reserve gigabytes. A failed filesystem control fails the scenario.
Consumer local-client controls run with system-only PATH and require no Git/network or viewer.
