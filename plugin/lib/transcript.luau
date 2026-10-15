--!nonstrict
-- Presentation only: keep backend messages and Markdown exports unchanged.
local M = {}
function M.rows(messages)
    local rows, group = {}, nil
    for _, message in ipairs(messages or {}) do
        local text = message.text or ""
        local isActivity = message.role == "Tool" or (message.role == "Assistant" and not text:match("%S") and (message.details or "") ~= "")
        if isActivity then
            if not group then
                group = { id = "activity-" .. message.id, role = "Activity", items = {} }
                table.insert(rows, group)
            end
            table.insert(group.items, message)
        elseif message.role ~= "Assistant" or text:match("%S") then
            group = nil; table.insert(rows, message)
        end
    end
    return rows
end
function M.summary(group)
    local commands, failed, running = 0, 0, false
    for _, item in ipairs(group.items) do
        if item.activityKind == "commandExecution" then commands = commands + 1 end
        local status = item.activityStatus
        if status == "failed" or status == "error" or status == "declined" then failed = failed + 1 end
        if status == "inProgress" or status == "running" or status == "pending" then running = true end
    end
    local count = #group.items
    local text = "Activity · " .. tostring(count) .. (commands == count and (count == 1 and " command" or " commands") or (count == 1 and " step" or " steps"))
    if failed > 0 then text = text .. " · " .. tostring(failed) .. " failed"
    elseif running then text = text .. " · running" end
    return text, failed > 0
end
return M
