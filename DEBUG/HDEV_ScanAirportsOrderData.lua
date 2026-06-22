-- ============================================================================
-- HDEV_AirportScanner_JSON.lua
-- VERSION: 1
--
-- OBJETIVO:
-- - Escanea todos los aeropuertos/helipuertos detectados por DCS.
-- - Los ordena por Airbase ID.
-- - Asigna banderas consecutivas desde START_FLAG.
-- - Guarda un JSON con 3 tablas principales:
--      ordenAeropuertos
--      estadoBanderasAeropuertos
--      aeropuertos
--
-- IMPORTANTE:
-- - Este script NO dibuja marcas.
-- - El radius solo queda guardado para que otro script dibuje la marca.
-- - La coordenada guardada es el centro detectado del aeropuerto.
-- - Requiere io/lfs habilitados si vas a escribir JSON.
-- ============================================================================

HDEV_AirportScannerJSON = HDEV_AirportScannerJSON or {}
local AS = HDEV_AirportScannerJSON

-- ============================================================================
-- CONFIGURACION EDITABLE
-- ============================================================================
AS.CONFIG = AS.CONFIG or {
    DEBUG = true,

    -- Carpeta destino:
    -- lfs.writedir() .. "Config\\HorizontDev\\AFGHANISTAN\\SistemAirbaseScanAfghanistan.json"
    MAP_FOLDER = "AFGHANISTAN",
    JSON_FILE_NAME = "SistemAirbaseScanAfghanistan.json",

    -- Opcional: tambien genera un .lua listo para copiar/pegar tablas.
    WRITE_LUA_TABLE_FILE = true,
    LUA_TABLE_FILE_NAME = "SistemAirbaseTablesAfghanistan.lua",

    -- Primera bandera.
    -- Ejemplo:
    -- Herat = 100
    -- Farah = 101
    -- etc.
    START_FLAG = 100,

    -- Radius por defecto para todas las marcas.
    -- Este script NO dibuja la marca; solo guarda el radius.
    DEFAULT_RADIUS = 40000,

    -- Si ya existe el JSON, conserva bandera/radius/valor editados.
    PRESERVE_EXISTING_VALUES = true,

    -- Tipos de Airbase a incluir.
    -- En DCS normalmente:
    -- category 0 = Airdrome
    -- category 1 = Helipad/FARP
    -- category 2 = Ship
    INCLUDE_AIRDROMES = true,
    INCLUDE_HELIPADS = true,
    INCLUDE_SHIPS = false,

    -- Orden:
    -- "id"    = orden interno de DCS por Airbase ID
    -- "name"  = alfabetico
    -- "world" = orden crudo de world.getAirbases()
    SORT_MODE = "id",

    -- Si quieres forzar radius especifico por aeropuerto:
    RADIUS_OVERRIDES = {
        -- ["Herat"] = 40000,
        -- ["Kandahar"] = 50000,
    },

    -- Si quieres forzar bandera especifica por aeropuerto:
    FLAG_OVERRIDES = {
        -- ["Herat"] = 100,
        -- ["Farah"] = 101,
    },

    -- Corre despues de X segundos para dejar que DCS inicialice bien.
    RUN_DELAY = 1
}

-- ============================================================================
-- TABLAS GLOBALES QUE OTROS SCRIPTS PUEDEN USAR
-- ============================================================================
ordenAeropuertos = ordenAeropuertos or {}

estadoBanderasAeropuertos = estadoBanderasAeropuertos or {
    -- ["Herat"] = { bandera = 100, valor = nil }
}

aeropuertos = aeropuertos or {
    -- ["Herat"] = { position = {x = 25855, y = 0, z = -371268}, radius = 40000 }
}

-- ============================================================================
-- LOG
-- ============================================================================
local function log(msg)
    env.info("[HDEV_AIRPORT_SCANNER] " .. tostring(msg))
    if AS.CONFIG.DEBUG then
        trigger.action.outText("[AIRPORT SCANNER] " .. tostring(msg), 8)
    end
end

local function warn(msg)
    env.info("[HDEV_AIRPORT_SCANNER][WARN] " .. tostring(msg))
    if AS.CONFIG.DEBUG then
        trigger.action.outText("[AIRPORT SCANNER WARN] " .. tostring(msg), 10)
    end
