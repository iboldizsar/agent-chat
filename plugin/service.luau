local C = require("./lib/common.luau")
local Models = require("./lib/models.luau")
local OpenCode = require("./lib/opencode.luau")
local Codex = require("./lib/codex.luau")
local Conversations = require("./lib/conversations.luau")
local Attachments = require("./lib/attachments.luau")
local cwd = noctalia.expandPath(noctalia.getConfig("assistant_dir"))
local dataDir = noctalia.pluginDataDir()
noctalia.runAsync({ "chmod", "700", dataDir })
local prefsPath = dataDir .. "/preferences.json"
local preferenceStore = require("./lib/preferences.luau").open(noctalia, prefsPath)
local prefs = preferenceStore.value
local backend = prefs.backend == "codex" and "codex" or "opencode"
local adapters = {}
local dirty = true
local savingAt = 0
local sending = false
local sendingBackend = nil
local jobs = require("./lib/jobs.luau").new()
local navigation = 0
local replies = {}
local activity = require("./lib/activity.luau").new()
local handle
local notifyState = require("./lib/notifications.luau").new(function(name, session)
    handle({ action = "backend", value = name })
    if adapters[name].state.session ~= session then handle({ action = "open", value = session }) end
    noctalia.runAsync({ "noctalia", "msg", "panel-open", "local/agent-chat:panel" })
end)
local connected = {}
local visible = false
local wasBusy = {}
local function changed() dirty = true end
local setup = require("./lib/setup.luau").new(noctalia, changed)
-- Unreadable/future preferences are handled by recovery, never by onboarding.
local showSetup = prefs.setupCompleted == false and preferenceStore.writable
local setupDismissed = false
local setupChosen = false
adapters.opencode = OpenCode.new(cwd, changed)
adapters.codex = Codex.new(cwd, changed)
local function key(s) return s.backend .. ":" .. (s.session ~= "" and s.session or "new") end
for name, a in pairs(adapters) do
    local saved = prefs.selections[name] or {}
    a.state.model = saved.model or ""
    a.state.session = saved.session or ""
    a.state.effort = saved.effort
    a.state.agent = saved.agent or ""
    a.state.draft = prefs.drafts[key(a.state)] or ""
end
local function current() return adapters[backend], adapters[backend].state end
local function publish()
    local _, s = current()
    local background = {}
    for name, a in pairs(adapters) do
        local x = a.state
        x.activity = activity(name, x, sending and name == sendingBackend)
        prefs.pins[name] = prefs.pins[name] or {}
        for _, session in ipairs(x.sessions) do
            local pin = prefs.pins[name][session.id]
            if pin then pin.title = session.title; pin.updated = session.updated end
        end
        if prefs.pins[name][x.session] then prefs.pins[name][x.session].title = x.title end
        notifyState(name, x, not (visible and name == backend))
        if wasBusy[name] and not x.busy and x.connected and not x.recovering and (x.error or "") == "" and not (visible and name == backend) then x.unread = true end
        if (visible and name == backend) or x.busy or #x.requests > 0 then x.unread = false end
        wasBusy[name] = x.busy
        background[name] = connected[name] and (not x.connected and ((x.connection and x.connection.phase) or "disconnected") or (x.unread and "finished" or x.status)) or "idle"
    end
    noctalia.state.set("chat_snapshot", { current = s, backend = backend,
        background = background, sending = sending, assistantDir = cwd, pins = prefs.pins[backend] or {},
        setup = { active = showSetup, completed = prefs.setupCompleted == true, runtime = setup.state },
        interactiveJob = jobs.pending(), modelChoices = (prefs.modelChoices or {})[backend],
        preferences = { warning = preferenceStore.warning, canReset = preferenceStore.canReset } })
    prefs.backend = backend
    for name, a in pairs(adapters) do
        local x = a.state
        prefs.selections[name] = { model = x.model, session = x.session, effort = x.effort, agent = x.agent }
        prefs.drafts[key(x)] = x.draft
    end
    for replyKey, reply in pairs(replies) do
        local state = adapters[reply.backend].state
        local found = false
        if state.session == reply.session then
            for _, request in ipairs(state.requests) do if tostring(request.id) == reply.id then found = true end end
        end
        if not found then replies[replyKey] = nil end
    end
    local priorWarning = preferenceStore.warning
    preferenceStore.save()
    if priorWarning ~= preferenceStore.warning then dirty = true end
end
local function connect(name)
    if not noctalia.fileExists(cwd .. "/AGENTS.md") then
        adapters[name].state.error = "Assistant context is not installed. Run the documented setup, then Retry."
        changed(); return
    end
    connected[name] = true; adapters[name].connect()
