-- ============================================================================
-- HDEV_MarketplaceAutoRoutes.lua
-- VERSION: 13
--
-- Base real: VERSION 1 subida por el usuario, la que SI mostraba destinos.
--
-- CAMBIO VERSION 13:
-- - NO usa plantilla.
-- - NO reconstruye el menu.
-- - NO toca economia.
-- - NO toca StockWarehouse.
-- - Mantiene la deteccion dinamica de aeropuertos del archivo original.
-- - Mantiene la reconstruccion dinamica de plantillasLogisticaB/R.
-- - Mantiene destinosPorSubvariante dinamico.
-- - Mantiene mist.dynAdd.
--
-- CORRECCION REAL DEL PROBLEMA:
-- - Se mantiene la base original que SI mostraba destinos.
-- - Se conserva airdromeId en WP2, porque ya se comprobo que no es el problema.
-- - Se conservan las opciones IA correctas del Mission Editor:
--      Option 0  = 0
--      Option 1  = 0
--      Option 4  = 3
--      Option 32 = true
-- - Se usan altitudes BARO/MSL reales para no mezclar RADIO con alt=0.
-- - Se evita payload vacio: payload minimo con fuel/chaff/flare/gun.
-- - DESPUES de mist.dynAdd se fuerza Controller.setTask(Mission) con la ruta completa.
--   Esto ataca el problema correcto: que el grupo nazca, pero el controlador no ejecute
--   la mision/ruta avanzada exactamente como se construyo en groupData.
-- - Se restaura getHeading del archivo base original. El heading no decide el aterrizaje vertical.
--
-- CARGAR RECOMENDADO:
-- 1) mist_4_5_128.lua
-- 2) Economia / HDEV_Economy
-- 3) StockWarehouse_*.lua
-- 4) MENU_CONTENT_logistic_Kola.lua
-- 5) HDEV_MarketplaceCore_1_1.lua
-- 6) HDEV_MarketplaceAutoRoutes.lua  <-- este archivo
-- 7) MENU_logisticCoalition_BLUE_V4.lua
-- 8) MENU_logisticCoalition_RED_V4.lua
-- ============================================================================

HDEV_MarketplaceAutoRoutes = HDEV_MarketplaceAutoRoutes or {}
local AR = HDEV_MarketplaceAutoRoutes

-- ============================================================================
-- CONFIGURACION EDITABLE
-- ============================================================================
AR.CONFIG = AR.CONFIG or {
    DEBUG = true,

    -- Rutas automaticas
    ENABLE_AUTO_ROUTES = true,
    OVERWRITE_ROUTE_TABLES = true,
    UPDATE_DESTINOS_POR_SUBVARIANTE = true,

    -- Punto de spawn = centro del aeropuerto + offset
    SPAWN_OFFSET_NM = 3,
    SPAWN_DIRECTION = "north", -- north | south | east | west | northeast | northwest | southeast | southwest
    SPAWN_ALT_AGL = 250,

    -- Helicopteros por coalicion
    BLUE_TRANSPORT_TYPE = "CH-47Fbl1",
    RED_TRANSPORT_TYPE = "Mi-8MT",
    BLUE_COUNTRY_ID = country.id.USA,
    RED_COUNTRY_ID = country.id.RUSSIA,

    -- Velocidad m/s. 42 m/s ~= 151 km/h
    DEFAULT_SPEED = 42,
    DEFAULT_RECARGO_BLUE = 1.0,
    DEFAULT_RECARGO_RED = 1.0,
    DEFAULT_TIME_MULTIPLIER = 1.0,

    -- Validacion de compra
    -- "real"   = coalition.getAirbases() manda.
    -- "flag"   = usa bandera data.bandera / cfg.allowedFlagValue.
    -- "hybrid" = primero real; si no puede resolver, cae a bandera.
    VALIDATION_MODE = "hybrid",

    -- Que hacer si el aeropuerto esta neutral.
    -- hidden = nadie puede comprar
    -- both   = ambos pueden comprar
    -- blue   = solo azul
    -- red    = solo rojo
    NEUTRAL_MODE = "hidden",

    -- Banderas automaticas si no existe estadoBanderasAeropuertos[nombre].bandera
    AUTO_FLAG_START = 50000,

    -- Entrega real en destino especifico
    DELIVERY_RADIUS = 3000,
    LANDING_AGL_MAX = 30,
    DELIVERY_STOP_SPEED = 2,
    DELIVERY_MIN_ALT = 80,
    DELIVERY_DESTROY_DELAY = 20,
    MONITOR_INTERVAL = 5,
    COOLDOWN_SECONDS = 120,

    -- Menu existente
    MENU_NAME = "MARKETPLACE",
    ITEMS_PER_PAGE = 8,
    ROUTE_ZONE_NAME = "Rutas",

    -- Opciones del heli dinamico
    USE_EDITOR_HELI_OPTIONS = true,

    -- VERSION 13:
    -- No basta con que las opciones existan en groupData.
    -- Despues del spawn se fuerza la mision real del Controller con setTask().
    FORCE_CONTROLLER_MISSION_AFTER_SPAWN = true,
    FORCE_CONTROLLER_DELAY = 1.0,
    FORCE_CONTROLLER_RETRIES = 3,
    FORCE_CONTROLLER_RETRY_INTERVAL = 1.0,

    -- Mantengo esta variable por compatibilidad, pero ahora el trabajo real lo hace setTask().
    APPLY_CONTROLLER_OPTIONS_AFTER_SPAWN = true,

    -- Debug de archivo, por si vuelve a pasar algo raro
    ENABLE_FILE_DEBUG = false,
    DEBUG_OUTPUT_DIR = lfs.writedir() .. "Config\\HorizontDev\\DebugMarketplaceAutoRoutes\\",

    -- Seguridad
    INSTALL_RETRIES = 20,
    INSTALL_RETRY_SECONDS = 1,
}

AR.STATE = AR.STATE or {
    installed = false,
    installAttempts = 0,
    airports = {},
    airportByName = {},
    originalRequestDelivery = nil,
    originalMonitorTick = nil,
    originalShowRoutes = nil,
    nextSpawnId = 0,
}

-- ============================================================================
-- LOG / UTILS
-- ============================================================================
local function log(msg)
    env.info("[HDEV_MARKET_AUTOROUTES] " .. tostring(msg))
    if AR.CONFIG.DEBUG then
        trigger.action.outText("[MARKET AUTO] " .. tostring(msg), 8)
    end
end

