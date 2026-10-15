local M = {}
function M.history(sessions, pins, search)
    local result, known = {}, {}
    local query = (search or ""):lower()
    for id, pin in pairs(pins or {}) do
        if query == "" or pin.title:lower():find(query, 1, true) then
            table.insert(result, { id = id, title = pin.title, pinned = true, updated = pin.updated })
            known[id] = true
        end
    end
    table.sort(result, function(a, b) if a.title:lower() == b.title:lower() then return a.id < b.id end; return a.title:lower() < b.title:lower() end)
    for _, session in ipairs(sessions) do
        if not known[session.id] then table.insert(result, session); known[session.id] = true end
    end
    return result
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
