#define REDMONITOR_DEFINE_PROVIDER
#include <RedMonitor/Client.h>

#include <array>
#include <cstdio>
#include <string>

#include "TestSupport/TestSupport.Tests.FailureReports.h"

namespace
{
[[nodiscard]] bool CheckClientCondition(bool condition, const char* message) noexcept
{
    if (! condition)
    {
        std::fprintf(stderr, "FAILED: %s\n", message);
    }
    return condition;
}
} // namespace

int wmain(int argc, wchar_t** argv)
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
    if (argc == 2 && std::wstring_view(argv[1]) == L"--ci-assertion-probe")
    {
        return CheckClientCondition(false, "CI_ASSERTION_PROBE") ? 0 : 21;
    }
    if (argc == 3)
    {
        const bool expected = std::wstring_view(argv[1]) == L"--expect-production";
        if (RedMonitor::IsProductionViewer(argv[2]) != expected)
            return 9;
        std::puts("PASS: installed helper production metadata contract");
        return 0;
    }
    constexpr std::array severities{RedMonitor::Severity::Text,
                                    RedMonitor::Severity::Error,
                                    RedMonitor::Severity::Warning,
                                    RedMonitor::Severity::Info,
                                    RedMonitor::Severity::Perf,
                                    RedMonitor::Severity::Debug};
    for (size_t index = 0; index < severities.size(); ++index)
    {
        if (! CheckClientCondition(RedMonitor::FilterBit(severities[index]) == (1u << index), "severity-to-filter mapping"))
        {
            return 1;
        }
    }
    for (unsigned int cycle = 0; cycle < 3; ++cycle)
    {
        RedMonitor::Provider owner;
        if (owner.Status() != ERROR_SUCCESS)
        {
            return 2;
        }
        {
            RedMonitor::Provider duplicate;
            if (duplicate.Status() != ERROR_ALREADY_EXISTS || duplicate.Write(RedMonitor::Severity::Info, L"duplicate") != ERROR_ALREADY_EXISTS)
            {
                return 3;
            }
        }
        const wchar_t sentinel = L'x';
        const std::wstring_view oversized(&sentinel, RedMonitor::kMaxMessageCodeUnits + 1);
        if (owner.Write(RedMonitor::Severity::Info, oversized) != ERROR_BUFFER_OVERFLOW ||
            owner.Write(static_cast<RedMonitor::Severity>(63), L"invalid") != ERROR_INVALID_PARAMETER)
        {
            return 4;
        }
        const std::wstring maximum(RedMonitor::kMaxMessageCodeUnits, L'\u03bb');
        if (owner.Write(RedMonitor::Severity::Text, {}) != ERROR_SUCCESS ||
            owner.Write(RedMonitor::Severity::Info, L"RedMonitor client test: \u00e9\u65e5\U0001F642") != ERROR_SUCCESS ||
            owner.Write(RedMonitor::Severity::Debug, maximum) != ERROR_SUCCESS)
        {
            return 5;
        }
    }
    RedMonitor::Application application(L"RedPrism");
    if (application.Status() != ERROR_SUCCESS || application.Write(RedMonitor::Severity::Warning, L"Unicode \u00e9\u65e5\U0001F642") != ERROR_SUCCESS ||
        application.WriteUtf8(RedMonitor::Severity::Info, "bounded host/plugin record") != ERROR_SUCCESS ||
        application.Write(static_cast<RedMonitor::Severity>(63), L"invalid") != ERROR_INVALID_PARAMETER)
        return 6;
    const wchar_t sentinel = L'x';
    if (application.Write(RedMonitor::Severity::Info, {&sentinel, RedMonitor::kMaxMessageCodeUnits}) != ERROR_BUFFER_OVERFLOW)
        return 7;
    if (! RedMonitor::IsViewerCommand(L" \t--redmonitor \r\n") || RedMonitor::IsViewerCommand(L"--redmonitor other") || RedMonitor::IsViewerCommand(L"") ||
        ! RedMonitor::IsOrdinaryStartup(L" \t\r\n") || RedMonitor::IsOrdinaryStartup(L"--help") || RedMonitor::IsProductionViewer(L""))
        return 8;
    std::puts("PASS: severity mapping, repeated registration, Unicode, bounded app labels, UTF-8 and explicit adjacent viewer command");
    return 0;
}