local function warn(msg)
    env.info("[HDEV_MARKET_AUTOROUTES] " .. tostring(msg))
end

local function outCoalition(side, msg, seconds)
    trigger.action.outTextForCoalition(side, tostring(msg), seconds or 10)
end

local function nmToMeters(nm)
    return (tonumber(nm) or 0) * 1852
end

local function safeName(s)
    s = tostring(s or "")
    s = s:gsub("[^%w_]+", "_")
    s = s:gsub("_+", "_")
    s = s:gsub("^_", "")
    s = s:gsub("_$", "")
    if s == "" then s = "AIRBASE" end
    return s
end

local function deepCopy(tbl)
    if mist and mist.utils and mist.utils.deepCopy then
        return mist.utils.deepCopy(tbl)
    end
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do
        out[k] = deepCopy(v)
    end
    return out
end

local function point2D(p)
    if not p then return { x = 0, y = 0, z = 0 } end
    return {
        x = tonumber(p.x) or 0,
        y = tonumber(p.y) or 0,
        z = tonumber(p.z or p.y) or 0,
    }
end

local function distance2D(a, b)
    if not a or not b then return math.huge end
    local ax = tonumber(a.x) or 0
    local az = tonumber(a.z or a.y) or 0
    local bx = tonumber(b.x) or 0
    local bz = tonumber(b.z or b.y) or 0
    local dx = ax - bx
    local dz = az - bz
    return math.sqrt(dx * dx + dz * dz)
end

local function formatMoney(value)
    if HDEV_Economy and HDEV_Economy.formatMoney then
        return HDEV_Economy.formatMoney(value)
    end

    value = tonumber(value) or 0
    local entero = math.floor(value)
    local partes = {}
    repeat
        table.insert(partes, 1, string.format("%03d", entero % 1000))
        entero = math.floor(entero / 1000)
    until entero == 0
    partes[1] = tostring(tonumber(partes[1]))
    return "$" .. table.concat(partes, ".")
end

local function getEconomy()
    return HDEV_Economy
end