end
handle = function(req)
    if type(req) ~= "table" then return end
    local a, s = current()
    local action = req.action
    if action == "setup_open" then
        showSetup = true; setup.check()
    elseif action == "setup_check" then
        setup.check()
    elseif action == "setup_cancel" then
        showSetup = false; setupDismissed = true
    elseif action == "setup_connect" then
        local info = setup.state.backends[req.value]
        if not info or info.status ~= "available" or sending then return end
        local target = adapters[req.value].state
        if target.busy or target.recovering or #target.requests > 0 then return end
        if req.value ~= backend then navigation = navigation + 1 end
        setupChosen = true; backend = req.value; connect(backend)
    elseif action == "setup_complete" then
        local model = C.selected(s)
        if s.connected and not s.recovering and not s.recoveryFailed and model and C.validEffort(s) and C.authReady(s) and not s.busy and not sending and #s.requests == 0 then
            prefs.setupCompleted = true; showSetup = false
        else s.error = "Connect and choose an available model before finishing setup." end
    elseif action == "reset_preferences" then preferenceStore.reset()
    elseif action == "visible" then
        visible = req.value == true
        if visible then navigation = navigation + 1 end
    elseif action == "backend" then
        if req.value ~= "opencode" and req.value ~= "codex" then return end
        setupChosen = true
        if backend ~= req.value then navigation = navigation + 1 end
        backend = req.value
        if not connected[backend] then connect(backend) end
    elseif action == "retry" then setupChosen = true; connect(backend)
    elseif action == "draft" then s.draft = req.value or ""
    elseif action == "favorite_model" then
        local model = Models.find(s.models, req.value)
        -- A disappeared favorite remains removable without inventing a model.
        local favorite = ((prefs.modelChoices or {})[backend] or {}).favorites or {}
        if model or favorite[req.value] then Models.toggle(prefs, backend, model or { key = req.value, label = favorite[req.value].label }) end
    elseif action == "model" then
        local model = Models.find(s.models, req.value)
        if s.busy or s.recovering or #s.requests > 0 or sending then
            s.error = "Wait for this turn before changing model."
        elseif not model then s.error = "Selected model is unavailable. Choose an available model."
        else
            s.model = model.key; s.effort = nil; s.error = ""
            Models.remember(prefs, backend, model)
        end
    elseif action == "effort" then
        local model = C.selected(s)
        if not s.busy and not s.recovering and not sending and #s.requests == 0 and model then
            for _, effort in ipairs(model.efforts or {}) do
                if effort.reasoningEffort == req.value then s.effort = req.value; break end
            end
        end
    elseif action == "agent" then
        if s.busy then s.error = "Wait for this turn before changing agent."
        elseif s.session == "" then s.agent = req.value
        elseif a.chooseAgent then a.chooseAgent(req.value) end
    elseif action == "new" or action == "open" then
        if s.busy or s.recovering or #s.requests > 0 or sending then s.error = "Stop or finish this conversation before opening another on this backend."; changed(); return end
        navigation = navigation + 1
        prefs.drafts[key(s)] = s.draft
        if action == "new" then a.new() else a.open(req.value) end
        s.draft = action == "new" and (prefs.drafts[s.backend .. ":new"] or "") or (prefs.drafts[s.backend .. ":" .. req.value] or "")
        s.attachments = {}
    elseif action == "pin" then
        local id = req.value
        if type(id) ~= "string" or id == "" then return end
        prefs.pins[backend] = prefs.pins[backend] or {}
        local pins = prefs.pins[backend]
        if pins[id] then pins[id] = nil
        else
            local title = id == s.session and s.title or nil
            for _, session in ipairs(s.sessions) do if session.id == id then title = session.title end end
            if title then pins[id] = { title = title } end
        end
    elseif action == "export" then
        if s.session == "" or s.busy or sending or s.exporting then return end
        local job = jobs.begin("export", { backend = backend, session = s.session, navigation = navigation })
        if not job then s.error = "Finish the open desktop dialog before starting another operation."; changed(); return end
        local title, name = s.title, backend
        local returnPanel = req.returnPanel
        if returnPanel ~= "local/agent-chat:panel" and returnPanel ~= "local/agent-chat:fullscreen" then returnPanel = nil end
        local function restorePanel()
            if returnPanel and jobs.current(job, backend, current().state.session, navigation) then
                noctalia.runAsync({ "noctalia", "msg", "panel-open", returnPanel })
            end
        end
        s.exporting = true; s.exportPath = nil; s.error = ""
        a.export(function(messages, err)
            if not messages then jobs.finish(job); s.exporting = false; s.error = "Export failed: " .. tostring(err); changed(); restorePanel(); return end
            if not jobs.current(job, backend, current().state.session, navigation) then
                jobs.finish(job); s.exporting = false; changed(); return
            end
            local dir = dataDir .. "/exports"
            local made = noctalia.mkdirAll(dir)
            local slug = title:gsub("[^%w_-]+", "-"):sub(1, 60)
            if slug == "" then slug = "chat" end
            local path = dir .. "/" .. name .. "-" .. slug .. "-" .. tostring(noctalia.nowMs()) .. ".md"
            local base, suffix = path:sub(1, -4), 1
            while noctalia.fileExists(path) do path = base .. "-" .. tostring(suffix) .. ".md"; suffix = suffix + 1 end
            if not made or not noctalia.writeFile(path, Conversations.markdown(title, name, messages)) then
                jobs.finish(job); s.exporting = false; s.error = "Could not prepare Markdown export"; changed(); restorePanel(); return
            end
            noctalia.runAsync({ "chmod", "600", path })
            local suggested = (prefs.exportDir or noctalia.expandPath("~/")):gsub("/$", "") .. "/" .. slug .. ".md"
            local launched = Attachments.saveExport(path, suggested, function(result)
                if not jobs.finish(job) then return end
                local saved = C.decode(result.stdout)
                s.exporting = false
                if not saved then s.error = "Could not save Markdown export"
                elseif saved.error then s.error = saved.error
                elseif not saved.cancelled then
                    s.exportPath = saved.path; s.exportTitle = title
                    prefs.exportDir = saved.path:match("^(.*)/[^/]+$")
                end
                -- The private staging copy is no longer needed after Save As.
                noctalia.removeFile(path)
                changed(); restorePanel()
            end)
            if not launched then
                jobs.finish(job); s.exporting = false; s.error = "Could not open the Save As dialog"
                noctalia.removeFile(path); changed(); restorePanel()
            end
            changed()
        end)
    elseif action == "dismiss_export" then s.exportPath = nil; s.exportTitle = nil
    elseif action == "history" then a.list(req.value or "", req.cursor)
    elseif action == "older" then a.refresh(s.messageCursor)
    elseif action == "stop" then s.stopping = true; a.stop()
    elseif action == "rename" and s.session ~= "" then a.rename(req.value)
    elseif action == "delete" and s.session ~= "" then
        local name, id = backend, s.session
        a.delete(function() if prefs.pins[name] then prefs.pins[name][id] = nil end end)
    elseif action == "reply" then
        if s.recovering or not s.connected then s.error = "Wait for pending requests to be recovered before replying."; changed(); return end
        for _, r in ipairs(s.requests) do
            if tostring(r.id) == tostring(req.id) then
                local replyKey = backend .. ":" .. s.session .. ":" .. tostring(r.id)
                if replies[replyKey] then return end
                local record = { backend = backend, session = s.session, id = tostring(r.id) }
                replies[replyKey] = record
                a.reply(r, req.value, function(ok)
                    if not ok and replies[replyKey] == record then replies[replyKey] = nil end
                    changed()
                end)
                break
            end
        end
    elseif action == "remove_attachment" then table.remove(s.attachments, tonumber(req.value))
    elseif action == "attach" then
        local job = jobs.begin("attachment", { backend = backend, session = s.session, navigation = navigation })
        if not job then s.error = "Finish the open desktop dialog before starting another operation."; changed(); return end
        local returnPanel = (req.value == "pick" or req.value == "screenshot") and req.returnPanel or nil
        if returnPanel ~= "local/agent-chat:panel" and returnPanel ~= "local/agent-chat:fullscreen" then returnPanel = nil end
        local name = backend
        local function restorePanel()
            if returnPanel and jobs.current(job, backend, current().state.session, navigation) then
                noctalia.runAsync({ "noctalia", "msg", "panel-open", returnPanel })
            end
        end
        local launched = Attachments.capture(req.value, dataDir .. "/attachments", function(result)
            if not jobs.finish(job) then return end
            if not jobs.matches(job, backend, current().state.session) then changed(); return end
            local f = C.decode(result.stdout)
            local x = adapters[name].state
            if not f then x.error = result.timedOut and "Attachment picker timed out; try again." or "Could not capture attachment"
            elseif f.error then x.error = f.error
            elseif not f.cancelled then
                if jobs.matches(job, backend, current().state.session) then table.insert(x.attachments, f) end
            end
            changed()
            restorePanel()
        end)
        if not launched then
            jobs.finish(job)
            s.error = "Could not launch the attachment helper"
            changed(); restorePanel()
        end
    elseif action == "send" then
        if type(req.value) == "string" then s.draft = req.value end
        if s.limitPaused then s.error = "Paused after a usage/rate limit. Retry reconnects without resending."; changed(); return end
        if s.recovering then s.error = "Wait for conversation recovery before sending; Retry reconnects without resending."; changed(); return end
        if sending or s.busy or s.draft:match("^%s*$") then return end
        if not s.connected then s.error = "Connect the selected backend first"; changed(); return end
        if not C.authReady(s) then s.error = "Codex sign-in is required or still being checked. Use codex login, then reconnect."; changed(); return end
        local model = C.selected(s)
        if not model then s.error = "Choose an available model"; changed(); return end
        if not C.validEffort(s) then s.error = "Saved reasoning effort is unavailable. Choose a supported effort in Chat options."; changed(); return end
        local hasImage = false
        for _, m in ipairs(model.modalities or {}) do if m == "image" then hasImage = true end end
        for _, f in ipairs(s.attachments) do
            if f.image and not hasImage then s.error = "This model does not accept images"; changed(); return end
        end
        local sourceDraftKey = key(s)
        local text, files = s.draft, s.attachments
        local wireFiles = {}
        for _, f in ipairs(files) do
            if backend == "opencode" then table.insert(wireFiles, { uri = f.uri, name = f.name })
            else table.insert(wireFiles, f) end
        end
        sending = true; sendingBackend = backend; s.error = ""; changed()
        a.send(text, wireFiles, function(ok, err)
            sending = false; sendingBackend = nil
            if ok then prefs.drafts[sourceDraftKey] = ""; s.draft = ""; s.attachments = {}; s.composerRevision = (s.composerRevision or 0) + 1
            else s.error = tostring(err or "Request failed") .. " — draft retained; check history before retrying." end
            changed()
        end)
    end
    changed()