end

-- ============================================================================
-- UTILS
-- ============================================================================
local function round(n)
    n = tonumber(n) or 0
    if n >= 0 then
        return math.floor(n + 0.5)
    end
    return math.ceil(n - 0.5)
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

local function luaEscape(str)
    return jsonEscape(str)
end

local function getBaseDir()
    local wd = ""
    if lfs and lfs.writedir then
        wd = lfs.writedir()
    end

    return wd .. "Config\\HorizontDev\\" .. tostring(AS.CONFIG.MAP_FOLDER) .. "\\"
end

local function getJsonPath()
    return getBaseDir() .. tostring(AS.CONFIG.JSON_FILE_NAME)
end

local function getLuaTablesPath()
    return getBaseDir() .. tostring(AS.CONFIG.LUA_TABLE_FILE_NAME)
end

local function ensureDirectoryForFile(path)
    if not lfs or not lfs.mkdir or not path or path == "" then
        return false
    end

    local separator = "\\"
    local dir = path:match("^(.*[\\/])")
    if not dir then
        return false
    end

    local prefix = ""
    local rest = dir

    if dir:match("^%a:[\\/]") then
        prefix = dir:sub(1, 3)
        rest = dir:sub(4)
    elseif dir:sub(1, 1) == "/" then
        prefix = "/"
        separator = "/"
        rest = dir:sub(2)
    end

    local current = prefix

    for part in string.gmatch(rest, "[^\\/]+") do
        if current == "" or current:sub(-1) == "\\" or current:sub(-1) == "/" then
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

    return data, nil
end

local function loadExistingJson()
    local path = getJsonPath()
    local txt = safeReadFile(path)

    if not txt then
        return nil
    end

    local data, err = decodeJson(txt)
    if not data then
        warn("No se pudo leer JSON existente: " .. tostring(err))
        return nil
    end

    return data
end

local function formatMetric(position)
    local x = round(position.x or 0)
    local z = round(position.z or 0)

    local sx = "+"
    local sz = "+"

    if x < 0 then sx = "-" end
    if z < 0 then sz = "-" end

    return string.format(
        "X%s%08d Z%s%08d",
        sx,
        math.abs(x),
        sz,
        math.abs(z)
    )
end

local function getAirbaseName(airbase)
    local ok, name = pcall(function()
        return airbase:getName()
    end)

    if ok and name and name ~= "" then
        return name
    end

    return nil
end

local function getAirbaseId(airbase)
    local ok, id = pcall(function()
        return airbase:getID()
    end)

    if ok then
        return tonumber(id)
    end

    return nil
end

local function getAirbaseCategory(airbase)
    local ok, desc = pcall(function()
        return Airbase.getDesc(airbase)
    end)

    if ok and type(desc) == "table" then
        return tonumber(desc.category)
    end

    return nil
end

local function categoryAllowed(category)
    if category == nil then
        return true
    end

    if category == 0 then
        return AS.CONFIG.INCLUDE_AIRDROMES == true
    elseif category == 1 then
        return AS.CONFIG.INCLUDE_HELIPADS == true
    elseif category == 2 then
        return AS.CONFIG.INCLUDE_SHIPS == true
    end

    return false
end

local function getAirbasePoint(airbase)
    local ok, point = pcall(function()
        return airbase:getPoint()
    end)

    if ok and point then
        return point
    end

    ok, point = pcall(function()
        local pos = airbase:getPosition()
        if pos and pos.p then
            return pos.p
        end
        return nil
    end)

    if ok and point then
        return point
    end

    return nil
end

