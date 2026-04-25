if not mist or not mist.teleportToPoint then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

----------------------------------------------------------------
-- ActivateUnitsCampaing_KOLA.lua
--
-- BASE:
--   Version estable de activaciones por flag
--
-- MODULO 1:
--   Clonado por bandera con nombre runtime fijo
--
-- MODULO 2:
--   Activacion simple por flag usando trigger.action.activateGroup
--   SOLO estos grupos llevan persistencia JSON
--
-- PERSISTENCIA MODULO 2:
--   GRUPO:
--     status = 1 habilitado para activarse
--     status = 2 muerto definitivamente, NO volver activar
--
--   UNIDADES:
--     status = 1 unidad habilitada/viva
--     status = 2 unidad muerta, se destruye despues del spawn del grupo
--
-- REGLA DURA:
--   Si un grupo esta en 2, JAMAS vuelve a 1 por script.
--   Si una unidad esta en 2, JAMAS vuelve a 1 por script.
--   Si aparece viva por cualquier motivo, se destruye.
--
-- NOTA:
--   DCS no expone una funcion estable para aplicar vida parcial exacta
--   tipo Unit:setLife(). Este script guarda life/life0/lifePercent,
--   pero solo restaura de forma segura las unidades muertas.
----------------------------------------------------------------

local debugActivo = false
local intervaloRevision = 1

local function getWriteDir()
    if lfs and lfs.writedir then
        return lfs.writedir()
    end
    return ""
end

----------------------------------------------------------------
-- MODULO 1
-- CLONADO POR BANDERA
--
-- 1 = ROJO
-- 2 = AZUL
----------------------------------------------------------------
local gruposPorBandera = {
    [100] = {
        rojo = {"RU_100_Banak","RU_100_Banak_Ship","RU_100_Banak_SAM","RU_100_Banak_EWR", "RU_100_Banak_Shield" , "RU_100_Banak_Artillery"},
        azul = {"US_100_Banak", "US_100_Banak_SAM", "US_100_Banak_Shield"}
    },
    [101] = { rojo = "RU_101_Rovaniemi", azul = "US_101_Rovaniemi" },
    [102] = { rojo = "RU_102_Kemi", azul = "US_102_Kemi" },
    [103] = { rojo = "RU_103_Vuojarvi", azul = "US_103_Vuojarvi" },
    [104] = { rojo = "RU_104_Kiruna", azul = "US_104_Kiruna" },
    [105] = {
        rojo = {"RU_105_Severomorsk-3", "RU_105_Severomorsk-3_SAM", "RU_105_Severomorsk-3_EWR", "RU_105_Severomorsk-3_Shield", "RU_105_Severomorsk-3_Manpad"},
        azul = {"US_105_Severomorsk-3"}
    },
    [106] = { rojo = "RU_106_Bodo", azul = "US_106_Bodo" },
    [107] = { rojo = "RU_107_Severomorsk-1", azul = "US_107_Severomorsk-1" },
    [108] = { rojo = "RU_108_Olenya", azul = "US_108_Olenya" },
    [109] = { rojo = "RU_109_Monchegorsk", azul = "US_109_Monchegorsk" },
    [110] = { rojo = "RU_110_Jokkmokk", azul = "US_110_Jokkmokk" },
    [111] = { rojo = "RU_111_Murmansk", azul = "US_111_Murmansk" },

    [112] = {
        rojo = {"RU_112_Kalixfors"},
        azul = {"US_112_Kalixfors", "US_112_Kalixfors_SAM", "US_112_Kalixfors_Shield", "RU_112_Kalixfors_Troops", "RU_112_Kalixfors_SEAD", "RU_112_Kalixfors_ISKANDER" }
    },
    [113] = { rojo = "RU_113_Kirkenes", azul = "US_113_Kirkenes" },

    [114] = {
        rojo = {"RU_114_Kallax", "RU_114_Kallax_SAM", "RU_114_Kallax_EWR", "RU_114_Kallax_Shield", "RU_114_Kallax_Ship"},
        azul = {"US_114_Kallax", "US_114_Kallax_SAM", "US_114_Kallax_Shield"}
    },
    [115] = {
        rojo = {"RU_115_Kuusamo", "RU_115_Kuusamo_SAM", "RU_115_Kuusamo_EWR", "RU_115_Kuusamo_Shield", "RU_115_Kuusamo_Manpad"},
        azul = {"US_115_Kuusamo" , "US_115_Kuusamo_SAM", "US_115_Kuusamo_Shield"}
    },
    [116] = { rojo = "RU_116_Vidsel", azul = "US_116_Vidsel" },
    [117] = { rojo = "RU_117_Ivalo", azul = "US_117_Ivalo" },
    [118] = { rojo = "RU_118_Alakurtti", azul = "US_118_Alakurtti" },

    [119] = {
        rojo = {"RU_119_Andoya"},
        azul = {"US_119_Andoya", "US_119_Andoya_SAM", "US_119_Andoya_Shield","RU_119_Andoya_STRIKE", "RU_119_Andoya_STRIKE2"}
    },
    [120] = {
        rojo = {"RU_120_Bardufoss"},
        azul = {"US_120_Bardufoss", "US_120_Bardufoss_SAM", "US_120_Bardufoss_Shield", "RU_120_Bardufoss_Troops"}
    },

    [121] = {
        rojo = {"RU_121_Kittila", "RU_121_Kittila_SAM","RU_121_Kittila_SAM_2","RU_121_Kittila_EWR", "RU_121_Kittila_Shield", "RU_121_Kittila_Shield_2", "RU_121_Kittila_Manpad"},
        azul = {"US_121_Kittila", "US_121_Kittila_SAM", "US_121_Kittila_Shield"}
    },

    [122] = { rojo = "RU_122_Hosio", azul = "US_122_Hosio" },
    [123] = { rojo = "RU_123_Alta", azul = "US_123_Alta" },

    [124] = {
        rojo = {"RU_124_Evenes"},
        azul = {"US_124_Evenes", "US_124_Evenes_SAM", "US_124_Evenes_Shield", "RU_124_Evenes_Ship", "RU_112_Kalixfors_STRIKE" }
    },
    [125] = {
        rojo = {"RU_125_Enontekio"},
        azul = {"US_125_Enontekio", "US_125_Enontekio_SAM", "RU_125_Enontekio_SEAD"}
    },

    [126] = { rojo = "RU_126_Sodankyla", azul = "US_126_Sodankyla" },
    [127] = { rojo = "RU_127_Kilpyavr", azul = "US_127_Kilpyavr" },
    [128] = { rojo = "RU_128_Luostari", azul = "US_128_Luostari" },
    [129] = { rojo = "RU_129_Koshka", azul = "US_129_Koshka" },
    [130] = { rojo = "RU_130_Poduzhemye", azul = "US_130_Poduzhemye" },
    [131] = { rojo = "RU_131_Kalevala", azul = "US_131_Kalevala" },
    [132] = { rojo = "RU_132_Afrikanda", azul = "US_132_Afrikanda" },
    [133] = {
        rojo = {"RU_133_Boden"},
        azul = {"US_133_Boden", "US_133_Boden_SAM"}
    },
    [134] = {
        rojo = {"RU_134_Hemavan"},
        azul = {"US_134_Hemavan", "US_134_Hemavan_SAM", "RU_134_Hemavan_TROOPS", "RU_134_Hemavan_STRIKE"}
    },
    [135] = {
        rojo = {"RU_135_Arvidsjaur"},
        azul = {"US_135_Arvidsjaur", "US_135_Arvidsjaur_SAM"}
    },
}

