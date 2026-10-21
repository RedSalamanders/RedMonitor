#pragma once

#include <filesystem>
#include <string>
#include <string_view>
#include <system_error>
#include <windows.h>

// The imported tests need only a fresh per-case directory, not RedSalamander's drive-root sandbox.
// test.ps1 supplies a unique, repository-local root. Never clean or follow an existing directory.
namespace RedSalamander::TestSupport
{
struct TestDirectoryOptions
{
    std::wstring_view harnessSegment;
    std::wstring_view leafSegment;
    std::wstring_view fallbackRunIdPrefix;
};

inline std::filesystem::path AcquireTestDirectory(const TestDirectoryOptions& options, std::error_code& error)
{
    wchar_t buffer[32768]{};
    const DWORD length = GetEnvironmentVariableW(L"REDMONITOR_TEST_ROOT", buffer, static_cast<DWORD>(std::size(buffer)));
    if (length == 0 || length >= std::size(buffer))
    {
        error = std::make_error_code(std::errc::invalid_argument);
        return {};
    }
    for (const auto segment : {options.harnessSegment, options.leafSegment})
    {
        if (segment.empty() || segment.find_first_not_of(L"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-") != std::wstring_view::npos)
        {
            error = std::make_error_code(std::errc::invalid_argument);
            return {};
        }
    }
    const std::filesystem::path root(buffer);
    const std::filesystem::path destination = root / options.harnessSegment / options.leafSegment;
    for (auto current = root; ! current.empty(); current = current.parent_path())
    {
        const DWORD attributes = GetFileAttributesW(current.c_str());
        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
        {
            error = std::make_error_code(std::errc::permission_denied);
            return {};
        }
        if (current == current.parent_path())
        {
            break;
        }
    }
    if (! std::filesystem::create_directories(destination, error))
    {
        if (! error)
        {
            error = std::make_error_code(std::errc::file_exists);
        }
        return {};
    }
    return destination;
}
} // namespace RedSalamander::TestSupport
