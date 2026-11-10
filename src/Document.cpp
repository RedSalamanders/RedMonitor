#include "Document.h"
#include "Helpers.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cwctype>
#include <format>
#include <limits>
#include <optional>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>

// Helper function to strip carriage returns from text
static void StripCarriageReturns(std::wstring& text)
{
    text.erase(std::remove(text.begin(), text.end(), L'\r'), text.end());
}

// Helper function for emoji display
static std::wstring_view EmojiForType(Debug::InfoParam::Type t)
{
    switch (t)
    {
        case Debug::InfoParam::Type::Error: return L"🛑 ";
        case Debug::InfoParam::Type::Warning: return L"⚠️ ";
        case Debug::InfoParam::Type::Info: return L"ℹ️ ";
        case Debug::InfoParam::Type::Perf: return L"⏱️ ";
        case Debug::InfoParam::Type::Debug: return L"🐞 ";
        case Debug::InfoParam::Type::Text: return L"📝 ";
        case Debug::InfoParam::Type::All: // Not a message type
        default: return L"";
    }
}

namespace
{
[[nodiscard]] size_t FindWithLowerNeedle(std::wstring_view hay, std::wstring_view lowerNeedle, size_t startPos) noexcept
{
    if (lowerNeedle.empty())
        return 0;
    if (startPos >= hay.size())
        return std::wstring::npos;

    const size_t nlen = lowerNeedle.size();
    if (nlen > hay.size() || startPos > hay.size() - nlen)
        return std::wstring::npos;

    const wchar_t firstChar = lowerNeedle[0];
    const size_t lastStart  = hay.size() - nlen;
    for (size_t i = startPos; i <= lastStart; ++i)
    {
        if (static_cast<wchar_t>(std::towlower(hay[i])) != firstChar)
            continue;

        size_t j = 1;
        for (; j < nlen; ++j)
        {
            if (static_cast<wchar_t>(std::towlower(hay[i + j])) != lowerNeedle[j])
                break;
        }
        if (j == nlen)
            return i;
    }
    return std::wstring::npos;
}
} // namespace

// --- Document Implementation ---

void Document::InvalidateCaches(CacheInvalidationReason reason)
{
    switch (reason)
    {
        case CacheInvalidationReason::ShowIdsChanged:
            // Prefix and display strings change; max line chars includes prefix so it's stale too
            for (auto& line : _lines)
            {
                line.cachedPrefix.clear();
                line.cachedPrefixLenValid = false;
                line.cachedDisplay.clear();
                line.cachedDisplayValid = false;
            }
            _totalLengthValid = false;
            _offsetsValid     = false;
            _lineOffsetBase   = 0;
            _lineOffsets.clear();
            _maxLineCharsValid = false;
            _maxLineChars      = 0;
            _maxLineIndex      = 0;
            break;

        case CacheInvalidationReason::FontChanged:
            // Width measurements invalid, but cached strings still valid
            _maxLineCharsValid = false;
            _maxLineChars      = 0;
            _maxLineIndex      = 0;
            ResetDirtyRange();
            // Display text unchanged, only layout widths affected
            break;

        case CacheInvalidationReason::ThemeChanged:
            // Only colors changed - no text cache invalidation needed
            // Nothing to do for document caches
            break;

        case CacheInvalidationReason::FilterChanged:
            // Visibility changed - visibleLines already rebuilt by SetFilterMask
            // No additional cache invalidation needed
            break;

        case CacheInvalidationReason::FullInvalidation:
        default:
            // Full invalidation (backward compatibility with old behavior)
            _totalLengthValid = false;
            _offsetsValid     = false;
            _lineOffsetBase   = 0;
            _lineOffsets.clear();
            _maxLineCharsValid = false;
            _maxLineChars      = 0;
            _maxLineIndex      = 0;
            ResetDirtyRange();
            for (auto& line : _lines)
            {
                line.cachedPrefix.clear();
                line.cachedDisplay.clear();
                line.cachedDisplayValid   = false;
                line.cachedPrefixLenValid = false;
            }
            break;
    }
}

void Document::EnsureOffsetsValid() const
{
    if (_offsetsValid && _lineOffsets.size() == _lines.size())
        return;

    _lineOffsets.clear();
    _lineOffsetBase = 0;
    uint64_t offset = 0;

    for (const auto& line : _lines)
    {
        _lineOffsets.push_back(offset);
        const UINT32 plen = PrefixLength(line);
        offset += static_cast<uint64_t>(plen) + line.text.size() + 1u; // +1 for '\n' separator between logical lines
    }
    _offsetsValid = true;
}

void Document::ResetDirtyRange()
{
    _dirtyRangeValid = false;
    _dirtyRangeFirst = 0;
    _dirtyRangeLast  = 0;
}

void Document::UpdateDirtyRange(size_t first, size_t last)
{
    if (_lines.empty())
    {
        ResetDirtyRange();
        return;
    }

    const size_t clampedFirst = std::min(first, last);
    const size_t clampedLast  = std::max(first, last);

    if (! _dirtyRangeValid)
    {
        _dirtyRangeValid = true;
        _dirtyRangeFirst = clampedFirst;
        _dirtyRangeLast  = clampedLast;
    }
    else
    {
        _dirtyRangeFirst = std::min(_dirtyRangeFirst, clampedFirst);
        _dirtyRangeLast  = std::max(_dirtyRangeLast, clampedLast);
    }
}

void Document::OnLineLengthChanged(size_t index, [[maybe_unused]] size_t oldLen, size_t newLen) const
{
    if (! _maxLineCharsValid)
    {
        if (newLen > _maxLineChars)
        {
            _maxLineChars = newLen;
            _maxLineIndex = index;
        }
        return;
    }

    if (newLen >= _maxLineChars)
    {
        _maxLineChars = newLen;
        _maxLineIndex = index;
        return;
    }

    if (index == _maxLineIndex && newLen < _maxLineChars)
    {
        _maxLineCharsValid = false;
    }
}

void Document::ReserveForAdditionalLines(size_t additionalLineCount)
{
    // std::deque keeps stable O(1) oldest-first eviction without moving every retained line.
    static_cast<void>(additionalLineCount);
}

void Document::EnsureTotalLengthValid() const
{
    if (_totalLengthValid)
        return;

    _cachedTotalLength = 0;
    for (size_t i = 0; i < _lines.size(); i++)
    {
        _cachedTotalLength += PrefixLength(_lines[i]);
        _cachedTotalLength += static_cast<UINT32>(_lines[i].text.size());
        if (i + 1 < _lines.size())
            _cachedTotalLength += 1; // '\n' separator
    }
    _totalLengthValid = true;
}

