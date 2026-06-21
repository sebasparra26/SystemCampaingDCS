-- ============================================================================
-- HDEV_MarketplaceDebugMarks.lua
-- VERSION: 1
--
-- Script separado de DEBUG para comprar por etiquetas/marks F10.
--
-- NO toca:
-- - HDEV_MarketplaceCore
-- - HDEV_MarketplaceMenuF10
-- - HDEV_MarketplaceAutoRoutes
-- - Economia
-- - StockWarehouse
--
-- Usa la funcion real:
-- HDEV_Marketplace.requestDelivery("BLUE" / "RED", airportName, subKey)
--
-- COMANDOS EN ETIQUETA F10:
--
-- 1) Comprar a todos los aeropuertos controlados por la coalicion:
--    mpbuy BLUE FA-18C-1
--    mpbuy RED JETFUEL-100T
--
-- 2) Comprar a todos los aeropuertos configurados, aunque no sean de esa coalicion:
--    mpbuy BLUE FA-18C-1 ALL
--    mpbuy RED JETFUEL-100T ALL
--
-- NOTA:
-- Aunque uses ALL, Marketplace igual puede rechazar la compra si la validacion
-- de control no permite comprar en ese aeropuerto.
--
-- 3) Comprar a un aeropuerto especifico:
--    mpbuy BLUE FA-18C-1 AIRPORT "Bodo"
--    mpbuy RED JETFUEL-100T AIRPORT "Banak"
--
-- 4) Comprar a aeropuertos cerca del punto donde pusiste la etiqueta:
--    mpbuy BLUE FA-18C-1 NEAR 20000
--    mpbuy RED JETFUEL-100T NEAR 30000
--
-- 5) Ver lista sin comprar:
--    mpbuy BLUE FA-18C-1 LIST
--    mpbuy BLUE FA-18C-1 ALL LIST
--
-- 6) Buscar claves:
--    mpkeys F-16
--    mpkeys JETFUEL
--    mpkeys FOX
--
-- 7) Ayuda:
--    mphelp
--
-- IMPORTANTE:
-- - Este script debe cargarse despues de HDEV_MarketplaceAutoRoutes.lua.
-- - Por defecto requiere que AutoRoutes ya este instalado.
-- - Para debug masivo, las compras se hacen con delay para no spawnear todo
--   en el mismo frame.
-- ============================================================================

HDEV_MarketplaceDebugMarks = HDEV_MarketplaceDebugMarks or {}
local DBG = HDEV_MarketplaceDebugMarks

-- ============================================================================
-- CONFIGURACION EDITABLE
-- ============================================================================
DBG.CONFIG = DBG.CONFIG or {
    ENABLED = true,
    DEBUG = true,

    -- Requiere que HDEV_MarketplaceAutoRoutes ya este instalado.
    -- Recomendado true para evitar usar requestDelivery viejo del core.
    REQUIRE_AUTOROUTES = true,

    -- Comandos principales aceptados en etiquetas F10
    BUY_PREFIXES = {
        ["mpbuy"] = true,
        ["comprar"] = true,
        ["buy"] = true,
    },

    HELP_PREFIXES = {
        ["mphelp"] = true,
        ["ayudamarket"] = true,
        ["markethelp"] = true,
    },

    KEYS_PREFIXES = {
        ["mpkeys"] = true,
        ["claves"] = true,
        ["marketkeys"] = true,
    },

    QUEUE_PREFIXES = {
        ["mpqueue"] = true,
        ["cola"] = true,
    },

    CLEAR_PREFIXES = {
        ["mpclear"] = true,
        ["limpiarcola"] = true,
    },

    -- Si no pones ALL / AIRPORT / NEAR, compra solo a aeropuertos
    -- controlados por la coalicion elegida.
    DEFAULT_SCOPE = "OWNED", -- OWNED | ALL

    -- Delay entre compras masivas.
    BUY_INTERVAL_SECONDS = 1.0,

    -- 0 = sin limite.
    -- Si quieres probar poco a poco, pon por ejemplo 5.
    MAX_BULK_PER_COMMAND = 0,

    -- Si true, borra cooldown antes de cada compra.
    -- Para debug puro puedes poner true.
    -- Para probar flujo real, dejalo false.
    IGNORE_COOLDOWNS = false,

    -- Si true, remueve la marca F10 despues de procesarla.
    REMOVE_MARK_AFTER_PROCESS = true,

    -- Si true, escucha tambien cambios de marca, no solo marca nueva.
    ACCEPT_MARK_CHANGE = true,

    -- Radio por defecto para comando NEAR si no das numero.
    DEFAULT_NEAR_RADIUS = 20000,

    -- Mensajes
    MESSAGE_TIME = 15,
    LONG_MESSAGE_TIME = 30,

    -- Reintentos de instalacion
    INSTALL_RETRIES = 60,
    INSTALL_RETRY_SECONDS = 1,
}

