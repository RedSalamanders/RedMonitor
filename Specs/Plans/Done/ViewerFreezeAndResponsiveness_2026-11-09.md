# Viewer freeze, layout, and ETW ingestion responsiveness repair — 2026-11-09

Status: COMPLETED. Owner: RedMonitor. Started: 2026-11-09. Completed: 2026-11-09.

This plan tracks the root-cause analysis, implementation, normative contract updates, and regression tests for
UI-thread freezes, message-queue starvation, redundant 100,000-line document rebuilds, and layout mismatches in
`RedMonitor`. Durable behavior belongs in [Core_Architecture.md](../../Core/Core_Architecture.md),
[Core_Transport.md](../../Core/Core_Transport.md), and [Testing_Validation.md](../../Testing/Testing_Validation.md).

## Delivery checklist

- [x] R0: audit `src/`, `include/`, and `support/` to isolate all UI-thread freeze and starvation vectors.
- [x] R1 (`[PERF-01]`): preserve incremental dirty ranges, line offsets, total length, visible lines, and longest-line tracking across `Document::EnforceRetentionLimits`; bound `ColorTextView::EnsureWidthAsync` to top candidate lines without full-document UI-thread string copies or synchronous 100,000-layout fallback loops.
- [x] R2 (`[BUG-01]`): coalesce `WndMsg::kColorTextViewEtwBatch` posts with a single-pending-post guard under `_etwQueueCS` and pace continuous batch draining so `WM_PAINT` and input are never starved.
- [x] R3 (`[PERF-02]`): preserve valid scrolled-back slice layouts and cached bitmaps across non-overlapping retention evictions and appends; coalesce scroll-back relayouts instead of cancelling in-flight layout workers on every batch.
- [x] R4 (`[BUG-02]`): use `_tailLayout` and bottom-anchored coordinates in `DrawHighlights`, `DrawSelection`, `DrawCaret`, `GetCaretRectPx`, and `PosFromPoint` during `RenderMode::AUTO_SCROLL` so active search or selection never triggers synchronous `CreateFallbackLayoutIfNeeded` during `WM_PAINT`.
- [x] R5 (`[PERF-03]` & `[BUG-05]`): eliminate full-document `VisibleLines()` vector copies in viewport/gutter/layout queries; optimize incremental search scanning (`AppendMatchesForRange`) and `Document::ColorizeWord` under locked document helpers without per-line deep copies or per-call needle allocations.
- [x] R6 (`[BUG-03]`): stop the owned real-time ETW trace session (`ControlTrace(..., EVENT_TRACE_CONTROL_STOP)`) before joining `_workerThread` in `EtwListener::Stop` so `ProcessTrace` unblocks immediately rather than stalling up to 5 seconds.
- [x] R7 (`[PERF-04]` & `[BUG-04]`): avoid redundant `UpdateStatusBar`/`CheckMenuItem` calls when status and auto-scroll state are unchanged; defer Find Bar creation until requested and clean up Find Bar child HWND lifecycle in `ColorTextView::DestroyFindBar`.
- [x] R8: add deterministic regression tests in `Tests/Monitor.Tests.Runner.cpp` covering retention cache preservation, incremental offset/visibility shifting, search/coloring helpers, width-candidate bounding, and ETW shutdown ordering.
- [x] R9: update normative contracts (`Specs/Core/Core_Architecture.md`, `Specs/Core/Core_Transport.md`, `Specs/Testing/Testing_Validation.md`), `docs/README.md`, and add a dated `Changes/` fragment.
- [x] R10: pass `Tools/Test-Changelog.ps1`, `validate.ps1`, `format.ps1 -Check`, `Tests/Tooling.Tests.ps1`, x64 Debug/Release/ASan Debug test suites, and all three ARM64 cross-builds (`Test-Changes.ps1 -Mode PrePush`), then open the pull request and move this plan to `Specs/Plans/Done/`.

## 1. Root-cause findings and technical design

### 1.1 `[PERF-01]` Retention eviction dirty-range storm and unbounded `EnsureWidthAsync`