void Document::SetText(const std::wstring& text)
{
    std::unique_lock lock(_rwMutex); // Write operation
    _lines.clear();
    _visibleLines.clear(); // Clear visible lines when replacing all text
    _retainedTextBytes = 0u;
    size_t start       = 0;
    size_t end         = 0;
    while (end != std::wstring::npos)
    {
        end = text.find(L'\n', start);
        std::wstring lineText;
        if (end == std::wstring::npos)
            lineText = text.substr(start);
        else
            lineText = text.substr(start, end - start);
        StripCarriageReturns(lineText);
        Line line;
        line.text = std::move(lineText);
        _retainedTextBytes += static_cast<uint64_t>(line.text.size()) * sizeof(wchar_t);
        line.newlineCount       = static_cast<UINT32>(std::count(line.text.begin(), line.text.end(), L'\n'));
        line.cachedDisplayValid = false;
        _lines.push_back(std::move(line));
        start = (end == std::wstring::npos) ? end : end + 1;
    }
    InvalidateCaches();
    MarkAllDirtyUnsafe();  // Already holding lock
    RebuildVisibleLines(); // Rebuild visible lines after replacing all text
}

void Document::SetTextSnapshot(RedSalamanderMonitor::MonitorTextSnapshot&& snapshot)
{
    std::unique_lock lock(_rwMutex);
    _lines.clear();
    _visibleLines.clear();
    _retainedTextBytes = 0u;
    for (RedSalamanderMonitor::MonitorTextBlock& text : snapshot.lines)
    {
        Line line;
        line.text = std::move(text);
        _retainedTextBytes += static_cast<uint64_t>(line.text.size()) * sizeof(wchar_t);
        line.newlineCount       = static_cast<UINT32>(std::count(line.text.begin(), line.text.end(), L'\n'));
        line.cachedDisplayValid = false;
        _lines.push_back(std::move(line));
    }
    InvalidateCaches();
    MarkAllDirtyUnsafe();
    RebuildVisibleLines();
}

void Document::AppendText(const std::wstring& more)
{
    std::unique_lock lock(_rwMutex); // Write operation
    if (more.empty())
        return;

    const bool wasEmpty = _lines.empty();
    if (wasEmpty)
        _lines.push_back(Line{});
    const size_t prevLineCount = _lines.size();

    size_t currentIndex           = _lines.size() - 1;
    const wchar_t* data           = more.c_str();
    const size_t length           = more.size();
    size_t segmentStart           = 0;
    size_t totalCharsAppended     = 0;
    size_t newlineSeparatorsAdded = 0;

    auto appendSegment = [&](size_t start, size_t end)
    {
        if (end <= start)
            return; // most of the time return here when you've got \r\n and allready add the segment on \r
        auto& line          = _lines[currentIndex];
        const UINT32 prefix = PrefixLength(line);
        const size_t oldLen = static_cast<size_t>(prefix) + line.text.size();
        const size_t count  = end - start;
        line.text.Append(data + start, count);
        line.cachedDisplayValid = false;
        totalCharsAppended += count;
        const size_t newLen = static_cast<size_t>(prefix) + line.text.size();
        OnLineLengthChanged(currentIndex, oldLen, newLen);
    };

    for (size_t i = 0; i < length; ++i)
    {
        const wchar_t ch = data[i];
        if (ch == L'\r')
        {
            appendSegment(segmentStart, i);
            segmentStart = i + 1;
            continue;
        }
        if (ch == L'\n')
        {
            appendSegment(segmentStart, i);
            ++newlineSeparatorsAdded;
            _lines.push_back(Line{});
            currentIndex = _lines.size() - 1;
            segmentStart = i + 1;
            continue;
        }
    }
    appendSegment(segmentStart, length);
    _retainedTextBytes += static_cast<uint64_t>(totalCharsAppended) * sizeof(wchar_t);

    if (_totalLengthValid)
    {
        _cachedTotalLength += static_cast<UINT32>(totalCharsAppended);
        _cachedTotalLength += static_cast<UINT32>(newlineSeparatorsAdded);
    }

    if (_offsetsValid)
    {
        if (wasEmpty && _lineOffsets.empty())
        {
            _lineOffsets.push_back(_lineOffsetBase);
        }

        if (_lineOffsets.size() != prevLineCount)
        {
            _offsetsValid = false;
        }
        else
        {
            uint64_t offset = _lineOffsetBase;
            if (prevLineCount > 0)
            {
                const auto& tail = _lines[prevLineCount - 1];
                offset           = _lineOffsets.back() + static_cast<uint64_t>(PrefixLength(tail)) + tail.text.size() + 1u;
            }
            for (size_t idx = prevLineCount; idx < _lines.size() && _offsetsValid; ++idx)
            {
                if (_lineOffsets.size() != idx)
                {
                    _offsetsValid = false;
                    break;
                }
                _lineOffsets.push_back(offset);
                const auto& newLine = _lines[idx];
                offset += static_cast<uint64_t>(PrefixLength(newLine)) + newLine.text.size() + 1u;
            }
        }
    }

    if (! _lines.empty())
    {
        const size_t lastIndex  = _lines.size() - 1;
        const size_t firstDirty = prevLineCount ? prevLineCount - 1 : 0;
        UpdateDirtyRange(firstDirty, lastIndex);
    }

    // Rebuild visibleLines after bulk append since multiple lines may have been added
    RebuildVisibleLines();
}

void Document::AppendInfoLine(const std::wstring& text, const Debug::InfoParam& info)
{
    std::unique_lock lock(_rwMutex); // Write operation
    ReserveForAdditionalLines(1u);
    AppendInfoLineUnsafe(std::wstring{text}, info);
}

void Document::AppendInfoLines(std::vector<InfoLineInput> lines)
{
    if (lines.empty())
        return;

    std::unique_lock lock(_rwMutex); // Write operation
    ReserveForAdditionalLines(lines.size());
    for (auto& input : lines)
    {
        AppendInfoLineUnsafe(std::move(input.text), input.info);
    }
}

