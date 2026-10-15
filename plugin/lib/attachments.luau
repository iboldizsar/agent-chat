local M = {}
local running = {}
local serial = 0
local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end
local function interactive(helper, arguments, done)
    local command = "exec python3 -u " .. quote(noctalia.pluginDir() .. "/helper/interactive_job.py")
        .. " python3 -u " .. quote(helper)
    for _, value in ipairs(arguments) do command = command .. " " .. quote(value) end
    serial = serial + 1
    local id = serial
    local operation = { lastSeen = noctalia.nowMs(), finished = false }
    local function finish(result)
        if operation.finished then return end
        operation.finished = true; running[id] = nil; done(result)
    end
    operation.finish = finish
    running[id] = operation
    local launched = noctalia.runStream(command, function(line)
        if operation.finished then return end
        operation.lastSeen = noctalia.nowMs()
        if line ~= "@agent-chat:alive" then finish({ stdout = line }) end
    end)
    if not launched then operation.finished = true; running[id] = nil end
    return launched
end
function M.capture(mode, directory, done)
    local helper = noctalia.pluginDir() .. "/helper/attachments.py"
    if mode == "pick" or mode == "screenshot" then
        return interactive(helper, { mode, "--directory", directory }, done)
    end
    return noctalia.runAsync({ "python3", helper, mode, "--directory", directory }, done)
end
function M.saveExport(source, suggested, done)
    return interactive(noctalia.pluginDir() .. "/helper/export_file.py", { "--source", source, "--suggested", suggested }, done)
end
function M.tick()
    for _, operation in pairs(running) do
        if noctalia.nowMs() - operation.lastSeen > 15000 then
            operation.finish({ stdout = '{"error":"Desktop helper stopped responding. Try again."}' })
        end
    end
end
return M