----------------------------------------------------------------
-- MODULO 2
-- ACTIVACION SIMPLE POR FLAG
-- ESTOS GRUPOS NO SE CLONAN
----------------------------------------------------------------
local activacionesPorFlag = {
    [2100] = {
        valor = 1,
        grupos = {
            "MT_01_EWR",
            "MT_01_SHIP",
            --"RU_EWR_154_Khalkhalah",
            --"RU_SHIELD_154_Khalkhalah"
            --"US_TROOP"
        }
    },

    [2200] = {
        valor = 1,
        grupos = {
            "US_TROOP_01"
        }
    },

    [106] = {
        valor = 2,
        grupos = {
            "TGT01",
            "TGT02",
            "TGT03",
            "TGT04",
            "TGT05",
            "TGT06",
            "TGT07",
            "TGT08",
            "TGT09",
            "TGT10",
        }
    },
}

----------------------------------------------------------------
-- SYNC JSON MODULO 2
----------------------------------------------------------------
local ACTSYNC = {
    DEBUG = false,

    FILE_PATH = getWriteDir() .. "Config\\HorizontDev\\KOLA\\ActivateUnitsFlagPersistence.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 350,

    TRACK_UNIT_STATUS = true,

    -- Aplica unidades muertas despues de activar el grupo.
    -- Esto elimina unidades con status = 2 o life <= 0 en el JSON.
    APPLY_DEAD_UNITS_ON_SPAWN = true,
    APPLY_DEAD_UNITS_DELAY = 1,

    -- DCS no tiene Unit:setLife() estable/documentado.
    -- Se deja en false para no usar explosiones ni trucos peligrosos.
    APPLY_PARTIAL_LIFE = false
}

local ACTSTATE = {
    started = false,
    injecting = false,
    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,

    trackedGroups = {},
    runtime = {},
    doc = nil,
    eventHandlerRegistered = false,
    lastSavedPayload = "",
    dirty = false,
    persistenceAvailable = false
}

local estadoPrevioBanderas = {}
local estadoPrevioActivaciones = {}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function debug(msg, tiempo)
    if debugActivo then
        trigger.action.outText("[ActivateUnits] " .. tostring(msg), tiempo or 10)
    end
end

local function log(msg)
    env.info("[ActivateUnitsCampaing_KOLA] " .. tostring(msg))
    if debugActivo then
        trigger.action.outText("[ActivateUnits] " .. tostring(msg), 8)
    end
end

local function syncLog(msg)
    env.info("[ACTSYNC] " .. tostring(msg))
    if ACTSYNC.DEBUG or debugActivo then
        trigger.action.outText("[ACTSYNC] " .. tostring(msg), 8)
    end
end

----------------------------------------------------------------
-- UTILS GENERALES
----------------------------------------------------------------
local function round(n, d)
    n = tonumber(n) or 0
    local m = 10 ^ (d or 0)
    return math.floor((n * m) + 0.5) / m
end

local function ensureNumber(v)
    return tonumber(v) or 0
end

local function deepCopy(tbl)
    if mist and mist.utils and mist.utils.deepCopy then
        return mist.utils.deepCopy(tbl)
    end

    if type(tbl) ~= "table" then
        return tbl
    end

    local out = {}
    for k, v in pairs(tbl) do
        out[k] = deepCopy(v)
    end
    return out
end