DBG.STATE = DBG.STATE or {
    installed = false,
    installAttempts = 0,
    processedMarks = {},
    activeJob = nil,
    pendingJobs = {},
    jobCounter = 0,
    eventHandler = nil,
}

-- ============================================================================
-- LOG / OUTPUT
-- ============================================================================
local function log(msg)
    env.info("[HDEV_MARKET_DEBUG_MARKS] " .. tostring(msg))
    if DBG.CONFIG.DEBUG then
        trigger.action.outText("[MARKET DEBUG] " .. tostring(msg), 8)
    end
end

local function warn(msg)
    env.info("[HDEV_MARKET_DEBUG_MARKS] " .. tostring(msg))
end

local function outAll(msg, seconds)
    trigger.action.outText(tostring(msg), seconds or DBG.CONFIG.MESSAGE_TIME or 10)
end

local function outCoalition(side, msg, seconds)
    if side == 1 or side == 2 then
        trigger.action.outTextForCoalition(side, tostring(msg), seconds or DBG.CONFIG.MESSAGE_TIME or 10)
    else
        outAll(msg, seconds)
    end
end

local function safeRemoveMark(idx)
    if not DBG.CONFIG.REMOVE_MARK_AFTER_PROCESS then
        return
    end

    if idx == nil then
        return
    end

    pcall(function()
        trigger.action.removeMark(idx)
    end)
end

-- ============================================================================
-- UTILS
-- ============================================================================
local function trim(s)
    s = tostring(s or "")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")
    return s
end

local function lower(s)
    return tostring(s or ""):lower()
end

local function upper(s)
    return tostring(s or ""):upper()
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

