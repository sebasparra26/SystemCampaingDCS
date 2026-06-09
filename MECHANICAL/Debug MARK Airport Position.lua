----------------------------------------------------------------
-- HDEV_AirbaseScanner_Afghanistan.lua
-- VERSION: 3
--
-- Escanea los aeropuertos/FARPs/helipuertos expuestos por DCS.
-- Guarda el control en JSON con el formato simple de siempre:
-- {
--   "Jalalabad": 2,
--   "Bagram": 0
-- }
--
-- Tambien crea marcas F10 para identificar cada aeropuerto.
-- VERSION 3:
-- - Agrega circulos rojos especiales para FOB:
--   FOB Camp Dubs
--   FOB Clark
--   FOB Salerno
--   FOB Thunder
--
-- Valores:
-- 0 = NEUTRAL
-- 1 = ROJO
-- 2 = AZUL
----------------------------------------------------------------

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------

local DEBUG = true

local rutaJSON = lfs.writedir() .. "Config\\HorizontDev\\AFGHANISTAN\\SistemAirbaseScan.json"

local INTERVALO_ESCANEO = 60
local DELAY_INICIO = 3

local CREAR_MARCAS_F10 = true
local BORRAR_MARCAS_ANTERIORES = true

local MARK_ID_START = 970000
local MARK_READONLY = true

-- Offset visual de la etiqueta en el mapa F10
-- Si quieres que quede justo encima del aeropuerto, deja ambos en 0
local OFFSET_MARCA_X = 0
local OFFSET_MARCA_Z = 1200

-- Texto de la marca:
-- "compacto" = una sola linea
-- "completo" = varias lineas con datos
local ESTILO_ETIQUETA = "compacto"

-- Si true, guarda en el JSON el control real actual de DCS.
-- Si false, conserva los valores existentes del JSON y solo agrega aeropuertos nuevos en 0.
local ACTUALIZAR_JSON_CON_CONTROL_DCS = true

-- Incluir categorias detectadas por DCS
local INCLUIR_AERODROMOS = true
local INCLUIR_HELIPUERTOS = true
local INCLUIR_BARCOS = false
local INCLUIR_DESCONOCIDOS = true

----------------------------------------------------------------
-- CIRCULOS ESPECIALES PARA FOB
----------------------------------------------------------------

local CREAR_CIRCULOS_FOB_ROJOS = true

local FOB_CIRCLE_ID_START = 980000

-- Radio del circulo en metros
local RADIO_CIRCULO_FOB = 25000

-- Colores de trigger.action.circleToAll usan valores 0 a 1
local COLOR_BORDE_FOB = {1, 0, 0, 1}
local COLOR_RELLENO_FOB = {1, 0, 0, 0.12}

local LINEA_CIRCULO_FOB = 1
local CIRCULO_READONLY = true

local FOB_CIRCULOS_ROJOS = {
    ["FOB Camp Dubs"] = true,
    ["FOB Clark"] = true,
    ["FOB Salerno"] = true,
    ["FOB Thunder"] = true
}

local FOB_ORDEN = {
    "FOB Camp Dubs",
    "FOB Clark",
    "FOB Salerno",
    "FOB Thunder"
}

----------------------------------------------------------------
-- ESTADO INTERNO
----------------------------------------------------------------

HDEV_AirbaseScanner = HDEV_AirbaseScanner or {}

HDEV_AirbaseScanner.estado = HDEV_AirbaseScanner.estado or {
    iniciado = false,
    marcas = {},
    circulosFOB = {},
    ultimoDocumento = nil
}

local estado = HDEV_AirbaseScanner.estado

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------

local function log(msg, tiempo)
    env.info("[AIRBASE_SCANNER] " .. tostring(msg))

    if DEBUG then
        trigger.action.outText("[AIRBASE_SCANNER] " .. tostring(msg), tiempo or 6)
    end
end

