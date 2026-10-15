--!nonstrict
local M = {}
local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
function M.new(openChat, checkpoint, changed)
    local previous, seen = {}, {}
    checkpoint = checkpoint or {}
    for _, key in ipairs(checkpoint) do seen[key] = true end
    local function remember(key)
        if seen[key] then return false end
        seen[key] = true; table.insert(checkpoint, key)
        while #checkpoint > 128 do seen[table.remove(checkpoint, 1)] = nil end
        if changed then changed() end
        return true
    end
    local function notify(name, session, waiting)
        if noctalia.getConfig(waiting and "notify_approvals" or "notify_completion") == false then return end
        local title = waiting and "Agent Chat needs your input" or "Agent Chat response finished"
        local body = (name == "codex" and "Codex" or "OpenCode") .. " · Open chat to continue."
        if noctalia.commandExists("notify-send") then
            local activated = false
            local launched = noctalia.runStream("exec notify-send --app-name='Agent Chat' --icon=dialog-information --expire-time=10000 --action=open='Open chat' " .. quote(title) .. " " .. quote(body), function(action)
                if action == "open" and not activated then activated = true; openChat(name, session) end
            end)
            if not launched then noctalia.notify(title, body) end
        else noctalia.notify(title, body) end
    end
    return function(name, s, hidden)
        local old = previous[name]
        local ids = {}
        for _, request in ipairs(s.requests or {}) do table.insert(ids, tostring(request.id)) end
        table.sort(ids)
        local fresh = false
        for _, id in ipairs(ids) do
            if remember(name .. ":" .. (s.session or "") .. ":" .. id) then fresh = true end
        end
        if old and old.session == s.session then
            if #ids > 0 and not s.recovering and s.connected and fresh then
                if hidden then notify(name, s.session, true) end
            elseif old.busy and old.connected and not old.recovering and not s.recovering and not s.busy and s.connected and s.status ~= "waiting" and #ids == 0 and (s.error or "") == "" then
                if hidden then notify(name, s.session, false) end
            end
        end
        previous[name] = { busy = s.busy, session = s.session, connected = s.connected, recovering = s.recovering }
    end
end
return M