- **Mechanism**:
  - Once `Document` reaches the retention cap (`100,000` lines or `64 MiB`), `Document::EnforceRetentionLimits` previously invalidated `_totalLengthValid`, `_offsetsValid`, `_maxLineCharsValid`, rebuilt all `100,000` `_visibleLines` from scratch, and called `MarkAllDirtyUnsafe()`, setting `_dirtyRangeFirst = 0` and `_dirtyRangeLast = 99,999` on every 200-event ETW batch.
  - `ColorTextView::HandleDocumentEviction` wiped all `100,000` entries of `_lineWidthCache`.
  - `ColorTextView::OnAppEtwBatch` then called `EnsureWidthAsync()`, which looped `0..99,999` on the UI thread (acquiring `100,000` locks and copying `100,000` `std::wstring` objects) and submitted a threadpool callback creating `100,000` `IDWriteTextLayout` COM objects per batch—or executed all `100,000` `CreateTextLayout` calls synchronously on the UI thread if `TrySubmitThreadpoolCallback` failed.
  - `Document::SetFilterMask` also called `MarkAllDirtyUnsafe()` even though filtering does not alter any source line's display text or width.
- **Fix**:
  - Maintain `_lineOffsets` as `std::deque<uint64_t>` with a running `_lineOffsetBase` so front eviction and back append are both $O(1)$ without invalidating `_offsetsValid`.
  - Update `_cachedTotalLength` in $O(1)$ on eviction using `result.characterPositionsEvicted`.
  - Shift `_maxLineIndex` by `result.linesEvicted` when the longest line is not among the evicted front lines, preserving `_maxLineCharsValid` in $O(1)$.
  - Shift `_dirtyRangeFirst` and `_dirtyRangeLast` down by `result.linesEvicted` instead of calling `MarkAllDirtyUnsafe()`.
  - Update `_visibleLines` incrementally across eviction by erasing evicted front entries and shifting surviving `sourceIndex` and `displayRowStart` values in place.
  - In `ColorTextView::HandleDocumentEviction`, erase the evicted prefix of `_lineWidthCache` and shift `_maxMeasuredIndex` instead of wiping all cached widths.
  - Bound `ColorTextView::EnsureWidthAsync` using `Document::CollectWidthCandidates`, which scans `[first..last]` under one shared lock and returns at most `kMaxWidthMeasureCandidates` (32) longest lines by display character length for exact DirectWrite measurement. Never run unbounded layout loops on the UI thread.

### 1.2 `[BUG-01]` Win32 message-queue starvation via `kColorTextViewEtwBatch` multiplication

- **Mechanism**:
  - `ColorTextView::QueueEtwEvent` posted `WndMsg::kColorTextViewEtwBatch` whenever `_etwQueue.empty()` was true, while `OnAppEtwBatch` unlocked `_etwQueueMutex` after popping up to 200 events and reposted `kColorTextViewEtwBatch` if `remainingAfterDrain > 0`.
  - Concurrent producer bursts during the unlocked processing window caused multiple `kColorTextViewEtwBatch` messages to accumulate and multiply in the Win32 message queue. Because posted messages take priority over `WM_PAINT` and `WM_TIMER`, sustained ETW traffic starved painting and user input.
- **Fix**:
  - Guard `kColorTextViewEtwBatch` posting with `_etwBatchPostPending` under `_etwQueueMutex` so at most one batch message is queued at any time.
  - Repost only at the end of `OnAppEtwBatch` when `_etwQueue` remains non-empty, and when a frame interval (`>= 16 ms`) has elapsed with pending invalidation, flush a frame via `UpdateWindow(_hWnd)` before reposting so painting stays responsive under continuous load.

### 1.3 `[PERF-02]` Scroll-back layout thrashing and synchronous fallback layout rebuilds

