----------------------------------------------------------------
-- HDEV_MissileZoneDetector.lua
--
-- Detecta misiles enemigos entrando en zonas.
--
-- Funcion:
-- 1. Escucha S_EVENT_SHOT.
-- 2. Si el disparo es un misil de la coalicion enemiga configurada,
--    lo guarda en seguimiento.
-- 3. Revisa su posicion cada cierto tiempo.
-- 4. Si entra en una zona configurada:
--      bandera = 1
--      espera 1 segundo
--      bandera = 0
--
-- Requiere:
-- - MIST cargado antes
----------------------------------------------------------------

if not mist or not mist.pointInZone then
    trigger.action.outText("ERROR: MIST no esta cargado o falta mist.pointInZone.", 15)
    return
end

HDEV_MissileZoneDetector = HDEV_MissileZoneDetector or {}
local MZD = HDEV_MissileZoneDetector

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------
MZD.CONFIG = {
    debugText = true,
    debugLog = true,

    -- Cada cuanto revisar la posicion de los misiles activos
    checkInterval = 0.2,

    -- Tiempo que la bandera queda encendida
    flagPulseSeconds = 1,

    -- Coalicion enemiga que dispara el misil
    -- coalition.side.RED  = rojo
    -- coalition.side.BLUE = azul
    enemyCoalition = coalition.side.RED,

    -- Si true, cualquier misil detectado sirve.
    -- Si false, solo detecta los tipos incluidos en missileTypes.
    detectAnyMissile = false,

    -- Tipos de misiles a detectar.
    -- El nombre debe coincidir con weapon:getTypeName().
    missileTypes = {
        ["9M723"] = true,
        ["X_31P"] = true,
        ["X_101"] = true,
       

    },

    -- Zonas a vigilar.
    -- zoneName = nombre exacto de la zona en el Mission Editor.
    -- flag = bandera que se prende cuando el misil entra.
    zones = {
        {
            zoneName = "MONITOREO2",
            flag = 9001,
            enabled = true
        },

        --{
         --   zoneName = "ZONA_MISIL_2",
         --   flag = 9002,
          --  enabled = true
        --},

        -- Puedes agregar mas:
        -- {
        --     zoneName = "ZONA_BASE_AEREA",
        --     flag = 9003,
        --     enabled = true
        -- },
    }
}

----------------------------------------------------------------
-- ESTADO INTERNO
----------------------------------------------------------------
MZD.STATE = MZD.STATE or {
    started = false,
    trackedWeapons = {},
    nextId = 1
}

----------------------------------------------------------------
-- DEBUG
----------------------------------------------------------------
local function log(msg, tiempo)
    msg = tostring(msg)

    if MZD.CONFIG.debugLog then
        env.info("[MISSILE_ZONE_DETECTOR] " .. msg)
    end

    if MZD.CONFIG.debugText then
        trigger.action.outText("[MISSILE_ZONE_DETECTOR] " .. msg, tiempo or 5)
    end
end

----------------------------------------------------------------
-- UTILIDADES SEGURAS
----------------------------------------------------------------
local function safeCall(obj, methodName)
    if not obj or not obj[methodName] then
        return nil
    end

    local ok, result = pcall(function()
        return obj[methodName](obj)
    end)

    if ok then
        return result
    end

    return nil
end

local function objectExists(obj)
    if not obj then
        return false
    end

    if not obj.isExist then
        return false
    end

    local ok, result = pcall(function()
        return obj:isExist()
    end)

    return ok and result == true
end

local function getObjectPoint(obj)
    if not objectExists(obj) then
        return nil
    end

    return safeCall(obj, "getPoint")
end

local function getObjectTypeName(obj)
    local t = safeCall(obj, "getTypeName")
    if t and t ~= "" then
        return t
    end
    return "UNKNOWN"
end

local function getObjectName(obj)
    local n = safeCall(obj, "getName")
    if n and n ~= "" then
        return n
    end
    return "UNKNOWN"
end

local function getInitiatorCoalition(obj)
    if not obj or not obj.getCoalition then
        return nil
    end

    local ok, result = pcall(function()
        return obj:getCoalition()
    end)

    if ok then
        return result
    end

    return nil
end

local function isMissileWeapon(weapon)
    if not weapon or not weapon.getDesc then
        return false
    end

    local ok, desc = pcall(function()
        return weapon:getDesc()
    end)

    if not ok or type(desc) ~= "table" then
        return false
    end

    if Weapon and Weapon.Category and desc.category == Weapon.Category.MISSILE then
        return true
    end

    return false
