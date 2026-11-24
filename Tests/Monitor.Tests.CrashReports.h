#pragma once

#include "CrashReports.h"
#include "TestSupport.Tests.Runner.h"

#include <array>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <system_error>

namespace RedSalamanderMonitor::Testing
{
[[nodiscard]] inline bool RunCrashStoreSelfTest()
{
    std::error_code error;
    const auto root = RedSalamander::TestSupport::AcquireTestDirectory({L"crash-store", L"retention", L""}, error);
    if (error || root.empty())
        return false;

    const auto write = [](const std::filesystem::path& file, const char* contents, std::streamsize bytes)
    {
        std::ofstream stream(file, std::ios::binary);
        stream.write(contents, bytes);
        stream.close();
        return static_cast<bool>(stream);
    };
    const auto legacy = root / L"RedSalamanderMonitor-legacy.dmp";
    const auto other  = root / L"separate.record";
    if (! write(legacy, "legacy", 6) || ! write(other, "other", 5))
        return false;

    CrashReports::RetainRecent(root);
    if (! std::filesystem::exists(legacy) || ! std::filesystem::exists(other))
        return false;

    std::array<std::filesystem::path, 11> reports;
    const auto oldest = std::filesystem::file_time_type::clock::now() - std::chrono::hours(24);
    for (size_t index = 0; index < reports.size(); ++index)
    {
        reports[index] = root / (L"RedMonitor-report-" + std::to_wstring(index) + L".dmp");
        if (! write(reports[index], "dump", 4))
            return false;
        std::filesystem::last_write_time(reports[index], oldest + std::chrono::minutes(index), error);
        if (error)
            return false;
        if (index == 9)
        {
            CrashReports::RetainRecent(root);
            for (size_t kept = 0; kept <= index; ++kept)
                if (! std::filesystem::exists(reports[kept]))
                    return false;
        }
    }

    CrashReports::RetainRecent(root);
    if (std::filesystem::exists(reports.front()) || ! std::filesystem::exists(legacy) || ! std::filesystem::exists(other))
        return false;
    for (size_t index = 1; index < reports.size(); ++index)
        if (! std::filesystem::exists(reports[index]))
            return false;

    const auto marker = root / L"pending.txt";
    const auto name   = reports.back().filename().native();
    if (! write(marker, reinterpret_cast<const char*>(name.data()), static_cast<std::streamsize>(name.size() * sizeof(wchar_t))))
        return false;

    if (CrashReports::TakePendingNotice(root, false) || ! std::filesystem::exists(marker))
        return false;
    return CrashReports::TakePendingNotice(root, true) == reports.back() && ! std::filesystem::exists(marker) && ! CrashReports::TakePendingNotice(root, true);
}
} // namespace RedSalamanderMonitor::Testing
