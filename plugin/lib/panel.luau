local M = {}
function M.mount(fullscreen)
local C = require("./common.luau")
local Conversations = require("./conversations.luau")
local Models = require("./models.luau")
local snapshot = noctalia.state.get("chat_snapshot")
local view, search, modelFilter = "chat", "", ""
local historyOpen = false
local isOpen = false
local expanded, answers = {}, {}
local armedDelete = false
local armedRecovery = false
local renameText = ""
local render
local function command(action, value, extra)
    local r = { action = action, value = value, nonce = noctalia.nowMs() }
    for k, v in pairs(extra or {}) do r[k] = v end
    noctalia.state.set("chat_command", r)
end
local function alphaSetting(key)
    return math.max(0, math.min(100, tonumber(noctalia.getConfig(key)) or 100)) / 100
end
local function cardFill(role, alpha)
    return role .. "/" .. tostring((alpha or 1) * alphaSetting("card_opacity"))
end
local function button(text, cb, extra)
    local p = { text = text, onClick = cb, controlSize = "sm", variant = "ghost", fontSize = 13 }
    for k, v in pairs(extra or {}) do p[k] = v end
    return ui.button(p)
end
local function label(text, extra)
    local p = { text = text, color = "on_surface", fontSize = 14 }
    for k, v in pairs(extra or {}) do p[k] = v end
    return ui.label(p)
