# Specification authority

AGENTS.md and this catalog own repository policy. Contracts state intended behavior; capabilities.json
distinguishes implemented behavior from pending qualification. Exact locks/manifests own machine identity.
Tests provide evidence, not permission to ignore contracts. WIP plans sequence unfinished work.

Completed plans move to Done only after their own gates close. Update the active index, Done index and inbound
links together. Validation checks the current indexed plans and their references; it does not permanently require
the extraction plan, or any other historical filename, to remain unfinished. The
[agent guidance checks](Testing/Testing_Validation.md#agent-guidance-checks) define the structural validation scope.

| Contract | Ownership |
| --- | --- |
| [Architecture](Core/Core_Architecture.md) | Source boundaries, compatibility and settings |
| [Transport](Core/Core_Transport.md) | ETW schema, client and session lifetime |
| [Consumption](Build/Build_Consumption.md) | Build, exact client pins and standalone installation |
| [Validation](Testing/Testing_Validation.md) | Native, tooling, performance and evidence |

See the [active plan index](Plans/WIP/README.md), [Done index](Plans/Done/README.md),
[source origin](SourceImport/source-origin.json) and [usage docs](../docs/README.md).
