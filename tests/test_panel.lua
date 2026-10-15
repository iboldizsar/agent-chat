-- Noctalia modules have separate global environments. Exercise the real entry hooks.
local root = assert(arg[1], "pass project root")
local snapshot = nil
local renders, lastTree = 0, nil
local commands, toggles, closes = {}, {}, 0
local ui = setmetatable({}, { __index = function(_, name)
    return function(props, children) return { type = name, props = props, children = children or {} } end
end })
local host = {
    ui = ui,
    panel = { render = function(tree) renders = renders + 1; lastTree = tree end,
        close = function() closes = closes + 1 end },
    noctalia = {
        state = { get = function() return snapshot end, set = function(key, value) if key == "chat_command" then table.insert(commands, value) end end, watch = function() end },
        nowMs = function() return 0 end,
        togglePanel = function(id) table.insert(toggles, id) end,
        getConfig = function(key)
            if key == "background_opacity" then return 35 end
            if key == "card_opacity" then return 50 end
            return false
        end,
    },
}
setmetatable(host, { __index = _G })
local function entry(filename)
    local cache = {}
    local function environment()
        local env = setmetatable({}, { __index = host })
        env._G = env
        env.require = function(relative)
            local caller = debug.getinfo(2, "S").source:sub(2)
            local file = caller:match("(.*/)") .. relative
            if not cache[file] then
                cache[file] = assert(loadfile(file, "t", environment()))()
            end
            return cache[file]
        end
        return env
    end
    local env = environment()
    assert(loadfile(root .. "/plugin/" .. filename, "t", env))()
    return env
end
local function contains(node, predicate)
    if predicate(node) then return true end
    for _, child in ipairs(node.children or {}) do if contains(child, predicate) then return true end end
    return false