void Document::AppendInfoLineUnsafe(std::wstring text, const Debug::InfoParam& info)
{
    StripCarriageReturns(text);
    Line line;
    line.text               = std::move(text);
    line.newlineCount       = static_cast<UINT32>(std::count(line.text.begin(), line.text.end(), L'\n'));
    line.cachedDisplayValid = false;
    line.hasMeta            = true;
    line.meta               = info;
    _retainedTextBytes += static_cast<uint64_t>(line.text.size()) * sizeof(wchar_t);

#ifdef _DEBUG
    if (line.newlineCount > 0)
    {
        auto msg = std::format("AppendInfoLine: line {} has newlineCount={} (embedded newlines in text)\n", _lines.size(), line.newlineCount);
        OutputDebugStringA(msg.c_str());
    }
#endif

    _lines.push_back(std::move(line));

    const size_t newIndex = _lines.size() - 1;
    const size_t newLen   = static_cast<size_t>(PrefixLength(_lines[newIndex])) + _lines[newIndex].text.size();
    OnLineLengthChanged(newIndex, 0, newLen);

    if (_totalLengthValid)
    {
        const auto& back  = _lines.back();
        const UINT32 plen = PrefixLength(back);
        _cachedTotalLength += plen + static_cast<UINT32>(back.text.size());
        if (_lines.size() > 1)
            _cachedTotalLength += 1; // newline separator before this line
    }

    if (_offsetsValid)
    {
        if (_lineOffsets.size() != _lines.size() - 1)
        {
            _offsetsValid = false;
        }
        else
        {
            uint64_t offset = _lineOffsetBase;
            if (! _lineOffsets.empty())
            {
                const auto& prev = _lines[_lines.size() - 2];
                offset           = _lineOffsets.back() + static_cast<uint64_t>(PrefixLength(prev)) + prev.text.size() + 1u;
            }
            _lineOffsets.push_back(offset);
        }
    }

    // Update visibleLines incrementally if the new line is visible
    // Use unsafe version since we already hold unique_lock
    if (IsLineVisibleUnsafe(newIndex))
    {
        UINT32 displayRow = 0;
        if (! _visibleLines.empty())
        {
            // Calculate display row based on last visible line
            const auto& lastVisible = _visibleLines.back();
            displayRow              = lastVisible.displayRowStart + _lines[lastVisible.sourceIndex].newlineCount + 1u;
        }
        _visibleLines.push_back({newIndex, displayRow});
    }

    UpdateDirtyRange(newIndex, newIndex);
}

void Document::Clear()
{
    std::unique_lock lock(_rwMutex); // Write operation
    _lines.clear();
    _visibleLines.clear(); // Clear visible lines when document is cleared
    _retainedTextBytes = 0u;
    InvalidateCaches();
}

Document::RetentionResult Document::EnforceRetentionLimits(size_t maxLines, uint64_t maxTextBytes)
{
    std::unique_lock lock(_rwMutex);
    RetentionResult result;
    maxLines     = std::max<size_t>(1u, maxLines);
    maxTextBytes = std::max<uint64_t>(sizeof(wchar_t), maxTextBytes);

    while (! _lines.empty() && (_lines.size() > maxLines || _retainedTextBytes > maxTextBytes))
    {
        const Line& line         = _lines.front();
        const uint64_t textBytes = static_cast<uint64_t>(line.text.size()) * sizeof(wchar_t);
        result.textBytesEvicted += textBytes;
        result.characterPositionsEvicted += static_cast<uint64_t>(PrefixLength(line)) + line.text.size() + (_lines.size() > 1u ? 1u : 0u);
        if (IsLineVisibleUnsafe(0u))
        {
            result.displayRowsEvicted += static_cast<uint64_t>(line.newlineCount) + 1u;
        }
        _retainedTextBytes = textBytes > _retainedTextBytes ? 0u : _retainedTextBytes - textBytes;
        _lines.pop_front();
        if (_offsetsValid && ! _lineOffsets.empty())
        {
            _lineOffsets.pop_front();
        }
        ++result.linesEvicted;
    }

    if (result.linesEvicted == 0u)
    {
        return result;
    }

    if (_lines.empty())
    {
        _totalLengthValid  = true;
        _cachedTotalLength = 0u;
        _offsetsValid      = true;
        _lineOffsetBase    = 0u;
        _lineOffsets.clear();
        _maxLineCharsValid = true;
        _maxLineChars      = 0u;
        _maxLineIndex      = 0u;
        _visibleLines.clear();
        ResetDirtyRange();
        return result;
    }

    if (_totalLengthValid)
    {
        if (_cachedTotalLength >= result.characterPositionsEvicted)
        {
            _cachedTotalLength -= static_cast<UINT32>(result.characterPositionsEvicted);
        }
        else
        {
            _totalLengthValid = false;
        }
    }

    if (_offsetsValid)
    {
        if (_lineOffsets.size() == _lines.size())
        {
            _lineOffsetBase = _lineOffsets.empty() ? 0u : _lineOffsets.front();
        }
        else
        {
            _offsetsValid   = false;
            _lineOffsetBase = 0u;
            _lineOffsets.clear();
        }
    }

    if (_maxLineCharsValid)
    {
        if (_maxLineIndex >= result.linesEvicted)
        {
            _maxLineIndex -= result.linesEvicted;
        }
        else
        {
            _maxLineCharsValid = false;
            _maxLineChars      = 0u;
            _maxLineIndex      = 0u;
        }
    }
    else
    {
        _maxLineChars = 0u;
        _maxLineIndex = 0u;
    }

    if (! _visibleLines.empty())
    {
        const auto firstSurviving =
            std::lower_bound(_visibleLines.begin(), _visibleLines.end(), result.linesEvicted, [](const VisibleLine& vl, size_t evictedCount) noexcept {
            return vl.sourceIndex < evictedCount;
        });
        _visibleLines.erase(_visibleLines.begin(), firstSurviving);
        const UINT32 rowsEvicted = static_cast<UINT32>(result.displayRowsEvicted);
        for (auto& vl : _visibleLines)
        {
            vl.sourceIndex -= result.linesEvicted;
            vl.displayRowStart = (vl.displayRowStart >= rowsEvicted) ? (vl.displayRowStart - rowsEvicted) : 0u;
        }
    }

    if (_dirtyRangeValid)
    {
        if (_dirtyRangeLast < result.linesEvicted)
        {
            ResetDirtyRange();
        }
        else
        {
            _dirtyRangeFirst = (_dirtyRangeFirst > result.linesEvicted) ? (_dirtyRangeFirst - result.linesEvicted) : 0u;
            _dirtyRangeLast  = std::min(_dirtyRangeLast - result.linesEvicted, _lines.size() - 1u);
        }
    }

    return result;
}

size_t Document::TotalLength() const
{
    {
        std::shared_lock sharedLock(_rwMutex);
        if (_totalLengthValid)
            return _cachedTotalLength;
    }
    std::unique_lock lock(_rwMutex); // May refresh cached aggregate state.
    EnsureTotalLengthValid();
    return _cachedTotalLength;
}

size_t Document::LongestLineChars() const
{
    {
        std::shared_lock sharedLock(_rwMutex);
        if (_maxLineCharsValid)
            return _maxLineChars;
    }
    std::unique_lock lock(_rwMutex); // May refresh cached aggregate state.
    if (! _maxLineCharsValid)
    {
        _maxLineChars = 0;
        _maxLineIndex = 0;
        for (size_t i = 0; i < _lines.size(); ++i)
        {
            const size_t len = static_cast<size_t>(PrefixLength(_lines[i])) + _lines[i].text.size();
            if (len > _maxLineChars)
            {
                _maxLineChars = len;
                _maxLineIndex = i;
            }
        }
        _maxLineCharsValid = true;
    }
    return _maxLineChars;
}

uint64_t Document::RetainedTextBytes() const
{
    std::shared_lock lock(_rwMutex);
    return _retainedTextBytes;
}

