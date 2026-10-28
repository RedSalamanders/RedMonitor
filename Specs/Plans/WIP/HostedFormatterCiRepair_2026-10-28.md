# Hosted formatter CI repair — 2026-10-28

- [x] Preserve the failing main run and identify the formatter/configuration mismatch.
- [x] Use an exact checksum-pinned formatter without changing the native style or check strictness.
- [x] Prove corrupt offline wheels cannot be extracted and preserve a working install.
- [x] Run native formatting, tooling validation and changelog checks.
- [ ] Publish and validate the PR; merge and confirm all seven main jobs are green.
- [ ] Update the Validation contract and move this plan to Done after verified closeout.

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
