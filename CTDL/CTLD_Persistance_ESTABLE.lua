----------------------------------------------------------------
-- HDEV_CTLDDeploymentPersistence_KOLA.lua
--
-- Persistencia de despliegues CTLD
--
-- Version 2.2.0
--
-- Corrige:
-- - Guarda grupos creados por CTLD al desempaquetar crates.
-- - Reinyecta grupos vivos desde JSON al reiniciar la mision.
-- - No cobra dinero al reinyectar.
-- - No guarda injectedThisSession en JSON.
-- - Restaura logica CTLD runtime despues de reinyectar:
--     * JTAC: vuelve a llamar ctld.JTACStart().
--     * AA System: vuelve a registrar ctld.completeAASystems si aplica.
--
-- Cargar despues de:
-- 1. MIST
-- 2. CTLD
-- 3. HookEconomyV2, si lo usas
----------------------------------------------------------------

if not mist or not mist.dynAdd then
    trigger.action.outText("ERROR: MIST no esta cargado o falta mist.dynAdd.", 15)
    return
end

if not ctld or not ctld.spawnCrateGroup then
    trigger.action.outText("ERROR: CTLD no esta cargado o falta ctld.spawnCrateGroup.", 15)
    return
end

HDEV_CTLDDeploymentPersistence = HDEV_CTLDDeploymentPersistence or {}
local CTDP = HDEV_CTLDDeploymentPersistence

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------
CTDP.CONFIG = {
    DEBUG = false,

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\SystemCTLDDeploymentPersistenceKola.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 350,
    MAIN_LOOP_INTERVAL = 1,

    RUNTIME_PREFIX = "HDEV_CTLD_",

    MISSING_DEAD_GRACE = 10,

    -- Tiempo despues de reinyectar para restaurar logica CTLD.
    -- JTACStart ya espera internamente, pero le damos unos segundos extra
    -- para que DCS termine de poblar el grupo.
    RESTORE_CTLD_DELAY = 4,

    -- "all"        = guarda todo lo que CTLD spawnee
    -- "categories" = guarda solo categorias activadas
    -- "units"      = guarda solo unidades activadas en SAVE_UNITS
    SAVE_MODE = "all",

    -- Nombres exactos de categorias dentro de ctld.spawnableCrates.
    SAVE_CATEGORIES = {
        ["SAM Corto Alcance"] = false,
        ["SAM Medio Alcance"] = true,
        ["SAM Largo Alcance"] = false,

        ["Vehiculos de Combate"] = false,

        -- IMPORTANTE:
        -- Dejalo en true si quieres persistir Hummer JTAC, SKP-11 JTAC,
        -- EWR, Ammo Trucks, Tankers, drones, etc. que esten en Soporte Logistico.
        ["Soporte Logistico"] = true,

        ["Artilleria"] = false,
        ["Drones"] = false
    },

    -- Si SAVE_MODE = "units", usa nombres tecnicos de DCS.
    -- Tambien funcionan como permiso extra aunque SAVE_MODE sea categories.
    SAVE_UNITS = {
        -- JTAC / soporte
        ["Hummer"] = true,
        ["SKP-11"] = true,
        ["MQ-9 Reaper"] = true,
        ["RQ-1A Predator"] = true,

        -- Ejemplos AA medio
        -- ["Hawk ln"] = true,
        -- ["Hawk sr"] = true,
        -- ["Hawk tr"] = true,
        -- ["Hawk pcp"] = true,
        -- ["Hawk cwar"] = true,

        -- ["NASAMS_LN_C"] = true,
        -- ["NASAMS_Radar_MPQ64F1"] = true,
        -- ["NASAMS_Command_Post"] = true,

        -- ["Kub 2P25 ln"] = true,
        -- ["Kub 1S91 str"] = true,

        -- ["SA-11 Buk LN 9A310M1"] = true,
        -- ["SA-11 Buk SR 9S18M1"] = true,
        -- ["SA-11 Buk CC 9S470M1"] = true
    },

    -- Si algo esta aqui, nunca se guarda aunque su categoria este activa.
    IGNORE_UNITS = {
        -- ["M 818"] = true,
        -- ["Ural-375"] = true,
        -- ["KAMAZ Truck"] = true
    }
}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
CTDP.STATE = CTDP.STATE or {
    started = false,
    injecting = false,
    writeEnabled = false,

    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,

    doc = nil,
    dirty = false,

    unitToCategory = {},
    unitToCrate = {},

    byGroupName = {},
    byUnitName = {},

    injectedThisSession = {},

    wrapperInstalled = false,
    eventHandlerRegistered = false
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg, time)
    env.info("[CTLD_PERSIST] " .. tostring(msg))

    if CTDP.CONFIG.DEBUG then
        trigger.action.outText("[CTLD_PERSIST] " .. tostring(msg), time or 8)
    end
end

