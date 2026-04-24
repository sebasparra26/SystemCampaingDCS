if not mist or not mist.teleportToPoint then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

----------------------------------------------------------------
-- ActivateUnitsCampaing_SINAI.lua
--
-- BASE:
--   Version estable de activaciones por flag
--
-- MODULO 1:
--   Clonado por bandera con nombre runtime fijo
--
-- MODULO 2:
--   Activacion simple por flag usando trigger.action.activateGroup
--   SOLO estos grupos llevan persistencia JSON
--
-- PERSISTENCIA MODULO 2:
--   1 = habilitado para activarse
--   2 = muerto definitivamente, NO volver activar
--
-- REGLA DURA:
--   Si un grupo esta en 2, JAMAS vuelve a 1 por script.
--   Si aparece vivo por cualquier motivo, se destruye.
----------------------------------------------------------------

local debugActivo = false
local intervaloRevision = 1

local function getWriteDir()
    if lfs and lfs.writedir then
        return lfs.writedir()
    end
    return ""
end

----------------------------------------------------------------
-- MODULO 1
-- CLONADO POR BANDERA
--
-- 1 = ROJO
-- 2 = AZUL
----------------------------------------------------------------
local gruposPorBandera = {
    [100] = { 
        rojo = {"RU_100_Difarsuwar", "RU_SAM_100_Difarsuwar", "RU_AAA_100_Difarsuwar" }, 
        azul = {"US_100_Difarsuwar", "US_SAM_100_Difarsuwar", "US_AAA_100_Difarsuwar" }
    },
    [101] = { rojo = "RU_101_AbuS", azul = "US_101_AbuS" },
    [102] = { rojo = "RU_102_AsS", azul = "US_102_AsS" },
    [103] = { rojo = "RU_103_Ismailiyah", azul = "US_103_Ismailiyah" },

    [104] = { 
            rojo = {"RU_104_Melez"}, 
            azul = {"US_104_Melez", "US_TROOPS_RU_104_Melez"}, 
            },
    [105] = { rojo = "RU_105_Fayed", azul = "US_105_Fayed" },
    [106] = { rojo = "RU_106_Hatzerim", azul = "US_106_Hatzerim" },
    [107] = { rojo = "RU_107_Nevatim", azul = "US_107_Nevatim" },

    [108] = { 
            rojo = {"RU_108_Ramon"},
            azul = {"US_108_Ramon", "US_TROOPS_RU_108_Ramon"},
            },

    [109] = {
         rojo = {"RU_109_Ovda", "RU_SAM_109_Ovda", "RU_SHIELD_109_Ovda" }, 
         azul = {"US_109_Ovda", "US_SAM_109_Ovda", "US_SHIELD_109_Ovda"}
            },
    [110] = { rojo = "RU_110_Kibrit", azul = "US_110_Kibrit" },
    [111] = { rojo = "RU_111_Kedem", azul = "US_111_Kedem" },
    [112] = { rojo = "RU_112_WadiJ", azul = "US_112_WadiJ" },
    [113] = { rojo = "RU_113_AlM", azul = "US_113_AlM" },
    [114] = { rojo = "RU_114_AzZaqaziq", azul = "US_114_AzZaqaziq" },
    [115] = { rojo = "RU_115_Bilbeis", azul = "US_115_Bilbeis" },
    [116] = { rojo = "RU_116_Cairo", azul = "US_116_Cairo" },

    [117] = {
         rojo = {"RU_117_CairoW", "RU_SAM_117_CairoW", "RU_SHIELD_117_CairoW", "RU_SAM_2_117_CairoW"}, 
         azul = {"US_117_CairoW", "US_SAM_117_CairoW"}
    },
    [118] = { rojo = "RU_118_Inshas", azul = "US_118_Inshas" },
    [119] = { rojo = "RU_119_Hatzor", azul = "US_119_Hatzor" },

    [120] = {
         rojo = {"RU_120_Palmachim", "RU_SAM_120_Palmachim", "RU_TROOPS_120_Palmachim"}, 
         azul = {"US_120_Palmachim", "US_SAM_120_Palmachim"},
           },
    [121] = { rojo = "RU_121_SdeD", azul = "US_121_SdeD" },
    [122] = { rojo = "RU_122_TelN", azul = "US_122_TelN" },

    [123] = { 
        rojo = {"RU_123_BenG", "RU_SAM_123_BenG", "RU_EWR_123_BenG", "RU_TROOPS_123_BenG", "RU_TROOPS_2_123_BenG", "RU_TROOPS_3_123_BenG" }, 
        azul = {"US_123_BenG", "US_SAM_123_BenG",  "US_SAM_2_123_BenG", "US_CRAM_123_BenG"}
            },
    [124] = { rojo = "RU_124_StC", azul = "US_124_StC" },
    [125] = { rojo = "RU_125_AbuR", azul = "US_125_AbuR" },
    [126] = { rojo = "RU_126_Baluza", azul = "US_126_Baluza" },

    [127] = {
         rojo = {"RU_127_BirH", "RU_SAM_127_BirH"}, 
         azul = {"US_127_BirH", "US_SAM_127_BirH"}
    },
    [128] = { 
            rojo = {"RU_128_ElA"},
            azul = {"US_128_ElA", "US_TROOPS_RU_128_ElA", "US_TROOPS_2_RU_128_ElA"},
            },

    [129] = { rojo = "RU_129_ElG", azul = "US_129_ElG" },
    [130] = { rojo = "RU_130_AlK", azul = "US_130_AlK" },
    [131] = { rojo = "RU_131_AlR", azul = "US_131_AlR" },
    [132] = { rojo = "RU_132_Beni", azul = "US_132_Beni" },
    [133] = { rojo = "RU_133_Birma", azul = "US_133_Birma" },
    [134] = { rojo = "RU_134_Borg", azul = "US_134_Borg" },
    [135] = { rojo = "RU_135_ElM", azul = "US_135_ElM" },
    [136] = { rojo = "RU_136_Gebel", azul = "US_136_Gebel" },
    [137] = { rojo = "RU_137_Hurghada", azul = "US_137_Hurghada" },
    [138] = { rojo = "RU_138_Jiyanklis", azul = "US_138_Jiyanklis" },
    [139] = { rojo = "RU_139_Kom", azul = "US_139_Kom" },
    [140] = { rojo = "RU_140_RamonI", azul = "US_140_RamonI" },
    [141] = { rojo = "RU_141_Sharm", azul = "US_141_Sharm" },
    [142] = { rojo = "RU_142_WadiR", azul = "US_142_WadiR" },
    [143] = { rojo = "RU_143_AlB", azul = "US_143_AlB" },
    [144] = { rojo = "RU_144_Quwaysina", azul = "US_144_Quwaysina" },

    [145] = { 
            rojo = {"RU_145_Rafic"},
            azul = {"US_145_Rafic", "US_SAM_145_Rafic", "US_SHIELD_145_Rafic" },
            },

    [146] = { rojo = "RU_146_Tabuk", azul = "US_146_Tabuk" },
    [147] = { rojo = "RU_147_Damascus", azul = "US_147_Damascus" },
    [148] = {
        
        rojo = {"RU_148_Mezzeh"}, 
        azul = {"US_148_Mezzeh", "US_TROOPS_RU_148_Mezzeh" },
            },
    [149] = {
        rojo = {"RU_149_Ramat", "RU_SAM_149_Ramat", "RU_TROOPS_149_Ramat", "RU_TROOPS_2_149_Ramat" },
        azul = {"US_149_Ramat", "US_SAM_149_Ramat" },
            },

    [150] = { rojo = "RU_150_Megiddo", azul = "US_150_Megiddo" },

    [151] = {
            rojo = {"RU_151_Ein"}, 
            azul = {"US_151_Ein", "US_TROOPS_RU_151_Ein" }, 
            },
    [152] = { rojo = "RU_152_Taba", azul = "US_152_Taba" },

    [153] = {
            rojo = {"RU_153_KingF"},
            azul = {"US_153_KingF", "US_TROOPS_RU_153_KingF"},
            },
    [154] = {
        rojo = { "RU_154_Khalkhalah", "RU_154_Khalkhalah_2" },
        azul = { "US_154_Khalkhalah", "US_SAM_154_Khalkhalah" }
    },
}

