----------------------------------------------------------------
-- HDEV_PersistentNotes.lua
-- Notas persistentes por marcas F10
--
-- Uso:
-- save: mensaje cualquiera
--
-- Crea el JSON apenas carga.
-- Si agregas una marca F10 con "save:", la guarda.
-- Si editas la marca, actualiza el JSON.
-- Si borras la marca, elimina esa nota del JSON.
-- Al reiniciar, restaura las notas guardadas en el mapa.
----------------------------------------------------------------

HDEV_PersistentNotes = HDEV_PersistentNotes or {}
local PN = HDEV_PersistentNotes

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------
PN.CONFIG = {
    DEBUG = false,

    KEYWORD = "save",

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\PersistentNotes.json",

    RESTORE_ON_START = true,
    RESTORE_DELAY = 3,

    MARK_ID_START = 980000,

    RESTORED_MARK_READ_ONLY = false,

    SHOW_MESSAGES = true,
    MESSAGE_TIME = 6
}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
PN.STATE = PN.STATE or {
    initialized = false,
    notes = {},
    markToNoteId = {},
    nextNoteNumber = 1,
    nextMarkId = PN.CONFIG.MARK_ID_START,
    ignoreMarks = {},
    lastPayload = ""
}

local CFG = PN.CONFIG
local STATE = PN.STATE

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg)
    env.info("[HDEV_NOTES] " .. tostring(msg))
    if CFG.DEBUG and CFG.SHOW_MESSAGES then
        trigger.action.outText("[HDEV_NOTES] " .. tostring(msg), CFG.MESSAGE_TIME)
    end
end

local function warn(msg)
    env.info("[HDEV_NOTES_ERROR] " .. tostring(msg))
    trigger.action.outText("[HDEV_NOTES_ERROR] " .. tostring(msg), 12)
end

----------------------------------------------------------------
-- VALIDACION
----------------------------------------------------------------
if not lfs or not lfs.writedir then
    trigger.action.outText("ERROR HDEV_NOTES: lfs no esta habilitado.", 15)
    return
end

if not io or not io.open then
    trigger.action.outText("ERROR HDEV_NOTES: io no esta habilitado. Revisa MissionScripting.lua.", 15)
    return
end

if not world or not world.addEventHandler then
    trigger.action.outText("ERROR HDEV_NOTES: world.addEventHandler no disponible.", 15)
    return
end

----------------------------------------------------------------
-- EVENTOS DE MARCAS
-- Si por alguna razon DCS no expone las constantes, usamos fallback.
----------------------------------------------------------------
local EVENT_MARK_ADDED  = world.event.S_EVENT_MARK_ADDED  or 25
local EVENT_MARK_CHANGE = world.event.S_EVENT_MARK_CHANGE or 26
local EVENT_MARK_REMOVE = world.event.S_EVENT_MARK_REMOVE or 27

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
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

