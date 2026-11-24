#include "CrashReports.h"

#include <algorithm>
#include <array>
#include <bit>
#include <csignal>
#include <cstdlib>
#include <exception>
#include <string_view>

#include <dbghelp.h>
#include <shlobj.h>
#include <strsafe.h>

#pragma warning(push)
#pragma warning(disable : 4625 4626 5026 5027) // WIL move-only resource wrappers.
#include <wil/resource.h>
#pragma warning(pop)

namespace RedSalamanderMonitor::CrashReports
{
namespace
{
constexpr std::wstring_view kReportPrefix  = L"RedMonitor-report-";
constexpr std::wstring_view kDumpExtension = L".dmp";
constexpr wchar_t kMarkerName[]            = L"pending.txt";
constexpr size_t kPathCapacity             = 1152;
constexpr DWORD kExcludedAttributes        = FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT | FILE_ATTRIBUTE_DEVICE;
std::array<wchar_t, 1024> g_crashDirectory{};
wil::unique_hmodule g_dbgHelp;
decltype(&MiniDumpWriteDump) g_writeDump = nullptr;
wil::unique_handle g_dumpFinished;
volatile LONG g_ownerThread{};

bool IsReportName(std::wstring_view name) noexcept
{
    return name.starts_with(kReportPrefix) && name.ends_with(kDumpExtension) && name.find_first_of(L"\\/:") == std::wstring_view::npos &&
           ! name.contains(L'\0');
}

bool IsOrdinaryFile(HANDLE file) noexcept
{
    BY_HANDLE_FILE_INFORMATION info{};
    return GetFileInformationByHandle(file, &info) && (info.dwFileAttributes & kExcludedAttributes) == 0;
}

bool MarkForRemoval(HANDLE file) noexcept
{
    FILE_DISPOSITION_INFO disposition{TRUE};
    return SetFileInformationByHandle(file, FileDispositionInfo, &disposition, sizeof(disposition)) != FALSE;
}

HRESULT PrepareDirectory(const std::filesystem::path& directory)
{
    if (! directory.is_absolute() || directory != directory.lexically_normal() || directory.native().size() >= g_crashDirectory.size())
        return E_INVALIDARG;

    auto path = directory.root_path();
    if (GetDriveTypeW(path.c_str()) != DRIVE_FIXED)
        return HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED);

    // Check each existing component before appending the next one.
    for (const auto& component : directory.relative_path())
    {
        path /= component;
        DWORD attrs = GetFileAttributesW(path.c_str());
        if (attrs == INVALID_FILE_ATTRIBUTES)
        {
            const DWORD error = GetLastError();
            if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND)
                return HRESULT_FROM_WIN32(error);

            if (! CreateDirectoryW(path.c_str(), nullptr) && GetLastError() != ERROR_ALREADY_EXISTS)
                return HRESULT_FROM_WIN32(GetLastError());
            attrs = GetFileAttributesW(path.c_str());
        }
        if (attrs == INVALID_FILE_ATTRIBUTES || (attrs & FILE_ATTRIBUTE_DIRECTORY) == 0 || (attrs & FILE_ATTRIBUTE_REPARSE_POINT) != 0)
            return HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED);
    }
    return S_OK;
}

void PublishMarker(const wchar_t* dump) noexcept
{
    wchar_t marker[kPathCapacity]{};
    wchar_t temporary[kPathCapacity]{};
    if (FAILED(StringCchPrintfW(marker, std::size(marker), L"%s\\%s", g_crashDirectory.data(), kMarkerName)) ||
        FAILED(StringCchPrintfW(temporary, std::size(temporary), L"%s.pending", dump)))
        return;

    wil::unique_hfile pending(CreateFileW(temporary, GENERIC_WRITE | DELETE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr));
    if (! pending)
        return;

    const wchar_t* leaf = dump + wcslen(g_crashDirectory.data()) + 1;
    const DWORD bytes   = static_cast<DWORD>(wcslen(leaf) * sizeof(wchar_t));
    DWORD written{};
    if (! WriteFile(pending.get(), leaf, bytes, &written, nullptr) || written != bytes || ! FlushFileBuffers(pending.get()))
    {
        (void)MarkForRemoval(pending.get());
        return;
    }
    pending.reset();
    if (! MoveFileExW(temporary, marker, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH))
        (void)DeleteFileW(temporary);
}

