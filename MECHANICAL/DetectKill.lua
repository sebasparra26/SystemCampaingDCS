--------------------------------------------------------
-- DETECTOR CAS + ECONOMIA
--
-- REQUIERE:
-- 1) mist cargado antes
-- 2) HDEV_EconomyCore.lua cargado antes idealmente
--
-- FUNCION:
-- - Detecta bajas ROJAS dentro de una zona
-- - Dispara una bandera ON -> OFF
-- - Paga recompensas al sistema economico
-- - Soporta: infanteria, vehiculos, aviones, helicopteros y barcos
-- - Permite precio por categoria y por tipo exacto
--------------------------------------------------------

if not mist then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

--------------------------------------------------------
-- CONFIGURACION
--------------------------------------------------------
local CAS = {}

CAS.flagId = 901
CAS.zoneName = "MONITOREO"

CAS.debugText = false
CAS.debugLog = false

--------------------------------------------------------
-- ECONOMIA
--------------------------------------------------------
CAS.useEconomy = true
CAS.rewardCoalition = 2          -- 1 = ROJO, 2 = AZUL
CAS.rewardText = true
CAS.rewardTextTime = 8
CAS.rewardReasonPrefix = "CAS_KILL_REWARD"

--------------------------------------------------------
-- QUE CATEGORIAS CONTAR
--------------------------------------------------------
CAS.includeInfantry = true
CAS.includeVehicles = true
CAS.includePlanes = true
CAS.includeHelicopters = true
CAS.includeShips = true

--------------------------------------------------------
-- RECOMPENSA POR CATEGORIA
-- Se usa si NO existe precio exacto en rewardByType
--------------------------------------------------------
CAS.defaultRewardByKind = {
    infantry   = 5000,
    vehicle    = 500000,
    plane      = 2000000,
    helicopter = 1000000,
    ship       = 30000000
}

--------------------------------------------------------
-- PRECIOS EXACTOS POR TIPO
-- Si un typeName esta aqui, este valor pisa el de categoria
--
-- EJEMPLOS:
-- ["T-90"] = 50000,
-- ["Tor 9A331"] = 350000,
-- ["Mi-8MT"] = 120000,
-- ["Mi-24P"] = 180000,
-- ["Su-27"] = 250000,
-- ["Su-34"] = 350000,
-- ["Moskva"] = 1500000,
--------------------------------------------------------
CAS.rewardByType = {
    -- Tierra
    -- ["T-90"] = 50000,
    -- ["Tor 9A331"] = 350000,
    -- ["Strela-10M3"] = 120000,

    -- Aviones
    -- ["MiG-29A"] = 220000,
    -- ["Su-27"] = 250000,
    -- ["Su-34"] = 350000,

    -- Helicopteros
    -- ["Mi-8MT"] = 120000,
    -- ["Mi-24P"] = 180000,

    -- Barcos
    -- ["MOLNIYA"] = 800000,
    -- ["MOSCOW"] = 1500000
}

--------------------------------------------------------
-- ESTADO
--------------------------------------------------------
CAS.state = CAS.state or {
    processed = {},
    totalKills = 0,
    totalReward = 0,
    killsByKind = {
        infantry = 0,
        vehicle = 0,
        plane = 0,
        helicopter = 0,
        ship = 0
    }
}

--------------------------------------------------------
-- DEBUG
--------------------------------------------------------
local function casDebug(msg, tiempo)
    tiempo = tiempo or 5

    if CAS.debugText then
        trigger.action.outText("[CAS DETECTOR] " .. tostring(msg), tiempo)
    end

    if CAS.debugLog then
        env.info("[CAS DETECTOR] " .. tostring(msg))
    end
end

--------------------------------------------------------
-- UTILS
--------------------------------------------------------
local function getEconomy()
    return HDEV_Economy
end

local function formatMoney(value)
    local econ = getEconomy()
    if econ and econ.formatMoney then
        return econ.formatMoney(tonumber(value) or 0)
    end

    value = math.floor(tonumber(value) or 0)
    return "$" .. tostring(value)
end

local function coalitionToText(coa)
    if coa == 1 then
        return "ROJO"
    elseif coa == 2 then
        return "AZUL"
    end
    return "NEUTRAL"
end

local function safeGetName(obj)
    if obj and obj.getName then
        local ok, res = pcall(obj.getName, obj)
        if ok and res then
            return res
        end
    end
    return "SIN_NOMBRE"
end

local function safeGetType(obj)
    if obj and obj.getTypeName then
        local ok, res = pcall(obj.getTypeName, obj)
        if ok and res then
            return res
        end
    end
    return "SIN_TIPO"
end

local function safeGetId(obj)
    if obj and obj.getID then
        local ok, res = pcall(obj.getID, obj)
        if ok and res then
            return tostring(res)
        end
    end
    return nil