local function convertirALista(valor)
    if not valor then
        return {}
    end

    if type(valor) == "string" then
        return { valor }
    end

    if type(valor) == "table" then
        local lista = {}
        for i = 1, #valor do
            if type(valor[i]) == "string" and valor[i] ~= "" then
                lista[#lista + 1] = valor[i]
            end
        end
        return lista
    end

    return {}
end

local function sortedKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do
        keys[#keys + 1] = k
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function sortedNumericListFromMap(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if v then
            out[#out + 1] = tonumber(k) or k
        end
    end

    table.sort(out, function(a, b)
        local na = tonumber(a)
        local nb = tonumber(b)

        if na and nb then
            return na < nb
        end

        return tostring(a) < tostring(b)
    end)

    return out
end

local function groupExistsByName(groupName)
    if not groupName then
        return nil
    end

    local grp = Group.getByName(groupName)
    if not grp then
        return nil
    end

    local ok, exists = pcall(function()
        return grp:isExist()
    end)

    if ok and exists then
        return grp
    end

    return nil
end

local function destroyGroupIfExists(groupName)
    local grp = groupExistsByName(groupName)
    if grp then
        pcall(function()
            grp:destroy()
        end)
        return true
    end
    return false
end

local function countAliveUnitsInGroup(groupName)
    local grp = groupExistsByName(groupName)
    if not grp then
        return 0
    end

    local okUnits, units = pcall(function()
        return grp:getUnits()
    end)

    if not okUnits or type(units) ~= "table" then
        return 0
    end

    local alive = 0

    for i = 1, #units do
        local u = units[i]
        if u then
            local okExist, exists = pcall(function()
                return u:isExist()
            end)

            if okExist and exists then
                local okLife, life = pcall(function()
                    return u:getLife()
                end)

                if okLife and ensureNumber(life) > 0 then
                    alive = alive + 1
                end
            end
        end
    end

    return alive
end

local function safeCall(obj, methodName)
    if not obj or not methodName or not obj[methodName] then
        return nil
    end

    local ok, result = pcall(function()
        return obj[methodName](obj)
    end)

    if ok then
        return result
    end

    return nil
end

----------------------------------------------------------------
-- MODULO 2
-- SNAPSHOT DE UNIDADES DEL GRUPO
----------------------------------------------------------------
local function getTemplateGroupData(groupName)
    if not groupName then
        return nil
    end

    if mist and mist.DBs and mist.DBs.MEgroupsByName and mist.DBs.MEgroupsByName[groupName] then
        return mist.DBs.MEgroupsByName[groupName]
    end

    if mist and mist.DBs and mist.DBs.groupsByName and mist.DBs.groupsByName[groupName] then
        return mist.DBs.groupsByName[groupName]
    end

    if mist and mist.getGroupData then
        local ok, data = pcall(function()
            return mist.getGroupData(groupName, true)
        end)

        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

local function getUnitNameFromTemplate(unitData, groupName, index)
    if type(unitData) ~= "table" then
        return tostring(groupName) .. "_UNIT_" .. tostring(index)
    end

    return unitData.unitName or unitData.name or tostring(groupName) .. "_UNIT_" .. tostring(index)
end

local function buildTemplateUnitsSnapshot(groupName)
    local out = {}
    local groupData = getTemplateGroupData(groupName)

    if type(groupData) ~= "table" or type(groupData.units) ~= "table" then
        return out
    end

    for i, unitData in pairs(groupData.units) do
        if type(unitData) == "table" then
            local unitName = getUnitNameFromTemplate(unitData, groupName, i)

            out[unitName] = {
                name = unitName,
                groupName = groupName,
                index = tonumber(i) or i,

                type = unitData.type or unitData.typeName,
                templateUnitId = unitData.unitId,

                status = 1,
                alive = false,
                life = nil,
                life0 = nil,
                lifePercent = nil,

                everSeenAlive = false,
                lastSeenAliveAt = nil,
                lastChangeTime = nil,

                source = "template"
            }
        end
    end

    return out
end

local function normalizeUnitRecord(unitName, groupName, data)
    data = type(data) == "table" and data or {}

    data.name = data.name or unitName
    data.groupName = data.groupName or groupName

    local status = tonumber(data.status) or 1
    if status ~= 2 then
        status = 1
    end

    data.status = status

    if status == 2 then
        data.alive = false
        data.life = 0
        data.lifePercent = 0
    end

    return data
end

local function mergeTemplateIntoUnitState(groupName, previousUnits)
    local unitsMap = {}

    if type(previousUnits) == "table" then
        for unitName, data in pairs(previousUnits) do
            if type(data) == "table" then
                unitsMap[unitName] = normalizeUnitRecord(unitName, groupName, deepCopy(data))
            end
        end
    end

    local templateUnits = buildTemplateUnitsSnapshot(groupName)
    for unitName, data in pairs(templateUnits) do
        if not unitsMap[unitName] then
            unitsMap[unitName] = data
        else
            unitsMap[unitName].name = unitsMap[unitName].name or data.name
            unitsMap[unitName].groupName = groupName
            unitsMap[unitName].index = unitsMap[unitName].index or data.index
            unitsMap[unitName].type = unitsMap[unitName].type or data.type
            unitsMap[unitName].templateUnitId = unitsMap[unitName].templateUnitId or data.templateUnitId
        end
    end

    return unitsMap
end

local function collectGroupUnitsSnapshot(groupName, previousUnits, markMissingAsDead)
    local now = round(timer.getTime(), 3)
    local unitsMap = mergeTemplateIntoUnitState(groupName, previousUnits)

    local grp = groupExistsByName(groupName)
    if not grp then
        return unitsMap
    end

    local okUnits, runtimeUnits = pcall(function()
        return grp:getUnits()
    end)

    if not okUnits or type(runtimeUnits) ~= "table" then
        return unitsMap
    end

    local runtimeSeen = {}

    for i = 1, #runtimeUnits do
        local unit = runtimeUnits[i]
        if unit then
            local unitName = safeCall(unit, "getName") or tostring(groupName) .. "_UNIT_" .. tostring(i)
            runtimeSeen[unitName] = true

            local row = unitsMap[unitName] or {
                name = unitName,
                groupName = groupName,
                index = i,
                status = 1,
                everSeenAlive = false
            }

            local lockedDead = tonumber(row.status) == 2

            local exists = safeCall(unit, "isExist") and true or false
            local typeName = safeCall(unit, "getTypeName")
            local life = ensureNumber(safeCall(unit, "getLife"))
            local life0 = ensureNumber(safeCall(unit, "getLife0"))

            local alive = exists and life > 0

            row.name = unitName
            row.groupName = groupName
            row.index = row.index or i
            row.type = typeName or row.type
            row.runtimeUnitId = safeCall(unit, "getID")
            row.coalition = safeCall(unit, "getCoalition")
            row.country = safeCall(unit, "getCountry")
            row.source = "runtime"

            if lockedDead then
                row.status = 2
                row.alive = false
                row.life = 0
                row.lifePercent = 0
            else
                row.status = alive and 1 or 2
                row.alive = alive
                row.life = round(life, 3)
                row.life0 = life0 > 0 and round(life0, 3) or row.life0

                if life0 > 0 then
                    row.lifePercent = round((life / life0) * 100, 2)
                elseif row.life0 and row.life0 > 0 then
                    row.lifePercent = round((life / row.life0) * 100, 2)
                else
                    row.lifePercent = nil
                end

                if alive then
                    row.everSeenAlive = true
                    row.lastSeenAliveAt = now
                else
                    row.lastChangeTime = row.lastChangeTime or now
                end
            end

            local point = safeCall(unit, "getPoint")
            if point then
                row.point = {
                    x = round(point.x, 3),
                    y = round(point.y, 3),
                    z = round(point.z, 3)
                }
            end

            unitsMap[unitName] = normalizeUnitRecord(unitName, groupName, row)
        end
    end

    if markMissingAsDead then
        for unitName, row in pairs(unitsMap) do
            if type(row) == "table" and not runtimeSeen[unitName] then
                if tonumber(row.status) ~= 2 and row.everSeenAlive then
                    row.status = 2
                    row.alive = false
                    row.life = 0
                    row.lifePercent = 0
                    row.lastChangeTime = now
                    row.source = row.source or "lastKnown"
                end
            end
        end
    end

    return unitsMap
end

local function countUnitsInSnapshot(unitsMap)
    local total = 0
    local alive = 0
    local dead = 0

    for _, data in pairs(unitsMap or {}) do
        if type(data) == "table" then
            total = total + 1

            if tonumber(data.status) == 2 then
                dead = dead + 1
            elseif data.alive then
                alive = alive + 1
            end
        end
    end

    return total, alive, dead
end

local function forceDeadUnitsInRecord(rec)
    if type(rec) ~= "table" or type(rec.units) ~= "table" then
        return
    end

    for _, unitData in pairs(rec.units) do
        if type(unitData) == "table" then
            unitData.status = 2
            unitData.alive = false
            unitData.life = 0
            unitData.lifePercent = 0
        end
    end

    rec.aliveUnits = 0
end

local function applySavedUnitStateToRuntime(groupName)
    if not ACTSYNC.APPLY_DEAD_UNITS_ON_SPAWN then
        return
    end

    local rec = ACTSTATE.trackedGroups[groupName]
    if not rec or type(rec.units) ~= "table" then
        return
    end

    if tonumber(rec.status) == 2 then
        return
    end

    for unitName, unitState in pairs(rec.units) do
        if type(unitState) == "table" then
            local unitStatus = tonumber(unitState.status) or 1
            local savedLife = tonumber(unitState.life)

            if unitStatus == 2 or (savedLife ~= nil and savedLife <= 0) then
                local unit = Unit.getByName(unitName)

                if unit then
                    local okExist, exists = pcall(function()
                        return unit:isExist()
                    end)

                    if okExist and exists then
                        pcall(function()
                            unit:destroy()
                        end)

                        unitState.status = 2
                        unitState.alive = false
                        unitState.life = 0
                        unitState.lifePercent = 0
                        unitState.lastChangeTime = round(timer.getTime(), 3)

                        ACTSTATE.dirty = true
                        syncLog("Unidad bloqueada en 2 destruida por persistencia: " .. tostring(unitName))
                    end
                end
            end
        end
    end
end

local function scheduleApplySavedUnitState(groupName, delay)
    delay = tonumber(delay) or ACTSYNC.APPLY_DEAD_UNITS_DELAY or 1

    timer.scheduleFunction(function(args)
        if args and args.groupName then
            applySavedUnitStateToRuntime(args.groupName)

            local rec = ACTSTATE.trackedGroups[args.groupName]
            local rt = ACTSTATE.runtime[args.groupName]

            if rec then
                rec.units = collectGroupUnitsSnapshot(args.groupName, rec.units, rt and rt.seenAliveOnce)
                local totalUnits, aliveUnits, deadUnits = countUnitsInSnapshot(rec.units)
                rec.totalUnits = totalUnits
                rec.aliveUnits = aliveUnits
                rec.deadUnits = deadUnits
                ACTSTATE.dirty = true
            end
        end
    end, { groupName = groupName }, timer.getTime() + delay)
end

----------------------------------------------------------------
-- JSON HELPERS
----------------------------------------------------------------
local function validatePersistenceEnvironment()
    if not io or not lfs then
        syncLog("io/lfs no disponibles. Persistencia deshabilitada.")
        return false
    end

    if not net or not net.json2lua then
        syncLog("net.json2lua no disponible. Persistencia deshabilitada.")
        return false
    end

    return true
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
    if not io then
        return nil
    end

    local f = io.open(path, "r")
    if not f then
        return nil
    end

    local txt = f:read("*a")
    f:close()
    return txt
end

local function safeWriteFile(path, txt)
    if not io then
        return false
    end

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
        return nil, "archivo vacio"
    end

    if not net or not net.json2lua then
        return nil, "net.json2lua no disponible"
    end

    local ok, data = pcall(net.json2lua, txt)
    if not ok then
        return nil, data
    end

    if type(data) ~= "table" then
        return nil, "json no devolvio tabla"
    end

    return data
end

local function loadSyncFile()
    local txt = safeReadFile(ACTSYNC.FILE_PATH)
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

local function isArray(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local count = 0
    local maxIndex = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        count = count + 1
        if k > maxIndex then
            maxIndex = k
        end
    end

    return count == maxIndex
end

local function encodeJsonValue(value, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    local t = type(value)

    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return "\"" .. jsonEscape(value) .. "\""
    elseif t ~= "table" then
        return "\"" .. jsonEscape(tostring(value)) .. "\""
    end

    if next(value) == nil then
        return isArray(value) and "[]" or "{}"
    end

    if isArray(value) then
        local lines = {"["}
        for i = 1, #value do
            local comma = (i < #value) and "," or ""
            lines[#lines + 1] = string.rep(" ", indent + 2) .. encodeJsonValue(value[i], indent + 2) .. comma
        end
        lines[#lines + 1] = pad .. "]"
        return table.concat(lines, "\n")
    end

    local keys = sortedKeys(value)
    local lines = {"{"}
    for i, key in ipairs(keys) do
        local comma = (i < #keys) and "," or ""
        lines[#lines + 1] =
            string.rep(" ", indent + 2) ..
            "\"" .. jsonEscape(tostring(key)) .. "\": " ..
            encodeJsonValue(value[key], indent + 2) ..
            comma
    end
    lines[#lines + 1] = pad .. "}"
    return table.concat(lines, "\n")
end

local function saveSyncFile(tbl)
    if not ACTSTATE.persistenceAvailable then
        return false
    end

    local payload = encodeJsonValue(tbl, 0)

    if payload == ACTSTATE.lastSavedPayload and not ACTSTATE.dirty then
        return true
    end

    local ok = safeWriteFile(ACTSYNC.FILE_PATH, payload)
    if ok then
        ACTSTATE.lastSavedPayload = payload
        ACTSTATE.dirty = false
    end
    return ok
end

----------------------------------------------------------------
-- MODULO 1
-- CLONADO POR BANDERA CON NOMBRE RUNTIME FIJO
----------------------------------------------------------------
local function getRuntimeName(templateName)
    return templateName .. "_RUNTIME"
end

local function clonarConNombreFijo(templateName, bandera, lado)
    if not templateName or templateName == "" then
        return false
    end

    local runtimeName = getRuntimeName(templateName)

    destroyGroupIfExists(runtimeName)

    local vars = {
        gpName = templateName,
        action = "clone",
        newGroupName = runtimeName,
        route = mist.getGroupRoute(templateName, "task")
    }

    local ok, result = pcall(function()
        return mist.teleportToPoint(vars)
    end)

    if ok and result then
        debug("Grupo " .. string.upper(lado) .. " '" .. runtimeName .. "' clonado por bandera " .. bandera, 10)
        env.info("[ActivateUnitsCampaing_KOLA] Grupo " .. string.upper(lado) .. " '" .. runtimeName .. "' clonado por bandera " .. bandera)
        return true
    end

    debug("ERROR clonando '" .. tostring(templateName) .. "' como '" .. tostring(runtimeName) .. "'", 10)
    env.info("[ActivateUnitsCampaing_KOLA] ERROR clonando '" .. tostring(templateName) .. "' como '" .. tostring(runtimeName) .. "'")
    return false
end

local function activarLadoClonado(bandera, lado, definicionLado)
    local listaGrupos = convertirALista(definicionLado)

    for i = 1, #listaGrupos do
        clonarConNombreFijo(listaGrupos[i], bandera, lado)
    end
end

local function revisarModuloClonado()
    for bandera, data in pairs(gruposPorBandera) do
        local valor = tonumber(trigger.misc.getUserFlag(bandera)) or 0
        local valorPrevio = estadoPrevioBanderas[bandera]

        if valor ~= valorPrevio then
            estadoPrevioBanderas[bandera] = valor

            if valor == 1 then
                activarLadoClonado(bandera, "rojo", data.rojo)
            elseif valor == 2 then
                activarLadoClonado(bandera, "azul", data.azul)
            end
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- CATALOGO DE GRUPOS PERSISTENTES
----------------------------------------------------------------
local function ensureTrackedGroup(groupName, sourceFlag)
    if not ACTSTATE.trackedGroups[groupName] then
        ACTSTATE.trackedGroups[groupName] = {
            status = 1,
            sourceFlags = {},
            lastChangeTime = 0,
            lastActivatedAt = nil,
            lastSeenAliveAt = nil,

            units = {},
            totalUnits = 0,
            aliveUnits = 0,
            deadUnits = 0
        }
    end

    local rec = ACTSTATE.trackedGroups[groupName]

    rec.units = collectGroupUnitsSnapshot(groupName, rec.units, false)
    local totalUnits, aliveUnits, deadUnits = countUnitsInSnapshot(rec.units)
    rec.totalUnits = totalUnits
    rec.aliveUnits = aliveUnits
    rec.deadUnits = deadUnits

    if sourceFlag ~= nil then
        rec.sourceFlags[sourceFlag] = true
    end

    if not ACTSTATE.runtime[groupName] then
        ACTSTATE.runtime[groupName] = {
            seenAliveOnce = false,
            activationRequested = false,
            activatedThisRun = false
        }
    end
end

local function buildTrackedCatalog()
    for flag, def in pairs(activacionesPorFlag or {}) do
        local lista = convertirALista(def.grupos)
        for i = 1, #lista do
            ensureTrackedGroup(lista[i], flag)
        end
    end
end

local function setTrackedStatus(groupName, newStatus)
    local rec = ACTSTATE.trackedGroups[groupName]
    if not rec then
        return
    end

    local current = tonumber(rec.status) or 1
    newStatus = tonumber(newStatus) or 1

    if current == 2 then
        return
    end

    if newStatus ~= 1 and newStatus ~= 2 then
        newStatus = 1
    end

    if rec.status ~= newStatus then
        rec.status = newStatus
        rec.lastChangeTime = round(timer.getTime(), 3)

        if newStatus == 2 then
            forceDeadUnitsInRecord(rec)
        end

        ACTSTATE.dirty = true
        syncLog("Estado actualizado | " .. tostring(groupName) .. " => " .. tostring(newStatus))
    end
end

local function buildDocFromState()
    local groups = {}

    for groupName, rec in pairs(ACTSTATE.trackedGroups or {}) do
        local rt = ACTSTATE.runtime[groupName]

        rec.units = collectGroupUnitsSnapshot(groupName, rec.units, rt and rt.seenAliveOnce)
        local totalUnits, aliveUnits, deadUnits = countUnitsInSnapshot(rec.units)

        rec.totalUnits = totalUnits
        rec.aliveUnits = aliveUnits
        rec.deadUnits = deadUnits

        if tonumber(rec.status) == 2 then
            forceDeadUnitsInRecord(rec)
        end

        groups[groupName] = {
            status = tonumber(rec.status) or 1,
            sourceFlags = sortedNumericListFromMap(rec.sourceFlags or {}),
            lastChangeTime = rec.lastChangeTime,
            lastActivatedAt = rec.lastActivatedAt,
            lastSeenAliveAt = rec.lastSeenAliveAt,

            totalUnits = rec.totalUnits or 0,
            aliveUnits = rec.aliveUnits or 0,
            deadUnits = rec.deadUnits or 0,
            units = rec.units or {}
        }
    end

    return {
        control = {
            injectDuration = ACTSYNC.INJECT_DURATION,
            injectInterval = ACTSYNC.INJECT_INTERVAL,
            exportInterval = ACTSYNC.EXPORT_INTERVAL,
            trackUnitStatus = ACTSYNC.TRACK_UNIT_STATUS,
            applyDeadUnitsOnSpawn = ACTSYNC.APPLY_DEAD_UNITS_ON_SPAWN,
            applyPartialLife = ACTSYNC.APPLY_PARTIAL_LIFE
        },
        meta = {
            mode = ACTSTATE.injecting and "inject" or "live",
            missionTime = round(timer.getTime(), 3),
            source = "ActivateUnitsCampaing_KOLA",
            unitRestoreMode = "deadUnitsOnly"
        },
        groups = groups
    }
end

local function applyDocToState(doc)
    if type(doc) ~= "table" then
        return
    end

    local savedGroups = doc.groups or {}
    for groupName, saved in pairs(savedGroups) do
        if ACTSTATE.trackedGroups[groupName] then
            local rec = ACTSTATE.trackedGroups[groupName]
            local savedStatus = tonumber(saved.status) or 1

            if savedStatus ~= 2 then
                savedStatus = 1
            end

            rec.status = savedStatus
            rec.lastChangeTime = saved.lastChangeTime or rec.lastChangeTime
            rec.lastActivatedAt = saved.lastActivatedAt or rec.lastActivatedAt
            rec.lastSeenAliveAt = saved.lastSeenAliveAt or rec.lastSeenAliveAt

            if type(saved.units) == "table" then
                rec.units = saved.units

                for unitName, unitData in pairs(rec.units) do
                    if type(unitData) == "table" then
                        rec.units[unitName] = normalizeUnitRecord(unitName, groupName, unitData)
                    end
                end
            end

            rec.units = collectGroupUnitsSnapshot(groupName, rec.units, false)

            local totalUnits, aliveUnits, deadUnits = countUnitsInSnapshot(rec.units)
            rec.totalUnits = tonumber(saved.totalUnits) or totalUnits
            rec.aliveUnits = tonumber(saved.aliveUnits) or aliveUnits
            rec.deadUnits = tonumber(saved.deadUnits) or deadUnits

            if savedStatus == 2 then
                forceDeadUnitsInRecord(rec)

                if ACTSTATE.runtime[groupName] then
                    ACTSTATE.runtime[groupName].seenAliveOnce = true
                end
            end
        end
    end
end

local function isLockedDead(groupName)
    local rec = ACTSTATE.trackedGroups[groupName]
    return rec and tonumber(rec.status) == 2
end

local function enforceDeadLock(groupName, reason)
    if isLockedDead(groupName) then
        local rec = ACTSTATE.trackedGroups[groupName]
        if rec then
            forceDeadUnitsInRecord(rec)
        end

        local destroyed = destroyGroupIfExists(groupName)
        if destroyed then
            syncLog("Grupo bloqueado en 2 destruido por seguridad: " .. tostring(groupName) .. " | motivo=" .. tostring(reason or "N/A"))
        end
        return true
    end
    return false
end

----------------------------------------------------------------
-- MODULO 2
-- ACTIVACION SIMPLE PERSISTENTE
-- MISMA BASE ESTABLE + FILTRO status==2
----------------------------------------------------------------
local function activarGrupoOriginalPersistente(nombreGrupo, bandera)
    if not nombreGrupo or nombreGrupo == "" then
        return false
    end

    if isLockedDead(nombreGrupo) then
        syncLog("Saltado por persistencia, ya murio: " .. tostring(nombreGrupo))
        enforceDeadLock(nombreGrupo, "activarGrupoOriginalPersistente")
        return false
    end

    local grp = Group.getByName(nombreGrupo)
    if not grp then
        debug("No existe grupo en ME: " .. tostring(nombreGrupo), 10)
        env.info("[ActivateUnitsCampaing_KOLA] No existe grupo en ME: " .. tostring(nombreGrupo))
        return false
    end

    local ok, err = pcall(function()
        trigger.action.activateGroup(grp)
    end)

    if ok then
        local rt = ACTSTATE.runtime[nombreGrupo]
        local rec = ACTSTATE.trackedGroups[nombreGrupo]

        if rt then
            rt.activationRequested = true
            rt.activatedThisRun = true
        end

        if rec then
            rec.lastActivatedAt = round(timer.getTime(), 3)

            if tonumber(rec.status) ~= 2 then
                setTrackedStatus(nombreGrupo, 1)
            end
        end

        scheduleApplySavedUnitState(nombreGrupo, ACTSYNC.APPLY_DEAD_UNITS_DELAY)

        debug("Grupo activado por flag " .. tostring(bandera) .. ": " .. tostring(nombreGrupo), 10)
        env.info("[ActivateUnitsCampaing_KOLA] Grupo activado por flag " .. tostring(bandera) .. ": " .. tostring(nombreGrupo))
        return true
    end

    debug("ERROR activando grupo '" .. tostring(nombreGrupo) .. "' por flag " .. tostring(bandera), 10)
    env.info("[ActivateUnitsCampaing_KOLA] ERROR activando grupo '" .. tostring(nombreGrupo) .. "' por flag " .. tostring(bandera) .. ": " .. tostring(err))
    return false
end

local function activarModuloSimple(flag, definicion)
    local listaGrupos = convertirALista(definicion.grupos)

    for i = 1, #listaGrupos do
        activarGrupoOriginalPersistente(listaGrupos[i], flag)
    end
end

----------------------------------------------------------------
-- MODULO 2
-- ESTO QUEDA IGUAL A LA VERSION ESTABLE
----------------------------------------------------------------
local function revisarModuloActivaciones()
    for flag, definicion in pairs(activacionesPorFlag) do
        local valorActual = tonumber(trigger.misc.getUserFlag(flag)) or 0
        local valorPrevio = estadoPrevioActivaciones[flag]
        local valorObjetivo = tonumber(definicion.valor) or 1

        if valorActual ~= valorPrevio then
            estadoPrevioActivaciones[flag] = valorActual

            if valorActual == valorObjetivo then
                activarModuloSimple(flag, definicion)
            end
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- MONITOREO DE VIDA / BLOQUEO DURO DE 2
----------------------------------------------------------------
local function monitorTrackedGroups()
    for groupName, rec in pairs(ACTSTATE.trackedGroups or {}) do
        local rt = ACTSTATE.runtime[groupName]

        if tonumber(rec.status) == 2 then
            forceDeadUnitsInRecord(rec)

            local alive = countAliveUnitsInGroup(groupName)
            if alive > 0 then
                enforceDeadLock(groupName, "monitorTrackedGroups")
            end
        else
            applySavedUnitStateToRuntime(groupName)

            local alive = countAliveUnitsInGroup(groupName)

            if alive > 0 then
                if rt then
                    rt.seenAliveOnce = true
                    rt.activatedThisRun = true
                    rt.activationRequested = true
                end

                rec.lastSeenAliveAt = round(timer.getTime(), 3)
                rec.units = collectGroupUnitsSnapshot(groupName, rec.units, true)
            else
                rec.units = collectGroupUnitsSnapshot(groupName, rec.units, rt and rt.seenAliveOnce)

                if rt and rt.seenAliveOnce then
                    setTrackedStatus(groupName, 2)
                end
            end

            local totalUnits, aliveUnits, deadUnits = countUnitsInSnapshot(rec.units)
            rec.totalUnits = totalUnits
            rec.aliveUnits = aliveUnits
            rec.deadUnits = deadUnits
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- EVENT HANDLER
-- SI EL GRUPO ESTA EN 2, SE DESTRUYE Y NO SE REHABILITA
----------------------------------------------------------------
local function registerSyncEventHandler()
    if ACTSTATE.eventHandlerRegistered then
        return
    end

    world.addEventHandler({
        onEvent = function(_, event)
            if not event or event.id ~= world.event.S_EVENT_BIRTH then
                return
            end

            local initiator = event.initiator
            if not initiator or not initiator.getGroup then
                return
            end

            local grp = initiator:getGroup()
            if not grp then
                return
            end

            local groupName = grp:getName()
            if not ACTSTATE.trackedGroups[groupName] then
                return
            end

            if isLockedDead(groupName) then
                syncLog("BIRTH bloqueado por status 2: " .. tostring(groupName))
                pcall(function()
                    grp:destroy()
                end)
                return
            end

            local rec = ACTSTATE.trackedGroups[groupName]
            local rt = ACTSTATE.runtime[groupName]

            if rt then
                rt.seenAliveOnce = true
                rt.activatedThisRun = true
                rt.activationRequested = true
            end

            if rec then
                rec.lastSeenAliveAt = round(timer.getTime(), 3)
            end

            scheduleApplySavedUnitState(groupName, ACTSYNC.APPLY_DEAD_UNITS_DELAY)

            syncLog("BIRTH detectado en grupo persistente: " .. tostring(groupName))
        end
    })

    ACTSTATE.eventHandlerRegistered = true
end

----------------------------------------------------------------
-- MODULO 2
-- INYECCION JSON -> ESTADO
----------------------------------------------------------------
local function injectFromJson()
    if not ACTSTATE.persistenceAvailable then
        return
    end

    local doc, err = loadSyncFile()

    if doc then
        ACTSTATE.doc = deepCopy(doc)
        applyDocToState(doc)
    else
        if not ACTSTATE.doc then
            ACTSTATE.doc = buildDocFromState()
        end
        syncLog("JSON no encontrado durante inyeccion. " .. tostring(err or ""))
    end

    for groupName, rec in pairs(ACTSTATE.trackedGroups or {}) do
        if tonumber(rec.status) == 2 then
            enforceDeadLock(groupName, "injectFromJson")
        else
            applySavedUnitStateToRuntime(groupName)
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- EXPORTACION DCS -> JSON
----------------------------------------------------------------
local function exportLiveToJson()
    if not ACTSTATE.persistenceAvailable then
        return
    end

    monitorTrackedGroups()
    ACTSTATE.doc = buildDocFromState()
    saveSyncFile(ACTSTATE.doc)
end

----------------------------------------------------------------
-- START SYNC
----------------------------------------------------------------
local function startActivateSync()
    buildTrackedCatalog()
    registerSyncEventHandler()

    ACTSTATE.persistenceAvailable = validatePersistenceEnvironment()

    if ACTSTATE.persistenceAvailable then
        local initialDoc = nil
        local okDoc, _ = loadSyncFile()

        if type(okDoc) == "table" then
            initialDoc = okDoc
            ACTSTATE.doc = deepCopy(initialDoc)
            applyDocToState(initialDoc)
        else
            ACTSTATE.doc = buildDocFromState()
        end

        ACTSTATE.started = true
        ACTSTATE.injecting = (initialDoc ~= nil)
        ACTSTATE.injectEndsAt = timer.getTime() + ACTSYNC.INJECT_DURATION
        ACTSTATE.lastInject = -9999
        ACTSTATE.lastExport = -9999
        ACTSTATE.dirty = true

        if initialDoc then
            syncLog("JSON encontrado. Inyeccion activa por " .. tostring(ACTSYNC.INJECT_DURATION) .. " segundos.")
        else
            syncLog("No habia JSON previo. Se crea snapshot inicial y DCS queda como fuente desde el inicio.")
            exportLiveToJson()
            ACTSTATE.injecting = false
        end
    else
        ACTSTATE.started = true
        ACTSTATE.injecting = false
        ACTSTATE.injectEndsAt = 0
        ACTSTATE.lastInject = -9999
        ACTSTATE.lastExport = -9999
        ACTSTATE.doc = buildDocFromState()
    end
end

----------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------
local function verificarSistema(_, now)
    now = now or timer.getTime()

    revisarModuloClonado()
    revisarModuloActivaciones()

    if ACTSTATE.started then
        if ACTSTATE.persistenceAvailable then
            if ACTSTATE.injecting then
                if now <= ACTSTATE.injectEndsAt then
                    if (now - ACTSTATE.lastInject) >= ACTSYNC.INJECT_INTERVAL then
                        ACTSTATE.lastInject = now
                        injectFromJson()
                        monitorTrackedGroups()
                    end
                else
                    ACTSTATE.injecting = false
                    syncLog("Fin de ventana de inyeccion. DCS toma el control y JSON pasa a espejo vivo.")
                    monitorTrackedGroups()
                    exportLiveToJson()
                    ACTSTATE.lastExport = now
                end
            else
                monitorTrackedGroups()

                if (now - ACTSTATE.lastExport) >= ACTSYNC.EXPORT_INTERVAL then
                    ACTSTATE.lastExport = now
                    exportLiveToJson()
                end
            end
        else
            monitorTrackedGroups()
        end
    end

    return now + intervaloRevision
end

----------------------------------------------------------------
-- ARRANQUE
----------------------------------------------------------------
startActivateSync()
timer.scheduleFunction(verificarSistema, nil, timer.getTime() + intervaloRevision)