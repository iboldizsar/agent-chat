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
local clock = 100000
noctalia = {
    json = { encode = function(x) serial = serial + 1; local key = "json-" .. serial; fixtures[key] = x; return key end, decode = function(x) return type(x) == "table" and x or fixtures[x] end },
    string = { urlEncode = function(x) return x end },
    expandPath = function(x) return x end,
    readFile = function() return { url = "http://127.0.0.1:1234", password = "test", token = "test", cwd = "/assistant" } end,
    pluginDir = function() return root .. "/plugin" end,
    nowMs = function() return clock end,
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
local function path(tail, result, status)
    return respond(function(r) return r.url:find(tail, 1, true) ~= nil end, result, status)
end
local Codex = assert(loadfile(root .. "/plugin/lib/codex.luau"))()
local a = Codex.new("/assistant", function() end)
a.connect()
path("/health", {})
rpc("model/list", { data = { { model = "test", displayName = "Test", isDefault = true } } })
rpc("account/read", { signedIn = true })
assert(a.state.authentication == "ready")
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

queue = {}
local failedExport
a.export(function(rows, err) assert(not rows); failedExport = err end)
fixtures.disconnect = { seq = 7, method = 'bridge/disconnected' }
eventCallbacks[1]('data:disconnect')
rpc('thread/items/list', { data = {} })
assert(failedExport and failedExport:find('not repeated'), 'connection loss must finish pending export instead of leaving it stuck')
queue = {}
local oldGeneration = o.state.connection.attempt
o.connect(); o.connect()
local connectionRequests = 0
for _, q in ipairs(queue) do if q.request.url:find('/api/info', 1, true) then connectionRequests = connectionRequests + 1 end end
assert(connectionRequests == 1, 'repeated Retry must not overlap OpenCode connections')
print('Adapter failure completion and duplicate connect prevention: passed')

queue = {}
a.connect(); clock = clock + 20001; a.tick()
assert(not a.state.connected)
path('/health', {})
assert(not a.state.connected, 'a timed-out health response must not revive a stale connection')
queue = {}
clock = clock + 40000; a.tick(); path('/health', {})
queue = {}
a.open('recover')
rpc('thread/resume', { model = 'test', thread = { id = 'recover', status = { type = 'idle' }, turns = {} } })
assert(a.state.recovering)
rpc('thread/items/list', { data = {} })
assert(a.state.recovering, 'messages alone are insufficient without pending-request recovery')
path('/pending', { pending = {}, usage = {} })
assert(not a.state.recovering)
queue = {}
a.list('old'); a.list('new')
rpc('thread/list', { data = { { id = 'stale', name = 'Old' } } })
rpc('thread/list', { data = { { id = 'fresh', name = 'New' } } })
assert(#a.state.sessions == 1 and a.state.sessions[1].id == 'fresh', 'late search results must not replace the new search')
queue = {}
o.tick(); o.connect(); path('/api/info', {})
queue = {}
o.open('recover')
path('/api/session/recover', { data = { id = 'recover', location = { directory = '/assistant' } } })
assert(o.state.recovering)
path('/message?', { data = {} }); path('/active', { data = {} }); path('/permission', { data = {} })
assert(o.state.recovering)
path('/form', { data = {} })
assert(not o.state.recovering, 'OpenCode recovery requires messages, activity, permissions and questions')
print('Timed-out connection, authoritative recovery gates and stale history search: passed')

queue = {}
a.rename('Old renamed'); a.new(); a.state.title = 'Keep new title'
rpc('thread/name/set', {})
assert(a.state.title == 'Keep new title', 'late rename must not rename a newer conversation')
queue = {}
a.state.session = 'delete-old'; local deleted = false
a.delete(function() deleted = true end); a.new(); a.state.session = 'keep-new'
rpc('thread/delete', {})
assert(deleted and a.state.session == 'keep-new', 'late delete must not clear a newly selected conversation')
queue = {}
o.state.busy = false; o.state.session = 'delete-old'; deleted = false
o.delete(function() deleted = true end); o.new(); o.state.session = 'keep-new'
path('/api/session/delete-old', {})
assert(deleted and o.state.session == 'keep-new')
print('Late rename/delete completion preserves newly selected conversations: passed')

queue = {}
local originalRead, registrationReady = noctalia.readFile, false
noctalia.readFile = function(path)
    if path:find('endpoint.json', 1, true) and not registrationReady then return nil end
    return originalRead(path)
end
local cold = Codex.new('/assistant', function() end)
cold.connect()
assert(cold.state.connection.phase == 'connecting' and cold.state.error == '', 'cold helper registration must be awaited without a false failure')
registrationReady = true; clock = clock + 201; cold.tick(); path('/health', {})
assert(cold.state.connected)
rpc('account/rateLimits/read', { known = false, windows = {} })
noctalia.readFile = originalRead
print('Cold Codex helper registration readiness: passed')

for _, backend in ipairs({ 'codex', 'opencode' }) do
    queue = {}
    local adapter = backend == 'codex' and cold or o
    local function historyReply(data, nextCursor, status)
        if backend == 'codex' then
            if status then respond(function(r) return fixtures[r.body] and fixtures[r.body].method == 'thread/list' end, { error = 'offline' }, status)
            else rpc('thread/list', { data = data, nextCursor = nextCursor }) end
        else path('/api/session?', status and { error = 'offline' } or { data = data, cursor = { next = nextCursor } }, status) end
    end
    adapter.list('new query')
    assert(adapter.state.historyLoading and #adapter.state.sessions == 0)
    local row = backend == 'codex' and { id = 'one', name = 'One', updatedAt = 1800000000 } or { id = 'one', title = 'One', time = { updated = 1800000000000 } }
    historyReply({ row }, 'next')
    assert(not adapter.state.historyLoading and adapter.state.sessions[1].updated == 1800000000)
    adapter.list('new query', 'next'); adapter.list('new query', 'next')
    assert(#queue == 1, 'pagination is serialized')
    historyReply({ row }, 'next')
    assert(#adapter.state.sessions == 1 and not adapter.state.historyCursor and adapter.state.historyError)
    adapter.list('failing query'); historyReply(nil, nil, 503)
    assert(not adapter.state.historyLoading and adapter.state.historyError and #adapter.state.sessions == 0)
end
print('Both adapters expose loading/errors, normalize dates and bound duplicate pagination: passed')

for _, backend in ipairs({ 'codex', 'opencode' }) do
    queue = {}
    local adapter = backend == 'codex' and cold or o
    adapter.state.session = 'keep'; adapter.state.draft = 'keep draft'
    local outcome
    adapter.open('missing-pin', function(ok) outcome = ok end)
    if backend == 'codex' then
        respond(function(r) return fixtures[r.body] and fixtures[r.body].method == 'thread/resume' end, { error = 'Conversation unavailable' }, 400)
    else path('/api/session/missing-pin', { error = 'Not found' }, 404) end
    assert(outcome == false and adapter.state.session == 'keep' and adapter.state.draft == 'keep draft')
    assert(not adapter.state.recovering and adapter.state.openFailures['missing-pin'])
end
print('Unavailable pins do not strand the current conversation or replace its draft: passed')

queue = {}
cold.refreshUsage(); cold.refreshUsage()
assert(#queue == 1 and cold.state.usageChecking)
rpc('account/rateLimits/read', { known = true, checkedAt = clock / 1000, windows = { { usedPercent = 5 } } })
assert(not cold.state.usageChecking and cold.state.usage.known)
cold.refreshUsage()
respond(function(r) return fixtures[r.body] and fixtures[r.body].method == 'account/rateLimits/read' end, { error = 'offline' }, 503)
assert(not cold.state.usageChecking and cold.state.usage.stale)
print('Usage refresh is serialized and retains stale evidence on failure: passed')

for _, backend in ipairs({ 'codex', 'opencode' }) do
    queue = {}
    local adapter = backend == 'codex' and cold or o
    adapter.state.session = 'keep-current'; adapter.state.busy = false; adapter.state.draft = 'keep draft'
    local success, cleared
    adapter.delete(function(ok, selected) success = ok; cleared = selected end, 'delete-history-row')
    if backend == 'codex' then
        local request = rpc('thread/delete', {})
        assert(fixtures[request.body].params.threadId == 'delete-history-row')
    else path('/api/session/delete-history-row', {}) end
    assert(success and not cleared and adapter.state.session == 'keep-current' and adapter.state.draft == 'keep draft')
    queue = {}
    adapter.delete(function(ok) success = ok end, 'cannot-delete')
    if backend == 'codex' then
        respond(function(r) return fixtures[r.body] and fixtures[r.body].method == 'thread/delete' end, { error = 'denied' }, 400)
    else path('/api/session/cannot-delete', { error = 'denied' }, 400) end
    assert(success == false and adapter.state.historyError and adapter.state.session == 'keep-current')
end
print('History row deletion targets its ID without switching or clearing the current chat: passed')

queue = {}
cold.open('tool-metadata')
rpc('thread/resume', { model = 'test', thread = { id = 'tool-metadata', turns = {}, status = { type = 'idle' } } })
rpc('thread/items/list', { data = { { id = 'command-failed', type = 'commandExecution', status = 'completed', exitCode = 1 } } })
path('/pending', { pending = {}, usage = {} })
assert(cold.state.messages[1].activityKind == 'commandExecution' and cold.state.messages[1].activityStatus == 'failed')
print('Nonzero command exit codes remain visible in compact activity summaries: passed')
