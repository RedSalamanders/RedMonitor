# Changelog

## Unreleased
- Default Release viewers to production mode, bind explicit viewer-test settings in build receipts and stamp version/test-surface resources so consumer packaging cannot confuse test-enabled diagnostics with distributable artifacts.
- Add bounded application-labelled producer and optional adjacent viewer helpers, a clean pinned consumer SDK restore, cross-process ETW probes and an isolated runtime/resource contract; carry CRT and dependency notices in Release viewer packages while retaining separate consumer and platform qualification gates.
- Extract the Windows log viewer and its native model tests into independent RedMonitor with exact dependencies, developer scripts and focused skills; add the compatible native producer API and owned ETW sessions. Consumer adoption and full qualification remain in WIP.
