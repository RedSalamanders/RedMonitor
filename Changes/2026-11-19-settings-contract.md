- The settings contract moves from a paragraph of `Specs/Core/Core_Architecture.md` to its own
  `Specs/Core/Core_Settings.md`, the contract name every RedSalamanders application uses (RedHome register H-26,
  CV-6-08). It records the app ID, folder, Release and Debug file names and their fallbacks, the schema, JSON5 reading,
  the unusable-file backup and explicit-replacement rule, and the stamped atomic save, as the code does today. The
  Release file stays `RedSalamanderMonitor-7.0.settings.json` until the S4 settings migration. Documentation only.