local function ensureDirectoryForFile(path)
    if not path or path == "" then
        return false
    end

    local separator = "\\"
    local parts = {}

    for part in string.gmatch(path, "[^\\/]+") do
        parts[#parts + 1] = part
    end

    if #parts <= 1 then
        return false
    end

    table.remove(parts, #parts)

    local current = ""

    if path:match("^%a:[\\/]") then
        current = path:sub(1, 3)
        table.remove(parts, 1)
    elseif path:sub(1, 1) == "/" then
        current = "/"
    end

    for _, part in ipairs(parts) do
        if current == "" or current:sub(-1) == "\\" or current:sub(-1) == "/" then
            current = current .. part
        else
            current = current .. separator .. part
        end

        lfs.mkdir(current)
    end

    return true
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

local function safeWriteFile(path, txt)
    ensureDirectoryForFile(path)

    local f, err = io.open(path, "w")
    if not f then
        warn("No se pudo abrir archivo para escritura: " .. tostring(path) .. " | err=" .. tostring(err))
        return false
    end

    f:write(txt or "")

    if f.flush then
        f:flush()
    end

    f:close()

    return true
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
        return "{}"
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

    return data, nil
end

----------------------------------------------------------------
-- PARSEO
----------------------------------------------------------------
local function parseNoteText(text)
    local raw = trim(text)
    if raw == "" then
        return false, nil
    end

    local keyword = string.lower(CFG.KEYWORD or "save")
    local rawLower = string.lower(raw)

    local prefixColon = keyword .. ":"
    local prefixSpace = keyword .. " "

    if rawLower:sub(1, #prefixColon) == prefixColon then
        local msg = trim(raw:sub(#prefixColon + 1))
        if msg ~= "" then
            return true, msg
        end
    end

    if rawLower:sub(1, #prefixSpace) == prefixSpace then
        local msg = trim(raw:sub(#prefixSpace + 1))
        if msg ~= "" then
            return true, msg
        end
    end

    return false, nil
end

local function getPointFromEvent(event)
    if event and event.pos then
        return {
            x = tonumber(event.pos.x) or 0,
            y = tonumber(event.pos.y) or 0,
            z = tonumber(event.pos.z) or 0
        }
    end

    return {
        x = 0,
        y = 0,
        z = 0
    }
end

local function getAuthor(event)
    local author = {
        playerName = nil,
        unitName = nil,
        groupName = nil,
        coalition = nil
    }

    if not event or not event.initiator then
        return author
    end

    local obj = event.initiator

    if obj.getName then
        local ok, value = pcall(function()
            return obj:getName()
        end)
        if ok then
            author.unitName = value
        end
    end

    if obj.getPlayerName then
        local ok, value = pcall(function()
            return obj:getPlayerName()
        end)
        if ok then
            author.playerName = value
        end
    end

    if obj.getCoalition then
        local ok, value = pcall(function()
            return obj:getCoalition()
        end)
        if ok then
            author.coalition = value
        end
    end

    if obj.getGroup then
        local ok, grp = pcall(function()
            return obj:getGroup()
        end)

        if ok and grp and grp.getName then
            local okName, groupName = pcall(function()
                return grp:getName()
            end)

            if okName then
                author.groupName = groupName
            end
        end
    end

    return author
end

----------------------------------------------------------------
-- JSON
----------------------------------------------------------------
local function buildDocument()
    return {
        meta = {
            source = "HDEV_PersistentNotes",
            missionTime = timer.getTime(),
            absTime = timer.getAbsTime(),
            theatre = env.mission and env.mission.theatre or nil,
            keyword = CFG.KEYWORD
        },

        nextNoteNumber = STATE.nextNoteNumber,
        nextMarkId = STATE.nextMarkId,

        notes = STATE.notes or {}
    }
end

local function saveJson(reason)
    local doc = buildDocument()
    local payload = encodeJsonValue(doc, 0)

    local ok = safeWriteFile(CFG.FILE_PATH, payload)

    if ok then
        STATE.lastPayload = payload
        env.info("[HDEV_NOTES] JSON guardado: " .. tostring(CFG.FILE_PATH) .. " | reason=" .. tostring(reason))
        return true
    end

    return false
end

local function loadJson()
    STATE.notes = {}
    STATE.markToNoteId = {}
    STATE.nextNoteNumber = 1
    STATE.nextMarkId = CFG.MARK_ID_START

    local txt = safeReadFile(CFG.FILE_PATH)

    if not txt then
        log("No existia JSON. Creando archivo nuevo en: " .. tostring(CFG.FILE_PATH))
        saveJson("create_new_file")
        return
    end

    local doc, err = decodeJson(txt)

    if not doc then
        warn("No se pudo leer JSON existente. Se reescribira limpio. Error: " .. tostring(err))
        saveJson("rewrite_invalid_json")
        return
    end

    STATE.nextNoteNumber = tonumber(doc.nextNoteNumber) or 1
    STATE.nextMarkId = tonumber(doc.nextMarkId) or CFG.MARK_ID_START
    STATE.notes = type(doc.notes) == "table" and doc.notes or {}

    for noteId, note in pairs(STATE.notes) do
        if type(note) == "table" and note.markId then
            STATE.markToNoteId[tonumber(note.markId)] = noteId
        end
    end

    log("JSON de notas cargado. Notas: " .. tostring(#sortedKeys(STATE.notes)))
end

----------------------------------------------------------------
-- IDS
----------------------------------------------------------------
local function newNoteId()
    local id = string.format("NOTE_%06d", tonumber(STATE.nextNoteNumber) or 1)
    STATE.nextNoteNumber = (tonumber(STATE.nextNoteNumber) or 1) + 1
    return id
end

local function newMarkId()
    local id = tonumber(STATE.nextMarkId) or CFG.MARK_ID_START
    STATE.nextMarkId = id + 1
    return id
end

----------------------------------------------------------------
-- NOTAS
----------------------------------------------------------------
local function createNote(event, message)
    local markId = tonumber(event.idx)
    if not markId then
        return
    end

    local noteId = newNoteId()

    STATE.notes[noteId] = {
        id = noteId,
        markId = markId,
        originalMarkId = markId,
        restoreMarkId = newMarkId(),

        text = tostring(message or ""),
        rawText = tostring(event.text or ""),

        point = getPointFromEvent(event),
        author = getAuthor(event),

        createdAt = timer.getTime(),
        updatedAt = timer.getTime(),
        createdAtAbs = timer.getAbsTime(),
        updatedAtAbs = timer.getAbsTime()
    }

    STATE.markToNoteId[markId] = noteId

    saveJson("create_note")

    if CFG.SHOW_MESSAGES then
        trigger.action.outText("Nota guardada:\n" .. tostring(message), CFG.MESSAGE_TIME)
    end
end

local function updateNote(noteId, event, message)
    local note = STATE.notes[noteId]
    if not note then
        return
    end

    local markId = tonumber(event.idx)
    if not markId then
        return
    end

    note.markId = markId
    note.text = tostring(message or "")
    note.rawText = tostring(event.text or "")
    note.point = getPointFromEvent(event)
    note.author = getAuthor(event)
    note.updatedAt = timer.getTime()
    note.updatedAtAbs = timer.getAbsTime()

    STATE.markToNoteId[markId] = noteId

    saveJson("update_note")

    if CFG.SHOW_MESSAGES then
        trigger.action.outText("Nota actualizada:\n" .. tostring(message), CFG.MESSAGE_TIME)
    end
end

local function deleteNote(noteId)
    local note = STATE.notes[noteId]
    if not note then
        return
    end

    if note.markId then
        STATE.markToNoteId[tonumber(note.markId)] = nil
    end

    STATE.notes[noteId] = nil

    saveJson("delete_note")

    if CFG.SHOW_MESSAGES then
        trigger.action.outText("Nota eliminada del JSON.", CFG.MESSAGE_TIME)
    end
end

----------------------------------------------------------------
-- RESTAURAR MARCAS
----------------------------------------------------------------
local function ignoreMark(markId)
    STATE.ignoreMarks[tonumber(markId)] = timer.getTime() + 5
end

local function isIgnoredMark(markId)
    markId = tonumber(markId)

    if not markId then
        return false
    end

    local untilTime = STATE.ignoreMarks[markId]

    if not untilTime then
        return false
    end

    if timer.getTime() <= untilTime then
        return true
    end

    STATE.ignoreMarks[markId] = nil
    return false
end

local function restoreNotes()
    if not CFG.RESTORE_ON_START then
        return
    end

    local count = 0

    for noteId, note in pairs(STATE.notes or {}) do
        if type(note) == "table" and note.point then
            local restoreId = tonumber(note.restoreMarkId) or newMarkId()
            note.restoreMarkId = restoreId
            note.markId = restoreId

            STATE.markToNoteId[restoreId] = noteId
            ignoreMark(restoreId)

            local text = tostring(CFG.KEYWORD) .. ": " .. tostring(note.text or "")

            trigger.action.markToAll(
                restoreId,
                text,
                {
                    x = tonumber(note.point.x) or 0,
                    y = tonumber(note.point.y) or 0,
                    z = tonumber(note.point.z) or 0
                },
                CFG.RESTORED_MARK_READ_ONLY == true
            )

            count = count + 1
        end
    end

    saveJson("restore_notes")

    log("Notas restauradas en F10: " .. tostring(count))
end

----------------------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------------------
local handler = {}

function handler:onEvent(event)
    if not event or not event.id then
        return
    end

    if event.id == EVENT_MARK_ADDED or event.id == EVENT_MARK_CHANGE then
        local markId = tonumber(event.idx)

        if not markId then
            return
        end

        if isIgnoredMark(markId) then
            return
        end

        local isNote, message = parseNoteText(event.text or "")
        local existingNoteId = STATE.markToNoteId[markId]

        if existingNoteId then
            if isNote then
                updateNote(existingNoteId, event, message)
            else
                deleteNote(existingNoteId)
            end

            return
        end

        if isNote then
            createNote(event, message)
        end

        return
    end

    if event.id == EVENT_MARK_REMOVE then
        local markId = tonumber(event.idx)

        if not markId then
            return
        end

        if isIgnoredMark(markId) then
            return
        end

        local existingNoteId = STATE.markToNoteId[markId]

        if existingNoteId then
            deleteNote(existingNoteId)
        end

        return
    end
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
local function start()
    if STATE.initialized then
        return
    end

    STATE.initialized = true

    loadJson()

    local created = saveJson("startup_forced_create")

    if created then
        log("Sistema iniciado. JSON: " .. tostring(CFG.FILE_PATH))
    else
        warn("El sistema inicio, pero NO pudo crear el JSON.")
    end

    world.addEventHandler(handler)

    timer.scheduleFunction(function()
        restoreNotes()
        return nil
    end, nil, timer.getTime() + (CFG.RESTORE_DELAY or 3))
end

start()