size_t Document::VisibleLineCount() const
{
    std::shared_lock lock(_rwMutex);
    return _visibleLines.size();
}

size_t Document::TotalLineCount() const
{
    std::shared_lock lock(_rwMutex);
    return _lines.size();
}

void Document::SetFilterMask(uint32_t mask)
{
    std::unique_lock lock(_rwMutex);
    if (_filterMask == mask)
        return;

#ifdef _DEBUG
    auto msg = std::format("SetFilterMask: 0x{:02X} -> 0x{:02X} (lineCount={})\n", _filterMask, mask, _lines.size());
    OutputDebugStringA(msg.c_str());
#endif

    _filterMask = mask;
    RebuildVisibleLines(); // Rebuild visible lines vector for new filter
    InvalidateCaches(CacheInvalidationReason::FilterChanged);
}

void Document::RebuildVisibleLines()
{
    // No lock needed - called from methods that already hold unique_lock
    _visibleLines.clear();

    if (_filterMask == Debug::InfoParam::Type::All)
    {
        // No filtering - all lines visible
        _visibleLines.reserve(_lines.size());
        UINT32 displayRow = 0;
        for (size_t i = 0; i < _lines.size(); ++i)
        {
            _visibleLines.push_back({i, displayRow});
            displayRow += _lines[i].newlineCount + 1u;
        }
    }
    else
    {
        // Filtering active - only visible lines
        size_t estimatedVisible = _lines.size() / 2; // Rough estimate for initial capacity
        _visibleLines.reserve(estimatedVisible);

        UINT32 displayRow = 0;
        for (size_t i = 0; i < _lines.size(); ++i)
        {
            const auto& line = _lines[i];

            // Lines without metadata are always visible
            bool visible = ! line.hasMeta;
            if (line.hasMeta)
            {
                // Check filter mask for this line's type
                if (line.meta.type == Debug::InfoParam::Type::All)
                {
                    visible = true;
                }
                else
                {
                    visible = (_filterMask & Debug::FilterBitForType(line.meta.type)) != 0u;
                }
            }

            if (visible)
            {
                _visibleLines.push_back({i, displayRow});
                displayRow += line.newlineCount + 1u;
            }
        }
    }

#ifdef _DEBUG
    auto msg = std::format("RebuildVisibleLines: {} visible of {} total lines, {} display rows\n",
                           _visibleLines.size(),
                           _lines.size(),
                           _visibleLines.empty() ? 0u : _visibleLines.back().displayRowStart + _lines[_visibleLines.back().sourceIndex].newlineCount + 1u);
    OutputDebugStringA(msg.c_str());
#endif
}

bool Document::IsLineVisibleUnsafe(size_t sourceIndex) const
{
    // Caller must hold lock
    if (_filterMask == Debug::InfoParam::Type::All)
        return true;

    if (sourceIndex >= _lines.size())
        return false;

    const auto& line = _lines[sourceIndex];
    if (! line.hasMeta)
        return true; // Lines without metadata always visible

    if (line.meta.type == Debug::InfoParam::Type::All)
        return true;

    return (_filterMask & Debug::FilterBitForType(line.meta.type)) != 0u;
}

bool Document::IsLineVisible(size_t sourceIndex) const
{
    std::shared_lock lock(_rwMutex);
    return IsLineVisibleUnsafe(sourceIndex);
}

Line Document::GetVisibleLine(size_t visibleIndex) const
{
    std::shared_lock lock(_rwMutex);

    if (visibleIndex >= _visibleLines.size())
        return {};

    const size_t sourceIndex = _visibleLines[visibleIndex].sourceIndex;
    if (sourceIndex >= _lines.size())
        return {};

    return _lines[sourceIndex];
}

Line Document::GetSourceLine(size_t sourceIndex) const
{
    std::shared_lock lock(_rwMutex);

    if (sourceIndex >= _lines.size())
        return {};

    return _lines[sourceIndex];
}

std::vector<VisibleLine> Document::VisibleLines() const
{
    std::shared_lock lock(_rwMutex);
    return _visibleLines;
}

std::vector<VisibleLine> Document::CopyVisibleLinesRange(size_t firstVisibleIndex, size_t lastVisibleIndex) const
{
    std::shared_lock lock(_rwMutex);
    if (_visibleLines.empty() || firstVisibleIndex >= _visibleLines.size())
        return {};

    const size_t clampedLast = std::min(lastVisibleIndex, _visibleLines.size() - 1u);
    if (clampedLast < firstVisibleIndex)
        return {};

    return std::vector<VisibleLine>(_visibleLines.begin() + static_cast<std::ptrdiff_t>(firstVisibleIndex),
                                    _visibleLines.begin() + static_cast<std::ptrdiff_t>(clampedLast + 1u));
}

std::optional<size_t> Document::SourceIndexForVisible(size_t visibleIndex) const
{
    std::shared_lock lock(_rwMutex);
    if (visibleIndex >= _visibleLines.size())
        return std::nullopt;
    return _visibleLines[visibleIndex].sourceIndex;
}

std::optional<size_t> Document::LowerBoundVisibleIndexForSource(size_t sourceIndex) const
{
    std::shared_lock lock(_rwMutex);
    if (_visibleLines.empty())
        return std::nullopt;

    const auto it = std::lower_bound(
        _visibleLines.begin(), _visibleLines.end(), sourceIndex, [](const VisibleLine& vl, size_t src) noexcept { return vl.sourceIndex < src; });
    if (it == _visibleLines.end())
        return std::nullopt;

    return static_cast<size_t>(std::distance(_visibleLines.begin(), it));
}

UINT32 Document::DisplayRowForVisible(size_t visibleIndex) const
{
    std::shared_lock lock(_rwMutex);

    if (visibleIndex >= _visibleLines.size())
    {
        if (_visibleLines.empty())
            return 0;
        const auto& lastVisible = _visibleLines.back();
        const auto& lastLine    = _lines[lastVisible.sourceIndex];
        return lastVisible.displayRowStart + lastLine.newlineCount + 1u;
    }

    return _visibleLines[visibleIndex].displayRowStart;
}

size_t Document::VisibleIndexFromDisplayRow(UINT32 displayRow) const
{
    std::shared_lock lock(_rwMutex);

    if (_visibleLines.empty())
        return 0;

    // Binary search: find first visible line where displayRowStart > displayRow
    auto it =
        std::upper_bound(_visibleLines.begin(), _visibleLines.end(), displayRow, [](UINT32 row, const VisibleLine& vl) { return row < vl.displayRowStart; });

    // upper_bound returns iterator to first element > displayRow, so back up one
    if (it == _visibleLines.begin())
        return 0;

    return static_cast<size_t>(std::distance(_visibleLines.begin(), it - 1));
}

