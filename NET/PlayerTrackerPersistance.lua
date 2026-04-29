----------------------------------------------------------------
-- HDEV_PlayerStatsTracker.lua
-- Tracker de estadisticas de jugadores por nombre visible
--
-- Guarda:
-- - jugador
-- - modulo usado
-- - tiempo de uso por modulo
-- - muertes, crashes, eyecciones
-- - kills
-- - aterrizajes y lugar
--
-- IMPORTANTE:
-- Esta primera version NO usa UCID.
-- La identidad se guarda por Unit:getPlayerName().
----------------------------------------------------------------

HDEV_PlayerStats = HDEV_PlayerStats or {}
local PST = HDEV_PlayerStats

PST.VERSION = "1.0.0"

PST.CONFIG = PST.CONFIG or {
    DEBUG = true,

    -- Ruta dentro de Saved Games/DCS.openbeta/
    jsonRelativePath = "Config\\HorizontDev\\KOLA\\PlayerStats.json",

    -- Guardado
    autosaveInterval = 10,
    minWriteInterval = 5,

    -- Revision de jugadores activos
    heartbeatInterval = 10,

    -- Busqueda de aeropuerto si event.place no viene disponible
    landingAirbaseSearchRadius = 7000,

    -- Limites para que el JSON no crezca infinito
    maxKillLogEntries = 300,
    maxLandingLogEntries = 200,
    maxSessionLogEntries = 200,

    -- Kills
    countFriendlyKillsAsKills = false,
    countMapObjectKillsAsKills = true,

    -- Mensajes
    showPlayerMessages = false,
    screenMessageTime = 8
}

PST.STATE = PST.STATE or {
    initialized = false,
    dirty = false,
    lastWriteTime = -9999,
    lastAutosaveAt = -9999,

    doc = nil,

    -- sesiones activas por nombre de unidad
    activeSessions = {},

    -- respaldo corto por si llega DEAD/CRASH despues de perder la unidad
    recentEndedSessions = {},

    -- evita contar dos veces el mismo evento de perdida
    lossDedup = {}
}

----------------------------------------------------------------
-- VALIDACION BASICA
----------------------------------------------------------------

if not lfs or not lfs.writedir then
    trigger.action.outText("ERROR HDEV_PlayerStats: lfs.writedir no disponible. Revisa MissionScripting.lua.", 15)
    return
end

if not io then
    trigger.action.outText("ERROR HDEV_PlayerStats: io no disponible. Revisa MissionScripting.lua.", 15)
    return
end

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------

local function log(msg, time)
    env.info("[HDEV_PLAYER_STATS] " .. tostring(msg))
    if PST.CONFIG.DEBUG then
        trigger.action.outText("[HDEV_PLAYER_STATS] " .. tostring(msg), time or 6)
    end
end

local function playerMsg(coalitionId, msg)
    if not PST.CONFIG.showPlayerMessages then
        return
    end

    coalitionId = tonumber(coalitionId) or 0

    if coalitionId == coalition.side.RED or coalitionId == coalition.side.BLUE then
        trigger.action.outTextForCoalition(coalitionId, msg, PST.CONFIG.screenMessageTime or 8)
    else
        trigger.action.outText(msg, PST.CONFIG.screenMessageTime or 8)
    end
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------

local function now()
    return timer.getTime()
end

local function round(n, d)
    n = tonumber(n) or 0
    local m = 10 ^ (d or 0)
    return math.floor((n * m) + 0.5) / m
end

local function trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function validString(s)
    s = trim(s)
    if s == "" then
        return nil
    end
    return s
end

local function buildWriteDirPath(relativePath)
    if not relativePath or relativePath == "" then
        return nil
    end

    if relativePath:match("^%a:[\\/]") or relativePath:sub(1, 1) == "/" then
        return relativePath
    end

    return lfs.writedir() .. relativePath
end

local function getJsonPath()
    return buildWriteDirPath(PST.CONFIG.jsonRelativePath)
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
    if not path or path == "" then
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

