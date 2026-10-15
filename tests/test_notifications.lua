local root = assert(arg[1])
local sent, opened, config = {}, {}, {}
local env = setmetatable({ noctalia = {
    getConfig = function(key) return config[key] end,
    commandExists = function() return true end,
    runStream = function(command, cb) table.insert(sent, { command = command, cb = cb }); return true end,
} }, { __index = _G })
local module = assert(loadfile(root .. "/plugin/lib/notifications.luau", "t", env))()
local update = module.new(function(name, session) opened = { name, session } end)
local s = { session = "chat1", connected = true, busy = false, status = "idle", error = "", requests = {} }
update("codex", s, true); assert(#sent == 0)
s.busy = true; update("codex", s, true)
s.busy = false; update("codex", s, true); assert(#sent == 1)
update("codex", s, true); assert(#sent == 1, "repeat snapshots must not repeat notifications")
sent[1].cb("open"); assert(opened[1] == "codex" and opened[2] == "chat1")
s.requests = { { id = 1, text = "private prompt" } }; s.status = "waiting"
update("codex", s, true); update("codex", s, true); assert(#sent == 2)
assert(not sent[2].command:find("private prompt", 1, true), "notifications must not expose prompts")
s.requests = {}; s.status = "idle"; s.busy = true; update("codex", s, false)
s.busy = false; update("codex", s, false); assert(#sent == 2, "visible chat needs no completion notification")
s.busy = true; update("codex", s, true)
s.busy = false; s.connected = false; update("codex", s, true); assert(#sent == 2, "disconnect is not completion")
s.connected = true; s.busy = true; update("codex", s, true)
config.notify_completion = false; s.busy = false; update("codex", s, true); assert(#sent == 2)
print("Notification transitions, privacy, actions and toggles: passed")

config.notify_completion = true
s.error = ''; s.busy = true; update('codex', s, true)
s.connected = false; update('codex', s, true)
s.connected = true; s.recovering = true; update('codex', s, true)
s.busy = false; update('codex', s, true)
s.recovering = false; update('codex', s, true)
assert(#sent == 2, 'transport/session recovery must not masquerade as completed work')

-- Action callbacks and individual approvals are delivered at most once.
local actionCount = 0
local checkpoint = {}
local tracking = module.new(function() actionCount = actionCount + 1 end, checkpoint)
local state = { session = 'separate', connected = true, busy = false, status = 'waiting', error = '', requests = {} }
tracking('codex', state, true)
state.requests = { { id = 'one' } }; tracking('codex', state, true)
local first = #sent
sent[first].cb('open'); sent[first].cb('open'); assert(actionCount == 1)
state.requests = { { id = 'one' }, { id = 'two' } }; tracking('codex', state, true)
local count = #sent
state.requests = { { id = 'one' } }; tracking('codex', state, true)
assert(#sent == count, 'resolving a subset must not repeat old approval notifications')
local reloaded = module.new(function() end, checkpoint)
reloaded('codex', state, true)
state.requests = {}; reloaded('codex', state, true)
state.requests = { { id = 'one' } }; reloaded('codex', state, true)
assert(#sent == count, 'persisted approval ids suppress replay after reload')
for i = 1, 150 do state.requests = { { id = 'new-' .. i } }; reloaded('codex', state, false) end
assert(#checkpoint == 128, 'deduplication metadata must stay bounded')
print('Notification actions, approval subsets, reload deduplication and metadata bounds: passed')
