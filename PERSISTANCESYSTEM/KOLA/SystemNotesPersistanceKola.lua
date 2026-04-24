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
--
-- Tambien intenta guardar el autor real:
-- playerName, unitName, groupName, groupId, coalition.
----------------------------------------------------------------

HDEV_PersistentNotes = HDEV_PersistentNotes or {}
local PN = HDEV_PersistentNotes

if PN.STATE and PN.STATE.initialized then
    env.info("[HDEV_NOTES] Sistema ya inicializado. No se vuelve a cargar.")
    return
end

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------
PN.CONFIG = {
    DEBUG = true,

    KEYWORD = "save",

    jsonRelativePath = "Config\\HorizontDev\\PersistentNotes.json",

    RESTORE_ON_START = true,
    RESTORE_DELAY = 3,

    MARK_ID_START = 980000,

    RESTORED_MARK_READ_ONLY = false,

    SHOW_MESSAGES = true,
    MESSAGE_TIME = 6,

    MENU_ENABLED = false,
    MENU_NAME = "Notas persistentes"
}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
PN.STATE = {
    initialized = false,

    notes = {},
    markToNoteId = {},

    nextNoteNumber = 1,
    nextMarkId = PN.CONFIG.MARK_ID_START,

    ignoreMarks = {},
    lastPayload = "",

    menuRoot = nil
}

local CFG = PN.CONFIG
local STATE = PN.STATE

----------------------------------------------------------------
-- VALIDACION BASICA
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
----------------------------------------------------------------
local EVENT_MARK_ADDED  = world.event.S_EVENT_MARK_ADDED  or 25
local EVENT_MARK_CHANGE = world.event.S_EVENT_MARK_CHANGE or 26
local EVENT_MARK_REMOVE = world.event.S_EVENT_MARK_REMOVE or 27

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg)
    env.info("[HDEV_NOTES] " .. tostring(msg))

    if CFG.DEBUG and CFG.SHOW_MESSAGES then
        trigger.action.outText("[HDEV_NOTES] " .. tostring(msg), CFG.MESSAGE_TIME or 6)
    end
end

local function warn(msg)
    env.info("[HDEV_NOTES_ERROR] " .. tostring(msg))
    trigger.action.outText("[HDEV_NOTES_ERROR] " .. tostring(msg), 12)
end

local function out(msg, time)
    if CFG.SHOW_MESSAGES then
        trigger.action.outText(tostring(msg), time or CFG.MESSAGE_TIME or 6)
    end
end

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

local function buildWriteDirPath(relativePath)
    if not relativePath or relativePath == "" then
        return nil
    end

    if relativePath:match("^%a:[\\/]") or relativePath:sub(1, 1) == "/" then
        return relativePath
    end

    return lfs.writedir() .. relativePath
end

local function getJsonPath()
    return buildWriteDirPath(CFG.jsonRelativePath or "Config\\HorizontDev\\PersistentNotes.json")
end

local function ensureDirectoryForFile(path)
    if not path or path == "" then
        return false
    end

    local dir = path:match("^(.*)[\\/][^\\/]*$")
    if not dir or dir == "" then
        return false
    end

    local separator = "\\"
    if dir:find("/") then
        separator = "/"
    end

    local current = ""
    local rest = dir

    if dir:match("^%a:[\\/]") then
        current = dir:sub(1, 3)
        rest = dir:sub(4)
    elseif dir:sub(1, 1) == "/" then
        current = "/"
        rest = dir:sub(2)
    end

    for part in string.gmatch(rest, "[^\\/]+") do
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
-- PARSEO DE MARCAS
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

----------------------------------------------------------------
-- AUTOR DE LA MARCA
----------------------------------------------------------------
local function coalitionToText(coa)
    coa = tonumber(coa)

    if coalition and coalition.side then
        if coa == coalition.side.RED then
            return "RED"
        elseif coa == coalition.side.BLUE then
            return "BLUE"
        elseif coa == coalition.side.NEUTRAL then
            return "NEUTRAL"
        end
    end

    if coa == 1 then
        return "RED"
    elseif coa == 2 then
        return "BLUE"
    elseif coa == 0 then
        return "NEUTRAL"
    end

    return "UNKNOWN"
end

local function safeObjCall(obj, fnName)
    if not obj or not obj[fnName] then
        return nil
    end

    local ok, result = pcall(function()
        return obj[fnName](obj)
    end)

    if ok then
        return result
    end

    return nil
end

