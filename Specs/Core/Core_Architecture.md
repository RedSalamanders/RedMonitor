# Architecture and compatibility

RedMonitor owns its executable, DirectX view, log model, ETW listener, worker-based file I/O,
resources, localization and test harness. Applications use a small producer header and optionally
stage/launch a pinned viewer. Neither clients nor plugins include private viewer/support headers.

The first extraction statically links a private transitive support snapshot from the MIT-licensed
RedSalamander commit in SourceImport. Its broad settings/theme types are S4 migration debt, not a
new shared ABI. No build or runtime dependency on Common.dll or a sibling checkout is allowed.
DxUi is an independent exact pinned archive. Shared theme extraction remains a separate project.

Product output is RedMonitor.exe. The initial compatibility contract retains settings app ID
`RedSalamanderMonitor`, window ID `MonitorWindow`, legacy registry fallback and single-instance mutex
`Local\RedSalamanderMonitor_Instance`. Satellite owner names remain RedSalamanderMonitor. A consuming
RedSalamander may stage the same executable as RedSalamanderMonitor.exe. No second live implementation
is retained there. The later independent-settings migration must preserve old files and rollback.

The document owns bounded immutable text blocks, copies metadata under lock, and shifts/clamps all
selection/search/scroll mappings together on oldest-first eviction. Save captures shared block ownership;
eviction cannot invalidate an in-flight snapshot. Queue defaults: 4096 events; retention: 100000 lines
and 64 MiB UTF-16 text; search: 100000 matches. Preserve validated setting ranges during extraction.

Open streams strict UTF-8/UTF-16LE in bounded chunks on an owned cancellable worker. Failed or cancelled
open never replaces the document. Export writes strict UTF-8+BOM through a sibling temporary and atomic
replacement; failure/cancellation preserves the destination. UI publication rejects stale completions.