local function appendLimited(list, entry, maxEntries)
    if type(list) ~= "table" then
        list = {}
    end

    list[#list + 1] = entry

    maxEntries = tonumber(maxEntries) or 100

    while #list > maxEntries do
        table.remove(list, 1)
    end

    return list
end

local function getTheatre()
    if env and env.mission and env.mission.theatre then
        return env.mission.theatre
    end

    return "UNKNOWN"
end

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end

    return nil
end

local function safeGetName(obj)
    if not obj or not obj.getName then
        return nil
    end

    return validString(safeCall(function()
        return obj:getName()
    end))
end

local function safeGetTypeName(obj)
    if not obj or not obj.getTypeName then
        return nil
    end

    return validString(safeCall(function()
        return obj:getTypeName()
    end))
end

local function safeGetPlayerName(unit)
    if not unit or not unit.getPlayerName then
        return nil
    end

    return validString(safeCall(function()
        return unit:getPlayerName()
    end))
end

local function safeGetCoalition(obj)
    if not obj or not obj.getCoalition then
        return nil
    end

    return tonumber(safeCall(function()
        return obj:getCoalition()
    end))
end

local function safeGetCountry(unit)
    if not unit or not unit.getCountry then
        return nil
    end

    return tonumber(safeCall(function()
        return unit:getCountry()
    end))
end

local function safeGetPoint(obj)
    if not obj or not obj.getPoint then
        return nil
    end

    local p = safeCall(function()
        return obj:getPoint()
    end)

    if not p then
        return nil
    end

    return {
        x = round(p.x or 0, 3),
        y = round(p.y or 0, 3),
        z = round(p.z or p.y or 0, 3)
    }
end

local function safeGetGroupName(unit)
    if not unit or not unit.getGroup then
        return nil
    end

    local grp = safeCall(function()
        return unit:getGroup()
    end)

    if not grp then
        return nil
    end

    return safeGetName(grp)
end

local function safeObjectCategory(obj)
    if not obj or not obj.getCategory then
        return nil
    end

    return tonumber(safeCall(function()
        return obj:getCategory()
    end))
end

local function objectCategoryToText(cat)
    if not cat then
        return "UNKNOWN"
    end

    if Object and Object.Category then
        if cat == Object.Category.UNIT then
            return "UNIT"
        elseif cat == Object.Category.WEAPON then
            return "WEAPON"
        elseif cat == Object.Category.STATIC then
            return "STATIC"
        elseif cat == Object.Category.BASE then
            return "BASE"
        elseif cat == Object.Category.SCENERY then
            return "SCENERY"
        elseif cat == Object.Category.CARGO then
            return "CARGO"
        end
    end

    return tostring(cat)
end

local function dist2D(a, b)
    if not a or not b then
        return math.huge
    end

    local ax = tonumber(a.x) or 0
    local az = tonumber(a.z or a.y) or 0
    local bx = tonumber(b.x) or 0
    local bz = tonumber(b.z or b.y) or 0

    local dx = ax - bx
    local dz = az - bz

    return math.sqrt(dx * dx + dz * dz)
end

local function getNearestAirbaseName(point)
    if not point or not world or not world.getAirbases then
        return nil, nil
    end

    local closestName = nil
    local closestDist = math.huge

    local airbases = safeCall(function()
        return world.getAirbases()
    end)

    if type(airbases) ~= "table" then
        return nil, nil
    end

    for _, ab in ipairs(airbases) do
        local abName = safeGetName(ab)
        local abPoint = safeGetPoint(ab)

        if abName and abPoint then
            local d = dist2D(point, abPoint)

            if d < closestDist then
                closestDist = d
                closestName = abName
            end
        end
    end

    local radius = tonumber(PST.CONFIG.landingAirbaseSearchRadius) or 7000

    if closestName and closestDist <= radius then
        return closestName, round(closestDist, 1)
    end

    return nil, nil
end

local function getEventPlaceName(event, point)
    if event and event.place then
        local placeName = safeGetName(event.place)
        if placeName then
            return placeName, 0, "event.place"
        end
    end

    local nearestName, nearestDist = getNearestAirbaseName(point)

    if nearestName then
        return nearestName, nearestDist, "nearestAirbase"
    end

    return "SIN_BASE_DETECTADA", nil, "unknown"
end

local function getEventId(name)
    if world and world.event and world.event[name] then
        return world.event[name]
    end

    return nil
end

local function eventIs(eventId, name)
    local id = getEventId(name)
    return id ~= nil and eventId == id
end

----------------------------------------------------------------
-- DOCUMENTO JSON
----------------------------------------------------------------

local function createEmptyDoc()
    return {
        meta = {
            version = PST.VERSION,
            source = "DCS Player Stats Tracker",
            theatre = getTheatre(),
            missionTime = round(now(), 3),
            updatedBy = "DCS"
        },
        players = {}
    }
end

local function normalizeDoc(doc)
    if type(doc) ~= "table" then
        doc = createEmptyDoc()
    end

    doc.meta = doc.meta or {}
    doc.meta.version = PST.VERSION
    doc.meta.source = "DCS Player Stats Tracker"
    doc.meta.theatre = getTheatre()

    doc.players = doc.players or {}

    return doc
end

local function loadDoc()
    local path = getJsonPath()
    local txt = safeReadFile(path)

    if not txt then
        return createEmptyDoc(), "nuevo"
    end

    local data, err = decodeJson(txt)

    if not data then
        log("No se pudo leer JSON existente. Se creara uno nuevo. Motivo: " .. tostring(err), 8)
        return createEmptyDoc(), "nuevo_por_error"
    end

    return normalizeDoc(data), "cargado"
end

local function markDirty()
    PST.STATE.dirty = true
end

function PST.saveNow(reason)
    if not PST.STATE.doc then
        return false
    end

    local t = now()
    local minWrite = tonumber(PST.CONFIG.minWriteInterval) or 5

    if (t - (PST.STATE.lastWriteTime or -9999)) < minWrite then
        return false
    end

    PST.STATE.doc.meta.version = PST.VERSION
    PST.STATE.doc.meta.theatre = getTheatre()
    PST.STATE.doc.meta.missionTime = round(t, 3)
    PST.STATE.doc.meta.updatedBy = "DCS"
    PST.STATE.doc.meta.lastReason = tostring(reason or "save")

    local payload = encodeJsonValue(PST.STATE.doc, 0)

    local ok = safeWriteFile(getJsonPath(), payload)

    if ok then
        PST.STATE.dirty = false
        PST.STATE.lastWriteTime = t
        return true
    end

    log("ERROR: no se pudo escribir PlayerStats.json", 10)
    return false
end

----------------------------------------------------------------
-- PLAYER / MODULE STATE
----------------------------------------------------------------

local function ensurePlayer(playerName)
    playerName = validString(playerName)
    if not playerName then
        return nil
    end

    local id = playerName
    local doc = PST.STATE.doc

    doc.players[id] = doc.players[id] or {
        id = id,
        name = playerName,

        firstSeenAt = round(now(), 3),
        lastSeenAt = round(now(), 3),

        lastUnitName = nil,
        lastGroupName = nil,
        lastModule = nil,
        lastCoalition = nil,
        lastCountry = nil,
        lastPoint = nil,

        totalFlightSeconds = 0,
        totalAirborneSeconds = 0,

        sorties = 0,
        takeoffs = 0,
        landings = 0,

        deaths = 0,
        crashes = 0,
        ejections = 0,

        kills = 0,
        friendlyKills = 0,
        mapKills = 0,

        killsByType = {},
        modules = {},

        killLog = {},
        landingLog = {},
        sessionLog = {}
    }

    local p = doc.players[id]

    p.name = playerName
    p.lastSeenAt = round(now(), 3)
    p.modules = p.modules or {}
    p.killsByType = p.killsByType or {}
    p.killLog = p.killLog or {}
    p.landingLog = p.landingLog or {}
    p.sessionLog = p.sessionLog or {}

    return p
end

local function ensureModule(player, moduleName)
    if not player then
        return nil
    end

    moduleName = validString(moduleName) or "UNKNOWN"

    player.modules = player.modules or {}

    player.modules[moduleName] = player.modules[moduleName] or {
        used = true,

        firstSeenAt = round(now(), 3),
        lastSeenAt = round(now(), 3),

        seconds = 0,
        airborneSeconds = 0,

        sorties = 0,
        takeoffs = 0,
        landings = 0,

        deaths = 0,
        crashes = 0,
        ejections = 0,

        kills = 0,
        friendlyKills = 0,
        mapKills = 0,

        killsByType = {},

        lastUnitName = nil,
        lastGroupName = nil,
        lastPoint = nil
    }

    local m = player.modules[moduleName]

    m.used = true
    m.lastSeenAt = round(now(), 3)
    m.killsByType = m.killsByType or {}

    return m
end

local function addKillByType(container, targetType)
    if not container then
        return
    end

    targetType = validString(targetType) or "UNKNOWN"
    container.killsByType = container.killsByType or {}
    container.killsByType[targetType] = (tonumber(container.killsByType[targetType]) or 0) + 1
end

----------------------------------------------------------------
-- SESSION CONTROL
----------------------------------------------------------------

local function getSessionByUnitName(unitName)
    if not unitName then
        return nil
    end

    return PST.STATE.activeSessions[unitName]
end

local function getRecentSessionByUnitName(unitName)
    if not unitName then
        return nil
    end

    local s = PST.STATE.recentEndedSessions[unitName]
    if not s then
        return nil
    end

    if (now() - (s.endedAt or 0)) > 120 then
        PST.STATE.recentEndedSessions[unitName] = nil
        return nil
    end

    return s
end

local function accumulateSessionTime(session, t)
    if not session then
        return
    end

    t = t or now()

    local delta = t - (session.lastHeartbeat or session.startTime or t)

    if delta <= 0 then
        session.lastHeartbeat = t
        return
    end

    if delta > 120 then
        delta = 120
    end

    local player = ensurePlayer(session.playerName)
    if not player then
        return
    end

    local moduleData = ensureModule(player, session.moduleName)

    player.totalFlightSeconds = round((tonumber(player.totalFlightSeconds) or 0) + delta, 3)
    player.lastSeenAt = round(t, 3)

    if moduleData then
        moduleData.seconds = round((tonumber(moduleData.seconds) or 0) + delta, 3)
        moduleData.lastSeenAt = round(t, 3)
    end

    if session.airborne then
        player.totalAirborneSeconds = round((tonumber(player.totalAirborneSeconds) or 0) + delta, 3)

        if moduleData then
            moduleData.airborneSeconds = round((tonumber(moduleData.airborneSeconds) or 0) + delta, 3)
        end
    end

    session.lastHeartbeat = t

    markDirty()
end

local function endSessionByUnitName(unitName, reason)
    local session = getSessionByUnitName(unitName)

    if not session then
        return false
    end

    local t = now()
    accumulateSessionTime(session, t)

    local player = ensurePlayer(session.playerName)

    if player then
        local duration = round(t - (session.startTime or t), 3)

        player.sessionLog = appendLimited(player.sessionLog, {
            startTime = round(session.startTime or t, 3),
            endTime = round(t, 3),
            durationSeconds = duration,
            reason = tostring(reason or "ended"),
            module = session.moduleName,
            unitName = session.unitName,
            groupName = session.groupName,
            coalition = session.coalition,
            country = session.country
        }, PST.CONFIG.maxSessionLogEntries)

        player.lastSeenAt = round(t, 3)
    end

    PST.STATE.recentEndedSessions[unitName] = {
        playerName = session.playerName,
        moduleName = session.moduleName,
        unitName = session.unitName,
        groupName = session.groupName,
        coalition = session.coalition,
        country = session.country,
        endedAt = t
    }

    PST.STATE.activeSessions[unitName] = nil

    markDirty()

    return true
end

local function endOtherSessionsForPlayer(playerName, exceptUnitName)
    for unitName, session in pairs(PST.STATE.activeSessions) do
        if session.playerName == playerName and unitName ~= exceptUnitName then
            endSessionByUnitName(unitName, "slot_change")
        end
    end
end

local function startSessionFromUnit(unit, reason)
    if not unit then
        return nil
    end

    local playerName = safeGetPlayerName(unit)
    if not playerName then
        return nil
    end

    local unitName = safeGetName(unit)
    if not unitName then
        return nil
    end

    local moduleName = safeGetTypeName(unit) or "UNKNOWN"
    local groupName = safeGetGroupName(unit)
    local coal = safeGetCoalition(unit)
    local countryId = safeGetCountry(unit)
    local point = safeGetPoint(unit)

    local existing = getSessionByUnitName(unitName)

    if existing and existing.playerName == playerName then
        existing.lastHeartbeat = existing.lastHeartbeat or now()
        existing.lastPoint = point or existing.lastPoint
        return existing
    end

    if existing and existing.playerName ~= playerName then
        endSessionByUnitName(unitName, "replaced_by_other_player")
    end

    endOtherSessionsForPlayer(playerName, unitName)

    local t = now()
    local player = ensurePlayer(playerName)
    local moduleData = ensureModule(player, moduleName)

    player.sorties = (tonumber(player.sorties) or 0) + 1
    player.lastUnitName = unitName
    player.lastGroupName = groupName
    player.lastModule = moduleName
    player.lastCoalition = coal
    player.lastCountry = countryId
    player.lastPoint = point
    player.lastSeenAt = round(t, 3)

    if moduleData then
        moduleData.sorties = (tonumber(moduleData.sorties) or 0) + 1
        moduleData.lastUnitName = unitName
        moduleData.lastGroupName = groupName
        moduleData.lastPoint = point
        moduleData.lastSeenAt = round(t, 3)
    end

    local session = {
        playerName = playerName,
        playerId = playerName,

        unitName = unitName,
        groupName = groupName,
        moduleName = moduleName,

        coalition = coal,
        country = countryId,

        startTime = t,
        lastHeartbeat = t,

        airborne = false,
        takeoffAt = nil,

        lastPoint = point,
        reason = reason or "start"
    }

    PST.STATE.activeSessions[unitName] = session

    markDirty()

    playerMsg(coal, "Estadisticas iniciadas para " .. tostring(playerName) .. "\nModulo: " .. tostring(moduleName))

    log("Sesion iniciada: " .. tostring(playerName) .. " | " .. tostring(moduleName) .. " | unidad=" .. tostring(unitName), 6)

    return session
end

----------------------------------------------------------------
-- EVENTOS
----------------------------------------------------------------

local function getPlayerInfoFromUnitOrSession(unit)
    if not unit then
        return nil
    end

    local unitName = safeGetName(unit)
    local session = getSessionByUnitName(unitName) or getRecentSessionByUnitName(unitName)

    local playerName = safeGetPlayerName(unit)
    local moduleName = safeGetTypeName(unit)
    local groupName = safeGetGroupName(unit)
    local coal = safeGetCoalition(unit)
    local countryId = safeGetCountry(unit)
    local point = safeGetPoint(unit)

    if session then
        playerName = playerName or session.playerName
        moduleName = moduleName or session.moduleName
        groupName = groupName or session.groupName
        coal = coal or session.coalition
        countryId = countryId or session.country
    end

    if not playerName then
        return nil
    end

    return {
        playerName = playerName,
        unitName = unitName or (session and session.unitName),
        moduleName = moduleName or "UNKNOWN",
        groupName = groupName,
        coalition = coal,
        country = countryId,
        point = point,
        session = session
    }
end

local function handleBirthOrEnter(event, reason)
    local unit = event and event.initiator
    if not unit then
        return
    end

    startSessionFromUnit(unit, reason)
end

local function handleTakeoff(event)
    local unit = event and event.initiator
    if not unit then
        return
    end

    local session = startSessionFromUnit(unit, "takeoff_detected")
    if not session then
        return
    end

    if session.airborne then
        return
    end

    local t = now()
    local player = ensurePlayer(session.playerName)
    local moduleData = ensureModule(player, session.moduleName)

    session.airborne = true
    session.takeoffAt = t

    player.takeoffs = (tonumber(player.takeoffs) or 0) + 1

    if moduleData then
        moduleData.takeoffs = (tonumber(moduleData.takeoffs) or 0) + 1
    end

    markDirty()

    log("Takeoff: " .. tostring(session.playerName) .. " | " .. tostring(session.moduleName), 5)
end

local function handleLanding(event)
    local unit = event and event.initiator
    if not unit then
        return
    end

    local session = startSessionFromUnit(unit, "landing_detected")
    if not session then
        return
    end

    accumulateSessionTime(session, now())

    local point = safeGetPoint(unit) or session.lastPoint
    local placeName, distance, source = getEventPlaceName(event, point)

    local player = ensurePlayer(session.playerName)
    local moduleData = ensureModule(player, session.moduleName)

    session.airborne = false
    session.takeoffAt = nil
    session.lastPoint = point or session.lastPoint

    player.landings = (tonumber(player.landings) or 0) + 1
    player.lastLanding = {
        time = round(now(), 3),
        module = session.moduleName,
        unitName = session.unitName,
        groupName = session.groupName,
        place = placeName,
        placeSource = source,
        distanceToPlace = distance,
        point = point
    }

    player.landingLog = appendLimited(player.landingLog, player.lastLanding, PST.CONFIG.maxLandingLogEntries)

    if moduleData then
        moduleData.landings = (tonumber(moduleData.landings) or 0) + 1
        moduleData.lastLanding = player.lastLanding
        moduleData.lastPoint = point
    end

    markDirty()

    log("Landing: " .. tostring(session.playerName) .. " | " .. tostring(session.moduleName) .. " | " .. tostring(placeName), 6)
end

local function handleLoss(event, lossType)
    local unit = event and event.initiator
    if not unit then
        return
    end

    local info = getPlayerInfoFromUnitOrSession(unit)
    if not info then
        return
    end

    local unitName = info.unitName or "UNKNOWN_UNIT"
    local dedupKey = tostring(unitName) .. ":" .. tostring(lossType)

    local last = PST.STATE.lossDedup[dedupKey]
    if last and (now() - last) < 30 then
        return
    end

    PST.STATE.lossDedup[dedupKey] = now()

    local player = ensurePlayer(info.playerName)
    local moduleData = ensureModule(player, info.moduleName)

    if lossType == "death" then
        player.deaths = (tonumber(player.deaths) or 0) + 1
        if moduleData then
            moduleData.deaths = (tonumber(moduleData.deaths) or 0) + 1
        end
    elseif lossType == "crash" then
        player.crashes = (tonumber(player.crashes) or 0) + 1
        if moduleData then
            moduleData.crashes = (tonumber(moduleData.crashes) or 0) + 1
        end
    elseif lossType == "ejection" then
        player.ejections = (tonumber(player.ejections) or 0) + 1
        if moduleData then
            moduleData.ejections = (tonumber(moduleData.ejections) or 0) + 1
        end
    end

    player.lastLoss = {
        time = round(now(), 3),
        type = lossType,
        module = info.moduleName,
        unitName = info.unitName,
        groupName = info.groupName,
        point = info.point
    }

    markDirty()

    endSessionByUnitName(unitName, lossType)

    log("Loss: " .. tostring(info.playerName) .. " | " .. tostring(info.moduleName) .. " | " .. tostring(lossType), 6)
end

local function handleKill(event)
    if not event then
        return
    end

    local killer = event.initiator
    local target = event.target

    if not killer or not target then
        return
    end

    local killerInfo = getPlayerInfoFromUnitOrSession(killer)
    if not killerInfo then
        return
    end

    local targetName = safeGetName(target) or "SIN_NOMBRE"
    local targetType = safeGetTypeName(target) or "SIN_TIPO"
    local targetCoalition = safeGetCoalition(target)
    local targetCategory = objectCategoryToText(safeObjectCategory(target))
    local targetPoint = safeGetPoint(target)

    local weaponName = nil
    if event.weapon then
        weaponName = safeGetTypeName(event.weapon) or safeGetName(event.weapon)
    end

    local killerCoalition = tonumber(killerInfo.coalition) or 0
    local isFriendly = false

    if targetCoalition and targetCoalition > 0 and killerCoalition > 0 and targetCoalition == killerCoalition then
        isFriendly = true
    end

    local isMapObject = false
    if targetCategory == "SCENERY" or targetCategory == "BASE" then
        isMapObject = true
    end

    local shouldCountAsKill = true

    if isFriendly and not PST.CONFIG.countFriendlyKillsAsKills then
        shouldCountAsKill = false
    end

    if isMapObject and not PST.CONFIG.countMapObjectKillsAsKills then
        shouldCountAsKill = false
    end

    local player = ensurePlayer(killerInfo.playerName)
    local moduleData = ensureModule(player, killerInfo.moduleName)

    local entry = {
        time = round(now(), 3),

        playerName = killerInfo.playerName,
        module = killerInfo.moduleName,
        unitName = killerInfo.unitName,
        groupName = killerInfo.groupName,
        killerCoalition = killerCoalition,

        targetName = targetName,
        targetType = targetType,
        targetCategory = targetCategory,
        targetCoalition = targetCoalition,

        friendly = isFriendly,
        mapObject = isMapObject,
        countedAsKill = shouldCountAsKill,

        weapon = weaponName,
        targetPoint = targetPoint
    }

    player.killLog = appendLimited(player.killLog, entry, PST.CONFIG.maxKillLogEntries)
    player.lastKill = entry

    if shouldCountAsKill then
        player.kills = (tonumber(player.kills) or 0) + 1
        addKillByType(player, targetType)

        if moduleData then
            moduleData.kills = (tonumber(moduleData.kills) or 0) + 1
            addKillByType(moduleData, targetType)
        end
    end

    if isFriendly then
        player.friendlyKills = (tonumber(player.friendlyKills) or 0) + 1

        if moduleData then
            moduleData.friendlyKills = (tonumber(moduleData.friendlyKills) or 0) + 1
        end
    end

    if isMapObject then
        player.mapKills = (tonumber(player.mapKills) or 0) + 1

        if moduleData then
            moduleData.mapKills = (tonumber(moduleData.mapKills) or 0) + 1
        end
    end

    markDirty()

    log(
        "Kill: " ..
        tostring(killerInfo.playerName) ..
        " | " ..
        tostring(killerInfo.moduleName) ..
        " -> " ..
        tostring(targetName) ..
        " (" ..
        tostring(targetType) ..
        ")",
        5
    )
end

local function handleLeaveUnit(event)
    local unit = event and event.initiator
    if not unit then
        return
    end

    local unitName = safeGetName(unit)
    if not unitName then
        return
    end

    endSessionByUnitName(unitName, "player_left_unit")
end

----------------------------------------------------------------
-- HEARTBEAT
----------------------------------------------------------------

local function heartbeat()
    local t = now()

    for unitName, session in pairs(PST.STATE.activeSessions) do
        local unit = Unit.getByName(unitName)

        if not unit then
            endSessionByUnitName(unitName, "unit_not_found")
        else
            local exists = safeCall(function()
                return unit:isExist()
            end)

            if not exists then
                endSessionByUnitName(unitName, "unit_not_exist")
            else
                local currentPlayer = safeGetPlayerName(unit)

                if not currentPlayer or currentPlayer ~= session.playerName then
                    endSessionByUnitName(unitName, "player_left_or_changed")
                else
                    local point = safeGetPoint(unit)

                    session.lastPoint = point or session.lastPoint

                    local player = ensurePlayer(session.playerName)
                    local moduleData = ensureModule(player, session.moduleName)

                    player.lastSeenAt = round(t, 3)
                    player.lastUnitName = session.unitName
                    player.lastGroupName = session.groupName
                    player.lastModule = session.moduleName
                    player.lastCoalition = session.coalition
                    player.lastCountry = session.country
                    player.lastPoint = session.lastPoint

                    if moduleData then
                        moduleData.lastSeenAt = round(t, 3)
                        moduleData.lastUnitName = session.unitName
                        moduleData.lastGroupName = session.groupName
                        moduleData.lastPoint = session.lastPoint
                    end

                    accumulateSessionTime(session, t)
                end
            end
        end
    end

    return t + (tonumber(PST.CONFIG.heartbeatInterval) or 10)
end

local function autosave()
    local t = now()

    if PST.STATE.dirty then
        PST.saveNow("autosave")
    end

    PST.STATE.lastAutosaveAt = t

    return t + (tonumber(PST.CONFIG.autosaveInterval) or 10)
end

----------------------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------------------

local eventHandler = {}

function eventHandler:onEvent(event)
    if not event or not event.id then
        return
    end

    local id = event.id

    if eventIs(id, "S_EVENT_BIRTH") then
        handleBirthOrEnter(event, "birth")
        return
    end

    if eventIs(id, "S_EVENT_PLAYER_ENTER_UNIT") then
        handleBirthOrEnter(event, "player_enter_unit")
        return
    end

    if eventIs(id, "S_EVENT_PLAYER_LEAVE_UNIT") then
        handleLeaveUnit(event)
        return
    end

    if eventIs(id, "S_EVENT_TAKEOFF") then
        handleTakeoff(event)
        return
    end

    if eventIs(id, "S_EVENT_LAND") then
        handleLanding(event)
        return
    end

    if eventIs(id, "S_EVENT_KILL") then
        handleKill(event)
        return
    end

    if eventIs(id, "S_EVENT_DEAD") then
        handleLoss(event, "death")
        return
    end

    if eventIs(id, "S_EVENT_CRASH") then
        handleLoss(event, "crash")
        return
    end

    if eventIs(id, "S_EVENT_EJECTION") then
        handleLoss(event, "ejection")
        return
    end
end

----------------------------------------------------------------
-- API PUBLICA
----------------------------------------------------------------

function PST.getDoc()
    return PST.STATE.doc
end

function PST.forceSave()
    return PST.saveNow("forceSave")
end

function PST.getPlayer(playerName)
    if not PST.STATE.doc or not PST.STATE.doc.players then
        return nil
    end

    return PST.STATE.doc.players[playerName]
end

function PST.showPlayer(playerName, coalitionId)
    local p = PST.getPlayer(playerName)

    if not p then
        local msg = "No hay estadisticas para: " .. tostring(playerName)
        if coalitionId then
            trigger.action.outTextForCoalition(coalitionId, msg, 10)
        else
            trigger.action.outText(msg, 10)
        end
        return
    end

    local msg = ""
    msg = msg .. "Jugador: " .. tostring(p.name) .. "\n"
    msg = msg .. "Ultimo modulo: " .. tostring(p.lastModule or "N/A") .. "\n"
    msg = msg .. "Tiempo total: " .. tostring(math.floor((p.totalFlightSeconds or 0) / 60)) .. " min\n"
    msg = msg .. "Sorties: " .. tostring(p.sorties or 0) .. "\n"
    msg = msg .. "Takeoffs: " .. tostring(p.takeoffs or 0) .. "\n"
    msg = msg .. "Landings: " .. tostring(p.landings or 0) .. "\n"
    msg = msg .. "Deaths: " .. tostring(p.deaths or 0) .. "\n"
    msg = msg .. "Crashes: " .. tostring(p.crashes or 0) .. "\n"
    msg = msg .. "Ejections: " .. tostring(p.ejections or 0) .. "\n"
    msg = msg .. "Kills: " .. tostring(p.kills or 0) .. "\n"

    if p.lastLanding and p.lastLanding.place then
        msg = msg .. "Ultimo aterrizaje: " .. tostring(p.lastLanding.place) .. "\n"
    end

    if coalitionId then
        trigger.action.outTextForCoalition(coalitionId, msg, 15)
    else
        trigger.action.outText(msg, 15)
    end
end

function PST.init(config)
    if PST.STATE.initialized then
        return PST
    end

    if type(config) == "table" then
        for k, v in pairs(config) do
            PST.CONFIG[k] = v
        end
    end

    PST.STATE.doc = normalizeDoc(loadDoc())
    PST.STATE.initialized = true

    world.addEventHandler(eventHandler)

    timer.scheduleFunction(function()
        return heartbeat()
    end, nil, timer.getTime() + 2)

    timer.scheduleFunction(function()
        return autosave()
    end, nil, timer.getTime() + 5)

    markDirty()
    PST.saveNow("init")

    log("PlayerStats iniciado. Archivo: " .. tostring(getJsonPath()), 10)

    return PST
end

PST.init()