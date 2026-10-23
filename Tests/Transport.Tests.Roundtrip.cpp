#define REDMONITOR_DEFINE_PROVIDER
#include <RedMonitor/Application.h>

#define REDSAL_DEFINE_TRACE_PROVIDER
#include "EtwListener.h"
#include "Helpers.h"
#include "TestSupport/TestSupport.Tests.FailureReports.h"

#include <atomic>
#include <cstdio>
#include <mutex>
#include <string>

int wmain(int argc, wchar_t** argv)
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
    RedMonitor::Application provider(L"RedPrism");
    if (provider.Status() != ERROR_SUCCESS)
    {
        return 1;
    }
    struct State
    {
        std::wstring expected = L"[RedPrism] RedMonitor roundtrip \u00e9\u65e5\U0001F642";
        wil::unique_event received;
        std::atomic<bool> valid{false};
        std::atomic<DWORD> producerThread{GetCurrentThreadId()};
        std::atomic<DWORD> producerProcess{GetCurrentProcessId()};
    };
    // Bounded Stop may detach shared callback state; the callback owns everything it accesses.
    const auto state     = std::make_shared<State>();
    const bool childMode = argc == 3;
    if (childMode)
        state->expected = L"[" + std::wstring(argv[2]) + L"] diagnostic probe \u00e9\u65e5\U0001F642";
    state->received.create();
    EtwListener listener;
    if (! listener.Start(
            [state](const Debug::InfoParam& info, const std::wstring& message)
    {
        if (message == state->expected)
        {
            state->valid.store(info.processID == state->producerProcess && info.threadID == state->producerThread &&
                               info.type == Debug::InfoParam::Type::Warning && (info.time.dwLowDateTime != 0 || info.time.dwHighDateTime != 0));
            SetEvent(state->received.get());
        }
    },
            2'000u))
    {
        std::fprintf(stderr, "ETW session unavailable: %lu\n", listener.GetLastErrorCode());
        return 2;
    }
    wil::unique_handle child;
    if (childMode)
    {
        std::wstring command = L"\"" + std::wstring(argv[1]) + L"\" --redmonitor-probe";
        STARTUPINFOW startup{};
        startup.cb = sizeof(startup);
        PROCESS_INFORMATION process{};
        if (! CreateProcessW(argv[1], command.data(), nullptr, nullptr, FALSE, CREATE_SUSPENDED | CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process))
            return 5;
        child.reset(process.hProcess);
        wil::unique_handle thread(process.hThread);
        state->producerProcess = process.dwProcessId;
        state->producerThread  = process.dwThreadId;
        if (ResumeThread(thread.get()) == static_cast<DWORD>(-1))
        {
            TerminateProcess(child.get(), 6); // Only this newly created suspended test probe is owned here.
            return 6;
        }
    }
    else if (! provider.IsEnabled() ||
             provider.WriteUtf8(RedMonitor::Severity::Warning, "RedMonitor roundtrip \xc3\xa9\xe6\x97\xa5\xf0\x9f\x99\x82") != ERROR_SUCCESS)
    {
        return 3;
    }
    const DWORD wait = WaitForSingleObject(state->received.get(), 8000);
    listener.Stop();
    if (child)
    {
        if (WaitForSingleObject(child.get(), 8000) != WAIT_OBJECT_0)
        {
            TerminateProcess(child.get(), 7); // The test's own probe, never an independently launched app.
            WaitForSingleObject(child.get(), 2000);
            return 7;
        }
        DWORD code{};
        if (! GetExitCodeProcess(child.get(), &code) || code != 0)
            return 8;
    }
    if (wait != WAIT_OBJECT_0 || ! state->valid.load())
    {
        std::fputs("ETW roundtrip metadata/text mismatch or timeout\n", stderr);
        return 4;
    }
    std::puts("PASS: real ETW roundtrip with exact Unicode, severity, PID, TID and timestamp");
    return 0;
}
