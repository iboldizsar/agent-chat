-- Native-host boundary simulation: delayed callbacks, v2 payloads, and resume races.
local root = assert(arg[1], "pass project root")
local cache = {}
function require(path)
    local source = debug.getinfo(2, "S").source:sub(2)
    local file = source:match("(.*/)") .. path
    if not cache[file] then cache[file] = assert(loadfile(file, "t", _G))() end
    return cache[file]
end
local queue, fixtures, eventCallbacks = {}, {}, {}
local serial = 0
noctalia = {
    json = { encode = function(x) serial = serial + 1; local key = "json-" .. serial; fixtures[key] = x; return key end, decode = function(x) return type(x) == "table" and x or fixtures[x] end },
    string = { urlEncode = function(x) return x end },
    expandPath = function(x) return x end,
    readFile = function() return { url = "http://127.0.0.1:1234", password = "test", token = "test", cwd = "/assistant" } end,
    pluginDir = function() return root .. "/plugin" end,
    nowMs = function() return 100000 end,
    runAsync = function(_, cb) if cb then cb({}) end; return true end,
    http = function(r, cb) table.insert(queue, { request = r, callback = cb }); return true end,
    httpStream = function(_, cb) table.insert(eventCallbacks, cb); return { stop = function() end } end,
}
local function respond(match, result, status)
    for i, q in ipairs(queue) do
        if match(q.request) then
            table.remove(queue, i)
            q.callback({ ok = true, status = status or 200, body = result })
            return q.request
        end
    end
    error("No matching request")
end
local function rpc(method, result)
    return respond(function(r) return fixtures[r.body] and fixtures[r.body].method == method end, { result = result })
end
local function path(tail, result)
    return respond(function(r) return r.url:find(tail, 1, true) ~= nil end, result)
end
local Codex = assert(loadfile(root .. "/plugin/lib/codex.luau"))()
local a = Codex.new("/assistant", function() end)
a.connect()
path("/health", {})
rpc("model/list", { data = { { model = "test", displayName = "Test", isDefault = true } } })
rpc("account/rateLimits/read", { known = true, blocked = false })
rpc("thread/list", { data = {} })
a.open("first")
a.open("second")
rpc("thread/resume", { model = "test", thread = { id = "first", turns = {}, status = { type = "idle" } } })
assert(a.state.session ~= "first", "stale resume must not overwrite selection")
rpc("thread/resume", { model = "test", thread = { id = "second", name = "Second", turns = {}, status = { type = "idle" } } })
rpc("thread/items/list", { data = {
    { turnId = "t", item = { id = "a", type = "agentMessage", text = "Hello" } },
    { turnId = "t", item = { id = "u", type = "userMessage", content = { { type = "text", text = "Hi" } } } },
} })
path("/pending", { pending = {}, usage = {} })
assert(a.state.messages[1].text == "Hi", "wrapped descending items must normalize chronologically")
assert(a.state.messages[2].text == "Hello")
fixtures.delta = { seq = 1, method = "item/agentMessage/delta", params = { threadId = "second", itemId = "a", delta = "!" } }
eventCallbacks[1]("data:delta")
assert(a.state.messages[2].text == "Hello!", "stream delta must update existing message")
fixtures.done = { seq = 2, method = "item/completed", params = { threadId = "second", item = { id = "a", type = "agentMessage", text = "Hello!" } } }
eventCallbacks[1]("data:done")
assert(#a.state.messages == 2 and a.state.messages[2].text == "Hello!", "final item must reconcile without duplication")
print("Codex normalization, stale-resume, delta reconciliation: passed")
queue = {}
local OpenCode = assert(loadfile(root .. "/plugin/lib/opencode.luau"))()
local o = OpenCode.new("/assistant", function() end)
o.connect()
path("/api/info", {})
path("/api/model?", { data = { { enabled = true, id = "test", providerID = "go", name = "Test" } } })
path("/api/model/default", { data = { id = "test", providerID = "go" } })
path("/api/agent", { data = { { id = "build", name = "Build", mode = "primary" } } })
path("/api/session?", { data = {} })
o.open("outside")
path("/outside", { data = { location = { directory = "/unrelated" } } })
assert(o.state.session == "", "must reject foreign sessions")
assert(o.state.error:find("outside"))
o.open("own")
path("/own", { data = { title = "Own", location = { directory = "/assistant" }, model = { id = "test", providerID = "go" } } })
path("/message?", { data = {
    { id = "a", type = "assistant", content = { { type = "text", text = "Answer" }, { type = "tool", name = "read", state = { status = "completed" } } } },
    { id = "u", type = "user", text = "Question" },
}, cursor = { next = "older" } })
path("/active", { data = {} })
path("/permission", { data = { { id = "p", action = "read", resources = { "/file" } } } })
path("/form", { data = {} })
assert(o.state.messages[1].text == "Question")
assert(o.state.messages[2].details:find("read"))
assert(o.state.status == "waiting" and #o.state.requests == 1)
print("OpenCode directory scoping, ordering, tool details, pending approvals: passed")

local sent = false
o.state.busy = false
o.send("test", {}, function(ok, err) assert(ok, err); sent = true end)
path("/model", {})
local submission = respond(function(r) return r.url:find("/prompt", 1, true) end, { data = {} })
assert(fixtures[submission.body].files == nil, "omit empty files: native empty tables encode as objects")
assert(sent)
print("OpenCode empty-attachment submission: passed")

o.state.busy = false
fixtures.formEvent = { type = "form.created", data = { form = { sessionID = "own" } } }
eventCallbacks[2]("data:formEvent")
o.tick()
local refreshQueued = false
for _, q in ipairs(queue) do if q.request.url:find("/message?", 1, true) then refreshQueued = true end end
assert(refreshQueued, "an idle session must fetch newly created forms from nested form.sessionID")
print("OpenCode idle form-event recovery: passed")

queue = {}
local beforeCodex = a.state.messages
local codexExport
a.export(function(rows, err) assert(not err, err); codexExport = rows end)
rpc('thread/items/list', { data = { { item = { id = 'new-export', type = 'agentMessage', text = 'Recent' } } }, nextCursor = 'older-page' })
local exportRequest = rpc('thread/items/list', { data = { { item = { id = 'old-export', type = 'userMessage', content = { { type = 'text', text = 'Original' } } } } } })
assert(fixtures[exportRequest.body].params.cursor == 'older-page')
assert(codexExport[1].text == 'Original' and codexExport[2].text == 'Recent')
assert(a.state.messages == beforeCodex, 'export must not replace the live transcript')
queue = {}
local beforeOpenCode = o.state.messages
local openCodeExport
o.export(function(rows, err) assert(not err, err); openCodeExport = rows end)
path('/message?', { data = { { id = 'new-export', type = 'assistant', content = { { type = 'text', text = 'Recent' } } } }, cursor = { next = 'older-page' } })
local exportPage = path('&cursor=older-page', { data = { { id = 'old-export', type = 'user', text = 'Original' } } })
assert(exportPage.url:find('/api/session/own/message?', 1, true))
assert(openCodeExport[1].text == 'Original' and openCodeExport[2].text == 'Recent')
assert(o.state.messages == beforeOpenCode)
print('Both backends export full pages without modifying chat state: passed')
