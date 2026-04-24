-- ============================================================================
-- AirportInventoryPanels_Sinai.lua
-- Paneles de inventario por aeropuerto
-- - Solo toca este script
-- - Capacidad manual por aeropuerto dentro de este archivo
-- - Letra blanca o negra configurable
-- - Visibilidad por coalición controladora del aeropuerto
-- ============================================================================

AirportInventoryPanelsSinai = AirportInventoryPanelsSinai or {}

local AIP = AirportInventoryPanelsSinai

AIP.cfg = {
    debug = false,

    -- Refresco
    updateInterval = 45,

    -- Posicion visual del cuadro respecto al aeropuerto
    offsetX = 5000,
    offsetZ = 2500,

    -- Apariencia
    fontSize = 11,
    textColor = "white",   -- "white" o "black"

    -- Si true, no muestra cuadros totalmente vacios
    onlyShowIfHasSomething = false,

    -- Si no es nil, fuerza mostrar solo ese control
    -- nil = no forzar
    -- 1 = solo rojos
    -- 2 = solo azules
    -- 0 = solo neutrales
    onlyShowControlledBy = nil,

    -- Que pasa si el aeropuerto esta neutral
    -- "all"    = lo ven todos
    -- "red"    = lo ven solo rojos
    -- "blue"   = lo ven solo azules
    -- "hidden" = no lo ve nadie
    neutralVisibleTo = "all",

    -- Que mostrar
    showLiquids = true,
    showAircraftSummary = true,
    showWeaponSummary = false,

    -- Top items
    topAircraftItems = 10,
    topWeaponItems = 3,
}

AIP.state = AIP.state or {
    started = false,
    markers = {},
    airports = {},
}