void WriteReport(EXCEPTION_POINTERS* exception) noexcept
{
    if (! g_writeDump)
        return;

    const DWORD thread = GetCurrentThreadId();
    const LONG owner   = InterlockedCompareExchange(&g_ownerThread, static_cast<LONG>(thread), 0);
    if (owner != 0)
    {
        if (owner != static_cast<LONG>(thread))
            (void)WaitForSingleObject(g_dumpFinished.get(), 10000);
        return;
    }
    const auto finished = wil::scope_exit([]() noexcept { (void)SetEvent(g_dumpFinished.get()); });

    SYSTEMTIME time{};
    GetSystemTime(&time);
    FILETIME created{}, exited{}, kernel{}, user{};
    if (! GetProcessTimes(GetCurrentProcess(), &created, &exited, &kernel, &user))
        return;
    ULARGE_INTEGER stamp{};
    stamp.LowPart  = created.dwLowDateTime;
    stamp.HighPart = created.dwHighDateTime;

    wchar_t dump[kPathCapacity]{};
    if (FAILED(StringCchPrintfW(dump,
                                std::size(dump),
                                L"%s\\%s%04u%02u%02u-%02u%02u%02u-%lu-%016llx.dmp",
                                g_crashDirectory.data(),
                                kReportPrefix.data(),
                                static_cast<unsigned>(time.wYear),
                                static_cast<unsigned>(time.wMonth),
                                static_cast<unsigned>(time.wDay),
                                static_cast<unsigned>(time.wHour),
                                static_cast<unsigned>(time.wMinute),
                                static_cast<unsigned>(time.wSecond),
                                GetCurrentProcessId(),
                                stamp.QuadPart)))
        return;

    wil::unique_hfile file(CreateFileW(dump, GENERIC_WRITE | DELETE, 0, nullptr, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr));
    if (! file)
        return;

    MINIDUMP_EXCEPTION_INFORMATION info{thread, exception, FALSE};
    if (! g_writeDump(GetCurrentProcess(), GetCurrentProcessId(), file.get(), MiniDumpNormal, exception ? &info : nullptr, nullptr, nullptr) ||
        ! FlushFileBuffers(file.get()))
    {
        (void)MarkForRemoval(file.get());
        return;
    }
    file.reset();
    PublishMarker(dump);
}

[[noreturn]] void Fatal(DWORD code) noexcept
{
    CONTEXT context{};
    RtlCaptureContext(&context);
    EXCEPTION_RECORD record{};
    record.ExceptionCode  = code;
    record.ExceptionFlags = EXCEPTION_NONCONTINUABLE;
#if defined(_M_ARM64)
    record.ExceptionAddress = reinterpret_cast<void*>(context.Pc);
#else
    record.ExceptionAddress = reinterpret_cast<void*>(context.Rip);
#endif
    EXCEPTION_POINTERS exception{&record, &context};
    (void)HandleException(&exception);
    __fastfail(FAST_FAIL_FATAL_APP_EXIT);
}

void Terminated() noexcept
{
    Fatal(0xE0524D01);
}

void InvalidParameter(const wchar_t*, const wchar_t*, const wchar_t*, unsigned, uintptr_t) noexcept
{
    Fatal(0xE0524D02);
}

void PureCall() noexcept
{
    Fatal(0xE0524D03);
}

void Aborted(int) noexcept
{
    Fatal(0xE0524D04);
}

void RemoveStaleDump(const std::filesystem::path& directory, const WIN32_FIND_DATAW& found)
{
    const auto path = directory / found.cFileName;
    wil::unique_hfile file(CreateFileW(path.c_str(), DELETE | FILE_READ_ATTRIBUTES, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
    FILETIME written{};
    if (file && IsOrdinaryFile(file.get()) && GetFileTime(file.get(), nullptr, nullptr, &written) && CompareFileTime(&written, &found.ftLastWriteTime) == 0)
        (void)MarkForRemoval(file.get());
}
} // namespace

std::filesystem::path LocalDirectory()
{
    wil::unique_cotaskmem_string localAppData;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, localAppData.put())) || ! localAppData)
        return {};

    return std::filesystem::path(localAppData.get()) / L"RedMonitor" / L"Crashes";
}

