local M = {}
local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end
function M.capture(mode, directory, done)
    local helper = noctalia.pluginDir() .. "/helper/attachments.py"
    if mode == "pick" or mode == "screenshot" then
        -- Captured runAsync commands have a short host deadline. A picker waits
        -- for the user, so use the lifecycle-managed streaming process instead.
        local command = "exec python3 -u " .. quote(helper) .. " " .. quote(mode) .. " --directory " .. quote(directory)
        local finished = false
        return noctalia.runStream(command, function(line)
            if finished then return end
            finished = true
            done({ stdout = line })
        end)
    end
    return noctalia.runAsync({ "python3", helper, mode, "--directory", directory }, done)
end
function M.saveExport(source, suggested, done)
    local command = "exec python3 -u " .. quote(noctalia.pluginDir() .. "/helper/export_file.py")
        .. " --source " .. quote(source) .. " --suggested " .. quote(suggested)
    local finished = false
    return noctalia.runStream(command, function(line)
        if finished then return end
        finished = true; done({ stdout = line })
    end)
end
return M
