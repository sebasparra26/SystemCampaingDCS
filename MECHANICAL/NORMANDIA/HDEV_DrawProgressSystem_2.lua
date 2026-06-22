-- ============================================================================
-- HDEV_DrawProgressSystem.lua
-- VERSION: 3
--
-- Sistema visual de progreso F10 con circulos, numeros y conexiones.
--
-- CAMBIO VERSION 3:
-- - Las conexiones YA NO usan lineToAll.
-- - Las conexiones se dibujan como un corredor/rectangulo delgado con quadToAll.
-- - Esto es mas estable en F10 cuando lineToAll o markupToAll no muestran lineas.
-- - Circulos y textos siguen usando MIST porque ya estaban funcionando.
--
-- CARGA RECOMENDADA:
-- 1) mist_4_5_128.lua
-- 2) Sistema de control de aeropuertos / banderas, si existe
-- 3) HDEV_DrawProgressSystem.lua
--
-- NO modifica Marketplace, Economia, CTLD, Warehouse ni MissionSystem.
-- ============================================================================

if not mist or not mist.marker or not mist.marker.add or not mist.marker.remove then
    env.info("[HDEV_DPS] ERROR: MIST no esta cargado antes de HDEV_DrawProgressSystem.lua")
    if trigger and trigger.action and trigger.action.outText then
        trigger.action.outText("[HDEV_DPS] ERROR: MIST no esta cargado. Carga mist_4_5_128.lua antes.", 15)
    end
    return
end

HDEV_DrawProgressSystem = HDEV_DrawProgressSystem or {}
local DPS = HDEV_DrawProgressSystem

-- ============================================================================
-- LIMPIEZA SI SE RECARGA EL SCRIPT
-- ============================================================================

if DPS.STATE then
    DPS.STATE.started = false

    if DPS.STATE.markers then
        for _, rec in pairs(DPS.STATE.markers) do
            local id = rec
            if type(rec) == "table" then
                id = rec.id or rec.markId
            end

            if id then
                pcall(function()
                    trigger.action.removeMark(id)
                end)

                pcall(function()
                    mist.marker.remove(id)
                end)
            end
        end
    end

    if DPS.STATE.menuRoot and missionCommands then
        pcall(function()
            missionCommands.removeItem(DPS.STATE.menuRoot)
        end)
    end
end

DPS.VERSION = 3

-- ============================================================================
-- CONFIGURACION EDITABLE
-- ============================================================================

DPS.CONFIG = {
    DEBUG = false,

    ENABLE_SCREEN_MESSAGES = false,
    SCREEN_MESSAGE_TIME = 8,

    UPDATE_INTERVAL = 10,
    START_DELAY = 2,
    FORCE_REDRAW_ON_START = true,

    ENABLE_MENU = false,
    MENU_NAME = "HDEV Draw Progress",

    -- -1 = global / todos
    --  1 = rojo
    --  2 = azul
    MENU_COALITION = -1,

    DEFAULT_DRAW_COALITION = -1,

    DEFAULT_CIRCLE_RADIUS = 40000,
    DEFAULT_CIRCLE_LINE_TYPE = 1,
    DEFAULT_LINE_TYPE = 1,
    DEFAULT_TEXT_FONT_SIZE = 18,

    -- IMPORTANTE:
    -- Como DCS no esta mostrando lineas normales, las conexiones se dibujan
    -- como un rectangulo delgado. Este valor es el ancho visual de esa linea.
    LINE_WIDTH_METERS = 50,

    -- ID inicial para los draws directos de conexiones.
    DIRECT_MARK_ID_START = 880000,

    -- Mantener colores editables en 0-255.
    CONVERT_COLORS_TO_0_1 = true,

    COLORS = {
        [0] = {
            name = "NEUTRAL",
            circle = {255, 255, 255, 255},
            fill = {255, 255, 255, 0},
            text = {255, 255, 255, 255}
        },

        [1] = {
            name = "ROJO",
            circle = {255, 0, 0, 255},
            fill = {255, 0, 0, 0},
            text = {255, 80, 80, 255}
        },

        [2] = {
            name = "AZUL",
            circle = {0, 80, 255, 255},
            fill = {0, 80, 255, 0},
            text = {120, 180, 255, 255}
        },

        mixed = {
            name = "MIXTO",
            line = {255, 200, 0, 255},
            fill = {255, 200, 0, 180}
        },

        pending = {
            name = "PENDIENTE",
            line = {160, 160, 160, 220},
            fill = {160, 160, 160, 160}
        },

        textBackground = {
            fill = {0, 0, 0, 0}
        }
    }
}

-- ============================================================================
-- RUTAS VISUALES EDITABLES
-- El orden de airports manda. NO se ordena alfabeticamente.
-- ============================================================================