HRESULT Install(const std::filesystem::path& directory)
{
    const HRESULT prepared = PrepareDirectory(directory);
    if (FAILED(prepared))
        return prepared;

    const HRESULT copied = StringCchCopyW(g_crashDirectory.data(), g_crashDirectory.size(), directory.c_str());
    if (FAILED(copied))
        return copied;

    g_dumpFinished.reset(CreateEventW(nullptr, TRUE, FALSE, nullptr));
    if (! g_dumpFinished)
        return HRESULT_FROM_WIN32(GetLastError());

    g_dbgHelp.reset(LoadLibraryExW(L"DbgHelp.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32));
    if (! g_dbgHelp)
        return HRESULT_FROM_WIN32(GetLastError());

    g_writeDump = std::bit_cast<decltype(g_writeDump)>(GetProcAddress(g_dbgHelp.get(), "MiniDumpWriteDump"));
    if (! g_writeDump)
        return HRESULT_FROM_WIN32(GetLastError());

    ULONG stackBytes = 64 * 1024;
    if (! SetThreadStackGuarantee(&stackBytes))
        return HRESULT_FROM_WIN32(GetLastError());

    SetUnhandledExceptionFilter(HandleException);
    std::set_terminate(Terminated);
    _set_invalid_parameter_handler(InvalidParameter);
    _set_purecall_handler(PureCall);
    (void)signal(SIGABRT, Aborted);
    return S_OK;
}

LONG WINAPI HandleException(EXCEPTION_POINTERS* exception) noexcept
{
    WriteReport(exception);
    const DWORD code = exception && exception->ExceptionRecord ? exception->ExceptionRecord->ExceptionCode : ERROR_UNHANDLED_EXCEPTION;
    TerminateProcess(GetCurrentProcess(), code);
    return EXCEPTION_EXECUTE_HANDLER;
}

void RetainRecent(const std::filesystem::path& directory)
{
    const auto pattern = directory / L"RedMonitor-report-*.dmp";
    WIN32_FIND_DATAW found{};
    wil::unique_hfind cursor(FindFirstFileW(pattern.c_str(), &found));
    if (! cursor)
        return;

    const auto older = [](const WIN32_FIND_DATAW& lhs, const WIN32_FIND_DATAW& rhs) noexcept
    {
        const LONG order = CompareFileTime(&lhs.ftLastWriteTime, &rhs.ftLastWriteTime);
        return order < 0 || (order == 0 && std::wstring_view(lhs.cFileName) < std::wstring_view(rhs.cFileName));
    };
    std::array<WIN32_FIND_DATAW, 10> retained{};
    size_t count{};
    do
    {
        if ((found.dwFileAttributes & kExcludedAttributes) != 0 || ! IsReportName(found.cFileName))
            continue;
        if (count < retained.size())
        {
            retained[count++] = found;
            continue;
        }
        auto oldest = std::ranges::min_element(retained, older);
        if (older(found, *oldest))
        {
            RemoveStaleDump(directory, found);
        }
        else
        {
            RemoveStaleDump(directory, *oldest);
            *oldest = found;
        }
    } while (FindNextFileW(cursor.get(), &found));
}

std::optional<std::filesystem::path> TakePendingNotice(const std::filesystem::path& directory, bool interactive)
{
    if (! interactive)
        return std::nullopt;

    const auto path = directory / kMarkerName;
    wil::unique_hfile pending(CreateFileW(path.c_str(), GENERIC_READ | DELETE, FILE_SHARE_READ, nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
    if (! pending || ! IsOrdinaryFile(pending.get()))
        return std::nullopt;

    // DELETE access with no delete sharing ensures only one startup can claim the marker.
    wchar_t leaf[MAX_PATH]{};
    DWORD read{};
    if (! ReadFile(pending.get(), leaf, sizeof(leaf), &read, nullptr) || ! MarkForRemoval(pending.get()) || read == 0 || read >= sizeof(leaf) ||
        read % sizeof(wchar_t) != 0)
        return std::nullopt;

    const std::wstring_view name(leaf, read / sizeof(wchar_t));
    if (! IsReportName(name))
        return std::nullopt;
    auto dump         = directory / name;
    const DWORD attrs = GetFileAttributesW(dump.c_str());
    if (attrs == INVALID_FILE_ATTRIBUTES || (attrs & kExcludedAttributes) != 0)
        return std::nullopt;

    return dump;
}
} // namespace RedSalamanderMonitor::CrashReports