local function warn(msg)
    env.info("[CTLD_PERSIST] " .. tostring(msg))
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function now()
    return timer.getTime()
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

local function safeReadFile(path)
    local f = io.open(path, "r")

    if not f then
        return nil
    end

    local txt = f:read("*a")
    f:close()

    return txt
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
        return "{}"
    end

    if isArray(value) then
        local lines = { "[" }

        for i = 1, #value do
            local comma = (i < #value) and "," or ""

            lines[#lines + 1] =
                string.rep(" ", indent + 2) ..
                encodeJsonValue(value[i], indent + 2) ..
                comma
        end

        lines[#lines + 1] = pad .. "]"

        return table.concat(lines, "\n")
    end

    local keys = sortedKeys(value)
    local lines = { "{" }

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

local function groupExistsByName(groupName)
    if not groupName or groupName == "" then
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

local function unitAlive(unit)
    if not unit then
        return false
    end

    local okExist, exists = pcall(function()
        return unit:isExist()
    end)

    if not okExist or not exists then
        return false
    end

    local okLife, life = pcall(function()
        return unit:getLife()
    end)

    if not okLife then
        return false
    end

    return (tonumber(life) or 0) > 0
end

local function groupHasAliveUnits(groupName)
    local grp = groupExistsByName(groupName)

    if not grp then
        return false
    end

    local ok, units = pcall(function()
        return grp:getUnits()
    end)

    if not ok or not units then
        return false
    end

    for _, unit in ipairs(units) do
        if unitAlive(unit) then
            return true
        end
    end

    return false
end

local function getGroupName(group)
    if not group then
        return nil
    end

    local ok, name = pcall(function()
        return group:getName()
    end)

    if ok then
        return name
    end

    return nil
end

local function getUnitName(unit)
    if not unit then
        return nil
    end

    local ok, name = pcall(function()
        return unit:getName()
    end)

    if ok then
        return name
    end

    return nil
end

local function getUnitType(unit)
    if not unit then
        return nil
    end

    local ok, typeName = pcall(function()
        return unit:getTypeName()
    end)

    if ok then
        return typeName
    end

    return nil
end

local function getUnitHeading(unit)
    if mist and mist.getHeading then
        local ok, heading = pcall(function()
            return mist.getHeading(unit, true)
        end)

        if ok and tonumber(heading) then
            return tonumber(heading)
        end
    end

    local ok, pos = pcall(function()
        return unit:getPosition()
    end)

    if ok and pos and pos.x then
        local h = math.atan2(pos.x.z, pos.x.x)

        if h < 0 then
            h = h + math.pi * 2
        end

        return h
    end

    return 0
end

local function getUnitLife(unit)
    local life = 0
    local life0 = 0

    local okLife, resultLife = pcall(function()
        return unit:getLife()
    end)

    if okLife and tonumber(resultLife) then
        life = tonumber(resultLife)
    end

    local okLife0, resultLife0 = pcall(function()
        return unit:getLife0()
    end)

    if okLife0 and tonumber(resultLife0) then
        life0 = tonumber(resultLife0)
    end

    return life, life0
end

local function lowerText(v)
    return string.lower(tostring(v or ""))
end

----------------------------------------------------------------
-- JSON STATE
----------------------------------------------------------------
local function createEmptyDoc()
    return {
        meta = {
            source = "HDEV CTLD Deployment Persistence",
            version = "2.2.0",
            missionTime = now(),
            updatedBy = "DCS"
        },

        counters = {
            nextId = 1
        },

        deployments = {}
    }
end

local function cleanRuntimeFields(doc)
    if not doc or type(doc.deployments) ~= "table" then
        return
    end

    for _, dep in pairs(doc.deployments or {}) do
        dep.injectedThisSession = nil
    end
end

local function normalizeDoc(doc)
    if type(doc) ~= "table" then
        doc = createEmptyDoc()
    end

    doc.meta = doc.meta or {}
    doc.counters = doc.counters or {}
    doc.deployments = doc.deployments or {}

    cleanRuntimeFields(doc)

    if not tonumber(doc.counters.nextId) then
        doc.counters.nextId = 1
    end

    return doc
end

local function loadState()
    local txt = safeReadFile(CTDP.CONFIG.FILE_PATH)

    if not txt then
        CTDP.STATE.doc = createEmptyDoc()
        CTDP.STATE.dirty = true
        log("JSON no existe. Se creara uno nuevo.", 8)
        return
    end

    local data, err = decodeJson(txt)

    if not data then
        CTDP.STATE.doc = createEmptyDoc()
        CTDP.STATE.dirty = true
        log("No se pudo leer JSON. Se creara uno nuevo. Error: " .. tostring(err), 10)
        return
    end

    CTDP.STATE.doc = normalizeDoc(data)
    log("JSON cargado correctamente.", 6)
end

local function writeState(force)
    if not CTDP.STATE.doc then
        CTDP.STATE.doc = createEmptyDoc()
    end

    cleanRuntimeFields(CTDP.STATE.doc)

    if not force and not CTDP.STATE.dirty then
        return true
    end

    CTDP.STATE.doc.meta = CTDP.STATE.doc.meta or {}
    CTDP.STATE.doc.meta.source = "HDEV CTLD Deployment Persistence"
    CTDP.STATE.doc.meta.version = "2.2.0"
    CTDP.STATE.doc.meta.missionTime = now()
    CTDP.STATE.doc.meta.updatedBy = "DCS"
    CTDP.STATE.doc.meta.injectDuration = CTDP.CONFIG.INJECT_DURATION
    CTDP.STATE.doc.meta.exportInterval = CTDP.CONFIG.EXPORT_INTERVAL

    local txt = encodeJsonValue(CTDP.STATE.doc, 0)
    local ok = safeWriteFile(CTDP.CONFIG.FILE_PATH, txt)

    if ok then
        CTDP.STATE.dirty = false
        CTDP.STATE.lastExport = now()
        return true
    end

    warn("No se pudo escribir JSON: " .. tostring(CTDP.CONFIG.FILE_PATH))
    return false
end

local function nextDeploymentId()
    local doc = CTDP.STATE.doc

    if not doc then
        doc = createEmptyDoc()
        CTDP.STATE.doc = doc
    end

    doc.counters = doc.counters or {}

    local n = tonumber(doc.counters.nextId) or 1
    local id = nil

    repeat
        id = string.format("CTLD_DEPLOY_%06d", n)
        n = n + 1
    until not doc.deployments[id]

    doc.counters.nextId = n

    return id
end

----------------------------------------------------------------
-- INDICE DE CATEGORIAS CTLD
----------------------------------------------------------------
local function buildCtldIndexes()
    CTDP.STATE.unitToCategory = {}
    CTDP.STATE.unitToCrate = {}

    for categoryName, list in pairs(ctld.spawnableCrates or {}) do
        for _, crate in ipairs(list or {}) do
            if crate.unit then
                CTDP.STATE.unitToCategory[tostring(crate.unit)] = tostring(categoryName)

                CTDP.STATE.unitToCrate[tostring(crate.unit)] = {
                    categoryName = tostring(categoryName),
                    unit = crate.unit,
                    desc = crate.desc,
                    weight = crate.weight,
                    cratesRequired = crate.cratesRequired,
                    side = crate.side
                }
            end
        end
    end

    log("Indice CTLD construido. Unidades indexadas: " .. tostring(#sortedKeys(CTDP.STATE.unitToCategory)), 6)
end

local function getCategoryForUnitType(typeName)
    if not typeName then
        return nil
    end

    return CTDP.STATE.unitToCategory[tostring(typeName)]
end

local function getCrateInfoForUnitType(typeName)
    if not typeName then
        return nil
    end

    return CTDP.STATE.unitToCrate[tostring(typeName)]
end

local function shouldPersistTypes(types)
    if CTDP.CONFIG.SAVE_MODE == "all" then
        return true, "all"
    end

    for _, typeName in ipairs(types or {}) do
        local t = tostring(typeName or "")

        if t ~= "" and not CTDP.CONFIG.IGNORE_UNITS[t] then
            if CTDP.CONFIG.SAVE_UNITS[t] then
                return true, "unit:" .. t
            end

            local categoryName = getCategoryForUnitType(t)

            if CTDP.CONFIG.SAVE_MODE == "categories"
                and categoryName
                and CTDP.CONFIG.SAVE_CATEGORIES[categoryName] == true then

                return true, "category:" .. categoryName
            end
        end
    end

    if CTDP.CONFIG.SAVE_MODE == "units" then
        return false, "no unit match"
    end

    return false, "no category match"
end

----------------------------------------------------------------
-- DETECCION DE ROLES CTLD
----------------------------------------------------------------
local function isCtldJtacType(typeName)
    if not typeName then
        return false
    end

    local t = lowerText(typeName)

    for _, jtacPattern in ipairs(ctld.jtacUnitTypes or {}) do
        local p = lowerText(jtacPattern)

        if p ~= "" and string.find(t, p, 1, true) then
            return true
        end
    end

    return false
end

local function deploymentContainsJtac(dep)
    if not dep then
        return false
    end

    if dep.ctldRole == "JTAC" then
        return true
    end

    if dep.crateUnit and isCtldJtacType(dep.crateUnit) then
        return true
    end

    for _, typeName in ipairs(dep.types or {}) do
        if isCtldJtacType(typeName) then
            return true
        end
    end

    if dep.groupData and dep.groupData.units then
        for _, unitData in ipairs(dep.groupData.units) do
            if isCtldJtacType(unitData.type) then
                return true
            end
        end
    end

    return false
end

local function getFreshLaserCode()
    ctld.jtacGeneratedLaserCodes = ctld.jtacGeneratedLaserCodes or {}

    local code = table.remove(ctld.jtacGeneratedLaserCodes, 1)

    if code then
        table.insert(ctld.jtacGeneratedLaserCodes, code)
        return tonumber(code)
    end

    return 1688
end

local function restoreJTACIfNeeded(dep, groupName)
    if not dep or not groupName or not ctld or not ctld.JTACStart then
        return false
    end

    if not deploymentContainsJtac(dep) then
        return false
    end

    local code = tonumber(dep.jtacLaserCode) or getFreshLaserCode() or 1688
    dep.jtacLaserCode = code
    dep.ctldRole = "JTAC"

    timer.scheduleFunction(function()
        local grp = Group.getByName(groupName)

        if grp and grp:isExist() then
            ctld.JTACStart(groupName, code)

            env.info("[CTLD_PERSIST] JTAC restaurado: " .. tostring(groupName) .. " | code=" .. tostring(code))

            if CTDP.CONFIG.DEBUG then
                trigger.action.outText(
                    "[CTLD_PERSIST] JTAC restaurado: " ..
                    tostring(groupName) ..
                    " | code=" ..
                    tostring(code),
                    8
                )
            end
        end

        return nil
    end, nil, timer.getTime() + 2)

    CTDP.STATE.dirty = true
    return true
end

local function restoreAASystemIfNeeded(dep, groupName)
    if not dep or not groupName or not ctld then
        return false
    end

    if not ctld.getAATemplate or not ctld.getAASystemDetails then
        return false
    end

    local grp = Group.getByName(groupName)

    if not grp or not grp:isExist() then
        return false
    end

    local units = grp:getUnits() or {}
    local selectedTemplate = nil

    for _, unit in ipairs(units) do
        if unit and unit:isExist() and unit:getLife() > 0 then
            local typeName = unit:getTypeName()
            local aaTemplate = ctld.getAATemplate(typeName)

            if aaTemplate then
                selectedTemplate = aaTemplate
                break
            end
        end
    end

    if not selectedTemplate then
        return false
    end

    ctld.completeAASystems = ctld.completeAASystems or {}
    ctld.completeAASystems[groupName] = ctld.getAASystemDetails(grp, selectedTemplate)

    dep.ctldRole = "AA_SYSTEM"
    dep.ctldAASystemName = selectedTemplate.name or "AA_SYSTEM"

    CTDP.STATE.dirty = true

    env.info(
        "[CTLD_PERSIST] Sistema AA restaurado en CTLD: " ..
        tostring(groupName) ..
        " | sistema=" ..
        tostring(dep.ctldAASystemName)
    )

    if CTDP.CONFIG.DEBUG then
        trigger.action.outText(
            "[CTLD_PERSIST] Sistema AA restaurado en CTLD: " ..
            tostring(groupName) ..
            " | sistema=" ..
            tostring(dep.ctldAASystemName),
            8
        )
    end

    return true
end

local function restoreCtldRuntimeForDeployment(dep, groupName)
    if not dep or not groupName then
        return
    end

    local restoredJtac = restoreJTACIfNeeded(dep, groupName)
    local restoredAA = restoreAASystemIfNeeded(dep, groupName)

    if restoredJtac or restoredAA then
        writeState(true)
    end
end

----------------------------------------------------------------
-- CAPTURA DE GRUPOS
----------------------------------------------------------------
local function captureGroupData(group, forcedName)
    if not group then
        return nil
    end

    local groupName = forcedName or getGroupName(group)

    if not groupName then
        return nil
    end

    local okUnits, units = pcall(function()
        return group:getUnits()
    end)

    if not okUnits or not units or #units == 0 then
        return nil
    end

    local groupCategory = Group.Category.GROUND

    local okCat, cat = pcall(function()
        return group:getCategory()
    end)

    if okCat and cat ~= nil then
        groupCategory = cat
    end

    local firstAliveUnit = nil

    for _, unit in ipairs(units) do
        if unitAlive(unit) then
            firstAliveUnit = unit
            break
        end
    end

    firstAliveUnit = firstAliveUnit or units[1]

    local coalitionValue = 2
    local countryValue = 2

    if firstAliveUnit then
        local okCoal, coal = pcall(function()
            return firstAliveUnit:getCoalition()
        end)

        if okCoal and tonumber(coal) then
            coalitionValue = tonumber(coal)
        end

        local okCountry, countryValueResult = pcall(function()
            return firstAliveUnit:getCountry()
        end)

        if okCountry and tonumber(countryValueResult) then
            countryValue = tonumber(countryValueResult)
        end
    end

    local groupData = {
        visible = false,
        hidden = false,
        name = groupName,
        task = "Ground Nothing",
        tasks = {},
        route = {},
        units = {},
        category = groupCategory,
        country = countryValue
    }

    if groupCategory == Group.Category.AIRPLANE then
        groupData.task = "Reconnaissance"
    end

    local unitTypes = {}

    for i, unit in ipairs(units) do
        if unitAlive(unit) then
            local p = unit:getPoint()
            local typeName = getUnitType(unit)
            local life, life0 = getUnitLife(unit)

            unitTypes[#unitTypes + 1] = typeName

            local unitData = {
                type = typeName,
                name = getUnitName(unit) or (groupName .. "_U" .. tostring(i)),
                x = p.x,
                y = p.z,
                heading = getUnitHeading(unit),
                skill = "Excellent",
                life = life,
                life0 = life0
            }

            if groupCategory == Group.Category.AIRPLANE then
                unitData.alt = p.y
                unitData.alt_type = "BARO"
                unitData.speed = 80
            end

            groupData.units[#groupData.units + 1] = unitData
        end
    end

    if #groupData.units == 0 then
        return nil
    end

    return groupData, coalitionValue, countryValue, groupCategory, unitTypes
end

local function makeRuntimeName(id)
    return CTDP.CONFIG.RUNTIME_PREFIX .. tostring(id)
end

local function deploymentAlreadyExistsForGroup(groupName)
    if not groupName or not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then
        return nil
    end

    for id, dep in pairs(CTDP.STATE.doc.deployments) do
        if dep.originalGroupName == groupName
            or dep.activeGroupName == groupName
            or dep.runtimeGroupName == groupName then

            return id
        end
    end

    return nil
end

local function indexDeployment(dep)
    if not dep or not dep.id then
        return
    end

    local names = {
        dep.originalGroupName,
        dep.activeGroupName,
        dep.runtimeGroupName
    }

    for _, name in ipairs(names) do
        if name and name ~= "" then
            CTDP.STATE.byGroupName[name] = dep.id
        end
    end

    if dep.groupData and dep.groupData.units then
        for _, unitData in ipairs(dep.groupData.units) do
            if unitData.name then
                CTDP.STATE.byUnitName[unitData.name] = dep.id
            end
        end
    end

    if dep.runtimeGroupName then
        for i = 1, 40 do
            CTDP.STATE.byUnitName[dep.runtimeGroupName .. "_U" .. tostring(i)] = dep.id
        end
    end
end

local function rebuildIndexes()
    CTDP.STATE.byGroupName = {}
    CTDP.STATE.byUnitName = {}

    if not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then
        return
    end

    for _, dep in pairs(CTDP.STATE.doc.deployments) do
        indexDeployment(dep)
    end
end

local function recordCtldSpawnedGroup(groupName, typesFromCtld, heliName)
    if CTDP.STATE.injecting then
        return
    end

    local group = groupExistsByName(groupName)

    if not group then
        log("No se pudo capturar. Grupo no existe: " .. tostring(groupName), 8)
        return
    end

    local groupData, coalitionValue, countryValue, groupCategory, unitTypes =
        captureGroupData(group, groupName)

    if not groupData then
        log("No se pudo capturar groupData: " .. tostring(groupName), 8)
        return
    end

    local typesToEvaluate = {}

    for _, t in ipairs(typesFromCtld or {}) do
        if t then
            typesToEvaluate[#typesToEvaluate + 1] = t
        end
    end

    for _, t in ipairs(unitTypes or {}) do
        if t then
            typesToEvaluate[#typesToEvaluate + 1] = t
        end
    end

    local allowed, reason = shouldPersistTypes(typesToEvaluate)

    if not allowed then
        if CTDP.CONFIG.DEBUG then
            log("Ignorado por filtro: " .. tostring(groupName) .. " | " .. tostring(reason), 6)
        end
        return
    end

    local existingId = deploymentAlreadyExistsForGroup(groupName)

    if existingId then
        local existing = CTDP.STATE.doc.deployments[existingId]

        if existing then
            existing.alive = true
            existing.activeGroupName = groupName
            existing.groupData = groupData
            existing.coalition = coalitionValue
            existing.country = countryValue
            existing.groupCategory = groupCategory
            existing.lastSeenAt = now()
            existing.updatedAt = now()
            existing.lastReason = reason
            existing.injectedThisSession = nil

            if deploymentContainsJtac(existing) then
                existing.ctldRole = "JTAC"
                existing.jtacLaserCode = existing.jtacLaserCode or getFreshLaserCode()
            end

            indexDeployment(existing)

            CTDP.STATE.dirty = true
            writeState(true)

            log("Despliegue actualizado: " .. tostring(existingId) .. " | " .. tostring(reason), 8)
        end

        return
    end

    local id = nextDeploymentId()
    local runtimeName = makeRuntimeName(id)

    local mainType = nil
    local mainCategory = nil
    local mainDesc = nil
    local mainWeight = nil

    for _, t in ipairs(typesToEvaluate) do
        local info = getCrateInfoForUnitType(t)

        if info then
            mainType = info.unit
            mainCategory = info.categoryName
            mainDesc = info.desc
            mainWeight = info.weight
            break
        end
    end

    local dep = {
        id = id,
        enabled = true,
        alive = true,

        source = "CTLD",
        captureMethod = "spawnCrateGroup_wrapper",

        reason = reason,

        crateUnit = mainType,
        crateDesc = mainDesc,
        crateWeight = mainWeight,
        categoryName = mainCategory,

        originalGroupName = groupName,
        activeGroupName = groupName,
        runtimeGroupName = runtimeName,

        heliName = heliName,

        coalition = coalitionValue,
        country = countryValue,
        groupCategory = groupCategory,

        createdAt = now(),
        updatedAt = now(),
        lastSeenAt = now(),
        destroyedAt = nil,
        destroyReason = nil,

        types = typesToEvaluate,
        groupData = groupData
    }

    if deploymentContainsJtac(dep) then
        dep.ctldRole = "JTAC"
        dep.jtacLaserCode = getFreshLaserCode()
    end

    CTDP.STATE.doc.deployments[id] = dep

    indexDeployment(dep)

    CTDP.STATE.dirty = true
    writeState(true)

    log(
        "Despliegue CTLD guardado: " ..
        tostring(id) ..
        " | grupo=" .. tostring(groupName) ..
        " | " .. tostring(reason),
        10
    )
end

----------------------------------------------------------------
-- WRAPPER DE CTLD
----------------------------------------------------------------
local function installCtldSpawnWrapper()
    if CTDP.STATE.wrapperInstalled then
        return
    end

    if ctld._HDEV_CTDP_originalSpawnCrateGroup then
        CTDP.STATE.wrapperInstalled = true
        return
    end

    ctld._HDEV_CTDP_originalSpawnCrateGroup = ctld.spawnCrateGroup

    ctld.spawnCrateGroup = function(_heli, _positions, _types, _hdgs)
        local spawnedGroup = ctld._HDEV_CTDP_originalSpawnCrateGroup(_heli, _positions, _types, _hdgs)

        local groupName = nil
        local heliName = nil
        local typesCopy = {}

        if spawnedGroup and spawnedGroup.getName then
            local okName, resultName = pcall(function()
                return spawnedGroup:getName()
            end)

            if okName then
                groupName = resultName
            end
        end

        if _heli and _heli.getName then
            local okHeli, resultHeli = pcall(function()
                return _heli:getName()
            end)

            if okHeli then
                heliName = resultHeli
            end
        end

        for _, t in ipairs(_types or {}) do
            typesCopy[#typesCopy + 1] = t
        end

        if groupName then
            timer.scheduleFunction(function()
                recordCtldSpawnedGroup(groupName, typesCopy, heliName)
                return nil
            end, nil, timer.getTime() + 1)
        else
            log("CTLD spawneo algo, pero no pude leer el nombre del grupo.", 8)
        end

        return spawnedGroup
    end

    CTDP.STATE.wrapperInstalled = true
    log("Wrapper instalado sobre ctld.spawnCrateGroup.", 8)
end

----------------------------------------------------------------
-- MUERTE DE DESPLIEGUES
----------------------------------------------------------------
local function getDeploymentById(id)
    if not id or not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then
        return nil
    end

    return CTDP.STATE.doc.deployments[id]
end

local function findDeploymentIdFromGroupName(groupName)
    if not groupName then
        return nil
    end

    if CTDP.STATE.byGroupName[groupName] then
        return CTDP.STATE.byGroupName[groupName]
    end

    if not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then
        return nil
    end

    for id, dep in pairs(CTDP.STATE.doc.deployments) do
        if dep.originalGroupName == groupName
            or dep.activeGroupName == groupName
            or dep.runtimeGroupName == groupName then

            return id
        end
    end

    return nil
end

local function markDeploymentDestroyed(id, reason)
    local dep = getDeploymentById(id)

    if not dep then
        return
    end

    if dep.alive == false then
        return
    end

    dep.alive = false
    dep.destroyedAt = now()
    dep.destroyReason = reason or "dead"
    dep.updatedAt = now()
    dep.injectedThisSession = nil

    CTDP.STATE.dirty = true
    writeState(true)

    log("Despliegue destruido: " .. tostring(id), 8)
end

local function checkDeploymentDestroyed(id)
    local dep = getDeploymentById(id)

    if not dep or dep.alive == false then
        return
    end

    local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName

    if groupHasAliveUnits(groupName) then
        return
    end

    markDeploymentDestroyed(id, "group_dead")
end

local function registerDeathEventHandler()
    if CTDP.STATE.eventHandlerRegistered then
        return
    end

    world.addEventHandler({
        onEvent = function(_, event)
            if not event or not event.id then
                return
            end

            if event.id ~= world.event.S_EVENT_DEAD
                and event.id ~= world.event.S_EVENT_CRASH then

                return
            end

            local obj = event.initiator or event.target

            if not obj then
                return
            end

            local id = nil

            local unitName = getUnitName(obj)

            if unitName and CTDP.STATE.byUnitName[unitName] then
                id = CTDP.STATE.byUnitName[unitName]
            end

            if not id and obj.getGroup then
                local ok, grp = pcall(function()
                    return obj:getGroup()
                end)

                if ok and grp then
                    id = findDeploymentIdFromGroupName(getGroupName(grp))
                end
            end

            if id then
                timer.scheduleFunction(function()
                    checkDeploymentDestroyed(id)
                    return nil
                end, nil, timer.getTime() + 2)
            end
        end
    })

    CTDP.STATE.eventHandlerRegistered = true
    log("Event handler de muerte registrado.", 6)
end

----------------------------------------------------------------
-- INYECCION DESDE JSON
----------------------------------------------------------------
local function prepareGroupDataForSpawn(dep)
    if not dep or type(dep.groupData) ~= "table" then
        return nil
    end

    local gd = deepCopy(dep.groupData)
    local runtimeName = dep.runtimeGroupName or makeRuntimeName(dep.id)

    gd.name = runtimeName
    gd.groupId = nil
    gd.clone = true

    gd.country = tonumber(dep.country) or tonumber(gd.country) or 2
    gd.category = tonumber(dep.groupCategory) or tonumber(gd.category) or Group.Category.GROUND

    gd.units = gd.units or {}

    for i, unitData in ipairs(gd.units) do
        unitData.name = runtimeName .. "_U" .. tostring(i)
        unitData.unitId = nil
        unitData.life = nil
        unitData.life0 = nil

        if not unitData.skill then
            unitData.skill = "Excellent"
        end
    end

    return gd
end

local function destroyGroupIfExists(groupName)
    local grp = groupExistsByName(groupName)

    if grp then
        pcall(function()
            grp:destroy()
        end)
    end
end

local function scheduleCtldRestore(dep, groupName)
    if not dep or not groupName then
        return
    end

    timer.scheduleFunction(function()
        restoreCtldRuntimeForDeployment(dep, groupName)
        return nil
    end, nil, timer.getTime() + (tonumber(CTDP.CONFIG.RESTORE_CTLD_DELAY) or 4))
end

local function injectDeployment(dep)
    if not dep or dep.enabled == false or dep.alive == false then
        return false
    end

    if not dep.id then
        return false
    end

    if CTDP.STATE.injectedThisSession[dep.id] == true then
        return false
    end

    dep.injectedThisSession = nil
    dep.runtimeGroupName = dep.runtimeGroupName or makeRuntimeName(dep.id)

    local existing = groupExistsByName(dep.runtimeGroupName)

    if existing and groupHasAliveUnits(dep.runtimeGroupName) then
        dep.activeGroupName = dep.runtimeGroupName
        CTDP.STATE.injectedThisSession[dep.id] = true
        indexDeployment(dep)
        scheduleCtldRestore(dep, dep.runtimeGroupName)
        return false
    end

    destroyGroupIfExists(dep.runtimeGroupName)

    local groupData = prepareGroupDataForSpawn(dep)

    if not groupData or not groupData.units or #groupData.units == 0 then
        log("No hay groupData valido para inyectar: " .. tostring(dep.id), 8)
        return false
    end

    local ok, result = pcall(function()
        return mist.dynAdd(groupData)
    end)

    if not ok or not result then
        log("Error inyectando " .. tostring(dep.id) .. ": " .. tostring(result), 10)
        return false
    end

    local spawnedName = nil

    if type(result) == "table" then
        spawnedName = result.name or result.groupName
    elseif type(result) == "string" then
        spawnedName = result
    end

    spawnedName = spawnedName or groupData.name

    dep.activeGroupName = spawnedName
    CTDP.STATE.injectedThisSession[dep.id] = true
    dep.lastInjectedAt = now()
    dep.lastSeenAt = now()
    dep.updatedAt = now()
    dep.injectedThisSession = nil

    indexDeployment(dep)

    CTDP.STATE.dirty = true

    log("Despliegue inyectado: " .. tostring(dep.id) .. " | " .. tostring(spawnedName), 8)

    scheduleCtldRestore(dep, spawnedName)

    return true
end

local function injectFromJson()
    if not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then
        return
    end

    local count = 0

    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.deployments)) do
        local dep = CTDP.STATE.doc.deployments[id]

        if injectDeployment(dep) then
            count = count + 1
        end
    end

    if count > 0 then
        writeState(true)
    end
end

----------------------------------------------------------------
-- EXPORTACION
----------------------------------------------------------------
local function updateDeploymentFromWorld(dep)
    if not dep or dep.alive == false then
        return
    end

    dep.injectedThisSession = nil

    local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName
    local grp = groupExistsByName(groupName)

    if grp and groupHasAliveUnits(groupName) then
        local groupData, coalitionValue, countryValue, groupCategory, unitTypes =
            captureGroupData(grp, groupName)

        if groupData then
            dep.groupData = groupData
            dep.coalition = coalitionValue
            dep.country = countryValue
            dep.groupCategory = groupCategory
            dep.types = unitTypes
            dep.lastSeenAt = now()
            dep.updatedAt = now()
            dep.injectedThisSession = nil

            if deploymentContainsJtac(dep) then
                dep.ctldRole = "JTAC"
                dep.jtacLaserCode = dep.jtacLaserCode or getFreshLaserCode()
            end

            indexDeployment(dep)

            CTDP.STATE.dirty = true
        end

        return
    end

    local lastSeen = tonumber(dep.lastSeenAt) or tonumber(dep.createdAt) or now()
    local missingFor = now() - lastSeen

    if missingFor >= (tonumber(CTDP.CONFIG.MISSING_DEAD_GRACE) or 10) then
        dep.alive = false
        dep.destroyedAt = now()
        dep.destroyReason = "missing_on_export"
        dep.updatedAt = now()
        dep.injectedThisSession = nil

        CTDP.STATE.dirty = true
    end
end

local function exportToJson()
    if not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then
        return
    end

    rebuildIndexes()

    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.deployments)) do
        updateDeploymentFromWorld(CTDP.STATE.doc.deployments[id])
    end

    cleanRuntimeFields(CTDP.STATE.doc)
    writeState(true)
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------
function CTDP.forceSave()
    exportToJson()
end

function CTDP.showStatus()
    local total = 0
    local alive = 0
    local dead = 0
    local jtac = 0
    local aa = 0

    if CTDP.STATE.doc and CTDP.STATE.doc.deployments then
        for _, dep in pairs(CTDP.STATE.doc.deployments) do
            total = total + 1

            if dep.alive == false then
                dead = dead + 1
            else
                alive = alive + 1
            end

            if dep.ctldRole == "JTAC" then
                jtac = jtac + 1
            elseif dep.ctldRole == "AA_SYSTEM" then
                aa = aa + 1
            end
        end
    end

    trigger.action.outText(
        "CTLD Persistence\n" ..
        "Total: " .. tostring(total) .. "\n" ..
        "Vivos: " .. tostring(alive) .. "\n" ..
        "Destruidos: " .. tostring(dead) .. "\n" ..
        "JTAC: " .. tostring(jtac) .. "\n" ..
        "AA Systems: " .. tostring(aa) .. "\n" ..
        "JSON: " .. tostring(CTDP.CONFIG.FILE_PATH),
        12
    )
end

----------------------------------------------------------------
-- LOOP
----------------------------------------------------------------
local function mainLoop()
    if not CTDP.STATE.started then
        return nil
    end

    local t = now()

    if CTDP.STATE.injecting then
        if t <= CTDP.STATE.injectEndsAt then
            if (t - CTDP.STATE.lastInject) >= (tonumber(CTDP.CONFIG.INJECT_INTERVAL) or 1) then
                CTDP.STATE.lastInject = t
                injectFromJson()
            end
        else
            CTDP.STATE.injecting = false
            CTDP.STATE.writeEnabled = true
            rebuildIndexes()
            exportToJson()
            log("Ventana de inyeccion finalizada. DCS toma control del JSON.", 8)
        end
    end

    if CTDP.STATE.writeEnabled then
        if (t - CTDP.STATE.lastExport) >= (tonumber(CTDP.CONFIG.EXPORT_INTERVAL) or 60) then
            exportToJson()
        end
    end

    return timer.getTime() + (tonumber(CTDP.CONFIG.MAIN_LOOP_INTERVAL) or 1)
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
local function start()
    if CTDP.STATE.started then
        return
    end

    CTDP.STATE.started = true
    CTDP.STATE.injecting = true
    CTDP.STATE.writeEnabled = false
    CTDP.STATE.injectEndsAt = now() + (tonumber(CTDP.CONFIG.INJECT_DURATION) or 30)
    CTDP.STATE.lastInject = -9999
    CTDP.STATE.lastExport = -9999

    CTDP.STATE.injectedThisSession = {}

    loadState()
    cleanRuntimeFields(CTDP.STATE.doc)
    buildCtldIndexes()
    rebuildIndexes()
    installCtldSpawnWrapper()
    registerDeathEventHandler()

    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)

    log(
        "Sistema iniciado. Inyectando JSON durante " ..
        tostring(CTDP.CONFIG.INJECT_DURATION) ..
        " segundos.",
        10
    )
end

start()