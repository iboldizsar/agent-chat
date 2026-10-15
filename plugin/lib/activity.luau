local M = {}
function M.new()
    local previous = {}
    return function(name, s, submitting)
        local old = previous[name]
        local same = old and old.session == s.session
        local wasActive = same and old.active
        local phase
        if not s.connected then phase = (wasActive or s.busy) and "interrupted" or "idle"
        elseif s.limitPaused or (s.usage or {}).blocked then phase = "usage-paused"
        elseif s.recovering then phase = "recovering"
        elseif submitting then phase = "submitting"
        elseif s.stopping and (s.busy or #(s.requests or {}) > 0) then phase = "stopping"
        elseif #(s.requests or {}) > 0 then phase = "waiting"
        elseif s.busy then phase = "running"
        elseif wasActive then phase = (s.error or "") == "" and "completed" or "interrupted"
        else phase = "idle" end
        if s.connected and not s.recovering and not s.busy and #(s.requests or {}) == 0 then s.stopping = false end
        previous[name] = { session = s.session, active = s.busy or phase == "interrupted" }
        return phase
    end
end
return M
