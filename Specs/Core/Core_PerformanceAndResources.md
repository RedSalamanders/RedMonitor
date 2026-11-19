# RedMonitor performance and resource contract

Status: current normative contract
Last reviewed: 2026-11-19

## Mandate

Performance and low resource consumption are primary RedMonitor requirements, not optional cleanup. Every design,
implementation, review, and validation change minimizes CPU time, memory, allocations, copies, synchronization, GPU
submissions, wake-ups, and loaded resources while preserving correctness, security, visual quality, and required
behavior.

When several correct designs exist, use the one with the lowest steady-state resource cost unless a measured result
or a materially simpler and safer implementation justifies another choice. An intentional regression is measured in
the affected configuration and justified in the owning contract or an active WIP plan.

"Zero CPU while idle" means RedMonitor owns no polling loop or periodic wake-up when no frame, input, I/O completion,
ETW batch, or state change is pending. Operating-system scheduling noise is outside this contract.

## Where the budgets live

Each bound is owned by the contract of the behavior it limits; this file does not restate the numbers.

| Budget or rule | Owner |
| --- | --- |
| Event queue, line and text retention, and search-match limits; incremental retention eviction | [Architecture](Core_Architecture.md) |
| Producer message bound, disabled-path cost, and session stop wait | [Transport](Core_Transport.md) |
| Filter changes without width remeasurement, sampled width measurement, tail-layout rendering in `WM_PAINT`, and ETW batch coalescing and repaint pacing | [Viewer](../UI/UI_Viewer.md) |
| Producer SDK: no worker or timer, no formatting or allocation on the disabled path | [Consumption](../Build/Build_Consumption.md#header-only-consumption) |

## Measurement

Paired Release measurement, the metrics it records, and the investigation rule for a repeatable regression are part
of [native and performance evidence](../Testing/Testing_Validation.md#native-and-performance-evidence). Receipts and
archived packets follow the [run-evidence contract](../Testing/Testing_RunEvidence.md). An unpaired measurement is
diagnostic only.