DPS.ROUTES = {
    {
        id = "AFGHANISTAN_MAIN",
        enabled = true,
        name = "Ruta principal Afganistan",
        coalition = -1,

        controlMode = "hybrid", -- "real", "flag", "global", "hybrid"

        circleRadius = 20000,
        circleLineType = 2,

        textOffsetX = 100,
        textOffsetZ = 0,
        textFontSize = 40,
        textMode = "number", -- "number" o "number_name"

        lineMode = "progress", -- "static" o "progress"
        lineType = 1,

        airports = {
            { name = "Kenley", flag = 142 },
            { name = "Friston", flag = 152 },
            { name = "Ford", flag = 130 },
       
        }
    }
}

-- ============================================================================
-- STATE
-- ============================================================================

DPS.STATE = {
    started = false,
    manualHidden = false,

    airportByName = {},
    airportByLowerName = {},
    airportList = {},

    realControlById = {},
    realControlByName = {},
    realControlByLowerName = {},

    markers = {},
    markerSnapshots = {},
    routeMarkerKeys = {},
    routeSnapshots = {},

    menuRoot = nil,
    nextDirectMarkId = DPS.CONFIG.DIRECT_MARK_ID_START or 880000,

    lastScanTime = -9999,
    lastRefreshTime = -9999
}

-- ============================================================================
-- LOG / UTILS
-- ============================================================================

local function log(msg)
    env.info("[HDEV_DPS] " .. tostring(msg))
end

local function debugLog(msg)
    if DPS.CONFIG.DEBUG then
        env.info("[HDEV_DPS] " .. tostring(msg))

        if DPS.CONFIG.ENABLE_SCREEN_MESSAGES then
            trigger.action.outText("[HDEV_DPS] " .. tostring(msg), DPS.CONFIG.SCREEN_MESSAGE_TIME or 8)
        end
    end
end

local function warn(msg)
    env.info("[HDEV_DPS] WARN: " .. tostring(msg))

    if DPS.CONFIG.DEBUG and DPS.CONFIG.ENABLE_SCREEN_MESSAGES then
        trigger.action.outText("[HDEV_DPS] WARN: " .. tostring(msg), DPS.CONFIG.SCREEN_MESSAGE_TIME or 8)
    end
end

local function out(msg, seconds)
    trigger.action.outText("[HDEV_DPS] " .. tostring(msg), seconds or 8)
end

local function safeNumber(v, default)
    local n = tonumber(v)
    if n == nil then
        return default or 0
    end
    return n
end

local function round(n, decimals)
    n = safeNumber(n, 0)
    local m = 10 ^ (decimals or 0)
    return math.floor((n * m) + 0.5) / m
end

local function safeName(s)
    s = tostring(s or "")
    s = s:gsub("[^%w_]+", "_")
    s = s:gsub("_+", "_")
    s = s:gsub("^_", "")
    s = s:gsub("_$", "")

    if s == "" then
        s = "NONAME"
    end

    return s
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function normalizePoint(p)
    if type(p) ~= "table" then
        return nil
    end

    return {
        x = safeNumber(p.x, 0),
        y = safeNumber(p.y, 0),
        z = safeNumber(p.z ~= nil and p.z or p.y, 0)
    }
end

local function flatPoint(p)
    p = normalizePoint(p)
    if not p then
        return nil
    end

    return {
        x = p.x,
        y = 0,
        z = p.z
    }
end

local function offsetPoint(p, dx, dz)
    p = normalizePoint(p)
    if not p then
        return nil
    end

    return {
        x = p.x + safeNumber(dx, 0),
        y = p.y,
        z = p.z + safeNumber(dz, 0)
    }
end

local function pointSnapshot(p)
    p = normalizePoint(p)

    if not p then
        return "nil"
    end

    return tostring(round(p.x, 1)) .. "," .. tostring(round(p.y, 1)) .. "," .. tostring(round(p.z, 1))
end

local function colorToDcs(c)
    if type(c) ~= "table" then
        return c
    end

    local outColor = {
        safeNumber(c[1], 255),
        safeNumber(c[2], 255),
        safeNumber(c[3], 255),
        safeNumber(c[4], 255)
    }

    if DPS.CONFIG.CONVERT_COLORS_TO_0_1 then
        for i = 1, 4 do
            if outColor[i] > 1 then
                outColor[i] = outColor[i] / 255
            end
        end
    end

    return outColor
end

local function makeStrongFill(c)
    if type(c) ~= "table" then
        return c
    end

    local alpha = safeNumber(c[4], 255)
    if alpha < 160 then
        alpha = 180
    end

    return {
        safeNumber(c[1], 255),
        safeNumber(c[2], 255),
        safeNumber(c[3], 255),
        alpha
    }
end

local function normalizeControlValue(v)
    if v == nil then
        return nil
    end

    if type(v) == "table" then
        if v.valor ~= nil then
            return normalizeControlValue(v.valor)
        end

        if v.coalition ~= nil then
            return normalizeControlValue(v.coalition)
        end

        if v.coalicion ~= nil then
            return normalizeControlValue(v.coalicion)
        end

        return nil
    end

    if type(v) == "boolean" then
        return v and 1 or 0
    end

    if type(v) == "number" then
        local n = math.floor(v)
        if n == 0 or n == 1 or n == 2 then
            return n
        end
        return nil
    end

    local s = lower(v)

    if s == "0" or s == "neutral" or s == "neutro" then
        return 0
    elseif s == "1" or s == "red" or s == "rojo" then
        return 1
    elseif s == "2" or s == "blue" or s == "azul" then
        return 2
    end

    return nil
