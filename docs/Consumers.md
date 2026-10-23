# Application adoption

`Client.h` is the wire-level producer. `Application.h` adds a bounded application label and strict counted UTF-8
conversion while retaining the disabled fast path. The module owns its provider; stop workers/callbacks before
disposal. RedXe forwards an already-copied bounded host log record, preserving file-queue policy and plugin ABI.
RedPrism keeps its independent Pipeline provider. RedTilde emits outcome diagnostics without Markdown or paths.

`Viewer.h` is an optional WIL-based helper for the explicit `--redmonitor` command. It launches only
`RedMonitor/RedMonitor.exe` adjacent to the application using an absolute executable path and no shell or wait.
Registration failure and missing viewer do not affect normal application behavior. The viewer owns its settings.

Each consumer bootstraps an exact clean commit into `.build/rm/<short-key>` and checks the full HEAD, origin
and API before importing `Tools/Restore-Consumer.ps1`. This emits SDK props, or builds and stages a verified
viewer package when explicitly requested. API 1 is retained; no consumer includes private source/support code.
Release viewer packages carry the app-local VC CRT, theme/satellite/schema closure and dependency notices.

The viewer's `--runtime-contract` verifies the real packaged schema/themes/four resource satellites before
any user settings, mutex, ETW or HWND access. `TransportRoundtripTests.exe <application.exe> <label>` starts an
owned `--redmonitor-probe` child and verifies its Unicode, severity, PID, initial TID and timestamp through ETW.
The test never selects or terminates an independently launched application. Ordinary startup has no readiness wait.

Legacy RedSalamander staging retains its executable/resource/settings names. Independent settings/support
narrowing remains S4; physical input/accessibility, native ARM64, controlled performance and release gates remain
explicit. A successful headless distribution probe does not qualify Preferences interaction or window placement.
