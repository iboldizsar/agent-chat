--!nonstrict
local function render(snapshot)
    local active = false
    for _, status in pairs(snapshot and snapshot.background or {}) do
        if status == "working" or status == "waiting" then active = true end
    end
    shortcut.setLabel("Agent Chat")
    shortcut.setIcon("message-circle")
    shortcut.setActive(active)
    shortcut.setEnabled(true)
end
noctalia.state.watch("chat_snapshot", render)
render(noctalia.state.get("chat_snapshot"))
function onClick()
    noctalia.togglePanel(noctalia.getConfig("open_fullscreen") and "iboldizsar/agent-chat:fullscreen" or "iboldizsar/agent-chat:panel")
end
function onRightClick() noctalia.openSettings() end
noctalia.writeFile(noctalia.pluginDataDir() .. "/shortcut-diagnostic.json",
    noctalia.json.encode({ loaded = true }))