local function warn(msg)
    env.info("[AIRBASE_SCANNER] " .. tostring(msg))
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------

local function round(n, d)
    n = tonumber(n) or 0
    local m = 10 ^ (d or 0)
    return math.floor((n * m) + 0.5) / m
end

local function safeCall(fn)
    local ok, result = pcall(fn)
    if ok then
        return result
    end
    return nil
end

local function sortedKeys(tbl)
    local keys = {}

    for k, _ in pairs(tbl or {}) do
        keys[#keys + 1] = tostring(k)
    end

    table.sort(keys, function(a, b)
        return a < b
    end)

    return keys
end

local function coalitionToText(value)
    local n = tonumber(value) or 0

    if n == 1 then
        return "ROJO"
    elseif n == 2 then
        return "AZUL"
    end

    return "NEUTRAL"
end

local function categoryToText(category)
    category = tonumber(category)

    if category == 0 then
        return "AERODROMO"
    elseif category == 1 then
        return "HELIPUERTO"
    elseif category == 2 then
        return "BARCO"
    end

    return "DESCONOCIDO"
end

local function categoryAllowed(category)
    category = tonumber(category)

    if category == 0 then
        return INCLUIR_AERODROMOS
    elseif category == 1 then
        return INCLUIR_HELIPUERTOS
    elseif category == 2 then
        return INCLUIR_BARCOS
    end

    return INCLUIR_DESCONOCIDOS
end

----------------------------------------------------------------
-- ARCHIVOS / JSON
----------------------------------------------------------------

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

local function cargarJSONActual()
    local txt = safeReadFile(rutaJSON)

    if not txt then
        return {}
    end

    local data, err = decodeJson(txt)

    if not data then
        warn("No se pudo leer JSON actual: " .. tostring(err))
        return {}
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

local function encodeJsonSimpleObject(tbl)
    tbl = tbl or {}

    local keys = sortedKeys(tbl)
    local lines = {"{"}

    for i, key in ipairs(keys) do
        local comma = (i < #keys) and "," or ""
        local value = tonumber(tbl[key]) or 0

        lines[#lines + 1] =
            "  \"" ..
            jsonEscape(key) ..
            "\": " ..
            tostring(value) ..
            comma
    end

    lines[#lines + 1] = "}"

    return table.concat(lines, "\n")
end

local function guardarJSONSimple(doc)
    local payload = encodeJsonSimpleObject(doc)
    local ok = safeWriteFile(rutaJSON, payload)

    if ok then
        log("JSON guardado: " .. tostring(rutaJSON), 6)
    else
        warn("No se pudo escribir JSON: " .. tostring(rutaJSON))
    end

    return ok
end

----------------------------------------------------------------
-- AIRBASE DATA
----------------------------------------------------------------

local function getAirbaseName(base)
    return safeCall(function()
        return base:getName()
    end)
end

local function getAirbaseId(base)
    return safeCall(function()
        return base:getID()
    end)
end

local function getAirbasePoint(base)
    local p = safeCall(function()
        return base:getPoint()
    end)

    if not p then
        return nil
    end

    local x = tonumber(p.x) or 0
    local z = tonumber(p.z) or 0
    local y = tonumber(p.y) or 0

    local ground = safeCall(function()
        return land.getHeight({ x = x, y = z })
    end)

    if ground then
        y = ground
    end

    return {
        x = round(x, 3),
        y = round(y, 3),
        z = round(z, 3)
    }
end

local function getAirbaseDesc(base)
    local desc = safeCall(function()
        return Airbase.getDesc(base)
    end)

    if type(desc) == "table" then
        return desc
    end

    desc = safeCall(function()
        return base:getDesc()
    end)

    if type(desc) == "table" then
        return desc
    end

    return {}
end

local function buildCoalitionMap()
    local result = {}

    local basesRojas = coalition.getAirbases(1) or {}
    local basesAzules = coalition.getAirbases(2) or {}

    for _, base in ipairs(basesRojas) do
        local name = getAirbaseName(base)
        if name then
            result[name] = 1
        end
    end

    for _, base in ipairs(basesAzules) do
        local name = getAirbaseName(base)
        if name then
            result[name] = 2
        end
    end

    return result
end

local function getFlagForAirbase(name)
    if not estadoBanderasAeropuertos then
        return nil
    end

    local info = estadoBanderasAeropuertos[name]

    if not info then
        return nil
    end

    return tonumber(info.bandera)
end

local function escanearAeropuertos()
    local raw = world.getAirbases() or {}
    local coalitionMap = buildCoalitionMap()
    local lista = {}

    for _, base in ipairs(raw) do
        local nombre = getAirbaseName(base)
        local punto = getAirbasePoint(base)
        local desc = getAirbaseDesc(base)

        local categoria = tonumber(desc.category)

        if nombre and punto and categoryAllowed(categoria) then
            local coal = coalitionMap[nombre] or 0

            lista[#lista + 1] = {
                name = nombre,
                dcsId = tonumber(getAirbaseId(base)) or 0,
                category = categoria or -1,
                categoryName = categoryToText(categoria),
                coalition = coal,
                coalitionName = coalitionToText(coal),
                flag = getFlagForAirbase(nombre),
                point = punto
            }
        end
    end

    table.sort(lista, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    for i, entry in ipairs(lista) do
        entry.scanId = i
        entry.markId = MARK_ID_START + i

        entry.markPoint = {
            x = round((entry.point.x or 0) + OFFSET_MARCA_X, 3),
            y = entry.point.y or 0,
            z = round((entry.point.z or 0) + OFFSET_MARCA_Z, 3)
        }
    end

    return lista
end

----------------------------------------------------------------
-- MARCAS F10
----------------------------------------------------------------

local function removeMark(markId)
    if not markId then
        return
    end

    pcall(function()
        trigger.action.removeMark(markId)
    end)
end

local function borrarMarcas()
    for _, markId in pairs(estado.marcas or {}) do
        removeMark(markId)
    end

    estado.marcas = {}
end

local function borrarCirculosFOB()
    for _, markId in pairs(estado.circulosFOB or {}) do
        removeMark(markId)
    end

    estado.circulosFOB = {}
end

local function construirTextoMarca(entry)
    local flagText = "SIN BANDERA"

    if entry.flag then
        flagText = "FLAG " .. tostring(entry.flag)
    end

    if ESTILO_ETIQUETA == "completo" then
        return
            "AIRBASE " .. tostring(entry.scanId) .. "\n" ..
            "Nombre: " .. tostring(entry.name) .. "\n" ..
            "DCS ID: " .. tostring(entry.dcsId) .. "\n" ..
            "Tipo: " .. tostring(entry.categoryName) .. "\n" ..
            "Control: " .. tostring(entry.coalitionName) .. " (" .. tostring(entry.coalition) .. ")\n" ..
            "Bandera: " .. flagText .. "\n" ..
            "X: " .. tostring(math.floor(entry.point.x or 0)) ..
            " Z: " .. tostring(math.floor(entry.point.z or 0))
    end

    return
        "AB-" ..
        string.format("%03d", tonumber(entry.scanId) or 0) ..
        " | " ..
        tostring(entry.name) ..
        " | " ..
        tostring(entry.coalitionName) ..
        " | " ..
        flagText
end

local function dibujarMarcas(lista)
    if not CREAR_MARCAS_F10 then
        return
    end

    if BORRAR_MARCAS_ANTERIORES then
        borrarMarcas()
    end

    for _, entry in ipairs(lista or {}) do
        local texto = construirTextoMarca(entry)
        local markId = entry.markId
        local punto = entry.markPoint or entry.point

        removeMark(markId)

        local ok, err = pcall(function()
            trigger.action.markToAll(
                markId,
                texto,
                punto,
                MARK_READONLY
            )
        end)

        if ok then
            estado.marcas[entry.name] = markId
        else
            warn("No se pudo crear marca para " .. tostring(entry.name) .. ": " .. tostring(err))
        end
    end
end

----------------------------------------------------------------
-- CIRCULOS ROJOS FOB
----------------------------------------------------------------

local function crearMapaPorNombre(lista)
    local mapa = {}

    for _, entry in ipairs(lista or {}) do
        mapa[entry.name] = entry
    end

    return mapa
end

local function dibujarCirculosFOB(lista)
    if not CREAR_CIRCULOS_FOB_ROJOS then
        return
    end

    if not trigger.action.circleToAll then
        warn("trigger.action.circleToAll no disponible. No se dibujan circulos FOB.")
        return
    end

    borrarCirculosFOB()

    local porNombre = crearMapaPorNombre(lista)
    local encontrados = 0

    for i, nombreFOB in ipairs(FOB_ORDEN) do
        local entry = porNombre[nombreFOB]

        if entry and entry.point then
            local id = FOB_CIRCLE_ID_START + i
            local texto = nombreFOB
            local punto = {
                x = entry.point.x,
                y = entry.point.y,
                z = entry.point.z
            }

            removeMark(id)

            local ok, err = pcall(function()
                trigger.action.circleToAll(
                    -1,
                    id,
                    punto,
                    RADIO_CIRCULO_FOB,
                    COLOR_BORDE_FOB,
                    COLOR_RELLENO_FOB,
                    LINEA_CIRCULO_FOB,
                    CIRCULO_READONLY,
                    texto
                )
            end)

            if ok then
                estado.circulosFOB[nombreFOB] = id
                encontrados = encontrados + 1
            else
                warn("No se pudo crear circulo FOB para " .. tostring(nombreFOB) .. ": " .. tostring(err))
            end
        else
            if DEBUG then
                warn("FOB no encontrado por world.getAirbases(): " .. tostring(nombreFOB))
            end
        end
    end

    if DEBUG then
        log("Circulos FOB rojos creados: " .. tostring(encontrados), 6)
    end
end

----------------------------------------------------------------
-- JSON DE CONTROL SIMPLE
----------------------------------------------------------------

local function construirJSONControlSimple(lista)
    local actual = cargarJSONActual()
    local nuevo = {}

    for _, entry in ipairs(lista or {}) do
        local nombre = entry.name

        if ACTUALIZAR_JSON_CON_CONTROL_DCS then
            nuevo[nombre] = tonumber(entry.coalition) or 0
        else
            nuevo[nombre] = tonumber(actual[nombre]) or 0
        end
    end

    return nuevo
end

local function actualizarTablasGlobales(doc)
    controlAeropuertos = controlAeropuertos or {}
    coalicionPorBase = coalicionPorBase or {}

    for nombre, coal in pairs(doc or {}) do
        controlAeropuertos[nombre] = tonumber(coal) or 0
        coalicionPorBase[nombre] = tonumber(coal) or 0
    end
end

----------------------------------------------------------------
-- CICLO PRINCIPAL
----------------------------------------------------------------

local function escanearGuardarYMarcar()
    local lista = escanearAeropuertos()
    local doc = construirJSONControlSimple(lista)

    estado.ultimoDocumento = doc

    actualizarTablasGlobales(doc)
    dibujarMarcas(lista)
    dibujarCirculosFOB(lista)
    guardarJSONSimple(doc)

    log("Escaneo completado. Aeropuertos detectados: " .. tostring(#lista), 8)

    return lista
end

local function iniciar()
    if estado.iniciado then
        return
    end

    estado.iniciado = true

    timer.scheduleFunction(function()
        escanearGuardarYMarcar()
        return timer.getTime() + INTERVALO_ESCANEO
    end, {}, timer.getTime() + DELAY_INICIO)

    log("Sistema iniciado.", 8)
end

iniciar()