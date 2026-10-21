#pragma once

#include "Common.Tests.SandboxPath.h"
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
    if (length == 0)
    {
        const DWORD legacyLength               = GetEnvironmentVariableW(L"REDSALAMANDER_TEST_ROOT", buffer, static_cast<DWORD>(std::size(buffer)));
        const std::filesystem::path repository = Common::Testing::FindTestRepositoryRoot(error);
        if (legacyLength == 0 || legacyLength >= std::size(buffer) || error ||
            ! Common::Testing::IsAuthorizedTestSandboxPath(std::filesystem::path(buffer), repository, false, error))
        {
            error = std::make_error_code(std::errc::permission_denied);
            return {};
        }
    }
    if (length >= std::size(buffer))
    {
        error = std::make_error_code(std::errc::invalid_argument);
        return {};
    }
    std::filesystem::path root = std::filesystem::path(buffer).lexically_normal();
    if (length == 0)
    {
        wchar_t runId[161]{};
        const DWORD runLength = GetEnvironmentVariableW(L"REDSALAMANDER_TEST_RUN_ID", runId, static_cast<DWORD>(std::size(runId)));
        const std::wstring_view run(runId);
        if (runLength == 0 || runLength >= std::size(runId) || run == L"." || run == L".." ||
            run.find_first_not_of(L"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-") != std::wstring_view::npos)
        {
            error = std::make_error_code(std::errc::permission_denied);
            return {};
        }
        root /= std::filesystem::path(L"runs") / run / L"scratch" / L"redmonitor";
    }
    else
    {
        wchar_t executable[32768]{};
        const DWORD executableLength = GetModuleFileNameW(nullptr, executable, static_cast<DWORD>(std::size(executable)));
        auto outputRoot              = std::filesystem::path(executable).parent_path();
        while (! outputRoot.empty() && outputRoot.filename() != L".build" && outputRoot != outputRoot.parent_path())
        {
            outputRoot = outputRoot.parent_path();
        }
        const std::wstring prefix   = outputRoot.native() + L"\\";
        const std::wstring selected = root.native();
        if (executableLength == 0 || executableLength >= std::size(executable) || outputRoot.filename() != L".build" || selected.size() <= prefix.size() ||
            CompareStringOrdinal(selected.data(), static_cast<int>(prefix.size()), prefix.data(), static_cast<int>(prefix.size()), TRUE) != CSTR_EQUAL)
        {
            error = std::make_error_code(std::errc::permission_denied);
            return {};
        }
    }
    for (const auto segment : {options.harnessSegment, options.leafSegment})
    {
        if (segment.empty() || segment.find_first_not_of(L"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-") != std::wstring_view::npos)
        {
            error = std::make_error_code(std::errc::invalid_argument);
            return {};
        }
    }
    const std::filesystem::path destination = root / options.harnessSegment / options.leafSegment;
    for (auto current = destination; ! current.empty(); current = current.parent_path())
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