end
local function form(req)
    local nodes = { label(req.title, { fontWeight = "bold" }) }
    local values = answers[tostring(req.id)] or {}
    answers[tostring(req.id)] = values
    if req.kind == "permission" then
        table.insert(nodes, label(req.text or "", { maxLines = 12 }))
        local choices = snapshot.backend == "codex" and
            { { "Allow once", "accept" }, { "Allow for session", "acceptForSession" }, { "Deny", "decline" }, { "Cancel turn", "cancel" } } or
            { { "Allow once", "once" }, { "Always allow", "always" }, { "Deny", "reject" } }
        local buttons = {}
        for _, choice in ipairs(choices) do
            table.insert(buttons, button(choice[1], function() command("reply", choice[2], { id = req.id }) end))
        end
        table.insert(nodes, ui.row({ gap = 6 }, buttons))
    elseif req.kind == "additional_permissions" then
        table.insert(nodes, label(req.text or "", { maxLines = 14 }))
        table.insert(nodes, ui.row({ gap = 6 }, {
            button("Allow requested permissions for this turn", function()
                command("reply", { permissions = req.permissions, scope = "turn" }, { id = req.id })
            end),
            button("Deny", function() command("reply", { permissions = {}, scope = "turn" }, { id = req.id }) end),
        }))
    elseif req.kind == "elicitation" and req.mode == "url" then
        table.insert(nodes, label(req.url or "", { maxLines = 4 }))
        table.insert(nodes, ui.row({ gap = 6 }, {
            button("Open consent page", function()
                if (req.url or ""):match("^https?://") then noctalia.runAsync({ "xdg-open", req.url }) end
            end),
            button("I have completed it", function() command("reply", { action = "accept" }, { id = req.id }) end),
            button("Cancel", function() command("reply", { action = "cancel" }, { id = req.id }) end),
        }))
    elseif req.kind == "questions" then
        for _, q in ipairs(req.questions or {}) do
            table.insert(nodes, label(q.header or q.id, { fontWeight = "bold" }))
            table.insert(nodes, label(q.question or ""))
            for _, o in ipairs(q.options or {}) do
                table.insert(nodes, button(o.label, function()
                    values[q.id] = { answers = { o.label } }; render()
                end, { selected = values[q.id] and values[q.id].answers[1] == o.label,
                       tooltip = o.description }))
            end
            table.insert(nodes, ui.input({ key = "q-" .. tostring(req.id) .. q.id, placeholder = "Your answer",
                onChange = function(v) values[q.id] = { answers = { v } } end }))
        end
        table.insert(nodes, button("Submit answers", function() command("reply", values, { id = req.id }) end))
    elseif req.kind == "form" or (req.kind == "elicitation" and req.mode == "form") then
        local supported = true
        local fields = req.fields or {}
        if req.kind == "elicitation" then
            fields = {}
            for fieldKey, schema in pairs((req.schema or {}).properties or {}) do
                local f = { key = fieldKey, title = schema.title or fieldKey, type = schema.type,
                    description = schema.description, default = schema.default, options = {} }
                if schema.enum then
                    for _, value in ipairs(schema.enum) do table.insert(f.options, { value = value, label = tostring(value) }) end
                elseif schema.type == "array" and schema.items and schema.items.enum then
                    f.type = "multiselect"
                    for _, value in ipairs(schema.items.enum) do table.insert(f.options, { value = value, label = tostring(value) }) end
                end
                table.insert(fields, f)
            end
        end
        for _, f in ipairs(fields) do
            if values[f.key] == nil and f.default ~= nil then values[f.key] = f.default end
            if not f.hidden then
                table.insert(nodes, label(f.title or f.key))
                if f.description then table.insert(nodes, label(f.description, { color = "on_surface_variant" })) end
                if f.type == "boolean" then
                    table.insert(nodes, ui.toggle({ checked = values[f.key] == true, onChange = function(v) values[f.key] = v == "true" end }))
                elseif f.type == "string" or f.type == "number" or f.type == "integer" then
                    for _, o in ipairs(f.options or {}) do
                        table.insert(nodes, button(o.label or tostring(o.value), function() values[f.key] = o.value; render() end,
                            { selected = values[f.key] == o.value }))
                    end
                    table.insert(nodes, ui.input({ key = "form-" .. tostring(req.id) .. f.key, value = tostring(values[f.key] or f.default or ""),
                        onChange = function(v) values[f.key] = f.type == "string" and v or tonumber(v) end }))
                elseif f.type == "multiselect" then
                    for _, o in ipairs(f.options or {}) do
                        local selected = false
                        for _, v in ipairs(values[f.key] or {}) do if v == o.value then selected = true end end
                        table.insert(nodes, button(o.label or tostring(o.value), function()
                            local list, found = {}, false
                            for _, v in ipairs(values[f.key] or {}) do
                                if v == o.value then found = true else table.insert(list, v) end
                            end
                            if not found then table.insert(list, o.value) end
                            values[f.key] = list; render()
                        end, { selected = selected }))
                    end
                else supported = false; table.insert(nodes, label("This question needs a control this version cannot display. Stop the turn to cancel.")) end
            end
        end
        table.insert(nodes, button("Submit", function()
            local result = req.kind == "elicitation" and { action = "accept", content = values } or values
            command("reply", result, { id = req.id })
        end, { enabled = supported }))
        if req.kind == "elicitation" then
            table.insert(nodes, button("Decline", function() command("reply", { action = "decline" }, { id = req.id }) end))
        end
    else
        table.insert(nodes, label("Waiting for an interaction this version cannot display. Nothing has been approved. Use Stop to cancel.", { color = "error" }))
        table.insert(nodes, label(req.text or "", { maxLines = 8 }))
    end
    return ui.column({ key = "request-" .. tostring(req.id), gap = 8, padding = 12, fill = cardFill("surface_variant"), radius = 10 }, nodes)
end
local function icon(name, tooltip, cb, extra)
    local props = { glyph = name, tooltip = tooltip, width = 32, height = 32 }
    for k, v in pairs(extra or {}) do props[k] = v end
    return button("", cb, props)
end
local function section(title, children, description)
    local rows = { label(title, { fontSize = 15, fontWeight = "bold" }) }
    if description then table.insert(rows, label(description, { fontSize = 12, color = "on_surface_variant", maxLines = 3 })) end
    for _, child in ipairs(children) do table.insert(rows, child) end
    return ui.column({ gap = 10, padding = 16, radius = 12, fill = cardFill("surface_variant", 0.25) }, rows)
