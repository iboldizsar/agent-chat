local root = assert(arg[1])
local M = assert(loadfile(root .. '/plugin/lib/models.luau'))()
local prefs = {}
local m = { key = 'provider/a', label = 'Alpha', provider = 'Provider' }
M.toggle(prefs, 'opencode', m)
assert(prefs.modelChoices.opencode.favorites[m.key])
assert(not prefs.modelChoices.codex)
M.remember(prefs, 'opencode', m)
for i = 1, 7 do M.remember(prefs, 'opencode', { key = 'p/' .. i }) end
M.remember(prefs, 'opencode', { key = 'p/6' })
assert(#prefs.modelChoices.opencode.recent == 5 and prefs.modelChoices.opencode.recent[1] == 'p/6')
local groups = M.groups({}, prefs.modelChoices.opencode, '')
assert(groups[1].rows[1].available == false and groups[1].rows[1].label == 'Alpha')
groups = M.groups({ { key = m.key, label = 'Renamed', provider = 'Provider' } }, prefs.modelChoices.opencode, 'provider')
assert(groups[1].rows[1].available and groups[1].rows[1].label == 'Renamed')
M.toggle(prefs, 'opencode', m)
assert(not prefs.modelChoices.opencode.favorites[m.key])
print('Model favorites, backend isolation, bounded recents and unavailable discovery: passed')
