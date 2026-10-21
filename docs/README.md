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
