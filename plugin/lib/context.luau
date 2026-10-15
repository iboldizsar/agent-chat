--!nonstrict
-- Store installs have the same portable default context as local installs.
local M = {}
function M.new(api, cwd, changed)
    local pending, started, serial = {}, nil, 0
    local A = {}
    local function finish(token, ready, message)
        if token ~= serial then return end
        serial = serial + 1; started = nil
        local callbacks = pending; pending = {}
        for _, callback in ipairs(callbacks) do callback(ready, message) end
        changed()
    end
    function A.ensure(done)
        local path = cwd .. "/AGENTS.md"
        local info = api.fileInfo and api.fileInfo(path)
        if (info and not info.isDir) or (not api.fileInfo and api.fileExists(path)) then done(true); return end
        table.insert(pending, done)
        if started then return end
        serial = serial + 1; local token = serial; started = api.nowMs()
        local launched = api.runAsync({ "python3", api.pluginDir() .. "/helper/context.py", "--directory", cwd }, function(result)
            local ok, value = pcall(api.json.decode, result and result.stdout or "")
            local ready = ok and type(value) == "table" and value.ready == true and not result.timedOut and (not result.exitCode or result.exitCode == 0)
            finish(token, ready, ok and type(value) == "table" and value.error or "Could not prepare assistant context. Check Python and directory access, then reconnect.")
        end)
        if not launched then finish(token, false, "Could not start assistant setup. Ensure Python is available to Noctalia.") end
    end
    function A.tick()
        if started and api.nowMs() - started > 8000 then finish(serial, false, "Assistant setup timed out. Check directory access, then reconnect.") end
    end
    function A.close() serial = serial + 1; started = nil; pending = {} end
    return A
end
return M
