local C = require("./common.luau")
local Conversations = require("./conversations.luau")
local Connection = require("./connection.luau")
local M = {}
function M.new(cwd, changed)
    local s = C.state("codex")
    local A = { state = s }
    local connection = Connection.new(noctalia.nowMs)
    s.connection = connection.state
    local historyGeneration = 0
    local endpoint, stream = nil, nil
    local pendingAttach, attachAt = nil, 0
    local cursor, gen = 0, 0
    local messageIndex = {}
    local helperDir = noctalia.expandPath("~/.local/state/agent-chat/codex")
    local function publish() changed() end
    local function fail(err) s.error = tostring(err); publish() end
    local function http(path, body, cb, deliverStale)
        if not endpoint then cb(nil, "Codex helper is not connected"); return end
        local token = connection.token()
        C.http({ url = endpoint.url .. path, method = body and "POST" or "GET",
            headers = { "Content-Type: application/json", "Authorization: Bearer " .. endpoint.token },
            body = body and C.json(body) or "" }, function(r, err)
                if connection.valid(token) then cb(r, err)
                elseif deliverStale then cb(nil, "Connection changed; the request was not repeated. Check recovered history before retrying.") end
            end)
    end
    local function rpc(method, params, cb, deliverStale)
        http("/rpc", { method = method, params = params }, function(r, err)
            cb(r and r.result or nil, err)
        end, deliverStale or method == "turn/start" or method == "thread/start" or method == "turn/interrupt" or method == "thread/delete" or method == "thread/name/set")
    end
    local function project(item, full)
        item = item.item or item
        if not item.id or not item.type then return end
        local role, text, detail = "Tool", "", ""
        if item.type == "agentMessage" then role = "Assistant"; text = item.text or ""
        elseif item.type == "userMessage" then
            role = "You"
            for _, x in ipairs(item.content or {}) do
                if x.type == "text" then text = text .. x.text
                elseif x.type == "localImage" then text = text .. "\n[Image]" end
            end
        elseif item.type == "reasoning" then return
        else
            text = item.type .. " · " .. (item.status or "")
            detail = C.text(item):sub(1, 16000)
        end
        local value = C.message(item.id, role, text, detail)
        if full then value.text = text end
        return value
    end
    local function upsert(item)
        local value = project(item)
        if not value then return end
        local row = messageIndex[value.id]
        if row then row.text = value.text; row.details = value.details
        else messageIndex[value.id] = value; table.insert(s.messages, value) end
    end
    local function pending(values)
        local out = {}
        for _, r in ipairs(values or {}) do
            local p = r.params or {}
            if p.threadId == s.session then
                local kind = "unsupported"
                if r.method == "item/commandExecution/requestApproval" or r.method == "item/fileChange/requestApproval" then kind = "permission"
                elseif r.method == "item/tool/requestUserInput" then kind = "questions"
                elseif r.method == "item/permissions/requestApproval" then kind = "additional_permissions"
                elseif r.method == "mcpServer/elicitation/request" then kind = "elicitation" end
                table.insert(out, { id = r.id, kind = kind, title = p.reason or p.message or r.method,
                    text = C.text(p):sub(1, 16000), questions = p.questions, method = r.method,
                    permissions = p.permissions, mode = p.mode, schema = p.requestedSchema, url = p.url })
            end
        end
        s.requests = out
        if #out > 0 then s.status = "waiting" elseif s.busy then s.status = "working" else s.status = "idle" end
    end
    local pendingGeneration = 0
    local pendingWaiters = {}
    local function syncPending(done)
        pendingGeneration = pendingGeneration + 1
        local pendingToken, currentGen = pendingGeneration, gen
        local retained = {}
        for _, waiter in ipairs(pendingWaiters) do if waiter.gen == gen then table.insert(retained, waiter) end end
        pendingWaiters = retained
        if done then table.insert(pendingWaiters, { gen = gen, done = done }) end
        local function complete(ok)
            local waiters = pendingWaiters; pendingWaiters = {}
            for _, waiter in ipairs(waiters) do if waiter.gen == gen then waiter.done(ok) end end
        end
        http("/pending", nil, function(r, err)
            if pendingToken ~= pendingGeneration or currentGen ~= gen then return end
            if not r then fail(err); complete(false); return end
            s.usage = r.usage or s.usage; pending(r.pending); publish(); complete(true)
        end)
    end
    local function event(e)
        if e.seq then cursor = e.seq end
        local p, method = e.params or {}, e.method
        if method == "bridge/usage" then s.usage = p; publish(); return end
        if method == "bridge/disconnected" then
            connection.failure(connection.token(), true)
            s.connected = false; s.busy = false; s.status = "disconnected"
            s.error = "Codex stopped. Retry reconnects; your last prompt will not be resent."
            publish(); return
        end
        if method == "bridge/resync" then if s.session ~= "" then A.open(s.session) end; return end
        if method == "serverRequest/resolved" then syncPending(); return end
        if p.threadId ~= s.session then return end
        if e.id ~= nil then syncPending() end
        if method == "turn/started" then s.turn = p.turn.id; s.busy = true; s.status = "working"
        elseif method == "turn/completed" then
            s.turn = nil; s.busy = false; s.status = "idle"
            if p.turn.error then s.error = C.text(p.turn.error):sub(1, 500) end
            syncPending()
        elseif method == "item/started" or method == "item/completed" then upsert(p.item)
        elseif method == "item/agentMessage/delta" then
            local row = messageIndex[p.itemId]
            if not row then upsert({ id = p.itemId, type = "agentMessage", text = "" }); row = messageIndex[p.itemId] end
            row.text = (row.text .. p.delta):sub(1, 200000)
        elseif method == "error" then s.error = C.text(p.error):sub(1, 500) end
        publish()
    end
    local function listen(token)
        if stream then stream.stop() end
        stream = noctalia.httpStream({ url = endpoint.url .. "/events?after=" .. cursor,
            headers = { "Authorization: Bearer " .. endpoint.token } }, function(line)
            if connection.valid(token) and line:sub(1, 5) == "data:" then local e = C.decode(line:sub(6)); if e then event(e) end end
        end, function()
            if not connection.valid(token) then return end
            connection.failure(token, true)
            stream = nil; s.connected = false; s.status = "disconnected"; publish()
        end)
    end
    function A.connect(manual)
        local token = connection.begin(manual ~= false)
        if not token then return end
        pendingAttach = nil
        gen = gen + 1; s.connected = false; s.recoveryFailed = false; s.status = "connecting"
        if stream then stream.stop(); stream = nil end
        publish()
        local function attach()
            if not connection.valid(token) then pendingAttach = nil; return end
            local raw = noctalia.readFile(helperDir .. "/endpoint.json")
            endpoint = raw and C.decode(raw)
            if not endpoint or endpoint.cwd ~= cwd or not (endpoint.url or ""):match("^http://127%.0%.0%.1:%d+$") then
                pendingAttach = attach; attachAt = noctalia.nowMs() + 200; return
            end
            pendingAttach = nil
            http("/health", nil, function(r)
                if not r then connection.failure(token, true); s.status = "disconnected"; fail("Codex helper did not respond. Retry reconnects without resending messages."); return end
                connection.success(token)
                s.connected = true; s.status = "idle"; s.error = ""; listen(token); A.discover()
                if s.session ~= "" then A.open(s.session) end
                publish()
            end)
        end
        local launched = noctalia.runAsync({ "python3", noctalia.pluginDir() .. "/helper/codex_bridge.py", "ensure",
            "--state-dir", helperDir, "--cwd", cwd }, function(result)
                if not connection.valid(token) then return end
                if result.timedOut or (result.exitCode and result.exitCode ~= 0) then
                    connection.failure(token, true); s.status = "disconnected"
                    fail("Could not start the Codex helper. Check that Python and Codex are available to Noctalia.")
                else attach() end
            end)
        if not launched then
            connection.failure(token, true); s.status = "disconnected"; fail("Could not launch the Codex helper.")
        end
    end
    function A.discover()
        s.authentication = "checking"
        rpc("account/read", {}, function(r)
            s.authentication = r and (r.signedIn and "ready" or "required") or "unknown"
            publish()
        end)
        rpc("model/list", { includeHidden = false, limit = 100 }, function(r, err)
            if not r then fail(err); return end
            s.models = {}
            local default = nil
            for _, m in ipairs(r.data or {}) do
                table.insert(s.models, { key = m.model, id = m.model, label = m.displayName,
                    modalities = m.inputModalities, efforts = m.supportedReasoningEfforts, defaultEffort = m.defaultReasoningEffort })
                if m.isDefault then default = m.model end
            end
            C.ensureModel(s, s.model, default); publish()
        end)
        rpc("account/rateLimits/read", {}, function(r) if r then s.usage = r; publish() end end)
        A.list(s.historyQuery or "")
    end
    function A.list(search, page)
        if not page then historyGeneration = historyGeneration + 1 end
        if s.historyLoading and page then return end
        s.historyLoading = true; s.historyError = nil; s.historyPendingCursor = page
        if not page then
            s.historyQuery = search or ""; s.sessions = {}; s.historyCursor = nil
            s.historyCursors = {}
        end
        publish()
        local currentHistory = historyGeneration
        local params = { limit = 40, searchTerm = search or "" }
        if page then params.cursor = page end
        rpc("thread/list", params, function(r, err)
            if currentHistory ~= historyGeneration then return end
            s.historyLoading = false; s.historyPendingCursor = nil
            if not r then s.historyError = "Could not load history. Try again when connected."; publish(); return end
            if not page then s.sessions = {} end
            local seen = {}
            for _, session in ipairs(s.sessions) do seen[session.id] = true end
            for _, t in ipairs(r.data or {}) do
                if not seen[t.id] then
                    table.insert(s.sessions, { id = t.id, title = t.name or t.preview or "Untitled", updated = Conversations.seconds(t.updatedAt) })
                    seen[t.id] = true
                end
            end
            local nextCursor = r.nextCursor
            if page then s.historyCursors[page] = true end
            if nextCursor and s.historyCursors[nextCursor] then
                s.historyCursor = nil; s.historyError = "History returned a repeated page. Refresh to try again."
            else s.historyCursor = nextCursor end
            publish()
        end, true)
    end
    function A.export(done)
        local id = s.session
        Conversations.collect(function(cursor, callback)
            local params = { threadId = id, sortDirection = "desc", limit = 50 }
            if cursor then params.cursor = cursor end
            rpc("thread/items/list", params, function(r, err)
                if not r then callback(nil, nil, err); return end
                local rows = {}
                for _, item in ipairs(r.data or {}) do
                    local row = project(item, true)
                    if row then table.insert(rows, row) end
                end
                callback(rows, r.nextCursor)
            end, true)
        end, done)
    end
    function A.refresh(page, done)
        if s.session == "" then return end
        local id, currentGen = s.session, gen
        local params = { threadId = id, sortDirection = "desc", limit = 50 }
        if page then params.cursor = page end
        rpc("thread/items/list", params, function(r, err)
            if currentGen ~= gen then return end
            if not r then fail(err); if done then done(false) end; return end
            local old = page and s.messages or {}
            s.messages = {}; messageIndex = {}
            for i = #(r.data or {}), 1, -1 do upsert(r.data[i]) end
            for _, m in ipairs(old) do if not messageIndex[m.id] then messageIndex[m.id] = m; table.insert(s.messages, m) end end
            s.messageCursor = r.nextCursor; publish(); if done then done(true) end
        end)
    end
    function A.open(id)
        gen = gen + 1
        s.recovering = true; s.recoveryFailed = false
        s.turn = nil; s.busy = false
        local currentGen = gen
        rpc("thread/resume", { threadId = id }, function(r, err)
            if currentGen ~= gen then return end
            if not r then s.recoveryFailed = true; fail(err); return end
            s.session = id; s.model = r.model; s.effort = r.reasoningEffort
            s.title = r.thread.name or r.thread.preview or "Chat"
            s.messages = {}; messageIndex = {}; s.error = ""
            for _, turn in ipairs(r.thread.turns or {}) do
                for _, item in ipairs(turn.items or {}) do upsert(item) end
                if turn.status == "inProgress" then s.turn = turn.id; s.busy = true end
            end
            local status = r.thread.status or {}
            s.busy = status.type == "active" or s.turn ~= nil
            s.status = s.busy and "working" or "idle"
            local remaining, healthy = 2, true
            local function loaded(ok)
                if currentGen ~= gen then return end
                healthy = healthy and ok; remaining = remaining - 1
                if remaining == 0 then s.recovering = not healthy; s.recoveryFailed = not healthy; publish() end
            end
            A.refresh(nil, loaded); syncPending(loaded); publish()
        end)
    end
    function A.new()
        gen = gen + 1
        s.recovering = false; s.recoveryFailed = false
        s.session = ""; s.turn = nil; s.busy = false; s.messages = {}; messageIndex = {}; s.requests = {}
        s.title = "New chat"; s.error = ""; s.status = s.connected and "idle" or "disconnected"; publish()
    end
    function A.send(text, files, done)
        local model = C.selected(s)
        if not model then done(false, "Choose an available model"); return end
        if s.busy then done(false, "Wait for this turn or press Stop"); return end
        if s.usage.blocked then done(false, "Paused near Codex usage limit"); return end
        local input = { { type = "text", text = text } }
        for _, file in ipairs(files or {}) do
            if file.image then table.insert(input, { type = "localImage", path = file.path })
            else table.insert(input, { type = "mention", name = file.name, path = file.path }) end
        end
        local function submit()
            local params = { threadId = s.session, input = input, model = model.id }
            if s.effort and s.effort ~= "" then params.effort = s.effort end
            rpc("turn/start", params, function(r, err)
                if not r then done(false, err); return end
                s.turn = r.turn.id; s.busy = r.turn.status == "inProgress"; s.status = s.busy and "working" or "idle"
                done(true); publish()
            end)
        end
        if s.session ~= "" then submit(); return end
        rpc("thread/start", { model = model.id }, function(r, err)
            if not r then done(false, err); return end
            s.session = r.thread.id; s.title = text:sub(1, 70)
            rpc("thread/name/set", { threadId = s.session, name = s.title }, function() A.list(s.historyQuery or "") end)
            submit()
        end)
    end
    function A.stop()
        if not s.turn then s.stopping = false; fail("No active turn ID. Retry to recover state before stopping."); return end
        rpc("turn/interrupt", { threadId = s.session, turnId = s.turn }, function(_, err) if err then s.stopping = false; fail(err) end end)
    end
    function A.rename(title)
        local id, version = s.session, gen
        rpc("thread/name/set", { threadId = id, name = title }, function(_, err)
            if id ~= s.session or version ~= gen then if not err then A.list(s.historyQuery or "") end; return end
            if err then fail(err) else s.title = title; A.list(s.historyQuery or ""); publish() end
        end)
    end
    function A.delete(done)
        if s.busy then fail("Stop the active turn before deleting"); return end
        local id, version = s.session, gen
        rpc("thread/delete", { threadId = id }, function(_, err)
            if err then if id == s.session and version == gen then fail(err) end; return end
            if done then done() end
            if id == s.session and version == gen then A.new() end
            A.list(s.historyQuery or "")
        end)
    end
    function A.reply(req, value, done)
        local id, version = s.session, gen
        local result
        if req.kind == "permission" then result = { decision = value }
        elseif req.kind == "additional_permissions" or req.kind == "elicitation" then result = value
        else result = { answers = value } end
        http("/reply", { id = req.id, result = result }, function(_, err)
            if id == s.session and version == gen then
                if err then fail(err) else syncPending() end
            end
            if done then done(err == nil) end
        end, true)
    end
    function A.tick()
        if pendingAttach and noctalia.nowMs() >= attachAt then pendingAttach() end
        if connection.expired() then
            local token = connection.token(); connection.failure(token, true)
            pendingAttach = nil
            gen = gen + 1; s.connected = false; s.status = "disconnected"
            fail("Connection timed out. Retry reconnects without resending messages.")
        end
        if connection.due() then A.connect(false) end
    end
    function A.close(reason)
        pendingAttach = nil
        connection.close()
        if stream then stream.stop() end
        if reason == "disable" or reason == "uninstall" then
            noctalia.runAsync({ "python3", noctalia.pluginDir() .. "/helper/codex_bridge.py", "stop",
                "--state-dir", helperDir, "--cwd", cwd })
        end
    end
    return A
end
return M
