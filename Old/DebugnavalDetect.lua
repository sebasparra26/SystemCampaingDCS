local CWD = {
    DEBUG_SCREEN = true,
    SCREEN_TIME = 15,
    RUN_DELAY = 20,

    OUTPUT_PATH = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\CarrierWarehouseDebug_KOLA.txt",

    TARGET_NAMES = {
        "Marshall",
        "Tarawa"
    },

    SECTION_ORDER = {
        "airports",
        "warehouses",
        "carriers",
        "farps",
        "helipads",
        "other"
    },

    JSON_PATHS = {
        KOLA_WAREHOUSE = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\SistemWarehousePersistanceKola.json",
        SINAI_WAREHOUSE = lfs.writedir() .. "Config\\HorizontDev\\SINAI\\SistemWarehousePersistanceSinai.json",
        KOLA_NAVAL = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\SystemUnitPositionPersistenceKola.json",
        SINAI_NAVAL = lfs.writedir() .. "Config\\HorizontDev\\SINAI\\SystemUnitPositionPersistence.json"
    }
}

local function log(msg)
    env.info("[CARRIER_DEBUG] " .. tostring(msg))
    if CWD.DEBUG_SCREEN then
        trigger.action.outText("[CARRIER_DEBUG] " .. tostring(msg), CWD.SCREEN_TIME)
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

local function tableCount(t)
    local c = 0
    if type(t) ~= "table" then
        return 0
    end
    for _, _ in pairs(t) do
        c = c + 1
    end
    return c
end

local function sortedKeysNumericAware(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local na = tonumber(a)
        local nb = tonumber(b)
        if na and nb then
            return na < nb
        end
        return tostring(a) < tostring(b)
    end)
    return keys
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

local function decodeJson(txt)
    if not txt or txt == "" then
        return nil, "archivo vacío"
    end

    if not net or not net.json2lua then
        return nil, "net.json2lua no disponible"
    end

    local ok, data = pcall(net.json2lua, txt)
    if not ok then
        return nil, tostring(data)
    end

    if type(data) ~= "table" then
        return nil, "json no devolvió tabla"
    end

    return data
end

local function loadJsonFile(path)
    local txt = safeReadFile(path)
    if not txt then
        return nil, "no existe archivo"
    end
    return decodeJson(txt)
end

local function getAirbaseCategoryInfo(ab)
    local rawCategory = nil
    local categoryName = "unknown"

    local ok, desc = pcall(function()
        return Airbase.getDesc(ab)
    end)

    if ok and type(desc) == "table" then
        rawCategory = tonumber(desc.category)
        if rawCategory ~= nil then
            if rawCategory > 0 then
                categoryName = "units"
            else
                categoryName = "airbase"
            end
        end
    end

    return categoryName, rawCategory
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
    local liquids = {
        jet_fuel = 0,
        gasoline = 0,
        methanol_mixture = 0,
        diesel = 0
    }

    local idToName = {
        [0] = "jet_fuel",
        [1] = "gasoline",
        [2] = "methanol_mixture",
        [3] = "diesel"
    }

    for i = 0, 3 do
        local amount = 0
        local ok, val = pcall(function()
            return wh:getLiquidAmount(i)
        end)

        if ok and type(val) == "number" then
            amount = val
        elseif inv and type(inv.liquids) == "table" then
            amount = inv.liquids[i] or inv.liquids[tostring(i)] or 0
        end

        liquids[idToName[i]] = tonumber(amount) or 0
    end

    return liquids
end

local function snapshotWarehouse(ab)
    if not ab then
        return nil
    end

    local okWh, wh = pcall(function()
        return ab:getWarehouse()
    end)
    if not okWh or not wh then
        return {
            warehouseAvailable = false
        }
    end

    local okInv, inv = pcall(function()
        return wh:getInventory()
    end)
    if not okInv or type(inv) ~= "table" then
        inv = {}
    end

    return {
        warehouseAvailable = true,
        aircraft = copyFlatMap(inv.aircraft),
        weapon = copyFlatMap(inv.weapon),
        liquids = getLiquidSnapshot(wh, inv)
    }
end

