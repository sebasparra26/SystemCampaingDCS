----------------------------------------------------------------
-- HDEV_RepeatingMessages.lua
-- Sistema de mensajes repetitivos por banderas
--
-- Autor: HorizontDev
-- Uso:
-- - Cargar este script en Mission Start.
-- - Editar la tabla MSG.MESSAGES.
-- - Cada mensaje puede depender de una bandera.
----------------------------------------------------------------

HDEV_RepeatingMessages = HDEV_RepeatingMessages or {}
local MSG = HDEV_RepeatingMessages

----------------------------------------------------------------
-- CONFIGURACION GENERAL
----------------------------------------------------------------
MSG.CONFIG = {
    DEBUG = false,

    -- Cada cuanto revisa banderas y mensajes
    MAIN_LOOP_INTERVAL = 1,

    -- Delay inicial despues de cargar el script
    START_DELAY = 2,

    -- Duracion por defecto si un mensaje no define showFor
    DEFAULT_SHOW_FOR = 10,

    -- Intervalo por defecto si un mensaje no define repeatEvery
    DEFAULT_REPEAT_EVERY = 300,

    -- true = al activarse la bandera, muestra el mensaje de una vez
    -- false = espera hasta que llegue el intervalo
    DEFAULT_SEND_ON_ACTIVATE = true
}

----------------------------------------------------------------
-- MENSAJES
--
-- target:
-- "all"  = todos
-- "blue" = coalicion azul
-- "red"  = coalicion roja
-- "group" = grupo especifico por groupName
--
-- Condicion simple:
-- flag = 100,
-- op = "==",
-- value = 1
--
-- Condiciones multiples:
-- conditions = {
--     { flag = 100, op = "==", value = 1 },
--     { flag = 101, op = ">",  value = 0 },
-- }
--
-- Operadores soportados:
-- "==", "~=", ">", "<", ">=", "<="
----------------------------------------------------------------

MSG.MESSAGES = {

    ----------------------------------------------------------------
    -- EJEMPLO 1
    -- EWR azul activo con bandera 100 valor 1
    ----------------------------------------------------------------
    {
        id = "EWR_BLUE_FREQ_01",

        enabled = true,

        target = "blue",

        text =
            "OSAMA BIEN LADEN A SIDO DADO DE BAJA\n" ..
            "Campaña Finalizada\n" ..
            "RTB a todas las unidades",

        showFor = 10,
        repeatEvery = 15,

        flag = 9005,
        op = "==",
        value = 1,

        sendOnActivate = true
    },

    {
        id = "EWR_BLUE_FREQ",

        enabled = true,

        target = "blue",

        text =
            "El OSO a sido destruido\n" ..
            "Campaña Finalizada\n" ..
            "RTB a todas las unidades",

        showFor = 15,
        repeatEvery = 30,

        flag = 2701,
        op = "==",
        value = 1,

        sendOnActivate = true
    },

    ----------------------------------------------------------------
    -- EJEMPLO 2
    -- Mensaje para rojos con otra bandera
    ----------------------------------------------------------------
    {
        id = "EWR_RED_FREQ",

        enabled = false,

        target = "red",

        text =
            "EWR ACTIVO\n" ..
            "Frecuencia: 260.000 MHz UHF\n" ..
            "Red de alerta temprana disponible para la coalicion roja.",

        showFor = 15,
        repeatEvery = 300,

        flag = 101,
        op = "==",
        value = 1,

        sendOnActivate = true
    },

    ----------------------------------------------------------------
    -- EJEMPLO 3
    -- Mensaje global, activo mientras la bandera 200 sea 1
    ----------------------------------------------------------------
    {
        id = "SERVER_INFO",

        enabled = false,

        target = "all",

        text =
            "INFORMACION DEL SERVIDOR\n" ..
            "Recuerde revisar las tareas activas en el menu F10.\n" ..
            "Mantenga comunicacion con su coalicion.",

        showFor = 12,
        repeatEvery = 600,

        flag = 200,
        op = "==",
        value = 1,

        sendOnActivate = true
    },

    ----------------------------------------------------------------
    -- EJEMPLO 4
    -- Mensaje con varias condiciones
    -- Solo se muestra si bandera 300 es 1 y bandera 301 es 2
    ----------------------------------------------------------------
    {
        id = "MISSION_WARNING_BLUE",

        enabled = false,

        target = "blue",

        text =
            "ADVERTENCIA OPERACIONAL\n" ..
            "Hay actividad enemiga cerca del frente.\n" ..
            "Proceda con escolta o cobertura aerea.",

        showFor = 20,
        repeatEvery = 180,

        conditions = {
            { flag = 300, op = "==", value = 1 },
            { flag = 301, op = "==", value = 2 },
        },

        sendOnActivate = true
    },

    ----------------------------------------------------------------
    -- EJEMPLO 5
    -- Mensaje a un grupo especifico
    ----------------------------------------------------------------
    {
        id = "GROUP_ONLY_MESSAGE",

        enabled = false,

        target = "group",
        groupName = "Nombre_Exacto_Del_Grupo",

        text =
            "MENSAJE PRIVADO DEL GRUPO\n" ..
            "Proceda al punto asignado.",

        showFor = 10,
        repeatEvery = 120,

        flag = 400,
        op = "==",
        value = 1,

        sendOnActivate = true
    },

    ----------------------------------------------------------------
    -- EJEMPLO 6
    -- Mensaje siempre activo, sin bandera
    -- Si no quieres mensajes siempre activos, dejalo enabled = false
    ----------------------------------------------------------------
    {
        id = "ALWAYS_ON_EXAMPLE",

        enabled = true,

        target = "all",

        text =
            "EXILIADOS SERVER 1\n" ..
            "MAGIC - AWACS: Freq = 265.200 MHz\n" ..
            "UNICOM: Freq = 228.000 MHz\n" ..
            "Recuerde revisar las tareas activas en el menu F10.",

        showFor = 6,
        repeatEvery = 400,

        sendOnActivate = true
    },
}

