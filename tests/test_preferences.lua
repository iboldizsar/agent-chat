local root = assert(arg[1])
local M = assert(loadfile(root .. '/plugin/lib/preferences.luau'))()
local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}; for key, child in pairs(value) do result[key] = copy(child) end; return result
end
local function host(initial)
    local files, fixtures, serial = {}, {}, 0
    local api = { failWrite = false, failRename = false }
    api.json = {
        encode = function(value)
            serial = serial + 1; local key = 'json-' .. serial; fixtures[key] = copy(value); return key
        end,
        decode = function(raw) return copy(fixtures[raw]) end,
    }
    api.readFile = function(path) return files[path] end
    api.writeFile = function(path, raw)
        if api.failWrite then return false end
        files[path] = raw; return true
    end
    api.renameFile = function(from, to)
        if api.failRename then return false end
        files[to] = files[from]; files[from] = nil; return true
    end
    api.removeFile = function(path) files[path] = nil; return true end
    api.fileExists = function(path) return files[path] ~= nil end
    api.nowMs = function() return 123 end
    if initial ~= nil then files.prefs = type(initial) == 'string' and initial or api.json.encode(initial) end
    return api, files
end
local api, files = host({ backend = 'codex', selections = { codex = { model = 'm', session = 's', effort = 'high' } },
    drafts = { ['codex:s'] = 'private draft' }, pins = { codex = { s = { title = 'Pinned' } } },
    exportDir = '/my exports', future_field = { keep = true } })
local store = M.open(api, 'prefs')
assert(store.writable and store.value.schema_version == 1)
assert(store.value.drafts['codex:s'] == 'private draft' and store.value.pins.codex.s.title == 'Pinned')
assert(store.value.exportDir == '/my exports' and store.value.future_field.keep)
assert(store.save())
local reloaded = M.open(api, 'prefs')
assert(reloaded.value.selections.codex.effort == 'high' and reloaded.value.drafts['codex:s'] == 'private draft')

api, files = host('broken original')
store = M.open(api, 'prefs')
assert(not store.writable and store.canReset and files[store.backupPath] == 'broken original')
store.value.drafts.new = 'new unsaved draft'
assert(not store.save() and files.prefs == 'broken original', 'corrupt preferences must never be replaced implicitly')
assert(store.reset() and files[store.backupPath] == 'broken original')
assert(M.open(api, 'prefs').value.drafts.new == 'new unsaved draft', 'explicit recovery retains the current draft')

api, files = host({ schema_version = 99, drafts = { future = 'keep' } })
local original = files.prefs
store = M.open(api, 'prefs')
assert(not store.writable and not store.canReset and not store.reset() and not store.save())
assert(files.prefs == original, 'an older plugin must not downgrade newer preferences')

api, files = host({ drafts = { x = 'saved' } })
store = M.open(api, 'prefs'); original = files.prefs
store.value.drafts.x = 'new'
api.failRename = true
assert(not store.save() and files.prefs == original and files['prefs.writing'])
assert(not store.writable, 'failed rename preserves old and pending files without retry overwrites')
api.failRename = false
local restarted = M.open(api, 'prefs')
assert(restarted.value.drafts.x == 'saved' and not restarted.save())
assert(files['prefs.writing'], 'restart must preserve an interrupted write for recovery')
assert(restarted.canReset and restarted.reset())
assert(not files['prefs.writing'] and files[restarted.backupPath], 'explicit pending-file recovery must keep its private backup')


api, files = host({ drafts = { x = 123 } })
store = M.open(api, 'prefs')
assert(not store.writable and store.canReset, 'malformed nested preferences require explicit recovery')
api, files = host('unreadable'); api.readFile = function() error('read failed') end
store = M.open(api, 'prefs')
assert(not store.writable and not store.canReset and files.prefs == 'unreadable')
api, files = host('bad'); api.failWrite = true
store = M.open(api, 'prefs')
assert(not store.writable and not store.canReset, 'failed backup must not enable reset')
api, files = host(nil); store = M.open(api, 'prefs'); assert(store.writable)
api.failWrite = true; assert(not store.save() and files.prefs == nil)
api.failWrite = false; assert(store.save(), 'a write that failed without touching a file may be retried')
print('Preferences migration, recovery, atomic failure and forward-version protection: passed')
