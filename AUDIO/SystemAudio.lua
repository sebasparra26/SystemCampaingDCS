----------------------------------------------------------------
-- HDEV_SoundFlags.lua
-- Sistema de sonidos por banderas para DCS
--
-- COMPORTAMIENTO:
-- - mode = "any"
--   Cada bandera se evalua de forma independiente.
--   Si una bandera entra al valor objetivo, dispara una vez.
--   No vuelve a disparar hasta que esa misma bandera salga
--   del valor objetivo y vuelva a entrar.
--
-- - mode = "all"
--   La regla completa dispara una vez cuando TODAS las banderas
--   cumplen a la vez. No vuelve a disparar hasta que el conjunto
--   deje de cumplir y luego vuelva a cumplir.
--
-- SOPORTA:
-- - flag = 112
-- - flag = {112, 113}
-- - mode = "any" | "all"
-- - target = "all" | "coalition" | "group" | "unit"
-- - delay opcional
-- - text opcional
--
-- RUTAS DE SONIDO:
-- - "Audio/Beep.ogg"
-- - "l10n/DEFAULT/Audio/Beep.ogg"
----------------------------------------------------------------

HDEV_SoundFlags = HDEV_SoundFlags or {}
local SF = HDEV_SoundFlags

SF.CONFIG = {
    DEBUG = false,
    CHECK_INTERVAL = 1
}

