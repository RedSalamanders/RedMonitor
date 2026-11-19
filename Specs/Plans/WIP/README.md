# Active work

Files in this directory are non-normative execution or decision records; current requirements stay in the owning
domain spec under `Specs/<Domain>/`. This index is routing only. Every direct plan in this directory is listed
exactly once, as `- **STATUS**: [Title](File.md) — purpose`. `ACTIVE` is executable work, `HOLD` paused work,
`DECISION` unresolved product intent, and `RETIRED` a bounded tombstone that names its retirement date, reason,
current owner, and a `git show` recovery command.

- **ACTIVE**: [RedMonitor extraction and Red-family adoption](RedMonitorExtraction_2026-10-21.md) — standalone
  implementation, RedSalamander cutover, settings reduction, three app adapters and qualification.

- **ACTIVE**: [Explicit state machines and lifetime safety](ExplicitStateMachines_2026-11-10.md) — plan only (code
  implementation not started) for `ColorTextView` presentation/capture, async file session generation, `Document`
  cache epochs and `EtwListener` phases without changing `Client.h`.

- **ACTIVE**: [Code conventions convergence](CodeConventionsConvergence_2026-11-19.md) — RedHome CV-6-08: one pull
  request per register row (device loss, COM pointers, window ownership, adapter selection, failure-report switch,
  replace sequence, resource-string gate, settings contract name).

Completed plans are listed in the [Done index](../Done/README.md).
