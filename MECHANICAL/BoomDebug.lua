----------------------------------------------------------------
-- DEBUG POR MARCAS F10
-- COMANDOS:
--
-- 1) EXPLOSION
--    boom 1000 15
--    boom 500 2
--
-- 2) SPAWN VEHICULO TERRESTRE
--    tank red
--    tank blue
--    tank red T-72B3
--    spawn red T-90
--    spawn blue M1A2C_SEP_V3
--    unit blue M1097 Avenger
--
-- NOTA:
-- - Esta version spawnea SOLO vehiculos terrestres.
-- - "tank red" usa el default rojo.
-- - "tank blue" usa el default azul.
-- - "spawn" y "unit" requieren el nombre tecnico.
----------------------------------------------------------------

HDEV_MarkDebug = HDEV_MarkDebug or {}
local MD = HDEV_MarkDebug

MD.CONFIG = {
    DEBUG = false,
    AUTO_REMOVE_MARK = true,
    MESSAGE_TIME = 8,

    ----------------------------------------------------------------
    -- BOOM
    ----------------------------------------------------------------
    BOOM_KEYWORD = "boom",
    DEFAULT_BOOM_DELAY = 0,
    MIN_BOOM_POWER = 1,
    MAX_BOOM_POWER = 100000,

    ----------------------------------------------------------------
    -- SPAWN
    ----------------------------------------------------------------
    DEFAULT_HEADING_DEG = 0,
    SPAWN_CATEGORY = Group.Category.GROUND,

    SIDES = {
        red = {
            label = "ROJO",
            aliases = { "red", "rojo", "r" },
            countryId = country.id.RUSSIA,
            defaultTank = "T-90"
        },
        blue = {
            label = "AZUL",
            aliases = { "blue", "azul", "b" },
            countryId = country.id.USA,
            defaultTank = "M1A2C_SEP_V3"
        }
    }
}

MD.STATE = MD.STATE or {
    processedMarks = {},
    nextSpawnId = 1
}

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function debugMsg(msg, t)
    if MD.CONFIG.DEBUG then
        trigger.action.outText("[MARK DEBUG] " .. tostring(msg), t or MD.CONFIG.MESSAGE_TIME)
    end
