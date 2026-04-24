if not mist then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

HDEV_NavalPersist = HDEV_NavalPersist or {}
local NAVP = HDEV_NavalPersist

NAVP.CONFIG = {
    DEBUG = false,

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\SINAI\\SystemUnitPositionPersistence.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 300,

    PRESERVE_ROUTE = true,

    GROUPS = {
        {
            key = "Marshall",
            templateGroupName = "Marshall",
            liveGroupName = "Marshall",
            enabled = true
        },
        {
            key = "Tarawa",
            templateGroupName = "Tarawa",
            liveGroupName = "Tarawa",
            enabled = true
        }
    }
}

NAVP.STATE = {
    started = false,
    injecting = false,
    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,
    doc = nil,
    injectDoneByKey = {},
    firstInjectCycleDone = false
}

local function log(msg)
    env.info("[NAVP] " .. tostring(msg))
    if NAVP.CONFIG.DEBUG then
        trigger.action.outText("[NAVP] " .. tostring(msg), 8)
    end
end

local function round(n, d)
    n = tonumber(n) or 0
    local m = 10 ^ (d or 0)
    return math.floor((n * m) + 0.5) / m
end

local function deepCopy(tbl)
    if mist and mist.utils and mist.utils.deepCopy then
        return mist.utils.deepCopy(tbl)
    end
    if type(tbl) ~= "table" then
        return tbl
    end
    local out = {}
    for k, v in pairs(tbl) do
        out[k] = deepCopy(v)
    end
    return out
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

local function loadSyncFile()
    local txt = safeReadFile(NAVP.CONFIG.FILE_PATH)
    if not txt then
        return nil, "no existe archivo"
    end
    return decodeJson(txt)
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

local function saveSyncFile(tbl)
    return safeWriteFile(NAVP.CONFIG.FILE_PATH, encodeJsonValue(tbl, 0))
end

local function groupExistsByName(groupName)
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

local function getTemplateData(templateGroupName)
    if not mist or not mist.DBs or not mist.DBs.MEgroupsByName then
        return nil
    end

    local data = mist.DBs.MEgroupsByName[templateGroupName]
    if not data then
        return nil
    end

    return deepCopy(data)
end

local function getLiveGroupName(cfg)
    return cfg.liveGroupName or cfg.templateGroupName
end

local function buildVec3Sea(mapX, mapY)
    return {
        x = round(mapX, 3),
        y = 0,
        z = round(mapY, 3)
    }
end

local function buildDefaultEntryFromTemplate(cfg)
    local template = getTemplateData(cfg.templateGroupName)
    if not template then
        return nil, "Plantilla no encontrada: " .. tostring(cfg.templateGroupName)
    end

    if not template.units or not template.units[1] then
        return nil, "Plantilla naval sin unidades"
    end

    local lead = template.units[1]

    local entry = {
        key = cfg.key,
        enabled = (cfg.enabled ~= false),
        templateGroupName = cfg.templateGroupName,
        liveGroupName = getLiveGroupName(cfg),
        runtimeGroupName = nil,
        alive = true,
        runtimePresent = true,
        category = "ship",
        coalition = template.coalition,
        coalitionId = template.coalitionId,
        country = template.country,
        countryId = template.countryId,
        lastSeenMissionTime = 0,
        anchor = {
            mapPoint = {
                x = round(lead.x or 0, 3),
                y = round(lead.y or 0, 3)
            },
            point = buildVec3Sea(lead.x or 0, lead.y or 0),
            heading = round(lead.heading or 0, 6)
        },
        units = {}
    }

    for i, unit in ipairs(template.units) do
        local ux = tonumber(unit.x) or 0
        local uy = tonumber(unit.y) or 0

        entry.units[#entry.units + 1] = {
            index = i,
            templateUnitName = unit.unitName or unit.name or ("SHIP_" .. tostring(i)),
            runtimeUnitName = nil,
            type = unit.type,
            alive = true,
            life = 1,
            heading = round(unit.heading or 0, 6),
            mapPoint = {
                x = round(ux, 3),
                y = round(uy, 3)
            },
            point = buildVec3Sea(ux, uy)
        }
    end

    return entry
end

local function buildDefaultDocument()
    local doc = {
        control = {
            injectDuration = NAVP.CONFIG.INJECT_DURATION,
            injectInterval = NAVP.CONFIG.INJECT_INTERVAL,
            exportInterval = NAVP.CONFIG.EXPORT_INTERVAL
        },
        meta = {
            mode = "inject",
            missionTime = 0,
            source = "DCS Naval Group Position Persistence",
            note = "El grupo naval original del ME es el persistido"
        },
        groups = {}
    }

    for _, cfg in ipairs(NAVP.CONFIG.GROUPS or {}) do
        if cfg.enabled ~= false then
            local entry, err = buildDefaultEntryFromTemplate(cfg)
            if entry then
                doc.groups[cfg.key] = entry
            else
                log(err)
            end
        end
    end

    return doc
