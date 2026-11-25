#define REDSAL_DEFINE_TRACE_PROVIDER
#include "Helpers.h"
#include "PathUtils.h"
#include "SettingsStore.h"
#include "SettingsWatcher.h"
#include "TestSupport.Tests.Runner.h"
#include "TestSupport/TestSupport.Tests.FailureReports.h"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <string_view>

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

[[nodiscard]] bool CheckColdSettingsRecovery()
{
    constexpr wchar_t rootVariable[] = L"REDMONITOR_TEST_ROOT";
    constexpr wchar_t appId[]        = L"RedSalamanderMonitor";
    wchar_t rootText[32768]{};
    const DWORD rootLength = GetEnvironmentVariableW(rootVariable, rootText, static_cast<DWORD>(std::size(rootText)));
    if (rootLength == 0 || rootLength >= std::size(rootText))
    {
        std::fputs("Cold settings recovery requires an owned run directory.\n", stderr);
        return false;
    }

    const auto restoreRoot = wil::scope_exit([&] { SetEnvironmentVariableW(rootVariable, rootText); });
    using namespace Common::Settings;
    if (! SetEnvironmentVariableW(rootVariable, L"relative-settings-test-root") || ! GetSettingsPath(appId).empty() ||
        ! SetEnvironmentVariableW(rootVariable, rootText))
    {
        std::fputs("An invalid settings test root must fail closed.\n", stderr);
        return false;
    }

    const auto profile        = GetSettingsPath(appId);
    const auto ownedDirectory = std::filesystem::path(rootText).lexically_normal() / L"settings-store" / L"RedSalamander" / L"Settings";
    if (profile.empty() || ! Common::Testing::TestSandboxPathEquals(profile.parent_path(), ownedDirectory))
    {
        std::fputs("Settings were not redirected to the owned run directory.\n", stderr);
        return false;
    }
    const std::filesystem::path extendedDirectory(Common::Paths::ToExtendedWin32Path(ownedDirectory.native()));
    const std::filesystem::path extendedProfile(Common::Paths::ToExtendedWin32Path(profile.native()));
    std::error_code error;
    if (! std::filesystem::create_directories(extendedDirectory, error))
    {
        std::fputs("Cold settings recovery needs a fresh fixture directory.\n", stderr);
        return false;
    }

    const auto write = [&](std::string_view text)
    {
        std::ofstream stream(extendedProfile, std::ios::binary | std::ios::trunc);
        stream << text;
        stream.close();
        return stream.good();
    };
    const auto read = [](const std::filesystem::path& path)
    {
        const std::filesystem::path extended(Common::Paths::ToExtendedWin32Path(path.native()));
        std::ifstream stream(extended, std::ios::binary);
        return std::string(std::istreambuf_iterator<char>(stream), {});
    };
    constexpr std::string_view malformed{"{ incomplete"};
    Settings settings;
    if (! write(malformed) || LoadSettings(appId, settings) != S_FALSE || TryLoadSettingsNoRecovery(appId, settings) != S_OK)
    {
        std::fputs("Malformed settings must be backed up before a readable template is installed.\n", stderr);
        return false;
    }

    const auto backupPrefix = profile.filename().native() + L".bad.";
    const auto backupCount  = [&](bool requireMalformedBytes)
    {
        size_t count = 0;
        for (const auto& entry : std::filesystem::directory_iterator(extendedDirectory))
        {
            if (entry.path().filename().native().starts_with(backupPrefix) && (! requireMalformedBytes || read(entry.path()) == malformed))
            {
                ++count;
            }
        }
        return count;
    };
    if (backupCount(false) != 1u || backupCount(true) != 1u)
    {
        std::fputs("The recovery backup must hold the exact malformed bytes.\n", stderr);
        return false;
    }

    for (const auto incompatible : {std::string_view{R"(["foreign settings"])"}, std::string_view{R"({"schemaVersion":999,"source":"foreign"})"}})
    {
        if (! write(incompatible) || LoadSettings(appId, settings) != S_FALSE || SaveSettings(appId, settings) == S_OK || read(profile) != incompatible ||
            backupCount(false) != 1u)
        {
            std::fputs("Readable incompatible settings must stay in place and refuse automatic save.\n", stderr);
            return false;
        }
    }

    std::puts("PASS: cold settings recovery stays in the owned run directory, backs up malformed bytes, and preserves readable incompatible profiles");
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
    if (argc == 2 && std::strcmp(argv[1], "--settings-cold-recovery-self-test") == 0)
        return CheckColdSettingsRecovery() ? 0 : 1;
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
