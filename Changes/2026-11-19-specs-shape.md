- Gave the specifications the same shape as every RedSalamanders repository (convergence CV-6-03): the common
  `Specs/README.md` structure and WIP index row format, a `Specs/UI/` folder with the viewer window contract, a
  `Core_PerformanceAndResources.md` contract, a `Testing_RunEvidence.md` contract, the common README
  "Recording changes" section and CODEOWNERS file, and one statement of the consumer contract in
  `Build_Consumption.md` for the four applications to link to. Rules moved between specs unchanged; no behavior,
  build input or test changed. Validated with `validate.ps1` and `Tools/Test-Changelog.ps1`.
