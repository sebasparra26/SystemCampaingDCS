-- ============================================================================
-- HDEV_MarketplaceMenuF10.lua
-- VERSION: 1
--
-- Separacion FASE 1 del Marketplace:
-- - Este archivo contiene SOLO la UI F10 del Marketplace.
-- - NO toca economia.
-- - NO toca rutas dinamicas.
-- - NO toca warehouses.
-- - NO crea entregas.
-- - Solo reemplaza/puentea estas funciones del core:
--      HDEV_Marketplace.buildMenu
--      HDEV_Marketplace.closeMarket
--      HDEV_Marketplace.marketTimerTick
--      HDEV_Marketplace.startMarketTimer
--
-- Mantiene compatibilidad con:
--      MENU_logisticCoalition_BLUE_V4.lua
--      MENU_logisticCoalition_RED_V4.lua
--
-- CARGA RECOMENDADA:
-- 1) mist_4_5_128.lua
-- 2) HookEconomyV2.lua / HDEV_Economy
-- 3) StockWarehouse_*.lua
-- 4) MENU_CONTENT_logistic_Kola.lua
-- 5) HDEV_MarketplaceCore_1_1.lua
-- 6) HDEV_MarketplaceMenuF10.lua       <-- NUEVO
-- 7) HDEV_MarketplaceAutoRoutes.lua    <-- version que ya aterriza bien
-- 8) MENU_logisticCoalition_BLUE_V4.lua
-- 9) MENU_logisticCoalition_RED_V4.lua
-- ============================================================================

if not HDEV_Marketplace then
    trigger.action.outText("ERROR: Carga primero HDEV_MarketplaceCore_1_1.lua antes de HDEV_MarketplaceMenuF10.lua", 15)
    env.info("[HDEV_MARKET_MENU_F10] ERROR: HDEV_Marketplace no existe.")
    return nil
end

HDEV_MarketplaceMenuF10 = HDEV_MarketplaceMenuF10 or {}
local MENU = HDEV_MarketplaceMenuF10
local Marketplace = HDEV_Marketplace

MENU.VERSION = "1"

MENU.CONFIG = MENU.CONFIG or {
    DEBUG = false,

    -- Comandos raiz del menu.
    SHOW_WALLET_COMMAND = true,
    SHOW_ROUTES_COMMAND = true,

    WALLET_LABEL = "Mostrar billetera",
    ROUTES_LABEL = "Mostrar rutas activas",

    DEFAULT_MENU_NAME = "MARKETPLACE",
    DEFAULT_PAGE_TITLE_PREFIX = "Pagina",
    DEFAULT_ITEMS_PER_PAGE = 8,

    BUY_LABEL_PREFIX = "Comprar y Enviar a: ",

    CLOSE_DEFAULT_MESSAGE = "El Mercado de Pulgas ha sido cerrado.",
    TIMER_MESSAGE_PREFIX = "El mercado se cerrara en: ",
}

MENU.STATE = MENU.STATE or {
    installed = false,
    originals = {},
}

-- ==========================================================================
-- LOG / UTILS
-- ==========================================================================
local function log(msg)
    env.info("[HDEV_MARKET_MENU_F10] " .. tostring(msg))
    if MENU.CONFIG.DEBUG then
        trigger.action.outText("[MARKET MENU] " .. tostring(msg), 6)
    end
end

local function warn(msg)
    env.info("[HDEV_MARKET_MENU_F10] " .. tostring(msg))
end