end
local shortcuts = {
    { "Enter", "Send message" },
    { "Shift + Enter", "Insert a newline" },
    { "Esc", "Hide chat; work continues" },
    { "Ctrl + N", "New chat" },
    { "Ctrl + H", "Toggle history" },
    { "Ctrl + M", "Choose model" },
    { "Ctrl + ,", "Chat options" },
    { "Ctrl + Shift + A", "Attach a file" },
    { "Ctrl + Shift + V", "Paste an image" },
    { "Ctrl + Shift + X", "Stop response" },
    { "Ctrl + Shift + F", "Toggle full screen" },
    { "Ctrl + Shift + /", "Keyboard shortcuts" },
}
local function toggleHistory()
    historyOpen = view ~= "chat" or not historyOpen; view = "chat"; render()
end
local function toggleModels()
    if not snapshot or snapshot.sending or snapshot.current.busy or snapshot.current.recovering then return end
    view = view == "models" and "chat" or "models"; render()
end
local function toggleBackend()
    if not snapshot or snapshot.sending then return end
    view = view == "backends" and "chat" or "backends"; render()
end
local function newChat()
    if not snapshot or snapshot.sending or snapshot.current.busy or snapshot.current.recovering then return end
    command("new"); armedDelete = false; view = "chat"; render()
end
local function toggleOptions()
    view = view == "options" and "chat" or "options"; armedDelete = false; render()
end
local function toggleFullscreen()
    panel.close(); noctalia.togglePanel(fullscreen and "local/agent-chat:panel" or "local/agent-chat:fullscreen")
end
local function toggleHelp()
    view = view == "shortcuts" and "chat" or "shortcuts"; render()
end
local function attachFile(mode)
    if snapshot and snapshot.interactiveJob then return end
    -- Release the layer-shell keyboard grab before opening an external window.
    panel.close()
    command("attach", mode or "pick", { returnPanel = fullscreen and "local/agent-chat:fullscreen" or "local/agent-chat:panel" })
end
local function key(chord, pressed)
    if pressed ~= true or not isOpen or not snapshot then return end
    chord = chord:lower()
    local s = snapshot.current
    if chord == "ctrl+n" then newChat()
    elseif chord == "ctrl+h" then toggleHistory()
    elseif chord == "ctrl+m" then toggleModels()
    elseif chord == "ctrl+comma" then toggleOptions()
    elseif chord == "ctrl+shift+a" then attachFile()
    elseif chord == "ctrl+shift+v" then command("attach", "paste")
    elseif chord == "ctrl+shift+x" then
        if s.busy or #(s.requests or {}) > 0 then command("stop") end
    elseif chord == "ctrl+shift+f" then toggleFullscreen()
    elseif chord == "ctrl+shift+slash" or chord == "ctrl+shift+question" then toggleHelp() end
