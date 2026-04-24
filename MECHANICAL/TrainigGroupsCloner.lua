----------------------------------------------------------------
-- Respawn simple de grupos con MIST
-- Clona grupos plantilla y los vuelve a clonar cuando mueren completos
----------------------------------------------------------------

if not mist or not mist.cloneGroup then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------

local DEBUG = false

local CHECK_INTERVAL = 60          -- cada cuantos segundos revisa si murio el grupo
local RESPAWN_DELAY = 30          -- segundos antes de volver a clonar
local CLONE_AT_START = true       -- true = clona al iniciar la mision

-- Grupos plantilla del Mission Editor
-- Recomendado: ponerlos en Late Activation
local TEMPLATES = {
    "Poligon01",
    "Poligon02",
    "Poligon03",
    "Poligon04",
    "Poligon05"
}

----------------------------------------------------------------
-- ESTADO INTERNO
----------------------------------------------------------------

local state = {}

----------------------------------------------------------------
-- DEBUG
----------------------------------------------------------------

local function debug(msg, time)
    env.info("[MIST_RESPAWN] " .. tostring(msg))

    if DEBUG then
        trigger.action.outText("[MIST_RESPAWN] " .. tostring(msg), time or 5)
    end
end

----------------------------------------------------------------
-- UTILIDADES
----------------------------------------------------------------

local function extractCloneName(clonedData)
    if type(clonedData) == "string" then
        return clonedData
    end

    if type(clonedData) == "table" then
        return clonedData.groupName or clonedData.name
    end

    return nil
end

local function groupExists(groupName)
    if not groupName then
        return nil
    end

    local grp = Group.getByName(groupName)
    if not grp then
        return nil
    end

    local ok, exists = pcall(function()
        return grp:isExist()
    end)

    if ok and exists then
        return grp
    end

    return nil
end

local function unitAlive(unit)
    if not unit then
        return false
    end

    local okExist, exists = pcall(function()
        return unit:isExist()
    end)

    if not okExist or not exists then
        return false
    end

    local okLife, life = pcall(function()
        return unit:getLife()
    end)

    if not okLife then
        return false
    end

    return (tonumber(life) or 0) > 0
end

local function groupHasAliveUnits(groupName)
    local grp = groupExists(groupName)
    if not grp then
        return false
    end

    local units = grp:getUnits() or {}

    for _, unit in ipairs(units) do
        if unitAlive(unit) then
            return true
        end
    end

    return false
end

----------------------------------------------------------------
-- CLONAR GRUPO
----------------------------------------------------------------

local function spawnClone(templateName)
    state[templateName] = state[templateName] or {
        activeCloneName = nil,
        respawnScheduled = false
    }

    local data = state[templateName]

    local ok, clonedData = pcall(function()
        -- true intenta conservar ruta/tareas del grupo plantilla
        return mist.cloneGroup(templateName, true)
    end)

    if not ok or not clonedData then
        debug("ERROR clonando template: " .. tostring(templateName), 10)
        data.activeCloneName = nil
        data.respawnScheduled = false
        return
    end

    local cloneName = extractCloneName(clonedData)

    if not cloneName then
        debug("ERROR: no se pudo obtener el nombre del clon de " .. tostring(templateName), 10)
        data.activeCloneName = nil
        data.respawnScheduled = false
        return
    end

    data.activeCloneName = cloneName
    data.respawnScheduled = false

    debug("Clonado: " .. tostring(templateName) .. " -> " .. tostring(cloneName), 6)
end

----------------------------------------------------------------
-- PROGRAMAR RESPAWN
----------------------------------------------------------------

local function scheduleRespawn(templateName)
    local data = state[templateName]
    if not data then
        return
    end

    if data.respawnScheduled then
        return
    end

    data.respawnScheduled = true

    debug("Grupo destruido completo: " .. tostring(data.activeCloneName) .. ". Respawn en " .. tostring(RESPAWN_DELAY) .. " segundos.", 8)

    mist.scheduleFunction(
        function()
            spawnClone(templateName)
        end,
        {},
        timer.getTime() + RESPAWN_DELAY
    )
end

----------------------------------------------------------------
-- LOOP DE REVISION
----------------------------------------------------------------

local function checkGroups()
    for _, templateName in ipairs(TEMPLATES) do
        state[templateName] = state[templateName] or {
            activeCloneName = nil,
            respawnScheduled = false
        }

        local data = state[templateName]

        if data.activeCloneName then
            local alive = groupHasAliveUnits(data.activeCloneName)

            if not alive then
                scheduleRespawn(templateName)
            end
        end
    end

    return timer.getTime() + CHECK_INTERVAL
end

----------------------------------------------------------------
-- INICIO
----------------------------------------------------------------

local function startSystem()
    debug("Sistema de respawn con MIST iniciado.", 8)

    if CLONE_AT_START then
        for _, templateName in ipairs(TEMPLATES) do
            spawnClone(templateName)
        end
    end

    timer.scheduleFunction(checkGroups, {}, timer.getTime() + CHECK_INTERVAL)
end

timer.scheduleFunction(
    function()
        startSystem()
    end,
    {},
    timer.getTime() + 2
)