end

local function mergeConfiguredGroupsIntoDoc(doc)
    doc.control = doc.control or {}
    doc.meta = doc.meta or {}
    doc.groups = doc.groups or {}

    for _, cfg in ipairs(NAVP.CONFIG.GROUPS or {}) do
        if not doc.groups[cfg.key] then
            local entry = buildDefaultEntryFromTemplate(cfg)
            if entry then
                doc.groups[cfg.key] = entry
            end
        else
            doc.groups[cfg.key].templateGroupName = cfg.templateGroupName
            doc.groups[cfg.key].liveGroupName = getLiveGroupName(cfg)
            doc.groups[cfg.key].runtimeGroupName = nil
            doc.groups[cfg.key].enabled = (cfg.enabled ~= false)
            doc.groups[cfg.key].category = "ship"
        end
    end
end

local function loadOrBuildDocument()
    local doc = loadSyncFile()
    if type(doc) ~= "table" then
        doc = buildDefaultDocument()
        saveSyncFile(doc)
        return doc
    end

    mergeConfiguredGroupsIntoDoc(doc)
    saveSyncFile(doc)
    return doc
end

local function getFallbackAnchorFromTemplate(cfg)
    local template = getTemplateData(cfg.templateGroupName)
    if not template or not template.units or not template.units[1] then
        return 0, 0
    end

    return tonumber(template.units[1].x) or 0, tonumber(template.units[1].y) or 0
end

local function injectEntry(cfg, entry)
    if entry.enabled == false then
        return true, "deshabilitado"
    end

    if entry.alive == false then
        return true, "marcado muerto en JSON"
    end

    local liveGroupName = getLiveGroupName(cfg)
    local grp = groupExistsByName(liveGroupName)

    if not grp then
        return false, "No existe el grupo original en la misión: " .. tostring(liveGroupName)
    end

    local fallbackX, fallbackY = getFallbackAnchorFromTemplate(cfg)

    local targetX =
        tonumber(entry and entry.anchor and entry.anchor.mapPoint and entry.anchor.mapPoint.x)
        or fallbackX

    local targetY =
        tonumber(entry and entry.anchor and entry.anchor.mapPoint and entry.anchor.mapPoint.y)
        or fallbackY

    local ok, result = pcall(function()
        return mist.teleportToPoint({
            gpName = liveGroupName,
            action = "teleport",
            point = { x = targetX, y = targetY },
            radius = 0,
            maxDisp = 0,
            offsetRoute = NAVP.CONFIG.PRESERVE_ROUTE and true or false
        })
    end)

    if not ok or not result then
        return false, result or "mist.teleportToPoint devolvio nil"
    end

    return true, result
end

local function injectFromJson()
    local doc, err = loadSyncFile()
    if not doc then
        log("No se pudo leer JSON: " .. tostring(err))
        return
    end

    mergeConfiguredGroupsIntoDoc(doc)
    NAVP.STATE.doc = doc

    for _, cfg in ipairs(NAVP.CONFIG.GROUPS or {}) do
        local entry = doc.groups and doc.groups[cfg.key] or nil
        if entry and not NAVP.STATE.injectDoneByKey[cfg.key] then
            local ok, res = injectEntry(cfg, entry)
            if ok then
                NAVP.STATE.injectDoneByKey[cfg.key] = true
                log("Grupo naval movido: " .. tostring(getLiveGroupName(cfg)))
            else
                log("Error moviendo grupo naval: " .. tostring(res))
            end
        end
    end

    NAVP.STATE.firstInjectCycleDone = true
end

local function getHeadingSafe(obj, fallback)
    fallback = tonumber(fallback) or 0
    if mist and mist.getHeading then
        local ok, h = pcall(function()
            return mist.getHeading(obj, true)
        end)
        if ok and type(h) == "number" then
            return h
        end
    end
    return fallback
end

local function getLifeSafe(unit)
    local ok, life = pcall(function()
        return unit:getLife()
    end)
    if ok and type(life) == "number" then
        return life
    end
    return 0
end

