#pragma once

#include <atomic>
#include <filesystem>
#include <thread>
#include <wil/resource.h>
#include <windows.h>

class SettingsWatcher final
{
public:
    static constexpr UINT ChangedMessage = WM_APP + 0x621;

    SettingsWatcher() = default;
    ~SettingsWatcher() noexcept;
    SettingsWatcher(const SettingsWatcher&)            = delete;
    SettingsWatcher& operator=(const SettingsWatcher&) = delete;

    [[nodiscard]] HRESULT Start(HWND window, const std::filesystem::path& directory) noexcept;
    void Acknowledge() noexcept;
    void Stop() noexcept;

private:
    void Watch();
    void PostChanged() noexcept;

    std::filesystem::path _directory;
    HWND _window = nullptr;
    wil::unique_event_nothrow _stop;
    std::jthread _worker;
    std::atomic_bool _pending = false;
};
