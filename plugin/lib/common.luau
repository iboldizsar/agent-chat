local M = {}
function M.json(value) return noctalia.json.encode(value) end
function M.decode(value) return noctalia.json.decode(value or "") end
function M.encode(value) return noctalia.string.urlEncode(tostring(value)) end
function M.http(request, cb)
    request.headers = request.headers or { "Content-Type: application/json" }
    local accepted = noctalia.http(request, function(r)
        local data = M.decode(r.body) or {}
        if not r.ok or r.status < 200 or r.status >= 300 then
            local err = data.error or data.message or ("HTTP " .. tostring(r.status))
            if type(err) == "table" then err = err.message or "Backend request failed" end
            cb(nil, tostring(err):sub(1, 500))
        else cb(data, nil) end
    end)
    if not accepted then cb(nil, "Could not start local request") end
end
function M.state(backend)
    return { backend = backend, models = {}, agents = {}, sessions = {}, messages = {}, requests = {},
        status = "disconnected", error = "", model = "", agent = "", session = "", title = "New chat",
        usage = { known = false }, connected = false, busy = false, draft = "", attachments = {} }
end
function M.text(value)
    if type(value) == "string" then return value end
    return M.json(value) or ""
end
function M.message(id, role, text, details)
    return { id = id, role = role, text = (text or ""):sub(1, 200000), details = details or "" }
end
function M.primary(list)
    local result = {}
    for _, a in ipairs(list or {}) do
        if not a.hidden and a.mode ~= "subagent" then table.insert(result, a) end
    end
    return result
end
function M.ensureModel(s, preferred, default)
    local selected = preferred ~= "" and preferred or default
    for _, m in ipairs(s.models) do
        if m.key == selected then s.model = selected; return end
    end
    if selected ~= nil and selected ~= "" then
        s.model = selected
        s.error = "Selected model is unavailable. Choose a model before sending."
    elseif #s.models > 0 then s.model = s.models[1].key end
end
function M.selected(s)
    for _, m in ipairs(s.models) do if m.key == s.model then return m end end
    return nil
end
return M
