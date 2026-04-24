----------------------------------------------------------------
-- HDEV_MissionSystem_Core.lua
-- Motor del sistema de misiones
--
-- REQUIERE:
-- - HDEV_MissionDB.lua cargado antes
-- - HDEV_EconomyCore.lua cargado antes si quieres pagos reales
-- - io, lfs y net.json2lua habilitados
----------------------------------------------------------------

if not HDEV_MissionDB or type(HDEV_MissionDB.MISSIONS) ~= "table" then
    trigger.action.outText("ERROR: HDEV_MissionDB.lua no esta cargado antes de HDEV_MissionSystem_Core.lua", 15)
    return
end

HDEV_MissionSystem = HDEV_MissionSystem or {}
local MS = HDEV_MissionSystem

MS.VERSION = "1.4.10"

MS.STATUS = {
    NOT_STARTED = 0,
    ACTIVE = 1,
    COMPLETED = 2,
    FAILED = 3
}

MS.CONFIG = MS.CONFIG or {
    DEBUG = true,

    rootRelativePath = "Scripts\\HorizontDev\\",
    jsonRelativePath = "Config\\HorizontDev\\SystemMissionPersistence.json",

    IMPORT_WINDOW_SECONDS = 30,
    AUTOSAVE_INTERVAL = 10,
    MIN_WRITE_INTERVAL = 5,
    MAIN_LOOP_INTERVAL = 1,

    MENU_NAME = "Sistema de Misiones",

    MARKS_ENABLED = true,
    MARK_READONLY = true,
    MARK_ID_START = 950000,

    MISSION_UI_ENABLED = true,
    MISSION_UI_DEFAULT_FONT_SIZE = 11,
    MISSION_UI_DEFAULT_TEXT_COLOR = "white",
    MISSION_UI_DEFAULT_FILL_COLOR = {255, 255, 255, 55},

    WAREHOUSE_SOURCE_MODE = "json",
    warehouseJsonRelativePaths = {
        "Config\\HorizontDev\\SystemWarehousesPersistanceSinai.json",
        "Config\\HorizontDev\\SistemWarehousePersistanceSinai.json",
    },
    WAREHOUSE_JSON_CACHE_SECONDS = 0,
    WAREHOUSE_JSON_SECTION_ORDER = { "airports", "warehouses", "carriers", "farps", "helipads", "other" },

    DEBUG_MISSION_RUNTIME = false,
    DEBUG_SCREEN = true,
    DEBUG_LOG = true,
    DEBUG_INTERVAL = 10,
    DEBUG_TEXT_DURATION = 10,
    DEBUG_INCLUDE_VALIDATORS = true
}

----------------------------------------------------------------
-- FORZADO DE ESTADOS PARA PRUEBAS
----------------------------------------------------------------
MS.DEBUG_FORCE_STATUS = MS.DEBUG_FORCE_STATUS or {
    ENABLED = false,
    MISSIONS = {
        --M01 = 2,
        --M02 = 1,
    }
}

MS.STATE = MS.STATE or {
    initialized = false,
    writeEnabled = false,
    importWindowEndsAt = nil,

    dirty = false,
    lastWriteTime = 0,
    lastSavedPayload = "",
    lastAutosaveAt = 0,

    currentMissionId = nil,
    managedFlags = {},
    missions = {},

    runtimeMarks = {},
    runtimeMarkMeta = {},
    runtimePanels = {},
    runtimePanelMeta = {},
    nextMarkId = nil,
    menuRoot = nil,

    lastDebugBroadcastAt = 0,

    warehouseJsonCache = {
        loadedAt = -9999,
        path = nil,
        doc = nil,
        err = nil
    }
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg)
    env.info("[HDEV_MISSION] " .. tostring(msg))
    if MS.CONFIG.DEBUG then
        trigger.action.outText("[HDEV_MISSION] " .. tostring(msg), 6)
    end
end

local function warn(msg)
    env.info("[HDEV_MISSION] " .. tostring(msg))
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function deepCopy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end

    local out = {}
    for k, v in pairs(tbl) do
        out[k] = deepCopy(v)
    end
    return out
end

local function ensureNumber(v)
    return tonumber(v) or 0
end

local function normalizeFlagValue(v)
    if type(v) == "boolean" then
        return v and 1 or 0
    end

    local n = tonumber(v)
    if n ~= nil then
        return n
    end

    local s = tostring(v or ""):lower()
    if s == "true" then
        return 1
    end

    return 0
end

local function normalizeCoalitionValue(v)
    if type(v) == "string" then
        local s = tostring(v):lower()
        if s == "red" or s == "rojo" then
            return 1
        elseif s == "blue" or s == "azul" then
            return 2
        elseif s == "neutral" or s == "neutro" or s == "neutra" then
            return 0
        end
    end

    local n = tonumber(v)
    if n == 1 or n == 2 or n == 0 then
        return n
    end

    return 0
end

local function coalitionToText(v)
    local n = normalizeCoalitionValue(v)
    if n == 1 then
        return "ROJO"
    elseif n == 2 then
        return "AZUL"
    end
    return "NEUTRAL"
end

local function compareValues(left, op, right)
    left = ensureNumber(left)
    right = ensureNumber(right)

    if op == "==" then
        return left == right
    elseif op == "~=" then
        return left ~= right
    elseif op == ">" then
        return left > right
    elseif op == "<" then
        return left < right
    elseif op == ">=" then
        return left >= right
    elseif op == "<=" then
        return left <= right
    end

    return false
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

local function getMissionDefs()
    return HDEV_MissionDB.MISSIONS or {}
end