end
noctalia.state.watch("chat_command", handle)
noctalia.setUpdateInterval(100)
function update()
    setup.tick()
    Attachments.tick()
    for _, a in pairs(adapters) do a.tick() end
    if dirty and noctalia.nowMs() >= savingAt then
        dirty = false; savingAt = noctalia.nowMs() + 100; publish()
    end
end
function onExit(_, reason)
    setup.close()
    publish()
    for _, a in pairs(adapters) do a.close(reason) end
    -- Codex transport remains alive independently; no backend process is terminated here.
end
if showSetup then
    setup.check(function(result)
        if setupDismissed or setupChosen then return end
        local only, count = nil, 0
        for _, name in ipairs({ "opencode", "codex" }) do
            if result.backends[name].status == "available" then only = name; count = count + 1 end
        end
        -- Preselect only on a fresh installation; connection is an explicit action.
        if count == 1 then backend = only end
    end)
else
    for name, a in pairs(adapters) do
        if name == backend or a.state.session ~= "" then connect(name) end
    end
end
publish()

-- Explicit diagnostic IPC reports only metadata, never drafts, text, paths to files, or secrets.
function onIpc(event, payload)
    if event == "action" then handle(C.decode(payload)); return end
    if event ~= "diagnose" then return end
    local manifest = noctalia.readFile(noctalia.pluginDir() .. "/plugin.toml") or ""
    local result = { pluginVersion = manifest:match('version%s*=%s*"([^"]+)"') or "unknown", backend = backend, assistantReady = noctalia.fileExists(cwd .. "/AGENTS.md"),
        preferenceSchema = prefs.schema_version, preferencesWritable = preferenceStore.writable, interactiveJob = jobs.pending(),
        setupCompleted = prefs.setupCompleted == true, setupActive = showSetup, setupChecking = setup.state.checking,
        runtimeBackends = setup.state.backends, optionalTools = setup.state.tools, setupCheckFailed = setup.state.error ~= nil }
    for name, a in pairs(adapters) do
        local s = a.state
        result[name] = { connected = s.connected, status = s.status, models = #s.models,
            agents = #s.agents, messages = #s.messages, requests = #s.requests,
            connectionPhase = s.connection and s.connection.phase, retryAttempt = s.connection and s.connection.attempt,
            activity = s.activity, authentication = s.authentication, recovering = s.recovering == true, recoveryFailed = s.recoveryFailed == true, hasError = (s.error or "") ~= "" }
    end
    noctalia.writeFile(dataDir .. "/diagnostic.json", C.json(result))
end
