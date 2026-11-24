# RedMonitor specification authority and workflow

Status: current normative repository policy
Last reviewed: 2026-11-19

## Purpose

This catalog defines where RedMonitor requirements live and how specifications, plans, implementation, and
validation stay consistent. Location alone does not make a document authoritative.

## Authority classes

| Class | Location | Meaning |
| --- | --- | --- |
| Normative domain contract | `Specs/<Domain>/*.md` | Current intended behavior, ownership boundaries, compatibility constraints, and required validation. |
| Normative repository policy | `AGENTS.md` and this file | Cross-domain engineering and closeout workflow. |
| Machine contract | Schemas, manifests, project files, resources, and lock data | Exact data that the build, the application, or its tools consume. Link to it instead of copying it into prose. |
| Active plan | `Specs/Plans/WIP/*.md`, excluding its `README.md` | Non-normative proposal, decision, or execution record for unfinished work. |
| Active-plan index | `Specs/Plans/WIP/README.md` | Routing only; it does not define behavior. |
| Historical plan | `Specs/Plans/Done/*.md`, excluding its `README.md` | Completed sequencing, rationale, and evidence; never the authority for current behavior. |
| Run evidence | `Measurements/` | Reviewed evidence packets under the [run-evidence contract](Testing/Testing_RunEvidence.md). A green historical run is not proof for changed code. |
| End-user documentation | `docs/` | The user guide. It agrees with the contracts and is updated when an end-user scenario changes. It is not an authority for behavior and holds no measurement receipts, checkpoints, generated reports, or WIP notes. |
| Implementation and tests | Source folders, `Tests/`, and root scripts | Executable behavior and evidence that must agree with the owning contract. Tests are evidence, not permission to ignore a contract. |
| Capability record | `capabilities.json` | What is implemented today and which qualification is still pending. An intended requirement is not evidence that the feature works. |
| Source provenance | `Specs/SourceImport/` | The recorded MIT origin of imported source and private support code. |

## Reconciliation rule

Neither prose nor implementation wins only because of its file type. When a spec, implementation, test, manifest,
or document disagrees:

1. Identify the owning normative domain contract and every affected consumer.
2. Inspect current runtime behavior, implementation anchors, tests, and relevant historical plans.
3. Correct the stale side when intent is mechanically clear.
4. Preserve the safe current behavior and create a `DECISION` WIP plan when product intent is unresolved.
5. Update the contract, implementation, tests, and `docs/` together when behavior changes.

## Change workflow

1. Read this catalog and the owning domain spec before changing durable behavior.
2. For a small, settled change, update the contract, implementation, and validation directly in one change.
3. For multi-step, risky, or undecided work, create one plan under `Specs/Plans/WIP/` that names the domain specs
   it expects to change, and add it to the [WIP index](Plans/WIP/README.md). When the index names a single current
   plan, add new in-scope work there instead.
4. A WIP plan is an execution aid only; it cannot override a current contract.
5. Run the validation that the owning spec names and the commands under
   [Specification validation](#specification-validation).
6. Before closeout, merge every durable requirement discovered during the work into the owning domain spec.
7. When the finished change affects an end-user scenario, anything a person using the product sees, touches,
   configures, or is prompted about, update `docs/` in the same closeout.
8. Only when every claimed implementation, test, and documentation obligation is closed, move the plan to
   `Specs/Plans/Done/`, add it to the [Done index](Plans/Done/README.md), remove its WIP row, and update inbound
   links, all in the same change. A completed plan never stays under WIP.
9. Record the change as one fragment under `Changes/`, as the [Changes workflow](Core/Core_Changes.md) states;
   never edit `CHANGELOG.md`.

If a behavior has no owning domain spec yet, create that spec in the first change that makes the behavior durable.

## Naming

- Domain specs: `<Domain>/<Domain>_<Title>.md`, without spaces.
- Plans, decision records, and RFCs: `<Title>_<yyyy-mm-dd>.md`, dated the day the plan was created. A plan keeps
  its name when it moves to Done.
- Index rows: a bullet that links the plan's title to its file and ends with an em dash and its purpose, opening
  with the bold status and a colon (`- **ACTIVE**:`) in the WIP index and without a status in the Done index.

## Domain entry points

| Domain | Start with |
| --- | --- |
| Source boundaries, compatibility, the log document, and file open and export | [Core/Core_Architecture.md](Core/Core_Architecture.md) |
| Settings files and location, schema, unusable-file recovery, and save | [Core/Core_Settings.md](Core/Core_Settings.md) |
| Local crash reporting, restart notice, and retention | [Core/Core_CrashHandling.md](Core/Core_CrashHandling.md) |
| ETW schema, the producer client, and session lifetime | [Core/Core_Transport.md](Core/Core_Transport.md) |
| Performance and resource consumption | [Core/Core_PerformanceAndResources.md](Core/Core_PerformanceAndResources.md) |
| The viewer window: rendering, filtering, and UI-thread publication | [UI/UI_Viewer.md](UI/UI_Viewer.md) |
| Build, exact client pins, standalone installation, and the consumer contract | [Build/Build_Consumption.md](Build/Build_Consumption.md) |
| Native, tooling, and performance validation | [Testing/Testing_Validation.md](Testing/Testing_Validation.md) |
| Run receipts and the evidence archive | [Testing/Testing_RunEvidence.md](Testing/Testing_RunEvidence.md) |
| End-user guide | [../docs/README.md](../docs/README.md) |

## Shared contracts

These files have the same role in every RedSalamanders repository:

- The [Changes workflow](Core/Core_Changes.md) owns fragment format, validation, and the fold of merged fragments
  into `CHANGELOG.md` on the default branch.
- The [Unified CI contract](Build/Build_UnifiedCI.md) owns how this repository adopts the shared CI engine.
- The [performance and resource contract](Core/Core_PerformanceAndResources.md) owns the performance mandate;
  measurement procedure stays under `Testing/`.
- The [run-evidence contract](Testing/Testing_RunEvidence.md) owns receipts and the `Measurements/` archive.
- RedMonitor is the producer of the diagnostics client. Its
  [consumer contract](Build/Build_Consumption.md#consumer-contract) is the one each consumer's
  `Core/Core_RedMonitorIntegration.md` links to.

## Specification validation

Before closing a specification change, run:

```powershell
./validate.ps1
./Tools/Test-Changelog.ps1
```

Also run the build and runtime checks that each modified domain spec names. Generated reports and build products
belong under `.build/`, never under `Specs/` or `docs/`.

## Repository rules

- `validate.ps1` checks the currently indexed plans and their references; it does not permanently require the
  extraction plan, or any other historical file name, to remain unfinished. The
  [agent guidance checks](Testing/Testing_Validation.md#agent-guidance-checks) define its structural scope.
- The [active plan index](Plans/WIP/README.md), the [Done index](Plans/Done/README.md), the
  [source origin](SourceImport/source-origin.json) and the [usage docs](../docs/README.md) are the entry points
  for plans, provenance, and users.