end

local function coalitionName(v)
    v = normalizeControlValue(v) or 0

    if v == 1 then
        return "ROJO"
    elseif v == 2 then
        return "AZUL"
    end

    return "NEUTRAL"
end

local function getColorSet(control)
    control = normalizeControlValue(control) or 0
    return DPS.CONFIG.COLORS[control] or DPS.CONFIG.COLORS[0]
end

local function getLineColorForControls(c1, c2, route)
    c1 = normalizeControlValue(c1) or 0
    c2 = normalizeControlValue(c2) or 0

    if lower(route.lineMode or "progress") == "static" then
        return DPS.CONFIG.COLORS.pending.line, DPS.CONFIG.COLORS.pending.fill, "PENDIENTE"
    end

    if c1 == 2 and c2 == 2 then
        local cs = DPS.CONFIG.COLORS[2]
        return cs.circle, makeStrongFill(cs.circle), "AZUL"
    end

    if c1 == 1 and c2 == 1 then
        local cs = DPS.CONFIG.COLORS[1]
        return cs.circle, makeStrongFill(cs.circle), "ROJO"
    end

    if c1 == 0 and c2 == 0 then
        return DPS.CONFIG.COLORS.pending.line, DPS.CONFIG.COLORS.pending.fill, "PENDIENTE"
    end

    return DPS.CONFIG.COLORS.mixed.line, DPS.CONFIG.COLORS.mixed.fill, "MIXTO"
end

local function getRouteCoa(route)
    local coa = tonumber(route.coalition)

    if coa == nil then
        coa = tonumber(DPS.CONFIG.DEFAULT_DRAW_COALITION) or -1
    end

    if coa ~= -1 and coa ~= 0 and coa ~= 1 and coa ~= 2 then
        coa = -1
    end

    return coa
end

local function getNextDirectMarkId()
    DPS.STATE.nextDirectMarkId = (tonumber(DPS.STATE.nextDirectMarkId) or tonumber(DPS.CONFIG.DIRECT_MARK_ID_START) or 880000) + 1
    return DPS.STATE.nextDirectMarkId
end

-- ============================================================================
-- AIRPORT SCAN
-- ============================================================================

