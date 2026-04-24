local WHSYNC = {
    DEBUG = false,

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\SINAI\\SistemWarehousePersistanceSinai.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 60,

    EXACT_SYNC = true,
    TRACK_ONLY_JSON_IDS = true,

    -- Aqui agregas nombres alternos por ID del JSON
    NAME_ALIASES = {
        [266] = { "Marshall" },
        [269] = { "Tarawa" },
        -- ejemplo futuro:
        -- [300] = { "Tarawa", "LHA_Tarawa", "USS Tarawa", "Naval-2-1" },
    },
}

local WHSTATE = {
    started = false,
    injecting = false,
    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,
    airbasesById = {},
    trackedIds = nil,
    idToSection = {},
    trackedEntries = {},
    sectionOrder = { "airports", "warehouses", "carriers", "farps", "helipads", "other" },
}

local LIQUID_NAME_TO_ID = {
    jet_fuel = 0,
    gasoline = 1,
    methanol_mixture = 2,
    diesel = 3,
}

local LIQUID_ID_TO_NAME = {
    [0] = "jet_fuel",
    [1] = "gasoline",
    [2] = "methanol_mixture",
    [3] = "diesel",
}

local function log(msg)
    env.info("[WHSYNC-SINAI-V03] " .. tostring(msg))
    if WHSYNC.DEBUG then
        trigger.action.outText("[WHSYNC-SINAI-V03] " .. tostring(msg), 8)
    end
end

