local root = assert(arg[1])
local stream, async, callback, command = 0, 0, nil, nil
local env = setmetatable({ noctalia = {
    pluginDir = function() return "/tmp/user's plugin" end,
    runStream = function(cmd, cb) stream = stream + 1; command = cmd; callback = cb; return true end,
    runAsync = function(argv, cb) async = async + 1; assert(argv[3] == "paste"); cb({ stdout = "clipboard" }); return true end,
} }, { __index = _G })
local runner = assert(loadfile(root .. "/plugin/lib/attachments.luau", "t", env))()
local results = {}
assert(runner.capture("pick", "/tmp/user's cache", function(r) table.insert(results, r.stdout) end))
assert(stream == 1 and async == 0 and #results == 0, "picker must wait without a captured-command deadline")
assert(command == "exec python3 -u '/tmp/user'\\''s plugin/helper/attachments.py' 'pick' --directory '/tmp/user'\\''s cache'", "paths must be shell quoted")
callback('{"cancelled":true}')
callback('{"cancelled":true}')
assert(#results == 1, "picker completion must restore chat only once")
runner.capture("paste", "/tmp/cache", function(r) table.insert(results, r.stdout) end)
assert(async == 1 and results[2] == "clipboard", "bounded clipboard operation can use runAsync")
print("Attachment picker uses streaming transport and quotes paths: passed")
local saved
assert(runner.saveExport('/tmp/source.md', "/tmp/user's export.md", function(r) saved = r.stdout end))
assert(command:find('export_file.py', 1, true) and command:find("--suggested '/tmp/user'\\''s export.md'", 1, true))
callback('{"cancelled":true}')
assert(saved == '{"cancelled":true}', 'Save As must use the same unbounded interactive transport')
print('Save As streaming and filename quoting: passed')