std::optional<size_t> Document::SourceLineForDisplayRow(UINT32 displayRow) const
{
    std::shared_lock lock(_rwMutex);

    if (_visibleLines.empty())
        return std::nullopt;

    auto it =
        std::upper_bound(_visibleLines.begin(), _visibleLines.end(), displayRow, [](UINT32 row, const VisibleLine& vl) { return row < vl.displayRowStart; });

    if (it == _visibleLines.begin())
        return _visibleLines.front().sourceIndex;

    --it;
    return it->sourceIndex;
}

std::optional<size_t> Document::ClosestVisibleSourceLine(size_t sourceIndex) const
{
    std::shared_lock lock(_rwMutex);

    if (_visibleLines.empty())
        return std::nullopt;

    auto it = std::lower_bound(_visibleLines.begin(), _visibleLines.end(), sourceIndex, [](const VisibleLine& vl, size_t src) { return vl.sourceIndex < src; });

    if (it != _visibleLines.end())
        return it->sourceIndex;

    return _visibleLines.back().sourceIndex;
}

UINT32 Document::TotalDisplayRows() const
{
    std::shared_lock lock(_rwMutex);

    if (_visibleLines.empty())
        return 0;

    const auto& lastVisible = _visibleLines.back();
    const auto& lastLine    = _lines[lastVisible.sourceIndex];
    return lastVisible.displayRowStart + lastLine.newlineCount + 1u;
}

UINT32 Document::DisplayRowForSource(size_t sourceIndex) const
{
    std::shared_lock lock(_rwMutex);

    if (sourceIndex >= _lines.size())
    {
        if (_visibleLines.empty())
            return 0;
        const auto& lastVisible = _visibleLines.back();
        const auto& lastLine    = _lines[lastVisible.sourceIndex];
        return lastVisible.displayRowStart + lastLine.newlineCount + 1u;
    }

    if (_visibleLines.empty())
        return 0;

    // O(log n): visibleLines is sorted by sourceIndex.
    auto it = std::lower_bound(_visibleLines.begin(), _visibleLines.end(), sourceIndex, [](const VisibleLine& vl, size_t src) { return vl.sourceIndex < src; });

    if (it != _visibleLines.end())
        return it->displayRowStart; // exact match or next visible line (filtered source line)

    const auto& lastVisible = _visibleLines.back();
    const auto& lastLine    = _lines[lastVisible.sourceIndex];
    return lastVisible.displayRowStart + lastLine.newlineCount + 1u;
}

UINT32 Document::GetLineStartOffset(size_t sourceIndex) const
{
    {
        std::shared_lock sharedLock(_rwMutex);
        if (sourceIndex >= _lines.size())
            return 0;
        if (_offsetsValid && _lineOffsets.size() == _lines.size())
            return static_cast<UINT32>(_lineOffsets[sourceIndex] - _lineOffsetBase);
    }

    std::unique_lock lock(_rwMutex);
    if (sourceIndex >= _lines.size())
        return 0;

    EnsureOffsetsValid();
    if (! _offsetsValid || _lineOffsets.size() != _lines.size())
        return 0;

    return static_cast<UINT32>(_lineOffsets[sourceIndex] - _lineOffsetBase);
}

std::pair<size_t, UINT32> Document::GetLineAndOffsetUnsafe(UINT32 position) const
{
    // Caller must hold lock
    if (_lines.empty())
        return {0, 0};

    const size_t lastIdx = _lines.size() - 1;
    EnsureOffsetsValid();
    if (! _offsetsValid || _lineOffsets.size() != _lines.size())
        return {lastIdx, 0};

    const uint64_t targetOffset = _lineOffsetBase + position;
    const uint64_t lastStart    = _lineOffsets[lastIdx];
    const UINT32 lastLen        = PrefixLength(_lines[lastIdx]) + static_cast<UINT32>(_lines[lastIdx].text.size());
    const uint64_t totalEnd     = lastStart + lastLen; // no trailing separator after last line

    if (targetOffset >= totalEnd)
        return {lastIdx, lastLen};

    // Find the line such that lineStart <= targetOffset < nextLineStart.
    auto it                  = std::upper_bound(_lineOffsets.begin(), _lineOffsets.end(), targetOffset);
    const size_t idx         = (it == _lineOffsets.begin()) ? 0u : static_cast<size_t>((it - _lineOffsets.begin()) - 1);
    const uint64_t lineStart = _lineOffsets[idx];
    const UINT32 off         = static_cast<UINT32>(targetOffset - lineStart);
    const UINT32 lineLen     = PrefixLength(_lines[idx]) + static_cast<UINT32>(_lines[idx].text.size());
    return {idx, std::min(off, lineLen)};
}

std::pair<size_t, UINT32> Document::GetLineAndOffset(UINT32 position) const
{
    std::unique_lock lock(_rwMutex);
    return GetLineAndOffsetUnsafe(position);
}

std::wstring Document::GetDisplayText(size_t visibleIndex) const
{
    std::unique_lock lock(_rwMutex);

    if (visibleIndex >= _visibleLines.size())
        return {};

    const size_t sourceIndex = _visibleLines[visibleIndex].sourceIndex;
    if (sourceIndex >= _lines.size())
        return {};

    auto& line = _lines[sourceIndex];
    if (! line.cachedDisplayValid)
    {
        const auto& prefix = BuildPrefix(line);
        line.cachedDisplay.clear();
        line.cachedDisplay.reserve(prefix.size() + line.text.size());
        line.cachedDisplay.append(prefix);
        line.cachedDisplay.append(line.text);
        line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
        line.cachedDisplayValid = true;
    }
    return line.cachedDisplay;
}

std::wstring Document::GetDisplayTextAll(size_t sourceIndex) const
{
    std::unique_lock lock(_rwMutex);
    if (sourceIndex >= _lines.size())
        return {};

    auto& line = _lines[sourceIndex];
    if (! line.cachedDisplayValid)
    {
        const auto& prefix = BuildPrefix(line);
        line.cachedDisplay.clear();
        line.cachedDisplay.reserve(prefix.size() + line.text.size());
        line.cachedDisplay.append(prefix);
        line.cachedDisplay.append(line.text);
        line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
        line.cachedDisplayValid = true;
    }
    return line.cachedDisplay;
}

Document::DisplayTextBatch Document::GetDisplayTextBatch(size_t firstVisible, size_t lastVisible) const
{
    DisplayTextBatch batch;
    batch.lock = std::unique_lock(_rwMutex);
    batch.texts.reserve(lastVisible >= firstVisible ? (lastVisible - firstVisible + 1) : 0);

    for (size_t visIdx = firstVisible; visIdx <= lastVisible && visIdx < _visibleLines.size(); ++visIdx)
    {
        const size_t sourceIdx = _visibleLines[visIdx].sourceIndex;
        if (sourceIdx >= _lines.size())
            break;

        auto& line = _lines[sourceIdx];
        if (! line.cachedDisplayValid)
        {
            const auto& prefix = BuildPrefix(line);
            line.cachedDisplay.clear();
            line.cachedDisplay.reserve(prefix.size() + line.text.size());
            line.cachedDisplay.append(prefix);
            line.cachedDisplay.append(line.text);
            line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
            line.cachedDisplayValid = true;
        }
        batch.texts.emplace_back(std::cref(line.cachedDisplay));
    }

    // The lock is now owned by the batch object, which will release it when destructed.
    return batch;
}