end

local function safeGetPoint(obj)
    if obj and obj.getPoint then
        local ok, res = pcall(obj.getPoint, obj)
        if ok and res then
            return res
        end
    end
    return nil
end

local function safeGetCategory(obj)
    if obj and obj.getCategory then
        local ok, res = pcall(obj.getCategory, obj)
        if ok and res ~= nil then
            return res
        end
    end
    return nil
end

local function safeGetDescCategory(obj)
    if obj and obj.getDesc then
        local ok, desc = pcall(obj.getDesc, obj)
        if ok and type(desc) == "table" then
            return desc.category
        end
    end
    return nil
end

local function safeHasAttribute(obj, attr)
    if obj and obj.hasAttribute then
        local ok, res = pcall(obj.hasAttribute, obj, attr)
        if ok then
            return res == true
        end
    end
    return false
end

local function cleanupProcessedCache()
    local now = timer.getTime()
    for key, t in pairs(CAS.state.processed) do
        if (now - (t or 0)) > 7200 then
            CAS.state.processed[key] = nil
        end
    end
end

local function buildProcessedKey(obj)
    local id = safeGetId(obj)
    if id then
        return "ID:" .. id
    end

    local name = safeGetName(obj)
    local tipo = safeGetType(obj)
    local p = safeGetPoint(obj)

    local x = 0
    local z = 0
    if p then
        x = math.floor(p.x or 0)
        z = math.floor(p.z or p.y or 0)
    end

    return "FALLBACK:" .. name .. "|" .. tipo .. "|" .. tostring(x) .. "|" .. tostring(z)
end

local function alreadyProcessed(obj)
    cleanupProcessedCache()

    local key = buildProcessedKey(obj)
    if CAS.state.processed[key] then
        return true
    end

    CAS.state.processed[key] = timer.getTime()
    return false
end

--------------------------------------------------------
-- BANDERA: ON -> OFF
--------------------------------------------------------
local function fireFlagOnce()
    trigger.action.setUserFlag(CAS.flagId, 1)
    casDebug("Bandera " .. CAS.flagId .. " -> ON")

    mist.scheduleFunction(
        function()
            trigger.action.setUserFlag(CAS.flagId, 0)
            casDebug("Bandera " .. CAS.flagId .. " -> OFF")
        end,
        {},
        timer.getTime() + 1
    )
end

--------------------------------------------------------
-- CLASIFICACION DE UNIDAD
--------------------------------------------------------
local function classifyObject(obj)
    if safeHasAttribute(obj, "Infantry") or safeHasAttribute(obj, "Soldier") then
        return "infantry"
    end

    if safeHasAttribute(obj, "Helicopters") then
        return "helicopter"
    end

    if safeHasAttribute(obj, "Planes") then
        return "plane"
    end

    if safeHasAttribute(obj, "Ships")
        or safeHasAttribute(obj, "Armed ships")
        or safeHasAttribute(obj, "Heavy armed ships") then
        return "ship"
    end

    local descCategory = safeGetDescCategory(obj)

    if Unit and Unit.Category then
        if descCategory == Unit.Category.HELICOPTER then
            return "helicopter"
        elseif descCategory == Unit.Category.AIRPLANE then
            return "plane"
        elseif descCategory == Unit.Category.SHIP then
            return "ship"
        elseif descCategory == Unit.Category.GROUND_UNIT then
            if safeHasAttribute(obj, "Infantry") then
                return "infantry"
            end
            return "vehicle"
        end
    end

    return "vehicle"
end

local function isKindEnabled(kind)
    if kind == "infantry" then
        return CAS.includeInfantry
    elseif kind == "vehicle" then
        return CAS.includeVehicles
    elseif kind == "plane" then
        return CAS.includePlanes
    elseif kind == "helicopter" then
        return CAS.includeHelicopters
    elseif kind == "ship" then
        return CAS.includeShips
    end
    return false
end

local function getRewardForKill(kind, typeName)
    if CAS.rewardByType[typeName] ~= nil then
        return tonumber(CAS.rewardByType[typeName]) or 0
    end

    return tonumber(CAS.defaultRewardByKind[kind]) or 0
end

--------------------------------------------------------
-- CONTABILIDAD LOCAL
--------------------------------------------------------
local function registerKill(kind, amount)
    CAS.state.totalKills = (CAS.state.totalKills or 0) + 1
    CAS.state.totalReward = (CAS.state.totalReward or 0) + (tonumber(amount) or 0)

    CAS.state.killsByKind[kind] = (CAS.state.killsByKind[kind] or 0) + 1
end

