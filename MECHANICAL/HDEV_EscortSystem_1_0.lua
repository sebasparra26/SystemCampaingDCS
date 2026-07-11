----------------------------------------------------------------
-- HDEV_EscortSystem_1_1.lua
-- Sistema HDEV de escoltas dinamicas para DCS World
--
-- CARGA:
-- 1) mist_4_5_128.lua
-- 2) HDEV_EscortSystem_1_1.lua
--
-- Optimizado para jugadores que nacen exclusivamente en Dynamic Slots.
-- NO requiere slots Client tradicionales en el Mission Editor.
-- NO requiere MOOSE.
-- NO usa dofile.
----------------------------------------------------------------

if not mist or not mist.dynAdd or not mist.getGroupRoute then
    trigger.action.outText("ERROR HDEV ESCORT: MIST no esta cargado o faltan funciones requeridas.", 15)
    return
end

HDEV_EscortSystem = HDEV_EscortSystem or {}
local HES = HDEV_EscortSystem

HES.VERSION = "1.1.0-DYNAMIC-SLOTS"

----------------------------------------------------------------
-- CONFIGURACION EDITABLE
----------------------------------------------------------------
HES.CONFIG = HES.CONFIG or {
    DEBUG = true,

    MENU_NAME = "HDEV ESCOLTAS",
    MENU_SCAN_INTERVAL = 5,

    MINIMUM_AGL = 200,
    MINIMUM_SPEED = 50,

    DEFAULT_ESCORT_DISTANCE = 1500,
    MIN_ESCORT_DISTANCE = 300,
    MAX_ESCORT_DISTANCE = 5000,

    -- Distancia dentro de la cual la escolta puede atacar amenazas.
    -- El JSON real del Mission Editor exporto 60000 metros.
    ENGAGEMENT_DISTANCE = 60000,

    -- Posicion relativa local. En la tarea Escort real:
    -- pos.x = longitudinal, pos.y = vertical, pos.z = lateral.
    FORMATION_OFFSET = {
        lateral = 500,
        vertical = 100,
    },

    SPAWN_OFFSET = {
        longitudinal = -1500,
        lateral = 500,
        vertical = 100,
    },

    SPAWN_MIN_AGL = 150,
    SPAWN_CLEARANCE_RADIUS = 300,
    SPAWN_MIN_PLAYER_SEPARATION = 300,
    SPAWN_MAX_ATTEMPTS = 8,

    MARK_REQUEST_RADIUS = 10000,
    MARK_AMBIGUITY_DISTANCE = 500,
    AUTO_REMOVE_MARK = true,

    DEFAULT_MODE = "ESCORT",
    ALLOWED_MODES = {
        ESCORT = true,
        CAP = true,
        CAS = true,
        SEAD = true,
        STRIKE = true,
    },

    MODE_RADII = {
        CAP = 45000,
        CAS = 20000,
        SEAD = 35000,
    },

    MODE_TASK_REFRESH_DISTANCE = 10000,
    STRIKE_RETURN_SECONDS = 180,

    MONITOR_INTERVAL = 2,
    MAX_SEPARATION_DISTANCE = 30000,
    RECOVERY_REAPPLY_COOLDOWN = 15,
    RECOVERY_RESPAWN_DELAY = 20,
    MAX_RECOVERY_REAPPLIES = 2,
    ALLOW_SAFE_RESPAWN = true,
    MAX_RESPAWNS_PER_ESCORT = 3,
    COMBAT_GRACE_SECONDS = 90,

    STOPPED_ESCORT_SPEED = 20,
    STOPPED_ESCORT_SECONDS = 12,

    SET_TASK_DELAY = 1,
    SET_TASK_RETRIES = 5,
    SET_TASK_RETRY_INTERVAL = 1,

    REMOVE_ON_PLAYER_LANDING = true,
    LANDING_STOP_SECONDS = 20,
    LANDING_STOP_SPEED = 2,

    PLAYER_MISSING_GRACE = 10,

    DESTROY_DELAY_ON_CANCEL = 1,

    -- Limites de velocidad usados solamente al crear la IA.
    AIRPLANE_SPAWN_SPEED_MIN = 90,
    AIRPLANE_SPAWN_SPEED_MAX = 350,
    HELICOPTER_SPAWN_SPEED_MIN = 35,
    HELICOPTER_SPAWN_SPEED_MAX = 120,

    ----------------------------------------------------------------
    -- PAYLOAD DE SLOTS DINAMICOS
    ----------------------------------------------------------------
    -- En esta version el Mission Editor NO es la fuente principal.
    -- El orden real es:
    -- 1) Registro exacto/proveedor externo del slot dinamico.
    -- 2) Datos runtime/dinamicos de MIST si contienen payload.
    -- 3) Perfil configurado que coincida con Unit:getAmmo().
    -- 4) Payload por defecto del tipo de aeronave.
    -- 5) Fallback vacio, salvo que BLOCK_IF_PAYLOAD_UNKNOWN=true.
    DYNAMIC_SLOTS_ONLY = true,
    ALLOW_MISSION_EDITOR_FALLBACK = false,

    BLOCK_IF_PAYLOAD_UNKNOWN = false,
    PAYLOAD_MATCH_MIN_SCORE = 0.72,
    PAYLOAD_MATCH_AMBIGUITY_MARGIN = 0.08,
    PAYLOAD_ALLOW_SPENT_WEAPONS = true,
    PAYLOAD_IGNORE_SHELLS = true,
    SHOW_PAYLOAD_DIAGNOSTIC_MENU = true,
    PAYLOAD_DIAGNOSTIC_MAX_LINES = 12,
}

----------------------------------------------------------------
-- REGISTROS EDITABLES DE PAYLOAD
----------------------------------------------------------------
-- Registro exacto. Puede llenarlo otro sistema antes de solicitar la escolta:
-- HDEV_DYNAMIC_SLOT_PAYLOADS[unitName] = {
--     payload = deepCopy(unitData.payload),
--     livery_id = unitData.livery_id,
--     AddPropAircraft = deepCopy(unitData.AddPropAircraft),
-- }
HDEV_DYNAMIC_SLOT_PAYLOADS = HDEV_DYNAMIC_SLOT_PAYLOADS or {}
HES.DYNAMIC_PAYLOAD_REGISTRY = HES.DYNAMIC_PAYLOAD_REGISTRY or {}
HES.PAYLOAD_PROVIDERS = HES.PAYLOAD_PROVIDERS or {}

-- Perfiles para reconocer automaticamente el armamento observado con Unit:getAmmo().
-- Deben contener el payload REAL con CLSID y la firma de armas esperada.
-- Ejemplo de formato:
-- HES.PAYLOAD_PROFILES["FA-18C_hornet"] = {
--     {
--         name = "CAP PERSONAL",
--         priority = 100,
--         weapons = {
--             ["AIM-120C"] = 6,
--             ["AIM-9X"] = 2,
--         },
--         payload = {
--             fuel = 4900, flare = 60, chaff = 60, gun = 100,
--             pylons = {
--                 -- [1] = { CLSID = "..." },
--             },
--         },
--     },
-- }
HES.PAYLOAD_PROFILES = HES.PAYLOAD_PROFILES or {}
HES.DEFAULT_PAYLOADS = HES.DEFAULT_PAYLOADS or {}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
HES.ACTIVE_ESCORTS = HES.ACTIVE_ESCORTS or {}
HES.STATE = HES.STATE or {
    started = false,
    nextEscortId = 1,
    menus = {},
    processedMarks = {},
    rawMissionCache = {},
    eventHandler = nil,
}

local ACTIVE = HES.ACTIVE_ESCORTS
local STATE = HES.STATE
local CFG = HES.CONFIG

----------------------------------------------------------------
-- LOG Y MENSAJES
----------------------------------------------------------------
local function log(message)
    env.info("[HDEV_ESCORT] " .. tostring(message))
end

local function debugLog(message)
    if CFG.DEBUG then
        log("DEBUG: " .. tostring(message))
    end
end

local function warn(message)
    env.warning("[HDEV_ESCORT] " .. tostring(message))
end

local function outGroup(groupId, message, seconds)
    if not groupId then return end
    pcall(function()
        trigger.action.outTextForGroup(groupId, tostring(message), seconds or 10)
    end)
end

local function outCoalition(side, message, seconds)
    if side ~= coalition.side.RED and side ~= coalition.side.BLUE then return end
    pcall(function()
        trigger.action.outTextForCoalition(side, tostring(message), seconds or 10)
    end)
end

----------------------------------------------------------------
-- UTILIDADES GENERALES
----------------------------------------------------------------
local function now()
    if timer and timer.getTime then
        return timer.getTime()
    end
    return 0
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function round(value, decimals)
    value = tonumber(value) or 0
    local mult = 10 ^ (decimals or 0)
    if value >= 0 then
        return math.floor(value * mult + 0.5) / mult
    end
    return math.ceil(value * mult - 0.5) / mult
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    if mist and mist.utils and mist.utils.deepCopy then
        local ok, copy = pcall(mist.utils.deepCopy, value)
        if ok then return copy end
    end

    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return copy
end

local function trim(text)
    return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeSpaces(text)
    return trim(tostring(text or ""):gsub("%s+", " "))
end

local function safeName(text)
    local result = tostring(text or "PLAYER")
    result = result:gsub("[^%w_%-]+", "_")
    result = result:gsub("_+", "_")
    result = result:gsub("^_", "")
    result = result:gsub("_$", "")
    if result == "" then result = "PLAYER" end
    return result
end

local function atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function vecLength(vector)
    if not vector then return 0 end
    local x = tonumber(vector.x) or 0
    local y = tonumber(vector.y) or 0
    local z = tonumber(vector.z) or 0
    return math.sqrt(x * x + y * y + z * z)
end