local function sortKeys(t)
    local keys = {}
    for k, _ in pairs(t or {}) do
        keys[#keys + 1] = k
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function outCoalition(coalitionSide, msg, seconds)
    trigger.action.outTextForCoalition(coalitionSide, tostring(msg), seconds or 10)
end

local function getEconomy()
    return HDEV_Economy
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

local function buildCategoryMap(tipos)
    local categorias = {}

    for nombreAvion, datos in pairs(tipos or {}) do
        local categoria = datos.categoria or "Sin Clasificar"
        categorias[categoria] = categorias[categoria] or {}
        table.insert(categorias[categoria], nombreAvion)
    end

    for _, list in pairs(categorias) do
        table.sort(list)
    end

    return categorias
end

local function getVisibleDestinations(cfg, subKey)
    local result = {}

    if type(destinosPorSubvariante) ~= "table" then
        return result
    end

    local entries = destinosPorSubvariante[subKey] or {}

    for _, airport in ipairs(entries) do
        if cfg.plantillas and cfg.plantillas[airport] then
            result[#result + 1] = airport
        end
    end

    return result
end

local function getFinalCost(cfg, airport, subKey)
    local base = 0

    if tipoAviones and tipoAviones[subKey] then
        base = tonumber(tipoAviones[subKey].costo) or 0
    end

    local recargo = cfg.recargos and cfg.recargos[airport] or 1
    return math.floor(base * recargo)
end

-- ==========================================================================
-- COMANDOS RAIZ
-- ==========================================================================
function MENU.registerRootCommands(cfg)
    if not cfg or not cfg.menuRoot then
        return
    end

    if MENU.CONFIG.SHOW_WALLET_COMMAND then
        missionCommands.addCommandForCoalition(cfg.coalition, MENU.CONFIG.WALLET_LABEL or "Mostrar billetera", cfg.menuRoot, function()
            local econ = getEconomy()

            if not econ or not econ.get then
                outCoalition(cfg.coalition, "Sistema economico no disponible.", 8)
                return
            end

            local msg = "Billetera\n"
            msg = msg .. "Azul: " .. formatMoney(econ.get(2)) .. "\n"
            msg = msg .. "Rojo: " .. formatMoney(econ.get(1))

            outCoalition(cfg.coalition, msg, 10)
        end)
    end

    if MENU.CONFIG.SHOW_ROUTES_COMMAND then
        missionCommands.addCommandForCoalition(cfg.coalition, MENU.CONFIG.ROUTES_LABEL or "Mostrar rutas activas", cfg.menuRoot, function()
            if Marketplace.showRoutes then
                Marketplace.showRoutes(cfg.key)
            else
                outCoalition(cfg.coalition, "Funcion showRoutes no disponible.", 8)
            end
        end)
    end
end

-- ==========================================================================
-- BUILD MENU F10
-- ==========================================================================
function MENU.buildMenu(key)
    local cfg = Marketplace.coalitions and Marketplace.coalitions[key]

    if not cfg then
        warn("No existe configuracion de marketplace para: " .. tostring(key))
        return false
    end

    if cfg.menuRoot then
        missionCommands.removeItem(cfg.menuRoot)
        cfg.menuRoot = nil
    end

    cfg.menuRoot = missionCommands.addSubMenuForCoalition(
        cfg.coalition,
        cfg.menuName or MENU.CONFIG.DEFAULT_MENU_NAME or "MARKETPLACE"
    )

    MENU.registerRootCommands(cfg)

    local categorias = buildCategoryMap(tiposAvion)

    for _, categoria in ipairs(sortKeys(categorias)) do
        local menuCategoria = missionCommands.addSubMenuForCoalition(cfg.coalition, categoria, cfg.menuRoot)

        for _, nombreAvion in ipairs(categorias[categoria]) do
            local datos = tiposAvion[nombreAvion]
            local claveTipo = datos and datos.clave

            if claveTipo and subvariantesAvion and subvariantesAvion[claveTipo] then
                local menuAvion = missionCommands.addSubMenuForCoalition(cfg.coalition, nombreAvion, menuCategoria)
                local subMap = subvariantesAvion[claveTipo]

                for _, nombreSub in ipairs(sortKeys(subMap)) do
                    local claveSub = subMap[nombreSub]
                    local visibleDestinations = getVisibleDestinations(cfg, claveSub)

                    if #visibleDestinations > 0 then
                        local menuSub = missionCommands.addSubMenuForCoalition(cfg.coalition, nombreSub, menuAvion)
                        local porPagina = cfg.itemsPerPage or MENU.CONFIG.DEFAULT_ITEMS_PER_PAGE or 8
                        local totalPaginas = math.max(1, math.ceil(#visibleDestinations / porPagina))

                        for pagina = 1, totalPaginas do
                            local paginaMenu = menuSub

                            if totalPaginas > 1 then
                                local pageName = (cfg.pageTitlePrefix or MENU.CONFIG.DEFAULT_PAGE_TITLE_PREFIX or "Pagina") .. " " .. tostring(pagina)
                                paginaMenu = missionCommands.addSubMenuForCoalition(cfg.coalition, pageName, menuSub)
                            end

                            local iInicio = ((pagina - 1) * porPagina) + 1
                            local iFin = math.min(#visibleDestinations, pagina * porPagina)

                            for i = iInicio, iFin do
                                local airport = visibleDestinations[i]
                                local cost = getFinalCost(cfg, airport, claveSub)
                                local label = (MENU.CONFIG.BUY_LABEL_PREFIX or "Comprar y Enviar a: ") .. airport .. " (" .. formatMoney(cost) .. ")"

                                missionCommands.addCommandForCoalition(cfg.coalition, label, paginaMenu, function()
                                    Marketplace.requestDelivery(key, airport, claveSub)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end

    warn("Menu F10 construido para " .. tostring(key))
    return true
end

function MENU.closeMarket(key)
    local cfg = Marketplace.coalitions and Marketplace.coalitions[key]

    if not cfg then
        return
    end

    if cfg.menuRoot then
        missionCommands.removeItem(cfg.menuRoot)
        cfg.menuRoot = nil
        outCoalition(cfg.coalition, cfg.closeMessage or MENU.CONFIG.CLOSE_DEFAULT_MESSAGE or "El Mercado de Pulgas ha sido cerrado.", 15)
    end
end

function MENU.marketTimerTick(key, now)
    local cfg = Marketplace.coalitions and Marketplace.coalitions[key]

    if not cfg or not cfg.marketTimer or not cfg.marketStartTime then
        return nil
    end

    local total = cfg.marketTimer.Total or 0
    local intervalo = cfg.marketTimer.Intervalo or 0

    if total <= 0 or intervalo <= 0 then
        return nil
    end

    local restante = math.max(0, (cfg.marketStartTime + total) - now)

    if restante <= 0 then
        MENU.closeMarket(key)
        return nil
    end

    local minutos = math.floor(restante / 60)
    local segundos = math.floor(restante % 60)

    outCoalition(
        cfg.coalition,
        (MENU.CONFIG.TIMER_MESSAGE_PREFIX or "El mercado se cerrara en: ") .. minutos .. " min " .. segundos .. " seg",
        10
    )

    return now + intervalo
end

function MENU.startMarketTimer(key, marketTimer)
    local cfg = Marketplace.coalitions and Marketplace.coalitions[key]

    if not cfg then
        return false
    end

    cfg.marketTimer = marketTimer
    cfg.marketStartTime = timer.getTime()

    if not marketTimer or not marketTimer.Total or not marketTimer.Intervalo then
        return false
    end

    timer.scheduleFunction(function(_, now)
        return MENU.marketTimerTick(key, now)
    end, nil, timer.getTime() + marketTimer.Intervalo)

    return true
end

-- ==========================================================================
-- PUENTE DE COMPATIBILIDAD
-- ==========================================================================
function MENU.install()
    if MENU.STATE.installed then
        return true
    end

    MENU.STATE.originals.buildMenu = Marketplace.buildMenu
    MENU.STATE.originals.closeMarket = Marketplace.closeMarket
    MENU.STATE.originals.marketTimerTick = Marketplace.marketTimerTick
    MENU.STATE.originals.startMarketTimer = Marketplace.startMarketTimer

    -- Compatibilidad: los V4 pueden seguir llamando HDEV_Marketplace.buildMenu().
    Marketplace.buildMenu = MENU.buildMenu
    Marketplace.closeMarket = MENU.closeMarket
    Marketplace.marketTimerTick = MENU.marketTimerTick
    Marketplace.startMarketTimer = MENU.startMarketTimer

    MENU.STATE.installed = true
    log("Instalado. UI F10 separada del core. VERSION " .. tostring(MENU.VERSION))
    return true
end

MENU.install()

return HDEV_MarketplaceMenuF10
