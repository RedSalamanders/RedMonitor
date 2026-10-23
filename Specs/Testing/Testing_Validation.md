# Validation and evidence

Use Test-Changes.ps1 -Explain and affected testing during edits; Full/PrePush explicitly account for
x64 Debug/Release/ASan runtime and six builds. validate.ps1 checks script syntax, links, pins, source
boundaries and required repository surfaces. format.ps1 -Check verifies native formatting.

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
