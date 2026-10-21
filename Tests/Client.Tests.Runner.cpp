#define REDMONITOR_DEFINE_PROVIDER
#include <RedMonitor/Client.h>

#include <array>
#include <cstdio>
#include <string>

#include "TestSupport/TestSupport.Tests.FailureReports.h"

int main()
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
    constexpr std::array severities{RedMonitor::Severity::Text,
                                    RedMonitor::Severity::Error,
                                    RedMonitor::Severity::Warning,
                                    RedMonitor::Severity::Info,
                                    RedMonitor::Severity::Perf,
                                    RedMonitor::Severity::Debug};
    for (size_t index = 0; index < severities.size(); ++index)
    {
        if (RedMonitor::FilterBit(severities[index]) != (1u << index))
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
    std::puts("PASS: severity mapping, duplicate owner, repeated registration, Unicode, empty and bounded payloads");
    return 0;
}