SF.RULES = {
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
------------------------------INI AUDIO CAS----------------------------------------------------------
-----------------------------------------------------------------------------------------------------
    {
        key = "Kill 01",
        flag = 900,
        value = 1,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill1.ogg",
        text = "kill 01",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },
     {
        key = "Kill 03",
        flag = 900,
        value = 2,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill3.ogg",
        text = "kill 02",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

      {
        key = "Kill 04",
        flag = 900,
        value = 3,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill4.ogg",
        text = "kill 04",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

    {
        key = "Kill 05",
        flag = 900,
        value = 4,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill5.ogg",
        text = "kill 05",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

    {
        key = "Kill 06",
        flag = 900,
        value = 5,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill6.ogg",
        text = "kill 06",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

    {
        key = "Kill 07",
        flag = 900,
        value = 6,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill7.ogg",
        text = "kill 07",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

    {
        key = "Kill 08",
        flag = 900,
        value = 7,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill8.ogg",
        text = "kill 08",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

    {
        key = "Kill 09",
        flag = 900,
        value = 8,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill9.ogg",
        text = "kill 09",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

     {
        key = "Kill 10",
        flag = 900,
        value = 9,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill10.ogg",
        text = "kill 10",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

     {
        key = "Kill 11",
        flag = 900,
        value = 10,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill11.ogg",
        text = "kill 11",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },

    {
        key = "Kill 12",
        flag = 900,
        value = 11,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill12.ogg",
        text = "kill 12",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
    },
    {
        key = "Kill 14",
        flag = 900,
        value = 12,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill14.ogg",
        text = "kill 14",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
        
    },

     {
        key = "Kill 15",
        flag = 900,
        value = 13,
        target = "all",
        coalition = 2,                   -- 1 rojo, 2 azul
        sound = "Audio/Kill15.ogg",
        text = "kill 15",
        textTime = 2,
        delay = 0,
        fireAtStart = false,
        rearmWhenLeavesValue = true
        
    },
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
------------------------------FIN AUDIO CAS----------------------------------------------------------
-----------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------
    -- EJEMPLO:
    -- 112 -> 2 suena
    -- 113 -> 2 suena tambien, aunque 112 siga en 2
    -- cada una se rearma sola cuando baja del valor objetivo
    ----------------------------------------------------------------
    {
        key = "MultiFlagSoundBLUE",
        flag = {100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136},
        value = 2,
        mode = "any",
        target = "all",
        sound = "Audio/Uibeep.ogg",
        text = "Base Capturada por Equipo AZUL",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },
     {
        key = "MultiFlagSoundRED",
        flag = {100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136},
        value = 1,
        mode = "any",
        target = "all",
        sound = "Audio/intel.ogg",
        text = "Base Capturada por Equipo RED",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },

    {
        key = "InitMission",
        flag = {2100, 2200, 2300, 2400},
        value = 1,
        mode = "any",
        target = "all",
        sound = "Audio/CommencingAttack.ogg",
        text = "Inicio de Misión - Consulta detalles en Mapa (F10), Menu de Radio F10 - Misiones",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },

    {
        key = "FailMission",
        flag = {2102, 2202, 2302, 2402},
        value = 1,
        mode = "any",
        target = "all",
        sound = "Audio/fail.ogg",
        text = "La misión a Fallado",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },

    {
        key = "SecundaryMission",
        flag = {2000, 2004, 2001, 2006, 2008, 2010, 2012, 2014, 2015, 2017, 2019, 2021},
        value = 1,
        mode = "any",
        target = "all",
        sound = "Audio/Hi-Tech.ogg",
        text = "Objetivo Secuendaria Completado",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },

     {
        key = "DetectMissile",
        flag = {9001},
        value = 1,
        mode = "any",
        target = "all",
        sound = "Audio/air-raid-siren-UI.ogg",
        text = "El sistema de defensa ha detectado un ataque inminente",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },

    ----------------------------------------------------------------
    -- EJEMPLO ALL:
    -- solo suena cuando TODAS las flags valen 1
    ----------------------------------------------------------------
    {
        key = "SONIDO_ALL_AZUL",
        flag = {120, 121},
        value = 1,
        mode = "all",
        target = "coalition",
        coalition = 2,
        sound = "Audio/Beep.ogg",
        text = "Condicion ALL cumplida",
        textTime = 5,
        delay = 0,
        fireAtStart = false
    },
}

SF.STATE = SF.STATE or {
    started = false,
    lastRuleMatched = {},
    lastFlagMatchedByRule = {}
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg, tiempo)
    env.info("[HDEV_SOUND_FLAGS] " .. tostring(msg))
    if SF.CONFIG.DEBUG then
        trigger.action.outText("[HDEV_SOUND_FLAGS] " .. tostring(msg), tiempo or 5)
    end
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function getFlagValue(flagNameOrNumber)
    return tonumber(trigger.misc.getUserFlag(tostring(flagNameOrNumber))) or 0
end

local function toList(v)
    if v == nil then
        return {}
    end

    if type(v) == "table" then
        return v
    end

    return { v }
end

local function normalizeCoalition(v)
    if type(v) == "string" then
        local s = string.lower(tostring(v))
        if s == "red" or s == "rojo" then
            return 1
        elseif s == "blue" or s == "azul" then
            return 2
        end
    end

    local n = tonumber(v)
    if n == 1 or n == 2 then
        return n
    end

    return 2
end

local function buildFlagsKey(flagField)
    local flags = toList(flagField)
    if #flags == 0 then
        return "NOFLAG"
    end

    local parts = {}
    for _, f in ipairs(flags) do
        parts[#parts + 1] = tostring(f)
    end

    return table.concat(parts, "_")
end

local function getRuleKey(rule)
    if rule.key and tostring(rule.key) ~= "" then
        return tostring(rule.key)
    end

    return "RULE_" ..
        buildFlagsKey(rule.flag) .. "_" ..
        tostring(rule.value or 1) .. "_" ..
        tostring(rule.mode or "any")
end

local function flagMatchesValue(flag, wantedValue)
    return getFlagValue(flag) == wantedValue
end

local function ruleMatches(rule)
    local flags = toList(rule.flag)
    local wanted = tonumber(rule.value) or 1
    local mode = string.lower(tostring(rule.mode or "any"))

    if #flags == 0 then
        return false
    end

    if mode == "all" then
        for _, flag in ipairs(flags) do
            if not flagMatchesValue(flag, wanted) then
                return false
            end
        end
        return true
    end

    for _, flag in ipairs(flags) do
        if flagMatchesValue(flag, wanted) then
            return true
        end
    end

    return false
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

local function unitExistsByName(unitName)
    if not unitName or unitName == "" then
        return nil
    end

    local unit = Unit.getByName(unitName)
    if not unit then
        return nil
    end

    local ok, exists = pcall(function()
        return unit:isExist()
    end)

    if ok and exists then
        return unit
    end

    return nil
end

----------------------------------------------------------------
-- TEXTO
----------------------------------------------------------------
local function playText(rule, groupId, unitId)
    if not rule.text or rule.text == "" then
        return
    end

    local t = tonumber(rule.textTime) or 8
    local target = string.lower(tostring(rule.target or "all"))

    if target == "all" then
        trigger.action.outText(rule.text, t)
        return
    end

    if target == "coalition" then
        local coa = normalizeCoalition(rule.coalition)
        trigger.action.outTextForCoalition(coa, rule.text, t)
        return
    end

    if target == "group" then
        if groupId then
            trigger.action.outTextForGroup(groupId, rule.text, t, false)
        end
        return
    end

    if target == "unit" then
        if unitId and trigger.action.outTextForUnit then
            local ok = pcall(function()
                trigger.action.outTextForUnit(unitId, rule.text, t, false)
            end)

            if ok then
                return
            end
        end

        if groupId then
            trigger.action.outTextForGroup(groupId, rule.text, t, false)
        end
        return
    end

    trigger.action.outText(rule.text, t)
end

----------------------------------------------------------------
-- SONIDO
----------------------------------------------------------------
local function playSound(rule)
    local target = string.lower(tostring(rule.target or "all"))
    local sound = tostring(rule.sound or "")

    if sound == "" then
        log("Regla sin sound: " .. getRuleKey(rule), 6)
        return
    end

    if target == "all" then
        trigger.action.outSound(sound)
        playText(rule)
        log("Sonido disparado | key=" .. getRuleKey(rule) .. " | sound=" .. sound, 5)
        return
    end

    if target == "coalition" then
        local coa = normalizeCoalition(rule.coalition)
        trigger.action.outSoundForCoalition(coa, sound)
        playText(rule)
        log("Sonido disparado | key=" .. getRuleKey(rule) .. " | sound=" .. sound, 5)
        return
    end

    if target == "group" then
        local grp = groupExistsByName(rule.groupName)
        if not grp then
            log("No existe el grupo para sonido: " .. tostring(rule.groupName), 6)
            return
        end

        local gid = grp:getID()
        trigger.action.outSoundForGroup(gid, sound)
        playText(rule, gid, nil)
        log("Sonido disparado | key=" .. getRuleKey(rule) .. " | sound=" .. sound, 5)
        return
    end

    if target == "unit" then
        local unit = unitExistsByName(rule.unitName)
        if not unit then
            log("No existe la unidad para sonido: " .. tostring(rule.unitName), 6)
            return
        end

        local uid = unit:getID()
        local grp = unit:getGroup()
        local gid = grp and grp:getID() or nil

        if trigger.action.outSoundForUnit then
            local ok = pcall(function()
                trigger.action.outSoundForUnit(uid, sound)
            end)

            if not ok then
                if gid then
                    trigger.action.outSoundForGroup(gid, sound)
                else
                    trigger.action.outSound(sound)
                end
            end
        else
            if gid then
                trigger.action.outSoundForGroup(gid, sound)
            else
                trigger.action.outSound(sound)
            end
        end

        playText(rule, gid, uid)
        log("Sonido disparado | key=" .. getRuleKey(rule) .. " | sound=" .. sound, 5)
        return
    end

    log("target no valido en regla: " .. getRuleKey(rule), 6)
end

local function delayedPlay(rule, time)
    playSound(rule)
    return nil
end

local function triggerRule(rule, sourceFlag)
    local delay = tonumber(rule.delay) or 0
    local key = getRuleKey(rule)

    if delay > 0 then
        timer.scheduleFunction(delayedPlay, rule, timer.getTime() + delay)
        log(
            "Regla programada con delay | key=" .. key ..
            " | flag=" .. tostring(sourceFlag or "N/A") ..
            " | delay=" .. tostring(delay),
            5
        )
    else
        playSound(rule)
    end
end

----------------------------------------------------------------
-- ESTADO INICIAL
----------------------------------------------------------------
local function initRuleState(rule)
    local key = getRuleKey(rule)
    local flags = toList(rule.flag)
    local wanted = tonumber(rule.value) or 1
    local mode = string.lower(tostring(rule.mode or "any"))
    local fireAtStart = rule.fireAtStart == true

    SF.STATE.lastFlagMatchedByRule[key] = {}

    if mode == "any" then
        for _, flag in ipairs(flags) do
            local currentMatched = flagMatchesValue(flag, wanted)

            if fireAtStart then
                SF.STATE.lastFlagMatchedByRule[key][tostring(flag)] = false
            else
                SF.STATE.lastFlagMatchedByRule[key][tostring(flag)] = currentMatched
            end
        end

        SF.STATE.lastRuleMatched[key] = ruleMatches(rule)
        return
    end

    local currentRuleMatched = ruleMatches(rule)

    if fireAtStart then
        SF.STATE.lastRuleMatched[key] = false
    else
        SF.STATE.lastRuleMatched[key] = currentRuleMatched
    end

    for _, flag in ipairs(flags) do
        SF.STATE.lastFlagMatchedByRule[key][tostring(flag)] = flagMatchesValue(flag, wanted)
    end
end

----------------------------------------------------------------
-- REVISION DE REGLAS
----------------------------------------------------------------
local function checkRule(rule)
    local key = getRuleKey(rule)
    local flags = toList(rule.flag)
    local wanted = tonumber(rule.value) or 1
    local mode = string.lower(tostring(rule.mode or "any"))

    if mode == "any" then
        SF.STATE.lastFlagMatchedByRule[key] = SF.STATE.lastFlagMatchedByRule[key] or {}

        for _, flag in ipairs(flags) do
            local flagKey = tostring(flag)
            local matched = flagMatchesValue(flag, wanted)
            local lastMatched = SF.STATE.lastFlagMatchedByRule[key][flagKey] == true

            if matched and not lastMatched then
                triggerRule(rule, flag)
            end

            SF.STATE.lastFlagMatchedByRule[key][flagKey] = matched
        end

        SF.STATE.lastRuleMatched[key] = ruleMatches(rule)
        return
    end

    local matched = ruleMatches(rule)
    local lastMatched = SF.STATE.lastRuleMatched[key] == true

    if matched and not lastMatched then
        triggerRule(rule, nil)
    end

    SF.STATE.lastRuleMatched[key] = matched

    SF.STATE.lastFlagMatchedByRule[key] = SF.STATE.lastFlagMatchedByRule[key] or {}
    for _, flag in ipairs(flags) do
        SF.STATE.lastFlagMatchedByRule[key][tostring(flag)] = flagMatchesValue(flag, wanted)
    end
end

----------------------------------------------------------------
-- LOOP
----------------------------------------------------------------
local function mainLoop(_, now)
    for _, rule in ipairs(SF.RULES) do
        checkRule(rule)
    end

    return now + (tonumber(SF.CONFIG.CHECK_INTERVAL) or 1)
end

local function start()
    if SF.STATE.started then
        return
    end

    for _, rule in ipairs(SF.RULES) do
        initRuleState(rule)
    end

    SF.STATE.started = true
    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)
    log("Sistema de sonidos por banderas iniciado", 5)
end

start()