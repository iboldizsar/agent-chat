-- Noctalia discovers lifecycle callbacks only in the entry environment.
local view = require("./lib/panel.luau").mount(true)
local lastError = nil
local function openView(context)
    local ok, err = pcall(view.open, context)
    lastError = not ok and tostring(err) or nil
    if not ok then
        panel.render(ui.column({ padding = 20, gap = 12 }, {
            ui.label({ text = "Agent Chat could not render", color = "error" }),
            ui.label({ text = lastError }),
        }))
    end
end
function onOpen(context) openView(context) end
function onClose() view.close() end
function onKey(chord, pressed) view.key(chord, pressed) end
function onIpc(event)
    if event ~= "diagnose" then return end
    openView()
    noctalia.writeFile(noctalia.pluginDataDir() .. "/fullscreen-diagnostic.json",
        noctalia.json.encode({ rendered = lastError == nil, error = lastError }))
end
