local root = assert(arg[1])
local time, files, encoded, serial = 0, {}, {}, 0
local function clone(value)
    if type(value) ~= 'table' then return value end
    local out = {}; for k, v in pairs(value) do out[k] = clone(v) end; return out
end
local api, watch, snapshot, captureDone, exportDone, saveDone = {}, nil, nil, nil, nil, nil
local runtimeDone
local states, replyCount, replyDone, opens = {}, 0, nil, 0
api.json = { encode = function(value) serial = serial + 1; local id = 'j' .. serial; encoded[id] = clone(value); return id end,
    decode = function(raw) return clone(encoded[raw]) end }
api.string = { urlEncode = function(v) return v end }
api.pluginDataDir = function() return '/private' end
api.pluginDir = function() return root .. '/plugin' end
api.expandPath = function(v) return v end
api.getConfig = function() return '/assistant' end
api.nowMs = function() return time end
api.readFile = function(path) return files[path] end
api.writeFile = function(path, value) files[path] = value; return true end
api.renameFile = function(from, to) files[to] = files[from]; files[from] = nil; return true end
api.removeFile = function(path) files[path] = nil; return true end
api.fileExists = function(path) return path == '/assistant/AGENTS.md' or files[path] ~= nil end
api.mkdirAll = function() return true end
api.setUpdateInterval = function() end
api.runAsync = function(argv, cb)
    if argv[2] and argv[2]:find('runtime_check.py', 1, true) then runtimeDone = cb end
    if argv[2] == 'msg' and argv[3] == 'panel-open' then opens = opens + 1 end
    return true
end
api.state = { watch = function(_, cb) watch = cb end, set = function(_, value) snapshot = value end }
local env = setmetatable({ noctalia = api }, { __index = _G })
local cache = {}
local function adapter(name)
    local s = { backend = name, model = '', session = '', effort = '', agent = '', draft = '', title = 'Chat', error = '',
        requests = {}, sessions = {}, models = {}, agents = {}, attachments = {}, messages = {}, busy = false, status = 'idle' }
    states[name] = s
    return { state = s, connect = function() s.connected = true end, tick = function() end,
        export = function(cb) exportDone = cb end, close = function() end,
        open = function(id) s.session = id end, new = function() s.session = '' end,
        reply = function(_, _, cb) replyCount = replyCount + 1; replyDone = cb end }
end
env.require = function(relative)
    if relative == './lib/opencode.luau' then return { new = function() return adapter('opencode') end } end
    if relative == './lib/codex.luau' then return { new = function() return adapter('codex') end } end
    if relative == './lib/notifications.luau' then return { new = function() return function() end end } end
    if relative == './lib/attachments.luau' then return {
        capture = function(_, _, done) captureDone = done; return true end,
        saveExport = function(_, _, done) saveDone = done; return true end, tick = function() end,
    } end
    local caller = debug.getinfo(2, 'S').source:sub(2)
    local path = caller:match('(.*/)') .. relative
    if not cache[path] then cache[path] = assert(loadfile(path, 't', env))() end
    return cache[path]
end
assert(loadfile(root .. '/plugin/service.luau', 't', env))()
local function tick() time = time + 101; env.update() end
local function action(kind, value, extra)
    local req = { action = kind, value = value }; for k, v in pairs(extra or {}) do req[k] = v end
    watch(req); tick()
end
local function result(value) return { stdout = api.json.encode(value) } end
assert(snapshot.setup.active and not states.opencode.connected and not states.codex.connected)
runtimeDone(result({ backends = { codex = { status = 'available' }, opencode = { status = 'missing' } }, tools = {} })); tick()
assert(snapshot.backend == 'codex' and not states.codex.connected, 'only backend is preselected without connecting')
action('setup_complete'); assert(snapshot.setup.active)
action('setup_connect', 'opencode'); assert(not states.opencode.connected)
action('setup_connect', 'codex'); assert(states.codex.connected)
states.codex.models = { { key = 'c', label = 'Codex', efforts = { { reasoningEffort = 'low' } } } }
action('model', 'c'); action('effort', 'invented'); assert(states.codex.effort == nil)
action('effort', 'low'); assert(states.codex.effort == 'low')
states.codex.authentication = 'required'
action('setup_complete'); assert(snapshot.setup.active)
states.codex.authentication = 'ready'
action('setup_complete'); assert(not snapshot.setup.active and snapshot.setup.completed)
action('setup_open'); assert(snapshot.setup.active)
action('setup_cancel'); assert(not snapshot.setup.active)
action('backend', 'opencode')