Document::DisplayTextBatch Document::GetDisplayTextBatchAll(size_t firstAll, size_t lastAll) const
{
    DisplayTextBatch batch;
    batch.lock = std::unique_lock(_rwMutex);
    batch.texts.reserve(lastAll >= firstAll ? (lastAll - firstAll + 1) : 0);

    for (size_t i = firstAll; i <= lastAll && i < _lines.size(); ++i)
    {
        auto& line = _lines[i];
        if (! line.cachedDisplayValid)
        {
            const auto& prefix = BuildPrefix(line);
            line.cachedDisplay.clear();
            line.cachedDisplay.reserve(prefix.size() + line.text.size());
            line.cachedDisplay.append(prefix);
            line.cachedDisplay.append(line.text);
            line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
            line.cachedDisplayValid = true;
        }
        batch.texts.emplace_back(std::cref(line.cachedDisplay));
    }

    return batch;
}

Document::FilteredTailResult Document::BuildFilteredTailText(size_t firstAll, size_t lastAll) const
{
    FilteredTailResult result;
    std::unique_lock lock(_rwMutex); // Cache population and snapshot construction share one exclusive scope.

    if (firstAll >= _lines.size())
        return result;

    EnsureOffsetsValid();
    lastAll                 = std::min(lastAll, _lines.size() - 1);
    result.firstSourceStart = static_cast<UINT32>(_lineOffsets[firstAll] - _lineOffsetBase);
    const auto& lastLine    = _lines[lastAll];
    result.lastSourceEnd    = static_cast<UINT32>(_lineOffsets[lastAll] - _lineOffsetBase) + PrefixLength(lastLine) + static_cast<UINT32>(lastLine.text.size());
    result.lines.reserve(lastAll - firstAll + 1);

    for (size_t i = firstAll; i <= lastAll; ++i)
    {
        if (! IsLineVisibleUnsafe(i))
            continue;

        ++result.visibleCount;

        auto& line = _lines[i];
        if (! line.cachedDisplayValid)
        {
            const auto& prefix = BuildPrefix(line);
            line.cachedDisplay.clear();
            line.cachedDisplay.reserve(prefix.size() + line.text.size());
            line.cachedDisplay.append(prefix);
            line.cachedDisplay.append(line.text);
            line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
            line.cachedDisplayValid = true;
        }

        const UINT32 prefixLen   = PrefixLength(line);
        const UINT32 sourceStart = static_cast<UINT32>(_lineOffsets[i] - _lineOffsetBase);
        const UINT32 displayTextLen =
            (line.cachedDisplay.size() >= prefixLen) ? static_cast<UINT32>(line.cachedDisplay.size() - prefixLen) : static_cast<UINT32>(line.text.size());
        result.lines.push_back({i, sourceStart, prefixLen, displayTextLen, line.hasMeta, line.meta.type, line.spans});
        result.text.append(line.cachedDisplay);
        result.text.append(L"\n");
    }

    // Remove trailing newline
    if (! result.text.empty())
        result.text.pop_back();

    return result;
}

std::vector<Document::WidthCandidate> Document::CollectWidthCandidates(size_t firstLine, size_t lastLine, size_t maxCandidates) const
{
    std::unique_lock lock(_rwMutex);
    std::vector<WidthCandidate> candidates;
    if (_lines.empty() || firstLine >= _lines.size() || maxCandidates == 0u)
        return candidates;

    lastLine                = std::min(lastLine, _lines.size() - 1u);
    const size_t rangeCount = (lastLine >= firstLine) ? (lastLine - firstLine + 1u) : 0u;
    if (rangeCount == 0u)
        return candidates;

    struct RankedIndex
    {
        size_t sourceIndex = 0;
        size_t charLength  = 0;
    };
    std::vector<RankedIndex> selected;
    selected.reserve(std::min(rangeCount, maxCandidates));

    for (size_t i = firstLine; i <= lastLine; ++i)
    {
        const size_t len = static_cast<size_t>(PrefixLength(_lines[i])) + _lines[i].text.size();
        OnLineLengthChanged(i, 0, len);

        if (selected.size() < maxCandidates)
        {
            selected.push_back({i, len});
            if (selected.size() == maxCandidates)
            {
                std::make_heap(
                    selected.begin(), selected.end(), [](const RankedIndex& a, const RankedIndex& b) noexcept { return a.charLength > b.charLength; });
            }
        }
        else if (len > selected.front().charLength)
        {
            std::pop_heap(selected.begin(), selected.end(), [](const RankedIndex& a, const RankedIndex& b) noexcept { return a.charLength > b.charLength; });
            selected.back() = {i, len};
            std::push_heap(selected.begin(), selected.end(), [](const RankedIndex& a, const RankedIndex& b) noexcept { return a.charLength > b.charLength; });
        }
    }

    std::sort(selected.begin(), selected.end(), [](const RankedIndex& a, const RankedIndex& b) noexcept { return a.sourceIndex < b.sourceIndex; });
    candidates.reserve(selected.size());
    for (const auto& item : selected)
    {
        auto& line = _lines[item.sourceIndex];
        if (! line.cachedDisplayValid)
        {
            const auto& prefix = BuildPrefix(line);
            line.cachedDisplay.clear();
            line.cachedDisplay.reserve(prefix.size() + line.text.size());
            line.cachedDisplay.append(prefix);
            line.cachedDisplay.append(line.text);
            line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
            line.cachedDisplayValid = true;
        }
        candidates.push_back({item.sourceIndex, item.charLength, line.cachedDisplay});
    }
    return candidates;
}

