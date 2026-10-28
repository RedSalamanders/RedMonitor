---
name: test-harness
description: Add or run standalone RedMonitor behavioral tests, captures or source-bound evidence.
---

# test-harness

Read the [validation contract](../../../Specs/Testing/Testing_Validation.md). Choose the needed scope:

```powershell
./validate.ps1
./Tests/Tooling.Tests.ps1
./test.ps1 -Platform x64 -Configuration Debug
./test.ps1 -Platform x64 -Configuration Debug -IncludeLiveEtw
./Test-Changes.ps1 -Explain -Mode Full
```

The first two commands check tooling without a native build. Default `test.ps1` builds and runs console cases;
the explicit live-ETW gate adds the real transport roundtrip and treats permission denial as failure. `-SkipBuild`
requires an exact successful source/profile/artifact receipt. Full/PrePush also require the other profiles and
installation controls named by `Test-Changes.ps1`; a focused pass does not close viewer/interactive/performance
gates. Preserve fresh run roots and failures. GUI images use non-activating synthetic harness fixtures;
foreground/clipboard tests require agreement to the time.
