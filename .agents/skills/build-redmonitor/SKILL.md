---
name: build-redmonitor
description: Build, restore or package standalone RedMonitor and diagnose toolchain failures. Use when running build.ps1 or package.ps1 for one of the six profiles, cross-building ARM64, checking the dependency closure or build receipts, or investigating a compiler or toolchain failure.
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