std::pair<size_t, size_t> Document::FindMatchesInRange(size_t startLine,
                                                       size_t startOffset,
                                                       std::wstring_view needle,
                                                       std::wstring_view lowerNeedle,
                                                       bool caseSensitive,
                                                       const D2D1_COLOR_F& highlightColor,
                                                       size_t maxMatches,
                                                       std::vector<Line::ColorSpan>& outMatches) const
{
    std::unique_lock lock(_rwMutex);
    if (needle.empty() || startLine >= _lines.size() || outMatches.size() >= maxMatches)
        return {std::min(startLine, _lines.size()), startOffset};

    EnsureOffsetsValid();
    const size_t totalLines = _lines.size();
    size_t lineIdx          = startLine;
    size_t scanOffset       = startOffset;
    while (lineIdx < totalLines && outMatches.size() < maxMatches)
    {
        if (! IsLineVisibleUnsafe(lineIdx))
        {
            ++lineIdx;
            scanOffset = 0;
            continue;
        }

        const auto& line            = _lines[lineIdx];
        const UINT32 lineStart      = static_cast<UINT32>(_lineOffsets[lineIdx] - _lineOffsetBase);
        const UINT32 prefixLen      = PrefixLength(line);
        const std::wstring_view hay = line.text.Text();
        size_t pos                  = std::min(scanOffset, hay.size());
        bool lineCompleted          = true;
        while (pos <= hay.size())
        {
            if (outMatches.size() >= maxMatches)
            {
                scanOffset    = pos;
                lineCompleted = false;
                break;
            }

            const size_t found = caseSensitive ? hay.find(needle, pos) : FindWithLowerNeedle(hay, lowerNeedle, pos);
            if (found == std::wstring::npos)
                break;

            outMatches.push_back(Line::ColorSpan{lineStart + prefixLen + static_cast<UINT32>(found), static_cast<UINT32>(needle.size()), highlightColor});
            pos = found + std::max<size_t>(1u, needle.size());
        }

        if (! lineCompleted)
            break;

        ++lineIdx;
        scanOffset = 0;
    }
    return {lineIdx, scanOffset};
}

RedSalamanderMonitor::MonitorTextSnapshot Document::CaptureTextSnapshot() const
{
    RedSalamanderMonitor::MonitorTextSnapshot snapshot;
    {
        std::shared_lock lock(_rwMutex);
        const auto lockStarted     = std::chrono::steady_clock::now();
        snapshot.retainedTextBytes = _retainedTextBytes;
        for (const Line& line : _lines)
        {
            snapshot.lines.push_back(line.text);
            ++snapshot.sharedBlockCount;
        }
        snapshot.sharedBlockBytes            = snapshot.retainedTextBytes;
        snapshot.peakAdditionalSnapshotBytes = static_cast<uint64_t>(snapshot.lines.size()) * sizeof(RedSalamanderMonitor::MonitorTextBlock);
        snapshot.lockHoldUs =
            static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - lockStarted).count());
    }
    return snapshot;
}

std::wstring Document::GetTextRange(UINT32 start, UINT32 length) const
{
    std::unique_lock lock(_rwMutex);
    if (length == 0)
        return L"";

    auto [startLine, startOffset] = GetLineAndOffsetUnsafe(start);
    auto [endLine, endOffset]     = GetLineAndOffsetUnsafe(start + length - 1);

    std::wstring result;
    result.reserve(length);

    // Helper to append a slice within one logical line from a unified (prefix+text) offset
    auto appendSlice = [&](const Line& line, UINT32 from, UINT32 count)
    {
        const UINT32 plen = PrefixLength(line);
        if (count == 0)
            return;
        // from lies in [0, plen + text.size()]
        if (from < plen)
        {
            const auto prefix      = BuildPrefix(line);
            const UINT32 firstPart = std::min(count, plen - from);
            result.append(prefix, from, firstPart);
            if (count > firstPart)
            {
                const UINT32 rem   = count - firstPart;
                const UINT32 tcopy = std::min<UINT32>(rem, static_cast<UINT32>(line.text.size()));
                result.append(line.text.Text(), 0, tcopy);
            }
        }
        else
        {
            const UINT32 off   = from - plen;
            const UINT32 tcopy = std::min<UINT32>(count, static_cast<UINT32>(line.text.size()) - std::min<UINT32>(off, static_cast<UINT32>(line.text.size())));
            if (off < line.text.size() && tcopy)
                result.append(line.text.Text(), off, tcopy);
        }
    };

    if (startLine == endLine)
    {
        if (startLine < _lines.size())
        {
            appendSlice(_lines[startLine], startOffset, length);
        }
        return result;
    }

    // First line tail
    if (startLine < _lines.size())
    {
        const auto& fl       = _lines[startLine];
        const UINT32 flTotal = PrefixLength(fl) + static_cast<UINT32>(fl.text.size());
        if (startOffset < flTotal)
            appendSlice(fl, startOffset, flTotal - startOffset);
        result += L'\n';
    }
    // Middle full lines
    for (size_t i = startLine + 1; i < endLine && i < _lines.size(); ++i)
    {
        const auto& ml = _lines[i];
        result += BuildPrefix(ml);
        result += ml.text.Text();
        result += L'\n';
    }
    // Last line head
    if (endLine < _lines.size())
    {
        const auto& ll    = _lines[endLine];
        const UINT32 upto = endOffset + 1; // inclusive end
        appendSlice(ll, 0, std::min<UINT32>(upto, PrefixLength(ll) + static_cast<UINT32>(ll.text.size())));
    }
    return result;
}

std::wstring Document::GetFilteredTextRange(UINT32 startOffset, UINT32 endOffset) const
{
    std::unique_lock lock(_rwMutex);
    if (endOffset <= startOffset || _lines.empty() || _visibleLines.empty())
        return L"";

    EnsureOffsetsValid();
    if (! _offsetsValid || _lineOffsets.size() != _lines.size())
        return L"";

    const auto [firstLine, firstOff] = GetLineAndOffsetUnsafe(startOffset);
    const auto [lastLine, lastOff]   = GetLineAndOffsetUnsafe(endOffset - 1u);
    static_cast<void>(firstOff);
    static_cast<void>(lastOff);

    auto it = std::lower_bound(_visibleLines.begin(), _visibleLines.end(), firstLine, [](const VisibleLine& vl, size_t src) { return vl.sourceIndex < src; });

    std::wstring result;
    bool firstChunk = true;
    for (; it != _visibleLines.end() && it->sourceIndex <= lastLine; ++it)
    {
        const size_t srcIndex = it->sourceIndex;
        if (srcIndex >= _lines.size())
            break;

        auto& line            = _lines[srcIndex];
        const UINT32 lineBase = static_cast<UINT32>(_lineOffsets[srcIndex] - _lineOffsetBase);
        const UINT32 lineLen  = PrefixLength(line) + static_cast<UINT32>(line.text.size());
        const UINT32 lineEnd  = lineBase + lineLen;

        const UINT32 segStart = std::max(startOffset, lineBase);
        const UINT32 segEnd   = std::min(endOffset, lineEnd);
        if (segEnd <= segStart)
            continue;

        if (! line.cachedDisplayValid)
        {
            const auto& prefix = BuildPrefix(line);
            line.cachedDisplay.clear();
            line.cachedDisplay.reserve(prefix.size() + line.text.size());
            line.cachedDisplay.append(prefix);
            line.cachedDisplay.append(line.text);
            line.cachedDisplay.erase(std::remove(line.cachedDisplay.begin(), line.cachedDisplay.end(), L'\r'), line.cachedDisplay.end());
            line.cachedDisplayValid = true;
        }

        const UINT32 localOff = segStart - lineBase;
        const UINT32 localLen = segEnd - segStart;
        if (localOff >= line.cachedDisplay.size() || localLen == 0u)
            continue;

        const UINT32 clampedLen = std::min(localLen, static_cast<UINT32>(line.cachedDisplay.size() - localOff));
        if (clampedLen == 0u)
            continue;

        if (! firstChunk)
            result.push_back(L'\n');
        firstChunk = false;
        result.append(line.cachedDisplay, localOff, clampedLen);
    }

    return result;
}

