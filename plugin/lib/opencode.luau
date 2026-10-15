--!nonstrict
local C = require("./common.luau")
local Conversations = require("./conversations.luau")
local Connection = require("./connection.luau")
local M = {}
function M.new(cwd, changed)
    local s = C.state("opencode")
    local A = { state = s }
    local connection = Connection.new(noctalia.nowMs)
    s.connection = connection.state
    local historyGeneration = 0
    local endpoint = nil
    local stream = nil
    local dirty = false
    local refreshing = false
    local refreshGeneration = 0
    local agentGeneration = 0
    local nextRefresh = 0
    local generation = 0
    local agentRetryAt = 0
    local limitSeen = {}
    local function publish() changed() end
    local function fail(err) s.error = err; publish() end
    local function request(method, path, body, cb, deliverStale)
        if not endpoint then cb(nil, "OpenCode is not connected"); return end
        local token = connection.token()
        C.http({ url = endpoint.url .. path, method = method,
            body = body and C.json(body) or "", basic_username = "opencode",
            basic_password = endpoint.password }, function(r, err)
                if connection.valid(token) then cb(r, err)
                elseif method ~= "GET" or deliverStale then cb(nil, "Connection changed; the request was not repeated. Check recovered history before retrying.") end
            end)
    end
    local function location(path)
        return path .. (path:find("?", 1, true) and "&" or "?") .. "location%5Bdirectory%5D=" .. C.encode(cwd)
    end
    local function sessionPath(tail) return "/api/session/" .. C.encode(s.session) .. (tail or "") end
    function A.discover()
        request("GET", location("/api/model"), nil, function(r, err)
            if not r then fail(err); return end
            s.models = {}
            for _, m in ipairs(r.data or {}) do
                if m.enabled then
                    local modalities = (m.capabilities or {}).input or {}
                    table.insert(s.models, { key = m.providerID .. "/" .. m.id, id = m.id,
                        provider = m.providerID, label = m.name .. " · " .. m.providerID,
                        modalities = modalities })
                end
            end
            request("GET", location("/api/model/default"), nil, function(d)
                local m = d and d.data
                C.ensureModel(s, s.model, m and (m.providerID .. "/" .. m.id))
                publish()
            end)
        end)
        A.loadAgents()
        A.list(s.historyQuery or "")
    end
    function A.loadAgents()
        agentGeneration = agentGeneration + 1
        local agentToken = agentGeneration
        request("GET", location("/api/agent"), nil, function(r)
            if agentToken ~= agentGeneration then return end
            s.agents = C.primary(r and r.data)
            agentRetryAt = #s.agents == 0 and (os.time() + 3) or 0
            if s.agent == "" then
                for _, a in ipairs(s.agents) do if a.id == "build" then s.agent = a.id end end
            end
            publish()
        end)
    end
    function A.connect(manual)
        local token = connection.begin(manual ~= false)
        if not token then return end
        generation = generation + 1; refreshing = false
        s.connected = false; s.recoveryFailed = false; s.status = "connecting"
        if stream then stream.stop(); stream = nil end
        publish()
        local raw = noctalia.readFile(noctalia.expandPath("~/.local/state/opencode/service.json"))
        endpoint = raw and C.decode(raw)
        if not endpoint or type(endpoint.url) ~= "string" or not endpoint.url:match("^http://127%.0%.0%.1:%d+$") then
            endpoint = nil; s.connected = false; s.status = "disconnected"
            connection.failure(token, false)
            fail("OpenCode service is unavailable. Start it with opencode service start, then Retry.")
            return
        end
        request("GET", "/api/info", nil, function(r, err)
            if not r then connection.failure(token, true); s.connected = false; s.status = "disconnected"; fail(err); return end
            connection.success(token)
            s.connected = true; s.status = "idle"; s.error = ""; s.limitPaused = false
            A.discover()
            if s.session ~= "" then A.open(s.session) end
            if stream then stream.stop(); stream = nil end
            stream = noctalia.httpStream({ url = endpoint.url .. "/api/event",
                basic_username = "opencode", basic_password = endpoint.password }, function(line)
                if not connection.valid(token) or line:sub(1, 5) ~= "data:" then return end
                local e = C.decode(line:sub(6))
                if not e then return end
                local d = e.data or {}
                local id = d.sessionID or (d.session and d.session.id) or (d.form and d.form.sessionID)
                if id == s.session or (not id and e.type == "server.connected") then dirty = true end
            end, function()
                if not connection.valid(token) then return end
                connection.failure(token, true)
                stream = nil; s.connected = false; s.status = "disconnected"; publish()
            end)
            publish()
        end)
    end
    function A.list(search, cursor)
        if not cursor then historyGeneration = historyGeneration + 1 end
        if s.historyLoading and cursor then return end
        s.historyLoading = true; s.historyError = nil; s.historyPendingCursor = cursor
        if not cursor then
            s.historyQuery = search or ""; s.sessions = {}; s.historyCursor = nil
            s.historyCursors = {}
        end
        publish()
        local currentHistory = historyGeneration
        local path = "/api/session?directory=" .. C.encode(cwd) .. "&limit=40&parentID=null"
        if search and search ~= "" then path = path .. "&search=" .. C.encode(search) end
        if cursor then path = path .. "&cursor=" .. C.encode(cursor) end
        request("GET", path, nil, function(r, err)
            if currentHistory ~= historyGeneration then return end
            s.historyLoading = false; s.historyPendingCursor = nil
            if not r then s.historyError = "Could not load history. Try again when connected."; publish(); return end
            if not cursor then s.sessions = {} end
            local seen = {}
            for _, session in ipairs(s.sessions) do seen[session.id] = true end
            for _, x in ipairs(r.data or {}) do
                if not seen[x.id] then
                    table.insert(s.sessions, { id = x.id, title = x.title or "Untitled", updated = Conversations.seconds((x.time or {}).updated) })
                    seen[x.id] = true
                end
            end
            local nextCursor = r.cursor and r.cursor.next or nil
            if cursor then s.historyCursors[cursor] = true end
            if nextCursor and s.historyCursors[nextCursor] then
                s.historyCursor = nil; s.historyError = "History returned a repeated page. Refresh to try again."
            else s.historyCursor = nextCursor end
            publish()
        end, true)
    end
    local function messages(data, full)
        local out = {}
        for _, m in ipairs(data or {}) do
            if m.type == "user" then
                table.insert(out, C.message(m.id, "You", m.text))
                if full then out[#out].text = m.text or "" end
            elseif m.type == "assistant" then
                local text, detail = {}, {}
                for _, part in ipairs(m.content or {}) do
                    if part.type == "text" then table.insert(text, part.text)
                    elseif part.type == "tool" then
                        table.insert(detail, part.name .. " · " .. (part.state.status or "") .. "\n" .. C.text(part.state):sub(1, 12000))
                    end
                end
                if m.error then table.insert(detail, C.text(m.error)) end
                table.insert(out, C.message(m.id, "Assistant", table.concat(text, "\n"), table.concat(detail, "\n\n")))
                if full then out[#out].text = table.concat(text, "\n") end
            end
        end
        return out
    end
    function A.export(done)
        local id = s.session
        Conversations.collect(function(cursor, callback)
            local path = "/api/session/" .. C.encode(id) .. "/message?limit=50"
            path = path .. (cursor and ("&cursor=" .. C.encode(cursor)) or "&order=desc")
            request("GET", path, nil, function(r, err)
                if not r then callback(nil, nil, err); return end
                callback(messages(r.data, true), r.cursor and r.cursor.next)
            end, true)
        end, done)
    end
    function A.refresh(cursor, loaded)
        if s.session == "" or refreshing then return end
        refreshing = true
        refreshGeneration = refreshGeneration + 1
        local refreshToken = refreshGeneration
        local id, gen = s.session, generation
        local count, healthy = 4, true
        local function complete(ok)
            healthy = healthy and ok; count = count - 1
            if count == 0 then
                s.status = #s.requests > 0 and "waiting" or (s.busy and "working" or "idle")
                if loaded then loaded(healthy) end
            end
        end
        local path = sessionPath("/message?limit=50")
        if cursor then path = path .. "&cursor=" .. C.encode(cursor) else path = path .. "&order=desc" end
        request("GET", path, nil, function(r, err)
            if s.session ~= id or gen ~= generation or refreshToken ~= refreshGeneration then return end
            refreshing = false
            if not r then fail(err); complete(false); return end
            for _, item in ipairs(r.data or {}) do
                local issue = C.text(item.error or item.retry or ""):lower()
                if not limitSeen[item.id] and (issue:find("rate.limit") or issue:find("usage.limit") or issue:find("quota", 1, true) or issue:find("429", 1, true)) then
                    limitSeen[item.id] = true
                    if not s.limitPaused then A.stop() end
                    s.limitPaused = true
                    s.error = "OpenCode reported a usage/rate limit. Generation stopped. Retry reconnects without resending."
                end
            end
            local list = messages(r.data)
            local ordered = {}
            for i = #list, 1, -1 do table.insert(ordered, list[i]) end
            if cursor then for _, m in ipairs(s.messages) do table.insert(ordered, m) end end
            s.messages = ordered
            s.messageCursor = r.cursor and r.cursor.next or nil
            publish(); complete(true)
        end)
        request("GET", "/api/session/active", nil, function(r)
            if s.session ~= id or gen ~= generation or refreshToken ~= refreshGeneration then return end
            if r then
                s.busy = (r.data or {})[id] ~= nil
                s.status = s.busy and "working" or "idle"
                publish()
            end
            complete(r ~= nil)
        end)
        local requests = {}
        local remaining, permissionHealthy = 2, true
        local function done()
            remaining = remaining - 1
            if remaining == 0 and s.session == id and gen == generation and refreshToken == refreshGeneration then
                if permissionHealthy then s.requests = requests end
                if #requests > 0 then s.status = "waiting" end
                publish()
            end
        end
        request("GET", sessionPath("/permission"), nil, function(r, err)
            if s.session ~= id or gen ~= generation or refreshToken ~= refreshGeneration then return end
            if err then fail("Could not load permissions: " .. err) end
            for _, p in ipairs(r and r.data or {}) do
                table.insert(requests, { id = p.id, kind = "permission", title = p.message or p.action,
                    text = table.concat(p.resources or {}, "\n") })
            end
            permissionHealthy = permissionHealthy and r ~= nil
            done(); complete(r ~= nil)
        end)
        request("GET", sessionPath("/form"), nil, function(r, err)
            if s.session ~= id or gen ~= generation or refreshToken ~= refreshGeneration then return end
            if err then fail("Could not load questions: " .. err) end
            for _, p in ipairs(r and r.data or {}) do
                table.insert(requests, { id = p.id, kind = "form", title = p.title, fields = p.fields })
            end
            permissionHealthy = permissionHealthy and r ~= nil
            done(); complete(r ~= nil)
        end)
    end
    function A.open(id, done)
        generation = generation + 1
        refreshing = false; s.recovering = true; s.recoveryFailed = false
        local gen = generation
        request("GET", "/api/session/" .. C.encode(id), nil, function(r, err)
            if gen ~= generation then return end
            if not r then
                s.openFailures = s.openFailures or {}; s.openFailures[id] = true
                -- A failed lookup of a different chat does not invalidate the idle chat.
                s.recovering = id == s.session; s.recoveryFailed = id == s.session
                fail(err); if done then done(false) end; return
            end
            if (r.data.location or {}).directory ~= cwd then
                s.recovering = id == s.session; s.recoveryFailed = id == s.session
                fail("Conversation is outside assistant directory"); if done then done(false) end; return
            end
            s.session = id; s.title = r.data.title or "Chat"; s.agent = r.data.agent or s.agent
            local m = r.data.model
            if m then s.model = m.providerID .. "/" .. m.id end
            s.openFailures = s.openFailures or {}; s.openFailures[id] = nil
            s.messages = {}; s.error = ""
            if done then done(true) end
            A.refresh(nil, function(ok)
                if gen ~= generation then return end
                s.recovering = not ok; s.recoveryFailed = not ok; publish()
            end)
            publish()
        end)
    end
    function A.new()
        s.recovering = false; s.recoveryFailed = false
        generation = generation + 1
        s.session = ""; s.title = "New chat"; s.messages = {}; s.requests = {}; s.busy = false
        s.status = s.connected and "idle" or "disconnected"; s.error = ""; publish()
    end
    function A.send(text, files, done)
        if s.busy then done(false, "Wait for this turn or press Stop"); return end
        local model = C.selected(s)
        if not model then done(false, "Choose an available model"); return end
        local function submit()
            request("POST", sessionPath("/model"), { model = { id = model.id, providerID = model.provider } }, function(_, err)
                if err then done(false, err); return end
                local prompt = { text = text }
                if files and #files > 0 then prompt.files = files end
                request("POST", sessionPath("/prompt"), prompt, function(r, sendError)
                    if not r then done(false, sendError); return end
                    s.busy = true; s.status = "working"; dirty = true; done(true); publish()
                end)
            end)
        end
        if s.session ~= "" then submit(); return end
        local body = { location = { directory = cwd }, model = { id = model.id, providerID = model.provider },
            title = text:sub(1, 70), permissions = { { action = "*", resource = "*", effect = "ask" } } }
        if s.agent ~= "" then body.agent = s.agent end
        request("POST", "/api/session", body, function(r, err)
            if not r then done(false, err); return end
            s.session = r.data.id; s.title = r.data.title or "Chat"; submit(); A.list(s.historyQuery or "")
        end)
    end
    function A.chooseAgent(agent)
        local id, version = s.session, generation
        request("POST", sessionPath("/agent"), { agent = agent }, function(_, err)
            if id ~= s.session or version ~= generation then return end
            if err then fail(err) else s.agent = agent; publish() end
        end)
    end
    function A.stop()
        if s.session == "" then return end
        request("POST", sessionPath("/interrupt"), nil, function(_, err)
            if err then s.stopping = false; fail(err) else dirty = true end
        end)
    end
    function A.rename(title)
        local id, version = s.session, generation
        request("PATCH", sessionPath(), { title = title }, function(_, err)
            if id ~= s.session or version ~= generation then if not err then A.list(s.historyQuery or "") end; return end
            if err then fail(err) else s.title = title; A.list(s.historyQuery or ""); publish() end
        end)
    end
    function A.delete(done)
        if s.busy then fail("Stop the active turn before deleting"); return end
        local id, version = s.session, generation
        request("DELETE", sessionPath(), nil, function(_, err)
            if err then if id == s.session and version == generation then fail(err) end; return end
            if done then done() end
            if id == s.session and version == generation then A.new() end
            A.list(s.historyQuery or "")
        end)
    end
    function A.reply(req, value, done)
        local id, version = s.session, generation
        local tail = req.kind == "permission" and ("/permission/" .. C.encode(req.id) .. "/reply") or ("/form/" .. C.encode(req.id) .. "/reply")
        local body = req.kind == "permission" and { decision = value } or { answer = value }
        request("POST", sessionPath(tail), body, function(_, err)
            if id == s.session and version == generation then
                if err then fail(err) else dirty = true end
            end
            if done then done(err == nil) end
        end)
    end
    function A.tick()
        if s.connected and agentRetryAt > 0 and os.time() >= agentRetryAt then agentRetryAt = os.time() + 5; A.loadAgents() end
        if connection.expired() then
            local token = connection.token(); connection.failure(token, true)
            -- Invalidate callbacks from the expired attempt before another tick.
            generation = generation + 1; s.connected = false; s.status = "disconnected"
            fail("Connection timed out. Retry reconnects without resending messages.")
        end
        if connection.due() then A.connect(false) end
        if s.connected and not s.recovering and not refreshing and (dirty or s.busy) and noctalia.nowMs() >= nextRefresh then
            dirty = false; nextRefresh = noctalia.nowMs() + 750; A.refresh()
        end
    end
    function A.close() connection.close(); if stream then stream.stop() end end
    return A
end
return M
