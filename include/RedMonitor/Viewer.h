#pragma once

// Optional launch convenience; the producer-only Client/Application headers need no WIL.
#include "Client.h"
#include <string>
#include <string_view>
#include <wil/resource.h>
#include <windows.h>

namespace RedMonitor
{
[[nodiscard]] inline std::wstring ViewerPath(std::wstring_view executable)
{
    const auto separator = executable.find_last_of(L"\\/");
    if (separator == std::wstring_view::npos)
        return {};
    return std::wstring(executable.substr(0, separator + 1)) + L"RedMonitor\\RedMonitor.exe";
}

// An explicit command only: fixed adjacent path, no shell/PATH lookup, no settings or
// document access and no wait for the viewer. The viewer owns its single-instance guard.
[[nodiscard]] inline DWORD LaunchViewer()
{
    std::wstring executable(32768, L'\0');
    const DWORD count = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
    if (count == 0)
        return GetLastError();
    if (count >= executable.size())
        return ERROR_FILENAME_EXCED_RANGE;
    executable.resize(count);
    const auto path = ViewerPath(executable);
    if (path.empty() || path.size() >= 32767)
        return ERROR_FILENAME_EXCED_RANGE;
    auto command = L"\"" + path + L"\"";
    STARTUPINFOW startup{};
    startup.cb = sizeof(startup);
    PROCESS_INFORMATION process{};
    if (! CreateProcessW(path.c_str(), command.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &startup, &process))
        return GetLastError();
    wil::unique_handle thread(process.hThread);
    wil::unique_handle owner(process.hProcess);
    return ERROR_SUCCESS;
}
} // namespace RedMonitor