----------------------------------------------------------------
-- MODULO 2
-- ACTIVACION SIMPLE POR FLAG
-- ESTOS GRUPOS NO SE CLONAN
----------------------------------------------------------------
local activacionesPorFlag = {
    [2100] = {
        valor = 1,
        grupos = {
            "RU_SAM_154_Khalkhalah",
            "RU_HELI_154_Khalkhalah",
            "RU_EWR_154_Khalkhalah",
            "RU_SHIELD_154_Khalkhalah"
           --"US_TROOP"

        }
    },

    [2200] = {
        valor = 1,
        grupos = {
            "RU_Tanque"
        }
    },
}

----------------------------------------------------------------
-- SYNC JSON MODULO 2
----------------------------------------------------------------
local ACTSYNC = {
    DEBUG = false,

    FILE_PATH = getWriteDir() .. "Config\\HorizontDev\\ActivateUnitsFlagPersistence.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 350,
}

local ACTSTATE = {
    started = false,
    injecting = false,
    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,

    trackedGroups = {},
    runtime = {},
    doc = nil,
    eventHandlerRegistered = false,
    lastSavedPayload = "",
    dirty = false,
    persistenceAvailable = false
}

local estadoPrevioBanderas = {}
local estadoPrevioActivaciones = {}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function debug(msg, tiempo)
    if debugActivo then
        trigger.action.outText("[ActivateUnits] " .. tostring(msg), tiempo or 10)
    end