action('attach', 'pick', { returnPanel = 'local/agent-chat:panel' })
assert(snapshot.interactiveJob == 'attachment')
action('backend', 'codex')
captureDone(result({ path = '/private/image.png', name = 'image.png' })); tick()
assert(#states.codex.attachments == 0 and #states.opencode.attachments == 0 and opens == 0)
assert(not snapshot.interactiveJob)
action('attach', 'pick', { returnPanel = 'local/agent-chat:panel' })
action('visible', true)
captureDone(result({ path = '/private/image.png', name = 'image.png' })); tick()
assert(#states.codex.attachments == 1 and opens == 0, 'manual reopen permits same-chat attachment without stealing focus')
action('attach', 'pick', { returnPanel = 'local/agent-chat:fullscreen' })
local completed = captureDone
completed(result({ cancelled = true })); completed(result({ cancelled = true })); tick()
assert(opens == 1 and not snapshot.interactiveJob, 'cancellation restores the layout once')
assert(states.codex.attachmentNotice == 'File selection canceled.')
action('attach', 'pick', { returnPanel = 'local/agent-chat:panel' })
captureDone(result({ error = 'helper failed' })); tick()
assert(not snapshot.interactiveJob and states.codex.error == 'helper failed')
states.codex.session = 'old'
action('export', nil, { returnPanel = 'local/agent-chat:panel' })
action('backend', 'opencode')
exportDone({ { id = 'm', text = 'test', role = 'You' } }); tick()
assert(not states.codex.exporting and not snapshot.interactiveJob and saveDone == nil, 'obsolete export must not launch Save As')
states.opencode.requests = { { id = 'permission' } }
action('reply', 'once', { id = 'permission' }); action('reply', 'once', { id = 'permission' })
assert(replyCount == 1, 'an in-flight permission reply must not be submitted twice')
replyDone(false)
action('reply', 'once', { id = 'permission' }); assert(replyCount == 2, 'failed reply permits a new explicit user choice')
env.onIpc('diagnose')
local diagnostics = api.json.decode(files['/private/diagnostic.json'])
assert(diagnostics.opencode.error == nil and diagnostics.preferenceSchema == 1)
print('Service job ownership, stale navigation, error recovery, reply deduplication and private diagnostics: passed')

states.opencode.requests = {}
states.opencode.models = { { key = 'p/a', label = 'Alpha' } }
action('model', 'p/a')
assert(snapshot.modelChoices.recent[1] == 'p/a')
action('favorite_model', 'p/a')
assert(snapshot.modelChoices.favorites['p/a'])
states.opencode.busy = true
action('model', 'missing')
assert(states.opencode.model == 'p/a' and #snapshot.modelChoices.recent == 1)
states.opencode.busy = false
states.opencode.models = {}
action('favorite_model', 'p/a')
assert(not snapshot.modelChoices.favorites['p/a'])
action('model', 'missing')
assert(states.opencode.model == 'p/a', 'missing selection must never substitute a different model')

-- Boot independently for single/dual/no-backend setup and existing preferences.
for _, case in ipairs({
    { codex = 'missing', opencode = 'available', expected = 'opencode' },
    { codex = 'available', opencode = 'available', expected = 'opencode' },
    { codex = 'missing', opencode = 'missing', expected = 'opencode' },
    { codex = 'available', opencode = 'missing', expected = 'opencode', cancel = true },
    { codex = 'available', opencode = 'missing', expected = 'opencode', manual = true },
    { existing = true, expected = 'codex' },
}) do
    files = {}; cache = {}; runtimeDone = nil
    if case.existing then files['/private/preferences.json'] = api.json.encode({ backend = 'codex', selections = { codex = { model = 'keep' } } }) end
    assert(loadfile(root .. '/plugin/service.luau', 't', env))()
    if case.existing then
        assert(not snapshot.setup.active and not runtimeDone and states.codex.connected and states.codex.model == 'keep')
        action('setup_open')
        runtimeDone(result({ backends = { codex = { status = 'missing' }, opencode = { status = 'available' } }, tools = {} })); tick()
        assert(snapshot.backend == 'codex' and states.codex.model == 'keep', 'reviewing setup cannot substitute saved choices')
    else
        if case.cancel then action('setup_cancel') end
        if case.manual then action('backend', 'opencode') end
        runtimeDone(result({ backends = { codex = { status = case.codex }, opencode = { status = case.opencode } }, tools = {} })); tick()
        assert(snapshot.backend == case.expected)
        if not case.manual then assert(not states.codex.connected and not states.opencode.connected, 'discovery never connects') end
        assert(snapshot.setup.active == not case.cancel)
    end
end
print('Fresh single/dual/missing backend setup, cancellation and existing-install preservation: passed')
