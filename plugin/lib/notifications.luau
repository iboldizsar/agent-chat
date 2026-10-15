--!nonstrict
local M = {}
local function quote(value) return "'" .. value:gsub("'", "'\\''") .. "'" end
function M.new(openChat)
    local previous, seen = {}, {}
    local function notify(name, session, waiting)
        if noctalia.getConfig(waiting and "notify_approvals" or "notify_completion") == false then return end
        local title = waiting and "Agent Chat needs your input" or "Agent Chat response finished"
        local body = (name == "codex" and "Codex" or "OpenCode") .. " · Open chat to continue."
        if noctalia.commandExists("notify-send") then
            noctalia.runStream("exec notify-send --app-name='Agent Chat' --icon=dialog-information --expire-time=10000 --action=open='Open chat' " .. quote(title) .. " " .. quote(body), function(action)
                if action == "open" then openChat(name, session) end
            end)
        else noctalia.notify(title, body) end
    end
    return function(name, s, hidden)
        local old = previous[name]
        local ids = {}
        for _, request in ipairs(s.requests or {}) do table.insert(ids, tostring(request.id)) end
        table.sort(ids)
        local signature = (s.session or "") .. ":" .. table.concat(ids, ",")
        if old and old.session == s.session then
            if #ids > 0 and not s.recovering and not seen[name .. signature] then
                seen[name .. signature] = true
                if hidden then notify(name, s.session, true) end
            elseif old.busy and old.connected and not old.recovering and not s.recovering and not s.busy and s.connected and s.status ~= "waiting" and #ids == 0 and (s.error or "") == "" then
                if hidden then notify(name, s.session, false) end
            end
        elseif #ids > 0 then
            -- Initial/reconnected snapshots are a baseline, not new events.
            seen[name .. signature] = true
        end
        previous[name] = { busy = s.busy, session = s.session, connected = s.connected, recovering = s.recovering }
    end
end
return M
