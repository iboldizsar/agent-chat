local M = {}
-- Accept legacy pin timestamps in either backend's units; adapters normalize new rows.
function M.seconds(value)
    if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then return nil end
    return value >= 100000000000 and value / 1000 or value
end
function M.history(sessions, pins, search, onlyPinned)
    local result, known, available = {}, {}, {}
    local query = (search or ""):lower()
    for _, session in ipairs(sessions or {}) do available[session.id] = session end
    local function matches(title) return query == "" or title:lower():find(query, 1, true) end
    for id, pin in pairs(pins or {}) do
        local live = available[id]
        local title = live and live.title or pin.title
        if matches(title) then
            table.insert(result, { id = id, title = title, pinned = true,
                updated = live and live.updated or pin.updated, unverified = live == nil })
            known[id] = true
        end
    end
    table.sort(result, function(a, b) if a.title:lower() == b.title:lower() then return a.id < b.id end; return a.title:lower() < b.title:lower() end)
    if not onlyPinned then
        local others = {}
        for _, session in ipairs(sessions or {}) do
            if not known[session.id] and matches(session.title) then table.insert(others, session); known[session.id] = true end
        end
        table.sort(others, function(a, b)
            local first, second = M.seconds(a.updated) or 0, M.seconds(b.updated) or 0
            if first == second then return a.id < b.id end
            return first > second
        end)
        for _, session in ipairs(others) do table.insert(result, session) end
    end
    return result
end
-- Calendar ordinal from local YYYY-MM-DD, avoiding 24-hour assumptions across DST.
local function ordinal(date)
    if type(date) ~= "string" then return nil end
    local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not year then return nil end
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if month < 1 or month > 12 or day < 1 or day > 31 then return nil end
    if month <= 2 then year = year - 1 end
    local era = math.floor(year / 400)
    local y = year - era * 400
    local m = month + (month > 2 and -3 or 9)
    return era * 146097 + y * 365 + math.floor(y / 4) - math.floor(y / 100) + math.floor((153 * m + 2) / 5) + day
end
function M.groups(sessions, pins, search, onlyPinned, now, localDate)
    local groups = {}
    local names = { "Pinned", "Today", "Yesterday", "Previous 7 days", "Older", "Unknown date" }
    for _, name in ipairs(names) do table.insert(groups, { title = name, rows = {} }) end
    local today = ordinal(localDate(now))
    for _, session in ipairs(M.history(sessions, pins, search, onlyPinned)) do
        local index = 1
        if not session.pinned then
            local timestamp = M.seconds(session.updated)
            local day = timestamp and ordinal(localDate(timestamp))
            local age = day and today and today - day
            index = not age and 6 or (age == 0 and 2 or (age == 1 and 3 or (age >= 2 and age <= 7 and 4 or (age > 7 and 5 or 6))))
        end
        table.insert(groups[index].rows, session)
    end
    return groups
end
-- fetch(cursor, callback) returns descending normalized messages and a next cursor.
function M.collect(fetch, done)
    local rows, ids, cursors, pages, finished = {}, {}, {}, 0, false
    local function finish(value, err)
        if finished then return end
        finished = true; done(value, err)
    end
    local step
    step = function(cursor)
        pages = pages + 1
        if pages > 500 then finish(nil, "Conversation exceeds the export page limit; no partial export was saved."); return end
        fetch(cursor, function(page, nextCursor, err)
            if finished then return end
            if not page then finish(nil, err or "Could not read conversation"); return end
            for _, row in ipairs(page) do
                if not ids[row.id] then ids[row.id] = true; table.insert(rows, row) end
            end
            if nextCursor and nextCursor ~= "" then
                if cursors[nextCursor] then finish(nil, "Backend repeated an export cursor; no partial export was saved."); return end
                cursors[nextCursor] = true; step(nextCursor)
            else
                local ordered = {}
                for i = #rows, 1, -1 do table.insert(ordered, rows[i]) end
                finish(ordered)
            end
        end)
    end
    step(nil)
end
function M.markdown(title, backend, messages)
    local out = { "# " .. (title or "Conversation"):gsub("[\r\n]", " "), "", "Backend: " .. backend, "", "Attachment contents are not embedded. Activity summaries may be abbreviated.", "" }
    for _, message in ipairs(messages) do
        table.insert(out, "## " .. (message.role or "Message"))
        table.insert(out, "")
        table.insert(out, message.text or "")
        table.insert(out, "")
        if message.details and message.details ~= "" then
            local length = 3
            for run in message.details:gmatch("`+") do length = math.max(length, #run + 1) end
            local fence = string.rep("`", length)
            table.insert(out, "### Activity\n\n" .. fence .. "text\n" .. message.details .. "\n" .. fence .. "\n")
        end
    end
    return table.concat(out, "\n")
end
return M
