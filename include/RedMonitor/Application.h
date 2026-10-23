#pragma once

#include "Client.h"

#include <algorithm>
#include <array>

namespace RedMonitor
{
// The label is borrowed for the module lifetime. Construct before starting producers;
// destroy only after their workers/callbacks and plugin log forwarding have stopped.
class Application final
{
public:
    explicit Application(std::wstring_view label) noexcept : _label(label)
    {
    }

    [[nodiscard]] ULONG Status() const noexcept
    {
        return _provider.Status();
    }
    [[nodiscard]] bool IsEnabled() const noexcept
    {
        return _provider.IsEnabled();
    }

    [[nodiscard]] ULONG Write(Severity severity, std::wstring_view message) const noexcept
    {
        if (FilterBit(severity) == 0 || _label.empty() || _label.size() > 64)
            return ERROR_INVALID_PARAMETER;
        if (message.size() > kMaxMessageCodeUnits - _label.size() - 3)
            return ERROR_BUFFER_OVERFLOW;
        if (! IsEnabled())
            return Status();
        return WriteEnabled(severity, message);
    }

    // Bounded, counted UTF-8 from an app-owned log record. Conversion happens only with a subscriber.
    [[nodiscard]] ULONG WriteUtf8(Severity severity, std::string_view message) const noexcept
    {
        if (FilterBit(severity) == 0 || _label.empty() || _label.size() > 64)
            return ERROR_INVALID_PARAMETER;
        if (message.size() > kMaxMessageCodeUnits)
            return ERROR_BUFFER_OVERFLOW;
        if (! IsEnabled())
            return Status();
        return WriteUtf8Enabled(severity, message);
    }

private:
    // Keep large bounded stack buffers (and their stack probes) outside the disabled fast path.
    [[nodiscard]] __declspec(noinline) ULONG WriteEnabled(Severity severity, std::wstring_view message) const noexcept
    {
        std::array<wchar_t, kMaxMessageCodeUnits> text;
        text[0] = L'[';
        std::copy(_label.begin(), _label.end(), text.begin() + 1);
        text[_label.size() + 1] = L']';
        text[_label.size() + 2] = L' ';
        std::copy(message.begin(), message.end(), text.begin() + _label.size() + 3);
        return _provider.Write(severity, {text.data(), _label.size() + 3 + message.size()});
    }

    [[nodiscard]] __declspec(noinline) ULONG WriteUtf8Enabled(Severity severity, std::string_view message) const noexcept
    {
        if (message.empty())
            return Write(severity, {});
        std::array<wchar_t, kMaxMessageCodeUnits> text;
        const int count =
            MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, message.data(), static_cast<int>(message.size()), text.data(), static_cast<int>(text.size()));
        if (count == 0)
            return GetLastError();
        return Write(severity, {text.data(), static_cast<size_t>(count)});
    }

    Provider _provider;
    std::wstring_view _label;
};
} // namespace RedMonitor
