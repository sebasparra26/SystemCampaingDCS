-- ============================================================================
-- EconomicSystemCoalition_RED_V4.lua
-- Generador economico Rojo usando el nucleo compartido
-- ============================================================================

assert(HDEV_Economy, "Carga primero HDEV_EconomyCore.lua")

local economySettings = HDEV_EconomyGlobalConfig or {
    jsonRelativePath = "Config\\HorizontDev\\KOLA\\money.json",
    importWindowSeconds = 30,
    autosaveInterval = 10,
    minWriteInterval = 5,
    debug = false
}

local Economy = HDEV_Economy.init({
    jsonRelativePath = economySettings.jsonRelativePath or "Config\\HorizontDev\\KOLA\\money.json",
    importWindowSeconds = economySettings.importWindowSeconds or 30,
    autosaveInterval = economySettings.autosaveInterval or 10,
    minWriteInterval = economySettings.minWriteInterval or 5,
    debug = economySettings.debug and true or false
})

Economy.registerFactoryGenerator({
    id = "RED_FACTORIES",
    coalition = 1,
    zoneName = "EconomicZoneRED",
    staticNames = {
        "Factory_RED_1"
    },
    amountPerTick = 827, -- 18515
    interval = 10
})

env.info("[ECONOMIA] Sistema economico rojo V4 iniciado correctamente.")