local function collectRuntimeAirbases()
    local list = {}
    local all = world.getAirbases() or {}

    for _, ab in ipairs(all) do
        if ab and ab.getID then
            local id = nil
            local name = "SIN_NOMBRE"

            local okId, runtimeId = pcall(function()
                return ab:getID()
            end)
            if okId then
                id = runtimeId
            end

            local okName, runtimeName = pcall(function()
                return ab:getName()
            end)
            if okName and runtimeName then
                name = runtimeName
            end

            local categoryName, rawCategory = getAirbaseCategoryInfo(ab)

            list[#list + 1] = {
                id = id,
                name = name,
                categoryName = categoryName,
                rawCategory = rawCategory,
                ref = ab
            }
        end
    end

    table.sort(list, function(a, b)
        local ia = tonumber(a.id) or 999999
        local ib = tonumber(b.id) or 999999
        if ia ~= ib then
            return ia < ib
        end
        return tostring(a.name) < tostring(b.name)
    end)

    return list
end

local function findTargetInRuntime(targetName, runtimeAirbases)
    local result = {
        exactByName = nil,
        containsMatches = {}
    }

    local exact = nil
    local ok, ab = pcall(function()
        return Airbase.getByName(targetName)
    end)

    if ok and ab then
        local id = nil
        local name = "SIN_NOMBRE"
        local okId, runtimeId = pcall(function()
            return ab:getID()
        end)
        if okId then
            id = runtimeId
        end
        local okName, runtimeName = pcall(function()
            return ab:getName()
        end)
        if okName and runtimeName then
            name = runtimeName
        end

        local categoryName, rawCategory = getAirbaseCategoryInfo(ab)

        exact = {
            id = id,
            name = name,
            categoryName = categoryName,
            rawCategory = rawCategory,
            warehouse = snapshotWarehouse(ab)
        }
    end

    result.exactByName = exact

    for _, entry in ipairs(runtimeAirbases or {}) do
        if contains(entry.name, targetName) then
            result.containsMatches[#result.containsMatches + 1] = {
                id = entry.id,
                name = entry.name,
                categoryName = entry.categoryName,
                rawCategory = entry.rawCategory,
                warehouse = snapshotWarehouse(entry.ref)
            }
        end
    end

    return result
end

local function compactInventoryLine(inv)
    if not inv then
        return "sin warehouse snapshot"
    end
    if inv.warehouseAvailable == false then
        return "warehouse no disponible"
    end

    local aircraftCount = tableCount(inv.aircraft)
    local weaponCount = tableCount(inv.weapon)

    local jf = inv.liquids and inv.liquids.jet_fuel or 0
    local gs = inv.liquids and inv.liquids.gasoline or 0
    local mm = inv.liquids and inv.liquids.methanol_mixture or 0
    local ds = inv.liquids and inv.liquids.diesel or 0

    return string.format(
        "aircraftKeys=%d | weaponKeys=%d | liquids(jet=%s, gas=%s, meth=%s, diesel=%s)",
        aircraftCount,
        weaponCount,
        tostring(jf),
        tostring(gs),
        tostring(mm),
        tostring(ds)
    )
end

local function buildEntryInfo(section, key, data)
    local info = {
        section = section,
        key = tostring(key),
        id = nil,
        name = nil,
        categoryName = nil,
        aircraftKeys = 0,
        weaponKeys = 0
    }

    if type(data) == "table" then
        info.id = tonumber(data.id) or tonumber(key)
        info.name = data.name
        info.categoryName = data.categoryName
        info.aircraftKeys = tableCount(data.aircraft)
        info.weaponKeys = tableCount(data.weapon)
    else
        info.id = tonumber(key)
    end

    return info
end

local function matchesTarget(entryInfo, targetName)
    local n = entryInfo and entryInfo.name or ""
    if n == targetName then
        return true
    end
    return contains(n, targetName)
end