local function scanAirports()
    DPS.STATE.airportByName = {}
    DPS.STATE.airportByLowerName = {}
    DPS.STATE.airportList = {}

    local ok, airbases = pcall(function()
        return world.getAirbases()
    end)

    if not ok or type(airbases) ~= "table" then
        warn("No se pudo ejecutar world.getAirbases().")
        return false
    end

    for _, airbase in pairs(airbases) do
        local okName, name = pcall(function()
            return airbase:getName()
        end)

        local okId, id = pcall(function()
            return airbase:getID()
        end)

        local okPoint, point = pcall(function()
            return airbase:getPoint()
        end)

        if okName and name and okPoint and point then
            local data = {
                name = tostring(name),
                id = okId and id or nil,
                point = normalizePoint(point),
                airbase = airbase
            }

            DPS.STATE.airportByName[data.name] = data
            DPS.STATE.airportByLowerName[lower(data.name)] = data
            DPS.STATE.airportList[#DPS.STATE.airportList + 1] = data
        end
    end

    DPS.STATE.lastScanTime = timer.getTime()

    debugLog("Aeropuertos detectados: " .. tostring(#DPS.STATE.airportList))

    return true
end

local function findAirportByName(name)
    if not name then
        return nil
    end

    local exact = DPS.STATE.airportByName[tostring(name)]
    if exact then
        return exact
    end

    return DPS.STATE.airportByLowerName[lower(name)]
end

local function buildRealControlIndex()
    DPS.STATE.realControlById = {}
    DPS.STATE.realControlByName = {}
    DPS.STATE.realControlByLowerName = {}

    local function ingest(side)
        local ok, list = pcall(function()
            return coalition.getAirbases(side)
        end)

        if not ok or type(list) ~= "table" then
            return
        end

        for _, airbase in pairs(list) do
            local id = nil
            local name = nil

            pcall(function()
                id = airbase:getID()
            end)

            pcall(function()
                name = airbase:getName()
            end)

            if id ~= nil then
                DPS.STATE.realControlById[id] = side
            end

            if name then
                DPS.STATE.realControlByName[tostring(name)] = side
                DPS.STATE.realControlByLowerName[lower(name)] = side
            end
        end
    end

    ingest(1)
    ingest(2)
end

-- ============================================================================
-- CONTROL READERS
-- ============================================================================

local function readGlobalTableValue(tableName, airportName)
    local tbl = _G[tableName]

    if type(tbl) ~= "table" then
        return nil, nil
    end

    if tbl[airportName] ~= nil then
        return normalizeControlValue(tbl[airportName]), tableName .. "[" .. tostring(airportName) .. "]"
    end

    local wanted = lower(airportName)

    for k, v in pairs(tbl) do
        if lower(k) == wanted then
            return normalizeControlValue(v), tableName .. "[" .. tostring(k) .. "]"
        end
    end

    return nil, nil
end

local function getEstadoEntry(airportName)
    local tbl = _G.estadoBanderasAeropuertos

    if type(tbl) ~= "table" then
        return nil, nil
    end

    if type(tbl[airportName]) == "table" then
        return tbl[airportName], "estadoBanderasAeropuertos[" .. tostring(airportName) .. "]"
    end

    local wanted = lower(airportName)

    for k, v in pairs(tbl) do
        if lower(k) == wanted and type(v) == "table" then
            return v, "estadoBanderasAeropuertos[" .. tostring(k) .. "]"
        end
    end

    return nil, nil
end

local function readEstadoValor(airportName)
    local entry, source = getEstadoEntry(airportName)

    if not entry then
        return nil, nil
    end

    if entry.valor ~= nil then
        return normalizeControlValue(entry.valor), source .. ".valor"
    end

    return nil, nil
end

local function readFlagValue(flag)
    if flag == nil then
        return nil, nil
    end

    local ok, value = pcall(function()
        return trigger.misc.getUserFlag(flag)
    end)

    if not ok then
        return nil, nil
    end

    return normalizeControlValue(value), "flag:" .. tostring(flag)
end

local function readEstadoFlag(airportName)
    local entry, source = getEstadoEntry(airportName)

    if not entry or entry.bandera == nil then
        return nil, nil
    end

    local val, flagSource = readFlagValue(entry.bandera)

    if val == nil then
        return nil, nil
    end

    return val, source .. ".bandera/" .. flagSource
end

local function getRealAirportControl(airportData)
    if not airportData then
        return 0, "real:missing_airport"
    end

    if airportData.id ~= nil and DPS.STATE.realControlById[airportData.id] ~= nil then
        return normalizeControlValue(DPS.STATE.realControlById[airportData.id]) or 0, "real:id"
    end

    if airportData.name and DPS.STATE.realControlByName[airportData.name] ~= nil then
        return normalizeControlValue(DPS.STATE.realControlByName[airportData.name]) or 0, "real:name"
    end

    if airportData.name and DPS.STATE.realControlByLowerName[lower(airportData.name)] ~= nil then
        return normalizeControlValue(DPS.STATE.realControlByLowerName[lower(airportData.name)]) or 0, "real:lowerName"
    end

    return 0, "real:neutral"
end

local function getAirportControl(route, airportEntry, airportData)
    route = route or {}
    airportEntry = airportEntry or {}

    local airportName = airportEntry.name or (airportData and airportData.name) or "UNKNOWN"
    local mode = lower(route.controlMode or "hybrid")

    if mode == "real" then
        return getRealAirportControl(airportData)
    end

    if mode == "flag" then
        local val, source = readFlagValue(airportEntry.flag)

        if val ~= nil then
            return val, source
        end

        val, source = readEstadoFlag(airportName)

        if val ~= nil then
            return val, source
        end

        return 0, "flag:missing_default_neutral"
    end

    if mode == "global" then
        local val, source = readGlobalTableValue("controlAeropuertos", airportName)

        if val ~= nil then
            return val, source
        end

        val, source = readGlobalTableValue("coalicionPorBase", airportName)

        if val ~= nil then
            return val, source
        end

        val, source = readEstadoValor(airportName)

        if val ~= nil then
            return val, source
        end

        return 0, "global:missing_default_neutral"
    end

    -- HYBRID
    local val, source = readGlobalTableValue("controlAeropuertos", airportName)

    if val ~= nil then
        return val, source
    end

    val, source = readGlobalTableValue("coalicionPorBase", airportName)

    if val ~= nil then
        return val, source
    end

    val, source = readEstadoValor(airportName)

    if val ~= nil then
        return val, source
    end

    val, source = readFlagValue(airportEntry.flag)

    if val ~= nil then
        return val, source
    end

    val, source = readEstadoFlag(airportName)

    if val ~= nil then
        return val, source
    end

    return getRealAirportControl(airportData)
end

DPS.getAirportControl = getAirportControl

-- ============================================================================
-- MARKER MANAGEMENT
-- ============================================================================

local function getMarkerId(markerKey)
    local rec = DPS.STATE.markers[markerKey]

    if type(rec) == "table" then
        return rec.id or rec.markId
    end

    return rec
end

local function removeMarker(markerKey)
    local id = getMarkerId(markerKey)

    if id then
        pcall(function()
            trigger.action.removeMark(id)
        end)

        pcall(function()
            mist.marker.remove(id)
        end)
    end

    pcall(function()
        mist.marker.remove(markerKey)
    end)

    DPS.STATE.markers[markerKey] = nil
    DPS.STATE.markerSnapshots[markerKey] = nil
end

local function registerRouteMarker(routeId, markerKey)
    local rid = safeName(routeId)

    DPS.STATE.routeMarkerKeys[rid] = DPS.STATE.routeMarkerKeys[rid] or {}
    DPS.STATE.routeMarkerKeys[rid][markerKey] = true
end

local function cleanRouteMarkers(routeId)
    local rid = safeName(routeId)
    local keys = DPS.STATE.routeMarkerKeys[rid] or {}

    for markerKey, _ in pairs(keys) do
        removeMarker(markerKey)
        debugLog("Marker removido: " .. markerKey)
    end

    DPS.STATE.routeMarkerKeys[rid] = {}
    DPS.STATE.routeSnapshots[rid] = nil
end

local function cleanAllMarkers()
    for markerKey, _ in pairs(DPS.STATE.markers or {}) do
        removeMarker(markerKey)
    end

    DPS.STATE.markers = {}
    DPS.STATE.markerSnapshots = {}
    DPS.STATE.routeMarkerKeys = {}
    DPS.STATE.routeSnapshots = {}

    debugLog("Todos los draws DPS fueron limpiados.")
end

local function addMistMarker(markerKey, vars, snapshot)
    if DPS.STATE.markerSnapshots[markerKey] == snapshot and DPS.STATE.markers[markerKey] then
        return getMarkerId(markerKey), false
    end

    removeMarker(markerKey)

    vars.name = markerKey
    vars.readOnly = vars.readOnly ~= false

    local ok, markData = pcall(function()
        return mist.marker.add(vars)
    end)

    if ok and markData and markData.markId then
        DPS.STATE.markers[markerKey] = {
            id = markData.markId,
            kind = "mist"
        }

        DPS.STATE.markerSnapshots[markerKey] = snapshot
        debugLog("Marker MIST creado: " .. markerKey .. " | markId=" .. tostring(markData.markId))

        return markData.markId, true
    end

    warn("No se pudo crear marker MIST: " .. markerKey .. " | error=" .. tostring(markData))
    return nil, false
end

local function addDirectQuad(markerKey, points, color, fillColor, lineType, coa, message, snapshot)
    if DPS.STATE.markerSnapshots[markerKey] == snapshot and DPS.STATE.markers[markerKey] then
        return getMarkerId(markerKey), false
    end

    removeMarker(markerKey)

    local markId = getNextDirectMarkId()

    local ok, err = pcall(function()
        trigger.action.quadToAll(
            coa or -1,
            markId,
            points[1],
            points[2],
            points[3],
            points[4],
            colorToDcs(color),
            colorToDcs(fillColor),
            lineType or 1,
            true,
            message or ""
        )
    end)

    if ok then
        DPS.STATE.markers[markerKey] = {
            id = markId,
            kind = "direct_quad_line"
        }

        DPS.STATE.markerSnapshots[markerKey] = snapshot

        debugLog("Conexion QUAD creada: " .. markerKey .. " | markId=" .. tostring(markId))
        return markId, true
    end

    warn("No se pudo crear conexion QUAD: " .. markerKey .. " | error=" .. tostring(err))
    return nil, false
end

-- ============================================================================
-- DRAW BUILDERS
-- ============================================================================

local function buildCircleName(route, index, airportName)
    return "DPS_" .. safeName(route.id) .. "_CIRCLE_" .. tostring(index) .. "_" .. safeName(airportName)
end

local function buildTextName(route, index, airportName)
    return "DPS_" .. safeName(route.id) .. "_TEXT_" .. tostring(index) .. "_" .. safeName(airportName)
end

local function buildLineName(route, index)
    return "DPS_" .. safeName(route.id) .. "_CONNECTION_" .. tostring(index)
end

local function buildTextForAirport(route, index, airportName)
    local mode = lower(route.textMode or "number")

    if mode == "number_name" then
        return tostring(index) .. " - " .. tostring(airportName)
    end

    return tostring(index)
end

local function buildQuadLinePoints(p1, p2, widthMeters)
    p1 = flatPoint(p1)
    p2 = flatPoint(p2)

    if not p1 or not p2 then
        return nil
    end

    local dx = p2.x - p1.x
    local dz = p2.z - p1.z
    local len = math.sqrt(dx * dx + dz * dz)

    if len < 1 then
        return nil
    end

    local half = safeNumber(widthMeters, 2500) / 2

    -- Vector perpendicular normalizado
    local nx = (-dz / len) * half
    local nz = (dx / len) * half

    return {
        { x = p1.x + nx, y = 0, z = p1.z + nz },
        { x = p2.x + nx, y = 0, z = p2.z + nz },
        { x = p2.x - nx, y = 0, z = p2.z - nz },
        { x = p1.x - nx, y = 0, z = p1.z - nz }
    }
end

local function drawCircle(route, runtimeEntry)
    local airportEntry = runtimeEntry.entry
    local airportData = runtimeEntry.data
    local index = runtimeEntry.index
    local control = runtimeEntry.control

    local radius = safeNumber(
        airportEntry.radius or route.circleRadius or DPS.CONFIG.DEFAULT_CIRCLE_RADIUS,
        DPS.CONFIG.DEFAULT_CIRCLE_RADIUS
    )

    local colorSet = getColorSet(control)
    local markerKey = buildCircleName(route, index, airportData.name)

    local snapshot =
        "circle|" ..
        tostring(index) .. "|" ..
        tostring(airportData.name) .. "|" ..
        pointSnapshot(airportData.point) .. "|" ..
        tostring(radius) .. "|" ..
        tostring(control) .. "|" ..
        tostring(route.circleLineType or DPS.CONFIG.DEFAULT_CIRCLE_LINE_TYPE)

    addMistMarker(markerKey, {
        mType = 2,
        point = normalizePoint(airportData.point),
        radius = radius,
        color = colorToDcs(colorSet.circle),
        fillColor = colorToDcs(colorSet.fill),
        lineType = route.circleLineType or DPS.CONFIG.DEFAULT_CIRCLE_LINE_TYPE,
        coa = getRouteCoa(route),
        message = tostring(airportData.name)
    }, snapshot)

    registerRouteMarker(route.id, markerKey)
end

local function drawText(route, runtimeEntry)
    local airportEntry = runtimeEntry.entry
    local airportData = runtimeEntry.data
    local index = runtimeEntry.index
    local control = runtimeEntry.control

    local colorSet = getColorSet(control)
    local markerKey = buildTextName(route, index, airportData.name)

    local textPoint = offsetPoint(
        airportData.point,
        safeNumber(airportEntry.textOffsetX or route.textOffsetX, 0),
        safeNumber(airportEntry.textOffsetZ or route.textOffsetZ, 0)
    )

    local text = buildTextForAirport(route, index, airportData.name)
    local fontSize = safeNumber(
        airportEntry.textFontSize or route.textFontSize or DPS.CONFIG.DEFAULT_TEXT_FONT_SIZE,
        DPS.CONFIG.DEFAULT_TEXT_FONT_SIZE
    )

    local snapshot =
        "text|" ..
        tostring(index) .. "|" ..
        tostring(airportData.name) .. "|" ..
        pointSnapshot(textPoint) .. "|" ..
        tostring(control) .. "|" ..
        tostring(text) .. "|" ..
        tostring(fontSize)

    addMistMarker(markerKey, {
        mType = 5,
        point = textPoint,
        text = text,
        fontSize = fontSize,
        color = colorToDcs(colorSet.text),
        fillColor = colorToDcs(DPS.CONFIG.COLORS.textBackground.fill),
        lineType = 1,
        coa = getRouteCoa(route)
    }, snapshot)

    registerRouteMarker(route.id, markerKey)
end

local function drawConnection(route, runtimeA, runtimeB, lineIndex)
    if not runtimeA or not runtimeB then
        debugLog("Conexion saltada por runtime faltante en ruta " .. tostring(route.id) .. " index=" .. tostring(lineIndex))
        return
    end

    if not runtimeA.found or not runtimeB.found or not runtimeA.data or not runtimeB.data then
        debugLog("Conexion saltada por aeropuerto faltante en ruta " .. tostring(route.id) .. " index=" .. tostring(lineIndex))
        return
    end

    local p1 = normalizePoint(runtimeA.data.point)
    local p2 = normalizePoint(runtimeB.data.point)

    if not p1 or not p2 then
        debugLog("Conexion saltada por punto invalido en ruta " .. tostring(route.id) .. " index=" .. tostring(lineIndex))
        return
    end

    local lineColor, lineFill, lineState = getLineColorForControls(runtimeA.control, runtimeB.control, route)
    local markerKey = buildLineName(route, lineIndex)

    local width = safeNumber(route.lineWidthMeters or DPS.CONFIG.LINE_WIDTH_METERS, 2500)
    local quadPoints = buildQuadLinePoints(p1, p2, width)

    if not quadPoints then
        debugLog("Conexion saltada porque no se pudo construir QUAD en ruta " .. tostring(route.id) .. " index=" .. tostring(lineIndex))
        return
    end

    local snapshot =
        "quad_connection|" ..
        tostring(lineIndex) .. "|" ..
        tostring(runtimeA.data.name) .. ">" .. tostring(runtimeB.data.name) .. "|" ..
        pointSnapshot(p1) .. ">" .. pointSnapshot(p2) .. "|" ..
        tostring(runtimeA.control) .. ">" .. tostring(runtimeB.control) .. "|" ..
        tostring(lineState) .. "|" ..
        tostring(width) .. "|" ..
        tostring(route.lineType or DPS.CONFIG.DEFAULT_LINE_TYPE)

    addDirectQuad(
        markerKey,
        quadPoints,
        lineColor,
        lineFill,
        route.lineType or DPS.CONFIG.DEFAULT_LINE_TYPE,
        getRouteCoa(route),
        tostring(runtimeA.data.name) .. " -> " .. tostring(runtimeB.data.name),
        snapshot
    )

    registerRouteMarker(route.id, markerKey)
end

-- ============================================================================
-- ROUTE RUNTIME / SNAPSHOT
-- ============================================================================

local function buildRouteRuntime(route)
    local runtime = {}

    for index, airportEntry in ipairs(route.airports or {}) do
        local name = airportEntry.name
        local airportData = findAirportByName(name)

        if airportData then
            local control, source = getAirportControl(route, airportEntry, airportData)

            runtime[index] = {
                index = index,
                entry = airportEntry,
                data = airportData,
                control = normalizeControlValue(control) or 0,
                source = source or "unknown",
                found = true
            }

            debugLog(
                "Ruta " .. tostring(route.id) ..
                " | " .. tostring(index) ..
                " | " .. tostring(name) ..
                " encontrado | control=" .. coalitionName(control) ..
                " | source=" .. tostring(source)
            )
        else
            runtime[index] = {
                index = index,
                entry = airportEntry,
                data = nil,
                control = 0,
                source = "missing",
                found = false
            }

            debugLog(
                "Ruta " .. tostring(route.id) ..
                " | aeropuerto NO encontrado: " .. tostring(name)
            )
        end
    end

    return runtime
end

local function buildRouteSnapshot(route, runtime)
    local parts = {}

    parts[#parts + 1] = "route=" .. tostring(route.id)
    parts[#parts + 1] = "enabled=" .. tostring(route.enabled ~= false)
    parts[#parts + 1] = "controlMode=" .. tostring(route.controlMode)
    parts[#parts + 1] = "circleRadius=" .. tostring(route.circleRadius)
    parts[#parts + 1] = "textOffsetX=" .. tostring(route.textOffsetX)
    parts[#parts + 1] = "textOffsetZ=" .. tostring(route.textOffsetZ)
    parts[#parts + 1] = "textFontSize=" .. tostring(route.textFontSize)
    parts[#parts + 1] = "textMode=" .. tostring(route.textMode)
    parts[#parts + 1] = "lineMode=" .. tostring(route.lineMode)
    parts[#parts + 1] = "lineType=" .. tostring(route.lineType)
    parts[#parts + 1] = "lineWidth=" .. tostring(route.lineWidthMeters or DPS.CONFIG.LINE_WIDTH_METERS)
    parts[#parts + 1] = "coa=" .. tostring(route.coalition)

    for i = 1, #(route.airports or {}) do
        local item = runtime[i]

        if item and item.found and item.data then
            parts[#parts + 1] =
                tostring(item.index) ..
                ":" .. tostring(item.data.name) ..
                ":id=" .. tostring(item.data.id) ..
                ":p=" .. pointSnapshot(item.data.point) ..
                ":c=" .. tostring(item.control) ..
                ":src=" .. tostring(item.source)
        else
            local entry = route.airports[i]
            parts[#parts + 1] =
                tostring(i) ..
                ":" .. tostring(entry and entry.name or "UNKNOWN") ..
                ":MISSING"
        end
    end

    return table.concat(parts, "|")
end

local function drawRoute(route, force)
    if not route or route.enabled == false then
        return false
    end

    if not route.id then
        warn("Ruta sin id. Saltada.")
        return false
    end

    local rid = safeName(route.id)
    local runtime = buildRouteRuntime(route)
    local routeSnapshot = buildRouteSnapshot(route, runtime)

    if not force and DPS.STATE.routeSnapshots[rid] == routeSnapshot then
        debugLog("Sin cambios en ruta: " .. tostring(route.id))
        return false
    end

    debugLog("Redibujando ruta: " .. tostring(route.id))

    cleanRouteMarkers(route.id)

    -- Primero conexiones, para que queden debajo visualmente.
    for i = 1, #(route.airports or {}) - 1 do
        drawConnection(route, runtime[i], runtime[i + 1], i)
    end

    -- Luego circulos y textos.
    for i = 1, #(route.airports or {}) do
        local item = runtime[i]

        if item and item.found and item.data then
            drawCircle(route, item)
            drawText(route, item)
        end
    end

    DPS.STATE.routeSnapshots[rid] = routeSnapshot
    return true
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function DPS.refresh(force)
    if DPS.STATE.manualHidden and not force then
        return false
    end

    scanAirports()
    buildRealControlIndex()

    local any = false

    for _, route in ipairs(DPS.ROUTES or {}) do
        local changed = drawRoute(route, force == true)

        if changed then
            any = true
        end
    end

    DPS.STATE.lastRefreshTime = timer.getTime()
    return any
end

function DPS.clearDraws()
    DPS.STATE.manualHidden = true
    cleanAllMarkers()
    out("Draws limpiados. Usa Reconstruir draws o Refrescar draws ahora para volverlos a mostrar.", 8)
end

function DPS.rebuild()
    DPS.STATE.manualHidden = false
    cleanAllMarkers()
    scanAirports()
    buildRealControlIndex()
    DPS.refresh(true)
    out("Draws reconstruidos.", 8)
end

function DPS.refreshNow()
    DPS.STATE.manualHidden = false
    DPS.refresh(true)
    out("Refresh forzado ejecutado.", 6)
end

function DPS.stop()
    DPS.STATE.started = false
    cleanAllMarkers()

    if DPS.STATE.menuRoot and missionCommands then
        pcall(function()
            missionCommands.removeItem(DPS.STATE.menuRoot)
        end)

        DPS.STATE.menuRoot = nil
    end

    out("Sistema detenido y draws limpiados.", 8)
end

function DPS.showStatus()
    scanAirports()
    buildRealControlIndex()

    local lines = {}

    lines[#lines + 1] = "HDEV Draw Progress System"
    lines[#lines + 1] = "VERSION: " .. tostring(DPS.VERSION)
    lines[#lines + 1] = "Aeropuertos detectados: " .. tostring(#DPS.STATE.airportList)

    local markerCount = 0
    for _, _ in pairs(DPS.STATE.markers or {}) do
        markerCount = markerCount + 1
    end

    lines[#lines + 1] = "Markers activos: " .. tostring(markerCount)

    for _, route in ipairs(DPS.ROUTES or {}) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Ruta: " .. tostring(route.name or route.id) .. " [" .. tostring(route.id) .. "]"

        if route.enabled == false then
            lines[#lines + 1] = "  Estado: DESHABILITADA"
        else
            local runtime = buildRouteRuntime(route)

            for i = 1, #(route.airports or {}) do
                local item = runtime[i]

                if item and item.found and item.data then
                    local flagTxt = item.entry and item.entry.flag and (" | flag=" .. tostring(item.entry.flag)) or ""

                    lines[#lines + 1] =
                        "  " .. tostring(item.index) ..
                        ". " .. tostring(item.data.name) ..
                        " | " .. coalitionName(item.control) ..
                        flagTxt ..
                        " | " .. tostring(item.source)
                else
                    local entry = route.airports[i]
                    lines[#lines + 1] =
                        "  " .. tostring(i) ..
                        ". " .. tostring(entry and entry.name or "UNKNOWN") ..
                        " | NO ENCONTRADO"
                end
            end
        end
    end

    local msg = table.concat(lines, "\n")
    local coa = tonumber(DPS.CONFIG.MENU_COALITION) or -1

    if coa == 1 or coa == 2 then
        trigger.action.outTextForCoalition(coa, msg, 18)
    else
        trigger.action.outText(msg, 18)
    end

    log(msg)
end

-- ============================================================================
-- MENU F10
-- ============================================================================

local function addMenuCommand(label, root, fn)
    local coa = tonumber(DPS.CONFIG.MENU_COALITION) or -1

    if coa == 1 or coa == 2 then
        return missionCommands.addCommandForCoalition(coa, label, root, fn)
    end

    return missionCommands.addCommand(label, root, fn)
end

local function buildMenu()
    if not DPS.CONFIG.ENABLE_MENU then
        return
    end

    if not missionCommands then
        warn("missionCommands no disponible. Menu F10 no creado.")
        return
    end

    if DPS.STATE.menuRoot then
        pcall(function()
            missionCommands.removeItem(DPS.STATE.menuRoot)
        end)

        DPS.STATE.menuRoot = nil
    end

    local coa = tonumber(DPS.CONFIG.MENU_COALITION) or -1

    if coa == 1 or coa == 2 then
        DPS.STATE.menuRoot = missionCommands.addSubMenuForCoalition(coa, DPS.CONFIG.MENU_NAME or "HDEV Draw Progress")
    else
        DPS.STATE.menuRoot = missionCommands.addSubMenu(DPS.CONFIG.MENU_NAME or "HDEV Draw Progress")
    end

    addMenuCommand("Refrescar draws ahora", DPS.STATE.menuRoot, function()
        DPS.refreshNow()
    end)

    addMenuCommand("Mostrar estado de rutas", DPS.STATE.menuRoot, function()
        DPS.showStatus()
    end)

    addMenuCommand("Limpiar draws", DPS.STATE.menuRoot, function()
        DPS.clearDraws()
    end)

    addMenuCommand("Reconstruir draws", DPS.STATE.menuRoot, function()
        DPS.rebuild()
    end)

    debugLog("Menu F10 creado: " .. tostring(DPS.CONFIG.MENU_NAME))
end

-- ============================================================================
-- LOOP
-- ============================================================================

local function mainLoop(_, now)
    if not DPS.STATE.started then
        return nil
    end

    if not DPS.STATE.manualHidden then
        DPS.refresh(false)
    end

    return now + safeNumber(DPS.CONFIG.UPDATE_INTERVAL, 10)
end

function DPS.start()
    if DPS.STATE.started then
        debugLog("El sistema ya estaba iniciado.")
        return
    end

    if not mist or not mist.marker or not mist.marker.add then
        warn("No se pudo iniciar: MIST/mist.marker.add no disponible.")
        return
    end

    DPS.STATE.started = true
    DPS.STATE.manualHidden = false

    scanAirports()
    buildRealControlIndex()
    buildMenu()

    if DPS.CONFIG.FORCE_REDRAW_ON_START then
        DPS.refresh(true)
    else
        DPS.refresh(false)
    end

    timer.scheduleFunction(
        mainLoop,
        nil,
        timer.getTime() + safeNumber(DPS.CONFIG.START_DELAY, 2) + safeNumber(DPS.CONFIG.UPDATE_INTERVAL, 10)
    )

    log("HDEV_DrawProgressSystem iniciado. VERSION: " .. tostring(DPS.VERSION))
end

DPS.start()