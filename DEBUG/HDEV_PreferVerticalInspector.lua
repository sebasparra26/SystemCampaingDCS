-- ============================================================================
-- HDEV_PreferVerticalInspector.lua
-- VERSION: 1
--
-- Debugger para encontrar como DCS guarda la opcion:
-- "Prefer Take Off / Land Vertically"
-- en grupos de helicopteros creados desde el Mission Editor.
--
-- USO:
-- 1) Crea en el Mission Editor un grupo helicoptero con la opcion marcada.
-- 2) Ponle un nombre claro, por ejemplo: DEBUG_VERTICAL_HELI
-- 3) Carga este script DESPUES de MIST o solo como DO SCRIPT FILE.
-- 4) Revisa archivos generados en:
--    Saved Games\DCS...\Config\HorizontDev\DebugPreferVertical\
-- ============================================================================

HDEV_PreferVerticalInspector = HDEV_PreferVerticalInspector or {}
local PVI = HDEV_PreferVerticalInspector

PVI.CONFIG = PVI.CONFIG or {
    DEBUG = true,

    -- Si dejas esta tabla vacia {}, inspecciona todos los grupos de helicopteros.
    TARGET_GROUP_NAMES = {
        "DEBUG_VERTICAL_HELI",
        "DEBUG_VERTICAL_HELI_RED",
        "DEBUG_VERTICAL_HELI_BLUE",
        "DEBUG_NORMAL_HELI",
        "DEBUG_NORMAL_HELI_RED",
        "DEBUG_NORMAL_HELI_BLUE",
    },

    -- Si true, tambien inspecciona todos los helicopteros aunque no coincidan con TARGET_GROUP_NAMES.
    INSPECT_ALL_HELICOPTERS_IF_TARGETS_NOT_FOUND = true,

    -- Carpeta de salida.
    OUTPUT_DIR = lfs.writedir() .. "Config\\HorizontDev\\DebugPreferVertical\\",

    -- Exporta un archivo FULL por cada grupo con la estructura completa.
    WRITE_FULL_GROUP_DUMP = true,

    -- Exporta un resumen compacto con hallazgos.
    WRITE_SUMMARY = true,

    -- Crea un mark/F10 message con confirmacion simple.
    SHOW_SCREEN_MESSAGES = true,
}

PVI.STATE = PVI.STATE or {
    ran = false,
    found = {},
    reports = {},
}

-- ==========================================================================
-- LOG
-- ==========================================================================
local function log(msg)
    env.info("[HDEV_PREFER_VERTICAL_INSPECTOR] " .. tostring(msg))
    if PVI.CONFIG.DEBUG and PVI.CONFIG.SHOW_SCREEN_MESSAGES then
        trigger.action.outText("[PVI] " .. tostring(msg), 8)
    end
end

local function warn(msg)
    env.info("[HDEV_PREFER_VERTICAL_INSPECTOR] " .. tostring(msg))
    if PVI.CONFIG.SHOW_SCREEN_MESSAGES then
        trigger.action.outText("[PVI] " .. tostring(msg), 10)
    end
end

-- ==========================================================================
-- FILE UTILS
-- ==========================================================================
local function ensureDir(path)
    if not lfs or not lfs.mkdir then return false end
    local current = ""
    local prefix = ""

    if path:match("^%a:[\\/]") then
        prefix = path:sub(1, 3)
        current = prefix
    elseif path:sub(1, 1) == "/" then
        prefix = "/"
        current = prefix
    end

    for part in string.gmatch(path, "[^\\/]+") do
        if part ~= "" and not part:match("^%a:$") then
            if current == "" or current:sub(-1) == "\\" or current:sub(-1) == "/" then
                current = current .. part
            else
                current = current .. "\\" .. part
            end
            lfs.mkdir(current)
        end
    end
    return true
end

local function writeFile(path, text)
    local dir = path:gsub("[^\\/]+$", "")
    ensureDir(dir)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(text or "")
    f:close()
    return true
end

local function safeName(s)
    s = tostring(s or "")
    s = s:gsub("[^%w_%-]+", "_")
    s = s:gsub("_+", "_")
    if s == "" then s = "GROUP" end
    return s
end