local function scanAirports()
    local scanned = {}

    if not world or not world.getAirbases then
        warn("world.getAirbases no disponible.")
        return scanned
    end

    local airbases = world.getAirbases() or {}

    for worldIndex, airbase in ipairs(airbases) do
        local name = getAirbaseName(airbase)
        local id = getAirbaseId(airbase)
        local category = getAirbaseCategory(airbase)
        local point = getAirbasePoint(airbase)

        if name and point and categoryAllowed(category) then
            local position = {
                x = round(point.x or 0),
                y = 0,
                z = round(point.z or point.y or 0)
            }

            scanned[#scanned + 1] = {
                worldIndex = worldIndex,
                id = id or (900000 + worldIndex),
                name = name,
                category = category,
                position = position,
                metric = formatMetric(position)
            }
        end
    end

    local mode = tostring(AS.CONFIG.SORT_MODE or "id"):lower()

    table.sort(scanned, function(a, b)
        if mode == "name" then
            return tostring(a.name) < tostring(b.name)
        elseif mode == "world" then
            return (tonumber(a.worldIndex) or 0) < (tonumber(b.worldIndex) or 0)
        end

        local aid = tonumber(a.id) or 999999
        local bid = tonumber(b.id) or 999999

        if aid == bid then
            return tostring(a.name) < tostring(b.name)
        end

        return aid < bid
    end)

    return scanned
end

local function getPreviousState(previousDoc, airportName)
    if type(previousDoc) ~= "table" then
        return nil
    end

    local state = previousDoc.estadoBanderasAeropuertos
    if type(state) ~= "table" then
        return nil
    end

    return state[airportName]
end

local function getPreviousAirport(previousDoc, airportName)
    if type(previousDoc) ~= "table" then
        return nil
    end

    local aps = previousDoc.aeropuertos
    if type(aps) ~= "table" then
        return nil
    end

    return aps[airportName]
end

