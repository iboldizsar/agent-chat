--!nonstrict
local snapshot = noctalia.state.get("chat_snapshot")
local function render()
    local status = "idle"
    for _, value in pairs(snapshot and snapshot.background or {}) do
        if value == "waiting" then status = value; break
        elseif value == "working" then status = value
        elseif value == "finished" and status == "idle" then status = value
        elseif (value == "disconnected" or value == "offline") and status == "idle" then status = "disconnected"
        elseif (value == "connecting" or value == "reconnecting") and status == "idle" then status = value end
    end
    barWidget.setGlyph(status == "waiting" and "message-question" or "message-circle")
    barWidget.setText((noctalia.getConfig("show_bar_status") == false or status == "idle") and "" or status)
    barWidget.setTooltip("Agent Chat · " .. status)
end
noctalia.state.watch("chat_snapshot", function(value) snapshot = value; render() end)
function update() render() end
function onClick()
    noctalia.togglePanel(noctalia.getConfig("open_fullscreen") and "local/agent-chat:fullscreen" or "local/agent-chat:panel")
end
function onRightClick() noctalia.openSettings() end
render()