end

local function isAllowedMissile(typeName)
    if MZD.CONFIG.detectAnyMissile then
        return true
    end

    return MZD.CONFIG.missileTypes[typeName] == true
end

local function fireFlagPulse(flag, zoneName, missileType)
    flag = tonumber(flag)
    if not flag then
        return
    end

    trigger.action.setUserFlag(flag, 1)

    log(
        "Bandera " .. tostring(flag) ..
        " ON. Misil " .. tostring(missileType) ..
        " entro en zona " .. tostring(zoneName),
        6
    )

    timer.scheduleFunction(function()
        trigger.action.setUserFlag(flag, 0)

        log(
            "Bandera " .. tostring(flag) ..
            " OFF. Reset automatico.",
            4
        )

        return nil
    end, {}, timer.getTime() + (tonumber(MZD.CONFIG.flagPulseSeconds) or 1))
end

----------------------------------------------------------------
-- REGISTRAR MISIL
----------------------------------------------------------------
local function trackMissile(event)
    if not event or not event.weapon then
        return
    end

    local initiator = event.initiator
    if not initiator then
        return
    end

    local initiatorCoalition = getInitiatorCoalition(initiator)

    if initiatorCoalition ~= MZD.CONFIG.enemyCoalition then
        return
    end

    local weapon = event.weapon

    if not isMissileWeapon(weapon) then
        return
    end

    local missileType = getObjectTypeName(weapon)

    if not isAllowedMissile(missileType) then
        log("Misil ignorado por filtro: " .. tostring(missileType), 5)
        return
    end

    local shooterName = getObjectName(initiator)

    local id = MZD.STATE.nextId
    MZD.STATE.nextId = MZD.STATE.nextId + 1

    MZD.STATE.trackedWeapons[id] = {
        id = id,
        weapon = weapon,
        missileType = missileType,
        shooterName = shooterName,
        shooterCoalition = initiatorCoalition,
        createdAt = timer.getTime(),
        triggeredZones = {}
    }

    log(
        "Misil detectado: " .. tostring(missileType) ..
        " disparado por " .. tostring(shooterName) ..
        ". ID interno: " .. tostring(id),
        6
    )
end

----------------------------------------------------------------
-- REVISION DE MISILES ACTIVOS
----------------------------------------------------------------
local function checkTrackedMissiles()
    local now = timer.getTime()

    for id, data in pairs(MZD.STATE.trackedWeapons) do
        local weapon = data.weapon

        if not objectExists(weapon) then
            MZD.STATE.trackedWeapons[id] = nil
        else
            local point = getObjectPoint(weapon)

            if not point then
                MZD.STATE.trackedWeapons[id] = nil
            else
                for _, zoneCfg in ipairs(MZD.CONFIG.zones or {}) do
                    if zoneCfg.enabled ~= false and zoneCfg.zoneName and zoneCfg.flag then
                        local zoneName = zoneCfg.zoneName

                        if not data.triggeredZones[zoneName] then
                            local inside = false

                            local ok, result = pcall(function()
                                return mist.pointInZone(point, zoneName)
                            end)

                            if ok then
                                inside = result == true
                            else
                                log("Error revisando zona: " .. tostring(zoneName), 6)
                            end

                            if inside then
                                data.triggeredZones[zoneName] = true

                                fireFlagPulse(
                                    zoneCfg.flag,
                                    zoneName,
                                    data.missileType
                                )

                                -- Si quieres que el mismo misil pueda activar varias zonas,
                                -- comenta la siguiente linea.
                                MZD.STATE.trackedWeapons[id] = nil
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return now + (tonumber(MZD.CONFIG.checkInterval) or 0.2)
end

----------------------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------------------
local missileHandler = {}

function missileHandler:onEvent(event)
    if not event or not event.id then
        return
    end

    if event.id == world.event.S_EVENT_SHOT then
        trackMissile(event)
    end
end

----------------------------------------------------------------
-- INICIO
----------------------------------------------------------------
local function startSystem()
    if MZD.STATE.started then
        return
    end

    MZD.STATE.started = true

    world.addEventHandler(missileHandler)

    timer.scheduleFunction(function()
        return checkTrackedMissiles()
    end, {}, timer.getTime() + 1)

    log("Sistema iniciado correctamente.", 8)
end

startSystem()