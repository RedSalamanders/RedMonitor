# Explicit state machines and lifetime safety

Status: ACTIVE — plan only; code implementation has not started.
Priority: P1 rendering correctness, async lifetime safety, developer ergonomics (DX) and agent safety (AX).
Owner: RedMonitor maintainers.
Prepared: 2026-11-10.
Planned-at commit: `77239c80471f7f07ba4801c6081bc08b7d9ae47d` (`RedSalamanders/RedMonitor`).

- **Owning contracts**: [repository guidance](../../../AGENTS.md), [specification authority](../../README.md), [architecture](../../Core/Core_Architecture.md), [transport](../../Core/Core_Transport.md), [consumption](../../Build/Build_Consumption.md), [unified CI](../../Build/Build_UnifiedCI.md), [changes workflow](../../Core/Core_Changes.md), and [validation](../../Testing/Testing_Validation.md).
- **Coordinated plans**: [RedMonitor extraction and Red-family adoption](RedMonitorExtraction_2026-10-21.md) retains ownership of `S3` (`RedSalamander` cutover qualification), `S4` (independent settings migration), and `S8` (native/platform, performance, accessibility and release qualification). This plan owns only the internal explicit state-machine refactors and concrete defect fixes (`ISM-08`, `ISM-25`) below, without modifying the public producer header [Client.h](../../../include/RedMonitor/Client.h) or bumping [DxUi.lock.json](../../../Dependencies/DxUi.lock.json).

## 1. Mandatory pre-execution drift check

Before editing any file for this plan, run these read-only checks from the `RedMonitor` repository root:

```powershell
git status --short
git rev-parse HEAD
git diff --name-status 77239c80471f7f07ba4801c6081bc08b7d9ae47d HEAD -- AGENTS.md include src support Build Tests Test-Changes.ps1 validate.ps1 Specs
git diff --cached --name-status
git ls-files --others --exclude-standard
git worktree list --porcelain
```

Reopen any file reported by `git diff` and verify line anchors against current `HEAD` (especially if `S4` settings migration in [RedMonitorExtraction_2026-10-21.md](RedMonitorExtraction_2026-10-21.md) has landed) before applying a slice.

## 2. Architectural decision and non-breaking boundaries

Across `ColorTextView`, `RedMonitor`, `Document`, and `EtwListener`, mutually exclusive presentation, pointer-capture, async file I/O, and trace-session states are currently represented across independent booleans (`_needsFullRedraw`, `_hasScrollPresent`, `_mouseDown`, `_vScrollDrag`, `_hScrollDrag`, `_running`), scalar deltas (`_pendingScrollDy`), and parallel global tuples (`g_monitorFileOpen*`, `g_monitorFileSave*`). When coalesced scroll messages, `WM_CAPTURECHANGED`, filter toggles, or `IDM_FILE_NEW` arrive mid-flight, forgotten field resets produce sheared `Present1` scrolling, stale unfiltered worker layouts, stuck mouse-selection drags, or stale File Open completions overwriting a blank document.

### Non-breaking design patterns

1. **Pattern A — Flat `enum class Phase : uint8_t` + centralized `TransitionTo()`**:
   - Used for `EtwListener` session phases (`Stopped`, `Starting`, `ProcessingTrace`, `Stopping`) and `DocumentFileCoordinator` (`Idle`, `Opening`, `Saving`). Switch statements omit `default:` so `/Wall` enforces exhaustive handling of every phase.
2. **Pattern B — Inline value-type structs and `std::variant<std::monostate, ...>`**:
   - Used for `ColorTextView::PresentPlan` (`Clean`, `PartialScroll{accumulatedScrollDyPx}`, `FullRedraw` where `FullRedraw` dominates any `PartialScroll`) and `ColorTextView` pointer capture (`std::variant<std::monostate, SelectingText, DraggingVScroll, DraggingHScroll>`). Zero heap allocation on paint/scroll hot paths; one-line `.emplace<std::monostate>()` reset on `WM_CAPTURECHANGED` and `ClearText()`.