-- ==========================================================================
-- SERIALIZADOR LUA SEGURO
-- ============================================================================
local function serializeLua(value, indent, seen)
    indent = indent or 0
    seen = seen or {}
    local t = type(value)
    local pad = string.rep(" ", indent)
    local nextPad = string.rep(" ", indent + 2)

    if t == "nil" then
        return "nil"
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t ~= "table" then
        return string.format("%q", "<" .. t .. ": " .. tostring(value) .. ">")
    end

    if seen[value] then
        return string.format("%q", "<circular>")
    end
    seen[value] = true

    local keys = {}
    for k, _ in pairs(value) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == tb then return tostring(a) < tostring(b) end
        return ta < tb
    end)

    local out = {"{"}
    for _, k in ipairs(keys) do
        local keyText
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            keyText = k
        else
            keyText = "[" .. serializeLua(k, 0, seen) .. "]"
        end
        out[#out + 1] = nextPad .. keyText .. " = " .. serializeLua(value[k], indent + 2, seen) .. ","
    end
    out[#out + 1] = pad .. "}"
    seen[value] = nil
    return table.concat(out, "\n")
end

local function tryJson(value)
    if net and net.lua2json then
        local ok, txt = pcall(net.lua2json, value)
        if ok and txt then return txt end
    end
    return nil
end

-- ==========================================================================
-- ENUMS / FINDERS
-- ==========================================================================
local function getPreferVerticalId()
    if AI and AI.Option and AI.Option.Air and AI.Option.Air.id then
        return AI.Option.Air.id.PREFER_VERTICAL
    end
    return nil
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function targetNameSet()
    local set = {}
    for _, name in ipairs(PVI.CONFIG.TARGET_GROUP_NAMES or {}) do
        if name and name ~= "" then
            set[name] = true
        end
    end
    return set
end

local function groupMatchesTarget(groupName)
    local set = targetNameSet()
    local hasTargets = false
    for _, _ in pairs(set) do hasTargets = true break end
    if not hasTargets then return true end
    return set[groupName] == true
end

local function isHelicopterGroupCategory(categoryName)
    return categoryName == "helicopter"
end

local function getCoalitionEnumFromMissionName(coaName)
    coaName = tostring(coaName or "")
    if coaName == "blue" then return 2 end
    if coaName == "red" then return 1 end
    if coaName == "neutral" or coaName == "neutrals" then return 0 end
    return nil
end

local function collectMissionHelicopterGroups()
    local result = {}
    if not env or not env.mission or not env.mission.coalition then
        return result
    end

    for coaName, coaData in pairs(env.mission.coalition or {}) do
        if type(coaData) == "table" and type(coaData.country) == "table" then
            for _, countryData in pairs(coaData.country) do
                if type(countryData) == "table" and type(countryData.helicopter) == "table" and type(countryData.helicopter.group) == "table" then
                    for _, groupData in pairs(countryData.helicopter.group) do
                        if type(groupData) == "table" then
                            result[#result + 1] = {
                                coalitionName = coaName,
                                coalitionId = getCoalitionEnumFromMissionName(coaName),
                                countryId = countryData.id,
                                countryName = countryData.name,
                                category = "helicopter",
                                group = groupData,
                                groupName = groupData.name,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return tostring(a.groupName) < tostring(b.groupName)
    end)

    return result
end

local function recursiveSearch(value, path, preferVerticalId, hits, depth)
    depth = depth or 0
    if depth > 60 then return end
    hits = hits or {}

    local t = type(value)
    if t ~= "table" then
        return hits
    end

    -- Caso principal: Advanced Waypoint Action -> WrappedAction -> Option
    if value.id == "WrappedAction" and type(value.params) == "table" and type(value.params.action) == "table" then
        local action = value.params.action
        if action.id == "Option" and type(action.params) == "table" then
            local name = action.params.name
            local val = action.params.value
            local isPrefer = preferVerticalId ~= nil and name == preferVerticalId
            hits[#hits + 1] = {
                kind = isPrefer and "PREFER_VERTICAL_OPTION" or "OPTION_ACTION",
                path = path,
                optionName = name,
                optionValue = val,
                raw = value,
            }
        end
    end

    -- Campos sospechosos por nombre.
    for k, v in pairs(value) do
        local ks = lower(k)
        if ks:find("vertical", 1, true)
            or ks:find("land", 1, true)
            or ks:find("takeoff", 1, true)
            or ks:find("take_off", 1, true)
            or ks:find("prefer", 1, true)
        then
            hits[#hits + 1] = {
                kind = "SUSPECT_KEY",
                path = path .. "." .. tostring(k),
                key = tostring(k),
                value = v,
            }
        end

        if type(v) == "table" then
            recursiveSearch(v, path .. "." .. tostring(k), preferVerticalId, hits, depth + 1)
        else
            if preferVerticalId ~= nil and v == preferVerticalId then
                hits[#hits + 1] = {
                    kind = "PREFER_VERTICAL_ID_VALUE",
                    path = path .. "." .. tostring(k),
                    key = tostring(k),
                    value = v,
                }
            end
        end
    end

    return hits
end

local function extractRouteTasks(groupData)
    local out = {}
    if not groupData or not groupData.route or type(groupData.route.points) ~= "table" then
        return out
    end

    for wpIndex, wp in ipairs(groupData.route.points) do
        local wpInfo = {
            wpIndex = wpIndex,
            name = wp.name,
            type = wp.type,
            action = wp.action,
            alt = wp.alt,
            alt_type = wp.alt_type,
            speed = wp.speed,
            x = wp.x,
            y = wp.y,
            airdromeId = wp.airdromeId,
            helipadId = wp.helipadId,
            task = wp.task,
        }
        out[#out + 1] = wpInfo
    end
    return out
end

local function inspectLiveGroup(groupName)
    local live = {
        exists = false,
        error = nil,
    }

    if not Group or not Group.getByName then
        live.error = "Group API no disponible"
        return live
    end

    local grp = Group.getByName(groupName)
    if not grp then
        live.error = "Group.getByName devolvio nil"
        return live
    end

    live.exists = true

    local okExist, exists = pcall(function() return grp:isExist() end)
    live.isExist = okExist and exists or false

    local okCoal, coal = pcall(function() return grp:getCoalition() end)
    if okCoal then live.coalition = coal end

    local okCtrl, ctrl = pcall(function() return grp:getController() end)
    live.hasController = okCtrl and ctrl ~= nil
    live.controllerCanSetOption = live.hasController and ctrl.setOption ~= nil or false
    live.controllerCanSetTask = live.hasController and ctrl.setTask ~= nil or false
    live.controllerCanPushTask = live.hasController and ctrl.pushTask ~= nil or false

    local unit = nil
    local okUnit = pcall(function() unit = grp:getUnit(1) end)
    if okUnit and unit then
        live.unit1 = {}
        pcall(function() live.unit1.name = unit:getName() end)
        pcall(function() live.unit1.typeName = unit:getTypeName() end)
        pcall(function() live.unit1.coalition = unit:getCoalition() end)
        pcall(function() live.unit1.point = unit:getPoint() end)
        pcall(function() live.unit1.desc = unit:getDesc() end)
    end

    return live
end

local function buildReport(entry)
    local preferId = getPreferVerticalId()
    local groupData = entry.group
    local groupName = entry.groupName or groupData.name or "<sin nombre>"

    local hits = recursiveSearch(groupData, "group", preferId, {}, 0)
    local routeTasks = extractRouteTasks(groupData)
    local live = inspectLiveGroup(groupName)

    local report = {
        meta = {
            script = "HDEV_PreferVerticalInspector.lua",
            version = 1,
            missionTime = timer and timer.getTime and timer.getTime() or nil,
            theatre = env and env.mission and env.mission.theatre or nil,
            preferVerticalId = preferId,
            note = "Si aparece PREFER_VERTICAL_OPTION, esa es la estructura exacta que debemos replicar en dynAdd.",
        },
        missionGroupInfo = {
            groupName = groupName,
            coalitionName = entry.coalitionName,
            coalitionId = entry.coalitionId,
            countryName = entry.countryName,
            countryId = entry.countryId,
            category = entry.category,
        },
        liveGroupInfo = live,
        routePointsCompact = routeTasks,
        hits = hits,
        fullGroup = groupData,
    }

    return report
end

local function summaryText(reports)
    local lines = {}
    lines[#lines + 1] = "HDEV Prefer Vertical Inspector"
    lines[#lines + 1] = "Version: 1"
    lines[#lines + 1] = "Mission time: " .. tostring(timer and timer.getTime and timer.getTime() or "N/A")
    lines[#lines + 1] = "Theatre: " .. tostring(env and env.mission and env.mission.theatre or "N/A")
    lines[#lines + 1] = "AI.Option.Air.id.PREFER_VERTICAL: " .. tostring(getPreferVerticalId())
    lines[#lines + 1] = "Output dir: " .. tostring(PVI.CONFIG.OUTPUT_DIR)
    lines[#lines + 1] = ""

    for _, report in ipairs(reports or {}) do
        local info = report.missionGroupInfo or {}
        lines[#lines + 1] = "============================================================"
        lines[#lines + 1] = "GROUP: " .. tostring(info.groupName)
        lines[#lines + 1] = "Coalition: " .. tostring(info.coalitionName) .. " / " .. tostring(info.coalitionId)
        lines[#lines + 1] = "Country: " .. tostring(info.countryName) .. " / " .. tostring(info.countryId)
        lines[#lines + 1] = "Live exists: " .. tostring(report.liveGroupInfo and report.liveGroupInfo.exists)
        lines[#lines + 1] = "Hits: " .. tostring(#(report.hits or {}))
        lines[#lines + 1] = ""

        for _, hit in ipairs(report.hits or {}) do
            lines[#lines + 1] = "- kind=" .. tostring(hit.kind)
                .. " path=" .. tostring(hit.path)
                .. " optionName=" .. tostring(hit.optionName)
                .. " optionValue=" .. tostring(hit.optionValue)
                .. " key=" .. tostring(hit.key)
                .. " valueType=" .. type(hit.value)
        end

        lines[#lines + 1] = ""
        lines[#lines + 1] = "ROUTE POINTS:"
        for _, wp in ipairs(report.routePointsCompact or {}) do
            lines[#lines + 1] = "  WP" .. tostring(wp.wpIndex)
                .. " type=" .. tostring(wp.type)
                .. " action=" .. tostring(wp.action)
                .. " alt=" .. tostring(wp.alt)
                .. " alt_type=" .. tostring(wp.alt_type)
                .. " speed=" .. tostring(wp.speed)
                .. " airdromeId=" .. tostring(wp.airdromeId)
                .. " helipadId=" .. tostring(wp.helipadId)
        end
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

function PVI.run()
    PVI.STATE.ran = true
    PVI.STATE.found = {}
    PVI.STATE.reports = {}

    if not lfs or not io then
        warn("ERROR: lfs/io no disponibles. Revisa MissionScripting.lua sanitizeModule.")
        return false
    end

    if not env or not env.mission then
        warn("ERROR: env.mission no disponible.")
        return false
    end

    local allHelis = collectMissionHelicopterGroups()
    local selected = {}
    local targetCount = 0
    for _, _ in pairs(targetNameSet()) do targetCount = targetCount + 1 end

    for _, entry in ipairs(allHelis) do
        if groupMatchesTarget(entry.groupName) then
            selected[#selected + 1] = entry
        end
    end

    if #selected == 0 and PVI.CONFIG.INSPECT_ALL_HELICOPTERS_IF_TARGETS_NOT_FOUND then
        selected = allHelis
        warn("No encontre TARGET_GROUP_NAMES. Inspeccionare todos los helicopteros de env.mission: " .. tostring(#selected))
    end

    if #selected == 0 then
        warn("No encontre grupos de helicopteros para inspeccionar.")
        return false
    end

    ensureDir(PVI.CONFIG.OUTPUT_DIR)

    for _, entry in ipairs(selected) do
        local report = buildReport(entry)
        PVI.STATE.reports[#PVI.STATE.reports + 1] = report

        local name = report.missionGroupInfo and report.missionGroupInfo.groupName or entry.groupName or "GROUP"
        local basePath = PVI.CONFIG.OUTPUT_DIR .. safeName(name)

        if PVI.CONFIG.WRITE_FULL_GROUP_DUMP then
            writeFile(basePath .. "_FULL.lua", "return " .. serializeLua(report.fullGroup, 0, {}) .. "\n")
            writeFile(basePath .. "_REPORT.lua", "return " .. serializeLua(report, 0, {}) .. "\n")
            local json = tryJson(report)
            if json then
                writeFile(basePath .. "_REPORT.json", json)
            end
        end
    end

    if PVI.CONFIG.WRITE_SUMMARY then
        writeFile(PVI.CONFIG.OUTPUT_DIR .. "SUMMARY.txt", summaryText(PVI.STATE.reports))
    end

    log("Inspector terminado. Grupos inspeccionados: " .. tostring(#PVI.STATE.reports))
    log("Revisa: " .. tostring(PVI.CONFIG.OUTPUT_DIR))

    return true
end

-- Ejecutar automaticamente 3 segundos despues para dejar cargar env.mission/grupos.
timer.scheduleFunction(function()
    PVI.run()
    return nil
end, nil, timer.getTime() + 3)

