#pragma once

#include "MonitorTextSnapshot.h"

#include <cstddef>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <optional>
#include <stop_token>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

namespace RedSalamanderMonitor
{
inline constexpr HRESULT kMonitorFileExportConflict = HRESULT_FROM_WIN32(ERROR_REVISION_MISMATCH);

struct MonitorFileExportVersion
{
    uint64_t fileIndex       = 0u;
    uint64_t fileSize        = 0u;
    int64_t lastWriteTime    = 0;
    int64_t changeTime       = 0;
    DWORD volumeSerialNumber = 0u;

    bool operator==(const MonitorFileExportVersion&) const noexcept = default;
};

struct MonitorFileExportTarget
{
    std::filesystem::path path;
    // An absent version authorizes creation only.
    std::optional<MonitorFileExportVersion> acceptedVersion;
};

struct MonitorFileExportResult
{
    HRESULT hr            = E_FAIL;
    uint64_t bytesWritten = 0u;
    size_t lineCount      = 0u;
};

using MonitorFileExportProgress = std::function<void(uint64_t bytesWritten, size_t completedLines)>;

[[nodiscard]] HRESULT ObserveMonitorFileExportTarget(MonitorFileExportTarget& target) noexcept;

[[nodiscard]] MonitorFileExportResult WriteMonitorTextSnapshot(const MonitorFileExportTarget& target,
                                                               const MonitorTextSnapshot& snapshot,
                                                               std::stop_token stopToken,
                                                               const MonitorFileExportProgress& progress = {});
} // namespace RedSalamanderMonitor