local function sortedMissionDefs()
    local defs = {}
    for _, def in ipairs(getMissionDefs()) do
        if def.enabled ~= false then
            defs[#defs + 1] = def
        end
    end

    table.sort(defs, function(a, b)
        local oa = tonumber(a.order) or 999999
        local ob = tonumber(b.order) or 999999
        if oa == ob then
            return tostring(a.id) < tostring(b.id)
        end
        return oa < ob
    end)

    return defs
end

local function getMissionDefById(id)
    for _, def in ipairs(getMissionDefs()) do
        if def.id == id then
            return def
        end
    end
    return nil
end

local function statusToText(status)
    if status == MS.STATUS.NOT_STARTED then
        return "NO_INICIADA"
    elseif status == MS.STATUS.ACTIVE then
        return "ACTIVA"
    elseif status == MS.STATUS.COMPLETED then
        return "COMPLETADA"
    elseif status == MS.STATUS.FAILED then
        return "FALLIDA"
    end
    return "DESCONOCIDO"
end

local function getFlagValue(flag)
    return normalizeFlagValue(trigger.misc.getUserFlag(flag))
end

local function setManagedFlag(flag, value)
    local n = normalizeFlagValue(value)
    trigger.action.setUserFlag(flag, n)
    MS.STATE.managedFlags[tostring(flag)] = n
    MS.STATE.dirty = true
end

local function applyManagedFlagsFromState()
    for flag, value in pairs(MS.STATE.managedFlags or {}) do
        trigger.action.setUserFlag(flag, normalizeFlagValue(value))
    end
end

local function allFlagConditionsTrue(conditions)
    for _, cond in ipairs(conditions or {}) do
        local current = getFlagValue(cond.flag)
        local op = cond.op or "=="
        local expected = cond.value or 1

        if not compareValues(current, op, expected) then
            return false
        end
    end

    return true
end

local function groupExistsByName(groupName)
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

----------------------------------------------------------------
-- ECONOMIA
----------------------------------------------------------------
local function getEconomy()
    return HDEV_Economy
end

local function formatMoney(value)
    local econ = getEconomy()
    if econ and econ.formatMoney then
        return econ.formatMoney(tonumber(value) or 0)
    end
    return "$" .. tostring(math.floor(tonumber(value) or 0))
end

local function paySingleCoalition(coalition, amount, reason, missionId, rewardId)
    local econ = getEconomy()
    amount = tonumber(amount) or 0

    if amount <= 0 then
        return false
    end

    if not econ or not econ.add then
        warn("No hay sistema economico disponible para pagar recompensa.")
        return false
    end

    local before = econ.get and econ.get(coalition) or 0
    local after = econ.add(coalition, amount, reason or "recompensa")

    env.info(
        "[HDEV_MISSION_REWARD] coalicion=" .. tostring(coalition) ..
        " monto=" .. tostring(amount) ..
        " missionId=" .. tostring(missionId) ..
        " rewardId=" .. tostring(rewardId) ..
        " saldoAntes=" .. tostring(before) ..
        " saldoDespues=" .. tostring(after)
    )

    trigger.action.outTextForCoalition(
        coalition,
        "Recompensa recibida\n" ..
        "Mision: " .. tostring(missionId or "N/A") .. "\n" ..
        "Concepto: " .. tostring(rewardId or reason or "recompensa") .. "\n" ..
        "Valor: " .. formatMoney(amount),
        12
    )

    return true
end

local function payCoalition(coalition, amount, reason, missionId, rewardId)
    coalition = tonumber(coalition) or 2

    if coalition == 0 then
        local ok1 = paySingleCoalition(1, amount, reason, missionId, rewardId)
        local ok2 = paySingleCoalition(2, amount, reason, missionId, rewardId)
        return ok1 or ok2
    end

    if coalition ~= 1 and coalition ~= 2 then
        coalition = 2
    end

    return paySingleCoalition(coalition, amount, reason, missionId, rewardId)
end

----------------------------------------------------------------
-- FILE / JSON
----------------------------------------------------------------
local function buildWriteDirPath(relativePath)
    if not relativePath or relativePath == "" then
        return nil
    end

    if relativePath:match("^%a:[\\/]") or relativePath:sub(1, 1) == "/" then
        return relativePath
    end

    if lfs and lfs.writedir then
        return lfs.writedir() .. relativePath
    end

    return relativePath
end

local function getMissionJsonPath()
    return buildWriteDirPath(MS.CONFIG.jsonRelativePath or "Config\\HorizontDev\\SystemMissionPersistence.json")
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

local function jsonEscape(str)
    str = tostring(str or "")
    str = str:gsub("\\", "\\\\")
    str = str:gsub("\"", "\\\"")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\n", "\\n")
    str = str:gsub("\t", "\\t")
    return str
end

local function isArray(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    local count = 0
    local maxIndex = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false
        end
        count = count + 1
        if k > maxIndex then
            maxIndex = k
        end
    end

    return count == maxIndex
end

local function encodeJsonValue(value, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    local t = type(value)

    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return "\"" .. jsonEscape(value) .. "\""
    elseif t ~= "table" then
        return "\"" .. jsonEscape(tostring(value)) .. "\""
    end

    if next(value) == nil then
        return isArray(value) and "[]" or "{}"
    end

    if isArray(value) then
        local lines = {"["}
        for i = 1, #value do
            local comma = (i < #value) and "," or ""
            lines[#lines + 1] = string.rep(" ", indent + 2) .. encodeJsonValue(value[i], indent + 2) .. comma
        end
        lines[#lines + 1] = pad .. "]"
        return table.concat(lines, "\n")
    end

    local keys = sortedKeys(value)
    local lines = {"{"}
    for i, key in ipairs(keys) do
        local comma = (i < #keys) and "," or ""
        lines[#lines + 1] =
            string.rep(" ", indent + 2) ..
            "\"" .. jsonEscape(tostring(key)) .. "\": " ..
            encodeJsonValue(value[key], indent + 2) ..
            comma
    end
    lines[#lines + 1] = pad .. "}"
    return table.concat(lines, "\n")
end

local function loadStateFromDisk()
    local txt = safeReadFile(getMissionJsonPath())
    if not txt then
        return nil, "no existe archivo"
    end
    return decodeJson(txt)
end

----------------------------------------------------------------
-- STATE HELPERS
----------------------------------------------------------------
local function ensureMissionState(def)
    if not MS.STATE.missions[def.id] then
        MS.STATE.missions[def.id] = {
            id = def.id,
            order = def.order or 999999,

            status = MS.STATUS.NOT_STARTED,
            activatedAt = nil,
            completedAt = nil,
            failedAt = nil,

            validatorMemory = {},

            rewardsPaid = {
                secondaryObjectives = {},
                missionSuccess = false
            },

            secondaryObjectivesState = {}
        }
    end

    return MS.STATE.missions[def.id]
end

local function ensureRewardState(mState)
    mState.rewardsPaid = mState.rewardsPaid or {
        secondaryObjectives = {},
        missionSuccess = false
    }
    return mState.rewardsPaid
end

local function ensureSecondaryObjectiveState(mState, objectiveId)
    mState.secondaryObjectivesState = mState.secondaryObjectivesState or {}

    if not mState.secondaryObjectivesState[objectiveId] then
        mState.secondaryObjectivesState[objectiveId] = {
            completed = false,
            completedAt = nil,
            lastValue = nil,
            lastSnapshot = {},

            lastPass = false,
            lastExists = 0,

            armed = false,
            firstSeenAt = nil,
            lastSeenAt = nil,
            lastEvalAt = nil,

            debugStatus = "NO_EVALUADO"
        }
    end

    return mState.secondaryObjectivesState[objectiveId]
end

local function initializeMissionStates()
    MS.STATE.missions = {}

    for _, def in ipairs(sortedMissionDefs()) do
        ensureMissionState(def)
    end
end

local function getPreviousMissionDef(def)
    local defs = sortedMissionDefs()
    local prevDef = nil

    for _, other in ipairs(defs) do
        if other.id == def.id then
            break
        end
        prevDef = other
    end

    return prevDef
end

local function sanitizeLoadedState()
    local activeDefs = {}

    for _, def in ipairs(sortedMissionDefs()) do
        local mState = ensureMissionState(def)

        if mState.status == MS.STATUS.ACTIVE then
            activeDefs[#activeDefs + 1] = def
        end

        if mState.status == MS.STATUS.COMPLETED and MS.STATE.currentMissionId == def.id then
            MS.STATE.currentMissionId = nil
        end
    end

    if #activeDefs == 0 then
        if MS.STATE.currentMissionId then
            local def = getMissionDefById(MS.STATE.currentMissionId)
            if not def or ensureMissionState(def).status ~= MS.STATUS.ACTIVE then
                MS.STATE.currentMissionId = nil
            end
        end
        return
    end

    local keepId = nil

    if MS.STATE.currentMissionId then
        for _, def in ipairs(activeDefs) do
            if def.id == MS.STATE.currentMissionId then
                keepId = def.id
                break
            end
        end
    end

    if not keepId then
        keepId = activeDefs[1].id
    end

    MS.STATE.currentMissionId = keepId

    for _, def in ipairs(activeDefs) do
        if def.id ~= keepId then
            local mState = ensureMissionState(def)
            mState.status = MS.STATUS.NOT_STARTED
            mState.activatedAt = nil
        end
    end
end

local function applyForcedStatusOverrides()
    local force = MS.DEBUG_FORCE_STATUS
    if not force or force.ENABLED ~= true then
        return
    end

    local forcedActiveId = nil
    local now = timer.getTime()

    for missionId, forcedStatus in pairs(force.MISSIONS or {}) do
        local def = getMissionDefById(missionId)
        if def then
            local mState = ensureMissionState(def)
            local st = tonumber(forcedStatus)

            if st == MS.STATUS.NOT_STARTED then
                mState.status = MS.STATUS.NOT_STARTED
                mState.activatedAt = nil
                mState.completedAt = nil
                mState.failedAt = nil

            elseif st == MS.STATUS.ACTIVE then
                mState.status = MS.STATUS.ACTIVE
                mState.activatedAt = mState.activatedAt or now
                mState.completedAt = nil
                mState.failedAt = nil
                forcedActiveId = missionId

            elseif st == MS.STATUS.COMPLETED then
                mState.status = MS.STATUS.COMPLETED
                mState.completedAt = mState.completedAt or now
                mState.activatedAt = mState.activatedAt or now
                mState.failedAt = nil

            elseif st == MS.STATUS.FAILED then
                mState.status = MS.STATUS.FAILED
                mState.failedAt = mState.failedAt or now
                mState.completedAt = nil
            end
        end
    end

    if forcedActiveId then
        MS.STATE.currentMissionId = forcedActiveId
    else
        local currentDef = MS.STATE.currentMissionId and getMissionDefById(MS.STATE.currentMissionId) or nil
        local currentState = currentDef and ensureMissionState(currentDef) or nil
        if not currentState or currentState.status ~= MS.STATUS.ACTIVE then
            MS.STATE.currentMissionId = nil
        end
    end

    MS.STATE.dirty = true
    log("DEBUG_FORCE_STATUS aplicado.")
end

local function getActiveMissionDef()
    if not MS.STATE.currentMissionId then
        return nil
    end
    return getMissionDefById(MS.STATE.currentMissionId)
end

local function getActiveMissionState()
    local def = getActiveMissionDef()
    if not def then
        return nil
    end
    return ensureMissionState(def)
end

----------------------------------------------------------------
-- JSON SAVE / RESTORE
----------------------------------------------------------------
local function buildMissionCatalogSnapshot()
    local catalog = {}

    for _, def in ipairs(sortedMissionDefs()) do
        catalog[def.id] = {
            id = def.id,
            order = def.order,
            enabled = def.enabled ~= false,
            name = def.name,
            shortName = def.shortName,
            autoStart = def.autoStart == true,
            rewards = deepCopy(def.rewards or {}),
            hasMap = def.map and def.map.enabled ~= false or false,
            dbVersion = HDEV_MissionDB.VERSION
        }
    end

    return catalog
end

local function buildSaveDocument()
    local doc = {
        control = {
            importWindowSeconds = MS.CONFIG.IMPORT_WINDOW_SECONDS,
            autosaveInterval = MS.CONFIG.AUTOSAVE_INTERVAL,
            minWriteInterval = MS.CONFIG.MIN_WRITE_INTERVAL,
            mainLoopInterval = MS.CONFIG.MAIN_LOOP_INTERVAL
        },

        meta = {
            updatedAt = timer.getTime(),
            source = "HDEV_MissionSystem_Core",
            engineVersion = MS.VERSION,
            dbVersion = HDEV_MissionDB.VERSION,
            currentMissionId = MS.STATE.currentMissionId,
            nextMarkId = MS.STATE.nextMarkId
        },

        missionCatalog = buildMissionCatalogSnapshot(),
        managedFlags = deepCopy(MS.STATE.managedFlags or {}),
        missionsState = {}
    }

    for _, def in ipairs(sortedMissionDefs()) do
        local mState = ensureMissionState(def)

        doc.missionsState[def.id] = {
            id = def.id,
            status = mState.status,
            activatedAt = mState.activatedAt,
            completedAt = mState.completedAt,
            failedAt = mState.failedAt,
            validatorMemory = deepCopy(mState.validatorMemory or {}),
            rewardsPaid = deepCopy(mState.rewardsPaid or {
                secondaryObjectives = {},
                missionSuccess = false
            }),
            secondaryObjectivesState = deepCopy(mState.secondaryObjectivesState or {})
        }
    end

    return doc
end

local function writeJsonToDisk(force)
    if not force then
        if not MS.STATE.writeEnabled then
            return false
        end

        local now = timer.getTime()
        if (now - (MS.STATE.lastWriteTime or 0)) < (MS.CONFIG.MIN_WRITE_INTERVAL or 5) then
            return false
        end
    end

    local payload = encodeJsonValue(buildSaveDocument(), 0)

    if not force and payload == MS.STATE.lastSavedPayload and not MS.STATE.dirty then
        return false
    end

    local ok = safeWriteFile(getMissionJsonPath(), payload)
    if not ok then
        warn("No se pudo escribir el JSON de misiones: " .. tostring(getMissionJsonPath()))
        return false
    end

    MS.STATE.lastSavedPayload = payload
    MS.STATE.lastWriteTime = timer.getTime()
    MS.STATE.dirty = false
    return true
end

local function restoreStateFromDoc(doc)
    if type(doc) ~= "table" then
        return
    end

    MS.STATE.managedFlags = deepCopy(doc.managedFlags or {})
    applyManagedFlagsFromState()

    local sourceState = doc.missionsState or doc.missions or {}

    if type(sourceState) == "table" then
        for missionId, saved in pairs(sourceState) do
            local def = getMissionDefById(missionId)
            if def then
                local mState = ensureMissionState(def)
                mState.status = tonumber(saved.status) or mState.status
                mState.activatedAt = saved.activatedAt
                mState.completedAt = saved.completedAt
                mState.failedAt = saved.failedAt
                mState.validatorMemory = deepCopy(saved.validatorMemory or {})
                mState.rewardsPaid = deepCopy(saved.rewardsPaid or {
                    secondaryObjectives = {},
                    missionSuccess = false
                })
                mState.secondaryObjectivesState = deepCopy(saved.secondaryObjectivesState or {})
            end
        end
    end

    MS.STATE.currentMissionId = doc.meta and doc.meta.currentMissionId or nil
    MS.STATE.nextMarkId = tonumber(doc.meta and doc.meta.nextMarkId) or MS.CONFIG.MARK_ID_START
end

----------------------------------------------------------------
-- METRICAS DE UNIDADES / GRUPOS
----------------------------------------------------------------
local function getUnitMetrics(unitName)
    local out = {
        exists = false,
        alive = 0,
        life = 0,
        life0 = 0,
        lifePercent = 0
    }

    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
        return out
    end

    local life = ensureNumber(unit:getLife())
    local life0 = ensureNumber(unit:getLife0())

    out.exists = true
    out.alive = (life > 0) and 1 or 0
    out.life = life
    out.life0 = life0

    if life0 > 0 then
        out.lifePercent = (life / life0) * 100
    elseif life > 0 then
        out.lifePercent = 100
    end

    return out
end

local function getGroupMetrics(groupName)
    local out = {
        exists = false,
        totalUnits = 0,
        aliveUnits = 0,
        lifeSum = 0,
        life0Sum = 0,
        lifePercent = 0
    }

    local grp = groupExistsByName(groupName)
    if not grp then
        return out
    end

    out.exists = true

    local units = grp:getUnits() or {}
    out.totalUnits = #units

    for i = 1, #units do
        local unit = units[i]
        if unit and unit:isExist() then
            local life = ensureNumber(unit:getLife())
            local life0 = ensureNumber(unit:getLife0())

            if life > 0 then
                out.aliveUnits = out.aliveUnits + 1
            end

            out.lifeSum = out.lifeSum + life
            out.life0Sum = out.life0Sum + life0
        end
    end

    if out.life0Sum > 0 then
        out.lifePercent = (out.lifeSum / out.life0Sum) * 100
    elseif out.lifeSum > 0 then
        out.lifePercent = 100
    end

    return out
end

----------------------------------------------------------------
-- BASE / CAPTURA HELPERS
----------------------------------------------------------------
local function getBaseCoalitionMetrics(baseName)
    local out = {
        exists = false,
        coalition = 0,
        coalitionText = "NEUTRAL",
        category = nil,
        baseName = baseName
    }

    local base = Airbase.getByName(baseName)
    if not base then
        return out
    end

    out.exists = true

    local okCoalition, coalitionValue = pcall(function()
        return base:getCoalition()
    end)
    if okCoalition then
        out.coalition = normalizeCoalitionValue(coalitionValue)
        out.coalitionText = coalitionToText(out.coalition)
    end

    local okDesc, desc = pcall(function()
        return base:getDesc()
    end)
    if okDesc and type(desc) == "table" then
        out.category = desc.category
    end

    return out
end

----------------------------------------------------------------
-- WAREHOUSE HELPERS
----------------------------------------------------------------
local function getWarehouseJsonCandidatePaths()
    local out = {}
    local seen = {}

    for _, relativePath in ipairs(MS.CONFIG.warehouseJsonRelativePaths or {}) do
        local fullPath = buildWriteDirPath(relativePath)
        if fullPath and fullPath ~= "" and not seen[fullPath] then
            out[#out + 1] = fullPath
            seen[fullPath] = true
        end
    end

    return out
end

local function loadWarehouseJsonDocument(force)
    local cache = MS.STATE.warehouseJsonCache or {
        loadedAt = -9999,
        path = nil,
        doc = nil,
        err = nil,
        modifiedAt = nil
    }
    MS.STATE.warehouseJsonCache = cache

    local now = timer.getTime()
    local cacheSeconds = tonumber(MS.CONFIG.WAREHOUSE_JSON_CACHE_SECONDS) or 0

    if not force and cache.doc and cache.path then
        local diskModifiedAt = nil
        if lfs and lfs.attributes then
            local attr = lfs.attributes(cache.path)
            if type(attr) == "table" then
                diskModifiedAt = attr.modification
            end
        end

        local cacheStillFresh = (now - (cache.loadedAt or -9999)) <= cacheSeconds
        local fileUnchanged = (diskModifiedAt == nil) or (cache.modifiedAt == diskModifiedAt)

        if cacheStillFresh and fileUnchanged then
            return cache.doc, cache.path, nil
        end
    end

    local lastErr = "no existe archivo"

    for _, path in ipairs(getWarehouseJsonCandidatePaths()) do
        local txt = safeReadFile(path)
        if txt and txt ~= "" then
            local doc, err = decodeJson(txt)
            if doc then
                local modifiedAt = nil
                if lfs and lfs.attributes then
                    local attr = lfs.attributes(path)
                    if type(attr) == "table" then
                        modifiedAt = attr.modification
                    end
                end

                cache.loadedAt = now
                cache.path = path
                cache.doc = doc
                cache.err = nil
                cache.modifiedAt = modifiedAt
                return doc, path, nil
            end
            lastErr = err or ("json invalido: " .. tostring(path))
        else
            lastErr = "no se pudo leer: " .. tostring(path)
        end
    end

    cache.loadedAt = now
    cache.path = nil
    cache.doc = nil
    cache.err = lastErr
    cache.modifiedAt = nil

    return nil, nil, lastErr
end

local function forEachWarehouseJsonEntry(doc, fn)
    local sectionOrder = MS.CONFIG.WAREHOUSE_JSON_SECTION_ORDER or { "airports", "warehouses", "carriers", "farps", "helipads", "other" }

    for _, section in ipairs(sectionOrder) do
        local block = doc and doc[section]
        if type(block) == "table" then
            for idStr, data in pairs(block) do
                local id = tonumber(idStr)
                if not id and type(data) == "table" then
                    id = tonumber(data.id)
                end
                fn(section, id, data)
            end
        end
    end
end

local function findWarehouseJsonEntryByBaseName(doc, baseName)
    local wanted = tostring(baseName or "")
    local wantedLower = wanted:lower()

    local lowerMatchData = nil
    local lowerMatchMeta = nil

    forEachWarehouseJsonEntry(doc, function(section, id, data)
        if type(data) ~= "table" then
            return
        end

        local name = tostring(data.name or "")
        if name == wanted then
            lowerMatchData = data
            lowerMatchMeta = {
                source = "json",
                sectionName = section,
                entryId = id,
                entryName = name,
                baseExists = true
            }
            return
        end

        if not lowerMatchData and name:lower() == wantedLower then
            lowerMatchData = data
            lowerMatchMeta = {
                source = "json",
                sectionName = section,
                entryId = id,
                entryName = name,
                baseExists = true
            }
        end
    end)

    return lowerMatchData, lowerMatchMeta
end

local function getWarehouseSectionByCategory(entry, category)
    local key = tostring(category or ""):lower()

    if key == "liquid" or key == "liquids" then
        return entry.liquids or {}, "liquids"
    end

    if key == "aircraft" then
        return entry.aircraft or {}, "aircraft"
    end

    if key == "weapon" then
        return entry.weapon or {}, "weapon"
    end

    if key ~= "" and type(entry[key]) == "table" then
        return entry[key], key
    end

    return {}, key
end

local function getMapValueFlexible(section, itemName)
    if type(section) ~= "table" then
        return nil, nil
    end

    if section[itemName] ~= nil then
        return section[itemName], tostring(itemName)
    end

    local itemKey = tostring(itemName)
    if section[itemKey] ~= nil then
        return section[itemKey], itemKey
    end

    local itemLower = itemKey:lower()
    for k, v in pairs(section) do
        if tostring(k):lower() == itemLower then
            return v, tostring(k)
        end
    end

    return nil, nil
end

local function getWarehouseInventory(baseName)
    local sourceMode = tostring(MS.CONFIG.WAREHOUSE_SOURCE_MODE or "json"):lower()

    if sourceMode == "runtime" then
        local base = Airbase.getByName(baseName)
        if not base then
            return nil, "airbase no encontrada: " .. tostring(baseName), {
                source = "runtime",
                baseExists = false,
                entryName = baseName
            }
        end

        local okWh, wh = pcall(function()
            return base:getWarehouse()
        end)
        if not okWh or not wh then
            return nil, "warehouse no disponible: " .. tostring(baseName), {
                source = "runtime",
                baseExists = true,
                entryName = baseName
            }
        end

        local okInv, inv = pcall(function()
            return wh:getInventory()
        end)
        if not okInv or type(inv) ~= "table" then
            return nil, "getInventory fallo en: " .. tostring(baseName), {
                source = "runtime",
                baseExists = true,
                entryName = baseName
            }
        end

        return inv, nil, {
            source = "runtime",
            baseExists = true,
            entryName = baseName
        }
    end

    local doc, jsonPath, loadErr = loadWarehouseJsonDocument(false)
    if not doc then
        return nil, "warehouse json no disponible: " .. tostring(loadErr), {
            source = "json",
            baseExists = false,
            jsonPath = jsonPath
        }
    end

    local entry, meta = findWarehouseJsonEntryByBaseName(doc, baseName)
    if not entry then
        return nil, "base no encontrada en warehouse json: " .. tostring(baseName), {
            source = "json",
            baseExists = false,
            jsonPath = jsonPath,
            entryName = baseName
        }
    end

    meta = meta or {}
    meta.source = "json"
    meta.baseExists = true
    meta.jsonPath = jsonPath
    return entry, nil, meta
end

local function getWarehouseItemCount(baseName, category, itemName)
    local inv, err, meta = getWarehouseInventory(baseName)
    meta = meta or {
        source = tostring(MS.CONFIG.WAREHOUSE_SOURCE_MODE or "json"):lower()
    }

    if not inv then
        return 0, err, meta
    end

    local section, resolvedCategory = getWarehouseSectionByCategory(inv, category)
    local value, matchedKey = getMapValueFlexible(section, itemName)

    meta.resolvedCategory = resolvedCategory
    meta.itemKey = matchedKey or tostring(itemName)
    meta.itemExists = (value ~= nil)
    meta.baseName = baseName

    return ensureNumber(value), nil, meta
end

local function syncWarehouseBaseline(memory, currentCount)
    currentCount = ensureNumber(currentCount)
    memory.initialCount = ensureNumber(memory.initialCount)
    memory.highestCountSeen = ensureNumber(memory.highestCountSeen)

    if currentCount > 0 and memory.initialCount <= 0 then
        memory.initialCount = currentCount
    end

    if currentCount > memory.highestCountSeen then
        memory.highestCountSeen = currentCount
    end

    if memory.highestCountSeen <= 0 and memory.initialCount > 0 then
        memory.highestCountSeen = memory.initialCount
    end

    if memory.initialCount <= 0 and memory.highestCountSeen > 0 then
        memory.initialCount = memory.highestCountSeen
    end
end

local function formatDebugNumber(v)
    local n = tonumber(v) or 0
    if math.abs(n - math.floor(n)) < 0.001 then
        return tostring(math.floor(n))
    end
    return string.format("%.2f", n)
end

local function boolText(v)
    return v and "SI" or "NO"
end

local function debugMissionLog(msg)
    if MS.CONFIG.DEBUG_MISSION_RUNTIME and MS.CONFIG.DEBUG_LOG then
        env.info("[HDEV_MISSION_DEBUG] " .. tostring(msg))
    end
end

local function debugMissionScreen(msg)
    if not (MS.CONFIG.DEBUG_MISSION_RUNTIME and MS.CONFIG.DEBUG_SCREEN) then
        return
    end

    local text = "[HDEV_MISSION_DEBUG]\n" .. tostring(msg)
    if #text > 3500 then
        text = text:sub(1, 3500) .. "\n...TRUNCADO EN PANTALLA. REVISA DCS.LOG PARA EL COMPLETO."
    end

    trigger.action.outText(text, tonumber(MS.CONFIG.DEBUG_TEXT_DURATION) or 10)
end

local function rememberMonitorSeen(oState, exists)
    if exists then
        oState.armed = true
        oState.firstSeenAt = oState.firstSeenAt or timer.getTime()
        oState.lastSeenAt = timer.getTime()
    end
    oState.lastExists = exists and 1 or 0
end

local function buildSecondaryObjectiveDebugLines(def, mState, lines)
    for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
        if objectiveDef.enabled ~= false then
            local objectiveId = tostring(objectiveDef.id)
            local oState = ensureSecondaryObjectiveState(mState, objectiveId)
            local mon = objectiveDef.monitor or {}
            local kind = tostring(mon.kind or ""):lower()
            local snap = oState.lastSnapshot or {}

            if kind == "group" then
                lines[#lines + 1] =
                    "OBJ " .. objectiveId ..
                    " | kind=group" ..
                    " | nombre=" .. tostring(mon.groupName) ..
                    " | done=" .. boolText(oState.completed) ..
                    " | armed=" .. boolText(oState.armed) ..
                    " | pass=" .. boolText(oState.lastPass) ..
                    " | exists=" .. formatDebugNumber(oState.lastExists) ..
                    " | value=" .. formatDebugNumber(oState.lastValue) ..
                    " | aliveUnits=" .. formatDebugNumber(snap.aliveUnits) ..
                    " | totalUnits=" .. formatDebugNumber(snap.totalUnits) ..
                    " | target " .. tostring(mon.op or "==") .. " " .. formatDebugNumber(mon.value or 0) ..
                    " | estado=" .. tostring(oState.debugStatus or "N/A")

            elseif kind == "unit" then
                lines[#lines + 1] =
                    "OBJ " .. objectiveId ..
                    " | kind=unit" ..
                    " | nombre=" .. tostring(mon.unitName) ..
                    " | done=" .. boolText(oState.completed) ..
                    " | armed=" .. boolText(oState.armed) ..
                    " | pass=" .. boolText(oState.lastPass) ..
                    " | exists=" .. formatDebugNumber(oState.lastExists) ..
                    " | value=" .. formatDebugNumber(oState.lastValue) ..
                    " | alive=" .. formatDebugNumber(snap.alive) ..
                    " | life=" .. formatDebugNumber(snap.life) ..
                    " | life0=" .. formatDebugNumber(snap.life0) ..
                    " | life%=" .. formatDebugNumber(snap.lifePercent) ..
                    " | target " .. tostring(mon.op or "==") .. " " .. formatDebugNumber(mon.value or 0) ..
                    " | estado=" .. tostring(oState.debugStatus or "N/A")

            elseif kind == "base_capture" or kind == "base_control" or kind == "airbase_control" then
                lines[#lines + 1] =
                    "OBJ " .. objectiveId ..
                    " | kind=base_capture" ..
                    " | base=" .. tostring(snap.baseName or mon.baseName) ..
                    " | done=" .. boolText(oState.completed) ..
                    " | pass=" .. boolText(oState.lastPass) ..
                    " | exists=" .. boolText(snap.exists == true) ..
                    " | coalition=" .. tostring(snap.coalitionText or coalitionToText(snap.coalition or 0)) ..
                    " | target=" .. coalitionToText(mon.coalition or mon.value or 2) ..
                    " | estado=" .. tostring(oState.debugStatus or "N/A")

            elseif kind == "warehouse" then
                lines[#lines + 1] =
                    "OBJ " .. objectiveId ..
                    " | kind=warehouse" ..
                    " | base=" .. tostring(snap.baseName or mon.baseName) ..
                    " | done=" .. boolText(oState.completed) ..
                    " | pass=" .. boolText(oState.lastPass) ..
                    " | value=" .. formatDebugNumber(oState.lastValue) ..
                    " | baseline=" .. formatDebugNumber(snap.highestCountSeen or snap.initialCount) ..
                    " | modo=" .. tostring(snap.mode or mon.mode or "all") ..
                    " | src=" .. tostring(snap.source or "json") ..
                    " | sec=" .. tostring(snap.sectionName or "N/A") ..
                    " | baseFound=" .. boolText(snap.baseExists == true) ..
                    " | estado=" .. tostring(oState.debugStatus or "N/A") ..
                    (snap.error and (" | error=" .. tostring(snap.error)) or "")

                local itemKeys = sortedKeys(snap.items or {})
                for _, itemKey in ipairs(itemKeys) do
                    local item = snap.items[itemKey] or {}
                    lines[#lines + 1] =
                        "   " .. tostring(itemKey) ..
                        " | current=" .. formatDebugNumber(item.currentCount) ..
                        " | baseline=" .. formatDebugNumber(item.highestCountSeen or item.initialCount) ..
                        " | removed=" .. formatDebugNumber(item.removedCount) .. "/" .. formatDebugNumber(item.targetRemoved) ..
                        " | exists=" .. boolText(item.itemExists == true)
                end

            elseif kind == "flag" then
                lines[#lines + 1] =
                    "OBJ " .. objectiveId ..
                    " | kind=flag" ..
                    " | flag=" .. tostring(mon.flag) ..
                    " | done=" .. boolText(oState.completed) ..
                    " | pass=" .. boolText(oState.lastPass) ..
                    " | value=" .. formatDebugNumber(oState.lastValue) ..
                    " | target " .. tostring(mon.op or "==") .. " " .. formatDebugNumber(mon.value or 1)
            end
        end
    end
end

local function buildValidatorDebugLines(def, mState, lines)
    if not MS.CONFIG.DEBUG_INCLUDE_VALIDATORS then
        return
    end

    for i, check in ipairs(def.validators and def.validators.warehouse or {}) do
        local key = tostring(check.key or ("WH_" .. i))
        local mem = mState.validatorMemory[key] or {}

        lines[#lines + 1] =
            "VAL-W " .. key ..
            " | base=" .. tostring(check.baseName) ..
            " | cat=" .. tostring(check.category) ..
            " | item=" .. tostring(check.itemName) ..
            " | src=" .. tostring(mem.source or "json") ..
            " | sec=" .. tostring(mem.sectionName or "N/A") ..
            " | baseFound=" .. boolText(mem.baseExists == true) ..
            " | itemFound=" .. boolText(mem.itemExists == true) ..
            " | current=" .. formatDebugNumber(mem.currentCount) ..
            " | removed=" .. formatDebugNumber(mem.removedCount) .. "/" .. formatDebugNumber(mem.targetRemoved) ..
            (mem.error and (" | error=" .. tostring(mem.error)) or "")
    end

    for i, check in ipairs(def.validators and def.validators.groupChecks or {}) do
        local key = tostring(check.key or ("GRP_" .. i))
        local mem = mState.validatorMemory[key] or {}
        local snap = mem.snapshot or {}

        lines[#lines + 1] =
            "VAL-G " .. key ..
            " | nombre=" .. tostring(check.groupName) ..
            " | exists=" .. formatDebugNumber((snap.exists and 1) or 0) ..
            " | value=" .. formatDebugNumber(mem.currentValue) ..
            " | aliveUnits=" .. formatDebugNumber(snap.aliveUnits) ..
            " | totalUnits=" .. formatDebugNumber(snap.totalUnits) ..
            " | target " .. tostring(check.op or ">=") .. " " .. formatDebugNumber(check.value or 1)
    end

    for i, check in ipairs(def.validators and def.validators.unitChecks or {}) do
        local key = tostring(check.key or ("UNT_" .. i))
        local mem = mState.validatorMemory[key] or {}
        local snap = mem.snapshot or {}

        lines[#lines + 1] =
            "VAL-U " .. key ..
            " | nombre=" .. tostring(check.unitName) ..
            " | exists=" .. formatDebugNumber((snap.exists and 1) or 0) ..
            " | value=" .. formatDebugNumber(mem.currentValue) ..
            " | alive=" .. formatDebugNumber(snap.alive) ..
            " | life=" .. formatDebugNumber(snap.life) ..
            " | life%=" .. formatDebugNumber(snap.lifePercent) ..
            " | target " .. tostring(check.op or ">") .. " " .. formatDebugNumber(check.value or 0)
    end
end

local function dumpActiveMissionDebug(def, mState, now)
    if not MS.CONFIG.DEBUG_MISSION_RUNTIME then
        return
    end

    now = now or timer.getTime()

    if (now - (MS.STATE.lastDebugBroadcastAt or 0)) < (tonumber(MS.CONFIG.DEBUG_INTERVAL) or 10) then
        return
    end

    MS.STATE.lastDebugBroadcastAt = now

    local lines = {}
    lines[#lines + 1] =
        "MISION=" .. tostring(def.id) ..
        " | short=" .. tostring(def.shortName or def.id) ..
        " | status=" .. tostring(statusToText(mState.status)) ..
        " | currentMissionId=" .. tostring(MS.STATE.currentMissionId) ..
        " | writeEnabled=" .. boolText(MS.STATE.writeEnabled)

    buildSecondaryObjectiveDebugLines(def, mState, lines)
    buildValidatorDebugLines(def, mState, lines)

    local msg = table.concat(lines, "\n")
    debugMissionLog(msg)
    debugMissionScreen(msg)
end

----------------------------------------------------------------
-- MARKERS
----------------------------------------------------------------
local function getNextMarkId()
    if not MS.STATE.nextMarkId then
        MS.STATE.nextMarkId = tonumber(MS.CONFIG.MARK_ID_START) or 950000
    end

    MS.STATE.nextMarkId = MS.STATE.nextMarkId + 1
    return MS.STATE.nextMarkId
end

local function removeMissionMark(missionId)
    local centerMarkId = MS.STATE.runtimeMarks[missionId]
    if centerMarkId then
        pcall(function()
            trigger.action.removeMark(centerMarkId)
        end)

        MS.STATE.runtimeMarks[missionId] = nil
        MS.STATE.runtimeMarkMeta[missionId] = nil
    end

    local panelMarkId = MS.STATE.runtimePanels[missionId]
    if panelMarkId then
        if mist and mist.marker and mist.marker.remove then
            pcall(function()
                mist.marker.remove(panelMarkId)
            end)
        else
            pcall(function()
                trigger.action.removeMark(panelMarkId)
            end)
        end

        MS.STATE.runtimePanels[missionId] = nil
        MS.STATE.runtimePanelMeta[missionId] = nil
    end
end

local function resolveMissionMarkPoint(def)
    local map = def.map or {}
    if map.enabled == false then
        return nil
    end

    local mode = tostring(map.mode or "zone"):lower()

    if mode == "point" and map.point then
        return {
            x = ensureNumber(map.point.x),
            y = ensureNumber(map.point.y),
            z = map.point.z ~= nil and ensureNumber(map.point.z) or ensureNumber(map.point.y)
        }
    end

    if mode == "zone" and map.zoneName then
        local zone = trigger.misc.getZone(map.zoneName)
        if zone then
            if zone.point then
                return {
                    x = ensureNumber(zone.point.x),
                    y = ensureNumber(zone.point.y),
                    z = zone.point.z ~= nil and ensureNumber(zone.point.z) or ensureNumber(zone.point.y)
                }
            else
                return {
                    x = ensureNumber(zone.x),
                    y = 0,
                    z = ensureNumber(zone.y)
                }
            end
        end
    end

    return nil
end

local function normalizeMissionUIColorName(name)
    local s = tostring(name or MS.CONFIG.MISSION_UI_DEFAULT_TEXT_COLOR or "white"):lower()

    if s == "black" then return {0, 0, 0, 255} end
    if s == "white" then return {255, 255, 255, 255} end
    if s == "red" then return {255, 0, 0, 255} end
    if s == "blue" then return {0, 100, 255, 255} end
    if s == "yellow" then return {255, 255, 0, 255} end
    if s == "orange" then return {255, 165, 0, 255} end
    if s == "green" then return {0, 255, 0, 255} end

    return {255, 255, 255, 255}
end

local function getMissionUITextColor(def)
    local draw = def.draw or {}
    if type(draw.textColor) == "table" then
        return deepCopy(draw.textColor)
    end
    return normalizeMissionUIColorName(draw.textColor)
end

local function getMissionUIFillColor(def)
    local draw = def.draw or {}
    if type(draw.fillColor) == "table" then
        return deepCopy(draw.fillColor)
    end
    return deepCopy(MS.CONFIG.MISSION_UI_DEFAULT_FILL_COLOR or {255, 255, 255, 55})
end

local function getMissionUIPoint(def)
    local basePoint = resolveMissionMarkPoint(def)
    if not basePoint then
        return nil
    end

    local draw = def.draw or {}
    return {
        x = ensureNumber(basePoint.x) + ensureNumber(draw.offsetX),
        y = ensureNumber(basePoint.y),
        z = ensureNumber(basePoint.z) + ensureNumber(draw.offsetZ)
    }
end

local function getMissionUITitle(def)
    local draw = def.draw or {}
    return tostring(draw.title or (def.map and def.map.title) or def.shortName or def.id or "MISION")
end

local function getMissionGeneralObjective(def)
    local draw = def.draw or {}
    return tostring(def.generalObjective or def.objectiveGeneral or draw.generalObjective or def.name or def.id or "Sin objetivo general")
end

local function getMissionObjectiveDisplayName(objectiveDef)
    return tostring(objectiveDef.drawName or objectiveDef.name or objectiveDef.id or "OBJ")
end

local function splitLines(text)
    local out = {}
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n")
    text = text:gsub("\r", "\n")

    for line in string.gmatch(text, "([^\n]*)\n?") do
        if line == "" and #out > 0 and out[#out] == "" then
            -- evita dobles vacios repetidos
        else
            out[#out + 1] = line
        end
    end

    while #out > 0 and out[#out] == "" do
        table.remove(out, #out)
    end

    if #out == 0 then
        out[1] = ""
    end

    return out
end

local function buildWarehouseObjectivePendingLines(objectiveDef, oState)
    local lines = {}
    local mon = objectiveDef.monitor or {}
    local snapshot = oState.lastSnapshot or {}

    if tostring(mon.kind or ""):lower() ~= "warehouse" then
        return lines
    end

    if mon.itemName then
        local currentCount = ensureNumber(snapshot.currentCount)
        local targetRemoved = ensureNumber(mon.removedAtLeast or snapshot.targetRemoved or 0)
        local baseline = ensureNumber(snapshot.highestCountSeen or snapshot.initialCount or currentCount)
        local remaining = math.max(0, targetRemoved - math.max(0, baseline - currentCount))

        if remaining > 0 then
            lines[#lines + 1] =
                "  " .. tostring(mon.itemName) .. ": falta " .. tostring(remaining)
        end

        return lines
    end

    local itemDefs = mon.items or {}
    local snapItems = snapshot.items or {}

    for i = 1, #itemDefs do
        local itemDef = itemDefs[i]
        local itemCategory = tostring(itemDef.category or mon.category or "")
        local itemName = tostring(itemDef.itemName or "")
        local itemKey = itemCategory .. "::" .. itemName
        local itemSnap = snapItems[itemKey] or {}

        local currentCount = ensureNumber(itemSnap.currentCount)
        local targetRemoved = ensureNumber(itemDef.removedAtLeast or itemSnap.targetRemoved or 0)
        local baseline = ensureNumber(itemSnap.highestCountSeen or itemSnap.initialCount or currentCount)
        local removedCount = math.max(0, baseline - currentCount)
        local remaining = math.max(0, targetRemoved - removedCount)

        if remaining > 0 then
            lines[#lines + 1] =
                "  " .. itemName .. ": falta " .. tostring(remaining)
        end
    end

    return lines
end

local function buildMissionDynamicPanelText(def, mState)
    local lines = {}

    lines[#lines + 1] = getMissionUITitle(def)
    lines[#lines + 1] = "OBJETIVO GENERAL:"

    local generalLines = splitLines(getMissionGeneralObjective(def))
    for _, line in ipairs(generalLines) do
        lines[#lines + 1] = line
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "OBJETIVOS PENDIENTES:"

    local pending = 0
    for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
        if objectiveDef.enabled ~= false and objectiveDef.requiredForMission == true then
            local objectiveId = tostring(objectiveDef.id)
            local oState = ensureSecondaryObjectiveState(mState, objectiveId)

            if not oState.completed then
                pending = pending + 1
                lines[#lines + 1] = "- " .. getMissionObjectiveDisplayName(objectiveDef)

                local extraLines = buildWarehouseObjectivePendingLines(objectiveDef, oState)
                for _, extraLine in ipairs(extraLines) do
                    lines[#lines + 1] = extraLine
                end
            end
        end
    end

    if pending == 0 then
        if mState.status == MS.STATUS.COMPLETED then
            lines[#lines + 1] = "- MISION COMPLETADA"
        else
            lines[#lines + 1] = "- TODOS LOS OBJETIVOS CUMPLIDOS"
        end
    end

    return table.concat(lines, "\n")
end

local function buildMissionCenterMarkText(def)
    local map = def.map or {}
    return
        tostring(map.title or def.name or def.id) ..
        "\n\n" ..
        tostring(map.text or "") ..
        "\n\n" ..
        tostring(def.briefing or "")
end

local function missionUIPointEquals(a, b)
    if not a or not b then
        return false
    end

    return ensureNumber(a.x) == ensureNumber(b.x)
       and ensureNumber(a.y) == ensureNumber(b.y)
       and ensureNumber(a.z) == ensureNumber(b.z)
end

local function createMissionMark(def, mState)
    if not MS.CONFIG.MARKS_ENABLED then
        return
    end

    if not mState then
        mState = ensureMissionState(def)
    end

    removeMissionMark(def.id)

    local basePoint = resolveMissionMarkPoint(def)
    if not basePoint then
        return
    end

    local centerText = buildMissionCenterMarkText(def)
    local centerMarkId = getNextMarkId()

    local ok = pcall(function()
        trigger.action.markToAll(centerMarkId, centerText, basePoint, MS.CONFIG.MARK_READONLY, "")
    end)

    if not ok then
        pcall(function()
            trigger.action.markToAll(centerMarkId, centerText, basePoint, MS.CONFIG.MARK_READONLY)
        end)
    end

    MS.STATE.runtimeMarks[def.id] = centerMarkId
    MS.STATE.runtimeMarkMeta[def.id] = {
        text = centerText,
        point = deepCopy(basePoint)
    }

    local draw = def.draw or {}
    if draw.enabled == false then
        return
    end

    local panelPoint = getMissionUIPoint(def)
    if not panelPoint then
        return
    end

    local panelText = buildMissionDynamicPanelText(def, mState)
    local panelCoa = tonumber(draw.coalition)
    if panelCoa == nil then
        panelCoa = -1
    end

    if MS.CONFIG.MISSION_UI_ENABLED and mist and mist.marker and mist.marker.add then
        local panelData = mist.marker.add({
            name = "MISSION_PANEL_" .. tostring(def.id),
            mType = 5,
            point = panelPoint,
            text = panelText,
            fontSize = tonumber(draw.fontSize or MS.CONFIG.MISSION_UI_DEFAULT_FONT_SIZE or 11),
            color = getMissionUITextColor(def),
            fillColor = getMissionUIFillColor(def),
            lineType = tonumber(draw.lineType) or 1,
            readOnly = true,
            coa = panelCoa
        })

        if panelData and panelData.markId then
            MS.STATE.runtimePanels[def.id] = panelData.markId
            MS.STATE.runtimePanelMeta[def.id] = {
                text = panelText,
                point = deepCopy(panelPoint),
                coa = panelCoa
            }
            return
        end
    end

    local fallbackPanelId = getNextMarkId()
    local okPanel = pcall(function()
        trigger.action.markToAll(fallbackPanelId, panelText, panelPoint, true, "")
    end)

    if not okPanel then
        pcall(function()
            trigger.action.markToAll(fallbackPanelId, panelText, panelPoint, true)
        end)
    end

    MS.STATE.runtimePanels[def.id] = fallbackPanelId
    MS.STATE.runtimePanelMeta[def.id] = {
        text = panelText,
        point = deepCopy(panelPoint),
        coa = panelCoa
    }
end

local function refreshMissionMark(def, mState)
    if not MS.CONFIG.MARKS_ENABLED then
        return
    end

    if not def or not mState or mState.status ~= MS.STATUS.ACTIVE then
        return
    end

    local basePoint = resolveMissionMarkPoint(def)
    if not basePoint then
        removeMissionMark(def.id)
        return
    end

    local draw = def.draw or {}
    if draw.enabled == false then
        local centerText = buildMissionCenterMarkText(def)
        local centerMeta = MS.STATE.runtimeMarkMeta[def.id]

        if centerMeta and centerMeta.text == centerText and missionUIPointEquals(centerMeta.point, basePoint) then
            return
        end

        createMissionMark(def, mState)
        return
    end

    local panelPoint = getMissionUIPoint(def)
    if not panelPoint then
        removeMissionMark(def.id)
        return
    end

    local centerText = buildMissionCenterMarkText(def)
    local panelText = buildMissionDynamicPanelText(def, mState)
    local panelCoa = tonumber(draw.coalition)
    if panelCoa == nil then
        panelCoa = -1
    end

    local centerMeta = MS.STATE.runtimeMarkMeta[def.id]
    local panelMeta = MS.STATE.runtimePanelMeta[def.id]

    local centerOk = centerMeta and centerMeta.text == centerText and missionUIPointEquals(centerMeta.point, basePoint)
    local panelOk = panelMeta and panelMeta.text == panelText and panelMeta.coa == panelCoa and missionUIPointEquals(panelMeta.point, panelPoint)

    if centerOk and panelOk then
        return
    end

    createMissionMark(def, mState)
end
----------------------------------------------------------------
-- VALIDADORES TECNICOS
----------------------------------------------------------------
local function runWarehouseValidator(mState, check)
    local memory = mState.validatorMemory[check.key] or {}
    mState.validatorMemory[check.key] = memory

    local currentCount, err, meta = getWarehouseItemCount(
        check.baseName,
        check.category,
        check.itemName
    )

    memory.baseName = check.baseName
    memory.category = check.category
    memory.itemName = check.itemName
    memory.source = meta and meta.source or "json"
    memory.sectionName = meta and meta.sectionName or nil
    memory.entryId = meta and meta.entryId or nil
    memory.entryName = meta and meta.entryName or check.baseName
    memory.baseExists = meta and meta.baseExists == true or false
    memory.itemExists = meta and meta.itemExists == true or false
    memory.jsonPath = meta and meta.jsonPath or nil
    memory.resolvedCategory = meta and meta.resolvedCategory or check.category
    memory.resolvedItemKey = meta and meta.itemKey or check.itemName

    if err then
        memory.error = err
        memory.currentCount = 0
        memory.removedCount = 0
        memory.targetRemoved = tonumber(check.removedAtLeast) or 0
        memory.lastPass = false

        if check.setFlagOnPass and check.setFlagOnPass.elseValue ~= nil then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.elseValue)
        end

        return
    end

    memory.error = nil

    if memory.initialCount == nil then
        memory.initialCount = currentCount
    end
    memory.highestCountSeen = math.max(ensureNumber(memory.highestCountSeen), ensureNumber(memory.initialCount), ensureNumber(currentCount))

    memory.currentCount = currentCount
    memory.removedCount = math.max(0, ensureNumber(memory.highestCountSeen) - ensureNumber(currentCount))
    memory.targetRemoved = tonumber(check.removedAtLeast) or 0

    local pass = memory.removedCount >= memory.targetRemoved
    memory.lastPass = pass

    if check.setFlagOnPass then
        if pass then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.value)
        elseif check.setFlagOnPass.elseValue ~= nil then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.elseValue)
        end
    end
end

local function runGroupValidator(mState, check)
    local memory = mState.validatorMemory[check.key] or {}
    mState.validatorMemory[check.key] = memory

    local data = getGroupMetrics(check.groupName)
    local metricName = check.metric or "aliveUnits"
    local metricValue = ensureNumber(data[metricName])

    memory.groupName = check.groupName
    memory.metricName = metricName
    memory.currentValue = metricValue
    memory.snapshot = deepCopy(data)
    memory.error = nil

    if data.exists then
        memory.seenOnce = true
        memory.lastSeenAt = timer.getTime()
    end

    local pass = compareValues(metricValue, check.op or ">=", check.value or 1)
    memory.lastPass = pass

    if check.setFlagOnPass then
        if pass then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.value)
        elseif check.setFlagOnPass.elseValue ~= nil then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.elseValue)
        end
    end
end

local function runUnitValidator(mState, check)
    local memory = mState.validatorMemory[check.key] or {}
    mState.validatorMemory[check.key] = memory

    local data = getUnitMetrics(check.unitName)
    local metricName = check.metric or "lifePercent"
    local metricValue = ensureNumber(data[metricName])

    memory.unitName = check.unitName
    memory.metricName = metricName
    memory.currentValue = metricValue
    memory.snapshot = deepCopy(data)
    memory.error = nil

    if data.exists then
        memory.seenOnce = true
        memory.lastSeenAt = timer.getTime()
    end

    local pass = compareValues(metricValue, check.op or ">", check.value or 0)
    memory.lastPass = pass

    if check.setFlagOnPass then
        if pass then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.value)
        elseif check.setFlagOnPass.elseValue ~= nil then
            setManagedFlag(check.setFlagOnPass.flag, check.setFlagOnPass.elseValue)
        end
    end
end

local function runMissionValidators(def, mState)
    for _, check in ipairs(def.validators and def.validators.warehouse or {}) do
        runWarehouseValidator(mState, check)
    end

    for _, check in ipairs(def.validators and def.validators.groupChecks or {}) do
        runGroupValidator(mState, check)
    end

    for _, check in ipairs(def.validators and def.validators.unitChecks or {}) do
        runUnitValidator(mState, check)
    end
end

----------------------------------------------------------------
-- REGLAS DE FLAGS POR MISION
----------------------------------------------------------------
local function applyFlagActions(actionList)
    for _, entry in ipairs(actionList or {}) do
        if entry.flag ~= nil and entry.value ~= nil then
            setManagedFlag(entry.flag, entry.value)
        end
    end
end

local function runMissionFlagRules(def)
    for _, rule in ipairs(def.missionFlagRules or {}) do
        if rule.enabled ~= false then
            local pass = allFlagConditionsTrue(rule.conditions or {})
            if pass then
                applyFlagActions(rule.onTrue or {})
            else
                applyFlagActions(rule.onFalse or {})
            end
        end
    end
end

----------------------------------------------------------------
-- OBJETIVOS SECUNDARIOS
----------------------------------------------------------------
local function evaluateSecondaryObjectiveMonitor(mState, objectiveDef)
    local mon = objectiveDef.monitor or {}
    local kind = tostring(mon.kind or ""):lower()
    local objectiveId = tostring(objectiveDef.id or "UNKNOWN")
    local oState = ensureSecondaryObjectiveState(mState, objectiveId)

    oState.lastEvalAt = timer.getTime()

    if kind == "group" then
        local data = getGroupMetrics(mon.groupName)
        local metricName = mon.metric or "aliveUnits"
        local metricValue = ensureNumber(data[metricName])

        rememberMonitorSeen(oState, data.exists)

        if not oState.armed then
            oState.debugStatus = "ESPERANDO_PRIMERA_DETECCION"
            oState.lastPass = false
            return false, metricValue, data
        end

        if not data.exists then
            metricValue = 0
        end

        local pass = compareValues(metricValue, mon.op or "==", mon.value or 0)
        oState.debugStatus = pass and "PASS" or "PENDIENTE"
        oState.lastPass = pass
        return pass, metricValue, data

    elseif kind == "unit" then
        local data = getUnitMetrics(mon.unitName)
        local metricName = mon.metric or "alive"
        local metricValue = ensureNumber(data[metricName])

        rememberMonitorSeen(oState, data.exists)

        if not oState.armed then
            oState.debugStatus = "ESPERANDO_PRIMERA_DETECCION"
            oState.lastPass = false
            return false, metricValue, data
        end

        if not data.exists then
            metricValue = 0
        end

        local pass = compareValues(metricValue, mon.op or "==", mon.value or 0)
        oState.debugStatus = pass and "PASS" or "PENDIENTE"
        oState.lastPass = pass
        return pass, metricValue, data

    elseif kind == "base_capture" or kind == "base_control" or kind == "airbase_control" then
        local data = getBaseCoalitionMetrics(mon.baseName)
        local targetCoalition = normalizeCoalitionValue(mon.coalition ~= nil and mon.coalition or mon.value)
        local metricValue = normalizeCoalitionValue(data.coalition)

        if not data.exists then
            oState.debugStatus = "BASE_NO_ENCONTRADA"
            oState.lastPass = false
            return false, metricValue, data
        end

        local pass = compareValues(metricValue, mon.op or "==", targetCoalition)
        oState.debugStatus = pass and "PASS" or "PENDIENTE"
        oState.lastPass = pass
        data.targetCoalition = targetCoalition
        data.targetCoalitionText = coalitionToText(targetCoalition)
        return pass, metricValue, data

    elseif kind == "flag" then
        local current = getFlagValue(mon.flag)
        local pass = compareValues(current, mon.op or "==", mon.value or 1)
        oState.debugStatus = pass and "PASS" or "PENDIENTE"
        oState.lastPass = pass
        return pass, current, { flag = mon.flag }

    elseif kind == "warehouse" then
        local memoryKey = "__OBJ_WH__" .. tostring(objectiveDef.id)
        local memory = mState.validatorMemory[memoryKey] or {}
        mState.validatorMemory[memoryKey] = memory

        memory.baseName = mon.baseName
        memory.category = mon.category
        memory.mode = tostring(mon.mode or "all"):lower()
        memory.source = "json"
        memory.items = memory.items or {}
        memory.error = nil

        if mon.itemName then
            local currentCount, err, meta = getWarehouseItemCount(
                mon.baseName,
                mon.category,
                mon.itemName
            )

            memory.source = meta and meta.source or "json"
            memory.sectionName = meta and meta.sectionName or nil
            memory.entryId = meta and meta.entryId or nil
            memory.entryName = meta and meta.entryName or mon.baseName
            memory.baseExists = meta and meta.baseExists == true or false
            memory.itemExists = meta and meta.itemExists == true or false
            memory.jsonPath = meta and meta.jsonPath or nil
            memory.resolvedCategory = meta and meta.resolvedCategory or mon.category
            memory.resolvedItemKey = meta and meta.itemKey or mon.itemName

            if err then
                memory.error = err
                oState.debugStatus = "ERROR"
                oState.lastPass = false
                return false, 0, memory
            end

            if memory.initialCount == nil then
                memory.initialCount = currentCount
            end
            syncWarehouseBaseline(memory, currentCount)

            memory.itemName = mon.itemName
            memory.currentCount = currentCount
            memory.removedCount = math.max(0, ensureNumber(memory.highestCountSeen) - ensureNumber(currentCount))
            memory.targetRemoved = tonumber(mon.removedAtLeast) or 0

            local pass = memory.removedCount >= memory.targetRemoved
            oState.debugStatus = pass and "PASS" or "PENDIENTE"
            oState.lastPass = pass
            return pass, memory.removedCount, memory
        end

        local items = mon.items or {}
        local mode = tostring(mon.mode or "all"):lower()

        local totalRemoved = 0
        local anyPass = false
        local allPass = true

        memory.items = memory.items or {}

        local baseMeta = nil

        for i = 1, #items do
            local itemDef = items[i]
            local itemName = itemDef.itemName
            local target = tonumber(itemDef.removedAtLeast) or 0
            local itemCategory = itemDef.category or mon.category
            local itemKey = tostring(itemCategory) .. "::" .. tostring(itemName)

            local currentCount, err, meta = getWarehouseItemCount(
                mon.baseName,
                itemCategory,
                itemName
            )

            if not baseMeta and meta then
                baseMeta = meta
                memory.source = meta.source or "json"
                memory.sectionName = meta.sectionName
                memory.entryId = meta.entryId
                memory.entryName = meta.entryName or mon.baseName
                memory.baseExists = meta.baseExists == true
                memory.jsonPath = meta.jsonPath
            end

            if err then
                memory.error = err
                oState.debugStatus = "ERROR"
                oState.lastPass = false
                return false, 0, memory
            end

            memory.items[itemKey] = memory.items[itemKey] or {}
            local itemMemory = memory.items[itemKey]

            if itemMemory.initialCount == nil then
                itemMemory.initialCount = currentCount
            end
            syncWarehouseBaseline(itemMemory, currentCount)

            itemMemory.category = itemCategory
            itemMemory.itemName = itemName
            itemMemory.currentCount = currentCount
            itemMemory.removedCount = math.max(0, ensureNumber(itemMemory.highestCountSeen) - ensureNumber(currentCount))
            itemMemory.targetRemoved = target
            itemMemory.itemExists = ((meta and meta.itemExists == true) or (ensureNumber(currentCount) > 0)) and true or false
            itemMemory.resolvedCategory = meta and meta.resolvedCategory or itemCategory
            itemMemory.resolvedItemKey = meta and meta.itemKey or itemName

            totalRemoved = totalRemoved + itemMemory.removedCount

            local thisPass = itemMemory.removedCount >= target
            if thisPass then
                anyPass = true
            else
                allPass = false
            end
        end

        memory.totalRemoved = totalRemoved
        memory.targetRemovedTotal = tonumber(mon.removedAtLeastTotal) or 0

        local pass = false
        if mode == "any" then
            pass = anyPass
        elseif mode == "sum" then
            pass = totalRemoved >= memory.targetRemovedTotal
        else
            pass = allPass
        end

        oState.debugStatus = pass and "PASS" or "PENDIENTE"
        oState.lastPass = pass
        return pass, totalRemoved, memory
    end

    oState.debugStatus = "TIPO_NO_SOPORTADO"
    oState.lastPass = false
    return false, 0, {}
end

local function updateSecondaryObjectiveActiveFlags(def, mState)
    for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
        local activeFlag = objectiveDef.setFlagOnActive
        if activeFlag then
            local objectiveId = tostring(objectiveDef.id)
            local oState = ensureSecondaryObjectiveState(mState, objectiveId)

            local isActive =
                (mState.status == MS.STATUS.ACTIVE) and
                (objectiveDef.enabled ~= false) and
                (oState.completed ~= true)

            if isActive then
                setManagedFlag(activeFlag.flag, activeFlag.value)
            else
                if activeFlag.elseValue ~= nil then
                    setManagedFlag(activeFlag.flag, activeFlag.elseValue)
                else
                    setManagedFlag(activeFlag.flag, 0)
                end
            end
        end
    end
end

local function processSecondaryObjectives(def, mState)
    for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
        if objectiveDef.enabled ~= false then
            local objectiveId = tostring(objectiveDef.id)
            local oState = ensureSecondaryObjectiveState(mState, objectiveId)

            if not oState.completed then
                local previousPass = oState.lastPass == true

                local pass, metricValue, snapshot = evaluateSecondaryObjectiveMonitor(mState, objectiveDef)

                oState.lastValue = metricValue
                oState.lastSnapshot = deepCopy(snapshot or {})
                oState.lastPass = pass

                if pass ~= previousPass then
                    debugMissionLog(
                        "Cambio objetivo " .. tostring(def.id) ..
                        " -> " .. tostring(objectiveId) ..
                        " | pass=" .. tostring(pass) ..
                        " | value=" .. tostring(metricValue)
                    )
                end

                if objectiveDef.setFlagOnPass then
                    if pass then
                        setManagedFlag(objectiveDef.setFlagOnPass.flag, objectiveDef.setFlagOnPass.value)
                    elseif objectiveDef.setFlagOnPass.elseValue ~= nil then
                        setManagedFlag(objectiveDef.setFlagOnPass.flag, objectiveDef.setFlagOnPass.elseValue)
                    end
                end

                if pass then
                    oState.completed = true
                    oState.completedAt = timer.getTime()
                    MS.STATE.dirty = true

                    debugMissionLog(
                        "Objetivo completado " .. tostring(def.id) ..
                        " -> " .. tostring(objectiveId)
                    )

                    trigger.action.outText(
                        "Objetivo secundario completado\n" ..
                        tostring(def.shortName or def.id) .. "\n" ..
                        tostring(objectiveDef.name or objectiveId),
                        12
                    )

                    local reward = objectiveDef.reward or {}
                    if reward.enabled ~= false then
                        local rewardState = ensureRewardState(mState)

                        if not rewardState.secondaryObjectives[objectiveId] then
                            local amount = tonumber(reward.amount) or 0
                            if amount > 0 then
                                local coalition = tonumber(reward.coalition or (def.rewards and def.rewards.coalition) or 2) or 2
                                local ok = payCoalition(
                                    coalition,
                                    amount,
                                    "objetivo secundario " .. tostring(objectiveId),
                                    def.id,
                                    objectiveId
                                )

                                if ok then
                                    rewardState.secondaryObjectives[objectiveId] = true
                                    MS.STATE.dirty = true
                                end
                            else
                                rewardState.secondaryObjectives[objectiveId] = true
                                MS.STATE.dirty = true
                            end
                        end
                    end
                end
            end
        end
    end
end

local function countRequiredSecondaryObjectives(def)
    local count = 0
    for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
        if objectiveDef.enabled ~= false and objectiveDef.requiredForMission == true then
            count = count + 1
        end
    end
    return count
end

local function areRequiredSecondaryObjectivesComplete(def, mState)
    for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
        if objectiveDef.enabled ~= false and objectiveDef.requiredForMission == true then
            local objectiveId = tostring(objectiveDef.id)
            local oState = ensureSecondaryObjectiveState(mState, objectiveId)
            if not oState.completed then
                return false
            end
        end
    end
    return true
end

----------------------------------------------------------------
-- MISIONES
----------------------------------------------------------------
local function getCurrentOrNextMission()
    local defs = sortedMissionDefs()

    for _, def in ipairs(defs) do
        local st = ensureMissionState(def).status
        if st == MS.STATUS.ACTIVE then
            return def, "ACTIVE"
        end
    end

    for _, def in ipairs(defs) do
        local mState = ensureMissionState(def)
        if mState.status == MS.STATUS.NOT_STARTED then
            local prevDef = getPreviousMissionDef(def)
            local prevOk = true

            if prevDef then
                local prevState = ensureMissionState(prevDef)
                prevOk = prevState.status == MS.STATUS.COMPLETED
            end

            if prevOk and allFlagConditionsTrue(def.activationConditions or {}) then
                return def, "NEXT"
            end
        end
    end

    return nil, "NONE"
end

local function activateMission(def, mState, manual)
    if MS.STATE.currentMissionId and MS.STATE.currentMissionId ~= def.id then
        return false
    end

    if mState.status == MS.STATUS.COMPLETED then
        return false
    end

    if mState.status == MS.STATUS.FAILED then
        return false
    end

    if mState.status == MS.STATUS.ACTIVE then
        return true
    end

    mState.status = MS.STATUS.ACTIVE
    mState.activatedAt = timer.getTime()
    MS.STATE.currentMissionId = def.id

    applyFlagActions(def.flags and def.flags.onActivate or {})
    updateSecondaryObjectiveActiveFlags(def, mState)
    createMissionMark(def, mState)

    local modeText = manual and "manual" or "automatica"

    trigger.action.outText(
        "Mision activada (" .. modeText .. ")\n\n" ..
        tostring(def.name) .. "\n\n" ..
        tostring(def.briefing or ""),
        20
    )

    MS.STATE.dirty = true
    return true
end

local function processMissionCompletionReward(def, mState)
    local rewards = def.rewards or {}
    if rewards.enabled == false then
        return
    end

    local rewardState = ensureRewardState(mState)

    if rewardState.missionSuccess == true then
        return
    end

    local amount = tonumber(rewards.missionSuccessAmount) or 0
    local coalition = tonumber(rewards.coalition) or 2

    if amount <= 0 then
        rewardState.missionSuccess = true
        MS.STATE.dirty = true
        return
    end

    local ok = payCoalition(
        coalition,
        amount,
        "completada " .. tostring(def.id),
        def.id,
        "MISSION_SUCCESS"
    )

    if ok then
        rewardState.missionSuccess = true
        MS.STATE.dirty = true
    end
end

local function completeMission(def, mState)
    if mState.status == MS.STATUS.COMPLETED then
        return
    end

    processMissionCompletionReward(def, mState)

    mState.status = MS.STATUS.COMPLETED
    mState.completedAt = timer.getTime()

    if MS.STATE.currentMissionId == def.id then
        MS.STATE.currentMissionId = nil
    end

    applyFlagActions(def.flags and def.flags.onSuccess or {})
    updateSecondaryObjectiveActiveFlags(def, mState)
    removeMissionMark(def.id)

    trigger.action.outText(
        "Mision completada\n" ..
        tostring(def.name),
        15
    )

    MS.STATE.dirty = true
end

local function failMission(def, mState)
    if mState.status == MS.STATUS.FAILED then
        return
    end

    mState.status = MS.STATUS.FAILED
    mState.failedAt = timer.getTime()

    if MS.STATE.currentMissionId == def.id then
        MS.STATE.currentMissionId = nil
    end

    applyFlagActions(def.flags and def.flags.onFail or {})
    updateSecondaryObjectiveActiveFlags(def, mState)
    removeMissionMark(def.id)

    trigger.action.outText(
        "Mision fallida\n" ..
        tostring(def.name),
        15
    )

    MS.STATE.dirty = true
end

local function evaluateMissionResult(def, mState)
    if #(def.failConditions or {}) > 0 and allFlagConditionsTrue(def.failConditions) then
        trigger.action.outText(
            "Condiciones de fallo cumplidas\n" ..
            tostring(def.shortName or def.id) .. " - " .. tostring(def.name),
            10
        )
        failMission(def, mState)
        return
    end

    local requiredCount = countRequiredSecondaryObjectives(def)
    local requiredObjectivesOk = true
    if requiredCount > 0 then
        requiredObjectivesOk = areRequiredSecondaryObjectivesComplete(def, mState)
    end

    local successFlagsOk = true
    local hasSuccessFlags = #(def.successConditions or {}) > 0

    if hasSuccessFlags then
        successFlagsOk = allFlagConditionsTrue(def.successConditions)
    end

    local hasCompletionGate = (requiredCount > 0) or hasSuccessFlags
    if not hasCompletionGate then
        return
    end

    if requiredObjectivesOk and successFlagsOk then
        trigger.action.outText(
            "Condiciones de exito cumplidas\n" ..
            tostring(def.shortName or def.id) .. " - " .. tostring(def.name),
            10
        )
        completeMission(def, mState)
        return
    end
end

local function tryAutoStartNextMission()
    local def, mode = getCurrentOrNextMission()
    if not def then
        return
    end

    if mode == "NEXT" and def.autoStart then
        activateMission(def, ensureMissionState(def), false)
    end
end

local function manuallyActivateNextMission()
    local def, mode = getCurrentOrNextMission()

    if not def then
        trigger.action.outText("No hay una mision disponible para activar.", 8)
        return
    end

    if mode == "ACTIVE" then
        trigger.action.outText("Ya existe una mision activa: " .. tostring(def.name), 8)
        return
    end

    activateMission(def, ensureMissionState(def), true)
end

----------------------------------------------------------------
-- MENU F10
----------------------------------------------------------------
local function buildMissionSummaryLine(def, mState)
    local line =
        "[" .. tostring(def.order or "?") .. "] " ..
        tostring(def.shortName or def.id) .. " - " ..
        tostring(def.name) ..
        " | status=" .. tostring(mState.status) ..
        " (" .. statusToText(mState.status) .. ")"

    return line
end

local function showMissionStates()
    local lines = {}
    lines[#lines + 1] = "ESTADO DE MISIONES"

    for _, def in ipairs(sortedMissionDefs()) do
        local mState = ensureMissionState(def)
        lines[#lines + 1] = buildMissionSummaryLine(def, mState)
    end

    trigger.action.outText(table.concat(lines, "\n"), 20)
end

local function showActiveMission()
    local def = getActiveMissionDef()
    if not def then
        trigger.action.outText("No hay una mision activa en este momento.", 10)
        return
    end

    local mState = ensureMissionState(def)

    local msg =
        "MISION ACTIVA\n\n" ..
        tostring(def.name) .. "\n\n" ..
        tostring(def.briefing or "") .. "\n\n" ..
        "Estado: " .. tostring(mState.status) .. " (" .. statusToText(mState.status) .. ")"

    if #(def.secondaryObjectives or {}) > 0 then
        msg = msg .. "\n\nOBJETIVOS SECUNDARIOS:"
        for _, objectiveDef in ipairs(def.secondaryObjectives or {}) do
            local objectiveId = tostring(objectiveDef.id)
            local oState = ensureSecondaryObjectiveState(mState, objectiveId)

            msg = msg ..
                "\n- " .. tostring(objectiveDef.name or objectiveId) ..
                " | " .. tostring(oState.completed and "COMPLETADO" or "PENDIENTE")
        end
    end

    trigger.action.outText(msg, 25)
end

local function showWallet()
    local econ = getEconomy()
    if not econ or not econ.get then
        trigger.action.outText("Sistema economico no disponible.", 8)
        return
    end

    local msg =
        "BILLETERA\n" ..
        "Azul: " .. formatMoney(econ.get(2)) .. "\n" ..
        "Rojo: " .. formatMoney(econ.get(1))

    trigger.action.outText(msg, 12)
end

local function forceSaveNow()
    local ok = writeJsonToDisk(true)
    if ok then
        trigger.action.outText("JSON de misiones guardado.", 8)
    else
        trigger.action.outText("No se pudo guardar el JSON de misiones.", 8)
    end
end

local function rebuildMenu()
    if MS.STATE.menuRoot then
        missionCommands.removeItem(MS.STATE.menuRoot)
        MS.STATE.menuRoot = nil
    end

    MS.STATE.menuRoot = missionCommands.addSubMenu(MS.CONFIG.MENU_NAME)
    missionCommands.addCommand("Ver estado de misiones", MS.STATE.menuRoot, showMissionStates)
    missionCommands.addCommand("Ver mision activa", MS.STATE.menuRoot, showActiveMission)
    --missionCommands.addCommand("Activar siguiente disponible", MS.STATE.menuRoot, manuallyActivateNextMission)
    --missionCommands.addCommand("Ver billetera", MS.STATE.menuRoot, showWallet)
    --missionCommands.addCommand("Guardar JSON ahora", MS.STATE.menuRoot, forceSaveNow)
end

----------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------
local function mainLoop(_, now)
    now = now or timer.getTime()

    if MS.STATE.importWindowEndsAt and now >= MS.STATE.importWindowEndsAt and not MS.STATE.writeEnabled then
        MS.STATE.writeEnabled = true
        MS.STATE.dirty = true
        log("Ventana de importacion terminada. DCS toma control del JSON de misiones.")
    end

    local activeDef = getActiveMissionDef()

    if activeDef then
        local activeState = ensureMissionState(activeDef)

        if activeState.status == MS.STATUS.ACTIVE then
            runMissionFlagRules(activeDef)
            runMissionValidators(activeDef, activeState)
            processSecondaryObjectives(activeDef, activeState)
            updateSecondaryObjectiveActiveFlags(activeDef, activeState)
            refreshMissionMark(activeDef, activeState)
            evaluateMissionResult(activeDef, activeState)
            dumpActiveMissionDebug(activeDef, activeState, now)
        end
    else
        tryAutoStartNextMission()
    end

    if MS.STATE.writeEnabled then
        if (now - (MS.STATE.lastAutosaveAt or 0)) >= (MS.CONFIG.AUTOSAVE_INTERVAL or 10) then
            MS.STATE.lastAutosaveAt = now
            writeJsonToDisk(false)
        end
    end

    return now + (MS.CONFIG.MAIN_LOOP_INTERVAL or 1)
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
local function validateEnvironment()
    if not io or not lfs then
        warn("io/lfs no disponibles. Revisa MissionScripting.lua.")
        return false
    end

    if not net or not net.json2lua then
        warn("net.json2lua no disponible.")
        return false
    end

    return true
end

local function start()
    if MS.STATE.initialized then
        return
    end

    if not validateEnvironment() then
        return
    end

    initializeMissionStates()
    MS.STATE.nextMarkId = tonumber(MS.CONFIG.MARK_ID_START) or 950000

    local doc, err = loadStateFromDisk()
    if doc then
        restoreStateFromDoc(doc)
        log("Estado de misiones restaurado desde JSON.")
    else
        log("No habia JSON previo. Se inicia limpio. Motivo: " .. tostring(err))
    end

    applyForcedStatusOverrides()
    sanitizeLoadedState()

    if MS.STATE.currentMissionId then
        local def = getMissionDefById(MS.STATE.currentMissionId)
        local mState = def and ensureMissionState(def) or nil

        if def and mState and mState.status == MS.STATUS.ACTIVE then
            updateSecondaryObjectiveActiveFlags(def, mState)
            createMissionMark(def, mState)
        else
            MS.STATE.currentMissionId = nil
        end
    end

    rebuildMenu()

    MS.STATE.importWindowEndsAt = timer.getTime() + (MS.CONFIG.IMPORT_WINDOW_SECONDS or 30)
    MS.STATE.writeEnabled = false
    MS.STATE.initialized = true

    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)

    trigger.action.outText(
        "Sistema de Misiones cargado.\n" ..
        "Menu F10: " .. tostring(MS.CONFIG.MENU_NAME),
        12
    )

    log("Ruta JSON: " .. tostring(getMissionJsonPath()))
end

start()