end

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeSpaces(s)
    return trim((s or ""):gsub("%s+", " "))
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function splitWords(s)
    local out = {}
    for token in string.gmatch(normalizeSpaces(s or ""), "%S+") do
        out[#out + 1] = token
    end
    return out
end

local function clamp(v, minV, maxV)
    v = tonumber(v) or 0
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    return v
end

local function sanitizeName(s)
    s = tostring(s or "OBJ")
    s = s:gsub("[%s%-/\\]+", "_")
    s = s:gsub("[^%w_]", "")
    if s == "" then
        s = "OBJ"
    end
    return s
end

local function resolveMarkPoint(event)
    if event and event.pos then
        local z = event.pos.z or event.pos.y
        return {
            x = event.pos.x,
            y = event.pos.y or 0,
            z = z
        }
    end

    if mist
        and mist.DBs
        and mist.DBs.markList
        and event
        and event.idx
        and mist.DBs.markList[event.idx]
        and mist.DBs.markList[event.idx].pos then

        local p = mist.DBs.markList[event.idx].pos
        local z = p.z or p.y
        return {
            x = p.x,
            y = p.y or 0,
            z = z
        }
    end

    return nil
end

local function pointToGround(point)
    if not point then return nil end

    local x = point.x
    local z = point.z or point.y
    local groundY = 0

    if land and land.getHeight then
        groundY = land.getHeight({ x = x, y = z }) or 0
    end

    return {
        x = x,
        y = groundY,
        z = z
    }
end

local function buildSignature(text, point)
    return table.concat({
        lower(normalizeSpaces(text)),
        tostring(math.floor((point and point.x) or 0)),
        tostring(math.floor((point and (point.z or point.y)) or 0))
    }, "|")
end

local function resolveSide(sideToken)
    local token = lower(sideToken)

    for sideKey, sideCfg in pairs(MD.CONFIG.SIDES) do
        for i = 1, #(sideCfg.aliases or {}) do
            if token == lower(sideCfg.aliases[i]) then
                return sideKey, sideCfg
            end
        end
    end

    return nil, nil
end

----------------------------------------------------------------
-- PARSER BOOM
----------------------------------------------------------------
local function parseBoomCommand(text)
    local raw = normalizeSpaces(text)
    local parts = splitWords(raw)

    if #parts == 0 then
        return nil, nil
    end

    if lower(parts[1]) ~= MD.CONFIG.BOOM_KEYWORD then
        return nil, nil
    end

    if not parts[2] then
        return nil, "Falta la potencia. Ejemplo: boom 1000 15"
    end

    local power = tonumber(parts[2])
    if not power then
        return nil, "La potencia no es valida. Ejemplo: boom 1000 15"
    end

    local delay = MD.CONFIG.DEFAULT_BOOM_DELAY
    if parts[3] ~= nil then
        delay = tonumber(parts[3])
        if delay == nil then
            return nil, "El delay no es valido. Ejemplo: boom 1000 15"
        end
    end

    power = clamp(power, MD.CONFIG.MIN_BOOM_POWER, MD.CONFIG.MAX_BOOM_POWER)
    delay = math.max(0, delay)

    return {
        kind = "boom",
        power = power,
        delay = delay,
        rawText = raw
    }, nil
end

----------------------------------------------------------------
-- PARSER SPAWN
----------------------------------------------------------------
local function parseSpawnCommand(text)
    local raw = normalizeSpaces(text)
    local parts = splitWords(raw)

    if #parts == 0 then
        return nil, nil
    end

    local keyword = lower(parts[1])

    if keyword ~= "tank" and keyword ~= "spawn" and keyword ~= "unit" then
        return nil, nil
    end

    if not parts[2] then
        return nil, "Falta el lado. Ejemplo: tank red o spawn blue M1A2C_SEP_V3"
    end

    local sideKey, sideCfg = resolveSide(parts[2])
    if not sideCfg then
        return nil, "Lado invalido. Usa red/rojo o blue/azul."
    end

    local unitType = nil

    if keyword == "tank" then
        if #parts >= 3 then
            unitType = table.concat(parts, " ", 3)
        else
            unitType = sideCfg.defaultTank
        end
    else
        if #parts < 3 then
            return nil, "Falta el nombre tecnico. Ejemplo: spawn red T-90"
        end
        unitType = table.concat(parts, " ", 3)
    end

    unitType = trim(unitType)
    if unitType == "" then
        return nil, "El nombre tecnico esta vacio."
    end

    return {
        kind = "spawn",
        spawnKeyword = keyword,
        sideKey = sideKey,
        sideCfg = sideCfg,
        unitType = unitType,
        rawText = raw
    }, nil
end

local function parseAnyCommand(text)
    local cmd, err = parseBoomCommand(text)
    if cmd or err then
        return cmd, err
    end

    cmd, err = parseSpawnCommand(text)
    if cmd or err then
        return cmd, err
    end

    return nil, nil
end

----------------------------------------------------------------
-- BOOM
----------------------------------------------------------------
local function executeExplosion(data)
    if not data or not data.point then
        debugMsg("No se pudo ejecutar la explosion: punto invalido.", 8)
        return
    end

    local groundPoint = pointToGround(data.point)
    if not groundPoint then
        debugMsg("No se pudo ejecutar la explosion: ground point invalido.", 8)
        return
    end

    trigger.action.explosion(groundPoint, data.power)

    debugMsg(
        "Explosion ejecutada | poder=" .. tostring(data.power) ..
        " | x=" .. tostring(math.floor(groundPoint.x)) ..
        " | z=" .. tostring(math.floor(groundPoint.z)),
        8
    )
end

local function scheduleExplosion(cmd, point)
    local payload = {
        power = cmd.power,
        point = point
    }

    timer.scheduleFunction(function(args, timeNow)
        executeExplosion(args)
        return nil
    end, payload, timer.getTime() + cmd.delay)

    debugMsg(
        "Explosion programada | poder=" .. tostring(cmd.power) ..
        " | delay=" .. tostring(cmd.delay) .. "s",
        8
    )

    return true
end

----------------------------------------------------------------
-- SPAWN
----------------------------------------------------------------
local function buildSpawnNames(sideCfg, unitType)
    local id = MD.STATE.nextSpawnId
    MD.STATE.nextSpawnId = MD.STATE.nextSpawnId + 1

    local base =
        "DBG_" ..
        sanitizeName(sideCfg.label) .. "_" ..
        sanitizeName(unitType) .. "_" ..
        tostring(id)

    return base, (base .. "_1")
end

local function buildGroundGroupData(groupName, unitName, unitType, point)
    local groundPoint = pointToGround(point)
    if not groundPoint then
        return nil
    end

    return {
        visible = true,
        lateActivation = false,
        task = "Ground Nothing",
        route = {
            points = {
                [1] = {
                    x = groundPoint.x,
                    y = groundPoint.z,
                    action = "Off Road",
                    speed = 0,
                    type = "Turning Point",
                    task = {
                        id = "ComboTask",
                        params = {
                            tasks = {}
                        }
                    }
                }
            }
        },
        units = {
            [1] = {
                name = unitName,
                type = unitType,
                skill = "Excellent",
                x = groundPoint.x,
                y = groundPoint.z,
                heading = math.rad(MD.CONFIG.DEFAULT_HEADING_DEG),
                playerCanDrive = false
            }
        },
        name = groupName
    }
end

local function spawnGroundUnit(cmd, point)
    local groupName, unitName = buildSpawnNames(cmd.sideCfg, cmd.unitType)
    local groupData = buildGroundGroupData(groupName, unitName, cmd.unitType, point)

    if not groupData then
        debugMsg("No se pudo construir los datos del spawn.", 8)
        return false
    end

    local ok, result = pcall(function()
        return coalition.addGroup(
            cmd.sideCfg.countryId,
            MD.CONFIG.SPAWN_CATEGORY,
            groupData
        )
    end)

    if not ok or not result then
        debugMsg(
            "Error creando unidad | lado=" .. tostring(cmd.sideCfg.label) ..
            " | tipo=" .. tostring(cmd.unitType),
            10
        )
        return false
    end

    debugMsg(
        "Unidad creada | lado=" .. tostring(cmd.sideCfg.label) ..
        " | tipo=" .. tostring(cmd.unitType) ..
        " | grupo=" .. tostring(groupName),
        10
    )

    return true
end

----------------------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------------------
local markHandler = {}

function markHandler:onEvent(event)
    if not event then
        return
    end

    if event.id == world.event.S_EVENT_MARK_ADDED
        or event.id == world.event.S_EVENT_MARK_CHANGE then

        local text = event.text or ""
        local cmd, err = parseAnyCommand(text)

        if err then
            debugMsg(err, 8)
            return
        end

        if not cmd then
            return
        end

        local point = resolveMarkPoint(event)
        if not point then
            debugMsg("No se pudo leer la posicion de la marca.", 8)
            return
        end

        local signature = buildSignature(text, point)
        if event.idx and MD.STATE.processedMarks[event.idx] == signature then
            return
        end

        if event.idx then
            MD.STATE.processedMarks[event.idx] = signature
        end

        local success = false

        if cmd.kind == "boom" then
            success = scheduleExplosion(cmd, point)
        elseif cmd.kind == "spawn" then
            success = spawnGroundUnit(cmd, point)
        end

        if success and MD.CONFIG.AUTO_REMOVE_MARK and event.idx then
            trigger.action.removeMark(event.idx)
            MD.STATE.processedMarks[event.idx] = nil
        end

    elseif event.id == world.event.S_EVENT_MARK_REMOVE then
        if event.idx then
            MD.STATE.processedMarks[event.idx] = nil
        end
    end
end

world.addEventHandler(markHandler)

trigger.action.outText(
    "Mark Debug cargado.\n" ..
    "Comandos:\n" ..
    "boom 1000 15\n" ..
    "tank red\n" ..
    "tank blue\n" ..
    "spawn red T-90\n" ..
    "spawn blue M1A2C_SEP_V3",
    12
)