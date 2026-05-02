----------------------------------------------------------------
-- HDEV_StaticCargoPersistence.lua
--
-- Persistencia de estaticos de carga
--
-- OBJETIVO:
-- - Monitorear estaticos de carga por nombre.
-- - Si uno muere, guardarlo en JSON como destruido.
-- - Al reiniciar la mision, durante 30 segundos el JSON manda.
-- - Si el JSON dice que el item esta muerto, el script lo destruye.
-- - Luego de la ventana de inyeccion, DCS toma control y el JSON
--   pasa a ser espejo vivo del estado real.
--
-- REQUIERE:
-- - io/lfs habilitados en MissionScripting.lua
-- - net.json2lua habilitado
-- - MIST cargado antes si quieres autodeteccion desde el ME
----------------------------------------------------------------

HDEV_StaticCargoPersistence = HDEV_StaticCargoPersistence or {}
local SCP = HDEV_StaticCargoPersistence

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------
SCP.CONFIG = SCP.CONFIG or {
    DEBUG = true,

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\SystemStaticCargoPersistenceKola.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 300,
    MIN_WRITE_INTERVAL = 3,
    MAIN_LOOP_INTERVAL = 1,

    -- Si la vida es menor o igual a esto, se considera destruido.
    DEATH_LIFE_THRESHOLD = 1,

    -- Si true, usa MIST para encontrar estaticos del ME.
    AUTO_DISCOVER_FROM_MIST = false,

    -- Si true, solo autodetecta estaticos que parezcan carga.
    ONLY_CARGO_STATICS = false,

    -- Si true, si el JSON dice muerto, queda bloqueado como muerto.
    KEEP_DEAD_LOCKED = true,

    -- Normalmente dejalo false.
    -- Si true, intenta recrear estaticos si el JSON dice vivo y no existen.
    -- Para eso el JSON debe tener type, countryId y posicion.
    RESPAWN_MISSING_IF_JSON_ALIVE = false,

    -- Guardar de inmediato cuando se detecta una muerte.
    IMMEDIATE_SAVE_ON_DEATH = true,

    -- Si true, intenta registrar estaticos runtime nacidos en mision
    -- cuando coincidan con los prefijos configurados.
    AUTO_TRACK_RUNTIME_BIRTHS = false,

    -- Lista manual de nombres exactos de estaticos en el Mission Editor.
    -- Si no quieres depender de autodeteccion, llena esta lista.
    TRACKED_STATIC_NAMES = {
        "Cargo01",
        "Cargo02",
        "Cargo03",
        "Cargo04",
        "Cargo05",
        "Cargo06",
        "Cargo07",
        "Cargo08",
        "Cargo09",
        "Cargo10",
        "Cargo11",
        "Cargo12",
        "Cargo13",
        "Cargo14",
        "Cargo15",
        "Cargo16",
        "Cargo17",
        "Cargo18",
        "Cargo19",
        "Cargo20",
        "Cargo21",
        "Cargo22",
        "Cargo23",
        "Cargo24",
        "Cargo25",
        "Cargo26",
        "Cargo27",
        "Cargo28",
        "Cargo29",
        "Cargo30",
        "Cargo31",
        "Cargo32",
        "Cargo33",
        "Cargo34",
        "Cargo35",
        "Cargo36",
        "Cargo37",
        "Cargo38",
        "Cargo39",
        "Cargo40",
        "Cargo41",
        "Cargo42",
        "Cargo43",
        "Cargo44",
        "Cargo45",
        "Cargo46",
        "Cargo47",
        "Cargo48",
        "Cargo49",
        "Cargo50",
    },

    -- Prefijos usados para autodeteccion por nombre.
    DISCOVER_PREFIXES = {
        
    }
}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
SCP.STATE = SCP.STATE or {
    started = false,
    injecting = false,
    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,
    lastWriteTime = -9999,

    doc = nil,
    tracked = {},
    dirty = false,
    eventHandlerRegistered = false,
    lastSavedPayload = ""
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg, seconds)
    env.info("[STATIC_CARGO_PERSIST] " .. tostring(msg))
    if SCP.CONFIG.DEBUG then
        trigger.action.outText("[STATIC_CARGO_PERSIST] " .. tostring(msg), seconds or 8)
    end
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function now()
    return timer.getTime()
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

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function startsWithAnyPrefix(name)
    local n = string.lower(tostring(name or ""))

    for _, prefix in ipairs(SCP.CONFIG.DISCOVER_PREFIXES or {}) do
        local p = string.lower(tostring(prefix or ""))

        if p ~= "" and n:sub(1, #p) == p then
            return true
        end
    end

    return false
end

----------------------------------------------------------------
-- FILE / JSON
----------------------------------------------------------------
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

            lines[#lines + 1] =
                string.rep(" ", indent + 2) ..
                encodeJsonValue(value[i], indent + 2) ..
                comma
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

local function loadSyncFile()
    local txt = safeReadFile(SCP.CONFIG.FILE_PATH)

    if not txt then
        return nil, "no existe archivo"
    end

    return decodeJson(txt)
end

local function saveSyncFile(doc, force)
    local payload = encodeJsonValue(doc or {}, 0)

    if not force and payload == SCP.STATE.lastSavedPayload then
        return true
    end

    if not safeWriteFile(SCP.CONFIG.FILE_PATH, payload) then
        log("No se pudo escribir JSON: " .. tostring(SCP.CONFIG.FILE_PATH), 10)
        return false
    end

    SCP.STATE.lastSavedPayload = payload
    SCP.STATE.lastWriteTime = now()
    SCP.STATE.dirty = false

    return true
end

local function readControlOverrides(doc)
    if type(doc) ~= "table" or type(doc.control) ~= "table" then
        return
    end

    local c = doc.control

    if tonumber(c.injectDuration) then
        SCP.CONFIG.INJECT_DURATION = tonumber(c.injectDuration)
    end

    if tonumber(c.injectInterval) then
        SCP.CONFIG.INJECT_INTERVAL = tonumber(c.injectInterval)
    end

    if tonumber(c.exportInterval) then
        SCP.CONFIG.EXPORT_INTERVAL = tonumber(c.exportInterval)
    end

    if tonumber(c.minWriteInterval) then
        SCP.CONFIG.MIN_WRITE_INTERVAL = tonumber(c.minWriteInterval)
    end
end

----------------------------------------------------------------
-- DCS OBJECT HELPERS
----------------------------------------------------------------
local function getStaticByName(name)
    if not name or name == "" or not StaticObject or not StaticObject.getByName then
        return nil
    end

    local obj = StaticObject.getByName(name)

    if not obj then
        return nil
    end

    local ok, exists = pcall(function()
        return obj:isExist()
    end)

    if ok and exists then
        return obj
    end

    return nil
end

local function safeGetName(obj)
    if obj and obj.getName then
        local ok, value = pcall(function()
            return obj:getName()
        end)

        if ok and value then
            return value
        end
    end

    return nil
end

local function safeGetType(obj)
    if obj and obj.getTypeName then
        local ok, value = pcall(function()
            return obj:getTypeName()
        end)

        if ok and value then
            return value
        end
    end

    return nil
end

local function safeGetLife(obj)
    if obj and obj.getLife then
        local ok, value = pcall(function()
            return obj:getLife()
        end)

        if ok and value ~= nil then
            return tonumber(value)
        end
    end

    return nil
end

local function safeGetPoint(obj)
    if obj and obj.getPoint then
        local ok, value = pcall(function()
            return obj:getPoint()
        end)

        if ok and value then
            return value
        end
    end

    return nil
end

local function safeGetPosition(obj)
    if obj and obj.getPosition then
        local ok, value = pcall(function()
            return obj:getPosition()
        end)

        if ok and value then
            return value
        end
    end

    return nil
end

local function safeGetCoalition(obj)
    if obj and obj.getCoalition then
        local ok, value = pcall(function()
            return obj:getCoalition()
        end)

        if ok and value ~= nil then
            return tonumber(value)
        end
    end

    return nil
end

local function safeGetCountry(obj)
    if obj and obj.getCountry then
        local ok, value = pcall(function()
            return obj:getCountry()
        end)

        if ok and value ~= nil then
            return tonumber(value)
        end
    end

    return nil
end

local function safeGetCategory(obj)
    if obj and obj.getCategory then
        local ok, value = pcall(function()
            return obj:getCategory()
        end)

        if ok and value ~= nil then
            return tonumber(value)
        end
    end

    return nil
end

local function getHeadingFromObject(obj, fallback)
    local pos = safeGetPosition(obj)

    if pos and pos.x then
        local x = pos.x.x or 1
        local z = pos.x.z or 0

        if math.atan2 then
            return math.atan2(z, x)
        end

        if math.atan then
            return math.atan(z, x)
        end
    end

    return tonumber(fallback) or 0
end

local function isStaticAlive(obj)
    if not obj then
        return false
    end

    local life = safeGetLife(obj)

    if life == nil then
        return true
    end

    return life > (tonumber(SCP.CONFIG.DEATH_LIFE_THRESHOLD) or 1)
end

local function destroyStaticIfExists(name, reason)
    local obj = getStaticByName(name)

    if not obj then
        return false
    end

    pcall(function()
        obj:destroy()
    end)

    log("Estatico destruido por persistencia: " .. tostring(name) .. " | " .. tostring(reason or ""), 6)

    return true
end

----------------------------------------------------------------
-- DISCOVERY
----------------------------------------------------------------
local function looksLikeCargoStatic(data)
    if SCP.CONFIG.ONLY_CARGO_STATICS ~= true then
        return true
    end

    if not data then
        return false
    end

    if data.canCargo == true then
        return true
    end

    local name = tostring(data.unitName or data.name or "")
    local typeName = string.lower(tostring(data.type or ""))
    local categoryStatic = string.lower(tostring(data.categoryStatic or data.category or ""))

    if startsWithAnyPrefix(name) then
        return true
    end

    if typeName:find("cargo", 1, true) then
        return true
    end

    if categoryStatic:find("cargo", 1, true) then
        return true
    end

    if categoryStatic:find("cargos", 1, true) then
        return true
    end

    return false
end

local function discoverStaticCargoFromMist()
    local found = {}

    if SCP.CONFIG.AUTO_DISCOVER_FROM_MIST ~= true then
        return found
    end

    if not mist or not mist.DBs or not mist.DBs.MEunitsByCat or not mist.DBs.MEunitsByCat.static then
        return found
    end

    for _, data in pairs(mist.DBs.MEunitsByCat.static or {}) do
        local name = data.unitName or data.name

        if name and name ~= "" and looksLikeCargoStatic(data) then
            found[name] = deepCopy(data)
        end
    end

    return found
end

local function discoverConfiguredStatics()
    local found = {}

    for _, name in ipairs(SCP.CONFIG.TRACKED_STATIC_NAMES or {}) do
        name = trim(name)

        if name ~= "" then
            found[name] = found[name] or {
                unitName = name
            }
        end
    end

    local auto = discoverStaticCargoFromMist()

    for name, data in pairs(auto) do
        found[name] = data
    end

    return found
end

----------------------------------------------------------------
-- SNAPSHOTS
----------------------------------------------------------------
local function buildEntryFromMistData(name, data)
    data = data or {}

    local mapX = tonumber(data.x or (data.point and data.point.x)) or 0
    local mapY = tonumber(data.y or (data.point and data.point.y)) or 0

    return {
        name = name,
        enabled = true,

        alive = true,
        status = 1,
        present = getStaticByName(name) ~= nil,
        destroyed = false,

        type = data.type,
        category = "static",
        categoryStatic = data.categoryStatic,
        canCargo = data.canCargo and true or false,
        mass = data.mass,
        shape_name = data.shape_name,

        coalition = data.coalition,
        coalitionId = data.coalitionId,
        country = data.country,
        countryId = data.countryId,

        heading = round(data.heading or 0, 6),

        mapPoint = {
            x = round(mapX, 3),
            y = round(mapY, 3)
        },

        point = {
            x = round(mapX, 3),
            y = 0,
            z = round(mapY, 3)
        },

        life = nil,
        lastSeenMissionTime = 0,
        destroyedAt = nil,
        lastChangeTime = now()
    }
end

local function markEntryDead(entry, name)
    entry = entry or {}

    entry.name = entry.name or name
    entry.enabled = entry.enabled ~= false

    entry.alive = false
    entry.status = 2
    entry.present = false
    entry.destroyed = true
    entry.life = 0

    if not entry.destroyedAt then
        entry.destroyedAt = now()
    end

    entry.lastChangeTime = now()

    return entry
end

local function snapshotStatic(name, previous)
    previous = previous or {}

    if SCP.CONFIG.KEEP_DEAD_LOCKED == true then
        if previous.alive == false or previous.status == 2 or previous.destroyed == true then
            destroyStaticIfExists(name, "bloqueado como muerto en JSON")
            return markEntryDead(previous, name)
        end
    end

    local obj = getStaticByName(name)

    if not obj then
        return markEntryDead(previous, name)
    end

    local point = safeGetPoint(obj)
    local life = safeGetLife(obj)
    local alive = isStaticAlive(obj)

    if not alive then
        return markEntryDead(previous, name)
    end

    local entry = deepCopy(previous)

    entry.name = name
    entry.enabled = entry.enabled ~= false

    entry.alive = true
    entry.status = 1
    entry.present = true
    entry.destroyed = false
    entry.life = life

    entry.type = entry.type or safeGetType(obj)
    entry.category = "static"
    entry.coalitionId = entry.coalitionId or safeGetCoalition(obj)
    entry.countryId = entry.countryId or safeGetCountry(obj)
    entry.objectCategory = safeGetCategory(obj)

    if point then
        entry.point = {
            x = round(point.x or 0, 3),
            y = round(point.y or 0, 3),
            z = round(point.z or 0, 3)
        }

        entry.mapPoint = {
            x = round(point.x or 0, 3),
            y = round(point.z or 0, 3)
        }
    end

    entry.heading = round(getHeadingFromObject(obj, entry.heading), 6)
    entry.lastSeenMissionTime = now()
    entry.lastChangeTime = now()

    return entry
end

----------------------------------------------------------------
-- DOCUMENT
----------------------------------------------------------------
local function buildDefaultDocument()
    local doc = {
        control = {
            injectDuration = SCP.CONFIG.INJECT_DURATION,
            injectInterval = SCP.CONFIG.INJECT_INTERVAL,
            exportInterval = SCP.CONFIG.EXPORT_INTERVAL,
            minWriteInterval = SCP.CONFIG.MIN_WRITE_INTERVAL
        },

        meta = {
            mode = "bootstrap",
            missionTime = now(),
            source = "DCS Static Cargo Persistence",
            note = "Durante la ventana de inyeccion el JSON manda. Luego DCS toma control."
        },

        statics = {}
    }

    local discovered = discoverConfiguredStatics()

    for name, data in pairs(discovered) do
        local entry = buildEntryFromMistData(name, data)
        entry = snapshotStatic(name, entry)

        doc.statics[name] = entry
        SCP.STATE.tracked[name] = true
    end

    return doc
end

local function mergeConfiguredStaticsIntoDoc(doc)
    doc.control = doc.control or {}
    doc.meta = doc.meta or {}
    doc.statics = doc.statics or {}

    local discovered = discoverConfiguredStatics()

    for name, data in pairs(discovered) do
        if not doc.statics[name] then
            local entry = buildEntryFromMistData(name, data)
            entry = snapshotStatic(name, entry)

            doc.statics[name] = entry
        else
            doc.statics[name].name = name

            if doc.statics[name].enabled == nil then
                doc.statics[name].enabled = true
            end

            doc.statics[name].type = doc.statics[name].type or data.type
            doc.statics[name].categoryStatic = doc.statics[name].categoryStatic or data.categoryStatic
            doc.statics[name].canCargo = doc.statics[name].canCargo or data.canCargo
            doc.statics[name].mass = doc.statics[name].mass or data.mass
            doc.statics[name].shape_name = doc.statics[name].shape_name or data.shape_name
            doc.statics[name].countryId = doc.statics[name].countryId or data.countryId
            doc.statics[name].coalitionId = doc.statics[name].coalitionId or data.coalitionId
        end
    end

    for name, _ in pairs(doc.statics or {}) do
        SCP.STATE.tracked[name] = true
    end
end

local function loadOrBuildDocument()
    local doc, err = loadSyncFile()

    if type(doc) ~= "table" then
        doc = buildDefaultDocument()
        saveSyncFile(doc, true)

        log("No habia JSON previo. Snapshot inicial creado.", 8)

        return doc, false
    end

    readControlOverrides(doc)
    mergeConfiguredStaticsIntoDoc(doc)
    saveSyncFile(doc, true)

    return doc, true
end

----------------------------------------------------------------
-- SPAWN OPCIONAL
----------------------------------------------------------------
local function spawnStaticFromEntry(entry)
    if SCP.CONFIG.RESPAWN_MISSING_IF_JSON_ALIVE ~= true then
        return false
    end

    if not coalition or not coalition.addStaticObject then
        return false
    end

    if not entry or not entry.name or not entry.type then
        return false
    end

    local countryId = tonumber(entry.countryId)

    if not countryId then
        log("No se puede recrear estatico sin countryId: " .. tostring(entry.name), 8)
        return false
    end

    local mapX = nil
    local mapY = nil

    if entry.mapPoint then
        mapX = tonumber(entry.mapPoint.x)
        mapY = tonumber(entry.mapPoint.y)
    end

    if (not mapX or not mapY) and entry.point then
        mapX = tonumber(entry.point.x)
        mapY = tonumber(entry.point.z)
    end

    if not mapX or not mapY then
        log("No se puede recrear estatico sin posicion: " .. tostring(entry.name), 8)
        return false
    end

    local data = {
        name = entry.name,
        type = entry.type,
        category = entry.categoryStatic or "Cargos",
        x = mapX,
        y = mapY,
        heading = tonumber(entry.heading) or 0,
        canCargo = entry.canCargo,
        mass = entry.mass,
        shape_name = entry.shape_name
    }

    local clean = {}

    for k, v in pairs(data) do
        if v ~= nil then
            clean[k] = v
        end
    end

    local ok, result = pcall(function()
        return coalition.addStaticObject(countryId, clean)
    end)

    if ok and result then
        log("Estatico recreado desde JSON: " .. tostring(entry.name), 8)
        return true
    end

    log("Fallo recreando estatico desde JSON: " .. tostring(entry.name), 8)

    return false
end

----------------------------------------------------------------
-- INYECCION
----------------------------------------------------------------
local function shouldBeDeadFromJson(entry)
    if not entry then
        return false
    end

    if entry.alive == false then
        return true
    end

    if entry.status == 2 then
        return true
    end

    if entry.destroyed == true then
        return true
    end

    return false
end

local function injectFromJson()
    local doc, err = loadSyncFile()

    if type(doc) ~= "table" then
        log("No se pudo leer JSON para inyectar: " .. tostring(err), 8)
        return
    end

    readControlOverrides(doc)
    mergeConfiguredStaticsIntoDoc(doc)

    for name, entry in pairs(doc.statics or {}) do
        if entry.enabled ~= false then
            SCP.STATE.tracked[name] = true

            if shouldBeDeadFromJson(entry) then
                destroyStaticIfExists(name, "JSON dice muerto")
            else
                if SCP.CONFIG.RESPAWN_MISSING_IF_JSON_ALIVE == true then
                    if not getStaticByName(name) then
                        spawnStaticFromEntry(entry)
                    end
                end
            end
        end
    end

    SCP.STATE.doc = doc
end

----------------------------------------------------------------
-- EXPORTACION
----------------------------------------------------------------
local function exportLiveToJson(force)
    local doc = loadSyncFile()

    if type(doc) ~= "table" then
        doc = SCP.STATE.doc or buildDefaultDocument()
    end

    readControlOverrides(doc)
    mergeConfiguredStaticsIntoDoc(doc)

    doc.control = doc.control or {}
    doc.control.injectDuration = SCP.CONFIG.INJECT_DURATION
    doc.control.injectInterval = SCP.CONFIG.INJECT_INTERVAL
    doc.control.exportInterval = SCP.CONFIG.EXPORT_INTERVAL
    doc.control.minWriteInterval = SCP.CONFIG.MIN_WRITE_INTERVAL

    doc.meta = doc.meta or {}
    doc.meta.mode = SCP.STATE.injecting and "inject" or "live"
    doc.meta.missionTime = now()
    doc.meta.source = "DCS Static Cargo runtime"

    for name, entry in pairs(doc.statics or {}) do
        if entry.enabled ~= false then
            doc.statics[name] = snapshotStatic(name, entry)
        end
    end

    SCP.STATE.doc = doc

    local t = now()

    if not force and (t - (SCP.STATE.lastWriteTime or -9999)) < SCP.CONFIG.MIN_WRITE_INTERVAL then
        SCP.STATE.dirty = true
        return false
    end

    return saveSyncFile(doc, force == true)
end

----------------------------------------------------------------
-- MUERTES
----------------------------------------------------------------
local function markStaticDeadByName(name, reason)
    if not name or name == "" then
        return
    end

    SCP.STATE.tracked[name] = true

    local doc = loadSyncFile()

    if type(doc) ~= "table" then
        doc = SCP.STATE.doc or buildDefaultDocument()
    end

    doc.statics = doc.statics or {}

    doc.statics[name] = markEntryDead(doc.statics[name] or {
        name = name,
        enabled = true
    }, name)

    doc.statics[name].deathReason = reason or "dead_event"

    SCP.STATE.doc = doc
    SCP.STATE.dirty = true

    if SCP.CONFIG.IMMEDIATE_SAVE_ON_DEATH then
        saveSyncFile(doc, true)
    end

    log("Muerte persistida: " .. tostring(name), 8)
end

----------------------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------------------
local function objectIsStatic(obj)
    local cat = safeGetCategory(obj)

    if Object and Object.Category and Object.Category.STATIC ~= nil then
        return cat == Object.Category.STATIC
    end

    return true
end

local function canAutoTrackRuntimeName(name)
    if SCP.CONFIG.AUTO_TRACK_RUNTIME_BIRTHS ~= true then
        return false
    end

    return startsWithAnyPrefix(name)
end

local handler = {}

function handler:onEvent(event)
    if not event or not event.id then
        return
    end

    if event.id == world.event.S_EVENT_BIRTH then
        if SCP.CONFIG.AUTO_TRACK_RUNTIME_BIRTHS ~= true then
            return
        end

        local obj = event.initiator

        if not obj or not objectIsStatic(obj) then
            return
        end

        local name = safeGetName(obj)

        if not name or name == "" then
            return
        end

        if canAutoTrackRuntimeName(name) then
            SCP.STATE.tracked[name] = true

            local doc = SCP.STATE.doc or loadSyncFile() or buildDefaultDocument()
            doc.statics = doc.statics or {}

            if not doc.statics[name] then
                doc.statics[name] = snapshotStatic(name, {
                    name = name,
                    enabled = true
                })

                SCP.STATE.doc = doc
                SCP.STATE.dirty = true

                log("Estatico runtime registrado: " .. tostring(name), 6)
            end
        end

        return
    end

    if event.id ~= world.event.S_EVENT_DEAD then
        return
    end

    local obj = event.initiator or event.target

    if not obj then
        return
    end

    local name = safeGetName(obj)

    if not name or name == "" then
        return
    end

    if SCP.STATE.tracked[name] then
        markStaticDeadByName(name, "S_EVENT_DEAD")
        return
    end

    if canAutoTrackRuntimeName(name) and objectIsStatic(obj) then
        markStaticDeadByName(name, "S_EVENT_DEAD_RUNTIME")
    end
end

local function registerEventHandler()
    if SCP.STATE.eventHandlerRegistered then
        return
    end

    world.addEventHandler(handler)
    SCP.STATE.eventHandlerRegistered = true
end

----------------------------------------------------------------
-- VALIDACION
----------------------------------------------------------------
local function validateEnvironment()
    if not io or not lfs then
        return false, "io/lfs no disponibles. Revisa MissionScripting.lua"
    end

    if not net or not net.json2lua then
        return false, "net.json2lua no disponible"
    end

    if not StaticObject or not StaticObject.getByName then
        return false, "StaticObject.getByName no disponible"
    end

    return true
end

----------------------------------------------------------------
-- LOOP PRINCIPAL
----------------------------------------------------------------
local function mainLoop(_, currentTime)
    currentTime = currentTime or now()

    if not SCP.STATE.started then
        return currentTime + SCP.CONFIG.MAIN_LOOP_INTERVAL
    end

    if SCP.STATE.injecting then
        if currentTime <= SCP.STATE.injectEndsAt then
            if (currentTime - SCP.STATE.lastInject) >= SCP.CONFIG.INJECT_INTERVAL then
                SCP.STATE.lastInject = currentTime
                injectFromJson()
            end
        else
            SCP.STATE.injecting = false

            log("Fin de ventana de inyeccion. DCS toma control.", 10)

            exportLiveToJson(true)
            SCP.STATE.lastExport = currentTime
        end
    else
        if (currentTime - SCP.STATE.lastExport) >= SCP.CONFIG.EXPORT_INTERVAL then
            SCP.STATE.lastExport = currentTime
            exportLiveToJson(false)
        elseif SCP.STATE.dirty then
            if (currentTime - (SCP.STATE.lastWriteTime or -9999)) >= SCP.CONFIG.MIN_WRITE_INTERVAL then
                exportLiveToJson(true)
            end
        end
    end

    return currentTime + SCP.CONFIG.MAIN_LOOP_INTERVAL
end

----------------------------------------------------------------
-- ARRANQUE
----------------------------------------------------------------
local function startStaticCargoPersistence()
    local ok, err = validateEnvironment()

    if not ok then
        log("No se pudo iniciar: " .. tostring(err), 15)
        return
    end

    registerEventHandler()

    local doc, hadJson = loadOrBuildDocument()

    SCP.STATE.doc = doc
    SCP.STATE.started = true
    SCP.STATE.injecting = hadJson
    SCP.STATE.injectEndsAt = now() + SCP.CONFIG.INJECT_DURATION
    SCP.STATE.lastInject = -9999
    SCP.STATE.lastExport = -9999
    SCP.STATE.dirty = false

    if hadJson then
        log("JSON encontrado. Inyeccion activa por " .. tostring(SCP.CONFIG.INJECT_DURATION) .. " segundos.", 10)
        injectFromJson()
    else
        log("No habia JSON previo. DCS queda como fuente desde el inicio.", 10)
        SCP.STATE.injecting = false
        exportLiveToJson(true)
    end

    timer.scheduleFunction(mainLoop, nil, now() + SCP.CONFIG.MAIN_LOOP_INTERVAL)
end

startStaticCargoPersistence()