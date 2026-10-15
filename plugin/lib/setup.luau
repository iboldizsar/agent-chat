-- Bounded, metadata-only discovery from the actual Noctalia process environment.
local M = {}
function M.new(api, changed)
    local A = { state = { checking = false, backends = {}, tools = {} } }
    local generation, started = 0, 0
    function A.check(done)
        if A.state.checking then return end
        generation = generation + 1
        local token = generation
        A.state.checking = true; A.state.error = nil; started = api.nowMs(); changed()
        local function finish(result)
            if token ~= generation then return end
            generation = generation + 1; A.state.checking = false
            local ok, value = pcall(api.json.decode, result and result.stdout or "")
            local valid = ok and type(value) == "table" and type(value.backends) == "table" and type(value.tools) == "table"
            for _, name in ipairs({ "opencode", "codex" }) do
                local info = valid and value.backends[name]
                if type(info) ~= "table" or not ({ available = true, missing = true, unsupported = true, unverified = true })[info.status] then valid = false end
            end
            if valid and not result.timedOut and (not result.exitCode or result.exitCode == 0) then
                A.state.backends = value.backends; A.state.tools = value.tools
                if done then done(value) end
            else
                A.state.backends = {}; A.state.tools = {}
                A.state.error = "Could not check desktop dependencies. Ensure Python 3.11+ is available to Noctalia, then check again."
            end
            changed()
        end
        if not api.runAsync({ "python3", api.pluginDir() .. "/helper/runtime_check.py" }, finish) then finish(nil) end
    end
    function A.tick()
        if A.state.checking and api.nowMs() - started > 8000 then
            generation = generation + 1; A.state.checking = false
            A.state.backends = {}; A.state.tools = {}
            A.state.error = "Dependency check timed out. Check desktop PATH and try again."; changed()
        end
    end
    function A.close() generation = generation + 1; A.state.checking = false end
    return A
end
return M