----------------------------------------------------------------
-- ESTADO INTERNO
----------------------------------------------------------------
MSG.STATE = MSG.STATE or {
    started = false,
    loopToken = 0,
    messages = {}
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg)
    env.info("[HDEV_MSG] " .. tostring(msg))

    if MSG.CONFIG.DEBUG then
        trigger.action.outText("[HDEV_MSG] " .. tostring(msg), 5)
    end
end

----------------------------------------------------------------
-- UTILIDADES
----------------------------------------------------------------
local function getFlagValue(flag)
    return tonumber(trigger.misc.getUserFlag(flag)) or 0
end

local function compareValues(left, op, right)
    left = tonumber(left) or 0
    right = tonumber(right) or 0
    op = op or "=="

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

local function getMessageId(message, index)
    if message.id and message.id ~= "" then
        return tostring(message.id)
    end

    return "MSG_" .. tostring(index)
end

local function conditionIsTrue(cond)
    if not cond or not cond.flag then
        return true
    end

    local current = getFlagValue(cond.flag)
    local op = cond.op or "=="
    local expected = cond.value or 1

    return compareValues(current, op, expected)
end

local function messageConditionsAreTrue(message)
    if message.enabled == false then
        return false
    end

    -- Condicion simple
    if message.flag ~= nil then
        local current = getFlagValue(message.flag)
        local op = message.op or "=="
        local expected = message.value or 1

        if not compareValues(current, op, expected) then
            return false
        end
    end

    -- Condiciones multiples tipo AND
    if type(message.conditions) == "table" then
        for _, cond in ipairs(message.conditions) do
            if not conditionIsTrue(cond) then
                return false
            end
        end
    end

    return true
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

local function sendMessage(message)
    local text = tostring(message.text or "")
    if text == "" then
        return
    end

    local showFor = tonumber(message.showFor) or MSG.CONFIG.DEFAULT_SHOW_FOR
    local target = tostring(message.target or "all"):lower()
    local clearView = message.clearView == true

    if target == "blue" then
        trigger.action.outTextForCoalition(coalition.side.BLUE, text, showFor, clearView)

    elseif target == "red" then
        trigger.action.outTextForCoalition(coalition.side.RED, text, showFor, clearView)

    elseif target == "group" then
        local grp = groupExistsByName(message.groupName)
        if grp then
            trigger.action.outTextForGroup(grp:getID(), text, showFor, clearView)
        else
            log("Grupo no encontrado para mensaje " .. tostring(message.id) .. ": " .. tostring(message.groupName))
        end

    else
        trigger.action.outText(text, showFor, clearView)
    end