3. **Pattern C — RAII & lock-scope invariants**:
   - Retain [LocalFileTransaction.h](../../../support/LocalFileTransaction.h) (`Active` -> `Committed` / `Aborted`) and lock-free atomic registration in [Client.h](../../../include/RedMonitor/Client.h) (`0 = Unregistered`, `1 = Registering`, `2 = Registered`) unchanged as positive exemplars; tighten `Document::AddColorRange` so text-length clamping executes inside the exclusive lock.
4. **Pattern D — Discriminated PowerShell state records**:
   - Keep [Test-Changes.ps1](../../../Test-Changes.ps1) and `Build/` helpers aligned with the organization's closed verdict records, atomic `.tmp` writes, and bounded lock retry rules.

### Hard invariants (zero breaking changes)

- **Zero changes to [Client.h](../../../include/RedMonitor/Client.h)**: All four consumer repositories (`RedSalamander`, `RedPrism`, `RedTilde`, `RedXe`) vendor and SHA-256-pin `Client.h`; its bytes and wire schema remain untouched.
- **Zero changes to [DxUi.lock.json](../../../Dependencies/DxUi.lock.json)** or ETW provider GUIDs/event schemas.
- **WIL RAII only, zero manual `Release`/`DestroyWindow`, `/Wall` with zero warnings, and zero `catch (...)`**.

## 3. Source-verified defect ledger and component inventory

### 3.1 Concrete defects (`ISM-08`, `ISM-25`, `Document` lock-drop TOCTOU)

| ID | Location & symbol | Verified defect & user-visible symptom | Non-breaking fix |
| --- | --- | --- | --- |
| `ISM-08a` | `ColorTextView::InvalidateExposedArea` in [ColorTextView.cpp](../../../src/ColorTextView.cpp) (`L4359`–`L4390`) & `Render` (`L2736`–`L2934`) | Overwrites `_pendingScrollDy = deltaPx` instead of accumulating `+= deltaPx` across multiple wheel/scroll steps coalesced before `WM_PAINT`, and unconditionally clears `_needsFullRedraw = false`, downgrading a pending full redraw into a partial `IDXGISwapChain1::Present1` scroll that shifts by only the final delta and shears or duplicates log lines. | Replace `_needsFullRedraw`, `_hasScrollPresent`, and `_pendingScrollDy` with `PresentPlan` (`FullRedraw` dominates `PartialScroll`; `PartialScroll` accumulates `deltaPx` and upgrades to `FullRedraw` if `abs(accumulatedDy) >= viewportHeightPx`); remove dead `_sliceDirtyRegion` / `_sliceCmd` fields in [ColorTextView.h](../../../src/ColorTextView.h). |
| `ISM-08b` | `ColorTextView::SetFilterMask` in [ColorTextView.cpp](../../../src/ColorTextView.cpp) (`L342`–`L411`) | Updates `_document.SetFilterMask(mask)` without bumping `++_layoutSeq; ++_widthSeq;` or clearing `_lineMetrics` / rebuilding `AUTO_SCROLL` tail layout, allowing an in-flight background layout worker to publish an unfiltered `_textLayout` slice over the newly filtered view. | Route `SetFilterMask` through a single `InvalidateSliceLayout()` helper that increments `_layoutSeq` and `_widthSeq`, clears `_lineMetrics`, invalidates `_tailLayoutValid`, and requests `PresentPlan::RequestFullRedraw()`. |
| `ISM-25a` | `IDM_FILE_NEW` & async open/save globals in [RedMonitor.cpp](../../../src/RedMonitor.cpp) (`L300`–`L327`, `L2690`–`L2835`, `L4685`–`L4695`) | Executing `IDM_FILE_NEW` clears the document and view without incrementing `g_monitorFileOpenGeneration` or signalling cancellation on an in-flight async File Open worker, so when the worker finishes it passes `completion->generation == g_monitorFileOpenGeneration` and overwrites the user's new blank session. | Replace loose `g_monitorFileOpen*` / `g_monitorFileSave*` globals with `DocumentFileCoordinator` (`sessionEpoch`, `activeOpen`, `activeSave`); `IDM_FILE_NEW` increments `sessionEpoch`, requests cancel on any active open, and invalidates stale completions. |
| `ISM-25b` | `ColorTextView::WndProc` & `ClearText` in [ColorTextView.cpp](../../../src/ColorTextView.cpp) (`L711`–`L735`, `L4840`–`L4890`, `L5270`–`L5315`) | `ColorTextView::WndProc` has no `WM_CAPTURECHANGED` / `WM_CANCELMODE` handler to clear `_mouseDown`, `_vScrollDrag`, and `_hScrollDrag` (leaving drag-selection stuck on `Alt+Tab`), and `ClearText()` resets flags without calling `ReleaseCapture()` when `GetCapture() == _hwnd`. | Unify `_mouseDown`, `_vScrollDrag`, and `_hScrollDrag` into `PointerCaptureState` (`std::variant<std::monostate, SelectingText, DraggingVScroll, DraggingHScroll>`); handle `WM_CAPTURECHANGED` / `WM_CANCELMODE` and release capture cleanly in `ClearText()`. |
| `ISM-25c` | `PresetFromLegacy` in [RedMonitor.cpp](../../../src/RedMonitor.cpp) (`L1668`–`L1679`) | Maps legacy preset `3` (`IDM_FILTER_PRESET_ERRORS_DEBUG`) to `MonitorFilterPreset::Custom` instead of preserving its dedicated preset identity across save/reload. | Add `ErrorsPerfDebug = 3` (or preserve exact round-trip mapping in `MonitorFilterPreset` + exhaustive `switch`) without breaking existing JSON settings files. |
| `ISM-DOC` | `Document::AddColorRange` in [Document.cpp](../../../src/Document.cpp) (`L1045`–`L1060`) & cache flags in [Document.h](../../../src/Document.h) (`L229`–`L269`) | Reads `GetTextLength()` under a shared lock, drops it, and acquires the exclusive lock to append the range (TOCTOU if text mutates concurrently); tracks 6 separate validity booleans. | Compute length bounds inside the exclusive `_lock` critical section and tie derived line/filter/width caches to a monotonic `_contentEpoch`. |