local function buildDocument(scanned, previousDoc)
    local doc = {
        meta = {
            version = 1,
            generatedBy = "HDEV_AirportScanner_JSON.lua",
            generatedAt = timer and timer.getTime and round(timer.getTime()) or 0,
            mapFolder = tostring(AS.CONFIG.MAP_FOLDER),
            startFlag = tonumber(AS.CONFIG.START_FLAG) or 100,
            defaultRadius = tonumber(AS.CONFIG.DEFAULT_RADIUS) or 40000,
            sortMode = tostring(AS.CONFIG.SORT_MODE or "id"),
            count = #scanned
        },

        ordenAeropuertos = {},
        estadoBanderasAeropuertos = {},
        aeropuertos = {}
    }

    local usedFlags = {}
    local nextFlag = tonumber(AS.CONFIG.START_FLAG) or 100

    local function takeNextFlag()
        while usedFlags[nextFlag] do
            nextFlag = nextFlag + 1
        end

        local value = nextFlag
        usedFlags[value] = true
        nextFlag = nextFlag + 1
        return value
    end

    for _, item in ipairs(scanned) do
        local name = item.name
        local previousState = nil
        local previousAirport = nil

        if AS.CONFIG.PRESERVE_EXISTING_VALUES then
            previousState = getPreviousState(previousDoc, name)
            previousAirport = getPreviousAirport(previousDoc, name)
        end

        local forcedFlag = AS.CONFIG.FLAG_OVERRIDES and AS.CONFIG.FLAG_OVERRIDES[name]
        local flag = tonumber(forcedFlag)

        if not flag and previousState then
            flag = tonumber(previousState.bandera)
        end

        if not flag then
            flag = takeNextFlag()
        else
            usedFlags[flag] = true
        end

        local value = nil
        if previousState and previousState.valor ~= nil then
            value = tonumber(previousState.valor)
        end

        local forcedRadius = AS.CONFIG.RADIUS_OVERRIDES and AS.CONFIG.RADIUS_OVERRIDES[name]
        local radius = tonumber(forcedRadius)

        if not radius and previousAirport then
            radius = tonumber(previousAirport.radius)
        end

        if not radius then
            radius = tonumber(AS.CONFIG.DEFAULT_RADIUS) or 40000
        end

        doc.ordenAeropuertos[#doc.ordenAeropuertos + 1] = name

        doc.estadoBanderasAeropuertos[name] = {
            bandera = flag,
            valor = value
        }

        doc.aeropuertos[name] = {
            position = {
                x = item.position.x,
                y = item.position.y,
                z = item.position.z
            },
            radius = radius,
            metric = item.metric
        }
    end

    return doc
end

-- ============================================================================
-- ESCRITURA JSON CON ORDEN CONTROLADO
-- ============================================================================
local function jsonNumberOrNull(v)
    if v == nil then
        return "null"
    end

    local n = tonumber(v)
    if not n then
        return "null"
    end

    return tostring(n)
end

local function encodeJsonDocument(doc)
    local lines = {}

    lines[#lines + 1] = "{"

    lines[#lines + 1] = "  \"meta\": {"
    lines[#lines + 1] = "    \"version\": " .. tostring(doc.meta.version or 1) .. ","
    lines[#lines + 1] = "    \"generatedBy\": \"" .. jsonEscape(doc.meta.generatedBy) .. "\","
    lines[#lines + 1] = "    \"generatedAt\": " .. tostring(doc.meta.generatedAt or 0) .. ","
    lines[#lines + 1] = "    \"mapFolder\": \"" .. jsonEscape(doc.meta.mapFolder) .. "\","
    lines[#lines + 1] = "    \"startFlag\": " .. tostring(doc.meta.startFlag or 100) .. ","
    lines[#lines + 1] = "    \"defaultRadius\": " .. tostring(doc.meta.defaultRadius or 40000) .. ","
    lines[#lines + 1] = "    \"sortMode\": \"" .. jsonEscape(doc.meta.sortMode) .. "\","
    lines[#lines + 1] = "    \"count\": " .. tostring(doc.meta.count or 0)
    lines[#lines + 1] = "  },"

    lines[#lines + 1] = "  \"ordenAeropuertos\": ["
    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        local comma = (i < #doc.ordenAeropuertos) and "," or ""
        lines[#lines + 1] = "    \"" .. jsonEscape(name) .. "\"" .. comma
    end
    lines[#lines + 1] = "  ],"

    lines[#lines + 1] = "  \"estadoBanderasAeropuertos\": {"
    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        local info = doc.estadoBanderasAeropuertos[name] or {}
        local comma = (i < #doc.ordenAeropuertos) and "," or ""

        lines[#lines + 1] =
            "    \"" .. jsonEscape(name) .. "\": " ..
            "{ \"bandera\": " .. tostring(tonumber(info.bandera) or 0) ..
            ", \"valor\": " .. jsonNumberOrNull(info.valor) ..
            " }" .. comma
    end
    lines[#lines + 1] = "  },"

    lines[#lines + 1] = "  \"aeropuertos\": {"
    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        local data = doc.aeropuertos[name] or {}
        local p = data.position or { x = 0, y = 0, z = 0 }
        local comma = (i < #doc.ordenAeropuertos) and "," or ""

        lines[#lines + 1] = "    \"" .. jsonEscape(name) .. "\": {"
        lines[#lines + 1] = "      \"position\": {"
        lines[#lines + 1] = "        \"x\": " .. tostring(round(p.x or 0)) .. ","
        lines[#lines + 1] = "        \"y\": " .. tostring(round(p.y or 0)) .. ","
        lines[#lines + 1] = "        \"z\": " .. tostring(round(p.z or 0))
        lines[#lines + 1] = "      },"
        lines[#lines + 1] = "      \"radius\": " .. tostring(tonumber(data.radius) or AS.CONFIG.DEFAULT_RADIUS) .. ","
        lines[#lines + 1] = "      \"metric\": \"" .. jsonEscape(data.metric or formatMetric(p)) .. "\""
        lines[#lines + 1] = "    }" .. comma
    end
    lines[#lines + 1] = "  }"

    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end

-- ============================================================================
-- ESCRITURA LUA OPCIONAL
-- ============================================================================
local function encodeLuaTables(doc)
    local lines = {}

    lines[#lines + 1] = "-- ============================================================================"
    lines[#lines + 1] = "-- Archivo generado por HDEV_AirportScanner_JSON.lua"
    lines[#lines + 1] = "-- VERSION: 1"
    lines[#lines + 1] = "-- ============================================================================"
    lines[#lines + 1] = ""

    lines[#lines + 1] = "ordenAeropuertos = {"
    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        local comma = (i < #doc.ordenAeropuertos) and "," or ""
        lines[#lines + 1] = "    \"" .. luaEscape(name) .. "\"" .. comma
    end
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""

    lines[#lines + 1] = "estadoBanderasAeropuertos = {"
    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        local info = doc.estadoBanderasAeropuertos[name] or {}
        local comma = (i < #doc.ordenAeropuertos) and "," or ""

        local valorText = "nil"
        if info.valor ~= nil then
            valorText = tostring(tonumber(info.valor) or 0)
        end

        lines[#lines + 1] =
            "    [\"" .. luaEscape(name) .. "\"] = { bandera = " ..
            tostring(tonumber(info.bandera) or 0) ..
            ", valor = " .. valorText .. " }" .. comma
    end
    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""

    lines[#lines + 1] = "aeropuertos = {"
    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        local data = doc.aeropuertos[name] or {}
        local p = data.position or { x = 0, y = 0, z = 0 }
        local comma = (i < #doc.ordenAeropuertos) and "," or ""

        lines[#lines + 1] =
            "    [\"" .. luaEscape(name) .. "\"] = { position = {x = " ..
            tostring(round(p.x or 0)) ..
            ", y = " .. tostring(round(p.y or 0)) ..
            ", z = " .. tostring(round(p.z or 0)) ..
            "}, radius = " .. tostring(tonumber(data.radius) or AS.CONFIG.DEFAULT_RADIUS) ..
            " }" .. comma .. "--Metric: " .. tostring(data.metric or formatMetric(p))
    end
    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end

-- ============================================================================
-- APLICAR JSON/TABLAS AL RUNTIME GLOBAL
-- ============================================================================
local function applyGlobals(doc)
    ordenAeropuertos = {}
    estadoBanderasAeropuertos = {}
    aeropuertos = {}

    for i, name in ipairs(doc.ordenAeropuertos or {}) do
        ordenAeropuertos[i] = name

        local info = doc.estadoBanderasAeropuertos[name] or {}
        estadoBanderasAeropuertos[name] = {
            bandera = tonumber(info.bandera) or 0,
            valor = info.valor
        }

        local data = doc.aeropuertos[name] or {}
        local p = data.position or { x = 0, y = 0, z = 0 }

        aeropuertos[name] = {
            position = {
                x = round(p.x or 0),
                y = round(p.y or 0),
                z = round(p.z or 0)
            },
            radius = tonumber(data.radius) or AS.CONFIG.DEFAULT_RADIUS
        }
    end
end

-- ============================================================================
-- EJECUCION PRINCIPAL
-- ============================================================================
function AS.run()
    if not io or not io.open then
        warn("io.open no disponible. Revisa MissionScripting.lua.")
        return nil
    end

    if not lfs or not lfs.writedir then
        warn("lfs.writedir no disponible. Revisa MissionScripting.lua.")
        return nil
    end

    local previousDoc = nil

    if AS.CONFIG.PRESERVE_EXISTING_VALUES then
        previousDoc = loadExistingJson()
    end

    local scanned = scanAirports()

    if #scanned == 0 then
        warn("No se detectaron aeropuertos.")
        return nil
    end

    local doc = buildDocument(scanned, previousDoc)

    local jsonPath = getJsonPath()
    local jsonText = encodeJsonDocument(doc)
    local okJson = safeWriteFile(jsonPath, jsonText)

    if not okJson then
        warn("No se pudo escribir JSON: " .. tostring(jsonPath))
        return nil
    end

    if AS.CONFIG.WRITE_LUA_TABLE_FILE then
        local luaPath = getLuaTablesPath()
        local luaText = encodeLuaTables(doc)
        local okLua = safeWriteFile(luaPath, luaText)

        if not okLua then
            warn("No se pudo escribir archivo LUA de tablas: " .. tostring(luaPath))
        end
    end

    applyGlobals(doc)

    log(
        "JSON guardado con " .. tostring(#doc.ordenAeropuertos) ..
        " aeropuertos. Ruta: " .. tostring(jsonPath)
    )

    return doc
end

-- ============================================================================
-- AUTO RUN
-- ============================================================================
timer.scheduleFunction(function()
    AS.run()
    return nil
end, {}, timer.getTime() + (tonumber(AS.CONFIG.RUN_DELAY) or 1))