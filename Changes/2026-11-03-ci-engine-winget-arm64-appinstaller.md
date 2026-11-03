- Adopt shared CI engine `91c38d6`, which registers the hosted Windows 11 ARM64 image's inbox App Installer
  when `winget.exe` is absent. The `v0.1.84` Winget publication passed its x64 install proof but stopped on
  ARM64 before validation because that runner had no winget, so no submission occurred. Only the engine pin
  and generated callers change; publication still requires a fresh main qualification under this engine.