-- ============================================================================
-- TABLA MANUAL DE CAPACIDADES
-- AQUI EDITAS TU
-- ============================================================================
AIP.manualCapabilities = {
    -- FORMATO:
    -- ["Nombre exacto del aeropuerto"] = {
    --     aviones = true/false,
    --     helis   = true/false,
    --     c130    = true/false,
    --     armas   = true/false
    -- },

    -- EJEMPLOS:
    -- ["Wadi al Jandali"] = { aviones = false, helis = true,  c130 = false, armas = true  },
    ["Difarsuwar Airfield"] = { aviones = false, helis = true, c130 = false, armas = true }, --CAP
    ["Abu Suwayr"] = { aviones = true, helis = true, c130 = false, armas = false },--CAP
    ["As Salihiyah"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Al Ismailiyah"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Melez"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Fayed"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Hatzerim"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Nevatim"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Ramon Airbase"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Ovda"] = { aviones = true, helis = true, c130 = false, armas = true },
    ["Kibrit Air Base"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Kedem"] = { aviones = true, helis = true, c130 = false, armas = false }, --CAP
    ["Wadi al Jandali"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Al Mansurah"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["AzZaqaziq"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Bilbeis Air Base"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Cairo International Airport"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Cairo West"] = { aviones = true, helis = true, c130 = true, armas = true }, --CAP
    ["Inshas Airbase"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Hatzor"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Palmachim"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Sde Dov"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Tel Nof"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Ben-Gurion"] = { aviones = true, helis = true, c130 = true, armas = true },
    ["St Catherine"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Abu Rudeis"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Baluza"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Bir Hasanah"] = { aviones = true, helis = true, c130 = false, armas = true },
    ["El Arish"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["El Gora"] = { aviones = true, helis = true, c130 = false, armas = true },
    ["Al Khatatbah"] = { aviones = false, helis = true, c130 = false, armas = false },
    ["Al Rahmaniyah Air Base"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Beni Suef"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Birma Air Base"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Borg El Arab International Airport"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["El Minya"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Gebel El Basur Air Base"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Hurghada International Airport"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Jiyanklis Air Base"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Kom Awshim"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Ramon International Airport"] = { aviones = true, helis = true, c130 = true, armas = false }, --CAP
    ["Sharm El Sheikh International Airport"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Wadi Abu Rish"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Al Bahr al Ahmar"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Quwaysina"] = { aviones = false, helis = true, c130 = false, armas = false },
    ["Rafic Hariri Intl"] = { aviones = true, helis = true, c130 = true, armas = true }, -- CAP
    ["Tabuk"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Damascus Intl"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Mezzeh Air Base"] = { aviones = true, helis = true, c130 = false, armas = false },
    ["Ramat David"] = { aviones = true, helis = true, c130 = true, armas = true }, -- CAP
    ["Megiddo"] = { aviones = true, helis = false, c130 = false, armas = false },
    ["Ein Shamer"] = { aviones = true, helis = true, c130 = false, armas = true },
    ["Taba International Airport"] = { aviones = true, helis = true, c130 = true, armas = false }, --CAP
    ["King Feisal Air Base"] = { aviones = true, helis = true, c130 = true, armas = false },
    ["Khalkhalah Air Base"] = { aviones = true, helis = true, c130 = false, armas = false },

    -- DEJA AQUI TU CONFIG REAL
}

-- ============================================================================
-- UTILIDADES
-- ============================================================================

local function aipLog(msg)
    if AIP.cfg.debug then
        env.info("[AIRPORT PANELS] " .. tostring(msg))
        trigger.action.outText("[AIRPORT PANELS] " .. tostring(msg), 8)
    end
end

local function safeNumber(v)
    return tonumber(v) or 0
end

local function normalizeAirbaseCoalition(v)
    v = tonumber(v)

    if v == 1 or v == 2 or v == 0 then
        return v
    end

    -- En algunos flujos neutral puede venir como 3
    if v == 3 then
        return 0
    end

    return 0
end

local function normalizeName(name)
    name = tostring(name or "")

    if name == "Ai Ismailiyah" then
        return "Al Ismailiyah"
    end

    return name
end

local function coalitionName(v)
    if v == 1 then return "ROJO" end
    if v == 2 then return "AZUL" end
    return "NEUTRAL"
end

local function formatInt(n)
    return tostring(math.floor(safeNumber(n) + 0.5))
end

local function copyFlatMap(src)
    local out = {}
    if type(src) ~= "table" then
        return out
    end

    for k, v in pairs(src) do
        local n = safeNumber(v)
        if n > 0 then
            out[tostring(k)] = n
        end
    end

    return out
end

local function countMapSummary(tbl)
    local unique = 0
    local total = 0

    for _, v in pairs(tbl or {}) do
        local n = safeNumber(v)
        if n > 0 then
            unique = unique + 1
            total = total + n
        end
    end

    return unique, total
end

local function getTopItems(tbl, topN)
    local arr = {}

    for k, v in pairs(tbl or {}) do
        local n = safeNumber(v)
        if n > 0 then
            arr[#arr + 1] = {
                name = tostring(k),
                value = n
            }
        end
    end

    table.sort(arr, function(a, b)
        if a.value == b.value then
            return a.name < b.name
        end
        return a.value > b.value
    end)

    local out = {}
    local limit = math.min(topN or 3, #arr)
    for i = 1, limit do
        out[#out + 1] = arr[i]
    end

    return out
end

local function shortItemName(name, maxLen)
    name = tostring(name or "")
    maxLen = maxLen or 18

    if #name <= maxLen then
        return name
    end

    return name:sub(1, maxLen - 3) .. "..."
end

local function getPanelTextColor()
    if AIP.cfg.textColor == "black" then
        return {0, 0, 0, 255}
    end
    return {255, 255, 255, 255}
end

local function getPanelFillColorByCoalition(v)
    if v == 1 then
        return {255, 0, 0, 70}
    elseif v == 2 then
        return {0, 100, 255, 70}
    else
        return {255, 255, 255, 55}
    end
end

local function getMarkerAudienceCoa(controlCoalition)
    controlCoalition = normalizeAirbaseCoalition(controlCoalition)

    if controlCoalition == 1 then
        return 1
    end

    if controlCoalition == 2 then
        return 2
    end

    if AIP.cfg.neutralVisibleTo == "red" then
        return 1
    elseif AIP.cfg.neutralVisibleTo == "blue" then
        return 2
    elseif AIP.cfg.neutralVisibleTo == "hidden" then
        return nil
    end

    -- all
    return -1
end

local function removeAirportMarker(airportName)
    local existing = AIP.state.markers[airportName]
    if existing then
        mist.marker.remove(existing)
        AIP.state.markers[airportName] = nil
    end
end

local function buildAirportCoordIndex()
    local idx = {}

    local function ingest(tbl)
        if type(tbl) ~= "table" then
            return
        end

        for rawName, point in pairs(tbl) do
            local name = normalizeName(rawName)
            if type(point) == "table" and point.x and point.z then
                idx[name] = {
                    x = safeNumber(point.x),
                    y = safeNumber(point.y),
                    z = safeNumber(point.z)
                }
            end
        end
    end

    ingest(coordenadasAerodromosB)
    ingest(coordenadasAerodromosR)

    return idx
end

local function snapshotAirbase(ab)
    if not ab then
        return nil
    end

    local okWh, wh = pcall(function()
        return ab:getWarehouse()
    end)
    if not okWh or not wh then
        return nil
    end

    local okInv, inv = pcall(function()
        return wh:getInventory()
    end)
    if not okInv or type(inv) ~= "table" then
        inv = {}
    end

    local liquids = {
        jet_fuel = 0,
        gasoline = 0,
        methanol_mixture = 0,
        diesel = 0
    }

    local liquidIds = {
        jet_fuel = 0,
        gasoline = 1,
        methanol_mixture = 2,
        diesel = 3
    }

    for lname, lid in pairs(liquidIds) do
        local okLiquid, amount = pcall(function()
            return wh:getLiquidAmount(lid)
        end)

        if okLiquid and type(amount) == "number" then
            liquids[lname] = amount
        elseif inv.liquids then
            liquids[lname] = safeNumber(inv.liquids[lid] or inv.liquids[tostring(lid)] or 0)
        end
    end

    local coal = 0
    local okCoal, coalVal = pcall(function()
        return ab:getCoalition()
    end)
    if okCoal then
        coal = normalizeAirbaseCoalition(coalVal)
    end

    return {
        id = ab:getID(),
        name = normalizeName(ab:getName()),
        coalition = coal,
        liquids = liquids,
        aircraft = copyFlatMap(inv.aircraft),
        weapon = copyFlatMap(inv.weapon)
    }
end

local function hasAnything(snap)
    if not snap then
        return false
    end

    for _, v in pairs(snap.liquids or {}) do
        if safeNumber(v) > 0 then
            return true
        end
    end

    for _, v in pairs(snap.aircraft or {}) do
        if safeNumber(v) > 0 then
            return true
        end
    end

    for _, v in pairs(snap.weapon or {}) do
        if safeNumber(v) > 0 then
            return true
        end
    end

    return false
end

-- ============================================================================
-- CAPACIDADES MANUALES
-- ============================================================================

local function getManualCapabilities(airportName)
    airportName = normalizeName(airportName)

    local manual = AIP.manualCapabilities and AIP.manualCapabilities[airportName]
    if not manual then
        return nil
    end

    return {
        defined = true,
        planes = manual.aviones == true,
        helicopters = manual.helis == true,
        hercules = manual.c130 == true,
        weapons = manual.armas == true,
    }
end

local function capabilitiesToText(caps)
    if not caps or not caps.defined then
        return "SIN DEFINIR"
    end

    local p = caps.planes == true
    local h = caps.helicopters == true
    local c = caps.hercules == true
    local w = caps.weapons == true

    local parts = {}

    if p then parts[#parts + 1] = "AVIONES" end
    if h then parts[#parts + 1] = "HELIS" end
    if c then parts[#parts + 1] = "C130" end
    if w then parts[#parts + 1] = "CTDL" end

    if #parts == 0 then
        return "BLOQUEADO"
    end

    return table.concat(parts, " + ")
end

-- ============================================================================
-- TEXTO DEL PANEL
-- ============================================================================

local function buildPanelText(snap, caps)
    local lines = {}

    lines[#lines + 1] = snap.name
    lines[#lines + 1] = "CTRL: " .. coalitionName(snap.coalition)
    lines[#lines + 1] = "CAP: " .. capabilitiesToText(caps)

    if AIP.cfg.showLiquids then
        local jet = safeNumber(snap.liquids.jet_fuel)
        local gas = safeNumber(snap.liquids.gasoline)
        local met = safeNumber(snap.liquids.methanol_mixture)
        local dis = safeNumber(snap.liquids.diesel)

        lines[#lines + 1] = "JET: " .. formatInt(jet)

        if gas > 0 or met > 0 or dis > 0 then
            lines[#lines + 1] =
                "GAS: " .. formatInt(gas) ..
                "  MET: " .. formatInt(met) ..
                "  DIE: " .. formatInt(dis)
        end
    end

    if AIP.cfg.showAircraftSummary then
        local uniqueAircraft, totalAircraft = countMapSummary(snap.aircraft)
        lines[#lines + 1] = "ACFT: " .. uniqueAircraft .. " tipos / " .. formatInt(totalAircraft) .. " uds"

        local topAircraft = getTopItems(snap.aircraft, AIP.cfg.topAircraftItems)
        for _, item in ipairs(topAircraft) do
            lines[#lines + 1] = "- " .. shortItemName(item.name, 18) .. ": " .. formatInt(item.value)
        end
    end

    if AIP.cfg.showWeaponSummary then
        local uniqueWeapon, totalWeapon = countMapSummary(snap.weapon)
        lines[#lines + 1] = "WPN: " .. uniqueWeapon .. " tipos / " .. formatInt(totalWeapon) .. " uds"

        local topWeapon = getTopItems(snap.weapon, AIP.cfg.topWeaponItems)
        for _, item in ipairs(topWeapon) do
            lines[#lines + 1] = "- " .. shortItemName(item.name, 18) .. ": " .. formatInt(item.value)
        end
    end

    return table.concat(lines, "\n")
end

-- ============================================================================
-- DIBUJO
-- ============================================================================

local function drawPanelForAirport(airportName, basePoint, snap)
    removeAirportMarker(airportName)

    if not snap then
        return
    end

    if AIP.cfg.onlyShowIfHasSomething and not hasAnything(snap) then
        return
    end

    if AIP.cfg.onlyShowControlledBy ~= nil and snap.coalition ~= AIP.cfg.onlyShowControlledBy then
        return
    end

    local caps = getManualCapabilities(airportName)
    local text = buildPanelText(snap, caps)
    local markerCoa = getMarkerAudienceCoa(snap.coalition)

    if markerCoa == nil then
        return
    end

    local panelPoint = {
        x = safeNumber(basePoint.x) + AIP.cfg.offsetX,
        y = safeNumber(basePoint.y),
        z = safeNumber(basePoint.z) + AIP.cfg.offsetZ
    }

    local markData = mist.marker.add({
        name = "INV_PANEL_" .. airportName,
        mType = 5,
        point = panelPoint,
        text = text,
        fontSize = AIP.cfg.fontSize,
        color = getPanelTextColor(),
        fillColor = getPanelFillColorByCoalition(snap.coalition),
        lineType = 1,
        readOnly = true,
        coa = markerCoa
    })

    if markData and markData.markId then
        AIP.state.markers[airportName] = markData.markId
    end
end

local function refreshPanels()
    if not mist then
        aipLog("MIST no disponible.")
        return
    end

    for airportName, point in pairs(AIP.state.airports or {}) do
        local ab = Airbase.getByName(airportName)
        if ab then
            local snap = snapshotAirbase(ab)
            drawPanelForAirport(airportName, point, snap)
        else
            removeAirportMarker(airportName)
        end
    end
end

local function loop(_, now)
    refreshPanels()
    return now + (AIP.cfg.updateInterval or 45)
end

function AIP.start()
    if AIP.state.started then
        aipLog("Ya estaba iniciado.")
        return
    end

    if not mist then
        env.info("[AIRPORT PANELS] ERROR: MIST no esta cargado.")
        return
    end

    if type(coordenadasAerodromosB) ~= "table" and type(coordenadasAerodromosR) ~= "table" then
        env.info("[AIRPORT PANELS] ERROR: MENU_CONTENT_logistic_Sinai.lua no esta cargado.")
        return
    end

    AIP.state.airports = buildAirportCoordIndex()

    refreshPanels()

    timer.scheduleFunction(loop, nil, timer.getTime() + (AIP.cfg.updateInterval or 45))
    AIP.state.started = true

    env.info("[AIRPORT PANELS] Sistema iniciado.")
end

AIP.start()