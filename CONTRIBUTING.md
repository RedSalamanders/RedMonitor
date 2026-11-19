# Contributing

Read [AGENTS.md](AGENTS.md) first, then the [specification catalog](Specs/README.md) and the domain contract that
owns the behavior you change. Shared agent skills and cross-repository guidance live in
[RedHome](https://github.com/RedSalamanders/RedHome). Every RedSalamanders repository has this same file apart
from the last section.

- Work on a focused branch and open a pull request into `main`. Describe the observable change and how you
  validated it, and complete the pull request checklist.
- Keep durable requirements in the owning domain spec, not only in a plan, a pull request or a code comment.
  Multi-step work has one indexed plan under `Specs/Plans/WIP/`.
- Add one fragment under `Changes/`, as [its README](Changes/README.md) describes. Never edit `CHANGELOG.md`.
- Native builds are accepted only with zero warnings. Pull requests run compiler-free checks; native
  qualification runs on `main`, as the [Unified CI contract](Specs/Build/Build_UnifiedCI.md) states.
- Do not claim a performance result without paired evidence on the same machine and fixture.
- Screenshots come from the application's own deterministic, non-activating capture harness, never from a
  desktop screenshot. Tests that take real focus or the clipboard run only with the agreement of the person at
  the desktop.
- Update `docs/` when a change affects what a user sees, touches, configures or is prompted about.

## In this repository

- Validate with `./validate.ps1`, `./format.ps1 -Check` and `./Tools/Test-Changelog.ps1`. While editing, run
  `./Test-Changes.ps1 -Explain` and then the affected tests; Full and PrePush are explicit.
- RedMonitor is the producer of the diagnostics client. A change here never updates or qualifies a consumer; each
  consumer adopts a new client with `Update-RedMonitorClient.ps1` in its own repository, as the
  [consumer contract](Specs/Build/Build_Consumption.md#consumer-contract) states.
