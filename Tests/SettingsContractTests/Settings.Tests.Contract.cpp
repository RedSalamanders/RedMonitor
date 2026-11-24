#define REDSAL_DEFINE_TRACE_PROVIDER
#include "Helpers.h"
#include "SettingsStore.h"
#include "TestSupport/TestSupport.Tests.FailureReports.h"

#include <cstdio>

int main()
{
    RedSalamander::TestSupport::RouteFailureReportsAwayFromDialogs();
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
