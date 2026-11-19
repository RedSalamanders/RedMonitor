# Generated test-run evidence

Status: normative current tooling contract
Last reviewed: 2026-11-19

This contract owns what a RedMonitor build, test or validation run leaves behind and what that record proves.
The commands that produce it, and the scopes they select, are owned by [validation](Testing_Validation.md).

## Receipts and attempt records

A later native failure preserves the original successful attempt bytes. An identical
retry may reuse those independent checks; it still executes all requested native,
live ETW, cross-build, packaging and installation obligations. `-Force` reruns the
independent checks. Before execution, the latest-state index is marked started;
failure or interruption cannot fall back to an older green attempt. Failed or
input-mutating checks stop before native work. Corrupt/missing/mismatched evidence
is never a pass. Attempts are create-only records beneath `.build/validation-evidence/independent`,
with a bounded digest-checked latest-state index. The independent operation lease
does not cover later native execution. Final source drift refuses current-tree
success. No independent receipt grants native or repository-wide qualification.

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
