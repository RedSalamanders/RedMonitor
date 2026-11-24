#include "MonitorFileExporter.h"

#include "LocalFileTransaction.h"
#include "PathUtils.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

namespace RedSalamanderMonitor
{
namespace
{
constexpr HRESULT kCancelled       = HRESULT_FROM_WIN32(ERROR_CANCELLED);
constexpr HRESULT kEncodingError   = HRESULT_FROM_WIN32(ERROR_NO_UNICODE_TRANSLATION);
constexpr size_t kOutputChunkBytes = 64u * 1024u;

[[nodiscard]] HRESULT ReadExportVersion(HANDLE file, MonitorFileExportVersion& version) noexcept
{
    BY_HANDLE_FILE_INFORMATION identity{};
    FILE_BASIC_INFO timestamps{};
    if (! GetFileInformationByHandle(file, &identity) || ! GetFileInformationByHandleEx(file, FileBasicInfo, &timestamps, sizeof(timestamps)))
    {
        const DWORD error = GetLastError();
        return HRESULT_FROM_WIN32(error == ERROR_SUCCESS ? ERROR_READ_FAULT : error);
    }
    if ((identity.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) != 0u ||
        (identity.nFileIndexHigh == 0u && identity.nFileIndexLow == 0u))
    {
        return HRESULT_FROM_WIN32(ERROR_NOT_SUPPORTED);
    }
    version = {
        .fileIndex          = (static_cast<uint64_t>(identity.nFileIndexHigh) << 32u) | identity.nFileIndexLow,
        .fileSize           = (static_cast<uint64_t>(identity.nFileSizeHigh) << 32u) | identity.nFileSizeLow,
        .lastWriteTime      = timestamps.LastWriteTime.QuadPart,
        .changeTime         = timestamps.ChangeTime.QuadPart,
        .volumeSerialNumber = identity.dwVolumeSerialNumber,
    };
    return S_OK;
}

[[nodiscard]] HRESULT ReadExportVersionAtPath(const std::filesystem::path& path, std::optional<MonitorFileExportVersion>& version) noexcept
{
    version.reset();
    const auto native = Common::Paths::ToExtendedWin32Path(path.native());
    const wil::unique_hfile file(CreateFileW(native.c_str(),
                                             FILE_READ_ATTRIBUTES,
                                             FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                                             nullptr,
                                             OPEN_EXISTING,
                                             FILE_FLAG_OPEN_REPARSE_POINT,
                                             nullptr));
    if (! file)
    {
        const DWORD error = GetLastError();
        return error == ERROR_FILE_NOT_FOUND ? S_OK : HRESULT_FROM_WIN32(error == ERROR_SUCCESS ? ERROR_READ_FAULT : error);
    }

    MonitorFileExportVersion observed{};
    const HRESULT hr = ReadExportVersion(file.get(), observed);
    if (SUCCEEDED(hr))
    {
        version = observed;
    }
    return hr;
}

[[nodiscard]] MonitorFileExportResult Failed(HRESULT hr, uint64_t bytesWritten, size_t completedLines) noexcept
{
    return MonitorFileExportResult{.hr = hr, .bytesWritten = bytesWritten, .lineCount = completedLines};
}

void AppendUtf8Scalar(std::string& output, uint32_t scalar)
{
    if (scalar <= 0x7Fu)
    {
        output.push_back(static_cast<char>(scalar));
    }
    else if (scalar <= 0x7FFu)
    {
        output.push_back(static_cast<char>(0xC0u | (scalar >> 6u)));
        output.push_back(static_cast<char>(0x80u | (scalar & 0x3Fu)));
    }
    else if (scalar <= 0xFFFFu)
    {
        output.push_back(static_cast<char>(0xE0u | (scalar >> 12u)));
        output.push_back(static_cast<char>(0x80u | ((scalar >> 6u) & 0x3Fu)));
        output.push_back(static_cast<char>(0x80u | (scalar & 0x3Fu)));
    }
    else
    {
        output.push_back(static_cast<char>(0xF0u | (scalar >> 18u)));
        output.push_back(static_cast<char>(0x80u | ((scalar >> 12u) & 0x3Fu)));
        output.push_back(static_cast<char>(0x80u | ((scalar >> 6u) & 0x3Fu)));
        output.push_back(static_cast<char>(0x80u | (scalar & 0x3Fu)));
    }
}
} // namespace

HRESULT ObserveMonitorFileExportTarget(MonitorFileExportTarget& target) noexcept
{
    return ReadExportVersionAtPath(target.path, target.acceptedVersion);
}

MonitorFileExportResult WriteMonitorTextSnapshot(const MonitorFileExportTarget& target,
                                                 const MonitorTextSnapshot& snapshot,
                                                 std::stop_token stopToken,
                                                 const MonitorFileExportProgress& progress)
{
    if (stopToken.stop_requested())
    {
        return Failed(kCancelled, 0u, 0u);
    }

    Common::Files::LocalFileTransaction transaction;
    const auto policy      = target.acceptedVersion ? Common::Files::ExistingTargetPolicy::Replace : Common::Files::ExistingTargetPolicy::FailIfExists;
    const HRESULT createHr = Common::Files::LocalFileTransaction::Create(target.path, policy, false, transaction);
    if (FAILED(createHr))
    {
        if (createHr == HRESULT_FROM_WIN32(ERROR_FILE_EXISTS))
        {
            return Failed(kMonitorFileExportConflict, 0u, 0u);
        }
        return Failed(createHr, 0u, 0u);
    }

    uint64_t bytesWritten = 0u;
    size_t completedLines = 0u;
    const auto write      = [&](std::string_view bytes) -> HRESULT
    {
        const HRESULT hr = transaction.Write(bytes);
        if (SUCCEEDED(hr))
        {
            bytesWritten += bytes.size();
            if (progress)
            {
                progress(bytesWritten, completedLines);
            }
        }
        return hr;
    };

    constexpr std::string_view bom("\xEF\xBB\xBF", 3u);
    HRESULT hr = write(bom);
    if (FAILED(hr))
    {
        return Failed(hr, bytesWritten, completedLines);
    }

    std::string output;
    output.reserve(kOutputChunkBytes + 4u);
    size_t unitsSinceCancellationPoll = 0u;
    for (const MonitorTextBlock& block : snapshot.lines)
    {
        const std::wstring& line = block.Text();
        for (size_t index = 0u; index < line.size(); ++index)
        {
            if (++unitsSinceCancellationPoll >= 4'096u)
            {
                unitsSinceCancellationPoll = 0u;
                if (stopToken.stop_requested())
                {
                    return Failed(kCancelled, bytesWritten, completedLines);
                }
            }

            const uint16_t codeUnit = static_cast<uint16_t>(line[index]);
            uint32_t scalar         = codeUnit;
            if (codeUnit >= 0xD800u && codeUnit <= 0xDBFFu)
            {
                if (index + 1u >= line.size())
                {
                    return Failed(kEncodingError, bytesWritten, completedLines);
                }
                const uint16_t low = static_cast<uint16_t>(line[index + 1u]);
                if (low < 0xDC00u || low > 0xDFFFu)
                {
                    return Failed(kEncodingError, bytesWritten, completedLines);
                }
                scalar = 0x10000u + ((static_cast<uint32_t>(codeUnit) - 0xD800u) << 10u) + (static_cast<uint32_t>(low) - 0xDC00u);
                ++index;
            }
            else if (codeUnit >= 0xDC00u && codeUnit <= 0xDFFFu)
            {
                return Failed(kEncodingError, bytesWritten, completedLines);
            }

            AppendUtf8Scalar(output, scalar);
            if (output.size() >= kOutputChunkBytes)
            {
                hr = write(output);
                if (FAILED(hr))
                {
                    return Failed(hr, bytesWritten, completedLines);
                }
                output.clear();
            }
        }

        output.push_back('\n');
        ++completedLines;
        if (output.size() >= kOutputChunkBytes)
        {
            hr = write(output);
            if (FAILED(hr))
            {
                return Failed(hr, bytesWritten, completedLines);
            }
            output.clear();
        }
    }

    if (! output.empty())
    {
        hr = write(output);
        if (FAILED(hr))
        {
            return Failed(hr, bytesWritten, completedLines);
        }
    }
    if (stopToken.stop_requested())
    {
        return Failed(kCancelled, bytesWritten, completedLines);
    }

    wil::unique_hfile guard;
    if (target.acceptedVersion)
    {
        // Retain delete sharing for replacement and deny other writers until publication finishes.
        guard.reset(CreateFileW(transaction.TargetPath().c_str(),
                                FILE_READ_ATTRIBUTES | DELETE,
                                FILE_SHARE_READ | FILE_SHARE_DELETE,
                                nullptr,
                                OPEN_EXISTING,
                                FILE_FLAG_OPEN_REPARSE_POINT,
                                nullptr));
        MonitorFileExportVersion guarded{};
        if (! guard || FAILED(ReadExportVersion(guard.get(), guarded)) || guarded != *target.acceptedVersion)
        {
            return Failed(kMonitorFileExportConflict, bytesWritten, completedLines);
        }
    }
    struct PublishState
    {
        const std::filesystem::path* path;
        const std::optional<MonitorFileExportVersion>* acceptedVersion;
        std::stop_token stopToken;
    } publish{&transaction.TargetPath(), &target.acceptedVersion, stopToken};
    hr = transaction.Commit(bytesWritten,
                            nullptr,
                            {&publish,
                             [](void* raw) noexcept -> HRESULT
    {
        const auto& state = *static_cast<const PublishState*>(raw);
        if (state.stopToken.stop_requested())
        {
            return kCancelled;
        }
        std::optional<MonitorFileExportVersion> current;
        const HRESULT status = ReadExportVersionAtPath(*state.path, current);
        if (FAILED(status) || current != *state.acceptedVersion)
        {
            return kMonitorFileExportConflict;
        }
        return S_OK;
    }});
    if (hr == HRESULT_FROM_WIN32(ERROR_FILE_EXISTS) || hr == HRESULT_FROM_WIN32(ERROR_ALREADY_EXISTS))
    {
        hr = kMonitorFileExportConflict;
    }
    return MonitorFileExportResult{.hr = hr, .bytesWritten = bytesWritten, .lineCount = completedLines};
}
} // namespace RedSalamanderMonitor