--------------------------------------------------------
-- PAGO ECONOMICO
--------------------------------------------------------
local function payReward(kind, typeName, objName)
    local amount = getRewardForKill(kind, typeName)

    if amount <= 0 then
        return 0
    end

    if not CAS.useEconomy then
        return amount
    end

    local econ = getEconomy()
    if not econ or not econ.add then
        casDebug("HDEV_Economy no disponible. No se pudo pagar " .. tostring(typeName), 10)
        return 0
    end

    local coalitionReward = tonumber(CAS.rewardCoalition) or 2
    if coalitionReward ~= 1 and coalitionReward ~= 2 then
        coalitionReward = 2
    end

    local reason =
        tostring(CAS.rewardReasonPrefix) ..
        " | kind=" .. tostring(kind) ..
        " | type=" .. tostring(typeName) ..
        " | unit=" .. tostring(objName)

    local before = econ.get and econ.get(coalitionReward) or 0
    local after = econ.add(coalitionReward, amount, reason)

    if CAS.rewardText then
        trigger.action.outTextForCoalition(
            coalitionReward,
            "Recompensa por baja\n" ..
            "Unidad: " .. tostring(objName) .. "\n" ..
            "Tipo: " .. tostring(typeName) .. "\n" ..
            "Categoria: " .. tostring(kind) .. "\n" ..
            "Pago: " .. formatMoney(amount) .. "\n" ..
            "Saldo: " .. formatMoney(after or before),
            CAS.rewardTextTime
        )
    end

    casDebug(
        "Pago realizado a " .. coalitionToText(coalitionReward) ..
        " | " .. tostring(objName) ..
        " | " .. tostring(typeName) ..
        " | " .. tostring(kind) ..
        " | monto=" .. formatMoney(amount) ..
        " | saldoAntes=" .. formatMoney(before) ..
        " | saldoDespues=" .. formatMoney(after or before),
        8
    )

    return amount
end

--------------------------------------------------------
-- MANEJO DE MUERTE / CRASH DE OBJETO
--------------------------------------------------------
local function handleDeadObject(obj, eventId)
    if not obj then
        casDebug("handleDeadObject: obj es nil")
        return
    end

    local category = safeGetCategory(obj)
    if category ~= Object.Category.UNIT then
        return
    end

    if not obj.getCoalition then
        casDebug("Objeto UNIT sin getCoalition, ignorado")
        return
    end

    local coal = obj:getCoalition()
    if coal ~= coalition.side.RED then
        return
    end

    local pos = safeGetPoint(obj)
    if not pos then
        casDebug("Unidad roja sin posicion, ignorada")
        return
    end

    if not mist.pointInZone then
        casDebug("ERROR: mist.pointInZone no disponible")
        return
    end

    local enZona = mist.pointInZone(pos, CAS.zoneName)
    if not enZona then
        return
    end

    if alreadyProcessed(obj) then
        casDebug("Objeto ya procesado, se evita doble conteo: " .. safeGetName(obj))
        return
    end

    local name = safeGetName(obj)
    local typeName = safeGetType(obj)
    local kind = classifyObject(obj)

    if not isKindEnabled(kind) then
        casDebug("Baja ignorada por configuracion: " .. tostring(name) .. " | " .. tostring(kind))
        return
    end

    fireFlagOnce()

    local rewardPaid = payReward(kind, typeName, name)
    registerKill(kind, rewardPaid)

    casDebug(
        "Baja roja contabilizada" ..
        " | evento=" .. tostring(eventId) ..
        " | unidad=" .. tostring(name) ..
        " | tipo=" .. tostring(typeName) ..
        " | categoria=" .. tostring(kind) ..
        " | pago=" .. formatMoney(rewardPaid) ..
        " | bajasTotales=" .. tostring(CAS.state.totalKills) ..
        " | pagoTotal=" .. formatMoney(CAS.state.totalReward),
        8
    )
end

--------------------------------------------------------
-- EVENT HANDLER
--------------------------------------------------------
local casHandler = {}

function casHandler:onEvent(event)
    if not event or not event.id then
        return
    end

    if event.id ~= world.event.S_EVENT_DEAD
        and event.id ~= world.event.S_EVENT_CRASH then
        return
    end

    local obj = event.initiator or event.target
    if not obj then
        casDebug("Evento sin initiator ni target validos")
        return
    end

    handleDeadObject(obj, event.id)
end

world.addEventHandler(casHandler)

--------------------------------------------------------
-- INICIO
--------------------------------------------------------
if CAS.useEconomy and not HDEV_Economy then
    casDebug("ADVERTENCIA: HDEV_EconomyCore aun no esta cargado. El detector seguira vivo, pero no pagara hasta que el core exista.", 12)
end

casDebug(
    "Detector CAS inicializado" ..
    " | zona=" .. tostring(CAS.zoneName) ..
    " | bandera=" .. tostring(CAS.flagId) ..
    " | economia=" .. tostring(CAS.useEconomy) ..
    " | coalicionPago=" .. coalitionToText(CAS.rewardCoalition),
    10
)