---
name: build-redmonitor
description: Build, restore or package standalone RedMonitor and diagnose toolchain failures.
---

# build-redmonitor

Read the [build/consumption contract](../../../Specs/Build/Build_Consumption.md). Use the repository entrypoints:

```powershell
./build.ps1 -Platform x64 -Configuration Debug
./build.ps1 -Platform ARM64 -Configuration Release
./package.ps1 -Platform x64 -Configuration Release
```

The ARM64 command cross-builds on x64; it does not run ARM64 tests. Packaging is a separate Release operation,
not a default build step. Verify the owning profile matrix, dependency closure and receipts separately; do not
borrow sibling outputs or terminate independently launched apps. Outputs stay beneath the repository `.build`.
