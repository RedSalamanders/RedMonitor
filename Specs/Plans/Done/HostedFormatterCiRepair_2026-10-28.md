# Hosted formatter CI repair — 2026-10-28

- [x] Preserve the failing main run and identify the formatter/configuration mismatch.
- [x] Use an exact checksum-pinned formatter without changing the native style or check strictness.
- [x] Prove corrupt offline wheels cannot be extracted and preserve a working install.
- [x] Run native formatting, tooling validation and changelog checks.
- [x] Publish and validate the PR; merge and confirm all seven main jobs are green.
- [x] Update the Validation contract and move this plan to Done after verified closeout.

Baseline: main `8e96fc358fa056f9640e588551e42825269fb665`, workflow run
`40410379587`, tooling job `121879285770`. Its formatter rejects the existing
`SortIncludes` mapping in `.clang-format` at line 94. All six native jobs passed.

The repair retains `.clang-format`, `--dry-run --Werror`, the complete native file set,
and all native matrix jobs. `Build/clang-format.json` owns the exact formatter/package pin.
`Tools/Install-ClangFormat.ps1` follows the existing DxUi/Red-family checksum-pinned wheel
extraction pattern without Python or machine-wide installation. Generated files stay beneath
the repository's guarded `.build/format` root. `format.ps1 -Check` remains read-only and
requires the pinned version. Durable behavior belongs in `Specs/Testing/Testing_Validation.md`.

Hosted acceptance must be bound to the final PR head and merged main commit. A local formatter
pass does not replace native runtime or platform qualification.

## Completed qualification

[PR #2](https://github.com/RedSalamanders/RedMonitor/pull/2) merged as
`1e3e9d6059728e90542e013876c1c9783234f505` on 2026-10-28. The final PR head
`2a7e22bc54f736bb100f95b34bcf98a132a23585` integrated concurrent main changes,
preserving their canonical formatter discovery and style preflight, together with
the pinned repository formatter and all three tooling-test groups.

- [Final PR run 40668806684](https://github.com/RedSalamanders/RedMonitor/actions/runs/40668806684): tooling and all six native jobs passed.
- [Merged main run 40671228756](https://github.com/RedSalamanders/RedMonitor/actions/runs/40671228756): tooling and native x64/ARM64 Debug, Release and ASan Debug all passed.
- Local validation passed the unchanged complete native format check, all 22 changelog
  controls, corrupt-wheel/version/read-only formatter controls, 21 header and 44
  package/lifecycle/read-only guidance controls, 20 public-entrypoint controls and all
  eight formatter-discovery controls. No symbolic-link control was skipped.

This completes the formatter repair. The independent extraction/adoption plan retains its
viewer, consumer, performance and platform qualification gates.