end
render = function()
    if not snapshot then
        panel.render(ui.column({ padding = 24 }, { label("Opening Agent Chat…") }))
        return
    end
    local s = snapshot.current
    local model = C.selected(s)
    local idle = not s.busy and not snapshot.sending and not s.recovering and #s.requests == 0
    local backendName = s.backend == "codex" and "Codex" or "OpenCode"
    local header = ui.row({ gap = 8, align = "center" }, {
        icon(historyOpen and "layout-sidebar-left-collapse" or "layout-sidebar-left-expand", "Chat history · Ctrl+H", toggleHistory, { selected = historyOpen }),
        button(backendName, toggleBackend, { glyph = "chevron-down", tooltip = "Choose OpenCode or Codex", fontSize = 17,
            variant = "secondary", key = "backend-picker", enabled = not snapshot.sending }),
        ui.spacer({}),
        button(model and model.label or "Choose model", toggleModels, { tooltip = "Choose model · Ctrl+M", glyph = "chevron-down", variant = "secondary", enabled = idle, key = "model-picker" }),
        icon("square-plus", "New chat · Ctrl+N", newChat, { enabled = idle }),
        icon("download", s.exporting and "Exporting Markdown…" or "Export Markdown…", function()
            panel.close()
            command("export", nil, { returnPanel = fullscreen and "local/agent-chat:fullscreen" or "local/agent-chat:panel" })
        end, { enabled = idle and s.session ~= "" and not s.exporting and not snapshot.interactiveJob, key = "export-markdown" }),
        icon("adjustments-horizontal", "Chat options · Ctrl+,", toggleOptions, { selected = view == "options", key = "chat-options" }),
        icon(fullscreen and "arrows-minimize" or "arrows-maximize", (fullscreen and "Windowed" or "Full screen") .. " · Ctrl+Shift+F", toggleFullscreen),
        icon("keyboard", "Keyboard shortcuts · Ctrl+Shift+/", toggleHelp),
        icon("x", "Close · Esc", function() panel.close() end),
    })
    local nodes = { header, ui.separator({ color = "outline/0.35", thickness = 1 }) }
    if s.connection and (s.connection.phase ~= "connected" or s.recovering) then
        local phase = s.connection.phase
        local text = s.recoveryFailed and "Conversation recovery failed. Reconnect to try again; your draft is retained." or
            (s.recovering and s.connected and "Restoring conversation and pending requests…" or
            (phase == "connecting" and "Connecting…" or (phase == "reconnecting" and
                "Reconnecting · attempt " .. tostring(s.connection.attempt) .. " · messages are not resent" or
                "Offline · reconnect when the service is available")))
        table.insert(nodes, label(text, { fontSize = 12, color = "on_surface_variant", maxLines = 2 }))
    end
    if snapshot.preferences and snapshot.preferences.warning then
        table.insert(nodes, ui.column({ gap = 6, padding = 10, fill = "error/0.08", radius = 10 }, {
            label(snapshot.preferences.warning, { fontSize = 12, color = "error", maxLines = 3 }),
        }))
    end
    if s.exportPath then
        table.insert(nodes, ui.row({ gap = 8, align = "center" }, {
            icon("x", "Dismiss export confirmation", function() command("dismiss_export") end),
            label("Saved Markdown: " .. s.exportPath, { fontSize = 12, flexGrow = 1, maxLines = 2 }),
        }))
    end
    if s.error ~= "" then
        table.insert(nodes, ui.row({ gap = 10, padding = 10, radius = 10, fill = "error/0.08", align = "center" }, {
            label(s.error, { color = "error", maxLines = 4, flexGrow = 1 }),
            icon("refresh", "Reconnect without resending", function() command("retry") end),
        }))
    end
    if (s.usage or {}).blocked or s.limitPaused then
        table.insert(nodes, label("Usage limit pause · new messages are on hold", { color = "error", fontSize = 12 }))
    end
    if view == "shortcuts" then
        local rows = {
            ui.row({ gap = 8, align = "center" }, {
                icon("arrow-left", "Back to chat", function() view = "chat"; render() end),
                label("Keyboard shortcuts", { fontSize = 18, fontWeight = "bold" }),
            }),
            label("Active only while Agent Chat is focused. Text editing shortcuts stay available.", { fontSize = 12 }),
        }
        for _, binding in ipairs(shortcuts) do
            table.insert(rows, ui.row({ gap = 16 }, {
                label(binding[1], { width = 200, fontWeight = "bold" }), label(binding[2]),
            }))
        end
        table.insert(nodes, ui.scroll({ flexGrow = 1, gap = 12 }, rows))
    elseif view == "backends" then
        table.insert(nodes, ui.row({ gap = 8, align = "center" }, {
            icon("arrow-left", "Back to chat", function() view = "chat"; render() end),
            label("Choose a service", { fontWeight = "bold", flexGrow = 1 }),
        }))
        local rows = { label("Each service keeps its own conversations and model choices.", { fontSize = 12, color = "on_surface_variant" }) }
        for _, choice in ipairs({ { "opencode", "OpenCode" }, { "codex", "Codex" } }) do
            table.insert(rows, button(choice[2], function()
                if snapshot.sending then return end
                command("backend", choice[1]); view = "chat"; render()
            end, { key = "backend-" .. choice[1], selected = s.backend == choice[1], enabled = not snapshot.sending,
                glyph = s.backend == choice[1] and "check" or nil, contentAlign = "start" }))
        end
        table.insert(nodes, ui.scroll({ flexGrow = 1, gap = 8 }, rows))
    elseif view == "models" then
        table.insert(nodes, ui.row({ gap = 8, align = "center" }, {
            icon("arrow-left", "Back to chat", function() view = "chat"; render() end),
            label("Choose a model", { fontWeight = "bold", flexGrow = 1 }),
            label(backendName, { fontSize = 12, color = "on_surface_variant" }),
        }))
        table.insert(nodes, ui.input({ key = "model-search", value = modelFilter, placeholder = "Search models or providers", focus = true,
            onChange = function(v) modelFilter = v; render() end }))
        local rows = {}
        for _, group in ipairs(Models.groups(s.models, snapshot.modelChoices, modelFilter)) do
            if #group.rows > 0 then
                table.insert(rows, label(group.title, { fontSize = 12, color = "on_surface_variant" }))
                for _, m in ipairs(group.rows) do
                    table.insert(rows, ui.row({ gap = 6, align = "center" }, {
                        button(m.label .. (m.available and "" or " · Unavailable"), function() command("model", m.key); view = "chat"; render() end,
                            { key = m.key, enabled = idle and m.available, flexGrow = 1, selected = m.key == s.model,
                                contentAlign = "start", glyph = m.key == s.model and "check" or nil }),
                        button(m.favorite and "Unfavorite" or "Favorite", function() command("favorite_model", m.key) end,
                            { key = "favorite-" .. m.key, tooltip = m.favorite and "Remove favorite" or "Add favorite" }),
                    }))
                end
            end
        end
        if #rows == 0 then table.insert(rows, label("No matching models", { color = "on_surface_variant" })) end
        table.insert(nodes, ui.scroll({ flexGrow = 1, gap = 4 }, rows))
    elseif view == "options" or view == "rename" then
        local function hint(text)
            return label(text, { fontSize = 12, color = "on_surface_variant", maxLines = 3 })
        end
        local function settingRow(title, description, control)
            return ui.row({ gap = 16, align = "center" }, {
                ui.column({ gap = 3, flexGrow = 1 }, {
                    label(title, { fontSize = 13, fontWeight = "bold" }), hint(description),
                }), control,
            })
        end
        local settings = {
            ui.row({ gap = 8, align = "center" }, {
                icon("arrow-left", "Back to chat", function() view = "chat"; armedDelete = false; render() end),
                ui.column({ gap = 3 }, {
                    label("Chat options", { fontSize = 21, fontWeight = "bold" }),
                    hint("Choose your assistant and manage this conversation."),
                }),
            }),
        }
        local assistant = {
            settingRow("Model", model and model.label or "No model selected",
                button("Change", toggleModels, { glyph = "chevron-right", enabled = idle, variant = "secondary" })),
        }
        if s.backend == "codex" then
            local values, names, selected = {}, {}, 1
            local friendly = { minimal = "Minimal", low = "Low", medium = "Medium", high = "High", xhigh = "Extra high" }
            for i, option in ipairs(model and model.efforts or {}) do
                values[i] = option.reasoningEffort
                names[i] = friendly[option.reasoningEffort] or option.reasoningEffort
                if (s.effort or model.defaultEffort) == option.reasoningEffort then selected = i end
            end
            if #values > 0 then table.insert(assistant, settingRow("Reasoning effort", "Higher effort can take longer and use more allowance.",
                ui.select({ key = "reasoning-" .. s.model, options = names, selectedIndex = selected - 1, width = 160, enabled = idle,
                    onChange = function(index)
                        local value = values[(tonumber(index) or -1) + 1]
                        if value then command("effort", value) end
                    end }))) end
        elseif #s.agents > 0 then
            local values, names, selected = {}, {}, 1
            for i, agent in ipairs(s.agents) do
                values[i] = agent.id; names[i] = agent.name or agent.id
                if agent.id == s.agent then selected = i end
            end
            table.insert(assistant, settingRow("Agent", "Choose which OpenCode assistant handles your messages.",
                ui.select({ key = "agent-select", options = names, selectedIndex = selected - 1, width = 190, enabled = idle,
                    onChange = function(index)
                        local value = values[(tonumber(index) or -1) + 1]
                        if value then command("agent", value) end
                    end })))
        end
        if not idle then table.insert(assistant, hint("Model and assistant settings unlock when the current response finishes.")) end
        table.insert(settings, section("Assistant", assistant))
        if s.session ~= "" then
            local controls = {
                settingRow(s.title, "Keep this chat easy to find in history.",
                    button((snapshot.pins or {})[s.session] and "Unpin" or "Pin chat", function() command("pin", s.session) end,
                        { glyph = "pin", selected = (snapshot.pins or {})[s.session] ~= nil, variant = "secondary" })),
            }
            if view == "rename" then
                local function saveTitle()
                    local title = renameText:match("^%s*(.-)%s*$")
                    if title == "" then return end
                    command("rename", title); view = "options"; render()
                end
                table.insert(controls, ui.input({ key = "rename-" .. s.session, value = renameText, focus = true,
                    placeholder = "Conversation title", onChange = function(v) renameText = v end, onSubmit = saveTitle }))
                table.insert(controls, ui.row({ gap = 6 }, {
                    button("Save title", saveTitle, { variant = "primary", enabled = idle }),
                    button("Cancel", function() view = "options"; render() end),
                }))
            else
                table.insert(controls, button("Rename conversation", function() view = "rename"; renameText = s.title; render() end,
                    { glyph = "pencil", enabled = idle, contentAlign = "start" }))
            end
            table.insert(settings, section("Conversation", controls))
        end
        if s.backend == "codex" then
            local usage = {}
            for _, window in ipairs((s.usage or {}).windows or {}) do
                local mins = window.windowDurationMins or 0
                local name = mins == 300 and "5-hour allowance" or (mins == 10080 and "Weekly allowance" or tostring(mins) .. " minute allowance")
                local used = math.max(0, math.min(100, tonumber(window.usedPercent) or 0))
                table.insert(usage, ui.row({ gap = 8 }, {
                    label(name, { fontSize = 13, flexGrow = 1 }), label(tostring(used) .. "% used", { fontSize = 13 }),
                }))
                table.insert(usage, ui.progress({ progress = used / 100, fill = used >= 85 and "error" or "primary", track = "outline/0.15", height = 5, radius = 3 }))
            end
            if #usage == 0 then table.insert(usage, hint("This service has not reported an allowance yet.")) end
            table.insert(settings, section("Usage", usage, "Reported by Codex. New messages pause at 85% reported use."))
        end
        if snapshot.preferences and snapshot.preferences.warning then
            local recovery = { hint(snapshot.preferences.warning) }
            if snapshot.preferences.canReset then
                table.insert(recovery, button(armedRecovery and "Confirm new saved preferences" or "Start new saved preferences…", function()
                    if armedRecovery then command("reset_preferences"); armedRecovery = false
                    else armedRecovery = true; render() end
                end, { variant = armedRecovery and "destructive" or "secondary" }))
                if armedRecovery then
                    table.insert(recovery, hint("Previous saved files are kept as private recovery copies. This saves your current choices and drafts as the new preferences."))
                    table.insert(recovery, button("Cancel", function() armedRecovery = false; render() end))
                end
            end
            table.insert(settings, section("Saved preferences", recovery))
        end
        table.insert(settings, section("Connection & appearance", {
            settingRow(s.connected and (backendName .. " is connected") or (backendName .. " is disconnected"),
                s.connected and "Ready for messages." or "Reconnect to restore access to your chats.",
                button("Reconnect", function() command("retry") end, { glyph = "refresh", enabled = not snapshot.sending and not (s.connection and s.connection.startedAt),
                    tooltip = "Reconnect without resending messages", variant = "secondary" })),
            ui.separator({ color = "outline/0.2" }),
            settingRow("Plugin preferences", "Transparency, notifications, history and launch behavior.",
                button("Configure", function() noctalia.openSettings() end, { glyph = "settings", variant = "secondary" })),
        }))
        if s.session ~= "" then
            local removal = {}
            if armedDelete then
                table.insert(removal, label("Delete “" .. s.title .. "”?", { fontSize = 14, fontWeight = "bold", color = "error", maxLines = 2 }))
                table.insert(removal, hint("This permanently removes the conversation and any child sessions. This cannot be undone."))
                table.insert(removal, ui.row({ gap = 8 }, {
                    button("Delete permanently", function() command("delete"); armedDelete = false; view = "chat" end,
                        { glyph = "trash", variant = "destructive", enabled = idle }),
                    button("Keep conversation", function() armedDelete = false; render() end, { variant = "secondary" }),
                }))
            else
                table.insert(removal, settingRow("Delete conversation", "Permanently remove this chat from history.",
                    button("Delete…", function() armedDelete = true; render() end, { glyph = "trash", enabled = idle })))
            end
            table.insert(settings, ui.column({ gap = 10, padding = 16, radius = 12, border = "error/0.2", borderWidth = 1 }, removal))
        end
        table.insert(nodes, ui.scroll({ flexGrow = 1, gap = 12 }, {
            ui.row({ gap = 0 }, { ui.spacer({}), ui.column({ width = 740, gap = 12 }, settings), ui.spacer({}) }),
        }))
    else
        local conversation = {}
        if s.messageCursor then table.insert(conversation, button("Earlier messages", function() command("older") end, { glyph = "chevron-up" })) end
        for _, m in ipairs(s.messages) do
            if m.role == "You" then
                local width = math.min(historyOpen and 400 or 540, math.max(120, #m.text * 7 + 28))
                table.insert(conversation, ui.row({ key = m.id, gap = 6, align = "center" }, {
                    ui.spacer({}),
                    icon("copy", "Copy message", function() noctalia.copyToClipboard(m.text, "text/plain") end, { opacity = 0.55 }),
                    ui.column({ padding = 12, radius = 14, fill = cardFill("surface_variant", 0.65), width = width }, {
                        ui.markdown({ text = m.text }),
                    }),
                }))
            else
                local content = { ui.markdown({ text = m.text }) }
                local actions = { icon("copy", "Copy response", function() noctalia.copyToClipboard(m.text, "text/plain") end, { opacity = 0.6 }) }
                if m.details and m.details ~= "" then
                    table.insert(actions, button(expanded[m.id] and "Hide activity" or "Activity", function()
                        expanded[m.id] = not expanded[m.id]; render()
                    end, { glyph = "terminal-2", fontSize = 12 }))
                    if expanded[m.id] then
                        table.insert(content, ui.column({ padding = 12, fill = cardFill("surface_variant", 0.3), radius = 10 }, {
                            label(m.details, { fontFamily = "monospace", fontSize = 12, maxLines = 80 }),
                        }))
                    end
                end
                table.insert(content, ui.row({ gap = 6, align = "center" }, actions))
                table.insert(conversation, ui.column({ key = m.id, gap = 6, paddingV = 4 }, content))
            end
        end
        for _, r in ipairs(s.requests) do table.insert(conversation, form(r)) end
        local transcript
        if #s.messages == 0 and #s.requests == 0 then
            transcript = ui.column({ flexGrow = 1, gap = 12, align = "center", justify = "center" }, {
                ui.glyph({ name = "sparkles", size = 28, color = "primary" }),
                label("What can I help with?", { fontSize = 23, fontWeight = "bold" }),
                label("A quick question, a fresh idea, or help with your laptop.", { color = "on_surface_variant", fontSize = 13 }),
            })
        else
            transcript = ui.scroll({ key = "transcript-" .. s.backend .. s.session, flexGrow = 1, gap = 18, stickToBottom = true }, conversation)
        end
        local body = { transcript }
        if historyOpen then
            local history = {
                ui.row({ align = "center", gap = 6 }, {
                    label("History", { fontSize = 13, fontWeight = "bold", flexGrow = 1 }),
                    icon("square-plus", "New chat", function() command("new"); armedDelete = false end, { enabled = idle }),
                }),
                ui.input({ key = "history-search", value = search, placeholder = "Search titles · Enter", onChange = function(v) search = v end,
                    onSubmit = function() command("history", search) end }),
            }
            local sessions = Conversations.history(s.sessions, snapshot.pins, search)
            for _, session in ipairs(sessions) do
                table.insert(history, ui.row({ gap = 2, align = "center" }, {
                    button(session.title:sub(1, 42), function() command("open", session.id); armedDelete = false end,
                        { key = session.id, selected = session.id == s.session, enabled = idle, contentAlign = "start", flexGrow = 1 }),
                    icon("pin", session.pinned and "Unpin chat" or "Pin chat", function() command("pin", session.id) end,
                        { selected = session.pinned == true }),
                }))
            end
            if #sessions == 0 then table.insert(history, label("No saved chats yet", { fontSize = 12, color = "on_surface_variant" })) end
            if s.historyCursor then table.insert(history, button("More chats", function() command("history", search, { cursor = s.historyCursor }) end)) end
            body = { ui.scroll({ key = "history", width = 220, gap = 6, padding = 10, fill = cardFill("surface_variant", 0.2), radius = 12 }, history), transcript }
        end
        table.insert(nodes, ui.row({ key = "chat-body", flexGrow = 1, gap = 20 }, body))
        local composer = {}
        local chips = {}
        for i, f in ipairs(s.attachments) do
            table.insert(chips, button(f.name .. " ×", function() command("remove_attachment", i) end,
                { variant = "secondary", tooltip = f.image and "Image input" or "Local file reference" }))
        end
        if #chips > 0 then table.insert(composer, ui.row({ gap = 6 }, chips)) end
        table.insert(composer, ui.input({ key = "composer-" .. s.backend .. s.session .. tostring(s.composerRevision or 0),
            value = s.draft, placeholder = "Ask anything…", multiline = true, frameVisible = false,
            submitOnEnter = true, focus = true, height = 68, onChange = function(v) command("draft", v) end,
            onSubmit = function(v) command("send", v) end }))
        local toolbar = {
            icon("paperclip", "Attach file · Ctrl+Shift+A", function() attachFile() end),
            icon("screenshot", "Capture screenshot with Noctalia (copy when finished)", function() attachFile("screenshot") end),
            icon("photo-plus", "Paste image · Ctrl+Shift+V", function() command("attach", "paste") end),
            label("Enter to send · Shift+Enter for a new line", { fontSize = 11, color = "on_surface_variant" }),
            ui.spacer({}),
        }
        if s.busy or snapshot.sending or #s.requests > 0 then
            table.insert(toolbar, label(s.activity == "interrupted" and "Interrupted · reconnect" or (s.activity == "stopping" and "Stopping…" or (s.status == "waiting" and "Waiting for you" or "Working…")), { fontSize = 12, color = "tertiary" }))
            table.insert(toolbar, icon("player-stop", "Stop response · Ctrl+Shift+X", function() command("stop") end,
                { variant = "secondary", enabled = s.busy or #s.requests > 0 }))
        elseif not s.connected then
            table.insert(toolbar, label(s.connection and (s.connection.phase == "connecting" or s.connection.phase == "reconnecting") and "Connecting…" or "Disconnected", { fontSize = 12, color = "error" }))
        end
        table.insert(toolbar, icon("arrow-up", "Send message", function() command("send") end,
            { variant = "primary", enabled = s.connected and idle and not s.limitPaused and not (s.usage or {}).blocked and s.draft:match("%S") ~= nil, key = "send-message" }))
        table.insert(composer, ui.row({ gap = 6, align = "center" }, toolbar))
        table.insert(nodes, ui.column({ key = "composer-surface", gap = 4, padding = 10, radius = 14,
            fill = cardFill("surface_variant", 0.3), border = "outline/0.4", borderWidth = 1 }, composer))
    end
    panel.render(ui.column({ gap = 16, padding = 22, fill = "surface/" .. tostring(alphaSetting("background_opacity")), flexGrow = 1 }, nodes))
end
noctalia.state.watch("chat_snapshot", function(value) snapshot = value; render() end)
local function opened(context)
    if context == "options" then view = "options" end
    isOpen = true
    snapshot = noctalia.state.get("chat_snapshot")
    armedDelete = false
    armedRecovery = false
    historyOpen = noctalia.getConfig("history_open") == true
    command("visible", true)
    render()
end
local function closed() isOpen = false; command("visible", false) end
return { open = opened, close = closed, key = key }

end
return M