local function distance3D(a, b)
    if not a or not b then return math.huge end
    local dx = (tonumber(a.x) or 0) - (tonumber(b.x) or 0)
    local dy = (tonumber(a.y) or 0) - (tonumber(b.y) or 0)
    local dz = (tonumber(a.z) or 0) - (tonumber(b.z) or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function distance2D(a, b)
    if not a or not b then return math.huge end
    local dx = (tonumber(a.x) or 0) - (tonumber(b.x) or 0)
    local az = tonumber(a.z or a.y) or 0
    local bz = tonumber(b.z or b.y) or 0
    local dz = az - bz
    return math.sqrt(dx * dx + dz * dz)
end

local function formatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end

local function safeCall(object, methodName, ...)
    if not object then return nil, "objeto no disponible" end
    local method = object[methodName]
    if type(method) ~= "function" then
        return nil, "metodo " .. tostring(methodName) .. " no disponible"
    end
    local args = {...}
    local ok, resultA, resultB, resultC = pcall(function()
        return method(object, unpack(args))
    end)
    if not ok then return nil, resultA end
    return resultA, nil, resultB, resultC
end

local function objectExists(object)
    if not object then return false end
    local exists = safeCall(object, "isExist")
    return exists == true
end

local function getTerrainHeight(point)
    if not point or not land or not land.getHeight then return nil end
    local ok, height = pcall(function()
        return land.getHeight({
            x = tonumber(point.x) or 0,
            y = tonumber(point.z or point.y) or 0,
        })
    end)
    if ok and type(height) == "number" then return height end
    return nil
end

local function getAGL(unit)
    local point = safeCall(unit, "getPoint")
    if not point then return nil end
    local terrain = getTerrainHeight(point)
    if terrain == nil then return nil end
    return point.y - terrain
end

local function getSpeed(unit)
    local velocity = safeCall(unit, "getVelocity")
    return vecLength(velocity)
end

local function getHeadingAndAxes(unit)
    local position = safeCall(unit, "getPosition")
    if position and position.x and position.z then
        local forward = {
            x = tonumber(position.x.x) or 0,
            y = tonumber(position.x.y) or 0,
            z = tonumber(position.x.z) or 0,
        }
        local right = {
            x = tonumber(position.z.x) or 0,
            y = tonumber(position.z.y) or 0,
            z = tonumber(position.z.z) or 0,
        }
        local forwardHorizontal = math.sqrt(forward.x * forward.x + forward.z * forward.z)
        if forwardHorizontal > 0.0001 then
            forward.x = forward.x / forwardHorizontal
            forward.z = forward.z / forwardHorizontal
        end
        local rightHorizontal = math.sqrt(right.x * right.x + right.z * right.z)
        if rightHorizontal > 0.0001 then
            right.x = right.x / rightHorizontal
            right.z = right.z / rightHorizontal
        end
        return atan2(forward.z, forward.x), forward, right
    end

    return 0, {x = 1, y = 0, z = 0}, {x = 0, y = 0, z = 1}
end

local function getGroupByName(name)
    if not name or name == "" then return nil end
    local ok, group = pcall(Group.getByName, name)
    if ok and group and objectExists(group) then return group end
    return nil
end

local function getUnitByName(name)
    if not name or name == "" then return nil end
    local ok, unit = pcall(Unit.getByName, name)
    if ok and unit and objectExists(unit) then return unit end
    return nil
end

local function schedule(callback, argument, delay)
    if not timer or not timer.scheduleFunction then return nil end
    return timer.scheduleFunction(callback, argument, now() + (tonumber(delay) or 0))
end

local function normalizeMode(mode)
    mode = string.upper(trim(mode or CFG.DEFAULT_MODE))
    if CFG.ALLOWED_MODES[mode] then return mode end
    return nil
end

local function categoryIsAircraft(groupCategory)
    return groupCategory == Group.Category.AIRPLANE or
           groupCategory == Group.Category.HELICOPTER or
           groupCategory == Unit.Category.AIRPLANE or
           groupCategory == Unit.Category.HELICOPTER
end

----------------------------------------------------------------
-- BUSQUEDA DE JUGADORES
----------------------------------------------------------------
local function getCoalitionPlayers(side)
    local result = {}
    if not coalition or not coalition.getPlayers then return result end
    local ok, players = pcall(coalition.getPlayers, side)
    if not ok or type(players) ~= "table" then return result end

    for _, unit in pairs(players) do
        if unit and objectExists(unit) then
            local playerName = safeCall(unit, "getPlayerName")
            if playerName and playerName ~= "" then
                result[#result + 1] = unit
            end
        end
    end
    return result
end

local function getAllPlayers()
    local result = {}
    local red = getCoalitionPlayers(coalition.side.RED)
    local blue = getCoalitionPlayers(coalition.side.BLUE)
    for _, unit in ipairs(red) do result[#result + 1] = unit end
    for _, unit in ipairs(blue) do result[#result + 1] = unit end
    return result
end

local function getPlayersInGroup(groupId)
    local result = {}
    for _, unit in ipairs(getAllPlayers()) do
        local group = safeCall(unit, "getGroup")
        local id = group and safeCall(group, "getID") or nil
        if tonumber(id) == tonumber(groupId) then
            result[#result + 1] = unit
        end
    end
    table.sort(result, function(a, b)
        return tostring(safeCall(a, "getPlayerName") or "") < tostring(safeCall(b, "getPlayerName") or "")
    end)
    return result
end

local function findPlayerUnitByName(playerName)
    if not playerName then return nil end
    for _, unit in ipairs(getAllPlayers()) do
        if safeCall(unit, "getPlayerName") == playerName then
            return unit
        end
    end
    return nil
end

local function getPlayerDescriptor(unit)
    if not unit or not objectExists(unit) then return nil end
    local playerName = safeCall(unit, "getPlayerName")
    local group = safeCall(unit, "getGroup")
    if not playerName or playerName == "" or not group then return nil end

    return {
        unit = unit,
        playerName = playerName,
        unitName = safeCall(unit, "getName"),
        group = group,
        groupName = safeCall(group, "getName"),
        groupId = safeCall(group, "getID"),
        groupCategory = safeCall(group, "getCategory"),
        coalition = safeCall(unit, "getCoalition"),
        country = safeCall(unit, "getCountry"),
        aircraftType = safeCall(unit, "getTypeName"),
        point = safeCall(unit, "getPoint"),
        speed = getSpeed(unit),
        agl = getAGL(unit),
    }
end

local function resolveMenuPlayer(argument)
    argument = argument or {}
    if argument.playerName then
        local unit = findPlayerUnitByName(argument.playerName)
        if unit then
            local group = safeCall(unit, "getGroup")
            local groupId = group and safeCall(group, "getID") or nil
            if not argument.groupId or tonumber(groupId) == tonumber(argument.groupId) then
                return unit
            end
        end
        return nil, "El jugador ya no ocupa la unidad asociada al menu."
    end

    local players = getPlayersInGroup(argument.groupId)
    if #players == 1 then return players[1] end
    if #players == 0 then return nil, "No se encontro un jugador humano activo en este grupo." end
    return nil, "Hay varios jugadores en el grupo. Usa el submenu con tu nombre."
end

----------------------------------------------------------------
-- FUENTES DINAMICAS Y RESOLUCION DE PAYLOAD
----------------------------------------------------------------
local function normalizeWeaponToken(value)
    local token = string.upper(tostring(value or ""))
    token = token:gsub("WEAPONS", "")
    token = token:gsub("MISSILES", "")
    token = token:gsub("BOMBS", "")
    token = token:gsub("ROCKETS", "")
    token = token:gsub("CONTAINERS", "")
    token = token:gsub("[^%w]", "")
    return token
end

local function payloadLooksValid(payload)
    if type(payload) ~= "table" then return false end
    return type(payload.pylons) == "table" or
           payload.fuel ~= nil or payload.flare ~= nil or
           payload.chaff ~= nil or payload.gun ~= nil
end

local function payloadPylonCount(payload)
    if type(payload) ~= "table" or type(payload.pylons) ~= "table" then return 0 end
    local count = 0
    for _, pylon in pairs(payload.pylons) do
        if type(pylon) == "table" and pylon.CLSID and pylon.CLSID ~= "" and pylon.CLSID ~= "<CLEAN>" then
            count = count + 1
        end
    end
    return count
end

local function findUnitDataInGroup(groupData, descriptor)
    if type(groupData) ~= "table" or type(groupData.units) ~= "table" then return nil end
    local typeFallback = nil
    for _, unitData in pairs(groupData.units) do
        if type(unitData) == "table" then
            local name = unitData.name or unitData.unitName
            if descriptor and name == descriptor.unitName then return unitData end
            if descriptor and unitData.type == descriptor.aircraftType and not typeFallback then
                typeFallback = unitData
            end
        end
    end
    return typeFallback or groupData.units[1]
end

local function normalizeSourceEntry(entry, descriptor, sourceName)
    if type(entry) ~= "table" then return nil end

    local groupData = entry.groupData or entry.group
    local unitData = entry.unitData or entry.unit

    if not groupData and type(entry.units) == "table" then
        groupData = entry
    end
    if groupData and not unitData then
        unitData = findUnitDataInGroup(groupData, descriptor)
    end
    if not unitData and type(entry.payload) == "table" then
        unitData = entry
    end

    local payload = nil
    if unitData and type(unitData.payload) == "table" then
        payload = unitData.payload
    elseif type(entry.payload) == "table" then
        payload = entry.payload
    elseif payloadLooksValid(entry) then
        payload = entry
    end

    if not payloadLooksValid(payload) then return nil end

    return {
        source = sourceName or entry.source or "DYNAMIC_REGISTRY",
        payload = deepCopy(payload),
        unit = unitData and deepCopy(unitData) or nil,
        group = groupData and deepCopy(groupData) or nil,
        metadata = deepCopy(entry.metadata or entry.__metadata),
        exact = entry.exact ~= false,
    }
end

local function descriptorKeys(descriptor)
    local keys = {}
    local function add(value)
        if value == nil then return end
        keys[#keys + 1] = value
        if type(value) ~= "string" then keys[#keys + 1] = tostring(value) end
    end
    add(descriptor and descriptor.unitName)
    add(descriptor and descriptor.playerName)
    add(descriptor and descriptor.groupName)
    add(descriptor and descriptor.groupId)
    return keys
end

local function lookupRegistry(registry, descriptor, sourceName)
    if type(registry) ~= "table" then return nil end

    for _, key in ipairs(descriptorKeys(descriptor)) do
        local source = normalizeSourceEntry(registry[key], descriptor, sourceName)
        if source then return source end
    end

    local buckets = {
        {name = "byUnitName", key = descriptor and descriptor.unitName},
        {name = "byPlayerName", key = descriptor and descriptor.playerName},
        {name = "byGroupName", key = descriptor and descriptor.groupName},
        {name = "byGroupId", key = descriptor and descriptor.groupId},
        {name = "byAircraftType", key = descriptor and descriptor.aircraftType},
    }
    for _, bucket in ipairs(buckets) do
        local tableBucket = registry[bucket.name]
        if type(tableBucket) == "table" and bucket.key ~= nil then
            local source = normalizeSourceEntry(tableBucket[bucket.key] or tableBucket[tostring(bucket.key)], descriptor, sourceName)
            if source then return source end
        end
    end
    return nil
end

local function findExternalDynamicSource(descriptor)
    local source = lookupRegistry(HES.DYNAMIC_PAYLOAD_REGISTRY, descriptor, "HES_DYNAMIC_REGISTRY")
    if source then return source end

    local registryNames = {
        "HDEV_DYNAMIC_SLOT_PAYLOADS",
        "HDEV_DynamicSlotPayloads",
        "DYNAMIC_SLOT_PAYLOADS",
    }
    for _, registryName in ipairs(registryNames) do
        local registry = _G and _G[registryName] or nil
        source = lookupRegistry(registry, descriptor, registryName)
        if source then return source end
    end

    for index, provider in ipairs(HES.PAYLOAD_PROVIDERS or {}) do
        if type(provider) == "function" then
            local ok, result = pcall(provider, descriptor)
            if ok then
                source = normalizeSourceEntry(result, descriptor, "PAYLOAD_PROVIDER_" .. tostring(index))
                if source then return source end
            else
                warn("Proveedor de payload " .. tostring(index) .. " fallo: " .. tostring(result))
            end
        end
    end
    return nil
end

local function findMistDynamicSource(descriptor)
    if not mist or not mist.DBs then return nil, nil end

    local unitData = nil
    local groupData = nil

    if mist.DBs.unitsByName then unitData = mist.DBs.unitsByName[descriptor.unitName] end
    if not unitData and mist.DBs.humansByName then unitData = mist.DBs.humansByName[descriptor.unitName] end
    if mist.DBs.groupsByName then groupData = mist.DBs.groupsByName[descriptor.groupName] end

    if type(mist.DBs.dynGroupsAdded) == "table" then
        for index = #mist.DBs.dynGroupsAdded, 1, -1 do
            local candidate = mist.DBs.dynGroupsAdded[index]
            if type(candidate) == "table" and
               (candidate.groupName == descriptor.groupName or candidate.name == descriptor.groupName or
                tonumber(candidate.groupId) == tonumber(descriptor.groupId)) then
                groupData = candidate
                local candidateUnit = findUnitDataInGroup(candidate, descriptor)
                if candidateUnit then unitData = candidateUnit end
                break
            end
        end
    end

    local exact = normalizeSourceEntry({unit = unitData, group = groupData}, descriptor, "MIST_DYNAMIC_DB")
    return exact, unitData, groupData
end

-- Solo se conserva como respaldo opcional de pruebas. En producción queda desactivado.
local function scanMissionForUnit(unitName)
    if not CFG.ALLOW_MISSION_EDITOR_FALLBACK then return nil, nil, nil end
    if not unitName or not env or not env.mission or not env.mission.coalition then
        return nil, nil, nil
    end

    local cached = STATE.rawMissionCache[unitName]
    if cached then
        return cached.unit or nil, cached.group or nil, cached.location or nil
    end

    for coalitionKey, coalitionData in pairs(env.mission.coalition) do
        if type(coalitionData) == "table" and type(coalitionData.country) == "table" then
            for _, countryData in pairs(coalitionData.country) do
                if type(countryData) == "table" then
                    for _, categoryName in ipairs({"plane", "helicopter"}) do
                        local category = countryData[categoryName]
                        if category and type(category.group) == "table" then
                            for _, groupData in pairs(category.group) do
                                if groupData and type(groupData.units) == "table" then
                                    for _, unitData in pairs(groupData.units) do
                                        local resolvedName = unitData.name
                                        if env.getValueDictByKey and env.mission.version and env.mission.version > 7 and env.mission.version < 19 then
                                            local ok, translated = pcall(env.getValueDictByKey, unitData.name)
                                            if ok and translated then resolvedName = translated end
                                        end
                                        if resolvedName == unitName then
                                            local location = {
                                                coalitionKey = coalitionKey,
                                                countryId = countryData.id,
                                                countryName = countryData.name,
                                                categoryName = categoryName,
                                            }
                                            STATE.rawMissionCache[unitName] = {
                                                unit = deepCopy(unitData),
                                                group = deepCopy(groupData),
                                                location = location,
                                            }
                                            return deepCopy(unitData), deepCopy(groupData), deepCopy(location)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    STATE.rawMissionCache[unitName] = {unit = false, group = false, location = false}
    return nil, nil, nil
end

local function getRuntimeAmmoSnapshot(playerUnit)
    local ammo, ammoError = safeCall(playerUnit, "getAmmo")
    local snapshot = {
        available = type(ammo) == "table",
        error = ammoError,
        entries = {},
        total = 0,
    }
    if type(ammo) ~= "table" then return snapshot end

    local aggregated = {}
    for _, item in pairs(ammo) do
        if type(item) == "table" then
            local count = tonumber(item.count) or 0
            local desc = type(item.desc) == "table" and item.desc or {}
            local category = tonumber(desc.category)
            local shellCategory = (Weapon and Weapon.Category and Weapon.Category.SHELL) or 0
            local isShell = category == shellCategory or category == 0

            if count > 0 and not (CFG.PAYLOAD_IGNORE_SHELLS and isShell) then
                local displayName = desc.displayName or desc.typeName or desc.name or "ARMA_DESCONOCIDA"
                local canonical = normalizeWeaponToken(displayName)
                if canonical == "" then canonical = "UNKNOWN" end

                local entry = aggregated[canonical]
                if not entry then
                    entry = {
                        key = canonical,
                        label = tostring(displayName),
                        count = 0,
                        category = category,
                        aliases = {},
                        raw = {},
                    }
                    aggregated[canonical] = entry
                end

                entry.count = entry.count + count
                entry.raw[#entry.raw + 1] = deepCopy(item)
                local aliases = {displayName, desc.typeName, desc.name}
                for _, alias in ipairs(aliases) do
                    local normalized = normalizeWeaponToken(alias)
                    if normalized ~= "" then entry.aliases[normalized] = true end
                end
            end
        end
    end

    for _, entry in pairs(aggregated) do
        snapshot.total = snapshot.total + entry.count
        snapshot.entries[#snapshot.entries + 1] = entry
    end
    table.sort(snapshot.entries, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return snapshot
end

local function formatAmmoSnapshot(snapshot, maxLines)
    if not snapshot or not snapshot.available then return "Unit:getAmmo() no disponible" end
    if #snapshot.entries == 0 then return "Sin armamento externo detectable" end

    local lines = {}
    local limit = math.max(1, tonumber(maxLines) or CFG.PAYLOAD_DIAGNOSTIC_MAX_LINES or 12)
    for index, entry in ipairs(snapshot.entries) do
        if index > limit then
            lines[#lines + 1] = "... y " .. tostring(#snapshot.entries - limit) .. " tipos mas"
            break
        end
        lines[#lines + 1] = tostring(entry.label) .. " x" .. tostring(entry.count)
    end
    return table.concat(lines, ", ")
end

local function normalizeProfileWeapons(profile)
    local source = profile and (profile.weapons or profile.expectedWeapons or profile.ammo)
    local expected = {}
    if type(source) ~= "table" then return expected end

    if #source > 0 then
        for _, item in ipairs(source) do
            if type(item) == "table" then
                local aliases = item.aliases or item.alias or item.names or item.name or item.typeName or item.key
                if type(aliases) ~= "table" then aliases = {aliases} end
                local normalizedAliases = {}
                for _, alias in pairs(aliases) do
                    local token = normalizeWeaponToken(alias)
                    if token ~= "" then normalizedAliases[#normalizedAliases + 1] = token end
                end
                if #normalizedAliases > 0 then
                    expected[#expected + 1] = {
                        aliases = normalizedAliases,
                        count = math.max(0, tonumber(item.count or item.quantity or item.cantidad) or 0),
                    }
                end
            end
        end
    else
        for alias, count in pairs(source) do
            local token = normalizeWeaponToken(alias)
            if token ~= "" then
                expected[#expected + 1] = {
                    aliases = {token},
                    count = math.max(0, tonumber(count) or 0),
                }
            end
        end
    end
    return expected
end

local function tokenPairMatches(left, right)
    if left == right then return true end
    if #left >= 5 and #right >= 5 then
        if string.find(left, right, 1, true) or string.find(right, left, 1, true) then return true end
    end
    return false
end

local function expectedMatchesRuntime(expectedItem, runtimeEntry)
    for _, expectedAlias in ipairs(expectedItem.aliases or {}) do
        if tokenPairMatches(expectedAlias, runtimeEntry.key or "") then return true end
        for runtimeAlias in pairs(runtimeEntry.aliases or {}) do
            if tokenPairMatches(expectedAlias, runtimeAlias) then return true end
        end
    end
    return false
end

local function scorePayloadProfile(profile, snapshot)
    local expected = normalizeProfileWeapons(profile)
    if #expected == 0 then return nil end
    if not snapshot or not snapshot.available then return nil end

    local actualByExpected = {}
    local matchedRuntimeTotal = 0
    local extraRuntimeTotal = 0

    for _, runtimeEntry in ipairs(snapshot.entries or {}) do
        local bestIndex = nil
        for expectedIndex, expectedItem in ipairs(expected) do
            if expectedMatchesRuntime(expectedItem, runtimeEntry) then
                bestIndex = expectedIndex
                break
            end
        end
        if bestIndex then
            actualByExpected[bestIndex] = (actualByExpected[bestIndex] or 0) + runtimeEntry.count
            matchedRuntimeTotal = matchedRuntimeTotal + runtimeEntry.count
        else
            extraRuntimeTotal = extraRuntimeTotal + runtimeEntry.count
        end
    end

    local expectedTypes = #expected
    local matchedTypes = 0
    local countFitSum = 0
    local expectedTotal = 0
    local matchedCount = 0

    for index, expectedItem in ipairs(expected) do
        local expectedCount = math.max(0, tonumber(expectedItem.count) or 0)
        local actualCount = math.max(0, tonumber(actualByExpected[index]) or 0)
        expectedTotal = expectedTotal + expectedCount
        if actualCount > 0 or expectedCount == 0 then matchedTypes = matchedTypes + 1 end
        matchedCount = matchedCount + math.min(actualCount, expectedCount)

        if expectedCount == 0 and actualCount == 0 then
            countFitSum = countFitSum + 1
        elseif expectedCount > 0 and actualCount > 0 then
            if CFG.PAYLOAD_ALLOW_SPENT_WEAPONS and actualCount <= expectedCount then
                countFitSum = countFitSum + 1
            else
                countFitSum = countFitSum + (math.min(actualCount, expectedCount) / math.max(actualCount, expectedCount))
            end
        end
    end

    local typeCoverage = expectedTypes > 0 and (matchedTypes / expectedTypes) or 0
    local runtimeCoverage = snapshot.total > 0 and (matchedRuntimeTotal / snapshot.total) or 0
    local countFit = expectedTypes > 0 and (countFitSum / expectedTypes) or 0
    local extraPenalty = snapshot.total > 0 and (extraRuntimeTotal / snapshot.total) or 0
    local score = (typeCoverage * 0.50) + (runtimeCoverage * 0.35) + (countFit * 0.15) - (extraPenalty * 0.20)
    score = clamp(score, 0, 1)

    return {
        score = score,
        expectedTotal = expectedTotal,
        runtimeTotal = snapshot.total,
        matchedCount = matchedCount,
        matchedTypes = matchedTypes,
        expectedTypes = expectedTypes,
        extraRuntimeTotal = extraRuntimeTotal,
    }
end

local function findMatchingPayloadProfile(aircraftType, snapshot)
    local profiles = HES.PAYLOAD_PROFILES and HES.PAYLOAD_PROFILES[aircraftType]
    if type(profiles) ~= "table" then return nil, nil end

    local candidates = {}
    local defaultProfile = nil
    for index, profile in ipairs(profiles) do
        if type(profile) == "table" and type(profile.payload) == "table" then
            if profile.default == true and not defaultProfile then defaultProfile = profile end
            local match = scorePayloadProfile(profile, snapshot)
            if match then
                candidates[#candidates + 1] = {
                    profile = profile,
                    match = match,
                    index = index,
                    priority = tonumber(profile.priority) or 0,
                }
            end
        end
    end

    table.sort(candidates, function(a, b)
        if a.match.score == b.match.score then return a.priority > b.priority end
        return a.match.score > b.match.score
    end)

    local best = candidates[1]
    local second = candidates[2]
    if best and best.match.score >= CFG.PAYLOAD_MATCH_MIN_SCORE then
        local margin = second and (best.match.score - second.match.score) or 1
        if best.profile.forceMatch == true or margin >= CFG.PAYLOAD_MATCH_AMBIGUITY_MARGIN then
            return best.profile, {
                score = best.match.score,
                secondScore = second and second.match.score or nil,
                ambiguous = false,
                details = best.match,
            }
        end
        return nil, {
            score = best.match.score,
            secondScore = second and second.match.score or nil,
            ambiguous = true,
            bestName = best.profile.name or ("Perfil " .. tostring(best.index)),
            secondName = second and (second.profile.name or ("Perfil " .. tostring(second.index))) or nil,
        }
    end

    if defaultProfile then
        return defaultProfile, {score = 0, default = true, ambiguous = false}
    end
    return nil, best and {score = best.match.score, ambiguous = false} or nil
end

local function getSourceData(descriptor)
    local external = findExternalDynamicSource(descriptor)
    if external then
        return {
            source = external.source,
            exactPayload = external.payload,
            unit = external.unit,
            group = external.group,
            metadata = external.metadata,
            dynamic = true,
        }
    end

    local mistExact, mistUnit, mistGroup = findMistDynamicSource(descriptor)
    if mistExact then
        return {
            source = mistExact.source,
            exactPayload = mistExact.payload,
            unit = mistExact.unit or mistUnit,
            group = mistExact.group or mistGroup,
            dynamic = true,
        }
    end

    local rawUnit, rawGroup, location = scanMissionForUnit(descriptor.unitName)
    return {
        source = rawUnit and "MISSION_EDITOR_FALLBACK" or "RUNTIME_ONLY",
        exactPayload = rawUnit and rawUnit.payload or nil,
        unit = rawUnit or mistUnit,
        group = rawGroup or mistGroup,
        location = location,
        dynamic = rawUnit == nil,
    }
end

local function nextUniqueIds()
    local groupId = nil
    local unitId = nil
    if mist.getNextGroupId then
        local ok, value = pcall(mist.getNextGroupId)
        if ok then groupId = value end
    end
    if mist.getNextUnitId then
        local ok, value = pcall(mist.getNextUnitId)
        if ok then unitId = value end
    end
    return groupId, unitId
end

local function generateCallsign(rawCallsign, escortId)
    if type(rawCallsign) == "table" then
        local result = deepCopy(rawCallsign)
        local groupNumber = ((escortId - 1) % 9) + 1
        result[2] = groupNumber
        result[3] = 1
        result.name = nil
        return result
    end

    if type(rawCallsign) == "number" then
        return ((escortId - 1) % 9) + 1
    end

    return ((escortId - 1) % 9) + 1
end

local function generateOnboardNumber(escortId)
    return string.format("%03d", 100 + ((escortId - 1) % 899))
end

local function generateLink16STN(escortId)
    local value = 1000 + ((escortId * 3) % 6777)
    return string.format("%05d", value)
end

local function sanitizeSpecialProperties(properties, escortId)
    if type(properties) ~= "table" then return nil end
    local result = deepCopy(properties)
    if result.STN_L16 ~= nil then
        result.STN_L16 = generateLink16STN(escortId)
    end
    if result.VoiceCallsignNumber ~= nil then
        result.VoiceCallsignNumber = tostring(((escortId - 1) % 99) + 1)
    end
    return result
end

local function applyRuntimeFuel(playerUnit, payload)
    payload = deepCopy(payload or {})
    payload.pylons = payload.pylons or {}
    if payload.gun == nil then payload.gun = 100 end
    if payload.flare == nil then payload.flare = 0 end
    if payload.chaff == nil then payload.chaff = 0 end

    local runtimeFuel = safeCall(playerUnit, "getFuel")
    local desc = safeCall(playerUnit, "getDesc")
    if type(runtimeFuel) == "number" and type(desc) == "table" and type(desc.fuelMassMax) == "number" then
        payload.fuel = math.max(1, desc.fuelMassMax * clamp(runtimeFuel, 0, 1))
    elseif payload.fuel == nil then
        payload.fuel = 1000
    end
    return payload
end

local function resolvePayload(playerUnit, descriptor, sourceData)
    local snapshot = getRuntimeAmmoSnapshot(playerUnit)
    local payload = nil
    local info = {
        source = "UNKNOWN",
        exact = false,
        known = false,
        profileName = nil,
        score = nil,
        ammoSnapshot = snapshot,
        ammoSummary = formatAmmoSnapshot(snapshot),
        warning = nil,
    }

    if sourceData and payloadLooksValid(sourceData.exactPayload) then
        payload = deepCopy(sourceData.exactPayload)
        info.source = sourceData.source or "DYNAMIC_EXACT"
        info.exact = true
        info.known = true
    else
        local profile, profileMatch = findMatchingPayloadProfile(descriptor.aircraftType, snapshot)
        if profile then
            payload = deepCopy(profile.payload)
            info.source = profileMatch and profileMatch.default and "AIRCRAFT_DEFAULT_PROFILE" or "RUNTIME_AMMO_PROFILE_MATCH"
            info.profileName = profile.name or "Perfil sin nombre"
            info.score = profileMatch and profileMatch.score or nil
            info.exact = false
            info.known = true
        elseif type(HES.DEFAULT_PAYLOADS[descriptor.aircraftType]) == "table" then
            payload = deepCopy(HES.DEFAULT_PAYLOADS[descriptor.aircraftType])
            info.source = "AIRCRAFT_DEFAULT_PAYLOAD"
            info.profileName = "Default " .. tostring(descriptor.aircraftType)
            info.known = true
        else
            payload = {fuel = 1000, flare = 0, chaff = 0, gun = 100, pylons = {}}
            info.source = "RUNTIME_NO_PYLON_DATA"
            info.warning = "DCS detecto las armas runtime, pero no expuso los CLSID ni la estacion de cada pilon."
            if CFG.BLOCK_IF_PAYLOAD_UNKNOWN then
                return nil, info
            end
        end
    end

    payload = applyRuntimeFuel(playerUnit, payload)
    info.pylonCount = payloadPylonCount(payload)
    return payload, info
end

----------------------------------------------------------------
-- VALIDACION Y POSICION SEGURA DE SPAWN
----------------------------------------------------------------
local function validatePlayerForEscort(unit, allowExisting)
    if not unit or not objectExists(unit) then
        return false, "La unidad del jugador no existe o fue destruida."
    end

    local descriptor = getPlayerDescriptor(unit)
    if not descriptor then
        return false, "No se pudo determinar el jugador o su grupo.", nil
    end

    if not descriptor.playerName or descriptor.playerName == "" then
        return false, "No se pudo determinar el nombre del jugador.", descriptor
    end
    if not descriptor.aircraftType or descriptor.aircraftType == "" then
        return false, "No se pudo determinar el tipo de aeronave.", descriptor
    end
    if not descriptor.group or not objectExists(descriptor.group) then
        return false, "El grupo del jugador no existe.", descriptor
    end
    if not categoryIsAircraft(descriptor.groupCategory) then
        return false, "La unidad no pertenece a una categoria aerea valida.", descriptor
    end
    if descriptor.coalition ~= coalition.side.RED and descriptor.coalition ~= coalition.side.BLUE then
        return false, "La unidad no pertenece a una coalicion valida.", descriptor
    end
    if not descriptor.country then
        return false, "No se pudo determinar el pais de la aeronave.", descriptor
    end
    if not descriptor.point then
        return false, "No se pudo determinar la posicion de la aeronave.", descriptor
    end

    local inAir = safeCall(unit, "inAir")
    if inAir == false then
        return false, "La aeronave se encuentra en tierra.", descriptor
    end

    if descriptor.agl == nil then
        return false, "No se pudo calcular la altitud AGL.", descriptor
    end
    if descriptor.agl < CFG.MINIMUM_AGL then
        return false,
            "Debes encontrarte por encima de " .. tostring(CFG.MINIMUM_AGL) .. " metros AGL.\n\n" ..
            "Altitud AGL actual: " .. tostring(math.floor(descriptor.agl)) .. " metros.",
            descriptor
    end

    if descriptor.speed < CFG.MINIMUM_SPEED then
        return false,
            "La velocidad es demasiado baja.\n\n" ..
            "Velocidad minima: " .. tostring(CFG.MINIMUM_SPEED) .. " m/s.\n" ..
            "Velocidad actual: " .. tostring(math.floor(descriptor.speed)) .. " m/s.",
            descriptor
    end

    if not allowExisting and ACTIVE[descriptor.playerName] then
        return false, "Ya tienes una escolta activa.", descriptor
    end

    return true, nil, descriptor
end

local function nearbyUnitAtPoint(point, radius, ignoredNames)
    if not world or not world.searchObjects or not Object or not Object.Category then
        return false, nil
    end

    local foundName = nil
    local volume = {
        id = world.VolumeType.SPHERE,
        params = {
            point = point,
            radius = radius,
        }
    }

    local ok = pcall(function()
        world.searchObjects(Object.Category.UNIT, volume, function(object)
            if not object or not objectExists(object) then return true end
            local objectName = safeCall(object, "getName")
            if objectName and not (ignoredNames and ignoredNames[objectName]) then
                foundName = objectName
                return false
            end
            return true
        end)
    end)

    return ok and foundName ~= nil, foundName
end

local function calculateCandidate(playerUnit, longitudinal, lateral, vertical)
    local playerPoint = safeCall(playerUnit, "getPoint")
    if not playerPoint then return nil end
    local heading, forward, right = getHeadingAndAxes(playerUnit)

    local candidate = {
        x = playerPoint.x + forward.x * longitudinal + right.x * lateral,
        y = playerPoint.y + vertical,
        z = playerPoint.z + forward.z * longitudinal + right.z * lateral,
    }

    local terrain = getTerrainHeight(candidate)
    if terrain == nil then return nil end
    candidate.y = math.max(candidate.y, terrain + CFG.SPAWN_MIN_AGL)

    local relative = {
        x = candidate.x - playerPoint.x,
        y = candidate.y - playerPoint.y,
        z = candidate.z - playerPoint.z,
    }
    local forwardDot = relative.x * forward.x + relative.z * forward.z

    return {
        point = candidate,
        heading = heading,
        forwardDot = forwardDot,
        terrainHeight = terrain,
        actualDistance = distance3D(candidate, playerPoint),
        longitudinal = longitudinal,
        lateral = lateral,
        vertical = candidate.y - playerPoint.y,
    }
end

local function findSafeSpawn(playerUnit, requestedDistance, ignoredNames)
    local baseDistance = clamp(requestedDistance or CFG.DEFAULT_ESCORT_DISTANCE,
        CFG.MIN_ESCORT_DISTANCE, CFG.MAX_ESCORT_DISTANCE)
    local baseLateral = tonumber(CFG.SPAWN_OFFSET.lateral) or 500
    local baseVertical = tonumber(CFG.SPAWN_OFFSET.vertical) or 100

    local candidates = {
        {-baseDistance,  baseLateral, baseVertical},
        {-baseDistance, -baseLateral, baseVertical},
        {-baseDistance * 1.25,  baseLateral * 1.2, baseVertical + 100},
        {-baseDistance * 1.25, -baseLateral * 1.2, baseVertical + 100},
        {-baseDistance * 1.5,  baseLateral * 1.5, baseVertical + 200},
        {-baseDistance * 1.5, -baseLateral * 1.5, baseVertical + 200},
        {-baseDistance * 1.8,  baseLateral * 2.0, baseVertical + 300},
        {-baseDistance * 1.8, -baseLateral * 2.0, baseVertical + 300},
    }

    local maxAttempts = math.min(#candidates, tonumber(CFG.SPAWN_MAX_ATTEMPTS) or #candidates)
    for index = 1, maxAttempts do
        local values = candidates[index]
        local candidate = calculateCandidate(playerUnit, values[1], values[2], values[3])
        if candidate and
           candidate.forwardDot < 0 and
           candidate.actualDistance >= CFG.SPAWN_MIN_PLAYER_SEPARATION and
           candidate.point.y > candidate.terrainHeight then
            local occupied, objectName = nearbyUnitAtPoint(
                candidate.point,
                CFG.SPAWN_CLEARANCE_RADIUS,
                ignoredNames
            )
            if not occupied then
                return candidate
            end
            debugLog("Punto de spawn rechazado por cercania de unidad: " .. tostring(objectName))
        end
    end

    return nil, "No se encontro una posicion de aparicion segura."
end

----------------------------------------------------------------
-- CONSTRUCCION DEL GRUPO DINAMICO
----------------------------------------------------------------
local function getSpawnSpeed(groupCategory, playerSpeed)
    if groupCategory == Group.Category.HELICOPTER or groupCategory == Unit.Category.HELICOPTER then
        return clamp(playerSpeed, CFG.HELICOPTER_SPAWN_SPEED_MIN, CFG.HELICOPTER_SPAWN_SPEED_MAX)
    end
    return clamp(playerSpeed, CFG.AIRPLANE_SPAWN_SPEED_MIN, CFG.AIRPLANE_SPAWN_SPEED_MAX)
end

local function buildEscortGroupData(descriptor, escortId, spawn)
    local sourceData = getSourceData(descriptor)
    local sourceUnit = sourceData and sourceData.unit or nil
    local sourceGroup = sourceData and sourceData.group or nil
    local payload, payloadInfo = resolvePayload(descriptor.unit, descriptor, sourceData)
    if not payload then
        return nil, {
            error = "No fue posible resolver un payload seguro para el slot dinamico.",
            payloadInfo = payloadInfo,
        }
    end
    local groupName = "HDEV_ESCORT_" .. safeName(descriptor.playerName) .. "_" .. string.format("%03d", escortId)
    local unitName = groupName .. "_UNIT_1"
    local groupId, unitId = nextUniqueIds()
    local spawnSpeed = getSpawnSpeed(descriptor.groupCategory, descriptor.speed)

    local sourceCallsign = sourceUnit and sourceUnit.callsign or nil
    local sourceLivery = sourceUnit and sourceUnit.livery_id or nil
    local sourceOnboard = sourceUnit and sourceUnit.onboard_num or nil

    local unitData = {
        name = unitName,
        unitId = unitId,
        type = descriptor.aircraftType,
        skill = "Excellent",
        x = spawn.point.x,
        y = spawn.point.z,
        alt = spawn.point.y,
        alt_type = "BARO",
        speed = spawnSpeed,
        heading = spawn.heading,
        psi = spawn.heading,
        payload = payload,
        callsign = generateCallsign(sourceCallsign, escortId),
        onboard_num = generateOnboardNumber(escortId),
    }

    if sourceLivery then unitData.livery_id = sourceLivery end
    if sourceUnit and sourceUnit.hardpoint_racks ~= nil then
        unitData.hardpoint_racks = deepCopy(sourceUnit.hardpoint_racks)
    end
    if sourceUnit and sourceUnit.AddPropAircraft then
        unitData.AddPropAircraft = sanitizeSpecialProperties(sourceUnit.AddPropAircraft, escortId)
    end

    local waypoint = {
        x = spawn.point.x,
        y = spawn.point.z,
        alt = spawn.point.y,
        alt_type = "BARO",
        speed = spawnSpeed,
        speed_locked = true,
        ETA = 0,
        ETA_locked = false,
        action = "Turning Point",
        type = "Turning Point",
        task = {
            id = "ComboTask",
            params = {tasks = {}}
        }
    }

    local groupData = {
        name = groupName,
        groupId = groupId,
        category = descriptor.groupCategory,
        country = descriptor.country,
        task = "Escort",
        taskSelected = true,
        hidden = false,
        visible = false,
        lateActivation = false,
        uncontrolled = false,
        start_time = 0,
        route = {points = {waypoint}},
        units = {unitData},
    }

    if sourceGroup then
        if sourceGroup.communication ~= nil then groupData.communication = sourceGroup.communication end
        if sourceGroup.frequency ~= nil then groupData.frequency = sourceGroup.frequency end
        if sourceGroup.modulation ~= nil then groupData.modulation = sourceGroup.modulation end
        if sourceGroup.radioSet ~= nil then groupData.radioSet = sourceGroup.radioSet end
    end

    local copied = {
        type = descriptor.aircraftType ~= nil,
        country = descriptor.country ~= nil,
        coalition = descriptor.coalition ~= nil,
        livery = sourceLivery ~= nil,
        payload = payloadInfo and payloadInfo.known or false,
        pylons = payloadInfo and (payloadInfo.pylonCount or 0) > 0 or false,
        AddPropAircraft = unitData.AddPropAircraft ~= nil,
        hardpoint_racks = unitData.hardpoint_racks ~= nil,
        frequency = groupData.frequency ~= nil,
        modulation = groupData.modulation ~= nil,
        radioSet = groupData.radioSet ~= nil,
        callsignGenerated = true,
        onboardNumberGenerated = sourceOnboard ~= nil or true,
        datalinkRegenerated = unitData.AddPropAircraft and unitData.AddPropAircraft.STN_L16 ~= nil or false,
    }

    return groupData, {
        groupName = groupName,
        unitName = unitName,
        groupId = groupId,
        unitId = unitId,
        spawnSpeed = spawnSpeed,
        copied = copied,
        source = {
            name = sourceData and sourceData.source or "RUNTIME_ONLY",
            dynamic = sourceData and sourceData.dynamic or true,
            location = sourceData and sourceData.location or nil,
        },
        payloadInfo = payloadInfo,
    }
end

----------------------------------------------------------------
-- TAREAS DE ESCOLTA Y MODOS AVANZADOS
----------------------------------------------------------------
local function getTargetLastWaypointIndex(playerGroupName)
    local route = nil
    if mist and mist.getGroupRoute then
        local ok, result = pcall(mist.getGroupRoute, playerGroupName, true)
        if ok and type(result) == "table" then route = result end
    end

    if route and #route > 0 then return #route end

    if mist and mist.DBs and mist.DBs.MEgroupsByName then
        local groupData = mist.DBs.MEgroupsByName[playerGroupName]
        if groupData and groupData.route and groupData.route.points then
            return math.max(1, #groupData.route.points)
        end
    end

    return 1
end

local function getFormationTaskPosition(state)
    local distance = clamp(state.requestedDistance or CFG.DEFAULT_ESCORT_DISTANCE,
        CFG.MIN_ESCORT_DISTANCE, CFG.MAX_ESCORT_DISTANCE)
    local lateralConfigured = tonumber(CFG.FORMATION_OFFSET.lateral) or 500
    local lateral = math.min(math.abs(lateralConfigured), math.max(100, distance * 0.5))
    lateral = lateral * (state.sideSign or 1)

    return {
        x = -distance,
        y = tonumber(CFG.FORMATION_OFFSET.vertical) or 100,
        z = lateral,
    }
end

local function getModeAnchor(state, playerPoint)
    if state.commandPoint then return deepCopy(state.commandPoint) end
    return playerPoint and deepCopy(playerPoint) or nil
end

local function makeEscortTask(state, playerGroupId, playerGroupName)
    return {
        auto = false,
        enabled = true,
        id = "Escort",
        number = 1,
        params = {
            engagementDistMax = CFG.ENGAGEMENT_DISTANCE,
            groupId = playerGroupId,
            lastWptIndex = getTargetLastWaypointIndex(playerGroupName),
            lastWptIndexFlag = false,
            lastWptIndexFlagChangedManually = false,
            noTargetTypes = {},
            pos = getFormationTaskPosition(state),
            targetTypes = {"Air"},
            value = "Air;",
        }
    }
end

local MODE_TARGET_TYPES = {
    CAP = {"Air"},
    CAS = {"Ground Units"},
    SEAD = {"Air Defence", "SAM related", "AAA", "EWR"},
}

local function makeModeTask(state, anchor, number)
    local mode = state.mode
    if mode ~= "CAP" and mode ~= "CAS" and mode ~= "SEAD" then return nil end
    if not anchor then return nil end

    return {
        auto = false,
        enabled = true,
        id = "EngageTargetsInZone",
        number = number,
        params = {
            point = {x = anchor.x, y = anchor.z},
            zoneRadius = CFG.MODE_RADII[mode] or 20000,
            targetTypes = deepCopy(MODE_TARGET_TYPES[mode]),
            priority = 0,
        }
    }
end

local function makeMissionTask(state, escortUnit, playerUnit)
    local escortPoint = safeCall(escortUnit, "getPoint")
    local playerPoint = safeCall(playerUnit, "getPoint")
    if not escortPoint or not playerPoint then return nil, "posicion no disponible" end

    local playerGroup = safeCall(playerUnit, "getGroup")
    local playerGroupId = playerGroup and safeCall(playerGroup, "getID") or nil
    local playerGroupName = playerGroup and safeCall(playerGroup, "getName") or nil
    if not playerGroupId or not playerGroupName then
        return nil, "grupo escoltado no disponible"
    end

    local speed = getSpeed(escortUnit)
    if speed < 1 then speed = math.max(getSpeed(playerUnit), CFG.MINIMUM_SPEED) end

    local tasks = {
        makeEscortTask(state, playerGroupId, playerGroupName)
    }

    local anchor = getModeAnchor(state, playerPoint)
    local modeTask = makeModeTask(state, anchor, #tasks + 1)
    if modeTask then tasks[#tasks + 1] = modeTask end

    state.lastModeAnchor = anchor and deepCopy(anchor) or nil

    return {
        id = "Mission",
        params = {
            route = {
                points = {
                    {
                        x = escortPoint.x,
                        y = escortPoint.z,
                        alt = escortPoint.y,
                        alt_type = "BARO",
                        speed = speed,
                        speed_locked = true,
                        ETA = 0,
                        ETA_locked = false,
                        action = "Turning Point",
                        type = "Turning Point",
                        task = {
                            id = "ComboTask",
                            params = {tasks = tasks}
                        }
                    }
                }
            }
        }
    }
end

local function setAirOption(controller, optionName, valueGroup, valueName, directValue)
    if not controller or not AI or not AI.Option or not AI.Option.Air then return false end
    local air = AI.Option.Air
    local optionId = air.id and air.id[optionName]
    if optionId == nil then return false end

    local value = directValue
    if valueGroup and valueName and air.val and air.val[valueGroup] then
        value = air.val[valueGroup][valueName]
    end
    if value == nil then return false end

    local ok = pcall(function()
        controller:setOption(optionId, value)
    end)
    return ok
end

local function applySafeAirOptions(controller, mode)
    setAirOption(controller, "ROE", "ROE", "OPEN_FIRE")
    setAirOption(controller, "REACTION_ON_THREAT", "REACTION_ON_THREAT", "EVADE_FIRE")
    setAirOption(controller, "RTB_ON_BINGO", nil, nil, false)
    setAirOption(controller, "RTB_ON_OUT_OF_AMMO", nil, nil, false)
    setAirOption(controller, "PROHIBIT_AA", nil, nil, false)

    local prohibitGround = mode == "ESCORT" or mode == "CAP"
    setAirOption(controller, "PROHIBIT_AG", nil, nil, prohibitGround)
end

local function makeStrikeTask(state)
    if not state.commandPoint then return nil end
    local expend = "Auto"
    if AI and AI.Task and AI.Task.WeaponExpend and AI.Task.WeaponExpend.AUTO then
        expend = AI.Task.WeaponExpend.AUTO
    end

    return {
        id = "Bombing",
        params = {
            point = {x = state.commandPoint.x, y = state.commandPoint.z},
            attackQty = 1,
            attackQtyLimit = true,
            expend = expend,
            groupAttack = true,
            altitudeEnabled = false,
            directionEnabled = false,
        }
    }
end

local function pushStrikeTask(state, expectedOrderVersion)
    if not state or ACTIVE[state.playerName] ~= state then return end
    if state.mode ~= "STRIKE" or state.orderVersion ~= expectedOrderVersion then return end

    local escortGroup = getGroupByName(state.escortGroupName)
    local controller = escortGroup and safeCall(escortGroup, "getController") or nil
    local strikeTask = makeStrikeTask(state)
    if not controller or not strikeTask then
        warn("No se pudo aplicar STRIKE a " .. tostring(state.escortGroupName))
        return
    end

    local ok, err = pcall(function()
        controller:pushTask(strikeTask)
    end)
    if ok then
        state.strikeActiveUntil = now() + CFG.STRIKE_RETURN_SECONDS
        state.status = "ATACANDO_STRIKE"
        log("Tarea STRIKE aplicada a " .. tostring(state.escortGroupName))
    else
        warn("Error pushTask STRIKE: " .. tostring(err))
    end
end

local function applyEscortMissionNow(state)
    if not state or ACTIVE[state.playerName] ~= state then
        return false, "estado no activo"
    end

    local playerUnit = findPlayerUnitByName(state.playerName)
    local escortGroup = getGroupByName(state.escortGroupName)
    local escortUnit = getUnitByName(state.escortUnitName)
    if not playerUnit then return false, "jugador no disponible" end
    if not escortGroup or not escortUnit then return false, "escolta no disponible" end

    local controller = safeCall(escortGroup, "getController")
    if not controller then return false, "controller no disponible" end

    local missionTask, taskError = makeMissionTask(state, escortUnit, playerUnit)
    if not missionTask then return false, taskError end

    local ok, err = pcall(function()
        controller:setTask(missionTask)
    end)
    if not ok then return false, err end

    applySafeAirOptions(controller, state.mode)
    state.lastTaskAppliedAt = now()
    state.status = "ESCOLTANDO"
    state.taskApplyCount = (state.taskApplyCount or 0) + 1

    log(
        "Tarea aplicada. escolta=" .. tostring(state.escortGroupName) ..
        " objetivoGroupId=" .. tostring(safeCall(safeCall(playerUnit, "getGroup"), "getID")) ..
        " modo=" .. tostring(state.mode) ..
        " distancia=" .. tostring(state.requestedDistance)
    )

    return true
end

local function scheduleEscortMission(state, reason)
    if not state or ACTIVE[state.playerName] ~= state then return end
    state.taskGeneration = (state.taskGeneration or 0) + 1
    local generation = state.taskGeneration
    local attempts = 0
    local orderVersion = state.orderVersion

    debugLog("Programando setTask. escolta=" .. tostring(state.escortGroupName) .. " motivo=" .. tostring(reason))

    schedule(function(_, time)
        if not state or ACTIVE[state.playerName] ~= state then return nil end
        if state.taskGeneration ~= generation then return nil end

        attempts = attempts + 1
        local ok, err = applyEscortMissionNow(state)
        if ok then
            if state.mode == "STRIKE" then
                schedule(function()
                    pushStrikeTask(state, orderVersion)
                    return nil
                end, nil, 1)
            end
            return nil
        end

        warn(
            "Reintento Controller.setTask " .. tostring(attempts) .. "/" ..
            tostring(CFG.SET_TASK_RETRIES) .. " para " .. tostring(state.escortGroupName) ..
            ": " .. tostring(err)
        )

        if attempts < CFG.SET_TASK_RETRIES then
            return time + CFG.SET_TASK_RETRY_INTERVAL
        end

        state.status = "ERROR_TAREA"
        outGroup(state.playerGroupId,
            "La escolta fue creada, pero DCS no acepto su tarea despues de " ..
            tostring(CFG.SET_TASK_RETRIES) .. " intentos.", 12)
        return nil
    end, nil, CFG.SET_TASK_DELAY)
end

----------------------------------------------------------------
-- CREACION, ACTUALIZACION Y CANCELACION
----------------------------------------------------------------
local function destroyEscortGroup(state)
    if not state or not state.escortGroupName then return end
    local group = getGroupByName(state.escortGroupName)
    if group then
        local ok, err = pcall(function() group:destroy() end)
        if not ok then warn("Error destruyendo escolta: " .. tostring(err)) end
    end
end

local function removeState(state)
    if not state then return end
    if ACTIVE[state.playerName] == state then
        ACTIVE[state.playerName] = nil
    end
end

local function cancelEscort(state, reason, notify)
    if not state then return false end
    log(
        "Cancelacion. jugador=" .. tostring(state.playerName) ..
        " escolta=" .. tostring(state.escortGroupName) ..
        " motivo=" .. tostring(reason)
    )

    state.cancelled = true
    state.status = "CANCELADA"
    state.taskGeneration = (state.taskGeneration or 0) + 1
    removeState(state)

    if notify ~= false then
        outGroup(state.playerGroupId,
            "Escolta cancelada.\n\nMotivo: " .. tostring(reason or "solicitud del jugador") .. ".", 10)
    end

    schedule(function()
        destroyEscortGroup(state)
        return nil
    end, nil, CFG.DESTROY_DELAY_ON_CANCEL)
    return true
end

local function createEscortForUnit(playerUnit, requestedDistance, mode, commandPoint, source)
    local valid, reason, descriptor = validatePlayerForEscort(playerUnit, false)
    if not valid then
        local groupId = descriptor and descriptor.groupId or nil
        outGroup(groupId,
            "No es posible desplegar una escolta.\n\nMotivo:\n" .. tostring(reason), 12)
        return false, reason
    end

    requestedDistance = clamp(requestedDistance or CFG.DEFAULT_ESCORT_DISTANCE,
        CFG.MIN_ESCORT_DISTANCE, CFG.MAX_ESCORT_DISTANCE)
    mode = normalizeMode(mode) or CFG.DEFAULT_MODE

    local ignoredNames = {[descriptor.unitName] = true}
    local spawn, spawnError = findSafeSpawn(playerUnit, requestedDistance, ignoredNames)
    if not spawn then
        outGroup(descriptor.groupId,
            "No es posible desplegar una escolta.\n\nMotivo:\n" .. tostring(spawnError), 12)
        return false, spawnError
    end

    local escortId = STATE.nextEscortId
    STATE.nextEscortId = STATE.nextEscortId + 1

    local groupData, buildInfo = buildEscortGroupData(descriptor, escortId, spawn)
    if not groupData then
        local payloadInfo = buildInfo and buildInfo.payloadInfo or nil
        local errorText = buildInfo and buildInfo.error or "No fue posible construir el grupo de escolta."
        if payloadInfo and payloadInfo.warning then errorText = errorText .. "\n" .. payloadInfo.warning end
        outGroup(descriptor.groupId, "No fue posible crear la escolta.\n\n" .. tostring(errorText), 14)
        warn(errorText)
        return false, errorText
    end

    log(
        "Solicitud recibida. jugador=" .. tostring(descriptor.playerName) ..
        " unidad=" .. tostring(descriptor.unitName) ..
        " grupo=" .. tostring(descriptor.groupName) ..
        " tipo=" .. tostring(descriptor.aircraftType) ..
        " AGL=" .. tostring(round(descriptor.agl, 1)) ..
        " modo=" .. tostring(mode)
    )
    log(
        "Posicion spawn x=" .. tostring(round(spawn.point.x, 2)) ..
        " y=" .. tostring(round(spawn.point.y, 2)) ..
        " z=" .. tostring(round(spawn.point.z, 2))
    )

    local ok, dynResult = pcall(mist.dynAdd, groupData)
    if not ok or not dynResult then
        local errorText = ok and "mist.dynAdd devolvio false" or tostring(dynResult)
        warn("Fallo mist.dynAdd: " .. errorText)
        outGroup(descriptor.groupId,
            "No fue posible crear la escolta.\n\nError: " .. errorText, 12)
        return false, errorText
    end

    local state = {
        id = escortId,
        playerName = descriptor.playerName,
        playerUnitName = descriptor.unitName,
        playerGroupName = descriptor.groupName,
        playerGroupId = descriptor.groupId,
        coalition = descriptor.coalition,
        country = descriptor.country,
        aircraftType = descriptor.aircraftType,

        escortGroupName = buildInfo.groupName,
        escortUnitName = buildInfo.unitName,
        escortGroupId = buildInfo.groupId,
        escortUnitId = buildInfo.unitId,

        createdAt = now(),
        mode = mode,
        requestedDistance = requestedDistance,
        commandPoint = commandPoint and deepCopy(commandPoint) or nil,
        source = source or "MENU",
        status = "CREADA",
        copiedProperties = buildInfo.copied,
        cloneSources = buildInfo.source,
        payloadInfo = buildInfo.payloadInfo,
        spawnPoint = deepCopy(spawn.point),
        sideSign = (escortId % 2 == 0) and -1 or 1,

        orderVersion = 1,
        taskGeneration = 0,
        lastTaskAppliedAt = 0,
        lastRecoveryAt = 0,
        recoveryReapplyCount = 0,
        respawnCount = 0,
        stoppedSince = nil,
        landingStoppedSince = nil,
        playerMissingSince = nil,
        combatUntil = 0,
    }

    ACTIVE[state.playerName] = state

    log(
        "mist.dynAdd correcto. grupo=" .. tostring(state.escortGroupName) ..
        " unidad=" .. tostring(state.escortUnitName)
    )
    debugLog("Propiedades copiadas: payload=" .. tostring(state.copiedProperties.payload) ..
        " pylons=" .. tostring(state.copiedProperties.pylons) ..
        " fuentePayload=" .. tostring(state.payloadInfo and state.payloadInfo.source) ..
        " livery=" .. tostring(state.copiedProperties.livery) ..
        " AddPropAircraft=" .. tostring(state.copiedProperties.AddPropAircraft))

    local payloadLine = state.payloadInfo and tostring(state.payloadInfo.source) or "N/D"
    if state.payloadInfo and state.payloadInfo.profileName then
        payloadLine = payloadLine .. " - " .. tostring(state.payloadInfo.profileName)
    end
    if state.payloadInfo and state.payloadInfo.score then
        payloadLine = payloadLine .. " (" .. tostring(math.floor(state.payloadInfo.score * 100 + 0.5)) .. "%)"
    end
    local payloadWarning = state.payloadInfo and state.payloadInfo.warning
        and ("\n\nADVERTENCIA PAYLOAD:\n" .. tostring(state.payloadInfo.warning)) or ""

    outGroup(descriptor.groupId,
        "Escolta desplegada.\n\n" ..
        "Jugador: " .. tostring(state.playerName) .. "\n" ..
        "Aeronave: " .. tostring(state.aircraftType) .. "\n" ..
        "Grupo: " .. tostring(state.escortGroupName) .. "\n" ..
        "Modo: " .. tostring(state.mode) .. "\n" ..
        "Payload: " .. payloadLine .. "\n" ..
        "Pilones armados: " .. tostring(state.payloadInfo and state.payloadInfo.pylonCount or 0) .. "\n" ..
        "Distancia: " .. tostring(math.floor(state.requestedDistance)) .. " metros." .. payloadWarning, 15)

    scheduleEscortMission(state, "CREACION")
    return true, state
end

local function updateEscortOrder(state, distance, mode, commandPoint, source)
    if not state or ACTIVE[state.playerName] ~= state then
        return false, "La escolta activa ya no existe."
    end

    distance = clamp(distance or state.requestedDistance or CFG.DEFAULT_ESCORT_DISTANCE,
        CFG.MIN_ESCORT_DISTANCE, CFG.MAX_ESCORT_DISTANCE)
    mode = normalizeMode(mode) or state.mode or CFG.DEFAULT_MODE

    if mode == "STRIKE" and not commandPoint then
        return false, "El modo STRIKE requiere el punto de una etiqueta F10."
    end

    state.requestedDistance = distance
    state.mode = mode
    state.commandPoint = commandPoint and deepCopy(commandPoint) or nil
    state.source = source or state.source
    state.orderVersion = (state.orderVersion or 0) + 1
    state.status = "ORDEN_ACTUALIZADA"
    state.strikeActiveUntil = nil

    log(
        "Cambio de modo. jugador=" .. tostring(state.playerName) ..
        " escolta=" .. tostring(state.escortGroupName) ..
        " modo=" .. tostring(mode) ..
        " distancia=" .. tostring(distance)
    )

    scheduleEscortMission(state, "CAMBIO_MODO")
    outGroup(state.playerGroupId,
        "Orden actualizada.\n\n" ..
        "Escolta: " .. tostring(state.escortGroupName) .. "\n" ..
        "Distancia: " .. tostring(math.floor(distance)) .. " metros\n" ..
        "Modo: " .. tostring(mode), 12)
    return true
end

----------------------------------------------------------------
-- INFORMACION DEL MENU
----------------------------------------------------------------
local function showMyEscort(playerUnit)
    local descriptor = getPlayerDescriptor(playerUnit)
    if not descriptor then return end
    local state = ACTIVE[descriptor.playerName]
    if not state then
        outGroup(descriptor.groupId, "No tienes una escolta activa.", 8)
        return
    end

    local escortUnit = getUnitByName(state.escortUnitName)
    local playerPoint = safeCall(playerUnit, "getPoint")
    local escortPoint = escortUnit and safeCall(escortUnit, "getPoint") or nil
    local distance = playerPoint and escortPoint and distance3D(playerPoint, escortPoint) or nil
    local altitude = escortPoint and escortPoint.y or nil

    local message =
        "MI ESCOLTA\n\n" ..
        "Jugador: " .. tostring(state.playerName) .. "\n" ..
        "Tipo: " .. tostring(state.aircraftType) .. "\n" ..
        "Grupo: " .. tostring(state.escortGroupName) .. "\n" ..
        "Modo: " .. tostring(state.mode) .. "\n" ..
        "Fuente payload: " .. tostring(state.payloadInfo and state.payloadInfo.source or "N/D") .. "\n" ..
        "Perfil payload: " .. tostring(state.payloadInfo and state.payloadInfo.profileName or "N/D") .. "\n" ..
        "Pilones armados: " .. tostring(state.payloadInfo and state.payloadInfo.pylonCount or 0) .. "\n" ..
        "Distancia ordenada: " .. tostring(math.floor(state.requestedDistance)) .. " m\n" ..
        "Distancia actual: " .. (distance and tostring(math.floor(distance)) .. " m" or "N/D") .. "\n" ..
        "Altitud escolta MSL: " .. (altitude and tostring(math.floor(altitude)) .. " m" or "N/D") .. "\n" ..
        "Estado: " .. tostring(state.status or "DESCONOCIDO") .. "\n" ..
        "Tiempo activo: " .. formatDuration(now() - state.createdAt)

    outGroup(descriptor.groupId, message, 15)
end

local function showActiveEscorts(side, groupId)
    local states = {}
    for _, state in pairs(ACTIVE) do
        if state.coalition == side then states[#states + 1] = state end
    end
    table.sort(states, function(a, b) return tostring(a.playerName) < tostring(b.playerName) end)

    if #states == 0 then
        outGroup(groupId, "No hay escoltas activas en tu coalicion.", 8)
        return
    end

    local lines = {"ESCOLTAS ACTIVAS - COALICION", ""}
    for index, state in ipairs(states) do
        lines[#lines + 1] = tostring(index) .. ". " .. tostring(state.playerName) ..
            " | " .. tostring(state.aircraftType) ..
            " | " .. tostring(state.mode) ..
            " | " .. tostring(state.status)
    end
    outGroup(groupId, table.concat(lines, "\n"), 15)
end

----------------------------------------------------------------
-- CALLBACKS DEL MENU
----------------------------------------------------------------
local function showPayloadDiagnostic(playerUnit)
    local descriptor = getPlayerDescriptor(playerUnit)
    if not descriptor then return end
    local sourceData = getSourceData(descriptor)
    local _, payloadInfo = resolvePayload(playerUnit, descriptor, sourceData)

    local profileText = payloadInfo and payloadInfo.profileName or "N/D"
    local scoreText = payloadInfo and payloadInfo.score
        and (tostring(math.floor(payloadInfo.score * 100 + 0.5)) .. "%") or "N/D"
    local message =
        "DIAGNOSTICO PAYLOAD - SLOT DINAMICO\n\n" ..
        "Jugador: " .. tostring(descriptor.playerName) .. "\n" ..
        "Unidad: " .. tostring(descriptor.unitName) .. "\n" ..
        "Aeronave: " .. tostring(descriptor.aircraftType) .. "\n" ..
        "Fuente: " .. tostring(payloadInfo and payloadInfo.source or "N/D") .. "\n" ..
        "Perfil: " .. tostring(profileText) .. "\n" ..
        "Coincidencia: " .. tostring(scoreText) .. "\n" ..
        "Pilones resueltos: " .. tostring(payloadInfo and payloadInfo.pylonCount or 0) .. "\n\n" ..
        "Armamento runtime:\n" .. tostring(payloadInfo and payloadInfo.ammoSummary or "N/D")

    if payloadInfo and payloadInfo.warning then
        message = message .. "\n\nADVERTENCIA:\n" .. tostring(payloadInfo.warning)
    end

    log("PAYLOAD DIAGNOSTIC jugador=" .. tostring(descriptor.playerName) ..
        " unidad=" .. tostring(descriptor.unitName) ..
        " tipo=" .. tostring(descriptor.aircraftType) ..
        " fuente=" .. tostring(payloadInfo and payloadInfo.source) ..
        " perfil=" .. tostring(profileText) ..
        " score=" .. tostring(scoreText) ..
        " ammo=" .. tostring(payloadInfo and payloadInfo.ammoSummary))
    outGroup(descriptor.groupId, message, 20)
end

local function menuPayloadDiagnostic(argument)
    local playerUnit, errorText = resolveMenuPlayer(argument)
    if not playerUnit then
        outGroup(argument and argument.groupId,
            "No es posible identificar al solicitante.\n\n" .. tostring(errorText), 10)
        return
    end
    showPayloadDiagnostic(playerUnit)
end

local function menuRequest(argument)
    local playerUnit, errorText = resolveMenuPlayer(argument)
    if not playerUnit then
        outGroup(argument and argument.groupId,
            "No es posible identificar al solicitante.\n\n" .. tostring(errorText), 10)
        return
    end
    createEscortForUnit(playerUnit, CFG.DEFAULT_ESCORT_DISTANCE, CFG.DEFAULT_MODE, nil, "MENU")
end

local function menuCancel(argument)
    local playerUnit, errorText = resolveMenuPlayer(argument)
    if not playerUnit then
        outGroup(argument and argument.groupId,
            "No es posible identificar al solicitante.\n\n" .. tostring(errorText), 10)
        return
    end
    local descriptor = getPlayerDescriptor(playerUnit)
    local state = descriptor and ACTIVE[descriptor.playerName] or nil
    if not state then
        outGroup(descriptor and descriptor.groupId or argument.groupId, "No tienes una escolta activa.", 8)
        return
    end
    cancelEscort(state, "cancelada por el jugador", true)
end

local function menuShowMine(argument)
    local playerUnit, errorText = resolveMenuPlayer(argument)
    if not playerUnit then
        outGroup(argument and argument.groupId,
            "No es posible identificar al solicitante.\n\n" .. tostring(errorText), 10)
        return
    end
    showMyEscort(playerUnit)
end

local function menuShowActive(argument)
    local playerUnit, errorText = resolveMenuPlayer(argument)
    if not playerUnit then
        outGroup(argument and argument.groupId,
            "No es posible identificar al solicitante.\n\n" .. tostring(errorText), 10)
        return
    end
    local descriptor = getPlayerDescriptor(playerUnit)
    if descriptor then showActiveEscorts(descriptor.coalition, descriptor.groupId) end
end

local function addPlayerCommands(groupId, rootPath, playerName)
    local argument = {groupId = groupId, playerName = playerName}
    missionCommands.addCommandForGroup(groupId, "Solicitar escolta", rootPath, menuRequest, argument)
    missionCommands.addCommandForGroup(groupId, "Cancelar mi escolta", rootPath, menuCancel, argument)
    missionCommands.addCommandForGroup(groupId, "Ver mi escolta", rootPath, menuShowMine, argument)
    missionCommands.addCommandForGroup(groupId, "Ver escoltas activas", rootPath, menuShowActive, argument)
    if CFG.SHOW_PAYLOAD_DIAGNOSTIC_MENU then
        missionCommands.addCommandForGroup(groupId, "Diagnosticar payload actual", rootPath, menuPayloadDiagnostic, argument)
    end
end

local function buildMenuForGroup(groupId, players)
    local old = STATE.menus[groupId]
    if old and old.root then
        pcall(missionCommands.removeItemForGroup, groupId, old.root)
    end

    local root = missionCommands.addSubMenuForGroup(groupId, CFG.MENU_NAME)
    if #players == 1 then
        local playerName = safeCall(players[1], "getPlayerName")
        addPlayerCommands(groupId, root, playerName)
    else
        for _, unit in ipairs(players) do
            local playerName = safeCall(unit, "getPlayerName")
            local playerRoot = missionCommands.addSubMenuForGroup(groupId, tostring(playerName), root)
            addPlayerCommands(groupId, playerRoot, playerName)
        end
    end

    local names = {}
    for _, unit in ipairs(players) do names[#names + 1] = safeCall(unit, "getPlayerName") or "" end
    table.sort(names)
    STATE.menus[groupId] = {
        root = root,
        signature = table.concat(names, "|"),
        lastSeenAt = now(),
    }
    debugLog("Menu creado para grupo " .. tostring(groupId) .. " jugadores=" .. table.concat(names, ","))
end

local function scanMenus()
    local grouped = {}
    for _, unit in ipairs(getAllPlayers()) do
        local group = safeCall(unit, "getGroup")
        local groupId = group and safeCall(group, "getID") or nil
        if groupId then
            grouped[groupId] = grouped[groupId] or {}
            grouped[groupId][#grouped[groupId] + 1] = unit
        end
    end

    for groupId, players in pairs(grouped) do
        table.sort(players, function(a, b)
            return tostring(safeCall(a, "getPlayerName") or "") < tostring(safeCall(b, "getPlayerName") or "")
        end)
        local names = {}
        for _, unit in ipairs(players) do names[#names + 1] = safeCall(unit, "getPlayerName") or "" end
        local signature = table.concat(names, "|")
        local menu = STATE.menus[groupId]
        if not menu or menu.signature ~= signature then
            buildMenuForGroup(groupId, players)
        else
            menu.lastSeenAt = now()
        end
    end

    for groupId, menu in pairs(STATE.menus) do
        if not grouped[groupId] and now() - (menu.lastSeenAt or 0) > CFG.MENU_SCAN_INTERVAL * 2 then
            if menu.root then pcall(missionCommands.removeItemForGroup, groupId, menu.root) end
            STATE.menus[groupId] = nil
        end
    end
end

----------------------------------------------------------------
-- ETIQUETAS F10
----------------------------------------------------------------
local function parseMarkCommand(text)
    local normalized = string.lower(normalizeSpaces(text))
    local tokens = {}
    for token in normalized:gmatch("%S+") do tokens[#tokens + 1] = token end
    if tokens[1] ~= "escolta" and tokens[1] ~= "escort" then return nil end

    local distance = CFG.DEFAULT_ESCORT_DISTANCE
    local mode = CFG.DEFAULT_MODE

    for index = 2, #tokens do
        local number = tonumber(tokens[index])
        if number then
            distance = number
        else
            local parsedMode = normalizeMode(tokens[index])
            if parsedMode then mode = parsedMode else
                return false, "Modo no valido: " .. tostring(tokens[index])
            end
        end
    end

    if distance < CFG.MIN_ESCORT_DISTANCE or distance > CFG.MAX_ESCORT_DISTANCE then
        return false,
            "La distancia debe estar entre " .. tostring(CFG.MIN_ESCORT_DISTANCE) ..
            " y " .. tostring(CFG.MAX_ESCORT_DISTANCE) .. " metros."
    end

    return {
        distance = distance,
        mode = mode,
    }
end

local function nearestUniquePlayer(units, point)
    local candidates = {}
    for _, unit in ipairs(units or {}) do
        local descriptor = getPlayerDescriptor(unit)
        if descriptor and descriptor.point then
            -- La etiqueta esta sobre el mapa; la asociacion usa distancia horizontal.
            local dist = distance2D(descriptor.point, point)
            if dist <= CFG.MARK_REQUEST_RADIUS then
                candidates[#candidates + 1] = {unit = unit, descriptor = descriptor, distance = dist}
            end
        end
    end

    table.sort(candidates, function(a, b) return a.distance < b.distance end)
    if #candidates == 0 then return nil, "No hay jugadores validos cerca de la etiqueta." end

    if #candidates >= 2 and math.abs(candidates[2].distance - candidates[1].distance) < CFG.MARK_AMBIGUITY_DISTANCE then
        return nil, "No fue posible identificar de forma segura al solicitante.\n\nCrea la etiqueta mas cerca de tu aeronave.", candidates
    end

    return candidates[1].unit, nil, candidates
end

local function resolveMarkPlayer(event)
    local markPoint = event.pos
    if not markPoint then return nil, "La etiqueta no contiene una posicion valida." end

    local eventGroupId = event.groupID or event.groupId
    if eventGroupId and tonumber(eventGroupId) and tonumber(eventGroupId) > 0 then
        local unit, err, candidates = nearestUniquePlayer(getPlayersInGroup(eventGroupId), markPoint)
        if unit then return unit end
        if candidates and #candidates > 0 then return nil, err, candidates[1].descriptor.coalition end
    end

    local eventCoalition = tonumber(event.coalition)
    local units = nil
    if eventCoalition == coalition.side.RED or eventCoalition == coalition.side.BLUE then
        units = getCoalitionPlayers(eventCoalition)
    else
        units = getAllPlayers()
    end

    local unit, err, candidates = nearestUniquePlayer(units, markPoint)
    if unit then
        local descriptor = getPlayerDescriptor(unit)
        if eventCoalition == coalition.side.RED or eventCoalition == coalition.side.BLUE then
            if descriptor and descriptor.coalition ~= eventCoalition then
                return nil, "La etiqueta y el jugador pertenecen a coaliciones diferentes.", eventCoalition
            end
        end
        return unit
    end

    return nil, err, eventCoalition
end

local function processMarkEvent(event)
    if not event or not event.idx then return end
    local parsed, parseError = parseMarkCommand(event.text)
    if parsed == nil then return end

    local signature = tostring(event.text) .. "|" .. tostring(event.pos and event.pos.x) .. "|" .. tostring(event.pos and event.pos.z)
    if STATE.processedMarks[event.idx] == signature then return end
    STATE.processedMarks[event.idx] = signature

    if parsed == false then
        local side = tonumber(event.coalition)
        if side == coalition.side.RED or side == coalition.side.BLUE then
            outCoalition(side, "Comando de escolta invalido.\n\n" .. tostring(parseError), 10)
        end
        return
    end

    local playerUnit, resolveError, errorCoalition = resolveMarkPlayer(event)
    if not playerUnit then
        if errorCoalition == coalition.side.RED or errorCoalition == coalition.side.BLUE then
            outCoalition(errorCoalition, tostring(resolveError), 12)
        else
            warn("Etiqueta no asociada: " .. tostring(resolveError))
        end
        return
    end

    local valid, validationError, descriptor = validatePlayerForEscort(playerUnit, true)
    if not valid then
        outGroup(descriptor and descriptor.groupId,
            "No es posible procesar la orden de escolta.\n\nMotivo:\n" .. tostring(validationError), 12)
        return
    end

    local state = ACTIVE[descriptor.playerName]
    local ok, result = nil, nil
    if state then
        ok, result = updateEscortOrder(state, parsed.distance, parsed.mode, event.pos, "MARK")
    else
        ok, result = createEscortForUnit(playerUnit, parsed.distance, parsed.mode, event.pos, "MARK")
    end

    if not ok then
        outGroup(descriptor.groupId, "No se pudo aplicar la orden.\n\n" .. tostring(result), 10)
        return
    end

    if CFG.AUTO_REMOVE_MARK and trigger and trigger.action and trigger.action.removeMark then
        pcall(trigger.action.removeMark, event.idx)
    end
end

----------------------------------------------------------------
-- DETECCION DE COMBATE Y RECUPERACION
----------------------------------------------------------------
local function escortDetectedTargets(escortUnit)
    local controller = safeCall(escortUnit, "getController")
    if not controller or type(controller.getDetectedTargets) ~= "function" then return 0 end
    local ok, targets = pcall(function() return controller:getDetectedTargets() end)
    if ok and type(targets) == "table" then return #targets end
    return 0
end

local function respawnEscort(state, reason)
    if not state or ACTIVE[state.playerName] ~= state then return false end
    if not CFG.ALLOW_SAFE_RESPAWN then return false end
    if (state.respawnCount or 0) >= CFG.MAX_RESPAWNS_PER_ESCORT then
        cancelEscort(state, "se agotaron los intentos de recuperacion", true)
        return false
    end

    local playerUnit = findPlayerUnitByName(state.playerName)
    local valid, validationError, descriptor = validatePlayerForEscort(playerUnit, true)
    if not valid then
        cancelEscort(state, "no fue posible recrearla: " .. tostring(validationError), true)
        return false
    end

    local ignored = {[descriptor.unitName] = true, [state.escortUnitName] = true}
    local spawn, spawnError = findSafeSpawn(playerUnit, state.requestedDistance, ignored)
    if not spawn then
        warn("Respawn seguro rechazado: " .. tostring(spawnError))
        return false
    end

    local oldGroupName = state.escortGroupName
    destroyEscortGroup(state)

    local newEscortId = STATE.nextEscortId
    STATE.nextEscortId = STATE.nextEscortId + 1
    local groupData, buildInfo = buildEscortGroupData(descriptor, newEscortId, spawn)
    if not groupData then
        warn("Fallo resolviendo payload al recrear escolta: " .. tostring(buildInfo and buildInfo.error))
        return false
    end
    local ok, dynResult = pcall(mist.dynAdd, groupData)
    if not ok or not dynResult then
        warn("Fallo al recrear escolta: " .. tostring(dynResult))
        return false
    end

    state.id = newEscortId
    state.escortGroupName = buildInfo.groupName
    state.escortUnitName = buildInfo.unitName
    state.escortGroupId = buildInfo.groupId
    state.escortUnitId = buildInfo.unitId
    state.spawnPoint = deepCopy(spawn.point)
    state.copiedProperties = buildInfo.copied
    state.cloneSources = buildInfo.source
    state.payloadInfo = buildInfo.payloadInfo
    state.respawnCount = (state.respawnCount or 0) + 1
    state.recoveryReapplyCount = 0
    state.lastRecoveryAt = now()
    state.status = "RECREADA"
    state.taskGeneration = (state.taskGeneration or 0) + 1

    log(
        "Recreacion segura. jugador=" .. tostring(state.playerName) ..
        " anterior=" .. tostring(oldGroupName) ..
        " nueva=" .. tostring(state.escortGroupName) ..
        " motivo=" .. tostring(reason)
    )
    outGroup(state.playerGroupId,
        "La escolta fue recreada en una posicion segura para recuperar la formacion.", 10)
    scheduleEscortMission(state, "RESPAWN_SEGURO")
    return true
end

local function requestRecovery(state, reason)
    local current = now()
    if current - (state.lastRecoveryAt or 0) < CFG.RECOVERY_REAPPLY_COOLDOWN then return end

    state.lastRecoveryAt = current
    state.recoveryReapplyCount = (state.recoveryReapplyCount or 0) + 1
    state.status = "RECUPERANDO_FORMACION"

    log(
        "Recuperacion. escolta=" .. tostring(state.escortGroupName) ..
        " intento=" .. tostring(state.recoveryReapplyCount) ..
        " motivo=" .. tostring(reason)
    )

    if state.recoveryReapplyCount <= CFG.MAX_RECOVERY_REAPPLIES then
        scheduleEscortMission(state, "RECUPERACION: " .. tostring(reason))
        return
    end

    if CFG.ALLOW_SAFE_RESPAWN then
        schedule(function()
            if ACTIVE[state.playerName] ~= state then return nil end

            local playerUnit = findPlayerUnitByName(state.playerName)
            local escortUnit = getUnitByName(state.escortUnitName)
            local playerPoint = playerUnit and safeCall(playerUnit, "getPoint") or nil
            local escortPoint = escortUnit and safeCall(escortUnit, "getPoint") or nil
            local stillSeparated = playerPoint and escortPoint and
                distance3D(playerPoint, escortPoint) > CFG.MAX_SEPARATION_DISTANCE
            local stillStopped = escortUnit and getSpeed(escortUnit) < CFG.STOPPED_ESCORT_SPEED

            if stillSeparated or stillStopped then
                respawnEscort(state, reason)
            else
                state.recoveryReapplyCount = 0
                state.status = "ESCOLTANDO"
                log("Respawn de recuperacion cancelado: la escolta ya recupero la formacion.")
            end
            return nil
        end, nil, CFG.RECOVERY_RESPAWN_DELAY)
    end
end

local function monitorState(state)
    if not state or ACTIVE[state.playerName] ~= state then return end
    local current = now()
    local playerUnit = findPlayerUnitByName(state.playerName)

    if not playerUnit then
        state.playerMissingSince = state.playerMissingSince or current
        if current - state.playerMissingSince >= CFG.PLAYER_MISSING_GRACE then
            cancelEscort(state, "el jugador abandono la unidad o salio del servidor", false)
        end
        return
    end
    state.playerMissingSince = nil

    local descriptor = getPlayerDescriptor(playerUnit)
    if not descriptor then
        cancelEscort(state, "se perdio la asociacion con el jugador", false)
        return
    end

    if descriptor.unitName ~= state.playerUnitName or descriptor.groupName ~= state.playerGroupName then
        cancelEscort(state, "el jugador cambio de unidad", true)
        return
    end

    local escortGroup = getGroupByName(state.escortGroupName)
    local escortUnit = getUnitByName(state.escortUnitName)
    if not escortGroup or not escortUnit then
        cancelEscort(state, "la escolta fue destruida", true)
        return
    end

    local playerPoint = descriptor.point
    local escortPoint = safeCall(escortUnit, "getPoint")
    if not playerPoint or not escortPoint then return end

    state.currentDistance = distance3D(playerPoint, escortPoint)
    state.altitudeDifference = escortPoint.y - playerPoint.y
    state.escortSpeed = getSpeed(escortUnit)
    state.playerSpeed = descriptor.speed
    state.lastSeenAt = current

    local detectedCount = escortDetectedTargets(escortUnit)
    state.detectedTargets = detectedCount
    if detectedCount > 0 then
        state.combatUntil = current + CFG.COMBAT_GRACE_SECONDS
        state.status = "EN_COMBATE"
    elseif state.mode == "STRIKE" and state.strikeActiveUntil and current < state.strikeActiveUntil then
        state.status = "ATACANDO_STRIKE"
    elseif state.status == "EN_COMBATE" and current >= (state.combatUntil or 0) then
        state.status = "REGRESANDO_FORMACION"
    end

    if state.mode == "STRIKE" and state.strikeActiveUntil and current >= state.strikeActiveUntil then
        state.mode = "ESCORT"
        state.commandPoint = nil
        state.strikeActiveUntil = nil
        state.orderVersion = (state.orderVersion or 0) + 1
        state.status = "REGRESANDO_FORMACION"
        scheduleEscortMission(state, "FIN_STRIKE")
        outGroup(state.playerGroupId, "Ataque STRIKE finalizado. La escolta regresa a formacion.", 8)
    end

    local inCombatGrace = current < (state.combatUntil or 0)
    if state.currentDistance > CFG.MAX_SEPARATION_DISTANCE and not inCombatGrace then
        requestRecovery(state, "separacion de " .. tostring(math.floor(state.currentDistance)) .. " metros")
    elseif state.currentDistance <= CFG.MAX_SEPARATION_DISTANCE * 0.5 then
        state.recoveryReapplyCount = 0
        if not inCombatGrace and state.mode ~= "STRIKE" then state.status = "ESCOLTANDO" end
    end

    local playerInAir = safeCall(playerUnit, "inAir")
    local escortInAir = safeCall(escortUnit, "inAir")

    if playerInAir ~= false and escortInAir ~= false and state.escortSpeed < CFG.STOPPED_ESCORT_SPEED then
        state.stoppedSince = state.stoppedSince or current
        if current - state.stoppedSince >= CFG.STOPPED_ESCORT_SECONDS and not inCombatGrace then
            requestRecovery(state, "escolta detenida o sin velocidad")
            state.stoppedSince = current
        end
    else
        state.stoppedSince = nil
    end

    if CFG.REMOVE_ON_PLAYER_LANDING then
        if playerInAir == false and descriptor.speed <= CFG.LANDING_STOP_SPEED then
            state.landingStoppedSince = state.landingStoppedSince or current
            if current - state.landingStoppedSince >= CFG.LANDING_STOP_SECONDS then
                cancelEscort(state, "el jugador aterrizo y permanecio detenido", true)
                return
            end
        else
            state.landingStoppedSince = nil
        end
    end

    if (state.mode == "CAP" or state.mode == "CAS" or state.mode == "SEAD") and not state.commandPoint then
        if not state.lastModeAnchor or distance2D(state.lastModeAnchor, playerPoint) >= CFG.MODE_TASK_REFRESH_DISTANCE then
            scheduleEscortMission(state, "ACTUALIZAR_ZONA_MOVIL_" .. tostring(state.mode))
        end
    end
end

local function monitorAll()
    local states = {}
    for _, state in pairs(ACTIVE) do states[#states + 1] = state end
    for _, state in ipairs(states) do
        local ok, err = pcall(monitorState, state)
        if not ok then
            warn("Error monitorizando " .. tostring(state.playerName) .. ": " .. tostring(err))
        end
    end
end

----------------------------------------------------------------
-- EVENTOS
----------------------------------------------------------------
local EVENT_HANDLER = {}

function EVENT_HANDLER:onEvent(event)
    if not event or not event.id then return end

    if event.id == world.event.S_EVENT_MARK_ADDED or
       event.id == world.event.S_EVENT_MARK_CHANGE then
        local ok, err = pcall(processMarkEvent, event)
        if not ok then warn("Error procesando etiqueta: " .. tostring(err)) end
        return
    end

    if event.id == world.event.S_EVENT_MARK_REMOVED then
        if event.idx then STATE.processedMarks[event.idx] = nil end
        return
    end

    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT or
       event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT or
       event.id == world.event.S_EVENT_BIRTH then
        schedule(function()
            local ok, err = pcall(scanMenus)
            if not ok then warn("Error actualizando menus: " .. tostring(err)) end
            return nil
        end, nil, 1)
    end
end

----------------------------------------------------------------
-- API PUBLICA
----------------------------------------------------------------
function HES.registerDynamicPayload(key, data, metadata)
    if key == nil or type(data) ~= "table" then return false, "key o data invalidos" end
    local entry = deepCopy(data)
    if metadata ~= nil then entry.__metadata = deepCopy(metadata) end
    HES.DYNAMIC_PAYLOAD_REGISTRY[key] = entry
    HES.DYNAMIC_PAYLOAD_REGISTRY[tostring(key)] = entry
    return true
end

function HES.registerDynamicGroupData(groupData, metadata)
    if type(groupData) ~= "table" then return false, "groupData invalido" end
    local entry = {groupData = deepCopy(groupData), metadata = deepCopy(metadata), exact = true}
    if groupData.name then HES.DYNAMIC_PAYLOAD_REGISTRY[groupData.name] = entry end
    if groupData.groupId then HES.DYNAMIC_PAYLOAD_REGISTRY[groupData.groupId] = entry end
    for _, unitData in pairs(groupData.units or {}) do
        local unitName = unitData.name or unitData.unitName
        if unitName then HES.DYNAMIC_PAYLOAD_REGISTRY[unitName] = entry end
    end
    return true
end

function HES.registerPayloadProvider(provider)
    if type(provider) ~= "function" then return false, "provider debe ser funcion" end
    HES.PAYLOAD_PROVIDERS[#HES.PAYLOAD_PROVIDERS + 1] = provider
    return true
end

function HES.getRuntimePayloadDiagnostic(playerName)
    local unit = findPlayerUnitByName(playerName)
    if not unit then return nil, "jugador no encontrado" end
    local descriptor = getPlayerDescriptor(unit)
    local sourceData = getSourceData(descriptor)
    local payload, info = resolvePayload(unit, descriptor, sourceData)
    return {
        playerName = descriptor.playerName,
        unitName = descriptor.unitName,
        aircraftType = descriptor.aircraftType,
        payload = payload and deepCopy(payload) or nil,
        info = info and deepCopy(info) or nil,
    }
end

function HES.getEscort(playerName)
    return ACTIVE[playerName]
end

function HES.cancelPlayerEscort(playerName, reason)
    local state = ACTIVE[playerName]
    if not state then return false end
    return cancelEscort(state, reason or "cancelacion externa", true)
end

function HES.requestForPlayer(playerName, distance, mode, commandPoint)
    local unit = findPlayerUnitByName(playerName)
    if not unit then return false, "jugador no encontrado" end
    if ACTIVE[playerName] then
        return updateEscortOrder(ACTIVE[playerName], distance, mode, commandPoint, "API")
    end
    return createEscortForUnit(unit, distance, mode, commandPoint, "API")
end

----------------------------------------------------------------
-- INICIO
----------------------------------------------------------------
function HES.start()
    if STATE.started then
        log("El sistema ya estaba iniciado.")
        return
    end

    STATE.started = true
    STATE.eventHandler = EVENT_HANDLER
    world.addEventHandler(EVENT_HANDLER)

    schedule(function(_, time)
        local ok, err = pcall(scanMenus)
        if not ok then warn("Error en escaneo de menus: " .. tostring(err)) end
        return time + CFG.MENU_SCAN_INTERVAL
    end, nil, 1)

    schedule(function(_, time)
        local ok, err = pcall(monitorAll)
        if not ok then warn("Error en monitor general: " .. tostring(err)) end
        return time + CFG.MONITOR_INTERVAL
    end, nil, CFG.MONITOR_INTERVAL)

    log("HDEV Escort System v" .. HES.VERSION .. " iniciado correctamente.")
end

HES.start()
