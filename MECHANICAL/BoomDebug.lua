----------------------------------------------------------------
-- HDEV_MarkDebugSpawn.lua
-- VERSION: 1
--
-- SISTEMA DEBUG POR MARCAS F10
--
-- COMANDOS:
--
-- EXPLOSION:
--   boom 1000 15
--   boom 500 2
--
-- SPAWN MODERNO / WWII:
--   spawn red T-90
--   spawn blue M 818
--   spawn red Tiger_I
--   spawn blue M4_Sherman
--
-- SPAWN CON ALIAS:
--   spawn red tiger
--   spawn red panther
--   spawn blue sherman
--   spawn blue firefly
--   spawn red strela10
--   spawn blue avenger
--
-- SPAWN MULTIPLE:
--   spawn red tiger x4
--   spawn blue sherman x6
--
-- SPAWN POR NACION:
--   spawn nation thirdreich Tiger_I
--   spawn nation usa M4_Sherman
--   spawn nation uk Churchill_VII
--   spawn nation russia T-90
--
-- NOTA:
-- - Unidades de tierra.
-- - Los alias estan en MD.UNIT_DEFS.
-- - THIRDREICH usa countryId = 66, detectado por tu JSON.
----------------------------------------------------------------

HDEV_MarkDebugSpawn = HDEV_MarkDebugSpawn or {}
local MD = HDEV_MarkDebugSpawn

----------------------------------------------------------------
-- CONFIGURACION EDITABLE
----------------------------------------------------------------
MD.CONFIG = {
    DEBUG = false,
    AUTO_REMOVE_MARK = true,
    MESSAGE_TIME = 8,

    ----------------------------------------------------------------
    -- BOOM
    ----------------------------------------------------------------
    BOOM_KEYWORD = "boom",
    DEFAULT_BOOM_DELAY = 0,
    MIN_BOOM_POWER = 1,
    MAX_BOOM_POWER = 100000,

    ----------------------------------------------------------------
    -- SPAWN
    ----------------------------------------------------------------
    DEFAULT_HEADING_DEG = 0,
    SPAWN_CATEGORY = Group.Category.GROUND,
    MAX_UNITS_PER_SPAWN = 20,
    UNIT_SPACING = 12,

    -- Si true, si intentas spawn blue Tiger_I y THIRDREICH esta en rojo,
    -- el script avisa y no spawnea para evitar unidades del bando equivocado.
    ENFORCE_COUNTRY_COALITION = true,

    -- Si el tipo no esta en la tabla de alias, usa el pais default del lado.
    DEFAULT_RED_COUNTRY_ID = country.id.RUSSIA,
    DEFAULT_BLUE_COUNTRY_ID = country.id.USA
}

MD.STATE = MD.STATE or {
    processedMarks = {},
    nextSpawnId = 1,
    indexesReady = false,
    aliasIndex = {},
    typeIndex = {}
}

----------------------------------------------------------------
-- COUNTRY IDS
----------------------------------------------------------------
local CID = {
    USA = country.id.USA or 2,
    UK = country.id.UK or 4,
    RUSSIA = country.id.RUSSIA or 0,

    -- Detectado en tu JSON:
    -- country = "THIRDREICH"
    -- countryId = 66
    THIRDREICH = 66
}

----------------------------------------------------------------
-- NACIONES / ALIAS DE PAISES
----------------------------------------------------------------
MD.NATIONS = {
    usa = {
        label = "USA",
        countryId = CID.USA,
        preferredSide = 2
    },

    us = {
        label = "USA",
        countryId = CID.USA,
        preferredSide = 2
    },

    eeuu = {
        label = "USA",
        countryId = CID.USA,
        preferredSide = 2
    },

    uk = {
        label = "UK",
        countryId = CID.UK,
        preferredSide = 2
    },

    britain = {
        label = "UK",
        countryId = CID.UK,
        preferredSide = 2
    },

    british = {
        label = "UK",
        countryId = CID.UK,
        preferredSide = 2
    },

    russia = {
        label = "RUSSIA",
        countryId = CID.RUSSIA,
        preferredSide = 1
    },

    ru = {
        label = "RUSSIA",
        countryId = CID.RUSSIA,
        preferredSide = 1
    },

    ussr = {
        label = "RUSSIA",
        countryId = CID.RUSSIA,
        preferredSide = 1
    },

    thirdreich = {
        label = "THIRDREICH",
        countryId = CID.THIRDREICH,
        preferredSide = 1
    },

    third_reich = {
        label = "THIRDREICH",
        countryId = CID.THIRDREICH,
        preferredSide = 1
    },

    reich = {
        label = "THIRDREICH",
        countryId = CID.THIRDREICH,
        preferredSide = 1
    },

    germanyww2 = {
        label = "THIRDREICH",
        countryId = CID.THIRDREICH,
        preferredSide = 1
    },

    germany_ww2 = {
        label = "THIRDREICH",
        countryId = CID.THIRDREICH,
        preferredSide = 1
    }
}

