- Adopt shared CI engine `891b3bb`, whose generated winget manifests carry schema headers. winget 1.29
  `validate` previously exited with a warning code and failed the first Winget publication before any
  submission. Only the engine pin and generated callers change; publication still requires a fresh main
  qualification under this engine.
