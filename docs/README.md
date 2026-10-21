# Using RedMonitor

Launch RedMonitor.exe to receive compatible diagnostic events or open a UTF-8/UTF-16LE log. The viewer
supports severity filters, find, colored metadata, selection/copy, line numbers, auto-scroll, themes,
always-on-top and transactional Save As. Log retention and queued traffic are bounded; dropped events
are shown. The initial extraction keeps the legacy monitor settings identity for RedSalamander integration.

Real-time ETW needs appropriate Windows session permissions. A failed session does not prevent file
viewing. Self diagnostics are opt-in with `--etw`. Printing remains unsupported.

Client-only applications include the public producer header and own one registration per module.
Viewer distribution is optional and separately pinned. RedPrism, RedXe and RedTilde adoption remains
tracked by the [WIP plan](../Specs/Plans/WIP/RedMonitorExtraction_2026-10-21.md).

Define the provider in exactly one translation unit of each participating EXE/DLL:

```cpp
#define REDMONITOR_DEFINE_PROVIDER
#include <RedMonitor/Client.h>

int main()
{
    RedMonitor::Provider provider;
    if (provider.Status() == ERROR_SUCCESS && provider.IsEnabled())
    {
        const ULONG status = provider.Write(RedMonitor::Severity::Info, L"RedPrism: startup complete");
        static_cast<void>(status);
    }
    // Stop owned producer threads before provider leaves scope.
}
```

Other translation units include the header without the definition macro. Pass a borrowed provider
reference only inside the same module's lifetime. Header-only clients need no DxUi or viewer library;
they link the Windows ETW import library automatically. Check IsEnabled before formatting an expensive
message. Success means accepted/disabled, not confirmed viewer delivery; oversize and invalid severity
return explicit errors. Existing dedicated performance providers remain independent.