- **Mechanism**:
  - In `RenderMode::SCROLL_BACK`, `OnAppEtwBatch` unconditionally called `EnsureLayoutAdaptive(1)` and `InvalidateSliceBitmap()`. Because `changeSize = 1 < kSyncLayoutThresholdLines (100)`, `EnsureLayoutAdaptive` bypassed the debounce timer, incremented `++_layoutSeq` (cancelling in-flight async workers), and cleared `_sliceBitmap`—forcing `OnPaint` to build a synchronous fallback `IDWriteTextLayout` on the UI thread on every frame even when the scrolled-back viewport slice was unaffected by tail appends or front evictions.
- **Fix**:
  - In `HandleDocumentEviction`, when `_textLayout` covers source lines entirely after `eviction.linesEvicted` (`_sliceFirstLine >= eviction.linesEvicted`), shift `_sliceFirstLine`, `_sliceLastLine`, `_sliceFirstDisplayRow`, `_sliceStartPos`, `_sliceEndPos`, `_sliceBitmapYBase`, and `_sliceFilteredRuns` in place while retaining `_textLayout` and `_sliceBitmap`.
  - In `OnAppEtwBatch` during `SCROLL_BACK`, skip `EnsureLayoutAdaptive` and `InvalidateSliceBitmap` when the existing `_textLayout` already covers the visible line range `[visStartLine, visEndLine]` and no lines inside `[_sliceFirstLine, _sliceLastLine]` were modified.
  - When a scroll-back slice relayout is required during streaming, coalesce via `EnsureLayoutAsync()` rather than cancelling in-flight workers on every batch.

### 1.4 `[BUG-02]` `AUTO_SCROLL` highlight, selection, and caret layout mismatch

- **Mechanism**:
  - `DrawScene` invoked `DrawHighlights()` and `DrawSelection()` before checking `_renderMode == RenderMode::AUTO_SCROLL`. Because `_textLayout` is null or stale in `AUTO_SCROLL` mode, having an active search match or text selection forced `DrawHighlights()` / `DrawSelection()` to call `CreateFallbackLayoutIfNeeded` synchronously inside `WM_PAINT` on every frame and draw rectangles at `displayRow * GetLineHeight()` instead of the bottom-anchored `_tailLayout` origin.
  - `RebuildTailLayout` also used `GetLineStartOffset` + `GetTextRange` + per-line lock loops in unfiltered mode instead of `BuildFilteredTailText`.
- **Fix**:
  - Unify `RebuildTailLayout` and `ApplyColoringToTailLayout` to use `Document::BuildFilteredTailText` (for both filtered and unfiltered modes), recording `_tailStartPos`, `_tailEndPos`, `_tailIsFiltered`, and `_tailFilteredRuns`, and applying both metadata prefix colors and per-line custom `ColorSpan`s.
  - Keep `_scrollY` aligned with the bottom-anchored `_tailLayout` across `ResetAfterDocumentReplacement`, `SetFilterMask`, `SetFont`, `SetLinePadding`, `EnableShowIds`, `AppendText`, `AppendInfoLine`, and `EndBatchAppend` when in `RenderMode::AUTO_SCROLL`, and transition to `RenderMode::SCROLL_BACK` when `EnsureCaretVisible` or `VK_PRIOR` scrolls upward.
  - Do not invalidate `_tailLayoutValid` inside `InvalidateSliceBitmap()`.
  - In `DrawHighlights`, `DrawSelection`, `DrawCaret`, `GetCaretRectPx`, `PosFromPoint`, `EnsureCaretVisible`, and `MoveCaretToLine`, use `_tailLayout` and its bottom-anchored `yBase = documentBottom - metrics.height` whenever `_renderMode == RenderMode::AUTO_SCROLL && _tailLayoutValid && _tailLayout`.

### 1.5 `[PERF-03]` & `[BUG-05]` Zero-copy visible-line queries, fast incremental search, and locked `ColorizeWord`

