# Viewer window

Status: current normative contract
Last reviewed: 2026-11-19

This contract owns what the viewer window does on the UI thread: how the log view measures, filters, renders and
hit-tests lines, and how ETW batches and worker results reach it. The document it shows is owned by
[architecture](../Core/Core_Architecture.md), and the ETW session that feeds it by [transport](../Core/Core_Transport.md).

## Top-level window ownership

The UI thread owns the top-level window through a `MonitorWindow` and its `wil::unique_hwnd`. `WM_NCCREATE`
binds the instance supplied to `CreateWindowExW` and subsequent messages dispatch through it.
`WM_NCDESTROY` drains posted payloads and detaches the instance and window handle.

## Rendering and filtering

The viewer uses one device-loss predicate for partial draws, full draws and presentation. On
`D2DERR_RECREATE_TARGET`, `DXGI_ERROR_DEVICE_REMOVED`, `DXGI_ERROR_DEVICE_RESET`,
`DXGI_ERROR_DEVICE_HUNG` or `DXGI_ERROR_DRIVER_INTERNAL_ERROR`, it discards device-dependent
resources, resets presentation state and requests a full redraw to rebuild the view.

The viewer owns its Direct3D, DXGI, Direct2D and DirectWrite interfaces through
`wil::com_ptr_nothrow`. COM queries use checked results and follow the viewer's existing recovery paths.

Launch with `--warp` to use software rendering for the log view, the toolbar and the status bar.
The log view keeps that choice when it recreates its device. Ordinary launches try the hardware device
first and use WARP if hardware device creation fails.

Severity filter changes update the visible-line index table without marking retained source
lines dirty for width remeasurement; background width measurement samples at most 32 dirty candidate
lines per pass and never falls back to synchronous UI-thread DirectWrite layout when threadpool
admission fails. In auto-scroll mode, `ColorTextView` renders and hit-tests through the bounded tail
layout (supporting both unfiltered and filtered views with per-line severity and user color spans)
without triggering full-document or virtual-slice fallback layouts during `WM_PAINT`.

## Publishing to the UI thread

ETW batch delivery coalesces `kColorTextViewEtwBatch` window messages so at most one batch notification
is queued at a time, and paces immediate `UpdateWindow` repaints during sustained batch arrival to at
most 60 Hz (16 ms) so Win32 input and menu messages are never starved. GUI result payloads use the
registered token mechanism and are drained at WM_NCDESTROY. Permission denial is visible and recoverable
without file-view loss.
