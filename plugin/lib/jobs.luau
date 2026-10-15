local M = {}
function M.new()
    local serial, active = 0, nil
    local registry = {}
    function registry.begin(kind, context)
        if active then return nil end
        serial = serial + 1
        active = { id = serial, kind = kind, context = context }
        return active
    end
    function registry.finish(job)
        if active ~= job then return false end
        active = nil; return true
    end
    function registry.matches(job, backend, session)
        return job.context.backend == backend and job.context.session == session
    end
    function registry.current(job, backend, session, navigation)
        local origin = job.context
        return origin.backend == backend and origin.session == session and origin.navigation == navigation
    end
    function registry.pending() return active and active.kind or nil end
    return registry
end
return M
