--!nonstrict
local M = {}
function M.status(usage, now, connected)
    usage = usage or {}
    if not usage.known or #(usage.windows or {}) == 0 then return "unavailable" end
    local checked = tonumber(usage.checkedAt)
    if not connected or usage.stale or not checked or checked > now + 60 or now - checked > 300 then return "stale" end
    return "current"
end
return M