local function safeReadFile(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local txt = f:read("*a")
    f:close()
    return txt
end

local function safeWriteFile(path, txt)
    local f = io.open(path, "w")
    if not f then
        return false
    end
    f:write(txt or "")
    f:close()
    return true
end

local function decodeJson(txt)
    if not txt or txt == "" then
        return nil, "archivo vacío"
    end

    if not net or not net.json2lua then
        return nil, "net.json2lua no disponible"
    end

    local ok, data = pcall(net.json2lua, txt)
    if not ok then
        return nil, data
    end

    if type(data) ~= "table" then
        return nil, "json no devolvió tabla"
    end

    return data
end

local function loadSyncFile()
    local txt = safeReadFile(WHSYNC.FILE_PATH)
    if not txt then
        return nil, "no existe archivo"
    end
    return decodeJson(txt)
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

local function sortedKeysNumericString(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do
        keys[#keys + 1] = tostring(k)
    end
    table.sort(keys, function(a, b)
        local na = tonumber(a)
        local nb = tonumber(b)
        if na and nb then
            return na < nb
        end
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

local function writeWeaponByWsType(lines, indent, list)
    list = list or {}
    lines[#lines + 1] = indent .. "["
    for i, item in ipairs(list) do
        local comma = (i < #list) and "," or ""
        local ws = item.wsType or {}

        local v1 = ws[1] ~= nil and tostring(ws[1]) or "null"
        local v2 = ws[2] ~= nil and tostring(ws[2]) or "null"
        local v3 = ws[3] ~= nil and tostring(ws[3]) or "null"
        local v4 = ws[4] ~= nil and tostring(ws[4]) or "null"

        lines[#lines + 1] = indent .. "  {"
        lines[#lines + 1] = indent .. "    \"amount\": " .. tostring(tonumber(item.amount) or 0) .. ","
        lines[#lines + 1] = indent .. "    \"wsType\": [" .. v1 .. ", " .. v2 .. ", " .. v3 .. ", " .. v4 .. "]"
        lines[#lines + 1] = indent .. "  }" .. comma
    end
    lines[#lines + 1] = indent .. "]"
end

local function writeEntry(lines, indent, entry)
    lines[#lines + 1] = indent .. "{"
    lines[#lines + 1] = indent .. "  \"id\": " .. jsonPrimitive(entry.id) .. ","
    lines[#lines + 1] = indent .. "  \"name\": " .. jsonPrimitive(entry.name) .. ","
    lines[#lines + 1] = indent .. "  \"missionTime\": " .. jsonPrimitive(entry.missionTime) .. ","

    if entry.categoryName ~= nil then
        lines[#lines + 1] = indent .. "  \"categoryName\": " .. jsonPrimitive(entry.categoryName) .. ","
    end

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

    local needCommaAfterAircraft = false
    if entry.weapon or entry.weaponByWsType or entry.settings then
        needCommaAfterAircraft = true
    end
    if needCommaAfterAircraft then
        lines[#lines] = lines[#lines] .. ","
    end

    if entry.weapon then
        lines[#lines + 1] = indent .. "  \"weapon\":"
        writeInventoryMap(lines, indent .. "  ", entry.weapon or {})
        if entry.weaponByWsType or entry.settings then
            lines[#lines] = lines[#lines] .. ","
        end
    end

    if entry.weaponByWsType then
        lines[#lines + 1] = indent .. "  \"weaponByWsType\":"
        writeWeaponByWsType(lines, indent .. "  ", entry.weaponByWsType or {})
        if entry.settings then
            lines[#lines] = lines[#lines] .. ","
        end
    end

    if entry.settings then
        lines[#lines + 1] = indent .. "  \"settings\":"
        writeFlatObject(lines, indent .. "  ", entry.settings, {
            "unlimitedAircrafts",
            "unlimitedMunitions",
            "unlimitedFuel",
            "dynamicCargo",
            "dynamicSpawn",
            "allowHotStart",
            "coalition"
        })
    end

    lines[#lines + 1] = indent .. "}"
end

local function buildPrettyWarehouseJson(doc)
    local lines = {}

    lines[#lines + 1] = "{"

    lines[#lines + 1] = "  \"control\":"
    writeFlatObject(lines, "  ", doc.control or {}, {
        "injectDuration",
        "injectInterval",
        "exportInterval",
        "exactSync"
    })
    lines[#lines] = lines[#lines] .. ","

    lines[#lines + 1] = "  \"meta\":"
    writeFlatObject(lines, "  ", doc.meta or {}, {
        "mode",
        "missionTime",
        "injectDuration",
        "exportInterval",
        "source",
        "note",
        "theatre"
    })

    local wroteSection = false

    for _, section in ipairs(WHSTATE.sectionOrder) do
        if doc[section] and next(doc[section]) ~= nil then
            lines[#lines] = lines[#lines] .. ","
            lines[#lines + 1] = "  \"" .. section .. "\": {"

            local ids = sortedKeysNumericString(doc[section])
            for i, idStr in ipairs(ids) do
                local comma = (i < #ids) and "," or ""
                lines[#lines + 1] = "    \"" .. idStr .. "\":"
                writeEntry(lines, "    ", doc[section][idStr])
                lines[#lines] = lines[#lines] .. comma
            end

            lines[#lines + 1] = "  }"
            wroteSection = true
        end
    end

    if not wroteSection then
        lines[#lines] = lines[#lines] .. ","
        lines[#lines + 1] = "  \"airports\": {}"
    end

    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

local function saveSyncFile(tbl)
    local json = buildPrettyWarehouseJson(tbl)
    if not json or json == "" then
        log("No se pudo construir JSON bonito.")
        return false
    end

    if not safeWriteFile(WHSYNC.FILE_PATH, json) then
        log("No se pudo escribir el archivo: " .. WHSYNC.FILE_PATH)
        return false
    end

    return true
end

local function registerSectionIds(doc)
    WHSTATE.trackedIds = nil
    WHSTATE.idToSection = {}
    WHSTATE.trackedEntries = {}

    local any = false

    for _, section in ipairs(WHSTATE.sectionOrder) do
        if type(doc[section]) == "table" then
            for idStr, data in pairs(doc[section]) do
                local id = tonumber(idStr)
                if not id and type(data) == "table" then
                    id = tonumber(data.id)
                end

                if id then
                    WHSTATE.trackedIds = WHSTATE.trackedIds or {}
                    WHSTATE.trackedIds[id] = true
                    WHSTATE.idToSection[id] = section
                    WHSTATE.trackedEntries[id] = {
                        id = id,
                        section = section,
                        name = type(data) == "table" and data.name or nil,
                        categoryName = type(data) == "table" and data.categoryName or nil
                    }
                    any = true
                end
            end
        end
    end

    if not any then
        WHSTATE.trackedIds = nil
    end
end

local function shouldTrackAirbase(id)
    if not WHSYNC.TRACK_ONLY_JSON_IDS or WHSTATE.trackedIds == nil then
        return true
    end
    return WHSTATE.trackedIds[id] == true
end

local function tryGetAirbaseByName(name)
    if not name or name == "" then
        return nil
    end

    local ok, ab = pcall(function()
        return Airbase.getByName(name)
    end)

    if ok and ab and ab.getWarehouse then
        return ab
    end

    return nil
end

local function rebuildAirbaseIndex()
    local current = {}

    local allAirbases = world.getAirbases() or {}
    for _, ab in ipairs(allAirbases) do
        if ab and ab.getID and ab.getWarehouse then
            local runtimeId = ab:getID()
            if runtimeId and shouldTrackAirbase(runtimeId) then
                current[runtimeId] = ab
            end
        end
    end

    if WHSTATE.trackedEntries then
        for id, entry in pairs(WHSTATE.trackedEntries) do
            if not current[id] then
                local found = nil

                if entry.name and entry.name ~= "" then
                    found = tryGetAirbaseByName(entry.name)
                    if found then
                        current[id] = found
                        log("Fallback por nombre OK para ID " .. tostring(id) .. " -> " .. tostring(entry.name))
                    end
                end

                if not found and WHSYNC.NAME_ALIASES and WHSYNC.NAME_ALIASES[id] then
                    for _, aliasName in ipairs(WHSYNC.NAME_ALIASES[id]) do
                        found = tryGetAirbaseByName(aliasName)
                        if found then
                            current[id] = found
                            log("Fallback por alias OK para ID " .. tostring(id) .. " -> " .. tostring(aliasName))
                            break
                        end
                    end
                end
            end
        end
    end

    WHSTATE.airbasesById = current
end

local function refreshTrackedAirbases()
    if not WHSTATE.trackedEntries then
        return
    end

    local changed = false

    for id, entry in pairs(WHSTATE.trackedEntries) do
        if not WHSTATE.airbasesById[id] then
            local found = nil

            if entry.name and entry.name ~= "" then
                found = tryGetAirbaseByName(entry.name)
            end

            if not found and WHSYNC.NAME_ALIASES and WHSYNC.NAME_ALIASES[id] then
                for _, aliasName in ipairs(WHSYNC.NAME_ALIASES[id]) do
                    found = tryGetAirbaseByName(aliasName)
                    if found then
                        break
                    end
                end
            end

            if found then
                WHSTATE.airbasesById[id] = found
                changed = true
                log("Reconocimiento tardío OK para ID " .. tostring(id) .. " -> " .. tostring(found:getName()))
            end
        end
    end

    return changed
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

local function snapshotAirbase(id, ab)
    if not ab then
        return nil
    end

    local okWh, wh = pcall(function()
        return ab:getWarehouse()
    end)
    if not okWh or not wh then
        return nil
    end

    local okInv, inv = pcall(function()
        return wh:getInventory()
    end)
    if not okInv or type(inv) ~= "table" then
        inv = {}
    end

    local tracked = WHSTATE.trackedEntries and WHSTATE.trackedEntries[id] or nil

    local snap = {
        id = id,
        name = (tracked and tracked.name) or ab:getName(),
        missionTime = timer.getTime(),
        categoryName = (tracked and tracked.categoryName) or "unknown",
        aircraft = copyFlatMap(inv.aircraft),
        weapon = copyFlatMap(inv.weapon),
        liquids = getLiquidSnapshot(wh, inv),
    }

    if not tracked then
        local okDesc, desc = pcall(function()
            return Airbase.getDesc(ab)
        end)

        if okDesc and desc and desc.category ~= nil then
            local cat = tonumber(desc.category) or -1
            if cat == 0 then
                snap.categoryName = "airbase"
            else
                snap.categoryName = "units"
            end
        end
    end

    return snap
end

local function zeroAllItems(wh, currentMap)
    if not WHSYNC.EXACT_SYNC then
        return
    end
    if type(currentMap) ~= "table" then
        return
    end

    for itemName, _ in pairs(currentMap) do
        pcall(function()
            wh:setItem(itemName, 0)
        end)
    end
end

local function setMissingItemsToZero(wh, currentMap, desiredMap)
    if not WHSYNC.EXACT_SYNC then
        return
    end
    if type(currentMap) ~= "table" then
        return
    end
    if type(desiredMap) ~= "table" then
        desiredMap = {}
    end

    for itemName, _ in pairs(currentMap) do
        if desiredMap[itemName] == nil then
            pcall(function()
                wh:setItem(itemName, 0)
            end)
        end
    end
end

local function applyItemMap(wh, desiredMap)
    if type(desiredMap) ~= "table" then
        return
    end

    for itemName, count in pairs(desiredMap) do
        local n = tonumber(count) or 0
        pcall(function()
            wh:setItem(itemName, n)
        end)
    end
end

local function applyWeaponWsTypeList(wh, weaponList)
    if type(weaponList) ~= "table" then
        return
    end

    for _, entry in ipairs(weaponList) do
        if type(entry) == "table" and type(entry.wsType) == "table" then
            local n = tonumber(entry.amount) or tonumber(entry.initialAmount) or 0
            pcall(function()
                wh:setItem(entry.wsType, n)
            end)
        end
    end
end

local function applyLiquidMap(wh, desiredLiquids)
    if type(desiredLiquids) ~= "table" then
        return
    end

    for liquidName, count in pairs(desiredLiquids) do
        local liquidId = LIQUID_NAME_TO_ID[liquidName]
        if liquidId ~= nil then
            local n = tonumber(count) or 0
            pcall(function()
                wh:setLiquidAmount(liquidId, n)
            end)
        end
    end
end

local function applyLocationData(ab, data)
    if not ab or type(data) ~= "table" then
        return
    end

    local okWh, wh = pcall(function()
        return ab:getWarehouse()
    end)
    if not okWh or not wh then
        return
    end

    local okInv, current = pcall(function()
        return wh:getInventory()
    end)
    if not okInv or type(current) ~= "table" then
        current = {}
    end

    if data.aircraft then
        setMissingItemsToZero(wh, current.aircraft or {}, data.aircraft)
        applyItemMap(wh, data.aircraft)
    end

    if data.weapon then
        setMissingItemsToZero(wh, current.weapon or {}, data.weapon)
        applyItemMap(wh, data.weapon)
    elseif data.weaponByWsType then
        zeroAllItems(wh, current.weapon or {})
        applyWeaponWsTypeList(wh, data.weaponByWsType)
    end

    if data.liquids then
        applyLiquidMap(wh, data.liquids)
    end
end

local function readControlOverrides(doc)
    if type(doc) ~= "table" or type(doc.control) ~= "table" then
        return
    end

    local c = doc.control

    if tonumber(c.injectDuration) then
        WHSYNC.INJECT_DURATION = tonumber(c.injectDuration)
    end
    if tonumber(c.injectInterval) then
        WHSYNC.INJECT_INTERVAL = tonumber(c.injectInterval)
    end
    if tonumber(c.exportInterval) then
        WHSYNC.EXPORT_INTERVAL = tonumber(c.exportInterval)
    end
    if type(c.exactSync) == "boolean" then
        WHSYNC.EXACT_SYNC = c.exactSync
    end
end

local function forEachJsonEntry(doc, fn)
    for _, section in ipairs(WHSTATE.sectionOrder) do
        local block = doc[section]
        if type(block) == "table" then
            for idStr, data in pairs(block) do
                local id = tonumber(idStr)
                if not id and type(data) == "table" then
                    id = tonumber(data.id)
                end

                if id then
                    fn(section, id, data)
                end
            end
        end
    end
end

local function injectFromJson()
    local doc, err = loadSyncFile()
    if not doc then
        log("No se pudo leer JSON para inyectar: " .. tostring(err))
        return
    end

    readControlOverrides(doc)

    forEachJsonEntry(doc, function(section, id, data)
        local ab = WHSTATE.airbasesById[id]
        if ab then
            applyLocationData(ab, data)
        end
    end)
end

local function getSectionForExport(id, snap)
    if WHSTATE.idToSection[id] then
        return WHSTATE.idToSection[id]
    end

    if snap and snap.categoryName == "units" then
        return "warehouses"
    end

    return "airports"
end

local function exportLiveToJson()
    local previous = {}
    local doc = {}

    local prev, _ = loadSyncFile()
    if type(prev) == "table" then
        previous = prev
    end

    doc.control = previous.control or {}
    doc.meta = previous.meta or {}

    for _, section in ipairs(WHSTATE.sectionOrder) do
        doc[section] = {}
    end

    doc.meta.mode = WHSTATE.injecting and "inject" or "live"
    doc.meta.missionTime = timer.getTime()
    doc.meta.injectDuration = WHSYNC.INJECT_DURATION
    doc.meta.exportInterval = WHSYNC.EXPORT_INTERVAL
    doc.meta.source = "DCS Warehouse runtime"
    doc.meta.theatre = "Sinai"

    for _, section in ipairs(WHSTATE.sectionOrder) do
        if type(previous[section]) == "table" then
            for idStr, oldEntry in pairs(previous[section]) do
                doc[section][idStr] = oldEntry
            end
        end
    end

    for id, ab in pairs(WHSTATE.airbasesById) do
        local snap = snapshotAirbase(id, ab)
        if snap then
            local section = WHSTATE.idToSection[id] or getSectionForExport(id, snap)
            doc[section][tostring(id)] = snap

            local prevEntry = previous[section] and previous[section][tostring(id)]
            if prevEntry and prevEntry.settings then
                doc[section][tostring(id)].settings = prevEntry.settings
            end
        end
    end

    if saveSyncFile(doc) then
        if WHSYNC.DEBUG then
            log("JSON actualizado desde DCS")
        end
    end
end

local function startupProbe()
    local count = 0

    for id, ab in pairs(WHSTATE.airbasesById) do
        local tracked = WHSTATE.trackedEntries and WHSTATE.trackedEntries[id] or nil
        local shownName = (tracked and tracked.name) or (ab and ab:getName()) or "SIN_NOMBRE"
        count = count + 1

        if count <= 12 then
            log("Detectado ID " .. tostring(id) .. " -> " .. tostring(shownName))
        end
    end

    if WHSTATE.airbasesById[266] then
        local n = (WHSTATE.trackedEntries[266] and WHSTATE.trackedEntries[266].name) or "SIN_NOMBRE"
        log("ID 266 reconocido correctamente: " .. tostring(n))
    else
        log("ID 266 NO fue reconocido ni por runtime ni por fallback por nombre")
    end

    log("Total de ubicaciones monitoreadas: " .. tostring(count))
end

local function mainLoop(_, now)
    if not WHSTATE.started then
        return now + 1
    end

    refreshTrackedAirbases()

    if WHSTATE.injecting then
        if now <= WHSTATE.injectEndsAt then
            if (now - WHSTATE.lastInject) >= WHSYNC.INJECT_INTERVAL then
                WHSTATE.lastInject = now
                injectFromJson()
            end
        else
            WHSTATE.injecting = false
            log("Fin de ventana de inyección. DCS retoma control y JSON pasa a espejo vivo.")
            exportLiveToJson()
            WHSTATE.lastExport = now
        end
    else
        if (now - WHSTATE.lastExport) >= WHSYNC.EXPORT_INTERVAL then
            WHSTATE.lastExport = now
            exportLiveToJson()
        end
    end

    return now + 1
end

local function validateEnvironment()
    if not Airbase or not Airbase.getWarehouse then
        log("Airbase.getWarehouse no disponible. Requiere Warehouse API.")
        return false
    end

    if not net or not net.json2lua then
        log("net.json2lua no disponible en esta misión.")
        return false
    end

    if not io or not lfs then
        log("io/lfs no disponibles. Revisa MissionScripting.lua.")
        return false
    end

    return true
end

local function startWarehouseSync()
    if not validateEnvironment() then
        return
    end

    local initialDoc = nil
    local okDoc, _ = loadSyncFile()
    if type(okDoc) == "table" then
        initialDoc = okDoc
        readControlOverrides(initialDoc)
        registerSectionIds(initialDoc)
    end

    rebuildAirbaseIndex()

    WHSTATE.started = true
    WHSTATE.injecting = (initialDoc ~= nil)
    WHSTATE.injectEndsAt = timer.getTime() + WHSYNC.INJECT_DURATION
    WHSTATE.lastInject = -9999
    WHSTATE.lastExport = -9999

    if initialDoc then
        log("JSON encontrado. Inyección activa por " .. tostring(WHSYNC.INJECT_DURATION) .. " segundos.")
        injectFromJson()
    else
        log("No había JSON previo. Se crea snapshot inicial y DCS queda como fuente desde el inicio.")
        exportLiveToJson()
        WHSTATE.injecting = false
    end

    startupProbe()

    timer.scheduleFunction(function(_, t)
        refreshTrackedAirbases()
        return t + 5
    end, nil, timer.getTime() + 5)

    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)
end

startWarehouseSync()