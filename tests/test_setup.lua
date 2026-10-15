local root = assert(arg[1])
local Setup = assert(loadfile(root .. '/plugin/lib/setup.luau'))()
local now, callback, launches = 0, nil, 0
local value = { backends = { codex = { status = 'available' }, opencode = { status = 'missing' } }, tools = {} }
local api = { nowMs = function() return now end, pluginDir = function() return '/plugin' end,
    json = { decode = function() return value end },
    runAsync = function(argv, cb) assert(argv[2] == '/plugin/helper/runtime_check.py'); launches = launches + 1; callback = cb; return true end }
local setup = Setup.new(api, function() end)
local completed = 0
setup.check(function() completed = completed + 1 end); setup.check()
assert(launches == 1 and setup.state.checking)
local stale = callback
now = 8001; setup.tick()
assert(not setup.state.checking and setup.state.error)
setup.check(function() completed = completed + 1 end)
stale({ stdout = 'metadata' })
assert(setup.state.checking and completed == 0, 'late result must not replace the current check')
callback({ stdout = 'metadata', exitCode = 0 })
assert(not setup.state.checking and completed == 1 and setup.state.backends.codex.status == 'available')
callback({ stdout = 'metadata' }); assert(completed == 1)
value = { backends = { codex = {} }, tools = {} }
setup.check(); callback({ stdout = 'malformed' })
assert(setup.state.error and not next(setup.state.backends))
api.runAsync = function() return false end
setup.check(); assert(not setup.state.checking and setup.state.error)
print('Setup discovery serialization, timeout, stale callbacks and invalid results: passed')
