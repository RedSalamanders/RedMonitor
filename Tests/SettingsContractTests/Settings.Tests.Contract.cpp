#define REDSAL_DEFINE_TRACE_PROVIDER
#include "Helpers.h"
#include "SettingsStore.h"
#include "SettingsWatcher.h"
#include "TestSupport.Tests.Runner.h"
#include "TestSupport/TestSupport.Tests.FailureReports.h"

#include <cstdio>
#include <fstream>

namespace
{
[[nodiscard]] bool TakeSettingsChange(HWND window, DWORD timeout) noexcept
{
    const ULONGLONG deadline = GetTickCount64() + timeout;
    for (;;)
    {
        MSG message{};
        if (PeekMessageW(&message, window, SettingsWatcher::ChangedMessage, SettingsWatcher::ChangedMessage, PM_REMOVE))
        {
            return true;
        }
        const ULONGLONG now = GetTickCount64();
        if (now >= deadline ||
            MsgWaitForMultipleObjectsEx(0, nullptr, static_cast<DWORD>(deadline - now), QS_POSTMESSAGE, MWMO_INPUTAVAILABLE) != WAIT_OBJECT_0)
        {
            return false;
        }
    }
}

[[nodiscard]] bool CheckSettingsWatcher()
{
    std::error_code error;
    const auto fixture = RedSalamander::TestSupport::AcquireTestDirectory({L"SettingsTests", L"watcher", L"watch"}, error);
    if (error || fixture.empty())
    {
        std::fputs("Settings watcher requires an authorized fixture directory.\n", stderr);
        return false;
    }

    const wil::unique_hwnd receiver(CreateWindowExW(0, L"STATIC", nullptr, 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr));
    const auto directory = fixture / L"Settings";
    SettingsWatcher watcher;
    if (! receiver || FAILED(watcher.Start(receiver.get(), directory)) || ! TakeSettingsChange(receiver.get(), 5000))
    {
        std::fputs("Settings watcher did not post its startup notification.\n", stderr);
        return false;
    }
    watcher.Acknowledge();
    if (! std::filesystem::create_directory(directory, error) || error || ! TakeSettingsChange(receiver.get(), 5000))
    {
        std::fputs("Settings watcher missed the creation of its settings directory.\n", stderr);
        return false;
    }
    watcher.Acknowledge();

    const auto file  = directory / L"fixture.settings.json";
    const auto write = [&file]()
    {
        std::ofstream stream(file, std::ios::binary | std::ios::trunc);
        stream << "{}";
        stream.close();
        return stream.good();
    };
    if (! write() || ! TakeSettingsChange(receiver.get(), 5000))
    {
        std::fputs("Settings watcher missed a file created in its settings directory.\n", stderr);
        return false;
    }
    watcher.Stop();
    (void)TakeSettingsChange(receiver.get(), 0);
    if (! write() || TakeSettingsChange(receiver.get(), 150))
    {
        std::fputs("Settings watcher did not stop before its receiver was destroyed.\n", stderr);
        return false;
    }

    std::puts("PASS: settings watcher follows directory creation, posts file changes, and stops before window teardown");
    return true;
}
} // namespace

int main(int argc, char** argv)
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
    if (argc == 2 && std::strcmp(argv[1], "--failure-report-self-test") == 0)
        return RedSalamander::TestSupport::RunFailureReportRoutingSelfTest();
    if (argc == 2 && std::strcmp(argv[1], "--settings-watch-self-test") == 0)
        return CheckSettingsWatcher() ? 0 : 1;
    const auto path = Common::Settings::GetSettingsPath(L"RedSalamanderMonitor");
#if defined(_DEBUG)
    constexpr auto expected = L"RedSalamanderMonitor-debug.settings.json";
#else
    constexpr auto expected = L"RedSalamanderMonitor-7.0.settings.json";
#endif
    if (path.filename() != expected || path.parent_path().filename() != L"Settings")
    {
        std::fputs("Legacy monitor settings path changed with independent product version\n", stderr);
        return 1;
    }
    std::puts("PASS: legacy settings path is independent of the RedMonitor product version; no user file was opened");
    return 0;
}
