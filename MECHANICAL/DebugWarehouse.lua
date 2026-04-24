local HDEV_WarehouseSingleExport = {
    DEBUG = true,
    SCREEN_TIME = 12,

    -- Aqui pones el nombre exacto o parcial del aeropuerto/carrier
    TARGET_NAME = "Beatty",

    -- Delay para dar tiempo a que todo exista en runtime
    RUN_DELAY = 10,

    -- Carpeta / archivo de salida
    OUTPUT_PATH = lfs.writedir() .. "Config\\HorizontDev\\Exports\\WarehouseExport_Marshall.json"
}

local function log(msg)
    env.info("[WH_EXPORT_ONE] " .. tostring(msg))
    if HDEV_WarehouseSingleExport.DEBUG then
        trigger.action.outText("[WH_EXPORT_ONE] " .. tostring(msg), HDEV_WarehouseSingleExport.SCREEN_TIME)
    end
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function contains(a, b)
    a = lower(a)
    b = lower(b)
    if a == "" or b == "" then
        return false
    end
    return string.find(a, b, 1, true) ~= nil
end

local function ensureDirectoryForFile(path)
    if not lfs or not lfs.mkdir or not path or path == "" then
        return false
    end

    local separator = path:find("/") and "/" or "\\"
    local parts = {}

    for part in string.gmatch(path, "[^\\/]+") do
        parts[#parts + 1] = part
    end

    if #parts <= 1 then
        return false
    end

    table.remove(parts, #parts)

    local prefix = ""
    if path:match("^%a:[\\/]") then
        prefix = path:sub(1, 3)
    elseif path:sub(1, 1) == "/" then
        prefix = "/"
    end

    local current = prefix
    for _, part in ipairs(parts) do
        if current == "" or current:sub(-1) == separator then
            current = current .. part
        else
            current = current .. separator .. part
        end
        lfs.mkdir(current)
    end

    return true
end

local function safeWriteFile(path, txt)
    ensureDirectoryForFile(path)
    local f = io.open(path, "w")
    if not f then
        return false
    end
    f:write(txt or "")
    if f.flush then
        f:flush()
    end
    f:close()
    return true
end

local function jsonEscape(str)
    str = tostring(str or "")
    str = str:gsub("\\", "\\\\")
    str = str:gsub("\"", "\\\"")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\t", "\\t")
    return str
end

local function jsonPrimitive(v)
    local tv = type(v)

    if tv == "string" then
        return "\"" .. jsonEscape(v) .. "\""
    elseif tv == "number" then
        return tostring(v)
    elseif tv == "boolean" then
        return v and "true" or "false"
    elseif tv == "nil" then
        return "null"
    else
        return "\"" .. jsonEscape(tostring(v)) .. "\""
    end
end

local function sortedKeysAlpha(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys, function(a, b)
        return a < b
    end)
    return keys
end

local function writeFlatObject(lines, indent, tbl, orderedKeys)
    tbl = tbl or {}
    local done = {}
    local entries = {}

    if orderedKeys then
        for _, key in ipairs(orderedKeys) do
            if tbl[key] ~= nil then
                entries[#entries + 1] = {
                    key = key,
                    value = tbl[key]
                }
                done[key] = true
            end
        end
    end

    for _, key in ipairs(sortedKeysAlpha(tbl)) do
        if not done[key] then
            entries[#entries + 1] = {
                key = key,
                value = tbl[key]
            }
        end
    end

    lines[#lines + 1] = indent .. "{"
    for i, entry in ipairs(entries) do
        local comma = (i < #entries) and "," or ""
        lines[#lines + 1] = indent .. "  " .. "\"" .. jsonEscape(entry.key) .. "\": " .. jsonPrimitive(entry.value) .. comma
    end
    lines[#lines + 1] = indent .. "}"
end

local function writeInventoryMap(lines, indent, tbl)
    tbl = tbl or {}
    local keys = sortedKeysAlpha(tbl)

    lines[#lines + 1] = indent .. "{"
    for i, key in ipairs(keys) do
        local comma = (i < #keys) and "," or ""
        lines[#lines + 1] = indent .. "  " .. "\"" .. jsonEscape(key) .. "\": " .. tostring(tonumber(tbl[key]) or 0) .. comma
    end
    lines[#lines + 1] = indent .. "}"
end

local function copyFlatMap(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end

    for k, v in pairs(src) do
        out[tostring(k)] = tonumber(v) or 0
    end

    return out
end

local LIQUID_ID_TO_NAME = {
    [0] = "jet_fuel",
    [1] = "gasoline",
    [2] = "methanol_mixture",
    [3] = "diesel",
}

local function getLiquidSnapshot(wh, inv)
    local liquids = {}

    for i = 0, 3 do
        local lname = LIQUID_ID_TO_NAME[i]
        local amount = 0

        local ok, val = pcall(function()
            return wh:getLiquidAmount(i)
        end)

        if ok and type(val) == "number" then
            amount = val
        elseif inv and inv.liquids then
            amount = inv.liquids[i] or inv.liquids[tostring(i)] or 0
        end

        liquids[lname] = tonumber(amount) or 0
    end

    return liquids
end

local function getCategoryName(ab)
    local categoryName = "unknown"

    local okDesc, desc = pcall(function()
        return Airbase.getDesc(ab)
    end)

    if okDesc and desc and desc.category ~= nil then
        local cat = tonumber(desc.category) or -1
        if cat == 0 then
            categoryName = "airbase"
        else
            categoryName = "units"
        end
    end

    return categoryName
end

local function buildSnapshot(ab)
    if not ab then
        return nil, "airbase nil"
    end

    local okWh, wh = pcall(function()
        return ab:getWarehouse()
    end)
    if not okWh or not wh then
        return nil, "getWarehouse no disponible"
    end

    local okInv, inv = pcall(function()
        return wh:getInventory()
    end)
    if not okInv or type(inv) ~= "table" then
        inv = {}
    end

    local id = nil
    local okId, runtimeId = pcall(function()
        return ab:getID()
    end)
    if okId then
        id = runtimeId
    end

    local name = "SIN_NOMBRE"
    local okName, runtimeName = pcall(function()
        return ab:getName()
    end)
    if okName and runtimeName then
        name = runtimeName
    end

    local snap = {
        id = id,
        name = name,
        missionTime = timer.getTime(),
        categoryName = getCategoryName(ab),
        liquids = getLiquidSnapshot(wh, inv),
        aircraft = copyFlatMap(inv.aircraft),
        weapon = copyFlatMap(inv.weapon)
    }

    return snap, nil
end

local function findTargetAirbase(targetName)
    if not targetName or targetName == "" then
        return nil, "TARGET_NAME vacío", "none"
    end

    local okExact, exact = pcall(function()
        return Airbase.getByName(targetName)
    end)

    if okExact and exact then
        return exact, nil, "exact"
    end

    local all = world.getAirbases() or {}
    for _, ab in ipairs(all) do
        local okName, abName = pcall(function()
            return ab:getName()
        end)

        if okName and abName and contains(abName, targetName) then
            return ab, nil, "partial"
        end
    end

    return nil, "No se encontró ninguna airbase/warehouse con ese nombre", "none"
end

local function writeEntry(lines, indent, entry)
    lines[#lines + 1] = indent .. "{"
    lines[#lines + 1] = indent .. "  \"id\": " .. jsonPrimitive(entry.id) .. ","
    lines[#lines + 1] = indent .. "  \"name\": " .. jsonPrimitive(entry.name) .. ","
    lines[#lines + 1] = indent .. "  \"missionTime\": " .. jsonPrimitive(entry.missionTime) .. ","
    lines[#lines + 1] = indent .. "  \"categoryName\": " .. jsonPrimitive(entry.categoryName) .. ","

    lines[#lines + 1] = indent .. "  \"liquids\": {"
    local liquidOrder = { "jet_fuel", "gasoline", "methanol_mixture", "diesel" }
    for i, lname in ipairs(liquidOrder) do
        local comma = (i < #liquidOrder) and "," or ""
        local amount = 0
        if entry.liquids and entry.liquids[lname] ~= nil then
            amount = tonumber(entry.liquids[lname]) or 0
        end
        lines[#lines + 1] = indent .. "    \"" .. lname .. "\": " .. tostring(amount) .. comma
    end
    lines[#lines + 1] = indent .. "  },"

    lines[#lines + 1] = indent .. "  \"aircraft\":"
    writeInventoryMap(lines, indent .. "  ", entry.aircraft or {})
    lines[#lines] = lines[#lines] .. ","

    lines[#lines + 1] = indent .. "  \"weapon\":"
    writeInventoryMap(lines, indent .. "  ", entry.weapon or {})

    lines[#lines + 1] = indent .. "}"
end

local function buildPrettyJson(doc)
    local lines = {}

    lines[#lines + 1] = "{"

    lines[#lines + 1] = "  \"meta\":"
    writeFlatObject(lines, "  ", doc.meta or {}, {
        "mode",
        "missionTime",
        "source",
        "theatre",
        "targetQuery",
        "resolvedBy",
        "resolvedName",
        "resolvedId",
        "note"
    })
    lines[#lines] = lines[#lines] .. ","

    lines[#lines + 1] = "  \"" .. tostring(doc.sectionName or "airports") .. "\": {"
    lines[#lines + 1] = "    \"" .. tostring(doc.entryId) .. "\":"
    writeEntry(lines, "    ", doc.entry or {})
    lines[#lines + 1] = "  }"

    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

local function runExport()
    if not Airbase or not Airbase.getWarehouse then
        log("Airbase.getWarehouse no disponible. Requiere Warehouse API.")
        return
    end

    if not io or not lfs then
        log("io/lfs no disponibles. Revisa MissionScripting.lua.")
        return
    end

    local ab, err, resolvedBy = findTargetAirbase(HDEV_WarehouseSingleExport.TARGET_NAME)
    if not ab then
        log(err or "No se pudo resolver el target")
        return
    end

    local snap, snapErr = buildSnapshot(ab)
    if not snap then
        log("No se pudo crear snapshot: " .. tostring(snapErr))
        return
    end

    local sectionName = "airports"
    if snap.categoryName == "units" then
        sectionName = "warehouses"
    end

    local theatre = "unknown"
    if env and env.mission and env.mission.theatre then
        theatre = tostring(env.mission.theatre)
    end

    local doc = {
        meta = {
            mode = "single_export",
            missionTime = timer.getTime(),
            source = "DCS Warehouse runtime",
            theatre = theatre,
            targetQuery = HDEV_WarehouseSingleExport.TARGET_NAME,
            resolvedBy = resolvedBy or "unknown",
            resolvedName = snap.name,
            resolvedId = snap.id,
            note = "Export simple de una sola ubicacion. Incluye lo que la Warehouse API expone aqui: id, name, missionTime, categoryName, liquids, aircraft y weapon."
        },
        sectionName = sectionName,
        entryId = tostring(snap.id or snap.name or "target"),
        entry = snap
    }

    local json = buildPrettyJson(doc)
    local ok = safeWriteFile(HDEV_WarehouseSingleExport.OUTPUT_PATH, json)

    if ok then
        log("JSON exportado correctamente: " .. tostring(HDEV_WarehouseSingleExport.OUTPUT_PATH))
    else
        log("No se pudo escribir el archivo JSON")
    end
end

timer.scheduleFunction(function()
    runExport()
    return nil
end, nil, timer.getTime() + (HDEV_WarehouseSingleExport.RUN_DELAY or 10))