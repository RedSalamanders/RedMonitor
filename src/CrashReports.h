#pragma once

#include <filesystem>
#include <optional>
#include <windows.h>

namespace RedSalamanderMonitor::CrashReports
{
[[nodiscard]] std::filesystem::path LocalDirectory();
[[nodiscard]] HRESULT Install(const std::filesystem::path& directory);
LONG WINAPI HandleException(EXCEPTION_POINTERS* exception) noexcept;
void RetainRecent(const std::filesystem::path& directory);
[[nodiscard]] std::optional<std::filesystem::path> TakePendingNotice(const std::filesystem::path& directory, bool interactive);
} // namespace RedSalamanderMonitor::CrashReports