end

local function log(msg)
    env.info("[ActivateUnitsCampaing_SINAI] " .. tostring(msg))
    if debugActivo then
        trigger.action.outText("[ActivateUnits] " .. tostring(msg), 8)
    end
end

local function syncLog(msg)
    env.info("[ACTSYNC] " .. tostring(msg))
    if ACTSYNC.DEBUG or debugActivo then
        trigger.action.outText("[ACTSYNC] " .. tostring(msg), 8)
    end
end

----------------------------------------------------------------
-- UTILS GENERALES
----------------------------------------------------------------
local function round(n, d)
    n = tonumber(n) or 0
    local m = 10 ^ (d or 0)
    return math.floor((n * m) + 0.5) / m
end

local function ensureNumber(v)
    return tonumber(v) or 0
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

local function convertirALista(valor)
    if not valor then
        return {}
    end

    if type(valor) == "string" then
        return { valor }
    end

    if type(valor) == "table" then
        local lista = {}
        for i = 1, #valor do
            if type(valor[i]) == "string" and valor[i] ~= "" then
                lista[#lista + 1] = valor[i]
            end
        end
        return lista
    end

    return {}
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

local function sortedNumericListFromMap(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if v then
            out[#out + 1] = tonumber(k) or k
        end
    end

    table.sort(out, function(a, b)
        return tonumber(a) < tonumber(b)
    end)
    return out
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

local function destroyGroupIfExists(groupName)
    local grp = groupExistsByName(groupName)
    if grp then
        pcall(function()
            grp:destroy()
        end)
        return true
    end
    return false
end

local function countAliveUnitsInGroup(groupName)
    local grp = groupExistsByName(groupName)
    if not grp then
        return 0
    end

    local units = grp:getUnits() or {}
    local alive = 0

    for i = 1, #units do
        local u = units[i]
        if u and u:isExist() then
            local life = ensureNumber(u:getLife())
            if life > 0 then
                alive = alive + 1
            end
        end
    end

    return alive
end

----------------------------------------------------------------
-- JSON HELPERS
----------------------------------------------------------------
local function validatePersistenceEnvironment()
    if not io or not lfs then
        syncLog("io/lfs no disponibles. Persistencia deshabilitada.")
        return false
    end

    if not net or not net.json2lua then
        syncLog("net.json2lua no disponible. Persistencia deshabilitada.")
        return false
    end

    return true
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

local function safeReadFile(path)
    if not io then
        return nil
    end

    local f = io.open(path, "r")
    if not f then
        return nil
    end

    local txt = f:read("*a")
    f:close()
    return txt
end

local function safeWriteFile(path, txt)
    if not io then
        return false
    end

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
    local txt = safeReadFile(ACTSYNC.FILE_PATH)
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
    if not ACTSTATE.persistenceAvailable then
        return false
    end

    local payload = encodeJsonValue(tbl, 0)

    if payload == ACTSTATE.lastSavedPayload and not ACTSTATE.dirty then
        return true
    end

    local ok = safeWriteFile(ACTSYNC.FILE_PATH, payload)
    if ok then
        ACTSTATE.lastSavedPayload = payload
        ACTSTATE.dirty = false
    end
    return ok
end

----------------------------------------------------------------
-- MODULO 1
-- CLONADO POR BANDERA CON NOMBRE RUNTIME FIJO
----------------------------------------------------------------
local function getRuntimeName(templateName)
    return templateName .. "_RUNTIME"
end

local function clonarConNombreFijo(templateName, bandera, lado)
    if not templateName or templateName == "" then
        return false
    end

    local runtimeName = getRuntimeName(templateName)

    destroyGroupIfExists(runtimeName)

    local vars = {
        gpName = templateName,
        action = "clone",
        newGroupName = runtimeName,
        route = mist.getGroupRoute(templateName, "task")
    }

    local ok, result = pcall(function()
        return mist.teleportToPoint(vars)
    end)

    if ok and result then
        debug("Grupo " .. string.upper(lado) .. " '" .. runtimeName .. "' clonado por bandera " .. bandera, 10)
        env.info("[ActivateUnitsCampaing_SINAI] Grupo " .. string.upper(lado) .. " '" .. runtimeName .. "' clonado por bandera " .. bandera)
        return true
    end

    debug("ERROR clonando '" .. tostring(templateName) .. "' como '" .. tostring(runtimeName) .. "'", 10)
    env.info("[ActivateUnitsCampaing_SINAI] ERROR clonando '" .. tostring(templateName) .. "' como '" .. tostring(runtimeName) .. "'")
    return false
end

local function activarLadoClonado(bandera, lado, definicionLado)
    local listaGrupos = convertirALista(definicionLado)

    for i = 1, #listaGrupos do
        clonarConNombreFijo(listaGrupos[i], bandera, lado)
    end
end

local function revisarModuloClonado()
    for bandera, data in pairs(gruposPorBandera) do
        local valor = tonumber(trigger.misc.getUserFlag(bandera)) or 0
        local valorPrevio = estadoPrevioBanderas[bandera]

        if valor ~= valorPrevio then
            estadoPrevioBanderas[bandera] = valor

            if valor == 1 then
                activarLadoClonado(bandera, "rojo", data.rojo)
            elseif valor == 2 then
                activarLadoClonado(bandera, "azul", data.azul)
            end
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- CATALOGO DE GRUPOS PERSISTENTES
----------------------------------------------------------------
local function ensureTrackedGroup(groupName, sourceFlag)
    if not ACTSTATE.trackedGroups[groupName] then
        ACTSTATE.trackedGroups[groupName] = {
            status = 1,
            sourceFlags = {},
            lastChangeTime = 0,
            lastActivatedAt = nil,
            lastSeenAliveAt = nil
        }
    end

    if sourceFlag ~= nil then
        ACTSTATE.trackedGroups[groupName].sourceFlags[sourceFlag] = true
    end

    if not ACTSTATE.runtime[groupName] then
        ACTSTATE.runtime[groupName] = {
            seenAliveOnce = false,
            activationRequested = false,
            activatedThisRun = false
        }
    end
end

local function buildTrackedCatalog()
    for flag, def in pairs(activacionesPorFlag or {}) do
        local lista = convertirALista(def.grupos)
        for i = 1, #lista do
            ensureTrackedGroup(lista[i], flag)
        end
    end
end

local function setTrackedStatus(groupName, newStatus)
    local rec = ACTSTATE.trackedGroups[groupName]
    if not rec then
        return
    end

    local current = tonumber(rec.status) or 1
    newStatus = tonumber(newStatus) or 1

    if current == 2 then
        return
    end

    if newStatus ~= 1 and newStatus ~= 2 then
        newStatus = 1
    end

    if rec.status ~= newStatus then
        rec.status = newStatus
        rec.lastChangeTime = round(timer.getTime(), 3)
        ACTSTATE.dirty = true
        syncLog("Estado actualizado | " .. tostring(groupName) .. " => " .. tostring(newStatus))
    end
end

local function buildDocFromState()
    local groups = {}

    for groupName, rec in pairs(ACTSTATE.trackedGroups or {}) do
        groups[groupName] = {
            status = tonumber(rec.status) or 1,
            sourceFlags = sortedNumericListFromMap(rec.sourceFlags or {}),
            lastChangeTime = rec.lastChangeTime,
            lastActivatedAt = rec.lastActivatedAt,
            lastSeenAliveAt = rec.lastSeenAliveAt
        }
    end

    return {
        control = {
            injectDuration = ACTSYNC.INJECT_DURATION,
            injectInterval = ACTSYNC.INJECT_INTERVAL,
            exportInterval = ACTSYNC.EXPORT_INTERVAL
        },
        meta = {
            mode = ACTSTATE.injecting and "inject" or "live",
            missionTime = round(timer.getTime(), 3),
            source = "ActivateUnitsCampaing_SINAI"
        },
        groups = groups
    }
end

local function applyDocToState(doc)
    if type(doc) ~= "table" then
        return
    end

    local savedGroups = doc.groups or {}
    for groupName, saved in pairs(savedGroups) do
        if ACTSTATE.trackedGroups[groupName] then
            local rec = ACTSTATE.trackedGroups[groupName]
            local savedStatus = tonumber(saved.status) or 1

            if savedStatus ~= 2 then
                savedStatus = 1
            end

            rec.status = savedStatus
            rec.lastChangeTime = saved.lastChangeTime or rec.lastChangeTime
            rec.lastActivatedAt = saved.lastActivatedAt or rec.lastActivatedAt
            rec.lastSeenAliveAt = saved.lastSeenAliveAt or rec.lastSeenAliveAt

            if savedStatus == 2 and ACTSTATE.runtime[groupName] then
                ACTSTATE.runtime[groupName].seenAliveOnce = true
            end
        end
    end
end

local function isLockedDead(groupName)
    local rec = ACTSTATE.trackedGroups[groupName]
    return rec and tonumber(rec.status) == 2
end

local function enforceDeadLock(groupName, reason)
    if isLockedDead(groupName) then
        local destroyed = destroyGroupIfExists(groupName)
        if destroyed then
            syncLog("Grupo bloqueado en 2 destruido por seguridad: " .. tostring(groupName) .. " | motivo=" .. tostring(reason or "N/A"))
        end
        return true
    end
    return false
end

----------------------------------------------------------------
-- MODULO 2
-- ACTIVACION SIMPLE PERSISTENTE
-- MISMA BASE ESTABLE + FILTRO status==2
----------------------------------------------------------------
local function activarGrupoOriginalPersistente(nombreGrupo, bandera)
    if not nombreGrupo or nombreGrupo == "" then
        return false
    end

    if isLockedDead(nombreGrupo) then
        syncLog("Saltado por persistencia, ya murio: " .. tostring(nombreGrupo))
        enforceDeadLock(nombreGrupo, "activarGrupoOriginalPersistente")
        return false
    end

    local grp = Group.getByName(nombreGrupo)
    if not grp then
        debug("No existe grupo en ME: " .. tostring(nombreGrupo), 10)
        env.info("[ActivateUnitsCampaing_SINAI] No existe grupo en ME: " .. tostring(nombreGrupo))
        return false
    end

    local ok, err = pcall(function()
        trigger.action.activateGroup(grp)
    end)

    if ok then
        local rt = ACTSTATE.runtime[nombreGrupo]
        local rec = ACTSTATE.trackedGroups[nombreGrupo]

        if rt then
            rt.activationRequested = true
            rt.activatedThisRun = true
        end

        if rec then
            rec.lastActivatedAt = round(timer.getTime(), 3)
            if tonumber(rec.status) ~= 2 then
                setTrackedStatus(nombreGrupo, 1)
            end
        end

        debug("Grupo activado por flag " .. tostring(bandera) .. ": " .. tostring(nombreGrupo), 10)
        env.info("[ActivateUnitsCampaing_SINAI] Grupo activado por flag " .. tostring(bandera) .. ": " .. tostring(nombreGrupo))
        return true
    end

    debug("ERROR activando grupo '" .. tostring(nombreGrupo) .. "' por flag " .. tostring(bandera), 10)
    env.info("[ActivateUnitsCampaing_SINAI] ERROR activando grupo '" .. tostring(nombreGrupo) .. "' por flag " .. tostring(bandera) .. ": " .. tostring(err))
    return false
end

local function activarModuloSimple(flag, definicion)
    local listaGrupos = convertirALista(definicion.grupos)

    for i = 1, #listaGrupos do
        activarGrupoOriginalPersistente(listaGrupos[i], flag)
    end
end

----------------------------------------------------------------
-- MODULO 2
-- ESTO QUEDA IGUAL A LA VERSION ESTABLE
----------------------------------------------------------------
local function revisarModuloActivaciones()
    for flag, definicion in pairs(activacionesPorFlag) do
        local valorActual = tonumber(trigger.misc.getUserFlag(flag)) or 0
        local valorPrevio = estadoPrevioActivaciones[flag]
        local valorObjetivo = tonumber(definicion.valor) or 1

        if valorActual ~= valorPrevio then
            estadoPrevioActivaciones[flag] = valorActual

            if valorActual == valorObjetivo then
                activarModuloSimple(flag, definicion)
            end
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- MONITOREO DE VIDA / BLOQUEO DURO DE 2
----------------------------------------------------------------
local function monitorTrackedGroups()
    for groupName, rec in pairs(ACTSTATE.trackedGroups or {}) do
        local rt = ACTSTATE.runtime[groupName]
        local alive = countAliveUnitsInGroup(groupName)

        if tonumber(rec.status) == 2 then
            if alive > 0 then
                enforceDeadLock(groupName, "monitorTrackedGroups")
            end
        else
            if alive > 0 then
                if rt then
                    rt.seenAliveOnce = true
                    rt.activatedThisRun = true
                    rt.activationRequested = true
                end

                rec.lastSeenAliveAt = round(timer.getTime(), 3)
            else
                if rt and rt.seenAliveOnce then
                    setTrackedStatus(groupName, 2)
                end
            end
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- EVENT HANDLER
-- SI EL GRUPO ESTA EN 2, SE DESTRUYE Y NO SE REHABILITA
----------------------------------------------------------------
local function registerSyncEventHandler()
    if ACTSTATE.eventHandlerRegistered then
        return
    end

    world.addEventHandler({
        onEvent = function(_, event)
            if not event or event.id ~= world.event.S_EVENT_BIRTH then
                return
            end

            local initiator = event.initiator
            if not initiator or not initiator.getGroup then
                return
            end

            local grp = initiator:getGroup()
            if not grp then
                return
            end

            local groupName = grp:getName()
            if not ACTSTATE.trackedGroups[groupName] then
                return
            end

            if isLockedDead(groupName) then
                syncLog("BIRTH bloqueado por status 2: " .. tostring(groupName))
                pcall(function()
                    grp:destroy()
                end)
                return
            end

            local rec = ACTSTATE.trackedGroups[groupName]
            local rt = ACTSTATE.runtime[groupName]

            if rt then
                rt.seenAliveOnce = true
                rt.activatedThisRun = true
                rt.activationRequested = true
            end

            rec.lastSeenAliveAt = round(timer.getTime(), 3)

            syncLog("BIRTH detectado en grupo persistente: " .. tostring(groupName))
        end
    })

    ACTSTATE.eventHandlerRegistered = true
end

----------------------------------------------------------------
-- MODULO 2
-- INYECCION JSON -> ESTADO
----------------------------------------------------------------
local function injectFromJson()
    if not ACTSTATE.persistenceAvailable then
        return
    end

    local doc, err = loadSyncFile()

    if doc then
        ACTSTATE.doc = deepCopy(doc)
        applyDocToState(doc)
    else
        if not ACTSTATE.doc then
            ACTSTATE.doc = buildDocFromState()
        end
        syncLog("JSON no encontrado durante inyeccion. " .. tostring(err or ""))
    end

    for groupName, rec in pairs(ACTSTATE.trackedGroups or {}) do
        if tonumber(rec.status) == 2 then
            enforceDeadLock(groupName, "injectFromJson")
        end
    end
end

----------------------------------------------------------------
-- MODULO 2
-- EXPORTACION DCS -> JSON
----------------------------------------------------------------
local function exportLiveToJson()
    if not ACTSTATE.persistenceAvailable then
        return
    end

    monitorTrackedGroups()
    ACTSTATE.doc = buildDocFromState()
    saveSyncFile(ACTSTATE.doc)
end

----------------------------------------------------------------
-- START SYNC
----------------------------------------------------------------
local function startActivateSync()
    buildTrackedCatalog()
    registerSyncEventHandler()

    ACTSTATE.persistenceAvailable = validatePersistenceEnvironment()

    if ACTSTATE.persistenceAvailable then
        local initialDoc = nil
        local okDoc, _ = loadSyncFile()

        if type(okDoc) == "table" then
            initialDoc = okDoc
            ACTSTATE.doc = deepCopy(initialDoc)
            applyDocToState(initialDoc)
        else
            ACTSTATE.doc = buildDocFromState()
        end

        ACTSTATE.started = true
        ACTSTATE.injecting = (initialDoc ~= nil)
        ACTSTATE.injectEndsAt = timer.getTime() + ACTSYNC.INJECT_DURATION
        ACTSTATE.lastInject = -9999
        ACTSTATE.lastExport = -9999
        ACTSTATE.dirty = true

        if initialDoc then
            syncLog("JSON encontrado. Inyeccion activa por " .. tostring(ACTSYNC.INJECT_DURATION) .. " segundos.")
        else
            syncLog("No habia JSON previo. Se crea snapshot inicial y DCS queda como fuente desde el inicio.")
            exportLiveToJson()
            ACTSTATE.injecting = false
        end
    else
        ACTSTATE.started = true
        ACTSTATE.injecting = false
        ACTSTATE.injectEndsAt = 0
        ACTSTATE.lastInject = -9999
        ACTSTATE.lastExport = -9999
        ACTSTATE.doc = buildDocFromState()
    end
end

----------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------
local function verificarSistema(_, now)
    now = now or timer.getTime()

    revisarModuloClonado()
    revisarModuloActivaciones()

    if ACTSTATE.started then
        if ACTSTATE.persistenceAvailable then
            if ACTSTATE.injecting then
                if now <= ACTSTATE.injectEndsAt then
                    if (now - ACTSTATE.lastInject) >= ACTSYNC.INJECT_INTERVAL then
                        ACTSTATE.lastInject = now
                        injectFromJson()
                        monitorTrackedGroups()
                    end
                else
                    ACTSTATE.injecting = false
                    syncLog("Fin de ventana de inyeccion. DCS toma el control y JSON pasa a espejo vivo.")
                    monitorTrackedGroups()
                    exportLiveToJson()
                    ACTSTATE.lastExport = now
                end
            else
                monitorTrackedGroups()

                if (now - ACTSTATE.lastExport) >= ACTSYNC.EXPORT_INTERVAL then
                    ACTSTATE.lastExport = now
                    exportLiveToJson()
                end
            end
        else
            monitorTrackedGroups()
        end
    end

    return now + intervaloRevision
end

----------------------------------------------------------------
-- ARRANQUE
----------------------------------------------------------------
startActivateSync()
timer.scheduleFunction(verificarSistema, nil, timer.getTime() + intervaloRevision)