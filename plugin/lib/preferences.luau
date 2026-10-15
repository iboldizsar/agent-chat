-- Preferences are metadata/drafts only. Never silently replace unreadable saved state.
local M = {}
M.schemaVersion = 1
local function defaults()
    return { schema_version = M.schemaVersion, backend = "opencode", selections = {}, drafts = {}, pins = {} }
end
local function valid(value)
    if type(value) ~= "table" then return false end
    if value.backend ~= nil and value.backend ~= "opencode" and value.backend ~= "codex" then return false end
    for _, key in ipairs({ "selections", "drafts", "pins" }) do
        if value[key] ~= nil and type(value[key]) ~= "table" then return false end
    end
    for id, draft in pairs(value.drafts or {}) do
        if type(id) ~= "string" or type(draft) ~= "string" then return false end
    end
    for name, selection in pairs(value.selections or {}) do
        if type(name) ~= "string" or type(selection) ~= "table" then return false end
        for _, key in ipairs({ "model", "session", "effort", "agent" }) do
            if selection[key] ~= nil and type(selection[key]) ~= "string" then return false end
        end
    end
    for name, pins in pairs(value.pins or {}) do
        if type(name) ~= "string" or type(pins) ~= "table" then return false end
        for id, pin in pairs(pins) do
            if type(id) ~= "string" or type(pin) ~= "table" or type(pin.title) ~= "string" then return false end
        end
    end
    return value.exportDir == nil or type(value.exportDir) == "string"
end
function M.open(api, path)
    local store = { value = defaults(), warning = nil, writable = true, canReset = false }
    local lastSaved = nil
    local function preserve(raw)
        if type(raw) ~= "string" then return false end
        local backup = path .. ".recovery-" .. tostring(api.nowMs())
        local suffix = 0
        while api.fileExists(backup) do
            suffix = suffix + 1; backup = path .. ".recovery-" .. tostring(api.nowMs()) .. "-" .. tostring(suffix)
        end
        local ok, saved = pcall(api.writeFile, backup, raw)
        if ok and saved then store.backupPath = backup; return true end
        return false
    end
    if api.fileExists(path) then
        local readOK, raw = pcall(api.readFile, path)
        local decodedOK, decoded = false, nil
        if readOK and type(raw) == "string" then decodedOK, decoded = pcall(api.json.decode, raw) end
        local schema = type(decoded) == "table" and decoded.schema_version or nil
        if decodedOK and type(schema) == "number" and schema > M.schemaVersion then
            store.writable = false
            store.warning = "Saved preferences belong to a newer version. Use that version to keep saving changes."
        elseif not decodedOK or not valid(decoded) or (schema ~= nil and schema ~= 0 and schema ~= M.schemaVersion) then
            store.writable = false
            store.canReset = preserve(readOK and raw or nil)
            store.warning = store.canReset and
                "Saved preferences could not be loaded. A recovery copy was preserved; changes are not being saved." or
                "Saved preferences could not be read or backed up. The original is untouched; changes are not being saved."
        else
            store.value = decoded
            store.value.schema_version = M.schemaVersion
            store.value.backend = decoded.backend or "opencode"
            store.value.selections = decoded.selections or {}
            store.value.drafts = decoded.drafts or {}
            store.value.pins = decoded.pins or {}
        end
    end
    function store.save()
        if not store.writable then return false end
        local encodedOK, encoded = pcall(api.json.encode, store.value)
        if not encodedOK or type(encoded) ~= "string" then
            store.warning = "Could not encode preferences. Previous saved state is unchanged."
            return false
        end
        if encoded == lastSaved then return true end
        local temporary = path .. ".writing"
        if api.fileExists(temporary) then
            -- A failed/interrupted write may hold the newest unsaved draft.
            store.writable = false
            store.warning = "An unfinished preferences write was found. Saved files were preserved; recovery is needed before saving."
            return false
        end
        local writeOK, written = pcall(api.writeFile, temporary, encoded)
        if not writeOK or not written then
            store.warning = "Could not save preferences. Previous saved state is unchanged."
            return false
        end
        local renameOK, renamed = pcall(api.renameFile, temporary, path)
        if not renameOK or not renamed then
            store.writable = false
            store.warning = "Could not finish saving preferences. Both the previous and pending files were preserved."
            return false
        end
        lastSaved = encoded; store.warning = nil
        return true
    end
    function store.reset()
        if not store.canReset then return false end
        store.writable = true; store.canReset = false; store.warning = nil
        return store.save()
    end
    return store
end
return M
