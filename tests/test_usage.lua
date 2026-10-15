local root = assert(arg[1])
local Usage = assert(loadfile(root .. '/plugin/lib/usage.luau'))()
local now = 1000
local value = { known = true, windows = { { usedPercent = 20 } }, checkedAt = now }
assert(Usage.status(value, now, true) == 'current')
assert(Usage.status(value, now + 301, true) == 'stale')
assert(Usage.status(value, now, false) == 'stale')
value.stale = true; assert(Usage.status(value, now, true) == 'stale')
value.stale = nil; value.checkedAt = nil; assert(Usage.status(value, now, true) == 'stale')
assert(Usage.status({}, now, true) == 'unavailable')
print('Usage freshness distinguishes unavailable, current and stale evidence: passed')