local function shallowCopyList(list)
    local out = {}
    for i = 1, #(list or {}) do
        out[#out + 1] = list[i]
    end
    return out
end

local function joinFrom(tokens, startIndex, sep)
    local parts = {}
    for i = startIndex, #(tokens or {}) do
        parts[#parts + 1] = tokens[i]
    end
    return table.concat(parts, sep or " ")
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
        return HDEV_Economy.formatMoney(tonumber(value) or 0)
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

local function getMarketplace()
    return HDEV_Marketplace
end

local function getSideFromKey(key)
    key = upper(key)

    if key == "BLUE" or key == "AZUL" or key == "2" then
        return "BLUE", 2
    end

    if key == "RED" or key == "ROJO" or key == "1" then
        return "RED", 1
    end

    return nil, nil
end

local function sideName(side)
    if side == 2 then return "BLUE" end
    if side == 1 then return "RED" end
    return "UNKNOWN"
end

local function tokenize(text)
    local tokens = {}
    local s = tostring(text or "")
    local i = 1
    local len = #s

    while i <= len do
        while i <= len and s:sub(i, i):match("%s") do
            i = i + 1
        end

        if i > len then
            break
        end

        local c = s:sub(i, i)

        if c == "\"" or c == "'" then
            local quote = c
            i = i + 1
            local start = i

            while i <= len and s:sub(i, i) ~= quote do
                i = i + 1
            end

            tokens[#tokens + 1] = s:sub(start, i - 1)

            if i <= len and s:sub(i, i) == quote then
                i = i + 1
            end
        else
            local start = i

            while i <= len and not s:sub(i, i):match("%s") do
                i = i + 1
            end

            tokens[#tokens + 1] = s:sub(start, i - 1)
        end
    end

    return tokens
end

local function isToken(value, ...)
    local v = lower(value)
    local args = {...}

    for i = 1, #args do
        if v == lower(args[i]) then
            return true
        end
    end

    return false
end

-- ============================================================================
-- RESOLUCION DE CLAVES
-- ============================================================================
local function resolveSubKey(rawKey)
    rawKey = trim(rawKey)

    if rawKey == "" then
        return nil, "clave vacia"
    end

    if tipoAviones and tipoAviones[rawKey] then
        return rawKey, nil
    end

    local rawUpper = upper(rawKey)

    if type(tipoAviones) == "table" then
        for key, _ in pairs(tipoAviones) do
            if upper(key) == rawUpper then
                return key, nil
            end
        end
    end

    if type(nombresSubvariantes) == "table" then
        for key, visibleName in pairs(nombresSubvariantes) do
            if upper(key) == rawUpper or upper(visibleName) == rawUpper then
                return key, nil
            end
        end
    end

    return nil, "No existe clave en tipoAviones/nombresSubvariantes: " .. tostring(rawKey)
end

local function getSubKeyDisplay(subKey)
    if nombresSubvariantes and nombresSubvariantes[subKey] then
        return nombresSubvariantes[subKey] .. " [" .. tostring(subKey) .. "]"
    end

    if tipoAviones and tipoAviones[subKey] and tipoAviones[subKey].nombreAvion then
        return tostring(tipoAviones[subKey].nombreAvion) .. " [" .. tostring(subKey) .. "]"
    end

    return tostring(subKey)
end

local function searchKeys(term, limit)
    term = upper(term or "")
    limit = tonumber(limit) or 25

    local results = {}
    local seen = {}

    local function add(key, label)
        if not key or seen[key] then return end

        local haystack = upper(tostring(key) .. " " .. tostring(label or ""))
        if term == "" or haystack:find(term, 1, true) then
            seen[key] = true
            results[#results + 1] = {
                key = key,
                label = label or key,
            }
        end
    end

    if type(nombresSubvariantes) == "table" then
        for key, label in pairs(nombresSubvariantes) do
            add(key, label)
        end
    end

    if type(tipoAviones) == "table" then
        for key, data in pairs(tipoAviones) do
            local label = data and data.nombreAvion or key
            add(key, label)
        end
    end

    table.sort(results, function(a, b)
        return tostring(a.key) < tostring(b.key)
    end)

    local out = {}
    for i = 1, math.min(#results, limit) do
        out[#out + 1] = results[i]
    end

    return out, #results
end

-- ============================================================================
-- AEROPUERTOS / CONTROL
-- ============================================================================
local function getCfg(key)
    local Marketplace = getMarketplace()
    if not Marketplace or not Marketplace.coalitions then
        return nil
    end

    return Marketplace.coalitions[key]
end

local function buildCoalitionAirbaseSet(side)
    local set = {}

    local ok, bases = pcall(function()
        return coalition.getAirbases(side)
    end)

    if ok and type(bases) == "table" then
        for _, base in ipairs(bases) do
            local okName, name = pcall(function()
                return base:getName()
            end)

            if okName and name then
                set[name] = true
            end
        end
    end

    return set
end

local function getAirportControl(airportName)
    if type(controlAeropuertos) == "table" and controlAeropuertos[airportName] ~= nil then
        return tonumber(controlAeropuertos[airportName]) or 0, "controlAeropuertos"
    end

    if type(coalicionPorBase) == "table" and coalicionPorBase[airportName] ~= nil then
        return tonumber(coalicionPorBase[airportName]) or 0, "coalicionPorBase"
    end

    if type(estadoBanderasAeropuertos) == "table" then
        local info = estadoBanderasAeropuertos[airportName]
        if type(info) == "table" then
            if info.valor ~= nil then
                return tonumber(info.valor) or 0, "estadoBanderas.valor"
            end

            if info.bandera ~= nil then
                local ok, value = pcall(function()
                    return trigger.misc.getUserFlag(info.bandera)
                end)

                if ok then
                    return tonumber(value) or 0, "estadoBanderas.bandera"
                end
            end
        end
    end

    local blueSet = buildCoalitionAirbaseSet(2)
    if blueSet[airportName] then
        return 2, "coalition.getAirbases"
    end

    local redSet = buildCoalitionAirbaseSet(1)
    if redSet[airportName] then
        return 1, "coalition.getAirbases"
    end

    return 0, "unknown"
end

local function getAirportPoint(cfg, airportName)
    if cfg and cfg.coordinates and cfg.coordinates[airportName] then
        local p = cfg.coordinates[airportName]
        return {
            x = tonumber(p.x) or 0,
            y = tonumber(p.y) or 0,
            z = tonumber(p.z or p.y) or 0,
        }
    end

    local ab = Airbase.getByName(airportName)
    if ab then
        local ok, p = pcall(function()
            return ab:getPoint()
        end)

        if ok and p then
            return {
                x = tonumber(p.x) or 0,
                y = tonumber(p.y) or 0,
                z = tonumber(p.z or p.y) or 0,
            }
        end
    end

    return nil
end

local function getFinalCost(cfg, airport, subKey)
    local base = tipoAviones and tipoAviones[subKey] and tipoAviones[subKey].costo or 0
    local recargo = cfg and cfg.recargos and cfg.recargos[airport] or 1

    return math.floor((tonumber(base) or 0) * (tonumber(recargo) or 1))
end

local function getAllConfiguredAirports(cfg)
    local list = {}

    if not cfg or type(cfg.plantillas) ~= "table" then
        return list
    end

    for airport, _ in pairs(cfg.plantillas) do
        list[#list + 1] = airport
    end

    table.sort(list, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return list
end

local function filterOwnedAirports(cfg, key)
    local all = getAllConfiguredAirports(cfg)
    local out = {}
    local expectedSide = cfg and cfg.coalition or nil

    for _, airport in ipairs(all) do
        local control = getAirportControl(airport)
        if control == expectedSide then
            out[#out + 1] = airport
        end
    end

    return out
end

local function filterNearAirports(cfg, key, markPoint, radius, onlyOwned)
    local all = onlyOwned and filterOwnedAirports(cfg, key) or getAllConfiguredAirports(cfg)
    local out = {}
    radius = tonumber(radius) or DBG.CONFIG.DEFAULT_NEAR_RADIUS or 20000

    for _, airport in ipairs(all) do
        local p = getAirportPoint(cfg, airport)
        if p and markPoint then
            local dist = distance2D(markPoint, p)
            if dist <= radius then
                out[#out + 1] = airport
            end
        end
    end

    table.sort(out, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return out
end

local function formatAirportList(airports, cfg, subKey, maxLines)
    maxLines = tonumber(maxLines) or 25

    local totalCost = 0
    local lines = {}

    for i, airport in ipairs(airports or {}) do
        local control, source = getAirportControl(airport)
        local cost = getFinalCost(cfg, airport, subKey)
        totalCost = totalCost + cost

        if i <= maxLines then
            lines[#lines + 1] =
                tostring(i) .. ". " ..
                tostring(airport) ..
                " | control=" .. sideName(control) ..
                " | fuente=" .. tostring(source) ..
                " | costo=" .. formatMoney(cost)
        end
    end

    if #airports > maxLines then
        lines[#lines + 1] = "... +" .. tostring(#airports - maxLines) .. " aeropuertos mas"
    end

    return table.concat(lines, "\n"), totalCost
end

-- ============================================================================
-- COLA DE COMPRAS
-- ============================================================================
local function executePurchaseTask(task)
    local Marketplace = getMarketplace()
    if not Marketplace or not Marketplace.requestDelivery then
        return false, "HDEV_Marketplace.requestDelivery no disponible"
    end

    local cfg = getCfg(task.key)
    if not cfg then
        return false, "cfg no disponible para " .. tostring(task.key)
    end

    if DBG.CONFIG.IGNORE_COOLDOWNS and cfg.state and cfg.state.cooldowns then
        cfg.state.cooldowns[task.airport] = nil
    end

    local okCall, result = pcall(function()
        return Marketplace.requestDelivery(task.key, task.airport, task.subKey)
    end)

    if not okCall then
        return false, result
    end

    if result then
        return true, "OK"
    end

    return false, "requestDelivery devolvio false"
end

local function queueSummary(job)
    local msg =
        "MARKET DEBUG - Compra masiva terminada\n" ..
        "Job: " .. tostring(job.id) .. "\n" ..
        "Coalicion: " .. tostring(job.key) .. "\n" ..
        "Clave: " .. tostring(job.subKey) .. "\n" ..
        "Total: " .. tostring(job.total) .. "\n" ..
        "OK: " .. tostring(job.ok) .. "\n" ..
        "Fallos: " .. tostring(job.fail)

    outCoalition(job.side, msg, DBG.CONFIG.LONG_MESSAGE_TIME)
    warn(msg)
end

function DBG.processActiveJob()
    local job = DBG.STATE.activeJob
    if not job then
        return nil
    end

    job.index = (job.index or 0) + 1

    if job.index > #job.tasks then
        queueSummary(job)
        DBG.STATE.activeJob = nil

        if #DBG.STATE.pendingJobs > 0 then
            local nextJob = table.remove(DBG.STATE.pendingJobs, 1)
            DBG.startJob(nextJob)
        end

        return nil
    end

    local task = job.tasks[job.index]
    local ok, reason = executePurchaseTask(task)

    if ok then
        job.ok = (job.ok or 0) + 1
    else
        job.fail = (job.fail or 0) + 1
        warn(
            "Fallo compra debug: key=" .. tostring(task.key) ..
            " airport=" .. tostring(task.airport) ..
            " subKey=" .. tostring(task.subKey) ..
            " reason=" .. tostring(reason)
        )
    end

    if DBG.CONFIG.DEBUG then
        outCoalition(
            job.side,
            "MARKET DEBUG [" .. tostring(job.index) .. "/" .. tostring(job.total) .. "] " ..
            tostring(task.key) .. " " .. tostring(task.subKey) .. " -> " .. tostring(task.airport) ..
            " | " .. (ok and "OK" or "FALLO"),
            5
        )
    end

    return timer.getTime() + (tonumber(DBG.CONFIG.BUY_INTERVAL_SECONDS) or 1)
end

function DBG.startJob(job)
    if not job or not job.tasks or #job.tasks == 0 then
        return false
    end

    if DBG.STATE.activeJob then
        DBG.STATE.pendingJobs[#DBG.STATE.pendingJobs + 1] = job
        outCoalition(
            job.side,
            "MARKET DEBUG: ya hay una cola activa. Nueva cola agregada en espera. Pendientes: " .. tostring(#DBG.STATE.pendingJobs),
            10
        )
        return true
    end

    DBG.STATE.activeJob = job

    outCoalition(
        job.side,
        "MARKET DEBUG: iniciando compra masiva\n" ..
        "Job: " .. tostring(job.id) .. "\n" ..
        "Coalicion: " .. tostring(job.key) .. "\n" ..
        "Clave: " .. tostring(job.subKey) .. "\n" ..
        "Aeropuertos: " .. tostring(job.total) .. "\n" ..
        "Intervalo: " .. tostring(DBG.CONFIG.BUY_INTERVAL_SECONDS) .. " s",
        15
    )

    timer.scheduleFunction(function()
        return DBG.processActiveJob()
    end, nil, timer.getTime() + 0.1)

    return true
end

local function makeJob(key, side, subKey, airports, sourceText)
    DBG.STATE.jobCounter = (DBG.STATE.jobCounter or 0) + 1

    local maxBulk = tonumber(DBG.CONFIG.MAX_BULK_PER_COMMAND) or 0
    local finalAirports = {}

    for i, airport in ipairs(airports or {}) do
        if maxBulk > 0 and #finalAirports >= maxBulk then
            break
        end
        finalAirports[#finalAirports + 1] = airport
    end

    local tasks = {}
    for _, airport in ipairs(finalAirports) do
        tasks[#tasks + 1] = {
            key = key,
            side = side,
            airport = airport,
            subKey = subKey,
        }
    end

    return {
        id = DBG.STATE.jobCounter,
        key = key,
        side = side,
        subKey = subKey,
        sourceText = sourceText,
        tasks = tasks,
        total = #tasks,
        ok = 0,
        fail = 0,
        index = 0,
        createdAt = timer.getTime(),
    }
end

-- ============================================================================
-- COMANDOS
-- ============================================================================
local function showHelp(side)
    local msg =
        "MARKET DEBUG - Comandos F10\n\n" ..
        "Comprar a todos los aeropuertos de tu coalicion:\n" ..
        "mpbuy BLUE FA-18C-1\n" ..
        "mpbuy RED JETFUEL-100T\n\n" ..

        "Comprar a todos los aeropuertos configurados:\n" ..
        "mpbuy BLUE FA-18C-1 ALL\n\n" ..

        "Comprar a un aeropuerto especifico:\n" ..
        "mpbuy BLUE FA-18C-1 AIRPORT \"Bodo\"\n\n" ..

        "Comprar cerca de la etiqueta:\n" ..
        "mpbuy BLUE FA-18C-1 NEAR 20000\n\n" ..

        "Listar sin comprar:\n" ..
        "mpbuy BLUE FA-18C-1 LIST\n" ..
        "mpbuy BLUE FA-18C-1 ALL LIST\n\n" ..

        "Buscar claves:\n" ..
        "mpkeys F-16\n" ..
        "mpkeys JETFUEL\n\n" ..

        "Ver cola:\n" ..
        "mpqueue\n\n" ..

        "Limpiar cola:\n" ..
        "mpclear"

    outCoalition(side, msg, DBG.CONFIG.LONG_MESSAGE_TIME)
end

local function handleKeysCommand(tokens, event)
    local term = joinFrom(tokens, 2, " ")
    local results, total = searchKeys(term, 35)

    local msg = "MARKET DEBUG - Claves encontradas"
    if term ~= "" then
        msg = msg .. " para: " .. tostring(term)
    end
    msg = msg .. "\nTotal: " .. tostring(total) .. "\n\n"

    if #results == 0 then
        msg = msg .. "No encontre claves."
    else
        for i, item in ipairs(results) do
            msg = msg .. tostring(i) .. ". " .. tostring(item.key) .. " = " .. tostring(item.label) .. "\n"
        end

        if total > #results then
            msg = msg .. "\nMostrando " .. tostring(#results) .. " de " .. tostring(total) .. ". Refina la busqueda."
        end
    end

    outAll(msg, DBG.CONFIG.LONG_MESSAGE_TIME)
end

local function showQueue()
    local active = DBG.STATE.activeJob
    local msg = "MARKET DEBUG - Cola\n\n"

    if active then
        msg = msg ..
            "Activa:\n" ..
            "Job: " .. tostring(active.id) .. "\n" ..
            "Coalicion: " .. tostring(active.key) .. "\n" ..
            "Clave: " .. tostring(active.subKey) .. "\n" ..
            "Progreso: " .. tostring(active.index or 0) .. "/" .. tostring(active.total or 0) .. "\n" ..
            "OK: " .. tostring(active.ok or 0) .. "\n" ..
            "Fallos: " .. tostring(active.fail or 0) .. "\n\n"
    else
        msg = msg .. "No hay job activo.\n\n"
    end

    msg = msg .. "Jobs pendientes: " .. tostring(#(DBG.STATE.pendingJobs or {}))

    outAll(msg, DBG.CONFIG.LONG_MESSAGE_TIME)
end

local function clearQueue()
    DBG.STATE.pendingJobs = {}

    if DBG.STATE.activeJob then
        DBG.STATE.activeJob.cancelled = true
    end

    DBG.STATE.activeJob = nil

    outAll("MARKET DEBUG: cola limpiada.", 10)
end

local function resolveBuyTargets(key, side, cfg, subKey, tokens, event)
    local mode = upper(tokens[4] or DBG.CONFIG.DEFAULT_SCOPE or "OWNED")
    local listOnly = false
    local airports = {}

    -- Permite:
    -- mpbuy BLUE FA-18C-1 LIST
    -- mpbuy BLUE FA-18C-1 ALL LIST
    if mode == "LIST" or mode == "DRY" or mode == "DRYRUN" then
        listOnly = true
        mode = upper(DBG.CONFIG.DEFAULT_SCOPE or "OWNED")
    end

    if upper(tokens[5] or "") == "LIST" or upper(tokens[5] or "") == "DRY" or upper(tokens[5] or "") == "DRYRUN" then
        listOnly = true
    end

    if mode == "ALL" or mode == "TODOS" then
        airports = getAllConfiguredAirports(cfg)

    elseif mode == "OWNED" or mode == "CONTROLLED" or mode == "COALITION" or mode == "PROPIOS" or mode == "MÍOS" or mode == "MIOS" then
        airports = filterOwnedAirports(cfg, key)

    elseif mode == "AIRPORT" or mode == "BASE" or mode == "AEROPUERTO" then
        local airportName = trim(joinFrom(tokens, 5, " "))
        if airportName == "" then
            return nil, listOnly, "Falta nombre de aeropuerto. Ejemplo: mpbuy BLUE FA-18C-1 AIRPORT \"Bodo\""
        end

        if not cfg.plantillas or not cfg.plantillas[airportName] then
            return nil, listOnly, "Ese aeropuerto no existe en cfg.plantillas: " .. tostring(airportName)
        end

        airports = { airportName }

    elseif mode == "NEAR" or mode == "CERCA" then
        local radius = tonumber(tokens[5]) or DBG.CONFIG.DEFAULT_NEAR_RADIUS or 20000
        airports = filterNearAirports(cfg, key, event and event.pos, radius, true)

    elseif mode == "NEARALL" or mode == "CERCAALL" then
        local radius = tonumber(tokens[5]) or DBG.CONFIG.DEFAULT_NEAR_RADIUS or 20000
        airports = filterNearAirports(cfg, key, event and event.pos, radius, false)

    else
        -- Si no reconoce el modo, asumimos default owned.
        airports = filterOwnedAirports(cfg, key)
    end

    return airports, listOnly, nil
end

local function handleBuyCommand(tokens, event, sourceText)
    if #tokens < 3 then
        outAll(
            "MARKET DEBUG: comando incompleto.\n" ..
            "Ejemplo: mpbuy BLUE FA-18C-1\n" ..
            "Usa mphelp para ayuda.",
            12
        )
        return
    end

    local key, side = getSideFromKey(tokens[2])
    if not key then
        outAll("MARKET DEBUG: coalicion invalida: " .. tostring(tokens[2]) .. ". Usa BLUE/RED.", 10)
        return
    end

    local subKey, keyErr = resolveSubKey(tokens[3])
    if not subKey then
        outCoalition(side, "MARKET DEBUG: " .. tostring(keyErr) .. "\nUsa: mpkeys " .. tostring(tokens[3]), 15)
        return
    end

    local cfg = getCfg(key)
    if not cfg then
        outCoalition(side, "MARKET DEBUG: no existe configuracion Marketplace para " .. tostring(key) .. ". Revisa orden de carga.", 10)
        return
    end

    local airports, listOnly, err = resolveBuyTargets(key, side, cfg, subKey, tokens, event)
    if err then
        outCoalition(side, "MARKET DEBUG: " .. tostring(err), 12)
        return
    end

    if not airports or #airports == 0 then
        outCoalition(
            side,
            "MARKET DEBUG: no encontre aeropuertos para " .. tostring(key) .. " con clave " .. tostring(subKey) .. ".",
            12
        )
        return
    end

    local listText, totalCost = formatAirportList(airports, cfg, subKey, 30)

    if listOnly then
        outCoalition(
            side,
            "MARKET DEBUG - LISTA SIN COMPRAR\n" ..
            "Coalicion: " .. tostring(key) .. "\n" ..
            "Clave: " .. getSubKeyDisplay(subKey) .. "\n" ..
            "Aeropuertos: " .. tostring(#airports) .. "\n" ..
            "Costo estimado total: " .. formatMoney(totalCost) .. "\n\n" ..
            listText,
            DBG.CONFIG.LONG_MESSAGE_TIME
        )
        return
    end

    local job = makeJob(key, side, subKey, airports, sourceText)

    if not job or job.total <= 0 then
        outCoalition(side, "MARKET DEBUG: job vacio.", 10)
        return
    end

    DBG.startJob(job)
end

function DBG.handleTextCommand(text, event)
    text = trim(text)
    if text == "" then return false end

    local tokens = tokenize(text)
    if #tokens == 0 then return false end

    local cmd = lower(tokens[1])

    if DBG.CONFIG.HELP_PREFIXES[cmd] then
        showHelp(nil)
        return true
    end

    if DBG.CONFIG.KEYS_PREFIXES[cmd] then
        handleKeysCommand(tokens, event)
        return true
    end

    if DBG.CONFIG.QUEUE_PREFIXES[cmd] then
        showQueue()
        return true
    end

    if DBG.CONFIG.CLEAR_PREFIXES[cmd] then
        clearQueue()
        return true
    end

    if DBG.CONFIG.BUY_PREFIXES[cmd] then
        handleBuyCommand(tokens, event, text)
        return true
    end

    return false
end

-- ============================================================================
-- EVENTOS DE MARCAS F10
-- ============================================================================
local function isMarkEvent(event)
    if not event or not event.id then
        return false
    end

    if world and world.event then
        if event.id == world.event.S_EVENT_MARK_ADDED then
            return true
        end

        if DBG.CONFIG.ACCEPT_MARK_CHANGE and event.id == world.event.S_EVENT_MARK_CHANGE then
            return true
        end
    end

    return false
end

function DBG.onMarkEvent(event)
    if not DBG.CONFIG.ENABLED then
        return
    end

    if not isMarkEvent(event) then
        return
    end

    local text = tostring(event.text or event.comment or "")
    text = trim(text)

    if text == "" then
        return
    end

    local markKey = tostring(event.idx or "noidx") .. "|" .. tostring(event.id or "noid") .. "|" .. text
    if DBG.STATE.processedMarks[markKey] then
        return
    end

    DBG.STATE.processedMarks[markKey] = true

    local handled = DBG.handleTextCommand(text, event)
    if handled then
        safeRemoveMark(event.idx)
    end
end

-- ============================================================================
-- INSTALACION
-- ============================================================================
function DBG.dependenciesReady()
    if not world or not world.addEventHandler then
        return false, "world.addEventHandler no disponible"
    end

    if not HDEV_Marketplace then
        return false, "HDEV_Marketplace no cargado"
    end

    if not HDEV_Marketplace.requestDelivery then
        return false, "HDEV_Marketplace.requestDelivery no disponible"
    end

    if not HDEV_Marketplace.coalitions then
        return false, "HDEV_Marketplace.coalitions no disponible"
    end

    if DBG.CONFIG.REQUIRE_AUTOROUTES then
        if not HDEV_MarketplaceAutoRoutes then
            return false, "HDEV_MarketplaceAutoRoutes no cargado"
        end

        if not HDEV_MarketplaceAutoRoutes.STATE or not HDEV_MarketplaceAutoRoutes.STATE.installed then
            return false, "HDEV_MarketplaceAutoRoutes aun no instalado"
        end
    end

    if not HDEV_Marketplace.coalitions.BLUE and not HDEV_Marketplace.coalitions.RED then
        return false, "coaliciones BLUE/RED aun no registradas"
    end

    return true, nil
end

function DBG.install()
    if DBG.STATE.installed then
        return true
    end

    DBG.STATE.installAttempts = (DBG.STATE.installAttempts or 0) + 1

    local ready, reason = DBG.dependenciesReady()
    if not ready then
        warn("Esperando dependencias: " .. tostring(reason))
        return false
    end

    DBG.STATE.eventHandler = {
        onEvent = function(_, event)
            DBG.onMarkEvent(event)
        end
    }

    world.addEventHandler(DBG.STATE.eventHandler)

    DBG.STATE.installed = true

    log(
        "Instalado VERSION 1. Comandos: mpbuy, mpkeys, mphelp. " ..
        "Usa etiqueta F10: mpbuy BLUE FA-18C-1"
    )

    return true
end

local function installRetry()
    if DBG.install() then
        return nil
    end

    if (DBG.STATE.installAttempts or 0) >= (DBG.CONFIG.INSTALL_RETRIES or 60) then
        trigger.action.outText("ERROR: HDEV_MarketplaceDebugMarks no pudo instalarse. Revisa orden de carga.", 15)
        warn("No pudo instalarse despues de " .. tostring(DBG.STATE.installAttempts) .. " intentos.")
        return nil
    end

    return timer.getTime() + (DBG.CONFIG.INSTALL_RETRY_SECONDS or 1)
end

if not DBG.install() then
    timer.scheduleFunction(function()
        return installRetry()
    end, nil, timer.getTime() + (DBG.CONFIG.INSTALL_RETRY_SECONDS or 1))
end

return HDEV_MarketplaceDebugMarks