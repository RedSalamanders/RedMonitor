- `format.ps1` now formats with the formatter CI uses and over the files CI formats. It takes clang-format from
  `Install-CiFormatter` in the pinned `.ci-engine` (22.1.3 today, under `.build/shared-format`) and selects the
  eight C and C++ extensions under the `formatRoots` of `.ci/project.json`, minus `formatExclude`; `-Check` still
  verifies without writing and now lists every file that needs formatting. Every source already conforms.
  `Build/clang-format.json`, `Tools/Install-ClangFormat.ps1`, and the Visual Studio and `PATH` lookups are
  removed; `Get-RedMonitorClangFormat` returns the engine install, so Test-Changes identity still hashes the
  formatter `format.ps1` uses. The formatter test now uses an owned Git fixture with its own engine clone, the
  selection-order test of the removed lookup is deleted, and the native CI adapter no longer runs the installer.
  `Testing_Validation.md` and the README describe the new command.
  This is step CV-6-05 of the `RedHome` convergence plan (register D-02, D-05, D-06).
