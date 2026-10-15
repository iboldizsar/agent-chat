local root = assert(arg[1])
local stream, async, callback, command = 0, 0, nil, nil
local now = 0
local env = setmetatable({ noctalia = {
    nowMs = function() return now end,
    pluginDir = function() return "/tmp/user's plugin" end,
    runStream = function(cmd, cb) stream = stream + 1; command = cmd; callback = cb; return true end,
    runAsync = function(argv, cb) async = async + 1; assert(argv[3] == "paste"); cb({ stdout = "clipboard" }); return true end,
} }, { __index = _G })
local runner = assert(loadfile(root .. "/plugin/lib/attachments.luau", "t", env))()
local results = {}
assert(runner.capture("pick", "/tmp/user's cache", function(r) table.insert(results, r.stdout) end))
assert(stream == 1 and async == 0 and #results == 0, "picker must wait without a captured-command deadline")
assert(command:find("interactive_job.py' python3 -u '/tmp/user'\\''s plugin/helper/attachments.py' 'pick' '--directory' '/tmp/user'\\''s cache'", 1, true), 'supervisor arguments must be quoted')
callback('{"cancelled":true}')
callback('{"cancelled":true}')
assert(#results == 1, "picker completion must restore chat only once")
runner.capture("paste", "/tmp/cache", function(r) table.insert(results, r.stdout) end)
assert(async == 1 and results[2] == "clipboard", "bounded clipboard operation can use runAsync")
print("Attachment picker uses streaming transport and quotes paths: passed")
local saved
assert(runner.saveExport('/tmp/source.md', "/tmp/user's export.md", function(r) saved = r.stdout end))
assert(command:find('export_file.py', 1, true) and command:find("'--suggested' '/tmp/user'\\''s export.md'", 1, true))
callback('{"cancelled":true}')
assert(saved == '{"cancelled":true}', 'Save As must use the same unbounded interactive transport')
print('Save As streaming and filename quoting: passed')

local lost
runner.capture('pick', '/tmp/cache', function(result) lost = result.stdout end)
now = 14000; callback('@agent-chat:alive'); runner.tick(); assert(not lost)
now = 28000; callback('@agent-chat:alive'); runner.tick(); assert(not lost, 'live dialogs must not have a total deadline')
now = 44001; runner.tick(); assert(lost and lost:find('stopped responding'))
local old = lost; callback('{"cancelled":true}'); assert(lost == old, 'late results after liveness failure must be ignored')
print('Interactive liveness and stale completion suppression: passed')