void Document::AddColorRange(UINT32 start, UINT32 length, const D2D1_COLOR_F& color)
{
    if (length == 0)
        return;

    std::unique_lock lock(_rwMutex);
    auto [startLine, startOffset] = GetLineAndOffsetUnsafe(start);
    auto [endLine, endOffset]     = GetLineAndOffsetUnsafe(start + length - 1);

    for (size_t lineIdx = startLine; lineIdx <= endLine && lineIdx < _lines.size(); ++lineIdx)
    {
        auto& line = _lines[lineIdx];

        const UINT32 plen     = PrefixLength(line);
        UINT32 localStartFull = (lineIdx == startLine) ? startOffset : 0;
        UINT32 localEndFull   = (lineIdx == endLine) ? endOffset : (plen + static_cast<UINT32>(line.text.size()) - 1);
        // Map to text-only coordinates, skipping prefix
        UINT32 localStart = (localStartFull > plen) ? (localStartFull - plen) : 0;
        UINT32 localEnd   = (localEndFull > plen) ? (localEndFull - plen) : 0;
        UINT32 localLen   = localEnd - localStart + 1;

        if (localLen > 0 && localStart < line.text.size())
        {
            localLen = std::min(localLen, static_cast<UINT32>(line.text.size()) - localStart);
            line.spans.push_back({localStart, localLen, color});
        }
    }
}

void Document::ColorizeWord(std::wstring_view word, const D2D1_COLOR_F& color, bool caseSensitive)
{
    if (word.empty())
        return;

    std::wstring lowerWord;
    if (! caseSensitive)
    {
        lowerWord.assign(word.begin(), word.end());
        std::transform(lowerWord.begin(), lowerWord.end(), lowerWord.begin(), ::towlower);
    }

    std::unique_lock lock(_rwMutex);
    const UINT32 wordLen = static_cast<UINT32>(word.size());
    for (size_t i = 0; i < _lines.size(); ++i)
    {
        auto& line                   = _lines[i];
        const std::wstring_view view = line.text.Text();
        size_t pos                   = 0;
        while (pos <= view.size())
        {
            const size_t found = caseSensitive ? view.find(word, pos) : FindWithLowerNeedle(view, lowerWord, pos);
            if (found == std::wstring::npos)
                break;

            line.spans.push_back({static_cast<UINT32>(found), wordLen, color});
            pos = found + std::max<size_t>(1u, word.size());
        }
    }
}

void Document::ClearColoring()
{
    std::unique_lock lock(_rwMutex); // Write operation
    for (auto& line : _lines)
        line.spans.clear();
}

std::optional<std::pair<size_t, size_t>> Document::ExtractDirtyLineRange()
{
    std::unique_lock lock(_rwMutex); // Write operation (modifies _dirtyRangeValid)
    if (! _dirtyRangeValid)
        return std::nullopt;
    std::pair<size_t, size_t> range{_dirtyRangeFirst, _dirtyRangeLast};
    ResetDirtyRange();
    return range;
}

void Document::MarkAllDirty()
{
    std::unique_lock lock(_rwMutex); // Write operation
    MarkAllDirtyUnsafe();
}

void Document::MarkAllDirtyUnsafe()
{
    // Assumes lock already held by caller
    if (_lines.empty())
    {
        ResetDirtyRange();
        return;
    }
    _dirtyRangeValid = true;
    _dirtyRangeFirst = 0;
    _dirtyRangeLast  = _lines.size() - 1;
}

void Document::EnableShowIds(bool enable)
{
    std::unique_lock lock(_rwMutex);
    _showIds = enable;
    InvalidateCaches(CacheInvalidationReason::ShowIdsChanged);
    MarkAllDirtyUnsafe(); // Already holding lock
}

const std::wstring& Document::BuildPrefix(const Line& line) const
{
    if (! line.hasMeta)
    {
        static const std::wstring emptyString;
        return emptyString;
    }

    // Cache the built prefix to avoid repeated allocations and conversions
    if (! line.cachedPrefix.empty())
        return line.cachedPrefix;

    line.cachedDisplayValid = false;
    line.cachedPrefix.clear();

    // Pre-allocate buffer for formatting to avoid multiple allocations
    std::array<wchar_t, 128> buffer{};
    size_t offset = 0;

    // Add emoji
    const auto emoji   = EmojiForType(line.meta.type);
    const int emojiLen = static_cast<int>(emoji.size());
    if (emojiLen > 0 && (offset + static_cast<size_t>(emojiLen)) < 128u)
    {
        wmemcpy(buffer.data() + offset, emoji.data(), static_cast<size_t>(emojiLen));
        offset += static_cast<size_t>(emojiLen);
    }

    // Format time using GetTimeString (HH:MM:SS.mmm)
    const std::wstring ts = line.meta.GetTimeString();
    const int tsLen       = static_cast<int>(ts.size());
    if (tsLen > 0 && (offset + static_cast<size_t>(tsLen)) < 128u)
    {
        wmemcpy(buffer.data() + offset, ts.data(), static_cast<size_t>(tsLen));
        offset += static_cast<size_t>(tsLen);
    }

    if (_showIds)
    {
        // Append process-thread ids if available (non-zero)
        if (line.meta.processID || line.meta.threadID)
        {
            // Format: " PID:TID "
            const size_t remaining = 128 - offset;
            if (remaining > 20u) // Ensure space for IDs
            {
                wchar_t* const outBegin = buffer.data() + offset;
                const auto result  = std::format_to_n(outBegin, static_cast<std::ptrdiff_t>(remaining - 1), L" {}:{}", line.meta.processID, line.meta.threadID);
                const auto written = std::max<std::ptrdiff_t>(std::ptrdiff_t{0}, result.out - outBegin);
                if (written > 0)
                {
                    offset += static_cast<size_t>(written);
                }
            }
        }
    }

    // Add trailing space
    if (offset < 127u)
    {
        buffer[static_cast<size_t>(offset)] = L' ';
        ++offset;
    }

    line.cachedPrefix.assign(buffer.data(), static_cast<size_t>(offset));
    return line.cachedPrefix;
}

UINT32 Document::PrefixLength(const Line& line) const
{
    if (! line.hasMeta)
        return 0;

    // Use cached length if valid (Optimization - avoids repeated .length() calls)
    if (line.cachedPrefixLenValid)
        return line.cachedPrefixLen;

    // BuildPrefix() caches the string; compute and cache the length
    const auto& prefix        = BuildPrefix(line);
    line.cachedPrefixLen      = static_cast<UINT32>(prefix.length());
    line.cachedPrefixLenValid = true;
    return line.cachedPrefixLen;
}
