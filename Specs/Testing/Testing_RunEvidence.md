# Generated test-run evidence

Status: normative current tooling contract
Last reviewed: 2026-11-23

This contract owns what a RedMonitor build, test or validation run leaves behind and what that record proves.
The commands that produce it, and the scopes they select, are owned by [validation](Testing_Validation.md).

## Receipts and attempt records

The shared scoped runner owns reusable independent receipts under `.build/reports/scoped-tests/independent`.
Each executed independent command also records an immutable RedMonitor attempt under
`.build/validation-evidence/independent`. The latest-state index records that attempt's
started, failed or passed state and digest. On retry, exact independent success can be
reused through the engine and native gates still execute when selected. A failed attempt,
a changed source or a corrupt shared receipt cannot grant reuse.

Scoped native test calls keep their ordinary scenario output under `.build/test-runs` and
record a run through the pinned evidence module. Canonical per-scope reports appear in
`.build/reports` only after the requested work passes. Failed scoped runs retain their
failure state. Direct hosted regression retains its named scenario receipt and assertion
probe. The shared profile lease protects builds and tests across child processes.
Crash-probe dumps and markers stay in the corresponding local ".build/crash-probe-artifacts" run folder
outside the uploaded evidence. The ordinary scenario receipt records the dump hash.

Local SDK runtime results have role `LocalUnpinnedApplicationRuntimeResult`, bind the original build digest,
dependency and complete runtime-byte digest, and live only under `.build/local-sdk-test-runs`, outside hosted
`.build/test-runs` discovery. The reader rechecks all payload and SDK/source/engine inputs after child drain,
before a result can pass. Runtime, source or close failure retains a failed record and releases ownership.
Hosted/compiler-free requests, incomplete digest/profile requests and old partial build records refuse before
runtime launch. Local SDK results never satisfy pinned Full/PrePush, main, packaging or production gates;
their repository/production qualification flags stay false. Viewer/foreground/performance coverage keeps
its separately declared scope; these console results do not imply it.

Keep build and runtime results separate; cross-builds cannot close native ARM64 runtime. A successful
artifact identity is necessary for evidence reuse. Source/pin/binary/toolchain/environment/scenario must
all match; pending CI, private repair receipts and focused runs cannot be promoted to Full acceptance.

## Archive

Generated evidence stays under the repository `.build/`, ignored by Git, and normal builds never sweep it.
Reviewed evidence that a plan, contract or Done record cites is kept under `Measurements/`, one folder per topic
and date with a `README.md` that names the source commit, profile and scenario, and says what the packet does
and does not establish. Archived packets are history: they are never rewritten to match later code.
