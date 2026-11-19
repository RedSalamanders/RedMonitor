- RedMonitor restores vcpkg with the standard dynamic triplets (`x64-windows`, `arm64-windows`) instead of
  `*-windows-static-md`, the restore model and linkage every other scripted repository uses (RedHome CV-4-07,
  register C-07 and C-14, owner default of 2026-11-18). `yyjson` is now a DLL: every build copies `yyjson.dll`
  beside each executable (`Directory.Build.targets`, from `bin` or `debug\bin`), `build.ps1` lists it among the
  artifacts, `package.ps1` stages it beside `RedMonitor.exe` and no longer refuses it, and `Install-RedMonitor.ps1`
  requires it. **The Release package therefore ships `yyjson.dll` (about 260 KB) beside the executable.** Local x64
  Release and Debug builds pass; the Release package carries the DLL and its extracted `RedMonitor.exe` passes the
  runtime contract with `PATH` limited to System32. Native qualification of both architectures runs on `main` after
  merge.