### 3.2 Complete 7-component state-machine catalog

| # | Component | Current implicit encoding | Target refactor |
| --- | --- | --- | --- |
| `6.1` | `ColorTextView` swap-chain present & async slice layout ([ColorTextView.h](../../../src/ColorTextView.h), [ColorTextView.cpp](../../../src/ColorTextView.cpp)) | `_needsFullRedraw`, `_hasScrollPresent`, `_pendingScrollDy`, `_tailLayoutValid`, `_layoutSeq`, `_widthSeq`, dead `_sliceDirtyRegion`/`_sliceCmd` (`ISM-08a`, `ISM-08b`) | **Pattern B:** `PresentPlan` value struct + centralized `InvalidateSliceLayout()`. |
| `6.2` | `ColorTextView` pointer selection & scrollbar drag ([ColorTextView.cpp](../../../src/ColorTextView.cpp)) | `_mouseDown`, `_vScrollDrag`, `_hScrollDrag` without `WM_CAPTURECHANGED` (`ISM-25b`) | **Pattern B:** `PointerCaptureState` `std::variant` reset on `WM_CAPTURECHANGED`, `WM_CANCELMODE`, `WM_LBUTTONUP`, and `ClearText()`. |
| `6.3` | `RedMonitor` async File Open / Save, `IDM_FILE_NEW` & filter presets ([RedMonitor.cpp](../../../src/RedMonitor.cpp)) | Parallel `g_monitorFileOpen*` / `g_monitorFileSave*` globals + `PresetFromLegacy` gap (`ISM-25a`, `ISM-25c`) | **Pattern A + B:** `DocumentFileCoordinator` with `sessionEpoch` + exhaustive `MonitorFilterPreset` mapping. |
| `6.4` | `Document` line index, filtered view & color-range caches ([Document.h](../../../src/Document.h), [Document.cpp](../../../src/Document.cpp)) | 6 validity booleans + `AddColorRange` lock-drop TOCTOU (`ISM-DOC`) | Single-lock bounds check in `AddColorRange` + monotonic `_contentEpoch` cache stamp. |
| `6.5` | `EtwListener` real-time trace session & worker ([EtwListener.cpp](../../../src/EtwListener.cpp)) | `_running` boolean + `_sessionHandle` + `_traceHandle` + `_workerThread` | **Pattern A:** `enum class EtwSessionPhase : uint8_t { Stopped, Starting, ProcessingTrace, Stopping }` with RAII trace-handle cleanup on partial startup failure. |
| `6.6` | Producer SDK ([Client.h](../../../include/RedMonitor/Client.h)) | Lock-free atomic state (`0`, `1`, `2`) + `REGHANDLE` | **Positive exemplar — keep 100% unchanged.** |
| `6.7` | File transactions & test runner ([LocalFileTransaction.h](../../../support/LocalFileTransaction.h), [Test-Changes.ps1](../../../Test-Changes.ps1)) | `LocalFileTransaction` (`Active`, `Committed`, `Aborted`); `Test-Changes.ps1` wrapper | Keep `LocalFileTransaction` unchanged; align any `Build/` evidence/lock helpers with Pattern D retry & atomic `.tmp` rules. |

