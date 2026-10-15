-- One in-flight connection attempt, generation guards and bounded automatic recovery.
local M = {}
function M.new(now, random)
    random = random or math.random
    local epoch, inFlight = 0, false
    local state = { phase = "offline", attempt = 0 }
    local controller = { state = state }
    function controller.valid(token) return token == epoch end
    function controller.token() return epoch end
    function controller.begin(manual)
        if inFlight then return nil end
        if manual then state.attempt = 0 end
        epoch = epoch + 1; inFlight = true
        state.attempt = state.attempt + 1
        state.phase = state.attempt == 1 and "connecting" or "reconnecting"
        state.nextRetryAt = nil; state.startedAt = now()
        return epoch
    end
    function controller.success(token)
        if not controller.valid(token) then return false end
        inFlight = false; state.phase = "connected"; state.attempt = 0
        state.nextRetryAt = nil; state.startedAt = nil
        return true
    end
    function controller.failure(token, retryable)
        if not controller.valid(token) then return false end
        epoch = epoch + 1
        inFlight = false; state.startedAt = nil
        if state.attempt == 0 then state.attempt = 1 end
        state.phase = retryable and state.attempt < 8 and "reconnecting" or "offline"
        state.nextRetryAt = state.phase == "reconnecting" and
            (now() + math.min(30000, 1000 * 2 ^ (state.attempt - 1) * (0.8 + random() * 0.4))) or nil
        return true
    end
    function controller.due() return not inFlight and state.nextRetryAt ~= nil and now() >= state.nextRetryAt end
    function controller.expired() return inFlight and now() - state.startedAt > 20000 end
    function controller.close()
        epoch = epoch + 1; inFlight = false
        state.phase = "offline"; state.nextRetryAt = nil; state.startedAt = nil
    end
    return controller
end
return M
