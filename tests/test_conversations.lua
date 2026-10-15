local root = assert(arg[1])
local M = assert(loadfile(root .. '/plugin/lib/conversations.luau'))()
local sorted = M.history({ { id = 'new', title = 'Newest' }, { id = 'pin', title = 'Pinned' } }, { pin = { title = 'Pinned' }, old = { title = 'Archive' } }, '')
assert(#sorted == 3 and sorted[1].id == 'old' and sorted[2].id == 'pin' and sorted[3].id == 'new')
assert(sorted[1].pinned and sorted[2].pinned)
local filtered = M.history({}, { pin = { title = 'Pinned' }, old = { title = 'Archive' } }, 'ARCH')
assert(#filtered == 1 and filtered[1].id == 'old', 'pins outside the latest page remain searchable')
local result, errorText
M.collect(function(cursor, cb)
    if not cursor then cb({ { id = '3', role = 'Assistant', text = 'Latest' }, { id = '2', role = 'You', text = 'Question' } }, 'older')
    else cb({ { id = '2', text = 'duplicate' }, { id = '1', role = 'Assistant', text = 'Earlier', details = 'nested ``` fence' } }) end
end, function(rows, err) result, errorText = rows, err end)
assert(not errorText and #result == 3 and result[1].id == '1' and result[3].id == '3', 'export must include older pages chronologically without duplicates')
local markdown = M.markdown('Title\nInjected', 'codex', result)
assert(markdown:find('# Title Injected', 1, true))
assert(markdown:find('````text\nnested ``` fence\n````', 1, true))
M.collect(function(_, cb) cb({}, 'repeat') end, function(rows, err) assert(not rows); errorText = err end)
assert(errorText:find('repeated'), 'cursor loop must fail rather than produce a partial export')
M.collect(function(_, cb) cb(nil, nil, 'network failure') end, function(rows, err) assert(not rows and err == 'network failure') end)
print('Pinned history, full export pagination, escaping and failure handling: passed')

-- Map deliberately uneven epoch distances to calendar dates (DST/midnight).
local dates = { [100] = '2026-03-30', [99] = '2026-03-29', [98] = '2026-03-28', [97] = '2026-03-23', [96] = '2026-03-22', [95] = '2026-03-31' }
local groups = M.groups({
    { id = 'today', title = 'Today', updated = 100 },
    { id = 'yesterday', title = 'Yesterday', updated = 99 },
    { id = 'week', title = 'Week', updated = 98 },
    { id = 'edge', title = 'Edge', updated = 97 },
    { id = 'older', title = 'Older', updated = 96 },
    { id = 'missing', title = 'Missing' },
    { id = 'future', title = 'Future', updated = 95 },
}, { saved = { title = 'Saved' } }, '', false, 100, function(t) return dates[t] end)
assert(groups[1].rows[1].unverified and groups[2].rows[1].id == 'today')
assert(groups[3].rows[1].id == 'yesterday' and #groups[4].rows == 2 and #groups[5].rows == 1 and #groups[6].rows == 2)
assert(M.seconds(1800000000000) == 1800000000 and M.seconds(1800000000) == 1800000000)
assert(not M.seconds(0) and not M.seconds(0/0) and not M.seconds(math.huge))
local rows = M.history({ { id = 'p', title = 'New title', updated = 99 }, { id = 'x', title = 'No match' } }, { p = { title = 'Old title' } }, 'new', true)
assert(#rows == 1 and rows[1].title == 'New title' and not rows[1].unverified)
assert(#M.history({ { id = 'x', title = 'Other' } }, {}, 'absent') == 0)
print('Local calendar grouping, unknown dates, normalized units and pinned title filters: passed')