### 3.3 Target C++23 blueprint (`PresentPlan`)

```cpp
enum class PresentKind : uint8_t
{
    Clean = 0,
    PartialScroll,
    FullRedraw,
};

struct PresentPlan final
{
    PresentKind kind = PresentKind::FullRedraw;
    int32_t accumulatedScrollDyPx = 0;

    void RequestFullRedraw() noexcept
    {
        kind = PresentKind::FullRedraw;
        accumulatedScrollDyPx = 0;
    }

    void RequestScrollDelta(int32_t deltaPx, int32_t viewportHeightPx) noexcept
    {
        if (deltaPx == 0 || kind == PresentKind::FullRedraw)
        {
            return; // Never downgrade FullRedraw to PartialScroll.
        }
        const int64_t nextDy = static_cast<int64_t>(accumulatedScrollDyPx) + deltaPx;
        if (viewportHeightPx <= 0 || std::abs(nextDy) >= viewportHeightPx)
        {
            RequestFullRedraw();
            return;
        }
        kind = PresentKind::PartialScroll;
        accumulatedScrollDyPx = static_cast<int32_t>(nextDy);
    }

    [[nodiscard]] PresentPlan ConsumeForRender() noexcept
    {
        return std::exchange(*this, PresentPlan{PresentKind::Clean, 0});
    }
};
```

## 4. Ordered implementation slices

1. **Slice S0 — Drift check & deterministic state-transition unit tests (`Tests/MonitorTest.vcxproj`)**:
   - Run Section 1 drift checks.
   - Add headless deterministic tests in `Tests/` covering:
     1. Coalesced multi-step `InvalidateExposedArea` scroll deltas preserving total pixel delta, and `FullRedraw` + `InvalidateExposedArea` never downgrading to `PartialScroll` (`ISM-08a`).
     2. `SetFilterMask` incrementing layout/width sequence counters and rejecting stale pre-filter worker slice completions (`ISM-08b`).
     3. Synthetic `WM_CAPTURECHANGED` and `ClearText()` cancelling active selection and scrollbar drags (`ISM-25b`).
     4. `IDM_FILE_NEW` cancelling/invalidating an in-flight File Open generation (`ISM-25a`) and `MonitorFilterPreset` round-tripping all menu presets including `IDM_FILTER_PRESET_ERRORS_DEBUG` (`ISM-25c`).
     5. Concurrent `Document::AddColorRange` + append bounds safety (`ISM-DOC`).
2. **Slice S1 — `ColorTextView` `PresentPlan`, `InvalidateSliceLayout`, and `PointerCaptureState` (`6.1`, `6.2`)**:
   - Implement `PresentPlan`, `InvalidateSliceLayout()`, and `PointerCaptureState` in [ColorTextView.h](../../../src/ColorTextView.h) and [ColorTextView.cpp](../../../src/ColorTextView.cpp); remove unused `_sliceDirtyRegion`/`_sliceCmd`.
