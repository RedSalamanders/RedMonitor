#include "SettingsWatcher.h"

#include <new>
#include <system_error>
#include <utility>

namespace
{
using unique_change_notification      = wil::unique_any<HANDLE, decltype(&::FindCloseChangeNotification), ::FindCloseChangeNotification>;
constexpr DWORD kFileChanges          = FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_SIZE | FILE_NOTIFY_CHANGE_LAST_WRITE;
constexpr DWORD kDebounceMilliseconds = 100;

[[nodiscard]] unique_change_notification OpenChangeNotification(const std::filesystem::path& directory, bool subtree, DWORD filter) noexcept
{
    const HANDLE handle = FindFirstChangeNotificationW(directory.c_str(), subtree ? TRUE : FALSE, filter);
    return unique_change_notification{handle != INVALID_HANDLE_VALUE ? handle : nullptr};
}

[[nodiscard]] unique_change_notification OpenParentNotification(const std::filesystem::path& directory)
{
    const auto directParent = directory.parent_path();
    for (auto parent = directParent; ! parent.empty();)
    {
        auto notification = OpenChangeNotification(parent, parent != directParent, FILE_NOTIFY_CHANGE_DIR_NAME);
        if (notification)
        {
            return notification;
        }
        auto next = parent.parent_path();
        if (next == parent)
        {
            break;
        }
        parent = std::move(next);
    }
    return {};
}
} // namespace

SettingsWatcher::~SettingsWatcher() noexcept
{
    Stop();
}

HRESULT SettingsWatcher::Start(HWND window, const std::filesystem::path& directory) noexcept
{
    Stop();
    if (! window || directory.empty() || ! directory.is_absolute())
    {
        return E_INVALIDARG;
    }
    try
    {
        _window    = window;
        _directory = directory;
        _stop.reset(CreateEventW(nullptr, TRUE, FALSE, nullptr));
        if (! _stop)
        {
            const DWORD error = GetLastError();
            Stop();
            return error != ERROR_SUCCESS ? HRESULT_FROM_WIN32(error) : E_FAIL;
        }
        _worker = std::jthread([this]() noexcept
        {
            try
            {
                Watch();
            }
            catch (const std::bad_alloc&)
            {
                OutputDebugStringW(L"RedMonitor settings watcher ran out of memory.\n");
            }
        });
        return S_OK;
    }
    catch (const std::bad_alloc&)
    {
        Stop();
        return E_OUTOFMEMORY;
    }
    catch (const std::system_error&)
    {
        Stop();
        return E_FAIL;
    }
}

void SettingsWatcher::Acknowledge() noexcept
{
    _pending.store(false, std::memory_order_release);
}

void SettingsWatcher::Stop() noexcept
{
    if (_stop)
    {
        SetEvent(_stop.get());
    }
    if (_worker.joinable())
    {
        _worker.join();
    }
    _stop.reset();
    _directory.clear();
    _window = nullptr;
    Acknowledge();
}

void SettingsWatcher::Watch()
{
    auto parent = OpenParentNotification(_directory);
    auto files  = OpenChangeNotification(_directory, false, kFileChanges);
    PostChanged();
    while (parent || files)
    {
        const HANDLE first = parent ? parent.get() : files.get();
        const HANDLE handles[]{_stop.get(), first, files.get()};
        const DWORD count = parent && files ? 3U : 2U;
        const DWORD wake  = WaitForMultipleObjects(count, handles, FALSE, INFINITE);
        if (wake < WAIT_OBJECT_0 + 1 || wake >= WAIT_OBJECT_0 + count)
        {
            return;
        }
        if ((parent && wake == WAIT_OBJECT_0 + 1) || ! FindNextChangeNotification(files.get()))
        {
            parent = OpenParentNotification(_directory);
            files  = OpenChangeNotification(_directory, false, kFileChanges);
        }
        if (WaitForSingleObject(_stop.get(), kDebounceMilliseconds) != WAIT_TIMEOUT)
        {
            return;
        }
        PostChanged();
    }
}

void SettingsWatcher::PostChanged() noexcept
{
    if (! _pending.exchange(true, std::memory_order_acq_rel) && ! PostMessageW(_window, ChangedMessage, 0, 0))
    {
        Acknowledge();
    }
}