----------------------------------------------------------------
-- LADOS
----------------------------------------------------------------
MD.SIDES = {
    red = {
        label = "ROJO",
        sideId = 1,
        aliases = { "red", "rojo", "r" },
        defaultCountryId = MD.CONFIG.DEFAULT_RED_COUNTRY_ID,
        defaultTank = "T-90"
    },

    blue = {
        label = "AZUL",
        sideId = 2,
        aliases = { "blue", "azul", "b" },
        defaultCountryId = MD.CONFIG.DEFAULT_BLUE_COUNTRY_ID,
        defaultTank = "M1A2C_SEP_V3"
    }
}

----------------------------------------------------------------
-- UNIDADES / ALIAS / CLAVES
--
-- FORMATO:
-- {
--   type = "NombreTecnicoDCS",
--   countryId = CID.X,
--   preferredSide = 1 rojo / 2 azul,
--   aliases = { "alias1", "alias2" }
-- }
----------------------------------------------------------------
MD.UNIT_DEFS = {

    ----------------------------------------------------------------
    -- MODERNOS ROJOS
    ----------------------------------------------------------------
    {
        type = "T-90",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "t90", "t-90", "tankred", "tanqueruso" }
    },
    {
        type = "T-80UD",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "t80", "t80ud", "t-80ud" }
    },
    {
        type = "T-72B3",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "t72", "t72b3", "t-72b3" }
    },
    {
        type = "T-72B",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "t72b", "t-72b" }
    },
    {
        type = "SKP-11",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "skp", "skp11", "jtacred", "jtacrojo" }
    },
    {
        type = "Ural-375",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "ural", "ural375", "ammo_red", "municionred", "camionred" }
    },
    {
        type = "KAMAZ Truck",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "kamaz", "kamaztruck", "truckred", "camionrojo" }
    },
    {
        type = "SAU Msta",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "msta", "saumsta", "2s19", "artred1" }
    },
    {
        type = "Smerch",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "smerch", "smerchcm", "mlrsred" }
    },
    {
        type = "Smerch_HE",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "smerchhe", "smerch_he" }
    },
    {
        type = "Uragan_BM-27",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "uragan", "bm27", "bm-27" }
    },
    {
        type = "Grad-URAL",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "grad", "gradural", "grad-ural" }
    },
    {
        type = "SAU Akatsia",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "akatsia", "sauakatsia" }
    },
    {
        type = "SAU 2-C9",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "2c9", "sau2c9", "sau2-c9" }
    },
    {
        type = "Strela-1 9P31",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "strela1", "strela-1", "9p31" }
    },
    {
        type = "Strela-10M3",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "strela10", "strela-10", "strela10m3", "9k35", "9k35m" }
    },
    {
        type = "Osa 9A33 ln",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "osa", "9k33", "9a33", "osa9a33" }
    },
    {
        type = "Tor 9A331",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "tor", "9k331", "9a331" }
    },
    {
        type = "2S6 Tunguska",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "tunguska", "2s6", "2k22" }
    },
    {
        type = "Kub 2P25 ln",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "kubln", "kublauncher", "kub" }
    },
    {
        type = "Kub 1S91 str",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "kubradar", "kubstr", "1s91" }
    },
    {
        type = "SA-11 Buk LN 9A310M1",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "bukln", "buklauncher", "buk" }
    },
    {
        type = "SA-11 Buk SR 9S18M1",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "buksr", "buksearch", "bukradar" }
    },
    {
        type = "SA-11 Buk CC 9S470M1",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "bukcc", "bukcommand" }
    },
    {
        type = "S-300PS 5P85C ln",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "s300ln", "s300launcher", "s300" }
    },
    {
        type = "S-300PS 40B6M tr",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "s300tr", "s300track" }
    },
    {
        type = "S-300PS 40B6MD sr",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "s300sr", "s300search" }
    },
    {
        type = "S-300PS 64H6E sr",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "s300bigbird", "bigbird" }
    },
    {
        type = "S-300PS 54K6 cp",
        countryId = CID.RUSSIA,
        preferredSide = 1,
        aliases = { "s300cp", "s300command" }
    },

    {
    type = "CHAP_PantsirS1",
    countryId = CID.RUSSIA,
    preferredSide = 1,
    aliases = { "pantsir", "pantsirs1", "sa22", "sa-22", "chappantsir", "chap_pantsir" }
},

    ----------------------------------------------------------------
    -- MODERNOS AZULES
    ----------------------------------------------------------------
    {
        type = "M1A2C_SEP_V3",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "abrams", "m1", "m1a2", "m1a2c", "tankblue", "tanqueazul" }
    },
    {
        type = "Leopard-2",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "leopard", "leopard2", "leo2" }
    },
    {
        type = "Challenger2",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "challenger", "challenger2", "chieftain" }
    },
    {
        type = "Leclerc",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "leclerc" }
    },
    {
        type = "Merkava_Mk4",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "merkava", "merkava4", "merkavamk4" }
    },
    {
        type = "Hummer",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "hummer", "humvee", "jtacblue", "jtacazul" }
    },
    {
        type = "M 818",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m818", "m-818", "ammo", "ammoblue", "municionblue", "municionazul" }
    },
    {
        type = "M978 HEMTT Tanker",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "tanker", "fueltruck", "fuel", "m978", "hemtttanker", "combustible" }
    },
    {
        type = "MLRS",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "mlrs", "himars", "mlrsblue" }
    },
    {
        type = "SpGH_Dana",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "dana", "spghdana" }
    },
    {
        type = "T155_Firtina",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "firtina", "t155" }
    },
    {
        type = "M-109",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "paladin", "m109", "m-109" }
    },
    {
        type = "M1097 Avenger",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "avenger", "m1097" }
    },
    {
        type = "M48 Chaparral",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "chaparral", "m48" }
    },
    {
        type = "Roland ADS",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "roland", "rolandads" }
    },
    {
        type = "Roland Radar",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "rolandradar" }
    },
    {
        type = "Gepard",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "gepard", "gepardaaa" }
    },
    {
        type = "HEMTT_C-RAM_Phalanx",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "cram", "c-ram", "lpws", "phalanx", "hemttcram" }
    },
    {
        type = "Hawk ln",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "hawkln", "hawklauncher", "hawk" }
    },
    {
        type = "Hawk sr",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "hawksr", "hawksearch" }
    },
    {
        type = "Hawk tr",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "hawktr", "hawktrack" }
    },
    {
        type = "Hawk pcp",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "hawkpcp" }
    },
    {
        type = "Hawk cwar",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "hawkcwar" }
    },
    {
        type = "NASAMS_LN_C",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "nasamsln", "nasamslauncher", "nasams" }
    },
    {
        type = "NASAMS_Radar_MPQ64F1",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "nasamsradar", "mpq64" }
    },
    {
        type = "NASAMS_Command_Post",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "nasamscp", "nasamscommand" }
    },
    {
        type = "Patriot ln",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "patriotln", "patriotlauncher", "patriot" }
    },
    {
        type = "Patriot str",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "patriotradar", "patriotstr" }
    },
    {
        type = "Patriot ECS",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "patriotecs" }
    },
    {
        type = "Patriot cp",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "patriotcp", "patriotcommand" }
    },
    {
        type = "Patriot EPP",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "patriotepp" }
    },
    {
        type = "Patriot AMG",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "patriotamg" }
    },

    ----------------------------------------------------------------
    -- WWII THIRDREICH / ALEMANES
    ----------------------------------------------------------------
    {
        type = "Blitz_36-6700A",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "blitz", "opelblitz", "blitztruck" }
    },
    {
        type = "Elefant_SdKfz_184",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "elefant", "ferdinand", "sd184" }
    },
    {
        type = "Flakscheinwerfer_37",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "searchlight", "flakscheinwerfer", "reflector" }
    },
    {
        type = "FuMG-401",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "fumg401", "freya", "freya_lz", "radarww2" }
    },
    {
        type = "FuSe-65",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "fuse65", "wurzburg" }
    },
    {
        type = "Horch_901_typ_40_kfz_21",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "horch", "horch901", "kfz21" }
    },
    {
        type = "JagdPz_IV",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "jagdpz", "jagdpz4", "jagdpanzer4" }
    },
    {
        type = "Jagdpanther_G1",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "jagdpanther", "jagdpantherg1" }
    },
    {
        type = "KDO_Mod40",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "kdo", "kdomod40", "commandcar" }
    },
    {
        type = "Kubelwagen_82",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "kubel", "kubelwagen", "kubelwagen82" }
    },
    {
        type = "LeFH_18-40-105",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "lefh", "lefh18", "lefh105", "artww2red" }
    },
    {
        type = "Maschinensatz_33",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "generator", "maschinensatz" }
    },
    {
        type = "Pak40",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "pak", "pak40", "atgun", "antitanquealemana" }
    },
    {
        type = "Pz_IV_H",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "panzer4", "panziv", "pz4", "pziv", "panzeriv" }
    },
    {
        type = "Pz_V_Panther_G",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "panther", "pantherg", "pz5", "pzv" }
    },
    {
        type = "SK_C_28_naval_gun",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "skc28", "navalgun", "kanone" }
    },
    {
        type = "Sd_Kfz_2",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "sdkfz2", "kettenkrad" }
    },
    {
        type = "Sd_Kfz_234_2_Puma",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "puma", "sdkfz234", "sdkfz2342" }
    },
    {
        type = "Sd_Kfz_251",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "sdkfz251", "halftrackgerman", "hanomag" }
    },
    {
        type = "Sd_Kfz_7",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "sdkfz7" }
    },
    {
        type = "Stug_III",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "stug", "stug3", "stugiii" }
    },
    {
        type = "Stug_IV",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "stug4", "stugiv" }
    },
    {
        type = "SturmPzIV",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "sturmpz", "sturmpz4", "brummbar" }
    },
    {
        type = "Tiger_I",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "tiger", "tiger1", "tigeri" }
    },
    {
        type = "Tiger_II_H",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "tiger2", "tigerii", "kingtiger", "konigstiger" }
    },
    {
        type = "Watchtower",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "watchtowerred", "towerred", "torreww2red" }
    },
    {
        type = "Wespe124",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "wespe", "wespe124" }
    },
    {
        type = "fire_control",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "firecontrol", "fire_control" }
    },
    {
        type = "flak18",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "flak18" }
    },
    {
        type = "flak30",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "flak30" }
    },
    {
        type = "flak36",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "flak36", "88", "flak88" }
    },
    {
        type = "flak37",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "flak37" }
    },
    {
        type = "flak38",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "flak38" }
    },
    {
        type = "flak41",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "flak41" }
    },
    {
        type = "soldier_mauser98",
        countryId = CID.THIRDREICH,
        preferredSide = 1,
        aliases = { "mauser", "soldierger", "soldiergerman", "infredww2" }
    },

    ----------------------------------------------------------------
    -- WWII USA
    ----------------------------------------------------------------
    {
        type = "CCKW_353",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "cckw", "cckw353", "truckusa", "camionusa" }
    },
    {
        type = "FPS-117",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "fps117", "ewr", "radar" }
    },
    {
        type = "M10_GMC",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m10", "m10gmc", "wolverine" }
    },
    {
        type = "M12_GMC",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m12", "m12gmc" }
    },
    {
        type = "M1_37mm",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m137", "m1_37", "m1_37mm", "aa37" }
    },
    {
        type = "M2A1-105",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m2a1105", "m2a1", "howitzer105" }
    },
    {
        type = "M2A1_halftrack",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m2halftrack", "m2a1halftrack", "halftrackus" }
    },
    {
        type = "M30_CC",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m30", "m30cc" }
    },
    {
        type = "M45_Quadmount",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m45", "m45quad", "quadmount" }
    },
    {
        type = "M4A4_Sherman_FF",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "firefly", "shermanfirefly", "m4a4", "m4a4firefly" }
    },
    {
        type = "M4_Sherman",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "sherman", "m4", "m4sherman" }
    },
    {
        type = "M4_Tractor",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "m4tractor", "tractor" }
    },
    {
        type = "M8_Greyhound",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "greyhound", "m8", "m8greyhound" }
    },
    {
        type = "Watchtower",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "watchtowerblue", "towerblue", "torreww2blue" }
    },
    {
        type = "Willys_MB",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "willys", "jeep", "willysmb" }
    },
    {
        type = "bofors40",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "bofors", "bofors40", "aa40" }
    },
    {
        type = "soldier_wwii_us",
        countryId = CID.USA,
        preferredSide = 2,
        aliases = { "soldierus", "infus", "infblueww2" }
    },

    ----------------------------------------------------------------
    -- WWII UK
    ----------------------------------------------------------------
    {
        type = "Centaur_IV",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "centaur", "centaur4", "centauriv" }
    },
    {
        type = "Churchill_VII",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "churchill", "churchill7", "churchillvii" }
    },
    {
        type = "Cromwell_IV",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "cromwell", "cromwell4", "cromwelliv" }
    },
    {
        type = "Daimler_AC",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "daimler", "daimlerac", "armoredcaruk" }
    },
    {
        type = "Tetrarch",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "tetrarch" }
    },
    {
        type = "soldier_wwii_br_01",
        countryId = CID.UK,
        preferredSide = 2,
        aliases = { "soldieruk", "infuk", "infbr", "britishsoldier" }
    }


}

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function debugMsg(msg, t)
    if MD.CONFIG.DEBUG then
        trigger.action.outText("[MARK DEBUG] " .. tostring(msg), t or MD.CONFIG.MESSAGE_TIME)
    end
    env.info("[HDEV_MARK_DEBUG] " .. tostring(msg))
