# Developer command surface

Use the root build/restore/test/validate/format/package commands documented in README.md.
Generated outputs remain below `.build`; independently launched applications are never terminated.

| Tool | Purpose and side effects |
| --- | --- |
| `Fold-Changelog.ps1` | Validates/folds Changes into CHANGELOG.md; Check and WhatIf are read-only |
| `Test-Changelog.ps1` | Read-only fragment and generated changelog validation |
| `Test-ChangelogWorkflow.ps1` | Runs shared behavior fixtures in a caller-owned scratch directory |
| `VisualStudio.psm1` | Read-only discovery of the installed C++ toolchain |
| `VcpkgTriplet.psm1` | Writes toolchain-pinned overlay triplets under the generated dependency root |
| `Modules/Documentation/Changelog.psm1` | Shared changelog implementation with explicit exports |

Tests/Tooling.Tests.ps1 exercises output boundaries and shared changelog behavior. Source/dependency
locks, script syntax, documentation links and native project boundaries are checked by validate.ps1.

ClientSdk/Update-RedMonitorClient.ps1 explicitly fetches only the pinned public header and MIT notice. ClientSdk/Verify-RedMonitorClient.ps1 checks consumer-local bytes without network or a helper build. Install-RedMonitor.ps1 installs a validated production package separately into a standard folder; its harness override is confined to source .build. Tests/Tooling.Tests.Installation.ps1 covers installation/replacement, retained backups, hashes, missing closure, foreign profiles and path/reparse failures without touching a real installation.