local function snapshotLiveGroup(cfg, prevEntry)
    local liveGroupName = getLiveGroupName(cfg)
    local grp = groupExistsByName(liveGroupName)
    local entry = deepCopy(prevEntry or {})

    entry.key = cfg.key
    entry.enabled = (cfg.enabled ~= false)
    entry.templateGroupName = cfg.templateGroupName
    entry.liveGroupName = liveGroupName
    entry.runtimeGroupName = nil
    entry.category = "ship"
    entry.lastSeenMissionTime = timer.getTime()

    if not grp then
        entry.runtimePresent = false
        entry.alive = false
        return entry
    end

    local units = grp:getUnits() or {}
    local aliveCount = 0
    local anchorUnit = nil
    local snapUnits = {}

    for i, unit in ipairs(units) do
        if unit and unit:isExist() then
            local p = unit:getPoint()
            local life = getLifeSafe(unit)
            local isAlive = life > 0

            if isAlive then
                aliveCount = aliveCount + 1
                if not anchorUnit then
                    anchorUnit = unit
                end
            end

            snapUnits[#snapUnits + 1] = {
                index = i,
                templateUnitName = prevEntry and prevEntry.units and prevEntry.units[i] and prevEntry.units[i].templateUnitName or nil,
                runtimeUnitName = unit:getName(),
                type = unit:getTypeName(),
                alive = isAlive,
                life = round(life, 3),
                heading = round(getHeadingSafe(unit, 0), 6),
                mapPoint = {
                    x = round(p.x or 0, 3),
                    y = round(p.z or 0, 3)
                },
                point = {
                    x = round(p.x or 0, 3),
                    y = round(p.y or 0, 3),
                    z = round(p.z or 0, 3)
                }
            }
        end
    end

    if not anchorUnit and units[1] and units[1]:isExist() then
        anchorUnit = units[1]
    end

    if anchorUnit then
        local ap = anchorUnit:getPoint()
        entry.anchor = {
            mapPoint = {
                x = round(ap.x or 0, 3),
                y = round(ap.z or 0, 3)
            },
            point = {
                x = round(ap.x or 0, 3),
                y = round(ap.y or 0, 3),
                z = round(ap.z or 0, 3)
            },
            heading = round(getHeadingSafe(anchorUnit, 0), 6)
        }
    end

    entry.units = snapUnits
    entry.runtimePresent = true
    entry.alive = (aliveCount > 0)

    return entry
end

local function exportLiveToJson()
    local doc = loadSyncFile() or NAVP.STATE.doc or buildDefaultDocument()
    mergeConfiguredGroupsIntoDoc(doc)

    doc.meta.mode = NAVP.STATE.injecting and "inject" or "live"
    doc.meta.missionTime = timer.getTime()
    doc.meta.source = "DCS Naval live group"
    doc.meta.note = "El grupo naval original del ME es el persistido"

    for _, cfg in ipairs(NAVP.CONFIG.GROUPS or {}) do
        if doc.groups[cfg.key] then
            doc.groups[cfg.key] = snapshotLiveGroup(cfg, doc.groups[cfg.key])
        end
    end

    if saveSyncFile(doc) then
        NAVP.STATE.doc = doc
    end
end

local function mainLoop(_, now)
    if not NAVP.STATE.started then
        return now + 1
    end

    if NAVP.STATE.injecting then
        if now <= NAVP.STATE.injectEndsAt then
            if (now - NAVP.STATE.lastInject) >= NAVP.CONFIG.INJECT_INTERVAL then
                NAVP.STATE.lastInject = now
                injectFromJson()
            end
        else
            NAVP.STATE.injecting = false
            log("Fin ventana de inyeccion naval. DCS toma control.")
            exportLiveToJson()
            NAVP.STATE.lastExport = now
        end
    else
        if (now - NAVP.STATE.lastExport) >= NAVP.CONFIG.EXPORT_INTERVAL then
            NAVP.STATE.lastExport = now
            exportLiveToJson()
        end
    end

    return now + 1
end

local function validateEnvironment()
    if not mist or not mist.teleportToPoint then
        return false, "MIST no cargado o mist.teleportToPoint no disponible"
    end
    if not mist.DBs or not mist.DBs.MEgroupsByName then
        return false, "mist.DBs.MEgroupsByName no disponible"
    end
    if not io or not lfs then
        return false, "io/lfs no disponibles"
    end
    if not net or not net.json2lua then
        return false, "net.json2lua no disponible"
    end
    return true
end

local function startNavalPersistence()
    local ok, err = validateEnvironment()
    if not ok then
        log("No se pudo iniciar: " .. tostring(err))
        return
    end

    local doc = loadOrBuildDocument()
    NAVP.STATE.doc = doc
    NAVP.STATE.started = true
    NAVP.STATE.injecting = true
    NAVP.STATE.injectEndsAt = timer.getTime() + NAVP.CONFIG.INJECT_DURATION
    NAVP.STATE.lastInject = -9999
    NAVP.STATE.lastExport = -9999
    NAVP.STATE.injectDoneByKey = {}
    NAVP.STATE.firstInjectCycleDone = false

    injectFromJson()
    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)
end

startNavalPersistence()