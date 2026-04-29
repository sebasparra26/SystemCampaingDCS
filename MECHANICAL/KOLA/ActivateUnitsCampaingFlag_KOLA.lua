if not mist then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

if not ctld then
    trigger.action.outText("ERROR: CTLD no esta cargado.", 15)
    return
end

HDEV_ActivateCTLDByFlag = HDEV_ActivateCTLDByFlag or {}
local SYS = HDEV_ActivateCTLDByFlag

SYS.CONFIG = {
    debug = false,
    checkInterval = 1,
    preloadDelay = 2
}

----------------------------------------------------------------
-- CONFIGURACION
--
-- IMPORTANTE:
-- groupName = nombre exacto del grupo en el ME
-- unitNames = nombres exactos de las UNIDADES de ese grupo para CTLD
--
-- preloadTroops:
-- true  = precarga tropas
-- false = precarga vehiculos
----------------------------------------------------------------
SYS.ACTIVATIONS = {
    {
        flag = 121,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_1",
                unitNames = { "helicargo1" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 121,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_2",
                unitNames = { "helicargo2" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
     {
        flag = 114,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_3",
                unitNames = { "helicargo3" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
     {
        flag = 115,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_4",
                unitNames = { "helicargo4" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 119,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_5",
                unitNames = { "helicargo5" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 120,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_6",
                unitNames = { "helicargo6" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 112,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_7",
                unitNames = { "helicargo7" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 133,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_8",
                unitNames = { "helicargo8" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 116,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_9",
                unitNames = { "helicargo9" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 135,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_10",
                unitNames = { "helicargo10" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 134,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_11",
                unitNames = { "helicargo11" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 123,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_12",
                unitNames = { "helicargo12" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 126,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_13",
                unitNames = { "helicargo13" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 102,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_14",
                unitNames = { "helicargo14" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 109,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_15",
                unitNames = { "helicargo15" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    },
    {
        flag = 124,
        value = 2,
        groups = {
            {
                groupName = "Grupo_HeliCargo_16",
                unitNames = { "helicargo16" },
                ctldEnabled = true,
                preloadEnabled = true,
                preloadAmount = 1,
                preloadTroops = false
            },

        }
    }

}

----------------------------------------------------------------
-- MODULO RANDOM
--
-- EJEMPLO:
-- Si flag 5000 = 1
-- entonces resultFlag 300 = random entre 1 y 10
-- y despues de 1 segundo vuelve a 0
--
-- resetTriggerFlag = true
-- si quieres que la bandera disparadora tambien vuelva a 0
----------------------------------------------------------------
SYS.RANDOM_FLAGS = {
    {
        flag = 901,
        triggerValue = 1,
        resultFlag = 900,
        min = 1,
        max = 13,
        duration = 1,
        resetTriggerFlag = false
    },

    -- Ejemplo:
    -- {
    --     flag = 5001,
    --     triggerValue = 1,
    --     resultFlag = 301,
    --     min = 20,
    --     max = 50,
    --     duration = 1,
    --     resetTriggerFlag = true
    -- },
}

SYS.STATE = SYS.STATE or {
    prevFlags = {},
    groups = {},
    prevRandomFlags = {}
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg, tiempo)
    env.info("[ACTIVATE_CTLD_FLAG] " .. tostring(msg))
    if SYS.CONFIG.debug then
        trigger.action.outText("[ACTIVATE_CTLD_FLAG] " .. tostring(msg), tiempo or 8)
    end
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function getFlagValue(flag)
    return tonumber(trigger.misc.getUserFlag(flag)) or 0
end

local function toList(v)
    if not v then
        return {}
    end
    if type(v) == "table" then
        return v
    end
    return { v }
end

local function groupExistsByName(groupName)
    if not groupName or groupName == "" then
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
    local grp = groupExistsByName(groupName)
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

local function destroyGroupIfExists(groupName)
    local grp = groupExistsByName(groupName)
    if grp then
        pcall(function()
            grp:destroy()
        end)
    end
end

local function getState(groupName)
    SYS.STATE.groups[groupName] = SYS.STATE.groups[groupName] or {
        spawnedOnce = false
    }
    return SYS.STATE.groups[groupName]
end

----------------------------------------------------------------
-- CTLD
----------------------------------------------------------------
local function ensureCtldUnitRegistered(unitName)
    if not unitName or unitName == "" then
        return
    end

    ctld.transportPilotNames = ctld.transportPilotNames or {}

    for _, existing in ipairs(ctld.transportPilotNames) do
        if existing == unitName then
            return
        end
    end

    table.insert(ctld.transportPilotNames, unitName)
    log("Unidad agregada a ctld.transportPilotNames: " .. tostring(unitName), 5)
end

local function applyCtldToEntry(entry)
    if not entry then
        return
    end

    local unitNames = toList(entry.unitNames)
    local delay = tonumber(entry.preloadDelay) or SYS.CONFIG.preloadDelay or 2

    timer.scheduleFunction(function()
        for _, unitName in ipairs(unitNames) do
            if entry.ctldEnabled then
                ensureCtldUnitRegistered(unitName)
            end

            if entry.preloadEnabled and ctld.preLoadTransport then
                local ok, err = pcall(function()
                    ctld.preLoadTransport(
                        unitName,
                        tonumber(entry.preloadAmount) or 1,
                        entry.preloadTroops == true
                    )
                end)

                if ok then
                    log(
                        "CTLD preload aplicado a " .. tostring(unitName) ..
                        " | amount=" .. tostring(tonumber(entry.preloadAmount) or 1) ..
                        " | troops=" .. tostring(entry.preloadTroops == true),
                        6
                    )
                else
                    log("ERROR en ctld.preLoadTransport para " .. tostring(unitName) .. ": " .. tostring(err), 8)
                end
            end
        end
    end, nil, timer.getTime() + delay)
end

----------------------------------------------------------------
-- ACTIVACION ORIGINAL
----------------------------------------------------------------
local function activateOriginalGroup(groupName, flag)
    if not groupName or groupName == "" then
        return false
    end

    local grp = Group.getByName(groupName)
    if not grp then
        log("No existe grupo en el ME: " .. tostring(groupName), 10)
        return false
    end

    local ok, err = pcall(function()
        trigger.action.activateGroup(grp)
    end)

    if ok then
        log("Grupo activado por flag " .. tostring(flag) .. ": " .. tostring(groupName), 10)
        return true
    end

    log("ERROR activando grupo '" .. tostring(groupName) .. "' por flag " .. tostring(flag) .. ": " .. tostring(err), 10)
    return false
end

----------------------------------------------------------------
-- RESPWAN MISMO NOMBRE
----------------------------------------------------------------
local function buildGroupDataForRespawn(groupName)
    local data = mist.getGroupData(groupName, true)
    if not data then
        return nil, "mist.getGroupData no encontro la plantilla: " .. tostring(groupName)
    end

    data.name = groupName
    data.groupName = groupName
    data.groupId = mist.getNextGroupId()

    for i, unit in pairs(data.units or {}) do
        local originalUnitName = unit.unitName or unit.name or (groupName .. "_UNIT_" .. tostring(i))

        unit.unitId = mist.getNextUnitId()
        unit.unitName = originalUnitName
        unit.name = originalUnitName
    end

    return data
end

local function respawnSameName(groupName, flag)
    destroyGroupIfExists(groupName)

    local data, err = buildGroupDataForRespawn(groupName)
    if not data then
        log("ERROR preparando respawn de '" .. tostring(groupName) .. "': " .. tostring(err), 10)
        return false
    end

    local ok, result = pcall(function()
        return mist.dynAdd(data)
    end)

    if not ok or not result then
        log("ERROR en mist.dynAdd para '" .. tostring(groupName) .. "': " .. tostring(result), 10)
        return false
    end

    log("Grupo respawneado con mismo nombre por flag " .. tostring(flag) .. ": " .. tostring(groupName), 10)
    return true
end

----------------------------------------------------------------
-- ORQUESTACION
----------------------------------------------------------------
local function processGroupEntry(entry, flag)
    if not entry or not entry.groupName then
        return
    end

    local state = getState(entry.groupName)

    -- MUY IMPORTANTE:
    -- la primera vez NO revisamos "si esta vivo" antes de activar,
    -- porque eso fue lo que rompio la activacion en Late Activation.
    if not state.spawnedOnce then
        local ok = activateOriginalGroup(entry.groupName, flag)
        if ok then
            state.spawnedOnce = true
            applyCtldToEntry(entry)
        end
        return
    end

    -- Desde la segunda vez en adelante, si sigue vivo no hacemos nada.
    if groupHasAliveUnits(entry.groupName) then
        log("El grupo sigue vivo, no se respawnea: " .. tostring(entry.groupName), 5)
        return
    end

    -- Si ya fue activado alguna vez y ya murio, lo recreamos con mismo nombre.
    local ok = respawnSameName(entry.groupName, flag)
    if ok then
        applyCtldToEntry(entry)
    end
end

local function processActivationBlock(block)
    local currentValue = getFlagValue(block.flag)
    local previousValue = SYS.STATE.prevFlags[block.flag]
    local targetValue = tonumber(block.value) or 1

    if previousValue == nil then
        previousValue = -999999
    end

    if currentValue ~= previousValue then
        SYS.STATE.prevFlags[block.flag] = currentValue

        if currentValue == targetValue then
            local groups = toList(block.groups)

            log(
                "Bandera " .. tostring(block.flag) ..
                " entro en valor objetivo " .. tostring(targetValue),
                6
            )

            for _, entry in ipairs(groups) do
                processGroupEntry(entry, block.flag)
            end
        end
    end
end

----------------------------------------------------------------
-- RANDOM
----------------------------------------------------------------
local function resetRandomResultFlag(args)
    if not args or not args.resultFlag then
        return nil
    end

    trigger.action.setUserFlag(args.resultFlag, 0)
    log("Random reset -> flag " .. tostring(args.resultFlag) .. " = 0", 5)
    return nil
end

local function processRandomBlock(block)
    local currentValue = getFlagValue(block.flag)
    local previousValue = SYS.STATE.prevRandomFlags[block.flag]
    local targetValue = tonumber(block.triggerValue) or 1

    if previousValue == nil then
        previousValue = -999999
    end

    if currentValue ~= previousValue then
        SYS.STATE.prevRandomFlags[block.flag] = currentValue

        if currentValue == targetValue then
            local min = tonumber(block.min) or 1
            local max = tonumber(block.max) or min
            local duration = tonumber(block.duration) or 1

            if max < min then
                max = min
            end

            local result = math.random(min, max)

            trigger.action.setUserFlag(block.resultFlag, result)

            if block.resetTriggerFlag == true then
                trigger.action.setUserFlag(block.flag, 0)
            end

            timer.scheduleFunction(
                resetRandomResultFlag,
                { resultFlag = block.resultFlag },
                timer.getTime() + duration
            )

            log(
                "RANDOM | flag " .. tostring(block.flag) ..
                " -> resultFlag " .. tostring(block.resultFlag) ..
                " = " .. tostring(result) ..
                " | reset en " .. tostring(duration) .. "s",
                8
            )
        end
    end
end

local function mainLoop()
    for _, block in ipairs(SYS.ACTIVATIONS or {}) do
        processActivationBlock(block)
    end

    for _, block in ipairs(SYS.RANDOM_FLAGS or {}) do
        local ok, err = pcall(function()
            processRandomBlock(block)
        end)

        if not ok then
            log("ERROR en modulo random: " .. tostring(err), 10)
        end
    end

    return timer.getTime() + (tonumber(SYS.CONFIG.checkInterval) or 1)
end

log("Sistema de activacion CTLD por bandera cargado.", 8)
timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)