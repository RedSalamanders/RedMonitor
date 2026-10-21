#pragma once

// Define REDMONITOR_DEFINE_PROVIDER in exactly one translation unit per EXE/DLL before this include.
// Own one Provider per module. Join all producers before destroying it or unloading the module.
#include <atomic>
#include <cstddef>
#include <cstdint>
#include <string_view>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

#include <evntrace.h>

#include <TraceLoggingProvider.h>

#pragma comment(lib, "advapi32.lib")

namespace RedMonitor
{
inline constexpr unsigned int kApiRevision   = 1;
inline constexpr size_t kMaxMessageCodeUnits = 16000;

enum class Severity : uint32_t
{
    Text    = 0,
    Error   = 1,
    Warning = 2,
    Info    = 4,
    Perf    = 8,
    Debug   = 16,
};

[[nodiscard]] constexpr uint32_t FilterBit(Severity severity) noexcept
{
    switch (severity)
    {
        case Severity::Text: return 1;
        case Severity::Error: return 2;
        case Severity::Warning: return 4;
        case Severity::Info: return 8;
        case Severity::Perf: return 16;
        case Severity::Debug: return 32;
        default: return 0;
    }
}

namespace Detail
{
#if defined(REDMONITOR_DEFINE_PROVIDER)
TRACELOGGING_DEFINE_PROVIDER(g_provider, "RedSalamanderMonitor", (0x440c70f6, 0x6c6b, 0x4ff7, 0x9a, 0x3f, 0x0b, 0x7d, 0xb4, 0x11, 0xb3, 0x1a));
#else
TRACELOGGING_DECLARE_PROVIDER(g_provider);
#endif
inline std::atomic<bool> g_hasOwner{false};
} // namespace Detail

class Provider final
{
public:
    Provider() noexcept
    {
        bool expected = false;
        _owns         = Detail::g_hasOwner.compare_exchange_strong(expected, true, std::memory_order_acq_rel);
        _status       = _owns ? TraceLoggingRegister(Detail::g_provider) : ERROR_ALREADY_EXISTS;
    }

    ~Provider() noexcept
    {
        if (_owns)
        {
            if (_status == ERROR_SUCCESS)
            {
                TraceLoggingUnregister(Detail::g_provider);
            }
            Detail::g_hasOwner.store(false, std::memory_order_release);
        }
    }

    Provider(const Provider&)            = delete;
    Provider& operator=(const Provider&) = delete;
    Provider(Provider&&)                 = delete;
    Provider& operator=(Provider&&)      = delete;

    [[nodiscard]] ULONG Status() const noexcept
    {
        return _status;
    }

    [[nodiscard]] bool IsEnabled() const noexcept
    {
        return _status == ERROR_SUCCESS && TraceLoggingProviderEnabled(Detail::g_provider, TRACE_LEVEL_INFORMATION, 1);
    }

    // ERROR_SUCCESS means accepted by ETW or disabled; it does not promise viewer delivery.
    // Applications must check IsEnabled before constructing an expensive formatted message.
    [[nodiscard]] ULONG Write(Severity severity, std::wstring_view message) const noexcept
    {
        if (_status != ERROR_SUCCESS)
        {
            return _status;
        }
        if (FilterBit(severity) == 0)
        {
            return ERROR_INVALID_PARAMETER;
        }
        if (message.size() > kMaxMessageCodeUnits)
        {
            return ERROR_BUFFER_OVERFLOW;
        }
        if (! IsEnabled())
        {
            return ERROR_SUCCESS;
        }
        FILETIME timestamp{};
        GetSystemTimeAsFileTime(&timestamp);
        const uint64_t fileTime = (static_cast<uint64_t>(timestamp.dwHighDateTime) << 32u) | timestamp.dwLowDateTime;
        TraceLoggingWrite(Detail::g_provider,
                          "DebugMessage",
                          TraceLoggingLevel(TRACE_LEVEL_INFORMATION),
                          TraceLoggingKeyword(1),
                          TraceLoggingUInt32(static_cast<uint32_t>(severity), "Type"),
                          TraceLoggingUInt32(GetCurrentProcessId(), "ProcessId"),
                          TraceLoggingUInt32(GetCurrentThreadId(), "ThreadId"),
                          TraceLoggingUInt64(fileTime, "FileTime"),
                          TraceLoggingCountedWideString(message.data() ? message.data() : L"", static_cast<USHORT>(message.size()), "Message"));
        return ERROR_SUCCESS;
    }

private:
    ULONG _status = ERROR_INVALID_HANDLE;
    bool _owns    = false;
};
} // namespace RedMonitor