end

local function getStateForMessage(messageId)
    MSG.STATE.messages[messageId] = MSG.STATE.messages[messageId] or {
        active = false,
        nextSendAt = 0,
        lastSentAt = -999999,
        sentCount = 0
    }

    return MSG.STATE.messages[messageId]
end

----------------------------------------------------------------
-- LOOP PRINCIPAL
----------------------------------------------------------------
local function mainLoop(args, now)
    args = args or {}

    if args.token ~= MSG.STATE.loopToken then
        return nil
    end

    now = now or timer.getTime()

    for index, message in ipairs(MSG.MESSAGES or {}) do
        local messageId = getMessageId(message, index)
        message.id = messageId

        local st = getStateForMessage(messageId)
        local shouldBeActive = messageConditionsAreTrue(message)

        if shouldBeActive then
            -- Acaba de activarse
            if not st.active then
                st.active = true

                local sendOnActivate = message.sendOnActivate
                if sendOnActivate == nil then
                    sendOnActivate = MSG.CONFIG.DEFAULT_SEND_ON_ACTIVATE
                end

                if sendOnActivate then
                    st.nextSendAt = now
                else
                    local repeatEvery = tonumber(message.repeatEvery) or MSG.CONFIG.DEFAULT_REPEAT_EVERY
                    st.nextSendAt = now + repeatEvery
                end

                log("Mensaje activado: " .. messageId)
            end

            -- Enviar si ya cumplio el intervalo
            if now >= (st.nextSendAt or 0) then
                sendMessage(message)

                st.lastSentAt = now
                st.sentCount = (st.sentCount or 0) + 1

                local repeatEvery = tonumber(message.repeatEvery) or MSG.CONFIG.DEFAULT_REPEAT_EVERY
                if repeatEvery < 1 then
                    repeatEvery = 1
                end

                st.nextSendAt = now + repeatEvery

                if MSG.CONFIG.DEBUG then
                    log("Mensaje enviado: " .. messageId .. " | siguiente en " .. tostring(repeatEvery) .. " segundos")
                end
            end

        else
            -- Acaba de desactivarse
            if st.active then
                st.active = false
                st.nextSendAt = 0

                log("Mensaje desactivado: " .. messageId)

                if message.deactivateText and message.deactivateText ~= "" then
                    local temp = {
                        id = messageId .. "_DEACTIVATE",
                        target = message.target,
                        groupName = message.groupName,
                        text = message.deactivateText,
                        showFor = message.deactivateShowFor or 8,
                        clearView = message.clearView
                    }
                    sendMessage(temp)
                end
            end
        end
    end

    return now + (tonumber(MSG.CONFIG.MAIN_LOOP_INTERVAL) or 1)
end

----------------------------------------------------------------
-- API PUBLICA
----------------------------------------------------------------
function MSG.start()
    MSG.STATE.loopToken = (MSG.STATE.loopToken or 0) + 1
    MSG.STATE.started = true

    local token = MSG.STATE.loopToken

    timer.scheduleFunction(
        mainLoop,
        { token = token },
        timer.getTime() + (tonumber(MSG.CONFIG.START_DELAY) or 1)
    )

    log("Sistema iniciado. Token: " .. tostring(token))
end

function MSG.stop()
    MSG.STATE.loopToken = (MSG.STATE.loopToken or 0) + 1
    MSG.STATE.started = false
    log("Sistema detenido.")
end

function MSG.forceSend(messageId)
    for index, message in ipairs(MSG.MESSAGES or {}) do
        local id = getMessageId(message, index)
        if id == messageId then
            sendMessage(message)
            log("Mensaje forzado: " .. tostring(messageId))
            return true
        end
    end

    log("No se encontro mensaje para forzar: " .. tostring(messageId))
    return false
end

function MSG.setMessageEnabled(messageId, enabled)
    for index, message in ipairs(MSG.MESSAGES or {}) do
        local id = getMessageId(message, index)
        if id == messageId then
            message.enabled = enabled == true
            log("Mensaje " .. tostring(messageId) .. " enabled = " .. tostring(message.enabled))
            return true
        end
    end

    log("No se encontro mensaje para cambiar enabled: " .. tostring(messageId))
    return false
end

----------------------------------------------------------------
-- ARRANQUE
----------------------------------------------------------------
MSG.start()