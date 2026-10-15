local root = assert(arg[1])
local Context = assert(loadfile(root .. '/plugin/lib/context.luau'))()
local now, callback, launched, exists = 0, nil, 0, false
local api = { nowMs = function() return now end, fileExists = function() return exists end,
    pluginDir = function() return '/plugin' end, json = { decode = function(v) return v end },
    runAsync = function(argv, cb) assert(argv[2] == '/plugin/helper/context.py'); launched = launched + 1; callback = cb; return true end }
local context = Context.new(api, '/assistant', function() end)
local outcomes = {}
context.ensure(function(ok) table.insert(outcomes, ok) end)
context.ensure(function(ok) table.insert(outcomes, ok) end)
assert(launched == 1)
callback({ stdout = { ready = true } })
assert(#outcomes == 2 and outcomes[1] and outcomes[2])
local old = callback
context.ensure(function(ok) table.insert(outcomes, ok) end)
now = 8001; context.tick()
assert(#outcomes == 3 and not outcomes[3])
old({ stdout = { ready = true } }); assert(#outcomes == 3)
exists = true
context.ensure(function(ok) assert(ok) end); assert(launched == 2)
exists = false
context.ensure(function() error('closed runtime callback') end)
context.close(); callback({ stdout = { ready = true } })
print('Context setup coalesces requests, bounds failures and ignores stale callbacks: passed')