- **Mechanism**:
  - `Document::VisibleLines()` returned a copy of the 100,000-element `std::vector<VisibleLine>` by value (`1.6 MiB`). `GetVisibleLineRange()` called `_document.VisibleLines()` five times consecutively, `DrawLineNumbers()` called it four times per frame, and `MaybeRefreshVirtualSliceOnScroll()` / `StartLayoutWorker()` copied the full vector for single-element or small-range lookups.
  - `ColorTextView::AppendMatchesForRange` copied each `Line` struct by value, called `GetLineStartOffset` per match, and re-allocated/lowercased the search needle on every line in `FindCaseIncensitive`.
  - `ColorTextView::ColorizeWord` computed unlocked manual offsets across lines and acquired a separate `unique_lock` per match.
- **Fix**:
  - Add zero-copy locked lookup helpers on `Document` (`VisibleIndexForSource`, `SourceIndexForVisible`, `GetVisibleLineEntry`, `CopyVisibleLinesRange`, `GetFilteredTextRange`) and replace full-vector `VisibleLines()` copies in `GetVisibleLineRange`, `DrawLineNumbers`, `MaybeRefreshVirtualSliceOnScroll`, `StartLayoutWorker`, `CreateFallbackLayoutIfNeeded`, and `CopySelectionToClipboard`.
  - Precompute lowercase search needles once and add `Document::FindMatchesInRange` and `Document::ColorizeWord` to scan lines under a single lock without copying `Line` structs; clear stale DirectWrite drawing effects and cached slice layouts when recoloring or clearing coloring.

### 1.6 `[BUG-03]` Immediate real-time ETW session stop in `EtwListener::Stop`

- **Mechanism**:
  - `EtwListener::Stop` called `CloseTrace(traceHandle)` and waited up to 5,000 ms on `_workerThread` before calling `ControlTrace(_sessionHandle, nullptr, props, EVENT_TRACE_CONTROL_STOP)`. Real-time ETW sessions with a 1-second flush timer could stall `ProcessTrace` until buffer flush or timeout.
- **Fix**:
  - Stop the owned trace session via `ControlTrace(_sessionHandle, nullptr, props, EVENT_TRACE_CONTROL_STOP)` immediately after `CloseTrace(traceHandle)` and before waiting on `_workerThread`.

### 1.7 `[PERF-04]` & `[BUG-04]` Status/menu update gating and Find Bar teardown

- **Mechanism**:
  - `OnTimerMainWindow` triggered `UpdateStatusBar()` unconditionally when `(currentCount % 10 == 0)` even if no state changed, and `UpdateStatusBar` called `CheckMenuItem` unconditionally without checking the current menu check state.
  - `CreateDeviceResources` created `_hFindPanel` eagerly on every Direct3D device creation parented to `GetParent(_hWnd)` (`g_hMainWindow`), and `ColorTextView` did not unsubclass `_hFindEdit`/`_hFindPanel` or destroy `_hFindPanel` on `WM_DESTROY`/`WM_NCDESTROY`.
- **Fix**:
  - Track `(currentCount, visibleLines, totalLines, droppedCount, g_filterMask, autoScroll)` in `OnTimerMainWindow` so `UpdateStatusBar` runs only when state changes, and check `GetMenuState` before calling `CheckMenuItem`.
  - Create the Find Bar on demand in `ShowFindBar()` rather than `CreateDeviceResources()`, and unsubclass `_hFindEdit`/`_hFindPanel` and reset `_hFindPanel` and its child controls in `ColorTextView::DestroyFindBar` during `WM_DESTROY` and `WM_NCDESTROY`.

## 2. Verification and remaining gates

- Local validation requires `Tools/Test-Changelog.ps1`, `validate.ps1`, `format.ps1 -Check`, `Tests/Tooling.Tests.ps1`,
  `test.ps1` in x64 `Debug`, `Release`, and `ASan Debug` (including live ETW roundtrip and ASan probe), and `build.ps1`
  cross-builds in ARM64 `Debug`, `Release`, and `ASan Debug`, plus portable package and installation controls via
  `Test-Changes.ps1 -Mode PrePush`.
- Hosted CI on the pull request and merged `main`, native ARM64 runtime execution, physical IME/AT, and interactive
  desktop focus gates remain explicit separate obligations.