3. **Slice S2 — `DocumentFileCoordinator`, `MonitorFilterPreset`, `Document` epoch & `EtwSessionPhase` (`6.3`–`6.5`)**:
   - Refactor async file state and preset mapping in [RedMonitor.cpp](../../../src/RedMonitor.cpp), tighten `AddColorRange` lock scope in [Document.cpp](../../../src/Document.cpp), and introduce `EtwSessionPhase` in [EtwListener.cpp](../../../src/EtwListener.cpp).
4. **Slice S3 — Specification reconciliation & qualification**:
   - Update [Core_Architecture.md](../../Core/Core_Architecture.md) and [Testing_Validation.md](../../Testing/Testing_Validation.md) with the durable presentation, filter-sequence, capture-cancellation, and file-session invariants.

## 5. Validation commands and expected outcomes

```powershell
pwsh -NoProfile -File ./validate.ps1
pwsh -NoProfile -File ./Tools/Test-Changelog.ps1 -Base origin/main
pwsh -NoProfile -File ./format.ps1 -Check
pwsh -NoProfile -File ./Test-Changes.ps1
pwsh -NoProfile -File ./test.ps1 -Platform x64 -Configuration Debug
pwsh -NoProfile -File ./test.ps1 -Platform x64 -Configuration Release
pwsh -NoProfile -File ./test.ps1 -Platform x64 -Configuration "ASan Debug"
pwsh -NoProfile -File ./build.ps1 -Platform ARM64 -Configuration Debug
pwsh -NoProfile -File ./build.ps1 -Platform ARM64 -Configuration Release
pwsh -NoProfile -File ./build.ps1 -Platform ARM64 -Configuration "ASan Debug"
```

- **Static & formatting checks**: `validate.ps1`, `Test-Changelog.ps1 -Base origin/main`, and `format.ps1 -Check` pass with zero findings; `git diff -- include/RedMonitor/Client.h Dependencies/DxUi.lock.json` is empty.
- **Native builds & headless tests**: All six `x64`/`ARM64` configurations compile with zero warnings; `x64` `Debug`, `Release`, and `ASan Debug` test suites pass without stealing foreground focus.
- **Separate qualification gates**: Native `ARM64` runtime execution, elevated live ETW session tests, physical DPI/accessibility checks, and paired scroll-performance receipts remain distinct under [Testing_Validation.md](../../Testing/Testing_Validation.md) and `S8` of [RedMonitorExtraction_2026-10-21.md](RedMonitorExtraction_2026-10-21.md).

## 6. Out-of-scope boundaries, rollback and stop conditions

- **Out of scope**: Modifying [Client.h](../../../include/RedMonitor/Client.h), changing consumer repositories, bumping `DxUi.lock.json`, or altering the settings-schema cutover owned by `S4` of [RedMonitorExtraction_2026-10-21.md](RedMonitorExtraction_2026-10-21.md).
- **Stop conditions**:
  - Stop immediately if any edit alters `include/RedMonitor/Client.h` or requires a consumer pin update.
  - Stop if `S4` in [RedMonitorExtraction_2026-10-21.md](RedMonitorExtraction_2026-10-21.md) has refactored `MonitorFilterPreset` on `main`; reconcile `ISM-25c` against the new `Common/Settings` schema first.
- **Rollback**: Slices `S1` and `S2` touch disjoint translation units (`ColorTextView.*` vs `RedMonitor.cpp`/`Document.*`/`EtwListener.*`) and revert cleanly per commit.

## 7. Done criteria and closeout

1. Slices `S0`–`S3` pass all static checks, six-configuration builds, and `x64` `Debug`/`Release`/`ASan Debug` headless suites with zero warnings.
2. Durable state invariants are merged into [Core_Architecture.md](../../Core/Core_Architecture.md) and [Testing_Validation.md](../../Testing/Testing_Validation.md).
3. Move this file to `Specs/Plans/Done/ExplicitStateMachines_2026-11-10.md`, remove its bullet from `Specs/Plans/WIP/README.md`, and add an archive entry to [Done/README.md](../Done/README.md).