local function safeGetGroupFromUnit(unit)
    if not unit or not unit.getGroup then
        return nil
    end

    local ok, group = pcall(function()
        return unit:getGroup()
    end)

    if ok then
        return group
    end

    return nil
end

local function findGroupById(groupId)
    groupId = tonumber(groupId)

    if not groupId then
        return nil
    end

    if not coalition or not coalition.getGroups then
        return nil
    end

    local sides = {}

    if coalition.side then
        sides[#sides + 1] = coalition.side.RED
        sides[#sides + 1] = coalition.side.BLUE
        sides[#sides + 1] = coalition.side.NEUTRAL
    else
        sides[#sides + 1] = 1
        sides[#sides + 1] = 2
        sides[#sides + 1] = 0
    end

    local categories = {}

    if Group and Group.Category then
        categories[#categories + 1] = Group.Category.AIRPLANE
        categories[#categories + 1] = Group.Category.HELICOPTER
        categories[#categories + 1] = Group.Category.GROUND
        categories[#categories + 1] = Group.Category.SHIP
    end

    for _, side in ipairs(sides) do
        for _, category in ipairs(categories) do
            if side ~= nil and category ~= nil then
                local okGroups, groups = pcall(function()
                    return coalition.getGroups(side, category)
                end)

                if okGroups and type(groups) == "table" then
                    for _, group in ipairs(groups) do
                        if group and group.getID then
                            local okId, id = pcall(function()
                                return group:getID()
                            end)

                            if okId and tonumber(id) == groupId then
                                return group
                            end
                        end
                    end
                end
            end
        end
    end

    return nil
end

local function getPlayerFromGroup(group)
    if not group then
        return nil, nil
    end

    local okUnits, units = pcall(function()
        return group:getUnits()
    end)

    if not okUnits or type(units) ~= "table" then
        return nil, nil
    end

    for _, unit in ipairs(units) do
        if unit and unit.isExist then
            local okExist, exists = pcall(function()
                return unit:isExist()
            end)

            if okExist and exists and unit.getPlayerName then
                local okPlayer, playerName = pcall(function()
                    return unit:getPlayerName()
                end)

                if okPlayer and playerName and playerName ~= "" then
                    return playerName, unit
                end
            end
        end
    end

    return nil, nil
end

local function getAuthor(event)
    local author = {
        playerName = "UNKNOWN",
        unitName = "UNKNOWN",
        groupName = "UNKNOWN",
        groupId = 0,
        coalition = -1,
        coalitionName = "UNKNOWN",
        source = "unknown",

        eventGroupId = 0,
        eventCoalition = -1,
        eventIdx = event and tonumber(event.idx) or 0
    }

    if not event then
        return author
    end

    local eventGroupId = tonumber(event.groupID or event.groupId) or 0
    local eventCoalition = tonumber(event.coalition) or -1

    author.eventGroupId = eventGroupId
    author.eventCoalition = eventCoalition

    if eventGroupId ~= 0 then
        author.groupId = eventGroupId
    end

    if eventCoalition ~= -1 then
        author.coalition = eventCoalition
        author.coalitionName = coalitionToText(eventCoalition)
    end

    ------------------------------------------------------------
    -- 1. Intentar con event.initiator
    ------------------------------------------------------------
    local initiator = event.initiator

    if initiator then
        local playerName = safeObjCall(initiator, "getPlayerName")
        local unitName = safeObjCall(initiator, "getName")
        local unitCoalition = safeObjCall(initiator, "getCoalition")

        if playerName and playerName ~= "" then
            author.playerName = tostring(playerName)
            author.source = "event.initiator"
        end

        if unitName and unitName ~= "" then
            author.unitName = tostring(unitName)
        end

        if unitCoalition ~= nil then
            author.coalition = tonumber(unitCoalition) or author.coalition
            author.coalitionName = coalitionToText(author.coalition)
        end

        local group = safeGetGroupFromUnit(initiator)
        if group then
            local groupName = safeObjCall(group, "getName")
            local groupId = safeObjCall(group, "getID")
            local groupCoalition = safeObjCall(group, "getCoalition")

            if groupName and groupName ~= "" then
                author.groupName = tostring(groupName)
            end

            if groupId ~= nil then
                author.groupId = tonumber(groupId) or author.groupId
            end

            if groupCoalition ~= nil then
                author.coalition = tonumber(groupCoalition) or author.coalition
                author.coalitionName = coalitionToText(author.coalition)
            end
        end

        if author.playerName ~= "UNKNOWN" then
            return author
        end
    end

    ------------------------------------------------------------
    -- 2. Fallback por groupID del evento
    ------------------------------------------------------------
    if author.groupId and tonumber(author.groupId) ~= 0 then
        local group = findGroupById(author.groupId)

        if group then
            local groupName = safeObjCall(group, "getName")
            local groupCoalition = safeObjCall(group, "getCoalition")

            if groupName and groupName ~= "" then
                author.groupName = tostring(groupName)
            end

            if groupCoalition ~= nil then
                author.coalition = tonumber(groupCoalition) or author.coalition
                author.coalitionName = coalitionToText(author.coalition)
            end

            local playerName, playerUnit = getPlayerFromGroup(group)

            if playerName and playerName ~= "" then
                author.playerName = tostring(playerName)
                author.source = "event.groupID"

                local unitName = safeObjCall(playerUnit, "getName")
                if unitName and unitName ~= "" then
                    author.unitName = tostring(unitName)
                end

                return author
            end

            author.source = "event.groupID_no_player"
            return author
        end
    end

    ------------------------------------------------------------
    -- 3. Solo coalicion o desconocido
    ------------------------------------------------------------
    if author.coalition ~= -1 then
        author.source = "event.coalition"
    else
        author.source = "unknown"
    end

    return author
end

----------------------------------------------------------------
-- JSON
----------------------------------------------------------------
local function buildDocument()
    return {
        control = {
            keyword = CFG.KEYWORD,
            restoreOnStart = CFG.RESTORE_ON_START == true,
            restoredMarkReadOnly = CFG.RESTORED_MARK_READ_ONLY == true
        },

        meta = {
            source = "HDEV_PersistentNotes",
            missionTime = timer.getTime(),
            absTime = timer.getAbsTime(),
            theatre = env.mission and env.mission.theatre or "UNKNOWN",
            jsonPath = getJsonPath()
        },

        nextNoteNumber = STATE.nextNoteNumber,
        nextMarkId = STATE.nextMarkId,

        notes = STATE.notes or {}
    }
end

local function saveJson(reason)
    local path = getJsonPath()

    if not path then
        warn("Ruta JSON invalida.")
        return false
    end

    local doc = buildDocument()
    local payload = encodeJsonValue(doc, 0)

    local ok = safeWriteFile(path, payload)

    if ok then
        STATE.lastPayload = payload
        env.info("[HDEV_NOTES] JSON guardado: " .. tostring(path) .. " | reason=" .. tostring(reason))
        return true
    end

    return false
end

local function rebuildMarkIndex()
    STATE.markToNoteId = {}

    for noteId, note in pairs(STATE.notes or {}) do
        if type(note) == "table" and note.markId then
            STATE.markToNoteId[tonumber(note.markId)] = noteId
        end
    end
end

local function loadJson()
    STATE.notes = {}
    STATE.markToNoteId = {}
    STATE.nextNoteNumber = 1
    STATE.nextMarkId = CFG.MARK_ID_START

    local path = getJsonPath()
    local txt = safeReadFile(path)

    if not txt then
        log("No existia JSON. Creando archivo nuevo en: " .. tostring(path))
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

    local maxNoteNumber = STATE.nextNoteNumber
    local maxMarkId = STATE.nextMarkId

    for noteId, note in pairs(STATE.notes or {}) do
        if type(note) == "table" then
            note.id = tostring(note.id or noteId)

            if type(note.author) ~= "table" then
                note.author = {
                    playerName = "UNKNOWN",
                    unitName = "UNKNOWN",
                    groupName = "UNKNOWN",
                    groupId = 0,
                    coalition = -1,
                    coalitionName = "UNKNOWN",
                    source = "loaded_without_author"
                }
            end

            if not note.restoreMarkId then
                note.restoreMarkId = tonumber(note.markId) or STATE.nextMarkId
            end

            local n = tonumber(tostring(note.id):match("NOTE_(%d+)"))
            if n and n >= maxNoteNumber then
                maxNoteNumber = n + 1
            end

            local m = tonumber(note.restoreMarkId or note.markId)
            if m and m >= maxMarkId then
                maxMarkId = m + 1
            end
        end
    end

    STATE.nextNoteNumber = maxNoteNumber
    STATE.nextMarkId = maxMarkId

    rebuildMarkIndex()

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
    local author = getAuthor(event)

    STATE.notes[noteId] = {
        id = noteId,

        markId = markId,
        originalMarkId = markId,
        restoreMarkId = newMarkId(),

        text = tostring(message or ""),
        rawText = tostring(event.text or ""),

        point = getPointFromEvent(event),

        author = author,
        lastEditor = author,

        createdAt = timer.getTime(),
        updatedAt = timer.getTime(),
        createdAtAbs = timer.getAbsTime(),
        updatedAtAbs = timer.getAbsTime()
    }

    STATE.markToNoteId[markId] = noteId

    saveJson("create_note")

    out(
        "Nota guardada:\n" ..
        tostring(message) .. "\n\n" ..
        "Autor: " .. tostring(author.playerName) .. "\n" ..
        "Unidad: " .. tostring(author.unitName),
        CFG.MESSAGE_TIME
    )
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

    local editor = getAuthor(event)

    local oldMarkId = tonumber(note.markId)
    if oldMarkId and oldMarkId ~= markId then
        STATE.markToNoteId[oldMarkId] = nil
    end

    note.markId = markId
    note.text = tostring(message or "")
    note.rawText = tostring(event.text or "")
    note.point = getPointFromEvent(event)

    if type(note.author) ~= "table" or not note.author.playerName then
        note.author = editor
    end

    note.lastEditor = editor

    note.updatedAt = timer.getTime()
    note.updatedAtAbs = timer.getAbsTime()

    STATE.markToNoteId[markId] = noteId

    saveJson("update_note")

    out(
        "Nota actualizada:\n" ..
        tostring(message) .. "\n\n" ..
        "Editor: " .. tostring(editor.playerName) .. "\n" ..
        "Unidad: " .. tostring(editor.unitName),
        CFG.MESSAGE_TIME
    )
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

    out("Nota eliminada del JSON.", CFG.MESSAGE_TIME)
end

----------------------------------------------------------------
-- RESTAURAR MARCAS
----------------------------------------------------------------
local function ignoreMark(markId)
    markId = tonumber(markId)

    if not markId then
        return
    end

    STATE.ignoreMarks[markId] = timer.getTime() + 5
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
        if type(note) == "table" and type(note.point) == "table" then
            local restoreId = tonumber(note.restoreMarkId) or newMarkId()
            note.restoreMarkId = restoreId

            local oldMarkId = tonumber(note.markId)
            if oldMarkId then
                STATE.markToNoteId[oldMarkId] = nil
            end

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
-- MENU OPCIONAL
----------------------------------------------------------------
local function countNotes()
    local n = 0

    for _, _ in pairs(STATE.notes or {}) do
        n = n + 1
    end

    return n
end

local function showNotesSummary()
    local lines = {
        "NOTAS PERSISTENTES",
        "Total: " .. tostring(countNotes()),
        "JSON: " .. tostring(getJsonPath()),
        ""
    }

    for _, noteId in ipairs(sortedKeys(STATE.notes)) do
        local note = STATE.notes[noteId]

        if note then
            local authorName = "UNKNOWN"

            if type(note.author) == "table" then
                authorName = tostring(note.author.playerName or "UNKNOWN")
            end

            lines[#lines + 1] =
                tostring(noteId) ..
                " | markId=" .. tostring(note.markId) ..
                " | autor=" .. authorName ..
                " | " .. tostring(note.text or "")
        end
    end

    trigger.action.outText(table.concat(lines, "\n"), 20)
end

local function buildMenu()
    if not CFG.MENU_ENABLED then
        return
    end

    if STATE.menuRoot then
        missionCommands.removeItem(STATE.menuRoot)
        STATE.menuRoot = nil
    end

    STATE.menuRoot = missionCommands.addSubMenu(CFG.MENU_NAME or "Notas persistentes")

    missionCommands.addCommand("Mostrar notas", STATE.menuRoot, function()
        showNotesSummary()
    end)

    missionCommands.addCommand("Guardar JSON ahora", STATE.menuRoot, function()
        saveJson("manual_save")
        trigger.action.outText("JSON de notas guardado.", 8)
    end)

    missionCommands.addCommand("Restaurar notas en mapa", STATE.menuRoot, function()
        restoreNotes()
    end)
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
        log("Sistema iniciado. JSON: " .. tostring(getJsonPath()))
    else
        warn("El sistema inicio, pero NO pudo crear el JSON.")
    end

    world.addEventHandler(handler)
    buildMenu()

    timer.scheduleFunction(function()
        restoreNotes()
        return nil
    end, nil, timer.getTime() + (CFG.RESTORE_DELAY or 3))
end

start()