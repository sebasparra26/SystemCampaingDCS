if not mist or not mist.teleportToPoint then
    trigger.action.outText("ERROR: MIST no esta cargado.", 15)
    return
end

local debugActivo = false
local intervaloRevision = 2

----------------------------------------------------------------
-- MODULO 1
-- CLONADO POR BANDERA
--
-- 1 = ROJO
-- 2 = AZUL
--
-- Soporta:
-- [100] = { rojo = "RU_100_Difarsuwar", azul = "US_100_Difarsuwar" }
--
-- O tambien:
-- [154] = {
--     rojo = { "RU_154_Khalkhalah", "RU_SAM_154_Khalkhalah" },
--     azul = { "US_154_Khalkhalah" }
-- }
----------------------------------------------------------------
local gruposPorBandera = {
    [100] = { rojo = "RU_100_Difarsuwar", azul = "US_100_Difarsuwar" },
    [101] = { rojo = "RU_101_AbuS", azul = "US_101_AbuS" },
    [102] = { rojo = "RU_102_AsS", azul = "US_102_AsS" },
    [103] = { rojo = "RU_103_Ismailiyah", azul = "US_103_Ismailiyah" },
    [104] = { rojo = "RU_104_Melez", azul = "US_104_Melez" },
    [105] = { rojo = "RU_105_Fayed", azul = "US_105_Fayed" },
    [106] = { rojo = "RU_106_Hatzerim", azul = "US_106_Hatzerim" },
    [107] = { rojo = "RU_107_Nevatim", azul = "US_107_Nevatim" },
    [108] = { rojo = "RU_108_Ramon", azul = "US_108_Ramon" },
    [109] = { rojo = "RU_109_Ovda", azul = "US_109_Ovda" },
    [110] = { rojo = "RU_110_Kibrit", azul = "US_110_Kibrit" },
    [111] = { rojo = "RU_111_Kedem", azul = "US_111_Kedem" },
    [112] = { rojo = "RU_112_WadiJ", azul = "US_112_WadiJ" },
    [113] = { rojo = "RU_113_AlM", azul = "US_113_AlM" },
    [114] = { rojo = "RU_114_AzZaqaziq", azul = "US_114_AzZaqaziq" },
    [115] = { rojo = "RU_115_Bilbeis", azul = "US_115_Bilbeis" },
    [116] = { rojo = "RU_116_Cairo", azul = "US_116_Cairo" },
    [117] = { rojo = "RU_117_CairoW", azul = "US_117_CairoW" },
    [118] = { rojo = "RU_118_Inshas", azul = "US_118_Inshas" },
    [119] = { rojo = "RU_119_Hatzor", azul = "US_119_Hatzor" },
    [120] = { rojo = "RU_120_Palmachim", azul = "US_120_Palmachim" },
    [121] = { rojo = "RU_121_SdeD", azul = "US_121_SdeD" },
    [122] = { rojo = "RU_122_TelN", azul = "US_122_TelN" },
    [123] = { rojo = "RU_123_BenG", azul = "US_123_BenG" },
    [124] = { rojo = "RU_124_StC", azul = "US_124_StC" },
    [125] = { rojo = "RU_125_AbuR", azul = "US_125_AbuR" },
    [126] = { rojo = "RU_126_Baluza", azul = "US_126_Baluza" },
    [127] = { rojo = "RU_127_BirH", azul = "US_127_BirH" },
    [128] = { rojo = "RU_128_ElA", azul = "US_128_ElA" },
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
    [145] = { rojo = "RU_145_Rafic", azul = "US_145_Rafic" },
    [146] = { rojo = "RU_146_Tabuk", azul = "US_146_Tabuk" },
    [147] = { rojo = "RU_147_Damascus", azul = "US_147_Damascus" },
    [148] = { rojo = "RU_148_Mezzeh", azul = "US_148_Mezzeh" },
    [149] = { rojo = "RU_149_Ramat", azul = "US_149_Ramat" },
    [150] = { rojo = "RU_150_Megiddo", azul = "US_150_Megiddo" },
    [151] = { rojo = "RU_151_Ein", azul = "US_151_Ein" },
    [152] = { rojo = "RU_152_Taba", azul = "US_152_Taba" },
    [153] = { rojo = "RU_153_KingF", azul = "US_153_KingF" },
    [154] = { rojo = "RU_154_Khalkhalah", azul = "US_154_Khalkhalah" },
}

----------------------------------------------------------------
-- MODULO 2
-- ACTIVACION SIMPLE DE GRUPOS POR FLAG
--
-- EJEMPLO:
-- Flag 2000 = 1 -> activa Grupo_X y Grupo_Y
--
-- Estos grupos deben existir en el ME normalmente en Late Activation
-- y este modulo los activa con su nombre original del ME.
----------------------------------------------------------------
local activacionesPorFlag = {
    [2100] = {
        valor = 1,
        grupos = {
            "RU_SAM_154_Khalkhalah",
            "RU_HELI_154_Khalkhalah",
            "RU_EWR_154_Khalkhalah"
            --"Grupo_Y"
        }
    },

    -- Ejemplo adicional:
    -- [2001] = {
    --     valor = 1,
    --     grupos = {
    --         "SAM_EXTRA_01",
    --         "AAA_EXTRA_01"
    --     }
    -- },
}

local estadoPrevioBanderas = {}
local estadoPrevioActivaciones = {}

local function debug(msg, tiempo)
    if debugActivo then
        trigger.action.outText("[ActivateUnits] " .. tostring(msg), tiempo or 10)
    end
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
    end
end

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

local function activarGrupoOriginal(nombreGrupo, bandera)
    if not nombreGrupo or nombreGrupo == "" then
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
        activarGrupoOriginal(listaGrupos[i], flag)
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

local function verificarSistema()
    revisarModuloClonado()
    revisarModuloActivaciones()
    return timer.getTime() + intervaloRevision
end

timer.scheduleFunction(verificarSistema, nil, timer.getTime() + intervaloRevision)