local function scanWarehouseDoc(label, path)
    local report = {
        label = label,
        path = path,
        exists = false,
        parseOk = false,
        error = nil,
        sectionsPresent = {},
        rootNumericEntries = {},
        targetMatches = {},
        allUnitsLikeEntries = {}
    }

    for _, target in ipairs(CWD.TARGET_NAMES) do
        report.targetMatches[target] = {
            sectionEntries = {},
            rootEntries = {}
        }
    end

    local txt = safeReadFile(path)
    if not txt then
        report.error = "no existe archivo"
        return report
    end

    report.exists = true

    local doc, err = decodeJson(txt)
    if type(doc) ~= "table" then
        report.error = err or "json inválido"
        return report
    end

    report.parseOk = true

    for _, section in ipairs(CWD.SECTION_ORDER) do
        report.sectionsPresent[section] = (type(doc[section]) == "table")
        if type(doc[section]) == "table" then
            for idStr, data in pairs(doc[section]) do
                local info = buildEntryInfo(section, idStr, data)

                if info.categoryName == "units" then
                    report.allUnitsLikeEntries[#report.allUnitsLikeEntries + 1] = info
                end

                for _, target in ipairs(CWD.TARGET_NAMES) do
                    if matchesTarget(info, target) then
                        report.targetMatches[target].sectionEntries[#report.targetMatches[target].sectionEntries + 1] = info
                    end
                end
            end
        end
    end

    for k, v in pairs(doc) do
        if tonumber(k) and type(v) == "table" then
            local info = buildEntryInfo("ROOT", k, v)
            report.rootNumericEntries[#report.rootNumericEntries + 1] = info

            for _, target in ipairs(CWD.TARGET_NAMES) do
                if matchesTarget(info, target) then
                    report.targetMatches[target].rootEntries[#report.targetMatches[target].rootEntries + 1] = info
                end
            end
        end
    end

    table.sort(report.rootNumericEntries, function(a, b)
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)

    table.sort(report.allUnitsLikeEntries, function(a, b)
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)

    return report
end

local function scanNavalDoc(label, path)
    local report = {
        label = label,
        path = path,
        exists = false,
        parseOk = false,
        error = nil,
        targetGroups = {}
    }

    for _, target in ipairs(CWD.TARGET_NAMES) do
        report.targetGroups[target] = {}
    end

    local txt = safeReadFile(path)
    if not txt then
        report.error = "no existe archivo"
        return report
    end

    report.exists = true

    local doc, err = decodeJson(txt)
    if type(doc) ~= "table" then
        report.error = err or "json inválido"
        return report
    end

    report.parseOk = true

    if type(doc.groups) == "table" then
        for groupKey, entry in pairs(doc.groups) do
            local keyLower = lower(groupKey)
            local templateGroupName = entry and entry.templateGroupName or nil
            local liveGroupName = entry and entry.liveGroupName or nil
            local runtimeGroupName = entry and entry.runtimeGroupName or nil

            for _, target in ipairs(CWD.TARGET_NAMES) do
                if contains(keyLower, target)
                    or contains(templateGroupName, target)
                    or contains(liveGroupName, target)
                    or contains(runtimeGroupName, target)
                then
                    report.targetGroups[target][#report.targetGroups[target] + 1] = {
                        key = groupKey,
                        templateGroupName = templateGroupName,
                        liveGroupName = liveGroupName,
                        runtimeGroupName = runtimeGroupName,
                        enabled = entry and entry.enabled,
                        alive = entry and entry.alive,
                        anchorX = entry and entry.anchor and entry.anchor.mapPoint and entry.anchor.mapPoint.x or nil,
                        anchorY = entry and entry.anchor and entry.anchor.mapPoint and entry.anchor.mapPoint.y or nil
                    }
                end
            end
        end
    end

    return report
end

local function snapshotGroup(name)
    local result = {
        query = name,
        exists = false
    }

    local grp = Group.getByName(name)
    if not grp then
        return result
    end

    local okExist, exists = pcall(function()
        return grp:isExist()
    end)

    if not okExist or not exists then
        return result
    end

    result.exists = true
    result.groupName = name

    local okUnit, unit = pcall(function()
        return grp:getUnit(1)
    end)

    if okUnit and unit then
        result.unit1Name = unit:getName()
        result.unit1Type = unit:getTypeName()

        local okCoal, coal = pcall(function()
            return unit:getCoalition()
        end)
        if okCoal then
            result.coalition = coal
        end

        local okPoint, point = pcall(function()
            return unit:getPoint()
        end)
        if okPoint and point then
            result.x = point.x
            result.y = point.y
            result.z = point.z
        end
    end

    return result
end

local function snapshotMistSpawnBase(baseName)
    local result = {
        key = baseName,
        exists = false,
        count = 0,
        sample = {}
    }

    if not mist or not mist.DBs or not mist.DBs.spawnsByBase then
        result.note = "mist.DBs.spawnsByBase no disponible"
        return result
    end

    local list = mist.DBs.spawnsByBase[baseName]
    if type(list) ~= "table" then
        result.note = "clave no encontrada"
        return result
    end

    result.exists = true
    result.count = #list

    for i = 1, math.min(#list, 10) do
        result.sample[#result.sample + 1] = list[i]
    end

    return result
end

local function diagnoseTarget(targetName, runtimeInfo, kolaWarehouseReport)
    local lines = {}

    local exact = runtimeInfo and runtimeInfo.exactByName or nil
    local kola = kolaWarehouseReport and kolaWarehouseReport.targetMatches and kolaWarehouseReport.targetMatches[targetName] or nil

    local kolaSectionCount = 0
    local kolaRootCount = 0
    if kola then
        kolaSectionCount = #(kola.sectionEntries or {})
        kolaRootCount = #(kola.rootEntries or {})
    end

    if exact and kolaSectionCount > 0 then
        local first = kola.sectionEntries[1]
        if tonumber(first.id) == tonumber(exact.id) then
            lines[#lines + 1] = "KOLA: runtime y JSON coinciden en ID."
        else
            lines[#lines + 1] = "KOLA: runtime y JSON tienen IDs distintos. Runtime=" .. tostring(exact.id) .. " | JSON=" .. tostring(first.id)
        end
    end

    if not exact and kolaSectionCount > 0 then
        lines[#lines + 1] = "KOLA: el JSON sí tiene entrada, pero Airbase.getByName no resolvió ese nombre en runtime."
    end

    if exact and kolaSectionCount == 0 and kolaRootCount > 0 then
        lines[#lines + 1] = "KOLA: el target aparece en la raíz numérica del JSON, no dentro de sections. Así no lo leen los sync nuevos."
    end

    if exact and kolaSectionCount == 0 and kolaRootCount == 0 then
        lines[#lines + 1] = "KOLA: runtime sí existe, pero no aparece en el JSON con ese nombre."
    end

    if not exact and kolaSectionCount == 0 and kolaRootCount == 0 then
        lines[#lines + 1] = "KOLA: ni runtime exacto ni JSON target encontrado. Revisa nombre real expuesto por DCS."
    end

    if #lines == 0 then
        lines[#lines + 1] = "Sin hallazgo claro automático. Revisar detalle completo del reporte."
    end

    return lines
end

local function appendLine(lines, txt)
    lines[#lines + 1] = txt or ""
end

local function renderWarehouseTargetBlock(lines, title, block)
    appendLine(lines, title)
    if not block then
        appendLine(lines, "  sin datos")
        return
    end

    appendLine(lines, "  sectionEntries: " .. tostring(#(block.sectionEntries or {})))
    for _, entry in ipairs(block.sectionEntries or {}) do
        appendLine(lines,
            "    - section=" .. tostring(entry.section) ..
            " | key=" .. tostring(entry.key) ..
            " | id=" .. tostring(entry.id) ..
            " | name=" .. tostring(entry.name) ..
            " | categoryName=" .. tostring(entry.categoryName) ..
            " | aircraftKeys=" .. tostring(entry.aircraftKeys) ..
            " | weaponKeys=" .. tostring(entry.weaponKeys)
        )
    end

    appendLine(lines, "  rootEntries: " .. tostring(#(block.rootEntries or {})))
    for _, entry in ipairs(block.rootEntries or {}) do
        appendLine(lines,
            "    - ROOT" ..
            " | key=" .. tostring(entry.key) ..
            " | id=" .. tostring(entry.id) ..
            " | name=" .. tostring(entry.name) ..
            " | categoryName=" .. tostring(entry.categoryName) ..
            " | aircraftKeys=" .. tostring(entry.aircraftKeys) ..
            " | weaponKeys=" .. tostring(entry.weaponKeys)
        )
    end
end

local function buildReportText(data)
    local lines = {}

    appendLine(lines, "================ CARRIER / WAREHOUSE DEBUG REPORT ================")
    appendLine(lines, "Mission time: " .. tostring(timer.getTime()))
    appendLine(lines, "Theatre: " .. tostring(env.mission and env.mission.theatre or "N/A"))
    appendLine(lines, "Output file: " .. tostring(CWD.OUTPUT_PATH))
    appendLine(lines, "")

    appendLine(lines, "================ RUNTIME AIRBASES (CATEGORY units) ================")
    local runtimeUnitsCount = 0
    for _, entry in ipairs(data.runtimeAirbases or {}) do
        if entry.categoryName == "units" then
            runtimeUnitsCount = runtimeUnitsCount + 1
            appendLine(lines,
                "ID=" .. tostring(entry.id) ..
                " | Name=" .. tostring(entry.name) ..
                " | Category=" .. tostring(entry.categoryName) ..
                " | RawCategory=" .. tostring(entry.rawCategory)
            )
        end
    end
    appendLine(lines, "Total runtime units-like airbases: " .. tostring(runtimeUnitsCount))
    appendLine(lines, "")

    for _, target in ipairs(CWD.TARGET_NAMES) do
        local runtimeInfo = data.runtimeTargets[target]
        local groupInfo = data.groupTargets[target]
        local mistInfo = data.mistTargets[target]

        appendLine(lines, "================ TARGET: " .. tostring(target) .. " ================")

        appendLine(lines, "RUNTIME exact lookup:")
        if runtimeInfo and runtimeInfo.exactByName then
            appendLine(lines,
                "  Airbase.getByName OK | id=" .. tostring(runtimeInfo.exactByName.id) ..
                " | name=" .. tostring(runtimeInfo.exactByName.name) ..
                " | category=" .. tostring(runtimeInfo.exactByName.categoryName) ..
                " | rawCategory=" .. tostring(runtimeInfo.exactByName.rawCategory)
            )
            appendLine(lines, "  " .. compactInventoryLine(runtimeInfo.exactByName.warehouse))
        else
            appendLine(lines, "  Airbase.getByName NO encontró este nombre.")
        end

        appendLine(lines, "RUNTIME contains matches:")
        if runtimeInfo and #(runtimeInfo.containsMatches or {}) > 0 then
            for _, m in ipairs(runtimeInfo.containsMatches or {}) do
                appendLine(lines,
                    "  - id=" .. tostring(m.id) ..
                    " | name=" .. tostring(m.name) ..
                    " | category=" .. tostring(m.categoryName) ..
                    " | rawCategory=" .. tostring(m.rawCategory)
                )
                appendLine(lines, "    " .. compactInventoryLine(m.warehouse))
            end
        else
            appendLine(lines, "  sin coincidencias parciales")
        end

        appendLine(lines, "GROUP lookup:")
        if groupInfo and groupInfo.exists then
            appendLine(lines,
                "  Group.getByName OK | unit1Name=" .. tostring(groupInfo.unit1Name) ..
                " | unit1Type=" .. tostring(groupInfo.unit1Type) ..
                " | coalition=" .. tostring(groupInfo.coalition) ..
                " | x=" .. tostring(groupInfo.x) ..
                " | z=" .. tostring(groupInfo.z)
            )
        else
            appendLine(lines, "  Group.getByName NO encontró este grupo.")
        end

        appendLine(lines, "MIST spawnsByBase:")
        if mistInfo and mistInfo.exists then
            appendLine(lines, "  existe | count=" .. tostring(mistInfo.count))
            for _, sampleName in ipairs(mistInfo.sample or {}) do
                appendLine(lines, "    - " .. tostring(sampleName))
            end
        else
            appendLine(lines, "  " .. tostring(mistInfo and mistInfo.note or "no disponible"))
        end

        appendLine(lines, "")
        appendLine(lines, "KOLA warehouse JSON:")
        renderWarehouseTargetBlock(lines, "", data.kolaWarehouse.targetMatches[target])

        appendLine(lines, "")
        appendLine(lines, "SINAI warehouse JSON:")
        renderWarehouseTargetBlock(lines, "", data.sinaiWarehouse.targetMatches[target])

        appendLine(lines, "")
        appendLine(lines, "KOLA naval position JSON:")
        local kNav = data.kolaNaval.targetGroups[target] or {}
        if #kNav > 0 then
            for _, item in ipairs(kNav) do
                appendLine(lines,
                    "  - key=" .. tostring(item.key) ..
                    " | template=" .. tostring(item.templateGroupName) ..
                    " | live=" .. tostring(item.liveGroupName) ..
                    " | runtime=" .. tostring(item.runtimeGroupName) ..
                    " | enabled=" .. tostring(item.enabled) ..
                    " | alive=" .. tostring(item.alive) ..
                    " | anchorX=" .. tostring(item.anchorX) ..
                    " | anchorY=" .. tostring(item.anchorY)
                )
            end
        else
            appendLine(lines, "  sin coincidencias")
        end

        appendLine(lines, "")
        appendLine(lines, "SINAI naval position JSON:")
        local sNav = data.sinaiNaval.targetGroups[target] or {}
        if #sNav > 0 then
            for _, item in ipairs(sNav) do
                appendLine(lines,
                    "  - key=" .. tostring(item.key) ..
                    " | template=" .. tostring(item.templateGroupName) ..
                    " | live=" .. tostring(item.liveGroupName) ..
                    " | runtime=" .. tostring(item.runtimeGroupName) ..
                    " | enabled=" .. tostring(item.enabled) ..
                    " | alive=" .. tostring(item.alive) ..
                    " | anchorX=" .. tostring(item.anchorX) ..
                    " | anchorY=" .. tostring(item.anchorY)
                )
            end
        else
            appendLine(lines, "  sin coincidencias")
        end

        appendLine(lines, "")
        appendLine(lines, "DIAGNÓSTICO AUTOMÁTICO:")
        local diagnoses = diagnoseTarget(target, runtimeInfo, data.kolaWarehouse)
        for _, d in ipairs(diagnoses) do
            appendLine(lines, "  - " .. tostring(d))
        end

        appendLine(lines, "")
    end

    appendLine(lines, "================ KOLA WAREHOUSE JSON - ROOT NUMERIC ENTRIES ================")
    appendLine(lines, "Count: " .. tostring(#(data.kolaWarehouse.rootNumericEntries or {})))
    for _, entry in ipairs(data.kolaWarehouse.rootNumericEntries or {}) do
        appendLine(lines,
            "  - key=" .. tostring(entry.key) ..
            " | id=" .. tostring(entry.id) ..
            " | name=" .. tostring(entry.name) ..
            " | categoryName=" .. tostring(entry.categoryName)
        )
    end
    appendLine(lines, "")

    appendLine(lines, "================ KOLA WAREHOUSE JSON - ALL units LIKE ENTRIES ================")
    for _, entry in ipairs(data.kolaWarehouse.allUnitsLikeEntries or {}) do
        appendLine(lines,
            "  - section=" .. tostring(entry.section) ..
            " | key=" .. tostring(entry.key) ..
            " | id=" .. tostring(entry.id) ..
            " | name=" .. tostring(entry.name) ..
            " | categoryName=" .. tostring(entry.categoryName)
        )
    end
    appendLine(lines, "")

    appendLine(lines, "================ SECTION PRESENCE ================")
    appendLine(lines, "KOLA:")
    for _, section in ipairs(CWD.SECTION_ORDER) do
        appendLine(lines, "  " .. section .. " = " .. tostring(data.kolaWarehouse.sectionsPresent[section]))
    end
    appendLine(lines, "SINAI:")
    for _, section in ipairs(CWD.SECTION_ORDER) do
        appendLine(lines, "  " .. section .. " = " .. tostring(data.sinaiWarehouse.sectionsPresent[section]))
    end
    appendLine(lines, "")

    appendLine(lines, "================ END OF REPORT ================")

    return table.concat(lines, "\n")
end

local function runDebug()
    local data = {
        runtimeAirbases = collectRuntimeAirbases(),
        runtimeTargets = {},
        groupTargets = {},
        mistTargets = {},
        kolaWarehouse = scanWarehouseDoc("KOLA_WAREHOUSE", CWD.JSON_PATHS.KOLA_WAREHOUSE),
        sinaiWarehouse = scanWarehouseDoc("SINAI_WAREHOUSE", CWD.JSON_PATHS.SINAI_WAREHOUSE),
        kolaNaval = scanNavalDoc("KOLA_NAVAL", CWD.JSON_PATHS.KOLA_NAVAL),
        sinaiNaval = scanNavalDoc("SINAI_NAVAL", CWD.JSON_PATHS.SINAI_NAVAL)
    }

    for _, target in ipairs(CWD.TARGET_NAMES) do
        data.runtimeTargets[target] = findTargetInRuntime(target, data.runtimeAirbases)
        data.groupTargets[target] = snapshotGroup(target)
        data.mistTargets[target] = snapshotMistSpawnBase(target)
    end

    local reportText = buildReportText(data)
    local ok = safeWriteFile(CWD.OUTPUT_PATH, reportText)

    if ok then
        env.info("[CARRIER_DEBUG] Reporte escrito en: " .. tostring(CWD.OUTPUT_PATH))
        if CWD.DEBUG_SCREEN then
            trigger.action.outText(
                "[CARRIER_DEBUG] Reporte listo en:\n" .. tostring(CWD.OUTPUT_PATH),
                CWD.SCREEN_TIME
            )
        end
    else
        env.info("[CARRIER_DEBUG] ERROR escribiendo reporte en: " .. tostring(CWD.OUTPUT_PATH))
        if CWD.DEBUG_SCREEN then
            trigger.action.outText(
                "[CARRIER_DEBUG] ERROR escribiendo reporte.",
                CWD.SCREEN_TIME
            )
        end
    end
end

timer.scheduleFunction(function()
    runDebug()
    return nil
end, nil, timer.getTime() + (CWD.RUN_DELAY or 20))