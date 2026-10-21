#define REDMONITOR_DEFINE_PROVIDER
#include <RedMonitor/Client.h>

#define REDSAL_DEFINE_TRACE_PROVIDER
#include "EtwListener.h"
#include "Helpers.h"
#include "TestSupport/TestSupport.Tests.FailureReports.h"

#include <atomic>
#include <cstdio>
#include <mutex>
#include <string>

int main()
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
    RedMonitor::Provider provider;
    if (provider.Status() != ERROR_SUCCESS)
    {
        return 1;
    }
    struct State
    {
        std::wstring expected = L"RedMonitor roundtrip \u00e9\u65e5\U0001F642";
        wil::unique_event received;
        std::atomic<bool> valid{false};
        DWORD producerThread = GetCurrentThreadId();
    };
    // Bounded Stop may detach shared callback state; the callback owns everything it accesses.
    const auto state = std::make_shared<State>();
    state->received.create();
    EtwListener listener;
    if (! listener.Start(
            [state](const Debug::InfoParam& info, const std::wstring& message)
    {
        if (message == state->expected)
        {
            state->valid.store(info.processID == GetCurrentProcessId() && info.threadID == state->producerThread &&
                               info.type == Debug::InfoParam::Type::Warning && (info.time.dwLowDateTime != 0 || info.time.dwHighDateTime != 0));
            SetEvent(state->received.get());
        }
    },
            2'000u))
    {
        std::fprintf(stderr, "ETW session unavailable: %lu\n", listener.GetLastErrorCode());
        return 2;
    }
    if (! provider.IsEnabled() || provider.Write(RedMonitor::Severity::Warning, state->expected) != ERROR_SUCCESS)
    {
        return 3;
    }
    const DWORD wait = WaitForSingleObject(state->received.get(), 8000);
    listener.Stop();
    if (wait != WAIT_OBJECT_0 || ! state->valid.load())
    {
        std::fputs("ETW roundtrip metadata/text mismatch or timeout\n", stderr);
        return 4;
    }
    std::puts("PASS: real ETW roundtrip with exact Unicode, severity, PID, TID and timestamp");
    return 0;
}