end

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizeSpaces(s)
    return trim((s or ""):gsub("%s+", " "))
end

local function lower(s)
    return string.lower(tostring(s or ""))
end

local function splitWords(s)
    local out = {}
    for token in string.gmatch(normalizeSpaces(s or ""), "%S+") do
        out[#out + 1] = token
    end
    return out
end

local function normalizeKey(s)
    s = lower(tostring(s or ""))
    s = s:gsub("[^%w]", "")
    return s
end

local function clamp(v, minV, maxV)
    v = tonumber(v) or 0
    if v < minV then v = minV end
    if v > maxV then v = maxV end
    return v
end

local function sanitizeName(s)
    s = tostring(s or "OBJ")
    s = s:gsub("[%s%-/\\%.]+", "_")
    s = s:gsub("[^%w_]", "")
    if s == "" then
        s = "OBJ"
    end
    return s
end

local function getCountryCoalitionSafe(countryId)
    if not coalition or not coalition.getCountryCoalition then
        return nil
    end

    local ok, result = pcall(function()
        return coalition.getCountryCoalition(countryId)
    end)

    if ok then
        return result
    end

    return nil
end

local function coalitionName(sideId)
    if sideId == 1 then return "ROJO" end
    if sideId == 2 then return "AZUL" end
    if sideId == 0 then return "NEUTRAL" end
    return tostring(sideId or "N/A")
end

local function resolveMarkPoint(event)
    if event and event.pos then
        local z = event.pos.z or event.pos.y
        return {
            x = event.pos.x,
            y = event.pos.y or 0,
            z = z
        }
    end

    if mist
        and mist.DBs
        and mist.DBs.markList
        and event
        and event.idx
        and mist.DBs.markList[event.idx]
        and mist.DBs.markList[event.idx].pos then

        local p = mist.DBs.markList[event.idx].pos
        local z = p.z or p.y
        return {
            x = p.x,
            y = p.y or 0,
            z = z
        }
    end

    return nil
end

local function pointToGround(point)
    if not point then return nil end

    local x = point.x
    local z = point.z or point.y
    local groundY = 0

    if land and land.getHeight then
        groundY = land.getHeight({ x = x, y = z }) or 0
    end

    return {
        x = x,
        y = groundY,
        z = z
    }
end

local function buildSignature(text, point)
    return table.concat({
        lower(normalizeSpaces(text)),
        tostring(math.floor((point and point.x) or 0)),
        tostring(math.floor((point and (point.z or point.y)) or 0))
    }, "|")
end

local function resolveSide(sideToken)
    local token = lower(sideToken)

    for sideKey, sideCfg in pairs(MD.SIDES) do
        for i = 1, #(sideCfg.aliases or {}) do
            if token == lower(sideCfg.aliases[i]) then
                return sideKey, sideCfg
            end
        end
    end

    return nil, nil
end

local function resolveNation(token)
    local key = normalizeKey(token)
    return MD.NATIONS[key]
end

----------------------------------------------------------------
-- INDEXAR ALIAS
----------------------------------------------------------------
local function buildIndexes()
    MD.STATE.aliasIndex = {}
    MD.STATE.typeIndex = {}

    for _, def in ipairs(MD.UNIT_DEFS or {}) do
        if def.type and def.type ~= "" then
            local typeKey = normalizeKey(def.type)

            MD.STATE.typeIndex[def.type] = def
            MD.STATE.aliasIndex[typeKey] = def

            for _, alias in ipairs(def.aliases or {}) do
                local aliasKey = normalizeKey(alias)
                if aliasKey ~= "" then
                    MD.STATE.aliasIndex[aliasKey] = def
                end
            end
        end
    end

    MD.STATE.indexesReady = true
end

local function resolveUnitDef(rawType)
    if not MD.STATE.indexesReady then
        buildIndexes()
    end

    rawType = trim(rawType or "")
    if rawType == "" then
        return nil, ""
    end

    if MD.STATE.typeIndex[rawType] then
        return MD.STATE.typeIndex[rawType], rawType
    end

    local key = normalizeKey(rawType)
    if MD.STATE.aliasIndex[key] then
        return MD.STATE.aliasIndex[key], rawType
    end

    return nil, rawType
end

----------------------------------------------------------------
-- PARSER BOOM
----------------------------------------------------------------
local function parseBoomCommand(text)
    local raw = normalizeSpaces(text)
    local parts = splitWords(raw)

    if #parts == 0 then
        return nil, nil
    end

    if lower(parts[1]) ~= MD.CONFIG.BOOM_KEYWORD then
        return nil, nil
    end

    if not parts[2] then
        return nil, "Falta la potencia. Ejemplo: boom 1000 15"
    end

    local power = tonumber(parts[2])
    if not power then
        return nil, "La potencia no es valida. Ejemplo: boom 1000 15"
    end

    local delay = MD.CONFIG.DEFAULT_BOOM_DELAY
    if parts[3] ~= nil then
        delay = tonumber(parts[3])
        if delay == nil then
            return nil, "El delay no es valido. Ejemplo: boom 1000 15"
        end
    end

    power = clamp(power, MD.CONFIG.MIN_BOOM_POWER, MD.CONFIG.MAX_BOOM_POWER)
    delay = math.max(0, delay)

    return {
        kind = "boom",
        power = power,
        delay = delay,
        rawText = raw
    }, nil
end

----------------------------------------------------------------
-- PARSER SPAWN
----------------------------------------------------------------
local function extractCountFromParts(parts)
    local count = 1

    if #parts > 0 then
        local last = tostring(parts[#parts] or "")
        local n = last:match("^[xX](%d+)$")
        if n then
            count = tonumber(n) or 1
            table.remove(parts, #parts)
        end
    end

    count = clamp(count, 1, MD.CONFIG.MAX_UNITS_PER_SPAWN)
    return count
end

local function parseSpawnCommand(text)
    local raw = normalizeSpaces(text)
    local parts = splitWords(raw)

    if #parts == 0 then
        return nil, nil
    end

    local keyword = lower(parts[1])

    if keyword ~= "tank" and keyword ~= "spawn" and keyword ~= "unit" then
        return nil, nil
    end

    ----------------------------------------------------------------
    -- spawn nation thirdreich Tiger_I
    ----------------------------------------------------------------
    if keyword == "spawn" and lower(parts[2]) == "nation" then
        if not parts[3] then
            return nil, "Falta la nacion. Ejemplo: spawn nation thirdreich Tiger_I"
        end

        local nation = resolveNation(parts[3])
        if not nation then
            return nil, "Nacion invalida. Usa: thirdreich, usa, uk, russia."
        end

        if #parts < 4 then
            return nil, "Falta el tipo de unidad. Ejemplo: spawn nation thirdreich Tiger_I"
        end

        local typeParts = {}
        for i = 4, #parts do
            typeParts[#typeParts + 1] = parts[i]
        end

        local count = extractCountFromParts(typeParts)
        local requestedType = table.concat(typeParts, " ")
        local def, original = resolveUnitDef(requestedType)

        local unitType = requestedType
        if def and def.type then
            unitType = def.type
        end

        return {
            kind = "spawn",
            spawnKeyword = keyword,
            sideKey = nil,
            sideCfg = nil,
            nation = nation,
            countryId = nation.countryId,
            countryLabel = nation.label,
            requestedType = original,
            unitType = unitType,
            unitDef = def,
            count = count,
            rawText = raw
        }, nil
    end

    ----------------------------------------------------------------
    -- spawn red Tiger_I
    -- tank red
    ----------------------------------------------------------------
    if not parts[2] then
        return nil, "Falta el lado. Ejemplo: spawn red T-90 o spawn blue M 818"
    end

    local sideKey, sideCfg = resolveSide(parts[2])
    if not sideCfg then
        return nil, "Lado invalido. Usa red/rojo o blue/azul."
    end

    local typeParts = {}

    if keyword == "tank" and #parts < 3 then
        typeParts = { sideCfg.defaultTank }
    else
        if #parts < 3 then
            return nil, "Falta el nombre tecnico o alias. Ejemplo: spawn red tiger"
        end

        for i = 3, #parts do
            typeParts[#typeParts + 1] = parts[i]
        end
    end

    local count = extractCountFromParts(typeParts)
    local requestedType = table.concat(typeParts, " ")
    local def, original = resolveUnitDef(requestedType)

    local unitType = requestedType
    local countryId = sideCfg.defaultCountryId
    local countryLabel = sideCfg.label

    if def then
        unitType = def.type
        countryId = def.countryId or countryId

        if countryId == CID.THIRDREICH then
            countryLabel = "THIRDREICH"
        elseif countryId == CID.USA then
            countryLabel = "USA"
        elseif countryId == CID.UK then
            countryLabel = "UK"
        elseif countryId == CID.RUSSIA then
            countryLabel = "RUSSIA"
        end
    end

    return {
        kind = "spawn",
        spawnKeyword = keyword,
        sideKey = sideKey,
        sideCfg = sideCfg,
        countryId = countryId,
        countryLabel = countryLabel,
        requestedType = original,
        unitType = unitType,
        unitDef = def,
        count = count,
        rawText = raw
    }, nil
end

local function parseAnyCommand(text)
    local cmd, err = parseBoomCommand(text)
    if cmd or err then
        return cmd, err
    end

    cmd, err = parseSpawnCommand(text)
    if cmd or err then
        return cmd, err
    end

    return nil, nil
end

----------------------------------------------------------------
-- BOOM
----------------------------------------------------------------
local function executeExplosion(data)
    if not data or not data.point then
        debugMsg("No se pudo ejecutar la explosion: punto invalido.", 8)
        return
    end

    local groundPoint = pointToGround(data.point)
    if not groundPoint then
        debugMsg("No se pudo ejecutar la explosion: ground point invalido.", 8)
        return
    end

    trigger.action.explosion(groundPoint, data.power)

    debugMsg(
        "Explosion ejecutada | poder=" .. tostring(data.power) ..
        " | x=" .. tostring(math.floor(groundPoint.x)) ..
        " | z=" .. tostring(math.floor(groundPoint.z)),
        8
    )
end

local function scheduleExplosion(cmd, point)
    local payload = {
        power = cmd.power,
        point = point
    }

    timer.scheduleFunction(function(args)
        executeExplosion(args)
        return nil
    end, payload, timer.getTime() + cmd.delay)

    debugMsg(
        "Explosion programada | poder=" .. tostring(cmd.power) ..
        " | delay=" .. tostring(cmd.delay) .. "s",
        8
    )

    return true
end

----------------------------------------------------------------
-- SPAWN
----------------------------------------------------------------
local function buildSpawnNames(countryLabel, unitType)
    local id = MD.STATE.nextSpawnId
    MD.STATE.nextSpawnId = MD.STATE.nextSpawnId + 1

    local base =
        "DBG_" ..
        sanitizeName(countryLabel or "SIDE") .. "_" ..
        sanitizeName(unitType) .. "_" ..
        tostring(id)

    return base
end

local function buildGroundGroupData(groupName, unitType, point, count)
    local groundPoint = pointToGround(point)
    if not groundPoint then
        return nil
    end

    count = clamp(count or 1, 1, MD.CONFIG.MAX_UNITS_PER_SPAWN)

    local heading = math.rad(MD.CONFIG.DEFAULT_HEADING_DEG or 0)
    local spacing = tonumber(MD.CONFIG.UNIT_SPACING) or 12
    local half = (count - 1) / 2

    local units = {}

    for i = 1, count do
        local offset = (i - 1 - half) * spacing

        units[i] = {
            name = groupName .. "_U" .. tostring(i),
            type = unitType,
            skill = "Excellent",
            x = groundPoint.x + offset,
            y = groundPoint.z,
            heading = heading,
            playerCanDrive = false
        }
    end

    return {
        visible = true,
        lateActivation = false,
        task = "Ground Nothing",
        route = {
            points = {
                [1] = {
                    x = groundPoint.x,
                    y = groundPoint.z,
                    action = "Off Road",
                    speed = 0,
                    type = "Turning Point",
                    task = {
                        id = "ComboTask",
                        params = {
                            tasks = {}
                        }
                    }
                }
            }
        },
        units = units,
        name = groupName
    }
end

local function validateCountrySide(cmd)
    if not MD.CONFIG.ENFORCE_COUNTRY_COALITION then
        return true
    end

    if not cmd or not cmd.countryId then
        return true
    end

    -- spawn nation permite usar el pais directo sin exigir side.
    if cmd.nation then
        return true
    end

    if not cmd.sideCfg or not cmd.sideCfg.sideId then
        return true
    end

    local realSide = getCountryCoalitionSafe(cmd.countryId)
    if realSide == nil then
        return true
    end

    if realSide ~= cmd.sideCfg.sideId then
        debugMsg(
            "Pais no pertenece a ese lado.\n" ..
            "Pedido: " .. tostring(cmd.sideCfg.label) .. "\n" ..
            "Pais: " .. tostring(cmd.countryLabel) .. " countryId=" .. tostring(cmd.countryId) .. "\n" ..
            "Coalicion real del pais: " .. coalitionName(realSide) .. "\n" ..
            "Usa el lado correcto o usa: spawn nation " .. tostring(cmd.countryLabel) .. " " .. tostring(cmd.unitType),
            15
        )
        return false
    end

    return true
end

local function spawnGroundUnit(cmd, point)
    if not cmd or not point then
        debugMsg("Spawn invalido.", 8)
        return false
    end

    if not validateCountrySide(cmd) then
        return false
    end

    local groupName = buildSpawnNames(cmd.countryLabel, cmd.unitType)
    local groupData = buildGroundGroupData(groupName, cmd.unitType, point, cmd.count or 1)

    if not groupData then
        debugMsg("No se pudo construir los datos del spawn.", 8)
        return false
    end

    local ok, result = pcall(function()
        return coalition.addGroup(
            cmd.countryId,
            MD.CONFIG.SPAWN_CATEGORY,
            groupData
        )
    end)

    if not ok or not result then
        debugMsg(
            "Error creando unidad.\n" ..
            "Tipo: " .. tostring(cmd.unitType) .. "\n" ..
            "Pais: " .. tostring(cmd.countryLabel) .. " / " .. tostring(cmd.countryId) .. "\n" ..
            "Pedido: " .. tostring(cmd.rawText),
            15
        )

        env.info(
            "[HDEV_MARK_DEBUG_ERROR] spawn failed | type=" .. tostring(cmd.unitType) ..
            " countryId=" .. tostring(cmd.countryId) ..
            " raw=" .. tostring(cmd.rawText) ..
            " err=" .. tostring(result)
        )

        return false
    end

    debugMsg(
        "Unidad creada.\n" ..
        "Tipo: " .. tostring(cmd.unitType) .. "\n" ..
        "Cantidad: " .. tostring(cmd.count or 1) .. "\n" ..
        "Pais: " .. tostring(cmd.countryLabel) .. " / " .. tostring(cmd.countryId) .. "\n" ..
        "Grupo: " .. tostring(groupName),
        12
    )

    return true
end

----------------------------------------------------------------
-- EVENT HANDLER
----------------------------------------------------------------
local markHandler = {}

function markHandler:onEvent(event)
    if not event then
        return
    end

    if event.id == world.event.S_EVENT_MARK_ADDED
        or event.id == world.event.S_EVENT_MARK_CHANGE then

        local text = event.text or ""
        local cmd, err = parseAnyCommand(text)

        if err then
            debugMsg(err, 8)
            return
        end

        if not cmd then
            return
        end

        local point = resolveMarkPoint(event)
        if not point then
            debugMsg("No se pudo leer la posicion de la marca.", 8)
            return
        end

        local signature = buildSignature(text, point)
        if event.idx and MD.STATE.processedMarks[event.idx] == signature then
            return
        end

        if event.idx then
            MD.STATE.processedMarks[event.idx] = signature
        end

        local success = false

        if cmd.kind == "boom" then
            success = scheduleExplosion(cmd, point)
        elseif cmd.kind == "spawn" then
            success = spawnGroundUnit(cmd, point)
        end

        if success and MD.CONFIG.AUTO_REMOVE_MARK and event.idx then
            trigger.action.removeMark(event.idx)
            MD.STATE.processedMarks[event.idx] = nil
        end

    elseif event.id == world.event.S_EVENT_MARK_REMOVE then
        if event.idx then
            MD.STATE.processedMarks[event.idx] = nil
        end
    end
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
buildIndexes()
world.addEventHandler(markHandler)

trigger.action.outText(
    "HDEV Mark Debug Spawn cargado.\n" ..
    "Ejemplos:\n" ..
    "boom 1000 15\n" ..
    "spawn red tiger\n" ..
    "spawn blue sherman\n" ..
    "spawn red Strela-10M3\n" ..
    "spawn blue M 818\n" ..
    "spawn nation thirdreich Tiger_I",
    15
)

env.info("[HDEV_MARK_DEBUG] HDEV_MarkDebugSpawn VERSION 1 cargado.")