local function sortedAirportList(list)
    table.sort(list, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

local function getAirbaseId(airbase)
    if not airbase then return nil end
    local ok, id = pcall(function()
        return airbase:getID()
    end)
    if ok then return id end
    return nil
end

local function getTerrainAltMSL(point)
    if not point then return 0 end
    local ok, h = pcall(function()
        return land.getHeight({
            x = tonumber(point.x) or 0,
            y = tonumber(point.z or point.y) or 0,
        })
    end)
    if ok and type(h) == "number" then
        return h
    end
    return 0
end

local function getHeading(fromPoint, toPoint)
    local dx = (toPoint.x or 0) - (fromPoint.x or 0)
    local dz = (toPoint.z or toPoint.y or 0) - (fromPoint.z or fromPoint.y or 0)

    -- VERSION 13:
    -- Restaurado al comportamiento del archivo base original.
    -- El heading solo orienta el nacimiento; NO decide el aterrizaje vertical.
    -- En DCS normalmente el heading se mide desde el eje norte/z.
    return math.atan2(dx, dz)
end

local function offsetPointFrom(center, nm, direction)
    local dist = nmToMeters(nm)
    local p = point2D(center)
    local dir = tostring(direction or "north"):lower()

    local dx, dz = 0, 0
    if dir == "north" then
        dz = dist
    elseif dir == "south" then
        dz = -dist
    elseif dir == "east" then
        dx = dist
    elseif dir == "west" then
        dx = -dist
    elseif dir == "northeast" then
        dx = dist * 0.70710678
        dz = dist * 0.70710678
    elseif dir == "northwest" then
        dx = -dist * 0.70710678
        dz = dist * 0.70710678
    elseif dir == "southeast" then
        dx = dist * 0.70710678
        dz = -dist * 0.70710678
    elseif dir == "southwest" then
        dx = -dist * 0.70710678
        dz = -dist * 0.70710678
    else
        dz = dist
    end

    return { x = p.x + dx, y = p.y, z = p.z + dz }
end

local function getCoalitionName(side)
    if side == 1 then return "ROJO" end
    if side == 2 then return "AZUL" end
    return "NEUTRAL"
end

-- ============================================================================
-- DEBUG FILE
-- ============================================================================
local function ensureDirectory(path)
    if not AR.CONFIG.ENABLE_FILE_DEBUG then return false end
    if not lfs or not lfs.mkdir then return false end

    path = tostring(path or ""):gsub("/", "\\")

    local drive = path:match("^(%a:\\)")
    local current = ""

    if drive then
        current = drive
        path = path:sub(4)
    elseif path:sub(1, 1) == "\\" then
        current = "\\"
        path = path:sub(2)
    end

    for part in string.gmatch(path, "[^\\]+") do
        if part ~= "" then
            if current == "" or current:sub(-1) == "\\" then
                current = current .. part
            else
                current = current .. "\\" .. part
            end
            lfs.mkdir(current)
        end
    end

    return true
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

local function serialize(value, indent, seen)
    indent = indent or 0
    seen = seen or {}

    local t = type(value)
    if t == "nil" then
        return "nil"
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t ~= "table" then
        return string.format("%q", tostring(value))
    end

    if seen[value] then
        return string.format("%q", "<cycle>")
    end

    seen[value] = true

    local pad = string.rep(" ", indent)
    local childPad = string.rep(" ", indent + 4)
    local lines = { "{" }

    for _, k in ipairs(sortedKeys(value)) do
        local keyText
        if type(k) == "number" then
            keyText = "[" .. tostring(k) .. "]"
        else
            keyText = "[" .. string.format("%q", tostring(k)) .. "]"
        end

        lines[#lines + 1] = childPad .. keyText .. " = " .. serialize(value[k], indent + 4, seen) .. ","
    end

    lines[#lines + 1] = pad .. "}"
    seen[value] = nil
    return table.concat(lines, "\n")
end

local function safeWriteFile(path, text)
    if not AR.CONFIG.ENABLE_FILE_DEBUG then return false end
    local ok = pcall(function()
        local dir = tostring(path or ""):match("^(.*)[\\/][^\\/]+$")
        if dir then ensureDirectory(dir) end
        local f = io.open(path, "w")
        if not f then return false end
        f:write(text or "")
        if f.flush then f:flush() end
        f:close()
        return true
    end)
    return ok
end

local function exportDebugLua(fileName, data)
    if not AR.CONFIG.ENABLE_FILE_DEBUG then return end
    local dir = AR.CONFIG.DEBUG_OUTPUT_DIR or (lfs.writedir() .. "Config\\HorizontDev\\DebugMarketplaceAutoRoutes\\")
    ensureDirectory(dir)
    safeWriteFile(dir .. safeName(fileName) .. ".lua", "return " .. serialize(data, 0))
end

-- ============================================================================
-- DETECCION DE AEROPUERTOS Y CONTROL
-- ============================================================================
local function buildCoalitionAirbaseSet(side)
    local set = {}
    local ok, bases = pcall(function()
        return coalition.getAirbases(side)
    end)

    if ok and type(bases) == "table" then
        for _, ab in ipairs(bases) do
            local okName, name = pcall(function()
                return ab:getName()
            end)
            if okName and name then
                set[name] = true
            end
        end
    end

    return set
end

local function getRealAirportOwner(airportName)
    local blueSet = buildCoalitionAirbaseSet(2)
    if blueSet[airportName] then return 2, true end

    local redSet = buildCoalitionAirbaseSet(1)
    if redSet[airportName] then return 1, true end

    return 0, true
end

local function getFlagForAirport(name, index, previousData)
    if type(estadoBanderasAeropuertos) == "table" then
        local info = estadoBanderasAeropuertos[name]
        if type(info) == "table" and info.bandera ~= nil then
            return tonumber(info.bandera) or info.bandera
        end
    end

    if type(previousData) == "table" and previousData.bandera ~= nil then
        return previousData.bandera
    end

    return (tonumber(AR.CONFIG.AUTO_FLAG_START) or 50000) + (tonumber(index) or 0)
end

local function getControlFromFlag(data)
    if not data or data.bandera == nil then
        return nil
    end

    local ok, value = pcall(function()
        return trigger.misc.getUserFlag(data.bandera)
    end)

    if ok then
        return tonumber(value) or 0
    end

    return nil
end

local function getControlFromGlobals(airportName)
    if type(controlAeropuertos) == "table" and controlAeropuertos[airportName] ~= nil then
        return tonumber(controlAeropuertos[airportName]) or 0
    end

    if type(coalicionPorBase) == "table" and coalicionPorBase[airportName] ~= nil then
        return tonumber(coalicionPorBase[airportName]) or 0
    end

    if type(estadoBanderasAeropuertos) == "table" then
        local info = estadoBanderasAeropuertos[airportName]
        if type(info) == "table" then
            if info.valor ~= nil then
                return tonumber(info.valor) or 0
            end
            if info.bandera ~= nil then
                local ok, value = pcall(function()
                    return trigger.misc.getUserFlag(info.bandera)
                end)
                if ok then
                    return tonumber(value) or 0
                end
            end
        end
    end

    return nil
end

local function getAirportControl(airportName, data)
    local mode = tostring(AR.CONFIG.VALIDATION_MODE or "hybrid"):lower()

    if mode == "flag" then
        local fromFlag = getControlFromFlag(data)
        if fromFlag ~= nil then return fromFlag, "flag" end
        local fromGlobals = getControlFromGlobals(airportName)
        if fromGlobals ~= nil then return fromGlobals, "global" end
        return 0, "unknown"
    end

    local realOwner, okReal = getRealAirportOwner(airportName)
    if mode == "real" then
        return realOwner or 0, okReal and "real" or "unknown"
    end

    -- hybrid
    if okReal then
        return realOwner or 0, "real"
    end

    local fromGlobals = getControlFromGlobals(airportName)
    if fromGlobals ~= nil then return fromGlobals, "global" end

    local fromFlag = getControlFromFlag(data)
    if fromFlag ~= nil then return fromFlag, "flag" end

    return 0, "unknown"
end

local function canCoalitionBuy(cfg, airportName, data)
    local current, source = getAirportControl(airportName, data)
    local side = cfg.coalition

    if current == side then
        return true, current, source
    end

    if current == 0 then
        local neutralMode = tostring(AR.CONFIG.NEUTRAL_MODE or "hidden"):lower()
        if neutralMode == "both" then
            return true, current, source
        elseif neutralMode == "blue" and side == 2 then
            return true, current, source
        elseif neutralMode == "red" and side == 1 then
            return true, current, source
        end
    end

    return false, current, source
end

function AR.detectAirports()
    local airports = {}
    local byName = {}

    local ok, allBases = pcall(function()
        return world.getAirbases()
    end)

    if not ok or type(allBases) ~= "table" then
        warn("world.getAirbases() no disponible o fallo.")
        return {}, {}
    end

    for _, ab in ipairs(allBases) do
        local okName, name = pcall(function()
            return ab:getName()
        end)
        local okPoint, point = pcall(function()
            return ab:getPoint()
        end)

        if okName and name and name ~= "" and okPoint and point then
            local entry = {
                name = name,
                airbase = ab,
                id = getAirbaseId(ab),
                point = point2D(point),
            }
            airports[#airports + 1] = entry
            byName[name] = entry
        end
    end

    sortedAirportList(airports)
    AR.STATE.airports = airports
    AR.STATE.airportByName = byName

    return airports, byName
end

function AR.rebuildGlobalRouteTables()
    local airports = AR.STATE.airports
    if not airports or #airports == 0 then
        airports = AR.detectAirports()
    end

    if not airports or #airports == 0 then
        warn("No se detectaron aeropuertos para rutas automaticas.")
        return false
    end

    local oldB = type(plantillasLogisticaB) == "table" and plantillasLogisticaB or {}
    local oldR = type(plantillasLogisticaR) == "table" and plantillasLogisticaR or {}
    local oldRecB = type(recargoAeropuertoB) == "table" and recargoAeropuertoB or {}
    local oldRecR = type(recargoAeropuertoR) == "table" and recargoAeropuertoR or {}
    local oldMulB = type(multiplicadorTiempoB) == "table" and multiplicadorTiempoB or {}
    local oldMulR = type(multiplicadorTiempoR) == "table" and multiplicadorTiempoR or {}

    local newPlantillasB = {}
    local newPlantillasR = {}
    local newCoordsB = {}
    local newCoordsR = {}
    local newRecB = {}
    local newRecR = {}
    local newMulB = {}
    local newMulR = {}
    local destinos = {}

    for index, airport in ipairs(airports) do
        local name = airport.name
        local dest = point2D(airport.point)
        local spawn = offsetPointFrom(dest, AR.CONFIG.SPAWN_OFFSET_NM, AR.CONFIG.SPAWN_DIRECTION)

        destinos[#destinos + 1] = name
        newCoordsB[name] = deepCopy(dest)
        newCoordsR[name] = deepCopy(dest)

        local flagB = getFlagForAirport(name, index, oldB[name])
        local flagR = getFlagForAirport(name, index, oldR[name])

        newPlantillasB[name] = {
            autoRoute = true,
            template = "AUTO_BLUE_" .. safeName(name), -- solo compatibilidad visual; NO depende del editor
            bandera = flagB,
            origen = deepCopy(spawn),
            velocidad = tonumber(AR.CONFIG.DEFAULT_SPEED) or 42,
            airportName = name,
            originPoint = deepCopy(spawn),
            spawnPoint = deepCopy(spawn),
            destinationPoint = deepCopy(dest),
            landingPoint = deepCopy(dest),
            destinationAirbaseName = name,
            transportType = AR.CONFIG.BLUE_TRANSPORT_TYPE,
            coalition = 2,
            countryId = AR.CONFIG.BLUE_COUNTRY_ID,
            airbaseId = airport.id,
        }

        newPlantillasR[name] = {
            autoRoute = true,
            template = "AUTO_RED_" .. safeName(name), -- solo compatibilidad visual; NO depende del editor
            bandera = flagR,
            origen = deepCopy(spawn),
            velocidad = tonumber(AR.CONFIG.DEFAULT_SPEED) or 42,
            airportName = name,
            originPoint = deepCopy(spawn),
            spawnPoint = deepCopy(spawn),
            destinationPoint = deepCopy(dest),
            landingPoint = deepCopy(dest),
            destinationAirbaseName = name,
            transportType = AR.CONFIG.RED_TRANSPORT_TYPE,
            coalition = 1,
            countryId = AR.CONFIG.RED_COUNTRY_ID,
            airbaseId = airport.id,
        }

        newRecB[name] = oldRecB[name] or AR.CONFIG.DEFAULT_RECARGO_BLUE or 1.0
        newRecR[name] = oldRecR[name] or AR.CONFIG.DEFAULT_RECARGO_RED or 1.0
        newMulB[name] = oldMulB[name] or AR.CONFIG.DEFAULT_TIME_MULTIPLIER or 1.0
        newMulR[name] = oldMulR[name] or AR.CONFIG.DEFAULT_TIME_MULTIPLIER or 1.0
    end

    if AR.CONFIG.OVERWRITE_ROUTE_TABLES then
        plantillasLogisticaB = newPlantillasB
        plantillasLogisticaR = newPlantillasR
        coordenadasAerodromosB = newCoordsB
        coordenadasAerodromosR = newCoordsR
        recargoAeropuertoB = newRecB
        recargoAeropuertoR = newRecR
        multiplicadorTiempoB = newMulB
        multiplicadorTiempoR = newMulR
    end

    AR.destinosBase = destinos
    _G.destinosBaseAutoRoutes = destinos

    if AR.CONFIG.UPDATE_DESTINOS_POR_SUBVARIANTE then
        destinosPorSubvariante = destinosPorSubvariante or {}

        if type(subvariantesAvion) == "table" then
            for _, subMap in pairs(subvariantesAvion) do
                if type(subMap) == "table" then
                    for _, claveSub in pairs(subMap) do
                        destinosPorSubvariante[claveSub] = destinos
                    end
                end
            end
        else
            for subKey, _ in pairs(destinosPorSubvariante) do
                destinosPorSubvariante[subKey] = destinos
            end
        end
    end

    log("Rutas automaticas generadas: " .. tostring(#airports) .. " aeropuertos.")
    return true
end

-- ============================================================================
-- WAREHOUSE / INVENTARIO
-- Copia funcional de la logica del core para no tocar HDEV_MarketplaceCore_1_1.lua
-- ============================================================================
local LIQUID_NAME_TO_ID = {
    jet_fuel = 0,
    gasoline = 1,
    methanol_mixture = 2,
    diesel = 3,
}

local function applyInventoryToAirbase(side, airport, data)
    local base = Airbase.getByName(airport)
    if not base then
        return false, "Airbase no encontrada: " .. tostring(airport)
    end

    local warehouse = base:getWarehouse()
    if not warehouse then
        return false, "Warehouse no disponible en: " .. tostring(airport)
    end

    local resumen = {}
    local totalAviones = 0

    local function addWarehouseItem(ws, amount)
        if not ws or amount == nil then
            return
        end

        local cantidad = tonumber(amount) or 0
        if cantidad <= 0 then
            return
        end

        local ok, err = pcall(function()
            Warehouse.addItem(warehouse, ws, cantidad)
        end)

        if not ok then
            warn("Fallo agregando item al warehouse en " .. tostring(airport) .. ": " .. tostring(err))
        end
    end

    local function addLiquid(liquidName, amount)
        local liquidId = LIQUID_NAME_TO_ID[liquidName]
        if liquidId == nil then
            warn("Liquido no soportado en marketplace: " .. tostring(liquidName))
            return
        end

        local cantidad = tonumber(amount) or 0
        if cantidad <= 0 then
            return
        end

        local actual = 0
        local okRead, readVal = pcall(function()
            return warehouse:getLiquidAmount(liquidId)
        end)

        if okRead and type(readVal) == "number" then
            actual = readVal
        end

        local nuevoTotal = actual + cantidad
        local okWrite, errWrite = pcall(function()
            warehouse:setLiquidAmount(liquidId, nuevoTotal)
        end)

        if not okWrite then
            warn("Fallo agregando liquido '" .. tostring(liquidName) .. "' en " .. tostring(airport) .. ": " .. tostring(errWrite))
            return
        end

        table.insert(resumen, "LIQUIDO: " .. tostring(liquidName) .. " +" .. tostring(cantidad))
    end

    if data.avion then
        addWarehouseItem(data.avion.ws, data.avion.cantidad)
        totalAviones = tonumber(data.avion.cantidad) or 0
    end

    local function loadSection(section, title)
        for name, item in pairs(section or {}) do
            if item and item.ws and item.cantidad then
                addWarehouseItem(item.ws, item.cantidad)
                table.insert(resumen, title .. ": " .. tostring(name) .. " x" .. tostring(item.cantidad))
            end
        end
    end

    loadSection(data.bombas, "BOMBA")
    loadSection(data.bombas_guiadas, "BOMBAG")
    loadSection(data.cohetes, "COHETE")
    loadSection(data.tanques, "TANQUE")
    loadSection(data.misiles, "MISIL")
    loadSection(data.misiles_guiados, "MISILG")
    loadSection(data.misc, "MISCELANEO")

    for liquidName, amount in pairs(data.liquids or {}) do
        addLiquid(liquidName, amount)
    end

    local msg = "Suministros entregados en " .. airport .. ":\n\n"

    if data.avion then
        msg = msg .. (data.nombreAvion or "Avion") .. " x" .. tostring(totalAviones)
    else
        msg = msg .. (data.nombreAvion or "Suministro")
    end

    if #resumen > 0 then
        msg = msg .. "\n" .. table.concat(resumen, "\n")
    end

    outCoalition(side, msg, 30)
    return true, msg
end

-- ============================================================================
-- SPAWN DINAMICO CON MIST.DYNADD
-- ============================================================================
local function makeEditorOptionTask(number, optionName, optionValue)
    return {
        enabled = true,
        auto = false,
        id = "WrappedAction",
        number = number,
        params = {
            action = {
                id = "Option",
                params = {
                    name = optionName,
                    value = optionValue,
                }
            }
        }
    }
end

local function makeEditorHeliWp1Tasks()
    if not AR.CONFIG.USE_EDITOR_HELI_OPTIONS then
        return {}
    end

    return {
        makeEditorOptionTask(1, 0, 0),
        makeEditorOptionTask(2, 1, 0),
        makeEditorOptionTask(3, 4, 3),
        makeEditorOptionTask(4, 32, true),
    }
end

local function makeRoutePoint(x, z, altMSL, speed, pointType, action, airdromeId, tasks)
    local p = {
        x = tonumber(x) or 0,
        y = tonumber(z) or 0,

        -- BARO + MSL real. No mezclar RADIO con alt=0.
        alt = tonumber(altMSL) or 0,
        alt_type = "BARO",

        speed = tonumber(speed) or 42,
        speed_locked = true,

        type = pointType,
        action = action,

        ETA = 0,
        ETA_locked = false,
        formation_template = "",
        properties = {
            addopt = {},
        },

        task = {
            id = "ComboTask",
            params = {
                tasks = tasks or {},
            }
        }
    }

    if airdromeId then
        p.airdromeId = airdromeId
    end

    return p
end

local function makePayloadForHeli(_transportType)
    return {
        pylons = {},
        fuel = 100,
        flare = 60,
        chaff = 60,
        gun = 100,
    }
end

local function makeCallsignForCoalition(side)
    if side == 2 then
        return {
            [1] = 2,
            [2] = 1,
            [3] = 1,
            name = "Springfield11",
        }
    end

    return {
        [1] = 1,
        [2] = 1,
        [3] = 1,
        name = "Enfield11",
    }
end

local function buildDynamicGroupName(cfg, airport)
    AR.STATE.nextSpawnId = (AR.STATE.nextSpawnId or 0) + 1
    return "HDEV_AUTO_" ..
        tostring(cfg.key or cfg.coalition) .. "_" ..
        safeName(airport) .. "_" ..
        tostring(math.floor(timer.getTime() * 10)) .. "_" ..
        tostring(AR.STATE.nextSpawnId)
end

local function applyPostSpawnControllerMission(groupName, routePoints)
    if not AR.CONFIG.FORCE_CONTROLLER_MISSION_AFTER_SPAWN then
        return
    end

    local args = {
        groupName = groupName,
        routePoints = deepCopy(routePoints),
        attempt = 0,
    }

    timer.scheduleFunction(function(data)
        data.attempt = (data.attempt or 0) + 1

        local grp = Group.getByName(data.groupName)
        if not grp then
            if data.attempt < (AR.CONFIG.FORCE_CONTROLLER_RETRIES or 3) then
                return timer.getTime() + (AR.CONFIG.FORCE_CONTROLLER_RETRY_INTERVAL or 1)
            end

            exportDebugLua(data.groupName .. "_CONTROLLER_FORCE_FAILED", {
                reason = "Group.getByName nil",
                attempt = data.attempt,
            })
            return nil
        end

        local okExist, exists = pcall(function()
            return grp:isExist()
        end)

        if not okExist or not exists then
            if data.attempt < (AR.CONFIG.FORCE_CONTROLLER_RETRIES or 3) then
                return timer.getTime() + (AR.CONFIG.FORCE_CONTROLLER_RETRY_INTERVAL or 1)
            end

            exportDebugLua(data.groupName .. "_CONTROLLER_FORCE_FAILED", {
                reason = "group no existe",
                attempt = data.attempt,
            })
            return nil
        end

        local okCtrl, ctrl = pcall(function()
            return grp:getController()
        end)

        if not okCtrl or not ctrl then
            if data.attempt < (AR.CONFIG.FORCE_CONTROLLER_RETRIES or 3) then
                return timer.getTime() + (AR.CONFIG.FORCE_CONTROLLER_RETRY_INTERVAL or 1)
            end

            exportDebugLua(data.groupName .. "_CONTROLLER_FORCE_FAILED", {
                reason = "controller nil",
                attempt = data.attempt,
            })
            return nil
        end

        local routeForController = deepCopy(data.routePoints or {})

        -- Muy importante:
        -- Al forzar setTask 1 segundo despues, el heli ya se movio un poco.
        -- Si dejamos WP1 exactamente en el punto de spawn original, puede intentar devolverse.
        -- Por eso el WP1 se mueve a la posicion actual de la unidad, pero conserva sus tareas/opciones.
        local unit = grp:getUnit(1)
        if unit and routeForController[1] then
            local okPoint, p = pcall(function()
                return unit:getPoint()
            end)

            if okPoint and p then
                routeForController[1].x = p.x
                routeForController[1].y = p.z
                routeForController[1].alt = p.y
                routeForController[1].alt_type = "BARO"
            end
        end

        -- Opciones del controlador. No sustituyen la ruta; son refuerzo.
        pcall(function() ctrl:setOption(0, 0) end)
        pcall(function() ctrl:setOption(1, 0) end)
        pcall(function() ctrl:setOption(4, 3) end)
        pcall(function() ctrl:setOption(32, true) end)

        local missionTask = {
            id = "Mission",
            params = {
                route = {
                    points = routeForController
                }
            }
        }

        local okTask, errTask = pcall(function()
            ctrl:setTask(missionTask)
        end)

        exportDebugLua(data.groupName .. "_CONTROLLER_SET_TASK", {
            okTask = okTask,
            errTask = errTask,
            attempt = data.attempt,
            missionTask = missionTask,
            live = inspectLiveGroup(data.groupName),
        })

        if not okTask and data.attempt < (AR.CONFIG.FORCE_CONTROLLER_RETRIES or 3) then
            return timer.getTime() + (AR.CONFIG.FORCE_CONTROLLER_RETRY_INTERVAL or 1)
        end

        return nil
    end, args, timer.getTime() + (AR.CONFIG.FORCE_CONTROLLER_DELAY or 1))
end

local function createDynamicHelicopter(cfg, airport, subKey, data, purchaseControl)
    if not mist or not mist.dynAdd then
        return false, "MIST/mist.dynAdd no esta cargado"
    end

    local destination = point2D(data.destinationPoint or data.landingPoint or (cfg.coordinates and cfg.coordinates[airport]))
    local origin = point2D(data.originPoint or data.spawnPoint or data.origen or offsetPointFrom(destination, AR.CONFIG.SPAWN_OFFSET_NM, AR.CONFIG.SPAWN_DIRECTION))
    local speed = tonumber(data.velocidad or cfg.defaultSpeed or AR.CONFIG.DEFAULT_SPEED) or 42
    local transportType = data.transportType or (cfg.coalition == 2 and AR.CONFIG.BLUE_TRANSPORT_TYPE or AR.CONFIG.RED_TRANSPORT_TYPE)
    local countryId = data.countryId or (cfg.coalition == 2 and AR.CONFIG.BLUE_COUNTRY_ID or AR.CONFIG.RED_COUNTRY_ID)
    local now = timer.getTime()
    local groupName = buildDynamicGroupName(cfg, airport)
    local unitName = groupName .. "_UNIT_1"
    local heading = getHeading(origin, destination)

    local originGroundMSL = getTerrainAltMSL(origin)
    local destinationGroundMSL = getTerrainAltMSL(destination)
    local spawnAltMSL = originGroundMSL + (tonumber(AR.CONFIG.SPAWN_ALT_AGL) or 250)
    local landingAltMSL = destinationGroundMSL

    local routePoints = {
        makeRoutePoint(
            origin.x,
            origin.z,
            spawnAltMSL,
            speed,
            "Turning Point",
            "Turning Point",
            nil,
            makeEditorHeliWp1Tasks()
        ),

        -- IMPORTANTE: se conserva airdromeId.
        -- El debug del Mission Editor ya mostro que airdromeId no impide aterrizaje vertical.
        makeRoutePoint(
            destination.x,
            destination.z,
            landingAltMSL,
            speed,
            "Land",
            "Landing",
            data.airbaseId,
            {}
        ),
    }

    local groupData = {
        country = countryId,
        category = "helicopter",
        name = groupName,
        task = "Transport",
        hidden = false,
        visible = false,
        uncontrolled = false,
        lateActivation = false,
        communication = true,
        radioSet = false,
        frequency = 127.5,
        modulation = 0,

        route = {
            points = routePoints
        },

        units = {
            {
                type = transportType,
                name = unitName,
                skill = "Excellent",
                x = origin.x,
                y = origin.z,
                alt = spawnAltMSL,
                alt_type = "BARO",
                speed = speed,

                -- Heading del archivo base original; no decide aterrizaje vertical.
                heading = heading,
                psi = -heading,

                payload = makePayloadForHeli(transportType),
                callsign = makeCallsignForCoalition(cfg.coalition),
                onboard_num = "010",
            }
        },

        __HDEV_DEBUG = {
            version = 13,
            airport = airport,
            subKey = subKey,
            purchaseControl = purchaseControl,
            origin = deepCopy(origin),
            destination = deepCopy(destination),
            originGroundMSL = originGroundMSL,
            destinationGroundMSL = destinationGroundMSL,
            spawnAltMSL = spawnAltMSL,
            landingAltMSL = landingAltMSL,
            heading = heading,
            transportType = transportType,
            countryId = countryId,
            airbaseId = data.airbaseId,
        }
    }

    exportDebugLua(groupName .. "_BEFORE_DYNADD", groupData)

    local okSpawn, spawnResult = pcall(function()
        return mist.dynAdd(groupData)
    end)

    if not okSpawn or not spawnResult then
        exportDebugLua(groupName .. "_DYNADD_ERROR", {
            okSpawn = okSpawn,
            spawnResult = spawnResult,
            groupData = groupData,
        })
        return false, spawnResult or "mist.dynAdd devolvio false"
    end

    local spawnedName = groupName
    if type(spawnResult) == "table" and spawnResult.name then
        spawnedName = spawnResult.name
    end

    cfg.state.deliveries[spawnedName] = {
        autoRoute = true,
        destino = airport,
        inventario = subKey,
        plantilla = data.template,
        entregado = false,
        destruido = false,
        altMax = 0,
        createdAt = now,

        airportName = airport,
        destinationAirbaseName = data.destinationAirbaseName or airport,
        originPoint = deepCopy(origin),
        spawnPoint = deepCopy(origin),
        destinationPoint = deepCopy(destination),
        landingPoint = deepCopy(destination),
        originGroundMSL = originGroundMSL,
        destinationGroundMSL = destinationGroundMSL,
        spawnAltMSL = spawnAltMSL,
        landingAltMSL = landingAltMSL,
        destinationCoalitionAtPurchase = purchaseControl,
        transportType = transportType,
        coalition = cfg.coalition,
        countryId = countryId,
        airbaseId = data.airbaseId,
    }

    cfg.state.cooldowns[airport] = timer.getTime() + (cfg.cooldownSeconds or AR.CONFIG.COOLDOWN_SECONDS or 120)

    -- VERSION 13:
    -- Esta es la correccion importante. No basta con crear el grupo.
    -- Se fuerza la mision/ruta real en el Controller despues del nacimiento.
    applyPostSpawnControllerMission(spawnedName, routePoints)

    return true, spawnedName, origin, destination
end

local function getFinalCost(cfg, airport, subKey)
    local base = tipoAviones and tipoAviones[subKey] and tipoAviones[subKey].costo or 0
    local recargo = cfg.recargos and cfg.recargos[airport] or 1
    return math.floor(base * recargo)
end

function AR.requestDelivery(key, airport, subKey)
    local Marketplace = HDEV_Marketplace
    local cfg = Marketplace and Marketplace.coalitions and Marketplace.coalitions[key]
    if not cfg then
        return false
    end

    local data = cfg.plantillas and cfg.plantillas[airport]
    if not data then
        outCoalition(cfg.coalition, "No existe ruta logistica para " .. tostring(airport), 10)
        return false
    end

    local allowed, currentControl, controlSource = canCoalitionBuy(cfg, airport, data)
    if not allowed then
        outCoalition(
            cfg.coalition,
            "No puedes comprar hacia " .. tostring(airport) .. ". Control actual: " .. getCoalitionName(currentControl) .. ". Fuente: " .. tostring(controlSource),
            10
        )
        return false
    end

    local bloqueo = cfg.state.cooldowns[airport]
    if bloqueo and timer.getTime() < bloqueo then
        local restante = math.max(0, math.floor(bloqueo - timer.getTime()))
        outCoalition(cfg.coalition, "Debes esperar " .. restante .. " segundos antes de volver a comprar en " .. airport, 8)
        return false
    end

    local inventoryData = tipoAviones and tipoAviones[subKey]
    if not inventoryData then
        outCoalition(cfg.coalition, "No existe inventario para la clave: " .. tostring(subKey), 8)
        return false
    end

    local econ = getEconomy()
    if not econ or not econ.spend then
        outCoalition(cfg.coalition, "Sistema economico no disponible.", 8)
        return false
    end

    local cost = getFinalCost(cfg, airport, subKey)
    local okSpend = econ.spend(cfg.coalition, cost, "compra marketplace auto " .. airport .. " " .. subKey)
    if not okSpend then
        outCoalition(cfg.coalition, "No tienes suficientes dolares. Requiere: " .. formatMoney(cost), 10)
        return false
    end

    local okSpawn, spawnOrErr, origin, destination = createDynamicHelicopter(cfg, airport, subKey, data, currentControl)
    if not okSpawn then
        if econ.add then
            econ.add(cfg.coalition, cost, "reembolso error dynAdd " .. airport)
        end
        outCoalition(cfg.coalition, "Fallo al crear la ruta hacia " .. airport .. ". El dinero fue reembolsado.", 10)
        warn("mist.dynAdd fallo en " .. tostring(airport) .. ": " .. tostring(spawnOrErr))
        return false
    end

    local distance = distance2D(origin, destination)
    local speed = tonumber(data.velocidad or cfg.defaultSpeed or AR.CONFIG.DEFAULT_SPEED) or 42
    local timeMultiplier = cfg.timeMultipliers and cfg.timeMultipliers[airport] or 1
    local eta = math.floor((distance / math.max(speed, 1)) * timeMultiplier)
    local minutos = math.floor(eta / 60)
    local segundos = eta % 60

    outCoalition(cfg.coalition, "Compra confirmada. Enviando " .. tostring(data.transportType or "helicoptero") .. " a " .. airport, 15)
    outCoalition(cfg.coalition, "Ruta asignada: origen automatico -> " .. airport .. " | Llegada estimada: " .. minutos .. " min " .. segundos .. " seg", 15)

    log("Compra OK " .. tostring(key) .. " -> " .. tostring(airport) .. " | grupo=" .. tostring(spawnOrErr) .. " | subKey=" .. tostring(subKey))
    return true
end

-- ============================================================================
-- MONITOR DE ENTREGA CON VALIDACION POR DESTINO ESPECIFICO
-- ============================================================================
local function groupExistsByName(groupName)
    if not groupName then return nil end
    local grp = Group.getByName(groupName)
    if not grp then return nil end
    local ok, exists = pcall(function() return grp:isExist() end)
    if ok and exists then return grp end
    return nil
end

local function getUnit1(groupName)
    local grp = groupExistsByName(groupName)
    if not grp then return nil, nil end
    local unit = grp:getUnit(1)
    if not unit then return grp, nil end
    return grp, unit
end

function AR.monitorTick(key, now)
    local Marketplace = HDEV_Marketplace
    local cfg = Marketplace and Marketplace.coalitions and Marketplace.coalitions[key]
    if not cfg then
        return nil
    end

    now = now or timer.getTime()

    for groupName, info in pairs(cfg.state.deliveries or {}) do
        if not info.entregado and not info.destruido then
            local grp, unit = getUnit1(groupName)
            if grp and unit then
                local point = unit:getPoint()
                local terrain = land.getHeight({ x = point.x, y = point.z })
                local agl = point.y - terrain
                info.altMax = math.max(info.altMax or 0, agl)

                local velocity = unit:getVelocity()
                local speed = math.sqrt((velocity.x or 0)^2 + (velocity.z or 0)^2)

                if info.autoRoute then
                    local destPoint = info.destinationPoint or info.landingPoint
                    local distToDest = distance2D(point, destPoint)
                    info.lastDistanceToDestination = distToDest
                    info.lastAgl = agl
                    info.lastSpeed = speed

                    local minAltOk = (info.altMax or 0) >= (cfg.deliveryMinAlt or AR.CONFIG.DELIVERY_MIN_ALT or 80)
                    local distanceOk = distToDest <= (cfg.deliveryRadius or AR.CONFIG.DELIVERY_RADIUS or 3000)
                    local aglOk = agl <= (cfg.landingAglMax or AR.CONFIG.LANDING_AGL_MAX or 30)
                    local speedOk = speed <= (cfg.deliveryStopSpeed or AR.CONFIG.DELIVERY_STOP_SPEED or 2)

                    if minAltOk and distanceOk and aglOk and speedOk then
                        local inventoryData = tipoAviones[info.inventario]
                        if inventoryData then
                            local okApply, errApply = applyInventoryToAirbase(cfg.coalition, info.destinationAirbaseName or info.destino, inventoryData)
                            if not okApply then
                                warn(tostring(errApply))
                                outCoalition(cfg.coalition, "La ruta llego, pero fallo la entrega en warehouse: " .. tostring(errApply), 12)
                            end
                        end
                        info.entregado = true

                        timer.scheduleFunction(function()
                            local g = groupExistsByName(groupName)
                            if g then g:destroy() end
                        end, nil, timer.getTime() + (cfg.deliveryDestroyDelay or AR.CONFIG.DELIVERY_DESTROY_DELAY or 20))
                    end
                else
                    -- Compatibilidad con entregas antiguas si alguna quedo viva.
                    if (info.altMax or 0) >= (cfg.deliveryMinAlt or 100) and speed < (cfg.deliveryStopSpeed or 1) then
                        local inventoryData = tipoAviones[info.inventario]
                        if inventoryData then
                            applyInventoryToAirbase(cfg.coalition, info.destino, inventoryData)
                        end
                        info.entregado = true

                        timer.scheduleFunction(function()
                            local g = groupExistsByName(groupName)
                            if g then g:destroy() end
                        end, nil, timer.getTime() + (cfg.deliveryDestroyDelay or 20))
                    end
                end
            else
                info.destruido = true
            end
        end
    end

    return now + (cfg.monitorInterval or AR.CONFIG.MONITOR_INTERVAL or 5)
end

function AR.showRoutes(key)
    local Marketplace = HDEV_Marketplace
    local cfg = Marketplace and Marketplace.coalitions and Marketplace.coalitions[key]
    if not cfg then return end

    local msg = "Rutas activas Logistica:\n"
    local hay = false

    for groupName, info in pairs(cfg.state.deliveries or {}) do
        if not info.entregado and not info.destruido then
            local grp, unit = getUnit1(groupName)
            if grp and unit then
                local visibleName = nombresSubvariantes and nombresSubvariantes[info.inventario] or info.inventario
                local p = unit:getPoint()
                local dist = info.destinationPoint and distance2D(p, info.destinationPoint) or nil
                msg = msg .. "Ruta " .. groupName .. " (" .. tostring(visibleName) .. ") va hacia " .. tostring(info.destino)
                if dist then
                    msg = msg .. " | Dist: " .. tostring(math.floor(dist / 1000)) .. " km"
                end
                msg = msg .. "\n"
                hay = true
            else
                info.destruido = true
            end
        end
    end

    if not hay then
        msg = msg .. "\n(No hay rutas activas en este momento)"
    end

    outCoalition(cfg.coalition, msg, 30)
end

-- ============================================================================
-- REGISTRO DE COALICIONES / INSTALACION
-- ============================================================================
function AR.registerMarketplaceCoalitions()
    local Marketplace = HDEV_Marketplace
    if not Marketplace or not Marketplace.registerCoalition then
        return false
    end

    Marketplace.registerCoalition("BLUE", {
        coalition = 2,
        allowedFlagValue = 2,
        plantillas = plantillasLogisticaB,
        recargos = recargoAeropuertoB,
        coordinates = coordenadasAerodromosB,
        timeMultipliers = multiplicadorTiempoB,
        defaultSpeed = AR.CONFIG.DEFAULT_SPEED,
        itemsPerPage = AR.CONFIG.ITEMS_PER_PAGE,
        deliveryDestroyDelay = AR.CONFIG.DELIVERY_DESTROY_DELAY,
        monitorInterval = AR.CONFIG.MONITOR_INTERVAL,
        cooldownSeconds = AR.CONFIG.COOLDOWN_SECONDS,
        deliveryMinAlt = AR.CONFIG.DELIVERY_MIN_ALT,
        deliveryStopSpeed = AR.CONFIG.DELIVERY_STOP_SPEED,
        deliveryRadius = AR.CONFIG.DELIVERY_RADIUS,
        landingAglMax = AR.CONFIG.LANDING_AGL_MAX,
        menuName = AR.CONFIG.MENU_NAME,
        routeZoneName = AR.CONFIG.ROUTE_ZONE_NAME,
    })

    Marketplace.registerCoalition("RED", {
        coalition = 1,
        allowedFlagValue = 1,
        plantillas = plantillasLogisticaR,
        recargos = recargoAeropuertoR,
        coordinates = coordenadasAerodromosR,
        timeMultipliers = multiplicadorTiempoR,
        defaultSpeed = AR.CONFIG.DEFAULT_SPEED,
        itemsPerPage = AR.CONFIG.ITEMS_PER_PAGE,
        deliveryDestroyDelay = AR.CONFIG.DELIVERY_DESTROY_DELAY,
        monitorInterval = AR.CONFIG.MONITOR_INTERVAL,
        cooldownSeconds = AR.CONFIG.COOLDOWN_SECONDS,
        deliveryMinAlt = AR.CONFIG.DELIVERY_MIN_ALT,
        deliveryStopSpeed = AR.CONFIG.DELIVERY_STOP_SPEED,
        deliveryRadius = AR.CONFIG.DELIVERY_RADIUS,
        landingAglMax = AR.CONFIG.LANDING_AGL_MAX,
        menuName = AR.CONFIG.MENU_NAME,
        routeZoneName = AR.CONFIG.ROUTE_ZONE_NAME,
    })

    if Marketplace.startMonitor then
        Marketplace.startMonitor("BLUE")
        Marketplace.startMonitor("RED")
    end

    return true
end

function AR.install()
    if AR.STATE.installed then
        return true
    end

    AR.STATE.installAttempts = (AR.STATE.installAttempts or 0) + 1

    if not mist or not mist.dynAdd then
        warn("Esperando MIST/mist.dynAdd...")
        return false
    end

    if not HDEV_Marketplace or not HDEV_Marketplace.registerCoalition then
        warn("Esperando HDEV_MarketplaceCore_1_1.lua...")
        return false
    end

    if not world or not world.getAirbases then
        warn("Esperando world.getAirbases...")
        return false
    end

    AR.detectAirports()
    AR.rebuildGlobalRouteTables()

    AR.STATE.originalRequestDelivery = HDEV_Marketplace.requestDelivery
    AR.STATE.originalMonitorTick = HDEV_Marketplace.monitorTick
    AR.STATE.originalShowRoutes = HDEV_Marketplace.showRoutes

    HDEV_Marketplace.requestDelivery = AR.requestDelivery
    HDEV_Marketplace.monitorTick = AR.monitorTick
    HDEV_Marketplace.showRoutes = AR.showRoutes

    AR.registerMarketplaceCoalitions()

    AR.STATE.installed = true
    log("Instalado VERSION 13. Base original + dynAdd + airdromeId conservado + Controller.setTask forzado.")
    return true
end

local function installRetry()
    if AR.install() then
        return nil
    end

    if (AR.STATE.installAttempts or 0) >= (AR.CONFIG.INSTALL_RETRIES or 20) then
        trigger.action.outText("ERROR: HDEV_MarketplaceAutoRoutes no pudo instalarse. Revisa orden de carga.", 15)
        warn("No pudo instalarse despues de " .. tostring(AR.STATE.installAttempts) .. " intentos.")
        return nil
    end

    return timer.getTime() + (AR.CONFIG.INSTALL_RETRY_SECONDS or 1)
end

-- Instalacion inmediata. Si falta alguna dependencia, reintenta por scheduler.
if not AR.install() then
    timer.scheduleFunction(function()
        return installRetry()
    end, nil, timer.getTime() + (AR.CONFIG.INSTALL_RETRY_SECONDS or 1))
end

return HDEV_MarketplaceAutoRoutes
