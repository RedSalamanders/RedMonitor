# Use RedMonitor from an application

Vendor the single public Client.h and MIT notice at a reviewed immutable commit. Record both file hashes
in Dependencies/RedMonitor.lock.json and verify them locally during ordinary builds. Run the explicit
client updater only when adopting a new SDK; no viewer build, download or source checkout belongs in an
application build. The producer is header-only and uses existing Windows SDK/WIL dependencies.

Define REDMONITOR_DEFINE_PROVIDER in exactly one application translation unit before including Client.h.
Own one RedMonitor::Application with a static label (RedSalamander, RedPrism, RedXe or RedTilde) before
starting workers. Write or WriteUtf8 sends bounded messages with standard severity, PID, TID and time.
Stop workers/plugin callbacks before destroying the owner. Never transfer C++ provider ownership through
a plugin ABI. An existing module-owned provider can use WriteNormalizedEvent with its existing metadata.
Keep current file/debugger/crash fallback; avoid document content and personal paths in new diagnostics.

Install the separately packaged Release viewer by extracting its ZIP and running:

    pwsh -NoProfile -File ./Install-RedMonitor.ps1

The default is LocalAppData/Programs/RedMonitor; -Scope LocalMachine selects ProgramFiles/RedMonitor.
The installer requires the selected folder's write rights, refuses damaged/test-enabled packages and
running target viewers, and retains the previous version. It does not install a driver or service.

The app remains usable with no helper or ETW privileges. --redmonitor explicitly opens an installed
production viewer. Debug bare startup may queue that launch automatically. Tests/help/probes and Release
startup do not auto-launch it. No application package contains the viewer; no application kills it on exit.

The four integrations currently share the public bytes at SDK commit
9ebea6577fe9a5ced7647283c918f51f67d666fd. Each consumer owns its adapter, tests and evidence independently;
updating this repository does not change a consumer pin. See the [delivery checkpoint](../Specs/Plans/WIP/RedMonitorExtraction_2026-10-21.md)
for implemented scope and remaining qualification, including the owner's deferred RedSalamander Release gates.
