-- Backend-scoped model decorations; discovery remains authoritative.
local M = {}
function M.find(models, key)
    for _, model in ipairs(models or {}) do if model.key == key then return model end end
end
function M.remember(prefs, backend, model)
    prefs.modelChoices = prefs.modelChoices or {}
    local choices = prefs.modelChoices[backend] or { favorites = {}, recent = {} }
    prefs.modelChoices[backend] = choices
    local recent = { model.key }
    for _, key in ipairs(choices.recent) do
        if key ~= model.key and #recent < 5 then table.insert(recent, key) end
    end
    choices.recent = recent
end
function M.toggle(prefs, backend, model)
    prefs.modelChoices = prefs.modelChoices or {}
    local choices = prefs.modelChoices[backend] or { favorites = {}, recent = {} }
    prefs.modelChoices[backend] = choices
    if choices.favorites[model.key] then choices.favorites[model.key] = nil
    else choices.favorites[model.key] = { label = model.label } end
end
function M.groups(models, choices, query)
    choices = choices or {}; query = (query or ""):lower()
    local groups = { { title = "Favorites", rows = {} }, { title = "Recently used", rows = {} }, { title = "All models", rows = {} } }
    local favorites, seen = choices.favorites or {}, {}
    local function add(group, model, available)
        local text = model.label .. " " .. model.key .. " " .. (model.provider or "")
        if query == "" or text:lower():find(query, 1, true) then
            table.insert(group.rows, { key = model.key, label = model.label, available = available, favorite = favorites[model.key] ~= nil })
        end
    end
    local keys = {}; for key in pairs(favorites) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local model = M.find(models, key)
        add(groups[1], model or { key = key, label = favorites[key].label }, model ~= nil); seen[key] = true
    end
    for _, key in ipairs(choices.recent or {}) do
        local model = M.find(models, key)
        if model and not seen[key] then add(groups[2], model, true); seen[key] = true end
    end
    for _, model in ipairs(models or {}) do if not seen[model.key] then add(groups[3], model, true) end end
    return groups
end
return M