end
for _, filename in ipairs({ "panel.luau", "fullscreen.luau" }) do
    local env = entry(filename)
    assert(type(env.onOpen) == "function", filename .. " must export the entry onOpen callback")
    assert(type(env.onClose) == "function", filename .. " must export the entry onClose callback")
    snapshot = nil
    local before = renders
    env.onOpen()
    assert(renders > before, "opening without a service snapshot must render a startup view")
    snapshot = { backend = "opencode", current = {
        backend = "opencode", models = {}, agents = {}, sessions = {}, messages = {}, requests = {},
        model = "", status = "idle", title = "New chat", error = "", attachments = {}, session = "", draft = "",
    } }
    env.onOpen()
    assert(contains(lastTree, function(n) return n.props.text == "OpenCode" end), "header must render on open")
    assert(contains(lastTree, function(n) return n.type == "input" and n.props.multiline end), "composer must render on open")
    assert(contains(lastTree, function(n) return n.type == "button" and n.props.tooltip == ((filename == "fullscreen.luau" and "Windowed" or "Full screen") .. " · Ctrl+Shift+F") end))
    assert(not contains(lastTree, function(n) return n.type == "input" and n.props.key == "history-search" end), "history should start collapsed")
    assert(contains(lastTree, function(n) return n.type == "input" and n.props.frameVisible == false end), "composer should use its enclosing surface")
    local function click(node, key)
        if node.props.key == key then node.props.onClick(); return true end
        for _, child in ipairs(node.children or {}) do if click(child, key) then return true end end
        return false
    end
    assert(lastTree.props.fill == "surface/0.35", "background alpha must preserve opaque content")
    assert(lastTree.props.opacity == nil, "transparency must not fade text")
    assert(contains(lastTree, function(n) return n.props.key == "composer-surface" and n.props.fill == "surface_variant/0.15" end))
    assert(click(lastTree, "chat-options"))
    assert(contains(lastTree, function(n) return n.props.text == "Assistant" end), "assistant controls remain available in options")
    local function findControl(node, key)
        if node.props.key == key then return node end
        for _, child in ipairs(node.children or {}) do
            local found = findControl(child, key)
            if found then return found end
        end
    end
    snapshot.current.agents = { { id = "one", name = "One" }, { id = "two", name = "Two" } }
    snapshot.current.agent = "one"
    env.onOpen()
    local picker = assert(findControl(lastTree, "backend-picker"))
    assert(picker.props.text == "OpenCode", "backend name must be the panel title")
    picker.props.onClick()
    assert(click(lastTree, "backend-codex"))
    assert(commands[#commands].action == "backend" and commands[#commands].value == "codex")
    assert(click(lastTree, "chat-options"))
    local agents = assert(findControl(lastTree, "agent-select"))
    assert(agents.props.selectedIndex == 0)
    agents.props.onChange("1")
    assert(commands[#commands].action == "agent" and commands[#commands].value == "two")
    snapshot.backend = "codex"; snapshot.current.backend = "codex"
    snapshot.current.model = "test"
    snapshot.current.models = { { key = "test", label = "Test", defaultEffort = "high", efforts = {
        { reasoningEffort = "low" }, { reasoningEffort = "high" },
    } } }
    env.onOpen()
    assert(findControl(lastTree, "backend-picker").props.text == "Codex")
    local refresh = assert(findControl(lastTree, "refresh-usage"))
    refresh.props.onClick(); assert(commands[#commands].action == "usage")
    local effort = assert(findControl(lastTree, "reasoning-test"))
    assert(effort.props.selectedIndex == 1)
    effort.props.onChange("0")
    assert(commands[#commands].action == "effort" and commands[#commands].value == "low")
    snapshot.backend = "opencode"; snapshot.current.backend = "opencode"
    snapshot.current.model = ""; snapshot.current.models = {}
    local function press(chord) env.onKey(chord, true) end
    local function hasText(text)
        return contains(lastTree, function(n) return n.props.text == text end)
    end
    press("ctrl+shift+question")
    assert(hasText("Keyboard shortcuts"))
    press("ctrl+shift+slash")
    assert(hasText("What can I help with?"))
    press("ctrl+h")
    assert(commands[#commands].action == "history", "opening history must refresh backend-owned saved conversations")
    assert(contains(lastTree, function(n) return n.props.key == "history-search" end))
    press("ctrl+h")
    assert(not contains(lastTree, function(n) return n.props.key == "history-search" end))
    press("ctrl+m"); assert(hasText("Choose a model"))
    press("ctrl+comma"); assert(hasText("Chat options"))
    local count = #commands
    env.onKey("ctrl+n", false)
    press("ctrl+c"); press("ctrl+v"); press("ctrl+x"); press("ctrl+a"); press("ctrl+z")
    assert(#commands == count, "releases and editing chords must not dispatch actions")
    press("ctrl+n"); assert(commands[#commands].action == "new")
    press("ctrl+shift+A"); assert(commands[#commands].action == "attach" and commands[#commands].value == "pick" and commands[#commands].returnPanel == (filename == "fullscreen.luau" and "iboldizsar/agent-chat:fullscreen" or "iboldizsar/agent-chat:panel"))
    press("ctrl+shift+v"); assert(commands[#commands].action == "attach" and commands[#commands].value == "paste")
    snapshot.current.busy = true
    count = #commands
    press("ctrl+n"); assert(#commands == count, "new chat must be blocked while busy")
    press("ctrl+m"); assert(not hasText("Choose a model"), "model picker must be blocked while busy")
    press("ctrl+shift+x"); assert(commands[#commands].action == "stop")
    snapshot.current.busy = false
    count = #commands; press("ctrl+shift+x"); assert(#commands == count, "idle stop is a no-op")
    press("ctrl+shift+f")
    assert(closes > 0 and toggles[#toggles] == (filename == "fullscreen.luau" and "iboldizsar/agent-chat:panel" or "iboldizsar/agent-chat:fullscreen"))
    snapshot.current.attachments = { { name = '日本語 image.png', path = '/private/image.png', image = true, size = 2048 } }
    snapshot.current.models = { { key = 'text', label = 'Text', modalities = { 'text' } } }
    snapshot.current.model = 'text'
    env.onOpen()
    assert(contains(lastTree, function(n) return n.type == 'image' and n.props.path == '/private/image.png' end))
    assert(hasText('Choose a model that accepts images') and hasText('2 KiB'))
    assert(click(lastTree, 'preview-1'))
    assert(findControl(lastTree, 'attachment-preview'))
    assert(click(lastTree, 'preview-remove') and commands[#commands].action == 'remove_attachment')
    snapshot.current.attachments = {}
    snapshot.current.connected = true
    snapshot.current.sessions = { { id = 'row', title = 'Saved chat' } }
    press('ctrl+h')
    assert(findControl(lastTree, 'history-delete-row').props.enabled)
    local beforeDelete = #commands
    assert(click(lastTree, 'history-delete-row'))
    assert(hasText('Delete “Saved chat”?') and #commands == beforeDelete)
    assert(click(lastTree, 'history-delete-cancel') and #commands == beforeDelete)
    assert(click(lastTree, 'history-delete-row'))
    assert(click(lastTree, 'history-delete-confirm'))
    assert(commands[#commands].action == 'delete' and commands[#commands].value == 'row')
    assert(findControl(lastTree, 'history-pinned'))
    assert(click(lastTree, 'history-pinned') and hasText('No pinned chats'))
    press('ctrl+h')
    snapshot.current.connected = false
    snapshot.setup = { active = true, completed = false, runtime = {
        checking = false, backends = { codex = { status = "missing" }, opencode = { status = "available", version = "2.0.29" } }, tools = {} } }
    env.onOpen()
    assert(hasText("Welcome to Agent Chat"))
    assert(findControl(lastTree, "setup-opencode").props.enabled)
    assert(not findControl(lastTree, "setup-codex").props.enabled)
    assert(not findControl(lastTree, "setup-finish").props.enabled)
    assert(click(lastTree, "setup-cancel") and commands[#commands].action == "setup_cancel")
    snapshot.setup.active = false
    env.onOpen()
    assert(not hasText("Welcome to Agent Chat"))
    env.onClose()
    count = #commands
    press("ctrl+n"); press("ctrl+shift+a")
    assert(#commands == count, "closed panel must ignore shortcuts")
end
print("Panel entry callbacks render with isolated module globals: passed")
