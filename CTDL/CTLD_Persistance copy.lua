----------------------------------------------------------------
-- CTLD_Persistance.lua
-- HDEV CTLD Passive Persistence
-- VERSION: 2.8.0_PASSIVE_SAFE_FARP_DRONE
--
-- CARGA:
-- 1) mist_4_5_128.lua
-- 2) CTLD.lua
-- 3) CTLD_Persistance.lua
--
-- REGLA CRITICA:
-- Este script NO reemplaza funciones internas de CTLD.
-- NO toca:
--   ctld.spawnCrateGroup
--   ctld.spawnFOB
--   ctld.unpackCrates
--   ctld.unpackAASystem
--   ctld.unpackMultiCrate
--   ctld.addCallback
--
-- ESTRATEGIA:
-- - Captura pasiva por eventos S_EVENT_BIRTH.
-- - Escanea FOBs ya creados por CTLD desde ctld.logisticUnits / ctld.builtFOBS.
-- - Restaura grupos desde JSON usando mist.dynAdd.
-- - Restaura FOB static y crea FARP tipo Mission Editor.
-- - Restaura drones/JTAC con orbit, protecciones y ctld.JTACStart.
----------------------------------------------------------------

if not mist or not mist.dynAdd or not mist.dynAddStatic or not mist.getNextGroupId or not mist.getNextUnitId then
    trigger.action.outText("ERROR CTLD_Persistance: MIST no esta cargado o faltan funciones basicas.", 15)
    return
end

if not ctld then
    trigger.action.outText("ERROR CTLD_Persistance: CTLD.lua no esta cargado.", 15)
    return
end

HDEV_CTLDDeploymentPersistence = HDEV_CTLDDeploymentPersistence or {}
local CTDP = HDEV_CTLDDeploymentPersistence

----------------------------------------------------------------
-- CONFIGURACION EDITABLE
----------------------------------------------------------------
CTDP.CONFIG = CTDP.CONFIG or {
    DEBUG = false,

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\KOLA\\SystemCTLDDeploymentPersistenceKola.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 60,
    MAIN_LOOP_INTERVAL = 1,

    PASSIVE_CAPTURE_DELAY = 2,
    PASSIVE_WORLD_SCAN_DELAY = 3,
    PASSIVE_FOB_SCAN_INTERVAL = 5,
    MISSING_DEAD_GRACE = 10,

    RUNTIME_PREFIX = "HDEV_CTLD_",
    FOB_RUNTIME_PREFIX = "HDEV_FOB_",

    SAVE_MODE = "all", -- all | categories | units

    SAVE_CATEGORIES = {
        ["SAM Corto Alcance"] = true,
        ["SAM Medio Alcance"] = true,
        ["SAM Largo Alcance"] = true,
        ["Vehiculos de Combate"] = true,
        ["Soporte Logistico"] = true,
        ["Artilleria"] = true,
        ["Drones"] = true,
        ["JTAC"] = true,
        ["CTLD"] = true,
    },

    SAVE_UNITS = {
        ["Hummer"] = true,
        ["SKP-11"] = true,
        ["MQ-9 Reaper"] = true,
        ["RQ-1A Predator"] = true,
    },

    IGNORE_UNITS = {},

    DRONES = {
        PROTECT_ON_CAPTURE = true,
        PROTECT_ON_RESTORE = true,
        PROTECTION_RETRIES = 12,
        PROTECTION_INTERVAL = 1,
        DEFAULT_SPEED = 80,
        DEFAULT_ALT = 3500,
        DEFAULT_CODE = 1688,
        ORBIT_SPEED = 80,
        ORBIT_ALT = 3500,
        ORBIT_PATTERN = "Circle",
        ORBIT_RADIUS = 1500,
        TYPES = {
            ["MQ-9 Reaper"] = true,
            ["MQ-9_Reaper"] = true,
            ["RQ-1A Predator"] = true,
            ["RQ-1A_Predator"] = true,
        }
    },

    SAVE_FOBS = true,
    RESTORE_FOB_TO_CTLD_LOGISTICS = true,

    FARP = {
        enabled = true,

        NAME_MODE = "ALFA_ZULU",
        NAME_LIST = {
            "ALFA", "BRAVO", "CHARLIE", "DELTA", "ECO", "FOXTROT", "GOLF", "HOTEL", "INDIA", "JULIETT",
            "KILO", "LIMA", "MIKE", "NOVEMBER", "OSCAR", "PAPA", "QUEBEC", "ROMEO", "SIERRA", "TANGO",
            "UNIFORM", "VICTOR", "WHISKEY", "XRAY", "YANKEE", "ZULU"
        },

        -- MISMA ESTRUCTURA BASE DEL PERSISTENCE QUE FUNCIONABA.
        type = "FARP",
        shape_name = "FARPS",
        category = "Heliports",

        offsetX = 70,
        offsetZ = 50,
        heading = 0,

        -- Frecuencia en MHz como Mission Editor, no en Hz.
        frequency = 127.5,
        modulation = 0,
        callsign = 1,

        dynamicSpawn = true,
        allowHotStart = true,
        dynamicCargo = true,
        unlimitedFuel = true,
        unlimitedMunitions = true,
        unlimitedAircrafts = true,

        VERIFY_RETRIES = 15,
        VERIFY_INTERVAL = 2,

        WAREHOUSE = {
            enabled = true,
            applyDelay = 2,
            retryCount = 12,
            retryInterval = 2,
            repeatTopupOnExport = true,

            liquids = {
                [0] = 999999999,
                [1] = 999999999,
                [2] = 999999999,
                [3] = 999999999,
            },

            aircraft = {
                ["UH-1H"] = 9999,
                ["AH-64D_BLK_II"] = 9999,
                ["OH58D"] = 9999,
                ["CH-47Fbl1"] = 9999,
                ["SA342L"] = 9999,
                ["SA342M"] = 9999,
                ["SA342Minigun"] = 9999,
                ["Mi-24P"] = 9999,
                ["Ka-50_3"] = 9999,
                ["Mi-8MT"] = 9999,
            },

            weapon = {
                ["weapons.adapters.lau-88"] = 999999,
        ["weapons.bombs.250-2"] = 999999,
        ["weapons.bombs.250-3"] = 999999,
        ["weapons.bombs.AB_250_2_SD_10A"] = 999999,
        ["weapons.bombs.AB_250_2_SD_2"] = 999999,
        ["weapons.bombs.AB_500_1_SD_10A"] = 999999,
        ["weapons.bombs.AGM_62"] = 999999,
        ["weapons.bombs.AGM_62_I"] = 999999,
        ["weapons.bombs.AH6_SMOKE_BLUE"] = 999999,
        ["weapons.bombs.AH6_SMOKE_GREEN"] = 999999,
        ["weapons.bombs.AH6_SMOKE_RED"] = 999999,
        ["weapons.bombs.AH6_SMOKE_YELLOW"] = 999999,
        ["weapons.bombs.AN-M66A2"] = 999999,
        ["weapons.bombs.AN-M81"] = 999999,
        ["weapons.bombs.AN-M88"] = 999999,
        ["weapons.bombs.AN_M30A1"] = 999999,
        ["weapons.bombs.AN_M57"] = 999999,
        ["weapons.bombs.AN_M64"] = 999999,
        ["weapons.bombs.AN_M65"] = 999999,
        ["weapons.bombs.AN_M66"] = 999999,
        ["weapons.bombs.AO_25SL"] = 999999,
        ["weapons.bombs.BAP-100"] = 999999,
        ["weapons.bombs.BAP_100"] = 999999,
        ["weapons.bombs.BAT-120"] = 999999,
        ["weapons.bombs.BDU_33"] = 999999,
        ["weapons.bombs.BDU_45"] = 999999,
        ["weapons.bombs.BDU_45B"] = 999999,
        ["weapons.bombs.BDU_45LGB"] = 999999,
        ["weapons.bombs.BDU_50HD"] = 999999,
        ["weapons.bombs.BDU_50LD"] = 999999,
        ["weapons.bombs.BDU_50LGB"] = 999999,
        ["weapons.bombs.BEER_BOMB"] = 999999,
        ["weapons.bombs.BETAB-500M"] = 999999,
        ["weapons.bombs.BETAB-500S"] = 999999,
        ["weapons.bombs.BIN_200"] = 999999,
        ["weapons.bombs.BLG66"] = 999999,
        ["weapons.bombs.BLG66_BELOUGA"] = 999999,
        ["weapons.bombs.BLG66_EG"] = 999999,
        ["weapons.bombs.BLU-3B_GROUP"] = 999999,
        ["weapons.bombs.BLU-3B_OLD"] = 999999,
        ["weapons.bombs.BLU-3_GROUP"] = 999999,
        ["weapons.bombs.BLU-4B_GROUP"] = 999999,
        ["weapons.bombs.BLU-4B_OLD"] = 999999,
        ["weapons.bombs.BLU_3B_GROUP"] = 999999,
        ["weapons.bombs.BLU_4B_GROUP"] = 999999,
        ["weapons.bombs.BL_755"] = 999999,
        ["weapons.bombs.BR_250"] = 999999,
        ["weapons.bombs.BR_500"] = 999999,
        ["weapons.bombs.BetAB_500"] = 999999,
        ["weapons.bombs.BetAB_500ShP"] = 999999,
        ["weapons.bombs.British_GP_250LB_Bomb_Mk1"] = 999999,
        ["weapons.bombs.British_GP_250LB_Bomb_Mk4"] = 999999,
        ["weapons.bombs.British_GP_250LB_Bomb_Mk5"] = 999999,
        ["weapons.bombs.British_GP_500LB_Bomb_Mk1"] = 999999,
        ["weapons.bombs.British_GP_500LB_Bomb_Mk4"] = 999999,
        ["weapons.bombs.British_GP_500LB_Bomb_Mk4_Short"] = 999999,
        ["weapons.bombs.British_GP_500LB_Bomb_Mk5"] = 999999,
        ["weapons.bombs.British_MC_250LB_Bomb_Mk1"] = 999999,
        ["weapons.bombs.British_MC_250LB_Bomb_Mk2"] = 999999,
        ["weapons.bombs.British_MC_500LB_Bomb_Mk1_Short"] = 999999,
        ["weapons.bombs.British_MC_500LB_Bomb_Mk2"] = 999999,
        ["weapons.bombs.British_SAP_250LB_Bomb_Mk5"] = 999999,
        ["weapons.bombs.British_SAP_500LB_Bomb_Mk5"] = 999999,
        ["weapons.bombs.CBU_103"] = 999999,
        ["weapons.bombs.CBU_105"] = 999999,
        ["weapons.bombs.CBU_52B"] = 999999,
        ["weapons.bombs.CBU_87"] = 999999,
        ["weapons.bombs.CBU_97"] = 999999,
        ["weapons.bombs.CBU_99"] = 999999,
        ["weapons.bombs.Durandal"] = 999999,
        ["weapons.bombs.FAB-250-M62"] = 999999,
        ["weapons.bombs.FAB-250M54"] = 999999,
        ["weapons.bombs.FAB-250M54TU"] = 999999,
        ["weapons.bombs.FAB-500M54"] = 999999,
        ["weapons.bombs.FAB-500M54TU"] = 999999,
        ["weapons.bombs.FAB-500SL"] = 999999,
        ["weapons.bombs.FAB-500TA"] = 999999,
        ["weapons.bombs.FAB_100"] = 999999,
        ["weapons.bombs.FAB_100M"] = 999999,
        ["weapons.bombs.FAB_100SV"] = 999999,
        ["weapons.bombs.FAB_1500"] = 999999,
        ["weapons.bombs.FAB_250"] = 999999,
        ["weapons.bombs.FAB_50"] = 999999,
        ["weapons.bombs.FAB_500"] = 999999,
        ["weapons.bombs.GBU_10"] = 999999,
        ["weapons.bombs.GBU_12"] = 999999,
        ["weapons.bombs.GBU_15_V_1_B"] = 999999,
        ["weapons.bombs.GBU_15_V_31_B"] = 999999,
        ["weapons.bombs.GBU_16"] = 999999,
        ["weapons.bombs.GBU_24"] = 999999,
        ["weapons.bombs.GBU_27"] = 999999,
        ["weapons.bombs.GBU_28"] = 999999,
        ["weapons.bombs.GBU_31"] = 999999,
        ["weapons.bombs.GBU_31_V_2B"] = 999999,
        ["weapons.bombs.GBU_31_V_3B"] = 999999,
        ["weapons.bombs.GBU_31_V_4B"] = 999999,
        ["weapons.bombs.GBU_32_V_2B"] = 999999,
        ["weapons.bombs.GBU_38"] = 999999,
        ["weapons.bombs.GBU_39"] = 999999,
        ["weapons.bombs.GBU_43"] = 999999,
        ["weapons.bombs.GBU_54_V_1B"] = 999999,
        ["weapons.bombs.GBU_8_B"] = 999999,
        ["weapons.bombs.HB_F4E_GBU15V1"] = 999999,
        ["weapons.bombs.HEBOMB"] = 999999,
        ["weapons.bombs.HEBOMBD"] = 999999,
        ["weapons.bombs.IAB-500"] = 999999,
        ["weapons.bombs.KAB_1500Kr"] = 999999,
        ["weapons.bombs.KAB_1500LG"] = 999999,
        ["weapons.bombs.KAB_1500T"] = 999999,
        ["weapons.bombs.KAB_500"] = 999999,
        ["weapons.bombs.KAB_500Kr"] = 999999,
        ["weapons.bombs.KAB_500S"] = 999999,
        ["weapons.bombs.LS_6_100"] = 999999,
        ["weapons.bombs.LUU_2B"] = 999999,
        ["weapons.bombs.LYSBOMB 11086"] = 999999,
        ["weapons.bombs.LYSBOMB 11087"] = 999999,
        ["weapons.bombs.LYSBOMB 11088"] = 999999,
        ["weapons.bombs.LYSBOMB 11089"] = 999999,
        ["weapons.bombs.MK-81SE"] = 999999,
        ["weapons.bombs.MK106"] = 999999,
        ["weapons.bombs.MK76"] = 999999,
        ["weapons.bombs.MK77mod0-WPN"] = 999999,
        ["weapons.bombs.MK77mod1-WPN"] = 999999,
        ["weapons.bombs.MK_82AIR"] = 999999,
        ["weapons.bombs.MK_82SNAKEYE"] = 999999,
        ["weapons.bombs.M_117"] = 999999,
        ["weapons.bombs.Mk_81"] = 999999,
        ["weapons.bombs.Mk_82"] = 999999,
        ["weapons.bombs.Mk_82Y"] = 999999,
        ["weapons.bombs.Mk_83"] = 999999,
        ["weapons.bombs.Mk_83AIR"] = 999999,
        ["weapons.bombs.Mk_83CT"] = 999999,
        ["weapons.bombs.Mk_84"] = 999999,
        ["weapons.bombs.Mk_84AIR_GP"] = 999999,
        ["weapons.bombs.Mk_84AIR_TP"] = 999999,
        ["weapons.bombs.ODAB-500PM"] = 999999,
        ["weapons.bombs.OFAB-100 Jupiter"] = 999999,
        ["weapons.bombs.OFAB-100-120TU"] = 999999,
        ["weapons.bombs.OH58D_Blue_Smoke_Grenade"] = 999999,
        ["weapons.bombs.OH58D_Green_Smoke_Grenade"] = 999999,
        ["weapons.bombs.OH58D_Red_Smoke_Grenade"] = 999999,
        ["weapons.bombs.OH58D_Violet_Smoke_Grenade"] = 999999,
        ["weapons.bombs.OH58D_White_Smoke_Grenade"] = 999999,
        ["weapons.bombs.OH58D_Yellow_Smoke_Grenade"] = 999999,
        ["weapons.bombs.P-50T"] = 999999,
        ["weapons.bombs.RBK_250"] = 999999,
        ["weapons.bombs.RBK_250_275_AO_1SCH"] = 999999,
        ["weapons.bombs.RBK_500AO"] = 999999,
        ["weapons.bombs.RBK_500U"] = 999999,
        ["weapons.bombs.RBK_500U_OAB_2_5RT"] = 999999,
        ["weapons.bombs.RN-24"] = 999999,
        ["weapons.bombs.RN-28"] = 999999,
        ["weapons.bombs.ROCKEYE"] = 999999,
        ["weapons.bombs.SAB_100MN"] = 999999,
        ["weapons.bombs.SAB_250_200"] = 999999,
        ["weapons.bombs.SAMP125LD"] = 999999,
        ["weapons.bombs.SAMP250HD"] = 999999,
        ["weapons.bombs.SAMP250LD"] = 999999,
        ["weapons.bombs.SAMP400HD"] = 999999,
        ["weapons.bombs.SAMP400LD"] = 999999,
        ["weapons.bombs.SC_250_T1_L2"] = 999999,
        ["weapons.bombs.SC_250_T3_J"] = 999999,
        ["weapons.bombs.SC_50"] = 999999,
        ["weapons.bombs.SC_500_J"] = 999999,
        ["weapons.bombs.SC_500_L2"] = 999999,
        ["weapons.bombs.SD_250_Stg"] = 999999,
        ["weapons.bombs.SD_500_A"] = 999999,
        ["weapons.bombs.Type_200A"] = 999999,
        ["weapons.containers.16c_hts_pod"] = 999999,
        ["weapons.containers.AAQ-28_LITENING"] = 999999,
        ["weapons.containers.AIM-9S"] = 999999,
        ["weapons.containers.ALQ-131"] = 999999,
        ["weapons.containers.ALQ-184"] = 999999,
        ["weapons.containers.ANAWW_13"] = 999999,
        ["weapons.containers.AN_AAQ_33"] = 999999,
        ["weapons.containers.AN_ASQ_228"] = 999999,
        ["weapons.containers.APK-9"] = 999999,
        ["weapons.containers.ASO-2"] = 999999,
        ["weapons.containers.AV8BNA_ALQ164"] = 999999,
        ["weapons.containers.BARAX"] = 999999,
        ["weapons.containers.BOZ-100"] = 999999,
        ["weapons.containers.BRD-4-250"] = 999999,
        ["weapons.containers.ETHER"] = 999999,
        ["weapons.containers.F-15E_AAQ-13_LANTIRN"] = 999999,
        ["weapons.containers.F-15E_AAQ-14_LANTIRN"] = 999999,
        ["weapons.containers.F-15E_AAQ-28_LITENING"] = 999999,
        ["weapons.containers.F-15E_AAQ-33_XR_ATP-SE"] = 999999,
        ["weapons.containers.F-15E_AXQ-14_DATALINK"] = 999999,
        ["weapons.containers.F-18-FLIR-POD"] = 999999,
        ["weapons.containers.F-18-LDT-POD"] = 999999,
        ["weapons.containers.FAS"] = 999999,
        ["weapons.containers.Fantasm"] = 999999,
        ["weapons.containers.GUV_VOG"] = 999999,
        ["weapons.containers.GUV_YakB_GSHP"] = 999999,
        ["weapons.containers.HB_ALE_40_0_0"] = 999999,
        ["weapons.containers.HB_ALE_40_0_120"] = 999999,
        ["weapons.containers.HB_ALE_40_15_90"] = 999999,
        ["weapons.containers.HB_ALE_40_30_0"] = 999999,
        ["weapons.containers.HB_ALE_40_30_60"] = 999999,
        ["weapons.containers.HB_F14_EXT_AN_APQ-167"] = 999999,
        ["weapons.containers.HB_F14_EXT_ECA"] = 999999,
        ["weapons.containers.HB_F14_EXT_TARPS"] = 999999,
        ["weapons.containers.HB_ORD_Pave_Spike"] = 999999,
        ["weapons.containers.HB_ORD_Pave_Spike_Fast"] = 999999,
        ["weapons.containers.HVAR_rocket"] = 999999,
        ["weapons.containers.IRDeflector"] = 999999,
        ["weapons.containers.KBpod"] = 999999,
        ["weapons.containers.KINGAL"] = 999999,
        ["weapons.containers.KORD_12_7"] = 999999,
        ["weapons.containers.KORD_12_7_MI24_L"] = 999999,
        ["weapons.containers.KORD_12_7_MI24_R"] = 999999,
        ["weapons.containers.LANTIRN"] = 999999,
        ["weapons.containers.LANTIRN-F14-TARGET"] = 999999,
        ["weapons.containers.M134_L"] = 999999,
        ["weapons.containers.M134_R"] = 999999,
        ["weapons.containers.M134_SIDE_L"] = 999999,
        ["weapons.containers.M134_SIDE_R"] = 999999,
        ["weapons.containers.M60_SIDE_L"] = 999999,
        ["weapons.containers.M60_SIDE_R"] = 999999,
        ["weapons.containers.MATRA-PHIMAT"] = 999999,
        ["weapons.containers.MB339_SMOKE-POD"] = 999999,
        ["weapons.containers.MB339_TravelPod"] = 999999,
        ["weapons.containers.MB339_Vinten"] = 999999,
        ["weapons.containers.MPS-410"] = 999999,
        ["weapons.containers.MXU-648"] = 999999,
        ["weapons.containers.OH58D_M3P_L100"] = 999999,
        ["weapons.containers.OH58D_M3P_L200"] = 999999,
        ["weapons.containers.OH58D_M3P_L300"] = 999999,
        ["weapons.containers.OH58D_M3P_L400"] = 999999,
        ["weapons.containers.OH58D_M3P_L500"] = 999999,
        ["weapons.containers.PAVETACK"] = 999999,
        ["weapons.containers.PKT_7_62"] = 999999,
        ["weapons.containers.R-73U"] = 999999,
        ["weapons.containers.SHPIL"] = 999999,
        ["weapons.containers.SKY_SHADOW"] = 999999,
        ["weapons.containers.SORBCIJA_L"] = 999999,
        ["weapons.containers.SORBCIJA_R"] = 999999,
        ["weapons.containers.SPS-141"] = 999999,
        ["weapons.containers.SPS-141-100"] = 999999,
        ["weapons.containers.Spear"] = 999999,
        ["weapons.containers.TANGAZH"] = 999999,
        ["weapons.containers.U22"] = 999999,
        ["weapons.containers.U22A"] = 999999,
        ["weapons.containers.aaq-28LEFT litening"] = 999999,
        ["weapons.containers.ah-64d_radar"] = 999999,
        ["weapons.containers.ais-pod-t50_r"] = 999999,
        ["weapons.containers.alq-184long"] = 999999,
        ["weapons.containers.dlpod_akg"] = 999999,
        ["weapons.containers.fullCargoSeats"] = 999999,
        ["weapons.containers.hvar_SmokeGenerator"] = 999999,
        ["weapons.containers.kg600"] = 999999,
        ["weapons.containers.leftSeat"] = 999999,
        ["weapons.containers.oh-58-brauning"] = 999999,
        ["weapons.containers.rearCargoSeats"] = 999999,
        ["weapons.containers.rightSeat"] = 999999,
        ["weapons.containers.sa342_dipole_antenna"] = 999999,
        ["weapons.containers.smoke_pod"] = 999999,
        ["weapons.containers.wmd7"] = 999999,
        ["weapons.containers.{05544F1A-C39C-466b-BC37-5BD1D52E57BB}"] = 999999,
        ["weapons.containers.{ADEN_GUNPOD}"] = 999999,
        ["weapons.containers.{AH-6_DOORS}"] = 999999,
        ["weapons.containers.{AH-6_Door}"] = 999999,
        ["weapons.containers.{AH-6_FN_HMP400}"] = 999999,
        ["weapons.containers.{AH-6_Gunners}"] = 999999,
        ["weapons.containers.{AH6_M134L}"] = 999999,
        ["weapons.containers.{AH6_M134R}"] = 999999,
        ["weapons.containers.{AKAN_NO_TRC}"] = 999999,
        ["weapons.containers.{AKAN}"] = 999999,
        ["weapons.containers.{AN-M3}"] = 999999,
        ["weapons.containers.{C-101-DEFA553}"] = 999999,
        ["weapons.containers.{C130-Cargo-Bay-M4}"] = 999999,
        ["weapons.containers.{C130-M18-Sidearm}"] = 999999,
        ["weapons.containers.{CC420_GUN_POD}"] = 999999,
        ["weapons.containers.{CE2_SMOKE_WHITE}"] = 999999,
        ["weapons.containers.{CH47_AFT_M240H}"] = 999999,
        ["weapons.containers.{CH47_AFT_M3M}"] = 999999,
        ["weapons.containers.{CH47_AFT_M60D}"] = 999999,
        ["weapons.containers.{CH47_PORT_M134D}"] = 999999,
        ["weapons.containers.{CH47_PORT_M240H}"] = 999999,
        ["weapons.containers.{CH47_PORT_M60D}"] = 999999,
        ["weapons.containers.{CH47_STBD_M134D}"] = 999999,
        ["weapons.containers.{CH47_STBD_M240H}"] = 999999,
        ["weapons.containers.{CH47_STBD_M60D}"] = 999999,
        ["weapons.containers.{CHAP_HMP400LC}"] = 999999,
        ["weapons.containers.{E92CBFE5-C153-11d8-9897-000476191836}"] = 999999,
        ["weapons.containers.{ECM_POD_L_175V}"] = 999999,
        ["weapons.containers.{EclairM_06}"] = 999999,
        ["weapons.containers.{EclairM_15}"] = 999999,
        ["weapons.containers.{EclairM_24}"] = 999999,
        ["weapons.containers.{EclairM_33}"] = 999999,
        ["weapons.containers.{EclairM_42}"] = 999999,
        ["weapons.containers.{EclairM_51}"] = 999999,
        ["weapons.containers.{EclairM_60}"] = 999999,
        ["weapons.containers.{Eclair}"] = 999999,
        ["weapons.containers.{F14-LANTIRN-TP}"] = 999999,
        ["weapons.containers.{F4U1D_SMOKE_WHITE}"] = 999999,
        ["weapons.containers.{FN_HMP400_100}"] = 999999,
        ["weapons.containers.{FN_HMP400_200}"] = 999999,
        ["weapons.containers.{FN_HMP400}"] = 999999,
        ["weapons.containers.{GAU_12_Equalizer_AP}"] = 999999,
        ["weapons.containers.{GAU_12_Equalizer_HE}"] = 999999,
        ["weapons.containers.{GAU_12_Equalizer}"] = 999999,
        ["weapons.containers.{GIAT_M621_APHE}"] = 999999,
        ["weapons.containers.{GIAT_M621_AP}"] = 999999,
        ["weapons.containers.{GIAT_M621_HEAP}"] = 999999,
        ["weapons.containers.{GIAT_M621_HE}"] = 999999,
        ["weapons.containers.{GIAT_M621_SAPHEI}"] = 999999,
        ["weapons.containers.{INV-SMOKE-BLUE}"] = 999999,
        ["weapons.containers.{INV-SMOKE-GREEN}"] = 999999,
        ["weapons.containers.{INV-SMOKE-ORANGE}"] = 999999,
        ["weapons.containers.{INV-SMOKE-WHITE}"] = 999999,
        ["weapons.containers.{INV-SMOKE-YELLOW}"] = 999999,
        ["weapons.containers.{M2KC_AAF}"] = 999999,
        ["weapons.containers.{M2KC_AGF}"] = 999999,
        ["weapons.containers.{MB339_ANM3_L}"] = 999999,
        ["weapons.containers.{MB339_ANM3_R}"] = 999999,
        ["weapons.containers.{MB339_DEFA553_L}"] = 999999,
        ["weapons.containers.{MB339_DEFA553_R}"] = 999999,
        ["weapons.containers.{MIG21_SMOKE_RED}"] = 999999,
        ["weapons.containers.{MIG21_SMOKE_WHITE}"] = 999999,
        ["weapons.containers.{Mk4 HIPEG}"] = 999999,
        ["weapons.containers.{PK-3}"] = 999999,
        ["weapons.containers.{RKL609_L}"] = 999999,
        ["weapons.containers.{RKL609_R}"] = 999999,
        ["weapons.containers.{SA342_M134_SIDE_R}"] = 999999,
        ["weapons.containers.{SMOKE_WHITE}"] = 999999,
        ["weapons.containers.{SUU_23_POD}"] = 999999,
        ["weapons.containers.{UH60L_M134_GUNNER}"] = 999999,
        ["weapons.containers.{UH60L_M2_GUNNER}"] = 999999,
        ["weapons.containers.{UH60L_M60_GUNNER}"] = 999999,
        ["weapons.containers.{UH60_GAU19_LEFT}"] = 999999,
        ["weapons.containers.{UH60_GAU19_RIGHT}"] = 999999,
        ["weapons.containers.{UH60_M134_LEFT}"] = 999999,
        ["weapons.containers.{UH60_M134_RIGHT}"] = 999999,
        ["weapons.containers.{UH60_M230_LEFT}"] = 999999,
        ["weapons.containers.{UH60_M230_RIGHT}"] = 999999,
        ["weapons.containers.{US_M10_SMOKE_TANK_BLUE}"] = 999999,
        ["weapons.containers.{US_M10_SMOKE_TANK_GREEN}"] = 999999,
        ["weapons.containers.{US_M10_SMOKE_TANK_ORANGE}"] = 999999,
        ["weapons.containers.{US_M10_SMOKE_TANK_RED}"] = 999999,
        ["weapons.containers.{US_M10_SMOKE_TANK_WHITE}"] = 999999,
        ["weapons.containers.{US_M10_SMOKE_TANK_YELLOW}"] = 999999,
        ["weapons.droptanks.1100L Tank"] = 999999,
        ["weapons.droptanks.1100L Tank Empty"] = 999999,
        ["weapons.droptanks.800L Tank"] = 999999,
        ["weapons.droptanks.800L Tank Empty"] = 999999,
        ["weapons.droptanks.AV8BNA_AERO1D"] = 999999,
        ["weapons.droptanks.AV8BNA_AERO1D_EMPTY"] = 999999,
        ["weapons.droptanks.C130J_Ext_Tank_L"] = 999999,
        ["weapons.droptanks.C130J_Ext_Tank_R"] = 999999,
        ["weapons.droptanks.CHAP_TigerUHT_fueltank"] = 999999,
        ["weapons.droptanks.DFT_150_GAL_A4E"] = 999999,
        ["weapons.droptanks.DFT_300_GAL_A4E"] = 999999,
        ["weapons.droptanks.DFT_300_GAL_A4E_LR"] = 999999,
        ["weapons.droptanks.DFT_400_GAL_A4E"] = 999999,
        ["weapons.droptanks.Drop tank 75gal"] = 999999,
        ["weapons.droptanks.Drop_Tank_300_Liter"] = 999999,
        ["weapons.droptanks.F-15E_Drop_Tank"] = 999999,
        ["weapons.droptanks.F-15E_Drop_Tank_Empty"] = 999999,
        ["weapons.droptanks.F-16-PTB-N2"] = 999999,
        ["weapons.droptanks.F15-PTB"] = 999999,
        ["weapons.droptanks.F4-BAK-C"] = 999999,
        ["weapons.droptanks.F4-BAK-L"] = 999999,
        ["weapons.droptanks.F4U-1D_Drop_Tank_Aux"] = 999999,
        ["weapons.droptanks.F4U-1D_Drop_Tank_Mk5"] = 999999,
        ["weapons.droptanks.F4U-1D_Drop_Tank_Mk6"] = 999999,
        ["weapons.droptanks.FPU_8A"] = 999999,
        ["weapons.droptanks.FT600"] = 999999,
        ["weapons.droptanks.FW-190_Fuel-Tank"] = 999999,
        ["weapons.droptanks.FuelTank_150L"] = 999999,
        ["weapons.droptanks.FuelTank_350L"] = 999999,
        ["weapons.droptanks.HB_A6E_AERO1D"] = 999999,
        ["weapons.droptanks.HB_A6E_AERO1D_EMPTY"] = 999999,
        ["weapons.droptanks.HB_A6E_D704"] = 999999,
        ["weapons.droptanks.HB_F-4E_EXT_Center_Fuel_Tank"] = 999999,
        ["weapons.droptanks.HB_F-4E_EXT_Center_Fuel_Tank_EMPTY"] = 999999,
        ["weapons.droptanks.HB_F-4E_EXT_WingTank"] = 999999,
        ["weapons.droptanks.HB_F-4E_EXT_WingTank_EMPTY"] = 999999,
        ["weapons.droptanks.HB_F-4E_EXT_WingTank_R"] = 999999,
        ["weapons.droptanks.HB_F-4E_EXT_WingTank_R_EMPTY"] = 999999,
        ["weapons.droptanks.HB_F14_EXT_DROPTANK"] = 999999,
        ["weapons.droptanks.HB_F14_EXT_DROPTANK_EMPTY"] = 999999,
        ["weapons.droptanks.HB_HIGH_PERFORMANCE_CENTERLINE_600_GAL"] = 999999,
        ["weapons.droptanks.LNS_VIG_XTANK"] = 999999,
        ["weapons.droptanks.M2000-PTB"] = 999999,
        ["weapons.droptanks.M2KC_02_RPL541"] = 999999,
        ["weapons.droptanks.M2KC_02_RPL541_EMPTY"] = 999999,
        ["weapons.droptanks.M2KC_08_RPL541"] = 999999,
        ["weapons.droptanks.M2KC_08_RPL541_EMPTY"] = 999999,
        ["weapons.droptanks.M2KC_RPL_522"] = 999999,
        ["weapons.droptanks.M2KC_RPL_522_EMPTY"] = 999999,
        ["weapons.droptanks.MB339_FT330"] = 999999,
        ["weapons.droptanks.MB339_TT320_L"] = 999999,
        ["weapons.droptanks.MB339_TT320_R"] = 999999,
        ["weapons.droptanks.MB339_TT500_L"] = 999999,
        ["weapons.droptanks.MB339_TT500_R"] = 999999,
        ["weapons.droptanks.MIG-23-PTB"] = 999999,
        ["weapons.droptanks.MIG-25-PTB"] = 999999,
        ["weapons.droptanks.Mosquito_Drop_Tank_100gal"] = 999999,
        ["weapons.droptanks.Mosquito_Drop_Tank_50gal"] = 999999,
        ["weapons.droptanks.PTB-1150"] = 999999,
        ["weapons.droptanks.PTB-1150-29"] = 999999,
        ["weapons.droptanks.PTB-150"] = 999999,
        ["weapons.droptanks.PTB-1500"] = 999999,
        ["weapons.droptanks.PTB-2000"] = 999999,
        ["weapons.droptanks.PTB-275"] = 999999,
        ["weapons.droptanks.PTB-3000"] = 999999,
        ["weapons.droptanks.PTB-450"] = 999999,
        ["weapons.droptanks.PTB-490-MIG21"] = 999999,
        ["weapons.droptanks.PTB-490C-MIG21"] = 999999,
        ["weapons.droptanks.PTB-800"] = 999999,
        ["weapons.droptanks.PTB-800-MIG21"] = 999999,
        ["weapons.droptanks.PTB300_MIG15"] = 999999,
        ["weapons.droptanks.PTB400_MIG15"] = 999999,
        ["weapons.droptanks.PTB400_MIG19"] = 999999,
        ["weapons.droptanks.PTB600_MIG15"] = 999999,
        ["weapons.droptanks.PTB760_MIG19"] = 999999,
        ["weapons.droptanks.PTB_1200_F1"] = 999999,
        ["weapons.droptanks.PTB_120_F86F35"] = 999999,
        ["weapons.droptanks.PTB_1500_MIG29A"] = 999999,
        ["weapons.droptanks.PTB_200_F86F35"] = 999999,
        ["weapons.droptanks.PTB_580G_F1"] = 999999,
        ["weapons.droptanks.S-3-PTB"] = 999999,
        ["weapons.droptanks.Spitfire_slipper_tank"] = 999999,
        ["weapons.droptanks.Spitfire_tank_1"] = 999999,
        ["weapons.droptanks.T-PTB"] = 999999,
        ["weapons.droptanks.ah6_auxtank"] = 999999,
        ["weapons.droptanks.droptank_108_gal"] = 999999,
        ["weapons.droptanks.droptank_110_gal"] = 999999,
        ["weapons.droptanks.droptank_150_gal"] = 999999,
        ["weapons.droptanks.f-18c-ptb"] = 999999,
        ["weapons.droptanks.fuel_tank_230"] = 999999,
        ["weapons.droptanks.fuel_tank_300gal"] = 999999,
        ["weapons.droptanks.fuel_tank_370gal"] = 999999,
        ["weapons.droptanks.fueltank200"] = 999999,
        ["weapons.droptanks.fueltank230"] = 999999,
        ["weapons.droptanks.fueltank450"] = 999999,
        ["weapons.droptanks.i16_eft"] = 999999,
        ["weapons.droptanks.oiltank"] = 999999,
        ["weapons.droptanks.{IAFS_ComboPak_100}"] = 999999,
        ["weapons.missiles.ADM_141A"] = 999999,
        ["weapons.missiles.ADM_141B"] = 999999,
        ["weapons.missiles.AGM_114"] = 999999,
        ["weapons.missiles.AGM_114K"] = 999999,
        ["weapons.missiles.AGM_119"] = 999999,
        ["weapons.missiles.AGM_122"] = 999999,
        ["weapons.missiles.AGM_12A"] = 999999,
        ["weapons.missiles.AGM_12B"] = 999999,
        ["weapons.missiles.AGM_12C_ED"] = 999999,
        ["weapons.missiles.AGM_130"] = 999999,
        ["weapons.missiles.AGM_154"] = 999999,
        ["weapons.missiles.AGM_154A"] = 999999,
        ["weapons.missiles.AGM_154B"] = 999999,
        ["weapons.missiles.AGM_45A"] = 999999,
        ["weapons.missiles.AGM_45B"] = 999999,
        ["weapons.missiles.AGM_65A"] = 999999,
        ["weapons.missiles.AGM_65B"] = 999999,
        ["weapons.missiles.AGM_65D"] = 999999,
        ["weapons.missiles.AGM_65E"] = 999999,
        ["weapons.missiles.AGM_65F"] = 999999,
        ["weapons.missiles.AGM_65G"] = 999999,
        ["weapons.missiles.AGM_65H"] = 999999,
        ["weapons.missiles.AGM_65K"] = 999999,
        ["weapons.missiles.AGM_65L"] = 999999,
        ["weapons.missiles.AGM_78A"] = 999999,
        ["weapons.missiles.AGM_78B"] = 999999,
        ["weapons.missiles.AGM_84A"] = 999999,
        ["weapons.missiles.AGM_84D"] = 999999,
        ["weapons.missiles.AGM_84E"] = 999999,
        ["weapons.missiles.AGM_84H"] = 999999,
        ["weapons.missiles.AGM_86"] = 999999,
        ["weapons.missiles.AGM_86C"] = 999999,
        ["weapons.missiles.AGM_88"] = 999999,
        ["weapons.missiles.AGR_20A"] = 999999,
        ["weapons.missiles.AGR_20_M282"] = 999999,
        ["weapons.missiles.AIM-7E"] = 999999,
        ["weapons.missiles.AIM-7E-2"] = 999999,
        ["weapons.missiles.AIM-7F"] = 999999,
        ["weapons.missiles.AIM-7MH"] = 999999,
        ["weapons.missiles.AIM-7P"] = 999999,
        ["weapons.missiles.AIM-9E"] = 999999,
        ["weapons.missiles.AIM-9J"] = 999999,
        ["weapons.missiles.AIM-9JULI"] = 999999,
        ["weapons.missiles.AIM-9L"] = 999999,
        ["weapons.missiles.AIM-9P"] = 999999,
        ["weapons.missiles.AIM-9P3"] = 999999,
        ["weapons.missiles.AIM-9P5"] = 999999,
        ["weapons.missiles.AIM_120"] = 999999,
        ["weapons.missiles.AIM_120C"] = 999999,
        ["weapons.missiles.AIM_54"] = 999999,
        ["weapons.missiles.AIM_54A_Mk47"] = 999999,
        ["weapons.missiles.AIM_54A_Mk60"] = 999999,
        ["weapons.missiles.AIM_54C_Mk47"] = 999999,
        ["weapons.missiles.AIM_54C_Mk60"] = 999999,
        ["weapons.missiles.AIM_7"] = 999999,
        ["weapons.missiles.AIM_9"] = 999999,
        ["weapons.missiles.AIM_9X"] = 999999,
        ["weapons.missiles.AKD-10"] = 999999,
        ["weapons.missiles.ALARM"] = 999999,
        ["weapons.missiles.AM39"] = 999999,
        ["weapons.missiles.ASM_N_2"] = 999999,
        ["weapons.missiles.AT_6"] = 999999,
        ["weapons.missiles.Ataka_9M120"] = 999999,
        ["weapons.missiles.Ataka_9M120F"] = 999999,
        ["weapons.missiles.Ataka_9M220"] = 999999,
        ["weapons.missiles.BK90_MJ1"] = 999999,
        ["weapons.missiles.BK90_MJ1_MJ2"] = 999999,
        ["weapons.missiles.BK90_MJ2"] = 999999,
        ["weapons.missiles.BRM-1_90MM"] = 999999,
        ["weapons.missiles.CATM_65K"] = 999999,
        ["weapons.missiles.CATM_9M"] = 999999,
        ["weapons.missiles.CHAP_AIM92"] = 999999,
        ["weapons.missiles.CM-400AKG"] = 999999,
        ["weapons.missiles.CM-802AKG"] = 999999,
        ["weapons.missiles.CM_802AKG"] = 999999,
        ["weapons.missiles.C_701IR"] = 999999,
        ["weapons.missiles.C_701T"] = 999999,
        ["weapons.missiles.C_802AK"] = 999999,
        ["weapons.missiles.DWS39_MJ1"] = 999999,
        ["weapons.missiles.DWS39_MJ1_MJ2"] = 999999,
        ["weapons.missiles.DWS39_MJ2"] = 999999,
        ["weapons.missiles.GAR-8"] = 999999,
        ["weapons.missiles.GB-6"] = 999999,
        ["weapons.missiles.GB-6-HE"] = 999999,
        ["weapons.missiles.GB-6-SFW"] = 999999,
        ["weapons.missiles.HB-AIM-7E"] = 999999,
        ["weapons.missiles.HB-AIM-7E-2"] = 999999,
        ["weapons.missiles.HB_AGM_78"] = 999999,
        ["weapons.missiles.HJ-12"] = 999999,
        ["weapons.missiles.HOT3_MBDA"] = 999999,
        ["weapons.missiles.Igla_1E"] = 999999,
        ["weapons.missiles.KD_20"] = 999999,
        ["weapons.missiles.KD_63"] = 999999,
        ["weapons.missiles.KD_63B"] = 999999,
        ["weapons.missiles.Kh-66_Grom"] = 999999,
        ["weapons.missiles.Kh25MP_PRGS1VP"] = 999999,
        ["weapons.missiles.Kormoran"] = 999999,
        ["weapons.missiles.LD-10"] = 999999,
        ["weapons.missiles.LS_6"] = 999999,
        ["weapons.missiles.LS_6_500"] = 999999,
        ["weapons.missiles.MICA_R"] = 999999,
        ["weapons.missiles.MICA_T"] = 999999,
        ["weapons.missiles.MMagicII"] = 999999,
        ["weapons.missiles.Matra Super 530D"] = 999999,
        ["weapons.missiles.Mistral"] = 999999,
        ["weapons.missiles.OH58D_FIM_92"] = 999999,
        ["weapons.missiles.PL-12"] = 999999,
        ["weapons.missiles.PL-5EII"] = 999999,
        ["weapons.missiles.PL-8A"] = 999999,
        ["weapons.missiles.PL-8B"] = 999999,
        ["weapons.missiles.P_24R"] = 999999,
        ["weapons.missiles.P_24T"] = 999999,
        ["weapons.missiles.P_27P"] = 999999,
        ["weapons.missiles.P_27PE"] = 999999,
        ["weapons.missiles.P_27T"] = 999999,
        ["weapons.missiles.P_27TE"] = 999999,
        ["weapons.missiles.P_33E"] = 999999,
        ["weapons.missiles.P_40R"] = 999999,
        ["weapons.missiles.P_40T"] = 999999,
        ["weapons.missiles.P_60"] = 999999,
        ["weapons.missiles.P_73"] = 999999,
        ["weapons.missiles.P_77"] = 999999,
        ["weapons.missiles.R-13M"] = 999999,
        ["weapons.missiles.R-13M1"] = 999999,
        ["weapons.missiles.R-3R"] = 999999,
        ["weapons.missiles.R-3S"] = 999999,
        ["weapons.missiles.R-55"] = 999999,
        ["weapons.missiles.R-60"] = 999999,
        ["weapons.missiles.RB75"] = 999999,
        ["weapons.missiles.RB75B"] = 999999,
        ["weapons.missiles.RB75T"] = 999999,
        ["weapons.missiles.RS2US"] = 999999,
        ["weapons.missiles.R_530F_EM"] = 999999,
        ["weapons.missiles.R_530F_IR"] = 999999,
        ["weapons.missiles.R_550"] = 999999,
        ["weapons.missiles.R_550_M1"] = 999999,
        ["weapons.missiles.Rb 04E"] = 999999,
        ["weapons.missiles.Rb 04E (for A.I.)"] = 999999,
        ["weapons.missiles.Rb 05A"] = 999999,
        ["weapons.missiles.Rb 15F"] = 999999,
        ["weapons.missiles.Rb 15F (for A.I.)"] = 999999,
        ["weapons.missiles.Rb 24"] = 999999,
        ["weapons.missiles.Rb 24J"] = 999999,
        ["weapons.missiles.Rb 74"] = 999999,
        ["weapons.missiles.Rb_04"] = 999999,
        ["weapons.missiles.SD-10"] = 999999,
        ["weapons.missiles.SPIKE_ER"] = 999999,
        ["weapons.missiles.SPIKE_ER2"] = 999999,
        ["weapons.missiles.S_25L"] = 999999,
        ["weapons.missiles.Sea_Eagle"] = 999999,
        ["weapons.missiles.Super_530D"] = 999999,
        ["weapons.missiles.Super_530F"] = 999999,
        ["weapons.missiles.TGM_65D"] = 999999,
        ["weapons.missiles.TGM_65G"] = 999999,
        ["weapons.missiles.TGM_65H"] = 999999,
        ["weapons.missiles.TOW"] = 999999,
        ["weapons.missiles.Vikhr_M"] = 999999,
        ["weapons.missiles.X_101"] = 999999,
        ["weapons.missiles.X_22"] = 999999,
        ["weapons.missiles.X_25ML"] = 999999,
        ["weapons.missiles.X_25MP"] = 999999,
        ["weapons.missiles.X_25MR"] = 999999,
        ["weapons.missiles.X_28"] = 999999,
        ["weapons.missiles.X_29L"] = 999999,
        ["weapons.missiles.X_29T"] = 999999,
        ["weapons.missiles.X_31A"] = 999999,
        ["weapons.missiles.X_31P"] = 999999,
        ["weapons.missiles.X_35"] = 999999,
        ["weapons.missiles.X_41"] = 999999,
        ["weapons.missiles.X_555"] = 999999,
        ["weapons.missiles.X_58"] = 999999,
        ["weapons.missiles.X_59M"] = 999999,
        ["weapons.missiles.X_65"] = 999999,
        ["weapons.missiles.YJ-12"] = 999999,
        ["weapons.missiles.YJ-83K"] = 999999,
        ["weapons.nurs.ARAKM70BAP"] = 999999,
        ["weapons.nurs.ARAKM70BAPPX"] = 999999,
        ["weapons.nurs.ARAKM70BHE"] = 999999,
        ["weapons.nurs.ARF8M3API"] = 999999,
        ["weapons.nurs.ARF8M3HEI"] = 999999,
        ["weapons.nurs.ARF8M3TPSM"] = 999999,
        ["weapons.nurs.British_AP_25LBNo1_3INCHNo1"] = 999999,
        ["weapons.nurs.British_HE_60LBFNo1_3INCHNo1"] = 999999,
        ["weapons.nurs.British_HE_60LBSAPNo2_3INCHNo1"] = 999999,
        ["weapons.nurs.C_13"] = 999999,
        ["weapons.nurs.C_24"] = 999999,
        ["weapons.nurs.C_25"] = 999999,
        ["weapons.nurs.C_5"] = 999999,
        ["weapons.nurs.C_8"] = 999999,
        ["weapons.nurs.C_8CM"] = 999999,
        ["weapons.nurs.C_8CM_BU"] = 999999,
        ["weapons.nurs.C_8CM_GN"] = 999999,
        ["weapons.nurs.C_8CM_RD"] = 999999,
        ["weapons.nurs.C_8CM_VT"] = 999999,
        ["weapons.nurs.C_8CM_WH"] = 999999,
        ["weapons.nurs.C_8CM_YE"] = 999999,
        ["weapons.nurs.C_8OFP2"] = 999999,
        ["weapons.nurs.C_8OM"] = 999999,
        ["weapons.nurs.FFAR M156 WP"] = 999999,
        ["weapons.nurs.FFAR Mk1 HE"] = 999999,
        ["weapons.nurs.FFAR Mk5 HEAT"] = 999999,
        ["weapons.nurs.FFAR_Mk61"] = 999999,
        ["weapons.nurs.HVAR"] = 999999,
        ["weapons.nurs.HVAR USN Mk28 Mod4"] = 999999,
        ["weapons.nurs.HYDRA_70_M151"] = 999999,
        ["weapons.nurs.HYDRA_70_M151_M433"] = 999999,
        ["weapons.nurs.HYDRA_70_M156"] = 999999,
        ["weapons.nurs.HYDRA_70_M229"] = 999999,
        ["weapons.nurs.HYDRA_70_M257"] = 999999,
        ["weapons.nurs.HYDRA_70_M259"] = 999999,
        ["weapons.nurs.HYDRA_70_M274"] = 999999,
        ["weapons.nurs.HYDRA_70_M282"] = 999999,
        ["weapons.nurs.HYDRA_70_MK1"] = 999999,
        ["weapons.nurs.HYDRA_70_MK5"] = 999999,
        ["weapons.nurs.HYDRA_70_MK61"] = 999999,
        ["weapons.nurs.HYDRA_70_WTU1B"] = 999999,
        ["weapons.nurs.M8rocket"] = 999999,
        ["weapons.nurs.R4M"] = 999999,
        ["weapons.nurs.RS-82"] = 999999,
        ["weapons.nurs.Rkt_90-1_HE"] = 999999,
        ["weapons.nurs.S-24A"] = 999999,
        ["weapons.nurs.S-24B"] = 999999,
        ["weapons.nurs.S-25-O"] = 999999,
        ["weapons.nurs.S-5M"] = 999999,
        ["weapons.nurs.S5M1_HEFRAG_FFAR"] = 999999,
        ["weapons.nurs.S5MO_HEFRAG_FFAR"] = 999999,
        ["weapons.nurs.SNEB_TYPE250_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE251_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE251_H1"] = 999999,
        ["weapons.nurs.SNEB_TYPE252_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE252_H1"] = 999999,
        ["weapons.nurs.SNEB_TYPE253_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE253_H1"] = 999999,
        ["weapons.nurs.SNEB_TYPE254_F1B_GREEN"] = 999999,
        ["weapons.nurs.SNEB_TYPE254_F1B_RED"] = 999999,
        ["weapons.nurs.SNEB_TYPE254_F1B_YELLOW"] = 999999,
        ["weapons.nurs.SNEB_TYPE254_H1_GREEN"] = 999999,
        ["weapons.nurs.SNEB_TYPE254_H1_RED"] = 999999,
        ["weapons.nurs.SNEB_TYPE254_H1_YELLOW"] = 999999,
        ["weapons.nurs.SNEB_TYPE256_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE256_H1"] = 999999,
        ["weapons.nurs.SNEB_TYPE257_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE257_H1"] = 999999,
        ["weapons.nurs.SNEB_TYPE259E_F1B"] = 999999,
        ["weapons.nurs.SNEB_TYPE259E_H1"] = 999999,
        ["weapons.nurs.S_5KP"] = 999999,
        ["weapons.nurs.S_5M"] = 999999,
        ["weapons.nurs.Tiny Tim"] = 999999,
        ["weapons.nurs.WGr21"] = 999999,
        ["weapons.nurs.Zuni_127"] = 999999
            }
        }
    }
}

----------------------------------------------------------------
-- ESTADO
----------------------------------------------------------------
CTDP.STATE = CTDP.STATE or {
    started = false,
    injecting = false,
    writeEnabled = false,
    injectEndsAt = 0,
    lastInject = -9999,
    lastExport = -9999,

    doc = nil,
    dirty = false,

    unitToCategory = {},
    unitToCrate = {},

    byGroupName = {},
    byUnitName = {},
    byStaticName = {},
    byFarpName = {},

    passiveModuleInstalled = false,
    passivePendingGroups = {},
    passiveSeenGroups = {},
    injectedGroupsThisSession = {},
    injectedFobsThisSession = {},
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg, seconds)
    env.info("[CTLD_PERSIST] " .. tostring(msg))
    if CTDP.CONFIG.DEBUG then
        trigger.action.outText("[CTLD_PERSIST] " .. tostring(msg), seconds or 8)
    end
end

local function warn(msg)
    env.info("[CTLD_PERSIST] " .. tostring(msg))
end

local function now()
    return timer.getTime()
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function deepCopy(tbl)
    if mist and mist.utils and mist.utils.deepCopy then
        return mist.utils.deepCopy(tbl)
    end
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = deepCopy(v) end
    return out
end

local function round(n, d)
    n = tonumber(n) or 0
    local m = 10 ^ (d or 0)
    return math.floor((n * m) + 0.5) / m
end

local function lowerText(v)
    return string.lower(tostring(v or ""))
end

local function sortedKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function insertUnique(list, value)
    if not list or not value or value == "" then return false end
    for _, current in ipairs(list) do
        if current == value then return false end
    end
    list[#list + 1] = value
    return true
end

local function removeFromList(list, value)
    if not list or not value then return end
    local i = 1
    while i <= #list do
        if list[i] == value then table.remove(list, i) else i = i + 1 end
    end
end

local function ensureTable(parent, key)
    parent[key] = parent[key] or {}
    return parent[key]
end

----------------------------------------------------------------
-- JSON / FILE
----------------------------------------------------------------
local function safeReadFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local txt = f:read("*a")
    f:close()
    return txt
end

local function ensureDirectoryForFile(path)
    if not lfs or not lfs.mkdir or not path or path == "" then return false end
    local parts = {}
    for part in string.gmatch(path, "[^\\/]+") do parts[#parts + 1] = part end
    if #parts <= 1 then return false end
    table.remove(parts, #parts)

    local sep = path:find("/") and "/" or "\\"
    local current = ""
    if path:match("^%a:[\\/]") then
        current = path:sub(1, 3)
    elseif path:sub(1, 1) == "/" then
        current = "/"
    end

    for _, part in ipairs(parts) do
        if current == "" or current:sub(-1) == sep then
            current = current .. part
        else
            current = current .. sep .. part
        end
        lfs.mkdir(current)
    end
    return true
end

local function safeWriteFile(path, txt)
    ensureDirectoryForFile(path)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(txt or "")
    if f.flush then f:flush() end
    f:close()
    return true
end

local function decodeJson(txt)
    if not txt or txt == "" then return nil, "archivo vacio" end
    if not net or not net.json2lua then return nil, "net.json2lua no disponible" end
    local ok, data = pcall(net.json2lua, txt)
    if not ok then return nil, data end
    if type(data) ~= "table" then return nil, "json no devolvio tabla" end
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
    if type(tbl) ~= "table" then return false end
    local count, maxIndex = 0, 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then return false end
        count = count + 1
        if k > maxIndex then maxIndex = k end
    end
    return count == maxIndex
end

local function encodeJsonValue(value, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    local t = type(value)

    if t == "nil" then return "null" end
    if t == "boolean" then return value and "true" or "false" end
    if t == "number" then return tostring(value) end
    if t == "string" then return "\"" .. jsonEscape(value) .. "\"" end
    if t ~= "table" then return "\"" .. jsonEscape(tostring(value)) .. "\"" end
    if next(value) == nil then return isArray(value) and "[]" or "{}" end

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
        lines[#lines + 1] = string.rep(" ", indent + 2) .. "\"" .. jsonEscape(tostring(key)) .. "\": " .. encodeJsonValue(value[key], indent + 2) .. comma
    end
    lines[#lines + 1] = pad .. "}"
    return table.concat(lines, "\n")
end

----------------------------------------------------------------
-- DCS OBJECT HELPERS
----------------------------------------------------------------
local function groupExistsByName(groupName)
    if not groupName or groupName == "" then return nil end
    local grp = Group.getByName(groupName)
    if not grp then return nil end
    local ok, exists = pcall(function() return grp:isExist() end)
    if ok and exists then return grp end
    return nil
end

local function staticExistsByName(staticName)
    if not staticName or staticName == "" then return nil end
    local st = StaticObject.getByName(staticName)
    if not st then return nil end
    local ok, exists = pcall(function() return st:isExist() end)
    if ok and exists then return st end
    return nil
end

local function unitExistsByName(unitName)
    if not unitName or unitName == "" then return nil end
    local u = Unit.getByName(unitName)
    if not u then return nil end
    local ok, exists = pcall(function() return u:isExist() end)
    if ok and exists then return u end
    return nil
end

local function objectPoint(obj)
    if not obj then return nil end
    if obj.getPoint then
        local ok, p = pcall(function() return obj:getPoint() end)
        if ok and p then return p end
    end
    if obj.getPosition then
        local ok, pos = pcall(function() return obj:getPosition() end)
        if ok and pos and pos.p then return pos.p end
    end
    return nil
end

local function getHeadingFromObject(obj)
    if not obj or not obj.getPosition then return 0 end
    local ok, pos = pcall(function() return obj:getPosition() end)
    if not ok or not pos or not pos.x then return 0 end
    return math.atan2(pos.x.z or 0, pos.x.x or 0)
end

local function getCoalitionFromCountry(countryId)
    if not countryId then return nil end
    local ok, side = pcall(function() return coalition.getCountryCoalition(countryId) end)
    if ok then return side end
    return nil
end

local function countryForCoalition(side)
    side = tonumber(side) or coalition.side.BLUE
    if side == coalition.side.RED then return country.id.RUSSIA end
    return country.id.USA
end

local function groupHasAliveUnits(groupName)
    local grp = groupExistsByName(groupName)
    if not grp then return false end
    local ok, units = pcall(function() return grp:getUnits() end)
    if not ok or not units then return false end
    for _, unit in ipairs(units) do
        if unit and unit:isExist() then
            local okLife, life = pcall(function() return unit:getLife() end)
            if okLife and (tonumber(life) or 0) > 0 then return true end
        end
    end
    return false
end

----------------------------------------------------------------
-- DOCUMENTO
----------------------------------------------------------------
local function defaultDoc()
    return {
        version = "2.8.0_PASSIVE_SAFE_FARP_DRONE",
        updatedBy = "DCS",
        updatedAt = now(),
        counters = {
            nextDeploymentId = 1,
            nextFobId = 1,
            nextFarpIndex = 1,
        },
        deployments = {},
        fobs = {},
    }
end

local function normalizeDoc(doc)
    if type(doc) ~= "table" then doc = defaultDoc() end
    doc.version = doc.version or "2.8.0_PASSIVE_SAFE_FARP_DRONE"
    doc.updatedBy = "DCS"
    doc.updatedAt = tonumber(doc.updatedAt) or now()
    doc.counters = doc.counters or {}
    doc.counters.nextDeploymentId = tonumber(doc.counters.nextDeploymentId) or 1
    doc.counters.nextFobId = tonumber(doc.counters.nextFobId) or 1
    doc.counters.nextFarpIndex = tonumber(doc.counters.nextFarpIndex) or 1
    doc.deployments = doc.deployments or {}
    doc.fobs = doc.fobs or {}
    return doc
end

local function nextDeploymentId()
    CTDP.STATE.doc = normalizeDoc(CTDP.STATE.doc)
    local id = "DEP_" .. string.format("%06d", CTDP.STATE.doc.counters.nextDeploymentId)
    CTDP.STATE.doc.counters.nextDeploymentId = CTDP.STATE.doc.counters.nextDeploymentId + 1
    return id
end

local function nextFobId()
    CTDP.STATE.doc = normalizeDoc(CTDP.STATE.doc)
    local id = "FOB_" .. string.format("%06d", CTDP.STATE.doc.counters.nextFobId)
    CTDP.STATE.doc.counters.nextFobId = CTDP.STATE.doc.counters.nextFobId + 1
    return id
end

local function farpNameForIndex(index)
    local list = CTDP.CONFIG.FARP.NAME_LIST or {}
    index = tonumber(index) or 1
    if #list == 0 then return "FARP " .. tostring(index) end
    local baseIndex = ((index - 1) % #list) + 1
    local cycle = math.floor((index - 1) / #list) + 1
    local name = tostring(list[baseIndex]) .. " FARP"
    if cycle > 1 then name = name .. " " .. tostring(cycle) end
    return name
end

local function writeState(force)
    if not CTDP.STATE.doc then return false end
    if not force and not CTDP.STATE.dirty then return true end
    CTDP.STATE.doc.updatedBy = "DCS"
    CTDP.STATE.doc.updatedAt = now()
    local ok = safeWriteFile(CTDP.CONFIG.FILE_PATH, encodeJsonValue(CTDP.STATE.doc, 0))
    if ok then
        CTDP.STATE.dirty = false
        return true
    end
    warn("No se pudo escribir JSON: " .. tostring(CTDP.CONFIG.FILE_PATH))
    return false
end

local function loadState()
    local txt = safeReadFile(CTDP.CONFIG.FILE_PATH)
    if not txt then
        CTDP.STATE.doc = normalizeDoc(nil)
        CTDP.STATE.dirty = true
        writeState(true)
        log("JSON nuevo creado: " .. tostring(CTDP.CONFIG.FILE_PATH), 8)
        return
    end

    local doc, err = decodeJson(txt)
    if not doc then
        warn("JSON invalido. Se crea uno nuevo. Error: " .. tostring(err))
        CTDP.STATE.doc = normalizeDoc(nil)
        CTDP.STATE.dirty = true
        writeState(true)
        return
    end

    CTDP.STATE.doc = normalizeDoc(doc)
    log("JSON cargado: " .. tostring(CTDP.CONFIG.FILE_PATH), 8)
end

----------------------------------------------------------------
-- INDEXES
----------------------------------------------------------------
local function clearIndexes()
    CTDP.STATE.byGroupName = {}
    CTDP.STATE.byUnitName = {}
    CTDP.STATE.byStaticName = {}
    CTDP.STATE.byFarpName = {}
end

local function indexDeployment(dep)
    if not dep or not dep.id then return end
    if dep.activeGroupName then CTDP.STATE.byGroupName[dep.activeGroupName] = dep.id end
    if dep.runtimeGroupName then CTDP.STATE.byGroupName[dep.runtimeGroupName] = dep.id end
    if dep.originalGroupName then CTDP.STATE.byGroupName[dep.originalGroupName] = dep.id end
    if dep.names then
        for _, g in ipairs(dep.names.groups or {}) do CTDP.STATE.byGroupName[g] = dep.id end
        for _, u in ipairs(dep.names.units or {}) do CTDP.STATE.byUnitName[u] = dep.id end
    end
end

local function indexFob(fob)
    if not fob or not fob.id then return end
    if fob.staticName then CTDP.STATE.byStaticName[fob.staticName] = fob.id end
    if fob.runtimeStaticName then CTDP.STATE.byStaticName[fob.runtimeStaticName] = fob.id end
    if fob.farpName then CTDP.STATE.byFarpName[fob.farpName] = fob.id end
end

local function rebuildIndexes()
    clearIndexes()
    for _, dep in pairs((CTDP.STATE.doc and CTDP.STATE.doc.deployments) or {}) do indexDeployment(dep) end
    for _, fob in pairs((CTDP.STATE.doc and CTDP.STATE.doc.fobs) or {}) do indexFob(fob) end
end

----------------------------------------------------------------
-- CTLD TYPE INDEX
----------------------------------------------------------------
local function registerCrateUnit(categoryName, crate)
    if type(crate) ~= "table" then return end
    local unitType = crate.unit or crate.type or crate.unitType
    if unitType then
        CTDP.STATE.unitToCategory[tostring(unitType)] = tostring(categoryName or "CTLD")
        CTDP.STATE.unitToCrate[tostring(unitType)] = crate
    end
    if type(crate.units) == "table" then
        for _, unit in ipairs(crate.units) do
            if type(unit) == "string" then
                CTDP.STATE.unitToCategory[unit] = tostring(categoryName or "CTLD")
                CTDP.STATE.unitToCrate[unit] = crate
            elseif type(unit) == "table" and unit.type then
                CTDP.STATE.unitToCategory[tostring(unit.type)] = tostring(categoryName or "CTLD")
                CTDP.STATE.unitToCrate[tostring(unit.type)] = crate
            end
        end
    end
end

local function walkCrates(categoryName, node)
    if type(node) ~= "table" then return end
    if node.unit or node.type or node.units then registerCrateUnit(categoryName, node) end
    for k, v in pairs(node) do
        if type(v) == "table" then
            local nextCategory = categoryName
            if type(k) == "string" and not v.unit and not v.type then nextCategory = k end
            walkCrates(nextCategory, v)
        end
    end
end

local function buildCtldIndexes()
    CTDP.STATE.unitToCategory = {}
    CTDP.STATE.unitToCrate = {}

    if ctld.spawnableCrates then walkCrates("CTLD", ctld.spawnableCrates) end

    CTDP.STATE.unitToCategory["Hummer"] = CTDP.STATE.unitToCategory["Hummer"] or "JTAC"
    CTDP.STATE.unitToCategory["SKP-11"] = CTDP.STATE.unitToCategory["SKP-11"] or "JTAC"
    CTDP.STATE.unitToCategory["MQ-9 Reaper"] = CTDP.STATE.unitToCategory["MQ-9 Reaper"] or "Drones"
    CTDP.STATE.unitToCategory["RQ-1A Predator"] = CTDP.STATE.unitToCategory["RQ-1A Predator"] or "Drones"

    log("Indice CTLD construido. Tipos: " .. tostring(#sortedKeys(CTDP.STATE.unitToCategory)), 6)
end

----------------------------------------------------------------
-- DRONES / JTAC
----------------------------------------------------------------
local function isDroneType(typeName)
    typeName = tostring(typeName or "")
    if CTDP.CONFIG.DRONES.TYPES[typeName] then return true end
    local l = lowerText(typeName)
    if l:find("mq%-9") or l:find("reaper", 1, true) then return true end
    if l:find("rq%-1") or l:find("predator", 1, true) then return true end
    return false
end

local function isJtacType(typeName)
    typeName = tostring(typeName or "")
    if isDroneType(typeName) then return true end
    if typeName == "Hummer" or typeName == "SKP-11" then return true end
    if lowerText(typeName):find("jtac", 1, true) then return true end
    return false
end

local function groupContainsPredicate(groupName, predicate)
    local grp = groupExistsByName(groupName)
    if not grp then return false end
    local ok, units = pcall(function() return grp:getUnits() end)
    if not ok or not units then return false end
    for _, unit in ipairs(units) do
        if unit and unit:isExist() then
            local okType, typeName = pcall(function() return unit:getTypeName() end)
            if okType and predicate(typeName) then return true end
        end
    end
    return false
end

local function groupContainsDrone(groupName)
    return groupContainsPredicate(groupName, isDroneType)
end

local function groupContainsJtac(groupName)
    return groupContainsPredicate(groupName, isJtacType)
end

local function protectControllerAsDrone(controller)
    if not controller then return end
    pcall(function() controller:setCommand({ id = "SetImmortal", params = { value = true } }) end)
    pcall(function() controller:setCommand({ id = "SetInvisible", params = { value = true } }) end)
    pcall(function() controller:setCommand({ id = "SetUnlimitedFuel", params = { value = true } }) end)
    pcall(function() controller:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_HOLD) end)
    pcall(function() controller:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.NO_REACTION) end)
end

local function pushDroneOrbitTask(groupName)
    local grp = groupExistsByName(groupName)
    if not grp then return false end
    local okCtrl, ctrl = pcall(function() return grp:getController() end)
    if not okCtrl or not ctrl then return false end

    local task = {
        id = "ComboTask",
        params = {
            tasks = {
                [1] = {
                    enabled = true,
                    auto = false,
                    id = "WrappedAction",
                    number = 1,
                    params = {
                        action = {
                            id = "Orbit",
                            params = {
                                pattern = CTDP.CONFIG.DRONES.ORBIT_PATTERN or "Circle",
                                speed = tonumber(CTDP.CONFIG.DRONES.ORBIT_SPEED) or 80,
                                altitude = tonumber(CTDP.CONFIG.DRONES.ORBIT_ALT) or 3500,
                            }
                        }
                    }
                },
                [2] = {
                    enabled = true,
                    auto = false,
                    id = "WrappedAction",
                    number = 2,
                    params = {
                        action = {
                            id = "EPLRS",
                            params = { value = true, groupId = 1 }
                        }
                    }
                }
            }
        }
    }

    pcall(function() ctrl:setTask(task) end)
    return true
end

local function applyDroneProtectionNow(groupName)
    if not groupName or groupName == "" then return false end
    if not groupContainsDrone(groupName) then return false end

    local grp = groupExistsByName(groupName)
    if not grp then return false end

    local okCtrl, ctrl = pcall(function() return grp:getController() end)
    if okCtrl and ctrl then protectControllerAsDrone(ctrl) end

    local okUnits, units = pcall(function() return grp:getUnits() end)
    if okUnits and units then
        for _, unit in ipairs(units) do
            if unit and unit:isExist() and unit.getController then
                local okUCtrl, uCtrl = pcall(function() return unit:getController() end)
                if okUCtrl and uCtrl then protectControllerAsDrone(uCtrl) end
            end
        end
    end

    pushDroneOrbitTask(groupName)

    if ctld and type(ctld.JTACStart) == "function" then
        local code = tonumber(CTDP.CONFIG.DRONES.DEFAULT_CODE) or 1688
        pcall(function() ctld.JTACStart(groupName, code) end)
    end

    log("Dron protegido/JTAC iniciado: " .. tostring(groupName), 6)
    return true
end

local function scheduleDroneProtection(groupName)
    if not groupName or groupName == "" then return end
    local retries = tonumber(CTDP.CONFIG.DRONES.PROTECTION_RETRIES) or 12
    local interval = tonumber(CTDP.CONFIG.DRONES.PROTECTION_INTERVAL) or 1
    local count = 0

    local function tick()
        count = count + 1
        applyDroneProtectionNow(groupName)
        if count < retries then return timer.getTime() + interval end
        return nil
    end

    timer.scheduleFunction(tick, nil, timer.getTime() + interval)
end

local function buildDroneRoute(x, z)
    local alt = tonumber(CTDP.CONFIG.DRONES.ORBIT_ALT) or 3500
    local speed = tonumber(CTDP.CONFIG.DRONES.ORBIT_SPEED) or 80
    return {
        points = {
            [1] = {
                x = x,
                y = z,
                alt = alt,
                alt_type = "BARO",
                speed = speed,
                action = "Turning Point",
                type = "Turning Point",
                ETA = 0,
                ETA_locked = false,
                speed_locked = true,
                task = {
                    id = "ComboTask",
                    params = {
                        tasks = {
                            [1] = {
                                enabled = true,
                                auto = false,
                                id = "WrappedAction",
                                number = 1,
                                params = {
                                    action = {
                                        id = "Orbit",
                                        params = {
                                            pattern = CTDP.CONFIG.DRONES.ORBIT_PATTERN or "Circle",
                                            speed = speed,
                                            altitude = alt,
                                        }
                                    }
                                }
                            },
                            [2] = {
                                enabled = true,
                                auto = false,
                                id = "WrappedAction",
                                number = 2,
                                params = {
                                    action = {
                                        id = "EPLRS",
                                        params = { value = true, groupId = 1 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
end

----------------------------------------------------------------
-- CAPTURA DE GRUPOS
----------------------------------------------------------------
local function determineCategory(types)
    for _, typeName in ipairs(types or {}) do
        if CTDP.STATE.unitToCategory[typeName] then return CTDP.STATE.unitToCategory[typeName] end
    end
    return "CTLD"
end

local function shouldSaveDeployment(types, category)
    for _, typeName in ipairs(types or {}) do
        if CTDP.CONFIG.IGNORE_UNITS and CTDP.CONFIG.IGNORE_UNITS[typeName] then return false end
    end

    local mode = tostring(CTDP.CONFIG.SAVE_MODE or "all")
    if mode == "all" then return true end
    if mode == "categories" then return CTDP.CONFIG.SAVE_CATEGORIES and CTDP.CONFIG.SAVE_CATEGORIES[category] == true end
    if mode == "units" then
        for _, typeName in ipairs(types or {}) do
            if CTDP.CONFIG.SAVE_UNITS and CTDP.CONFIG.SAVE_UNITS[typeName] == true then return true end
        end
        return false
    end
    return true
end

local function captureGroupData(grp, forcedName)
    if not grp then return nil end

    local groupName = forcedName
    if not groupName then
        local okName, resultName = pcall(function() return grp:getName() end)
        if okName then groupName = resultName end
    end
    if not groupName or groupName == "" then return nil end

    local okUnits, units = pcall(function() return grp:getUnits() end)
    if not okUnits or not units or #units == 0 then return nil end

    local okGroupCategory, groupCategory = pcall(function() return grp:getCategory() end)
    if not okGroupCategory then groupCategory = Group.Category.GROUND end

    local okCoalition, coalitionValue = pcall(function() return grp:getCoalition() end)
    if not okCoalition then coalitionValue = coalition.side.BLUE end

    local countryValue = nil
    local unitTypes = {}
    local unitNames = {}
    local groupUnits = {}
    local firstPoint = nil
    local containsDrone = false

    for i, unit in ipairs(units) do
        if unit and unit:isExist() then
            local p = objectPoint(unit)
            if p then
                firstPoint = firstPoint or p
                local okType, typeName = pcall(function() return unit:getTypeName() end)
                if not okType then typeName = "" end

                local okUnitName, unitName = pcall(function() return unit:getName() end)
                if not okUnitName or not unitName or unitName == "" then unitName = groupName .. " Unit " .. tostring(i) end

                local okCountry, unitCountry = pcall(function() return unit:getCountry() end)
                if okCountry and unitCountry then countryValue = tonumber(unitCountry) end

                if isDroneType(typeName) then containsDrone = true end

                groupUnits[#groupUnits + 1] = {
                    name = unitName,
                    unitId = mist.getNextUnitId(),
                    type = typeName,
                    x = round(p.x, 2),
                    y = round(p.z, 2),
                    alt = containsDrone and (tonumber(CTDP.CONFIG.DRONES.ORBIT_ALT) or 3500) or 0,
                    alt_type = "BARO",
                    heading = getHeadingFromObject(unit),
                    skill = "Excellent",
                    playerCanDrive = true,
                }

                unitTypes[#unitTypes + 1] = typeName
                unitNames[#unitNames + 1] = unitName
            end
        end
    end

    if #groupUnits == 0 then return nil end

    countryValue = tonumber(countryValue) or countryForCoalition(coalitionValue)

    local task = "Ground Nothing"
    if containsDrone then
        groupCategory = Group.Category.AIRPLANE
        task = "Reconnaissance"
    elseif groupCategory == Group.Category.AIRPLANE or groupCategory == Group.Category.HELICOPTER then
        task = "Reconnaissance"
    end

    local route = {
        points = {
            [1] = {
                x = groupUnits[1].x,
                y = groupUnits[1].y,
                alt = groupUnits[1].alt or 0,
                alt_type = "BARO",
                speed = containsDrone and (tonumber(CTDP.CONFIG.DRONES.ORBIT_SPEED) or 80) or 0,
                action = containsDrone and "Turning Point" or "Off Road",
                type = "Turning Point",
                ETA = 0,
                ETA_locked = false,
                speed_locked = true,
                task = { id = "ComboTask", params = { tasks = {} } },
            }
        }
    }

    if containsDrone then route = buildDroneRoute(groupUnits[1].x, groupUnits[1].y) end

    local groupData = {
        visible = false,
        hidden = false,
        lateActivation = false,
        tasks = {},
        task = task,
        uncontrolled = false,
        route = route,
        country = countryValue,
        countryId = countryValue,
        coalition = coalitionValue,
        category = groupCategory,
        groupId = mist.getNextGroupId(),
        name = groupName,
        units = groupUnits,
    }

    return groupData, coalitionValue, countryValue, groupCategory, unitTypes, unitNames, containsDrone
end

local function findDeploymentByGroupName(groupName)
    local depId = CTDP.STATE.byGroupName and CTDP.STATE.byGroupName[groupName]
    if depId and CTDP.STATE.doc and CTDP.STATE.doc.deployments then
        return depId, CTDP.STATE.doc.deployments[depId]
    end
    return nil, nil
end

local function recordCtldSpawnedGroup(groupName)
    if not groupName or groupName == "" then return false end
    if CTDP.STATE.injecting then return false end

    local grp = groupExistsByName(groupName)
    if not grp then return false end

    local groupData, coalitionValue, countryValue, groupCategory, types, unitNames, containsDrone = captureGroupData(grp, groupName)
    if not groupData then return false end

    local category = determineCategory(types)
    if not shouldSaveDeployment(types, category) then return false end

    CTDP.STATE.doc = normalizeDoc(CTDP.STATE.doc)
    local depId, dep = findDeploymentByGroupName(groupName)

    if not dep then
        depId = nextDeploymentId()
        dep = {
            id = depId,
            alive = true,
            createdAt = now(),
            source = "passive_birth",
            originalGroupName = groupName,
            activeGroupName = groupName,
            runtimeGroupName = groupName,
            names = { groups = { groupName }, units = unitNames or {} },
        }
        CTDP.STATE.doc.deployments[depId] = dep
    end

    dep.alive = true
    dep.updatedAt = now()
    dep.lastSeenAt = now()
    dep.activeGroupName = groupName
    dep.runtimeGroupName = groupName
    dep.category = category
    dep.groupData = groupData
    dep.coalition = coalitionValue
    dep.country = countryValue
    dep.groupCategory = groupCategory
    dep.types = types or {}
    dep.names = dep.names or { groups = {}, units = {} }
    dep.names.groups = dep.names.groups or {}
    dep.names.units = dep.names.units or {}
    insertUnique(dep.names.groups, groupName)
    for _, unitName in ipairs(unitNames or {}) do insertUnique(dep.names.units, unitName) end

    if containsDrone or groupContainsDrone(groupName) then
        dep.ctldRole = "DRONE_JTAC"
        dep.jtacCode = dep.jtacCode or tonumber(CTDP.CONFIG.DRONES.DEFAULT_CODE) or 1688
        if CTDP.CONFIG.DRONES.PROTECT_ON_CAPTURE then
            applyDroneProtectionNow(groupName)
            scheduleDroneProtection(groupName)
        end
    elseif groupContainsJtac(groupName) then
        dep.ctldRole = "JTAC"
    elseif lowerText(category):find("sam", 1, true) then
        dep.ctldRole = "AA_SYSTEM"
    else
        dep.ctldRole = "DEPLOYMENT"
    end

    indexDeployment(dep)
    CTDP.STATE.dirty = true
    writeState(false)
    log("Despliegue capturado: " .. tostring(groupName) .. " | " .. tostring(category), 8)
    return true
end

local function isLikelyCtldDeploymentGroup(groupName)
    if not groupName or groupName == "" then return false end
    if CTDP.STATE.injectedGroupsThisSession[groupName] then return false end
    local grp = groupExistsByName(groupName)
    if not grp then return false end

    if string.find(groupName, "  #", 1, true) then return true end

    local okUnits, units = pcall(function() return grp:getUnits() end)
    if not okUnits or not units then return false end
    for _, unit in ipairs(units) do
        if unit and unit:isExist() then
            local okName, unitName = pcall(function() return unit:getName() end)
            if okName and tostring(unitName or ""):find("Unpacked ", 1, true) == 1 then return true end

            local okType, typeName = pcall(function() return unit:getTypeName() end)
            if okType and typeName and CTDP.STATE.unitToCategory[typeName] then return true end
            if okType and typeName and isJtacType(typeName) then return true end
        end
    end
    return false
end

local function passiveScheduleGroupCapture(groupName)
    if not groupName or groupName == "" then return end
    CTDP.STATE.passivePendingGroups = CTDP.STATE.passivePendingGroups or {}
    CTDP.STATE.passiveSeenGroups = CTDP.STATE.passiveSeenGroups or {}
    if CTDP.STATE.passiveSeenGroups[groupName] then return end
    if CTDP.STATE.passivePendingGroups[groupName] then return end
    CTDP.STATE.passivePendingGroups[groupName] = true

    timer.scheduleFunction(function()
        CTDP.STATE.passivePendingGroups[groupName] = nil
        if CTDP.STATE.injecting then return nil end
        if not isLikelyCtldDeploymentGroup(groupName) then return nil end
        CTDP.STATE.passiveSeenGroups[groupName] = true
        recordCtldSpawnedGroup(groupName)
        return nil
    end, nil, timer.getTime() + (tonumber(CTDP.CONFIG.PASSIVE_CAPTURE_DELAY) or 2))
end

local function passiveInitialWorldScan()
    for _, side in ipairs({ coalition.side.RED, coalition.side.BLUE }) do
        local groups = coalition.getGroups(side) or {}
        for _, grp in ipairs(groups) do
            if grp and grp:isExist() then
                local okName, groupName = pcall(function() return grp:getName() end)
                if okName and groupName then passiveScheduleGroupCapture(groupName) end
            end
        end
    end
end

----------------------------------------------------------------
-- FOB / FARP
----------------------------------------------------------------
local function getFobByStaticName(staticName)
    local fobId = CTDP.STATE.byStaticName and CTDP.STATE.byStaticName[staticName]
    if fobId and CTDP.STATE.doc and CTDP.STATE.doc.fobs then return fobId, CTDP.STATE.doc.fobs[fobId] end
    return nil, nil
end

local function addNameToCtldLogistics(name)
    if not name or name == "" then return end
    ctld.logisticUnits = ctld.logisticUnits or {}
    ctld.builtFOBS = ctld.builtFOBS or {}
    insertUnique(ctld.logisticUnits, name)
    insertUnique(ctld.builtFOBS, name)
end

local function removeNameFromCtldLogistics(name)
    if not name or name == "" then return end
    removeFromList(ctld.logisticUnits or {}, name)
    removeFromList(ctld.builtFOBS or {}, name)
end

local function normalizeFreqMHz(freq)
    local f = tonumber(freq) or 127.5
    if f > 1000000 then f = f / 1000000 end
    return f
end

local function buildEditorStyleFarpStaticData(fob, farpPoint)
    local cfg = CTDP.CONFIG.FARP
    local farpName = fob.farpName or farpNameForIndex(fob.farpIndex or 1)
    local countryValue = tonumber(fob.country) or countryForCoalition(fob.coalition)
    local coalitionValue = tonumber(fob.coalition) or getCoalitionFromCountry(countryValue) or coalition.side.BLUE
    local heading = tonumber(cfg.heading) or 0
    local frequency = normalizeFreqMHz(cfg.frequency)
    local modulation = tonumber(cfg.modulation) or 0
    local callsignId = tonumber(cfg.callsign) or 1

    local unitId = mist.getNextUnitId()
    local groupId = mist.getNextGroupId()

    local unit = {
        category = "Heliports",
        type = cfg.type or "FARP",
        shape_name = cfg.shape_name or "FARPS",
        name = farpName,
        unitId = unitId,
        x = farpPoint.x,
        y = farpPoint.z,
        heading = heading,
        heliport_callsign_id = callsignId,
        heliport_frequency = frequency,
        heliport_modulation = modulation,
        tasks = {},
        dynamicSpawn = cfg.dynamicSpawn == true,
        allowHotStart = cfg.allowHotStart == true,
        dynamicCargo = cfg.dynamicCargo == true,
        unlimitedFuel = cfg.unlimitedFuel ~= false,
        unlimitedMunitions = cfg.unlimitedMunitions ~= false,
        unlimitedAircrafts = cfg.unlimitedAircrafts ~= false,
    }

    local staticData = {
        country = countryValue,
        countryId = countryValue,
        coalition = coalitionValue,
        category = "Heliports",
        type = cfg.type or "FARP",
        shape_name = cfg.shape_name or "FARPS",
        name = farpName,
        unitId = unitId,
        groupId = groupId,
        x = farpPoint.x,
        y = farpPoint.z,
        heading = heading,
        dead = false,
        hidden = false,
        canCargo = false,

        heliport_callsign_id = callsignId,
        heliport_frequency = frequency,
        heliport_modulation = modulation,

        dynamicSpawn = cfg.dynamicSpawn == true,
        allowHotStart = cfg.allowHotStart == true,
        dynamicCargo = cfg.dynamicCargo == true,
        unlimitedFuel = cfg.unlimitedFuel ~= false,
        unlimitedMunitions = cfg.unlimitedMunitions ~= false,
        unlimitedAircrafts = cfg.unlimitedAircrafts ~= false,

        route = {
            points = {
                [1] = {
                    action = "",
                    alt = 0,
                    formation_template = "",
                    name = "",
                    speed = 0,
                    type = "",
                    x = farpPoint.x,
                    y = farpPoint.z,
                }
            }
        },

        units = {
            [1] = unit
        }
    }

    return staticData
end

local function verifyFarpRegistration(farpName)
    local staticOk = staticExistsByName(farpName) ~= nil
    local unitOk = unitExistsByName(farpName) ~= nil
    local airbaseOk = false
    local warehouseOk = false

    local okAb, ab = pcall(function() return Airbase.getByName(farpName) end)
    if okAb and ab then
        airbaseOk = true
        local okWh, wh = pcall(function() return ab:getWarehouse() end)
        if okWh and wh then warehouseOk = true end
    end

    return staticOk, unitOk, airbaseOk, warehouseOk
end

local function applyFarpWarehouseOnce(farpName)
    local whCfg = CTDP.CONFIG.FARP.WAREHOUSE or {}
    if whCfg.enabled ~= true then return false end

    local okAb, ab = pcall(function() return Airbase.getByName(farpName) end)
    if not okAb or not ab then return false end

    local okWh, wh = pcall(function() return ab:getWarehouse() end)
    if not okWh or not wh then return false end

    for liquidId, amount in pairs(whCfg.liquids or {}) do
        pcall(function() wh:setLiquidAmount(tonumber(liquidId), tonumber(amount) or 0) end)
    end
    for itemName, amount in pairs(whCfg.aircraft or {}) do
        pcall(function() wh:setItem(itemName, tonumber(amount) or 0) end)
    end
    for itemName, amount in pairs(whCfg.weapon or {}) do
        pcall(function() wh:setItem(itemName, tonumber(amount) or 0) end)
    end

    return true
end

local function scheduleFarpWarehouse(farpName)
    if not farpName or farpName == "" then return end
    local whCfg = CTDP.CONFIG.FARP.WAREHOUSE or {}
    if whCfg.enabled ~= true then return end

    local count = 0
    local max = tonumber(whCfg.retryCount) or 12
    local interval = tonumber(whCfg.retryInterval) or 2
    local delay = tonumber(whCfg.applyDelay) or 2

    local function tick()
        count = count + 1
        local ok = applyFarpWarehouseOnce(farpName)
        if ok then
            log("Warehouse aplicado al FARP: " .. tostring(farpName), 6)
            return nil
        end
        if count < max then return timer.getTime() + interval end
        warn("No se pudo aplicar warehouse al FARP: " .. tostring(farpName))
        return nil
    end

    timer.scheduleFunction(tick, nil, timer.getTime() + delay)
end

local function scheduleFarpVerification(farpName)
    local count = 0
    local max = tonumber(CTDP.CONFIG.FARP.VERIFY_RETRIES) or 15
    local interval = tonumber(CTDP.CONFIG.FARP.VERIFY_INTERVAL) or 2

    local function tick()
        count = count + 1
        local sOk, uOk, aOk, wOk = verifyFarpRegistration(farpName)
        env.info("[CTLD_PERSIST_FARP_VERIFY] " .. tostring(farpName) ..
            " StaticObject=" .. tostring(sOk) ..
            " Unit=" .. tostring(uOk) ..
            " Airbase=" .. tostring(aOk) ..
            " Warehouse=" .. tostring(wOk))

        if CTDP.CONFIG.DEBUG then
            trigger.action.outText("FARP VERIFY " .. tostring(farpName) ..
                " | Static=" .. tostring(sOk) ..
                " Unit=" .. tostring(uOk) ..
                " Airbase=" .. tostring(aOk) ..
                " WH=" .. tostring(wOk), 8)
        end

        if aOk and wOk then return nil end
        if count < max then return timer.getTime() + interval end
        return nil
    end

    timer.scheduleFunction(tick, nil, timer.getTime() + interval)
end

local function spawnEditorStyleFarp(staticData)
    if not staticData or not staticData.name then return nil, "staticData invalido" end
    local existing = staticExistsByName(staticData.name)
    if existing then return existing, "existing" end

    local okMist, resultMist = pcall(function() return mist.dynAddStatic(staticData) end)
    if okMist and resultMist then
        return staticExistsByName(staticData.name) or resultMist, "mist.dynAddStatic"
    end

    -- Fallback solo para evitar perdida total. Si dynamic slots no aparecen, revisar DCS.log.
    local okDirect, resultDirect = pcall(function()
        return coalition.addStaticObject(tonumber(staticData.country) or tonumber(staticData.countryId), staticData)
    end)
    if okDirect and resultDirect then return resultDirect, "coalition.addStaticObject_after_mist_error:" .. tostring(resultMist) end

    return nil, "mist=" .. tostring(resultMist) .. " | direct=" .. tostring(resultDirect)
end

local function createOrRestoreFarpForFob(fob)
    if not fob or fob.alive == false then return false end
    if CTDP.CONFIG.FARP.enabled ~= true then return false end
    if not fob.point then return false end

    CTDP.STATE.doc = normalizeDoc(CTDP.STATE.doc)
    if not fob.farpIndex then
        fob.farpIndex = tonumber(CTDP.STATE.doc.counters.nextFarpIndex) or 1
        CTDP.STATE.doc.counters.nextFarpIndex = fob.farpIndex + 1
    end

    fob.farpName = fob.farpName or farpNameForIndex(fob.farpIndex)

    local farpPoint = {
        x = (tonumber(fob.point.x) or 0) + (tonumber(CTDP.CONFIG.FARP.offsetX) or 0),
        y = tonumber(fob.point.y) or 0,
        z = (tonumber(fob.point.z) or 0) + (tonumber(CTDP.CONFIG.FARP.offsetZ) or 0),
    }

    local staticData = buildEditorStyleFarpStaticData(fob, farpPoint)
    local st, method = spawnEditorStyleFarp(staticData)
    if not st then
        warn("No se pudo crear FARP " .. tostring(fob.farpName) .. " | " .. tostring(method))
        fob.farpActive = false
        CTDP.STATE.dirty = true
        return false
    end

    fob.farpStaticData = staticData
    fob.farpActive = true
    fob.farpSpawnMethod = method
    fob.updatedAt = now()
    CTDP.STATE.dirty = true
    indexFob(fob)

    scheduleFarpVerification(fob.farpName)
    scheduleFarpWarehouse(fob.farpName)

    log("FARP activo: " .. tostring(fob.farpName) .. " | metodo=" .. tostring(method), 8)
    return true
end

local function makeFobStaticData(staticName, countryValue, coalitionValue, point, heading)
    return {
        name = staticName,
        type = "outpost",
        category = "Fortifications",
        x = round(point.x, 2),
        y = round(point.z, 2),
        heading = heading or 0,
        country = countryValue,
        countryId = countryValue,
        coalition = coalitionValue,
        dead = false,
        hidden = false,
        canCargo = false,
    }
end

local function spawnStatic(staticData)
    if not staticData or not staticData.name then return nil end
    if staticExistsByName(staticData.name) then return staticExistsByName(staticData.name) end
    local ok, result = pcall(function()
        return coalition.addStaticObject(tonumber(staticData.country) or tonumber(staticData.countryId), staticData)
    end)
    if ok then return result or staticExistsByName(staticData.name) end
    warn("Error creando static " .. tostring(staticData.name) .. ": " .. tostring(result))
    return nil
end

local function recordFobStatic(staticName)
    if CTDP.CONFIG.SAVE_FOBS ~= true then return false end
    if not staticName or staticName == "" then return false end
    if CTDP.STATE.injecting then return false end

    local st = staticExistsByName(staticName)
    if not st then return false end
    local _, existing = getFobByStaticName(staticName)
    if existing then return false end

    local point = objectPoint(st)
    if not point then return false end

    local countryValue = country.id.USA
    local coalitionValue = coalition.side.BLUE
    pcall(function() countryValue = st:getCountry() end)
    pcall(function() coalitionValue = st:getCoalition() end)
    coalitionValue = tonumber(coalitionValue) or getCoalitionFromCountry(countryValue) or coalition.side.BLUE
    countryValue = tonumber(countryValue) or countryForCoalition(coalitionValue)

    CTDP.STATE.doc = normalizeDoc(CTDP.STATE.doc)
    local fobId = nextFobId()
    local fob = {
        id = fobId,
        alive = true,
        createdAt = now(),
        updatedAt = now(),
        lastSeenAt = now(),
        staticName = staticName,
        runtimeStaticName = staticName,
        country = countryValue,
        coalition = coalitionValue,
        point = { x = round(point.x, 2), y = round(point.y or 0, 2), z = round(point.z, 2) },
        staticData = makeFobStaticData(staticName, countryValue, coalitionValue, point, getHeadingFromObject(st)),
    }

    CTDP.STATE.doc.fobs[fobId] = fob
    indexFob(fob)
    createOrRestoreFarpForFob(fob)
    CTDP.STATE.dirty = true
    writeState(false)
    log("FOB capturado: " .. tostring(staticName), 8)
    return true
end

local function passiveScanFobsOnce()
    if CTDP.STATE.injecting then return end
    if CTDP.CONFIG.SAVE_FOBS ~= true then return end

    local lists = { ctld.logisticUnits or {}, ctld.builtFOBS or {} }
    for _, list in ipairs(lists) do
        for _, staticName in ipairs(list) do
            staticName = tostring(staticName or "")
            if staticName ~= "" and staticExistsByName(staticName) then
                if staticName:find("Deployed FOB #", 1, true) == 1 or staticName:find("FOB", 1, true) then
                    recordFobStatic(staticName)
                end
            end
        end
    end
end

local function passiveFobScannerLoop()
    passiveScanFobsOnce()
    return timer.getTime() + (tonumber(CTDP.CONFIG.PASSIVE_FOB_SCAN_INTERVAL) or 5)
end

----------------------------------------------------------------
-- RESTAURACION
----------------------------------------------------------------
local function prepareGroupDataForRestore(dep)
    if not dep or not dep.groupData then return nil end
    local data = deepCopy(dep.groupData)
    local groupName = dep.runtimeGroupName or dep.activeGroupName or dep.originalGroupName or (CTDP.CONFIG.RUNTIME_PREFIX .. tostring(dep.id))

    data.groupId = mist.getNextGroupId()
    data.name = groupName
    data.groupName = nil
    data.country = tonumber(dep.country) or tonumber(data.country) or tonumber(data.countryId) or countryForCoalition(dep.coalition)
    data.countryId = data.country
    data.coalition = tonumber(dep.coalition) or tonumber(data.coalition) or getCoalitionFromCountry(data.country) or coalition.side.BLUE

    local isDrone = dep.ctldRole == "DRONE_JTAC"
    for _, t in ipairs(dep.types or {}) do if isDroneType(t) then isDrone = true end end

    if isDrone then
        data.category = Group.Category.AIRPLANE
        data.task = "Reconnaissance"
        local u = data.units and data.units[1]
        if u then
            u.alt = tonumber(CTDP.CONFIG.DRONES.ORBIT_ALT) or 3500
            u.alt_type = "BARO"
            data.route = buildDroneRoute(tonumber(u.x) or 0, tonumber(u.y) or 0)
        end
    end

    for i, unit in ipairs(data.units or {}) do
        unit.unitId = mist.getNextUnitId()
        unit.name = unit.name or (groupName .. " Unit " .. tostring(i))
    end

    return data, isDrone
end

local function injectDeployment(dep)
    if not dep or dep.alive == false then return false end
    if not dep.groupData then return false end

    local groupName = dep.runtimeGroupName or dep.activeGroupName or dep.originalGroupName
    if groupName and groupExistsByName(groupName) then
        dep.activeGroupName = groupName
        dep.lastSeenAt = now()
        indexDeployment(dep)
        return false
    end

    local groupData, isDrone = prepareGroupDataForRestore(dep)
    if not groupData then return false end

    local ok, result = pcall(function() return mist.dynAdd(groupData) end)
    if not ok or not result then
        warn("Error restaurando deployment " .. tostring(dep.id) .. ": " .. tostring(result))
        return false
    end

    local spawnedName = groupData.name
    if type(result) == "string" then spawnedName = result end
    if type(result) == "table" then spawnedName = result.name or result.groupName or spawnedName end

    dep.activeGroupName = spawnedName
    dep.runtimeGroupName = spawnedName
    dep.lastInjectedAt = now()
    dep.lastSeenAt = now()
    dep.updatedAt = now()
    CTDP.STATE.injectedGroupsThisSession[spawnedName] = true
    indexDeployment(dep)

    if isDrone and CTDP.CONFIG.DRONES.PROTECT_ON_RESTORE then
        scheduleDroneProtection(spawnedName)
    end

    CTDP.STATE.dirty = true
    log("Deployment restaurado: " .. tostring(dep.id) .. " | " .. tostring(spawnedName), 8)
    return true
end

local function restoreFob(fob)
    if not fob or fob.alive == false then return false end

    local staticName = fob.runtimeStaticName or fob.staticName or (CTDP.CONFIG.FOB_RUNTIME_PREFIX .. tostring(fob.id))
    if staticExistsByName(staticName) then
        if CTDP.CONFIG.RESTORE_FOB_TO_CTLD_LOGISTICS then addNameToCtldLogistics(staticName) end
        createOrRestoreFarpForFob(fob)
        return false
    end

    local staticData = deepCopy(fob.staticData or {})
    staticData.name = staticData.name or staticName
    staticData.country = tonumber(staticData.country) or tonumber(staticData.countryId) or tonumber(fob.country) or countryForCoalition(fob.coalition)
    staticData.countryId = staticData.country
    staticData.coalition = tonumber(staticData.coalition) or tonumber(fob.coalition) or getCoalitionFromCountry(staticData.country) or coalition.side.BLUE
    staticData.type = staticData.type or "outpost"
    staticData.category = staticData.category or "Fortifications"
    if fob.point then
        staticData.x = tonumber(staticData.x) or tonumber(fob.point.x) or 0
        staticData.y = tonumber(staticData.y) or tonumber(fob.point.z) or 0
    end

    local st = spawnStatic(staticData)
    if not st then return false end

    fob.runtimeStaticName = staticData.name
    fob.staticName = fob.staticName or staticData.name
    fob.lastInjectedAt = now()
    fob.lastSeenAt = now()
    fob.updatedAt = now()
    if CTDP.CONFIG.RESTORE_FOB_TO_CTLD_LOGISTICS then addNameToCtldLogistics(staticData.name) end
    createOrRestoreFarpForFob(fob)
    CTDP.STATE.injectedFobsThisSession[fob.id] = true
    CTDP.STATE.dirty = true
    indexFob(fob)
    log("FOB restaurado: " .. tostring(fob.id) .. " | " .. tostring(staticData.name), 8)
    return true
end

local function injectFromJson()
    if not CTDP.STATE.doc then return end
    rebuildIndexes()
    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.deployments or {})) do injectDeployment(CTDP.STATE.doc.deployments[id]) end
    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.fobs or {})) do restoreFob(CTDP.STATE.doc.fobs[id]) end
    writeState(false)
end

----------------------------------------------------------------
-- EXPORT / UPDATE
----------------------------------------------------------------
local function updateDeploymentFromWorld(dep)
    if not dep or dep.alive == false then return end
    local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName
    local grp = groupExistsByName(groupName)

    if grp and groupHasAliveUnits(groupName) then
        local groupData, coalitionValue, countryValue, groupCategory, types, unitNames = captureGroupData(grp, groupName)
        if groupData then
            dep.groupData = groupData
            dep.coalition = coalitionValue
            dep.country = countryValue
            dep.groupCategory = groupCategory
            dep.types = types or dep.types or {}
            dep.lastSeenAt = now()
            dep.updatedAt = now()
            dep.names = dep.names or { groups = {}, units = {} }
            dep.names.groups = dep.names.groups or {}
            dep.names.units = dep.names.units or {}
            insertUnique(dep.names.groups, groupName)
            for _, unitName in ipairs(unitNames or {}) do insertUnique(dep.names.units, unitName) end
            CTDP.STATE.dirty = true
        end
        return
    end

    local lastSeen = tonumber(dep.lastSeenAt) or tonumber(dep.createdAt) or now()
    if (now() - lastSeen) >= (tonumber(CTDP.CONFIG.MISSING_DEAD_GRACE) or 10) then
        dep.alive = false
        dep.destroyedAt = now()
        dep.destroyReason = "missing_on_export"
        dep.updatedAt = now()
        CTDP.STATE.dirty = true
    end
end

local function updateFobFromWorld(fob)
    if not fob or fob.alive == false then return end
    local staticName = fob.runtimeStaticName or fob.staticName
    local st = staticExistsByName(staticName)

    if st then
        local p = objectPoint(st)
        if p then fob.point = { x = round(p.x, 2), y = round(p.y or 0, 2), z = round(p.z, 2) } end
        fob.lastSeenAt = now()
        fob.updatedAt = now()
        createOrRestoreFarpForFob(fob)
        CTDP.STATE.dirty = true
        return
    end

    local lastSeen = tonumber(fob.lastSeenAt) or tonumber(fob.createdAt) or now()
    if (now() - lastSeen) >= (tonumber(CTDP.CONFIG.MISSING_DEAD_GRACE) or 10) then
        fob.alive = false
        fob.destroyedAt = now()
        fob.destroyReason = "missing_on_export"
        fob.updatedAt = now()
        if fob.farpName and staticExistsByName(fob.farpName) then pcall(function() staticExistsByName(fob.farpName):destroy() end) end
        removeNameFromCtldLogistics(staticName)
        CTDP.STATE.dirty = true
    end
end

local function exportToJson()
    if not CTDP.STATE.doc then return end
    passiveScanFobsOnce()
    rebuildIndexes()
    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.deployments or {})) do updateDeploymentFromWorld(CTDP.STATE.doc.deployments[id]) end
    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.fobs or {})) do updateFobFromWorld(CTDP.STATE.doc.fobs[id]) end

    local whCfg = CTDP.CONFIG.FARP.WAREHOUSE or {}
    if whCfg.repeatTopupOnExport == true then
        for _, fob in pairs(CTDP.STATE.doc.fobs or {}) do
            if fob and fob.alive ~= false and fob.farpName then applyFarpWarehouseOnce(fob.farpName) end
        end
    end

    writeState(true)
    CTDP.STATE.lastExport = now()
end

----------------------------------------------------------------
-- EVENTS
----------------------------------------------------------------
local function markDeploymentDeadByUnit(unitName, reason)
    local depId = CTDP.STATE.byUnitName and CTDP.STATE.byUnitName[unitName]
    if not depId or not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then return false end
    local dep = CTDP.STATE.doc.deployments[depId]
    if not dep or dep.alive == false then return false end
    local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName

    timer.scheduleFunction(function()
        if groupHasAliveUnits(groupName) then return nil end
        dep.alive = false
        dep.destroyedAt = now()
        dep.destroyReason = reason or "dead_event"
        dep.updatedAt = now()
        CTDP.STATE.dirty = true
        writeState(false)
        return nil
    end, nil, timer.getTime() + 3)

    return true
end

local function markFobDeadByName(staticName, reason)
    local fobId = CTDP.STATE.byStaticName and CTDP.STATE.byStaticName[staticName]
    if not fobId or not CTDP.STATE.doc or not CTDP.STATE.doc.fobs then return false end
    local fob = CTDP.STATE.doc.fobs[fobId]
    if not fob or fob.alive == false then return false end

    fob.alive = false
    fob.destroyedAt = now()
    fob.destroyReason = reason or "dead_event"
    fob.updatedAt = now()
    if fob.farpName and staticExistsByName(fob.farpName) then pcall(function() staticExistsByName(fob.farpName):destroy() end) end
    removeNameFromCtldLogistics(staticName)
    CTDP.STATE.dirty = true
    writeState(false)
    return true
end

local function installPassiveCtldCaptureModule()
    if CTDP.STATE.passiveModuleInstalled then return end
    CTDP.STATE.passiveModuleInstalled = true

    world.addEventHandler({
        onEvent = function(_, event)
            if not event or not event.id then return end

            if event.id == world.event.S_EVENT_BIRTH then
                if not event.initiator or not event.initiator.getGroup then return end
                local okGroup, grp = pcall(function() return event.initiator:getGroup() end)
                if not okGroup or not grp then return end
                local okName, groupName = pcall(function() return grp:getName() end)
                if not okName or not groupName or groupName == "" then return end
                passiveScheduleGroupCapture(groupName)
                return
            end

            if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH or event.id == world.event.S_EVENT_KILL then
                if not event.initiator or not event.initiator.getName then return end
                local okName, objName = pcall(function() return event.initiator:getName() end)
                if okName and objName then
                    markDeploymentDeadByUnit(objName, "dead_event")
                    markFobDeadByName(objName, "dead_event")
                end
            end
        end
    })

    timer.scheduleFunction(function()
        passiveInitialWorldScan()
        return nil
    end, nil, timer.getTime() + (tonumber(CTDP.CONFIG.PASSIVE_WORLD_SCAN_DELAY) or 3))

    timer.scheduleFunction(passiveFobScannerLoop, nil, timer.getTime() + (tonumber(CTDP.CONFIG.PASSIVE_FOB_SCAN_INTERVAL) or 5))

    log("Modulo pasivo instalado. No se modifica ninguna funcion de CTLD.", 8)
end

----------------------------------------------------------------
-- API MANUAL / DEBUG
----------------------------------------------------------------
function CTDP.forceSave()
    exportToJson()
end

function CTDP.forceInject()
    injectFromJson()
end

function CTDP.forceScan()
    passiveInitialWorldScan()
    passiveScanFobsOnce()
    exportToJson()
end

function CTDP.forceProtectDrones()
    for _, dep in pairs((CTDP.STATE.doc and CTDP.STATE.doc.deployments) or {}) do
        if dep and dep.alive ~= false and dep.ctldRole == "DRONE_JTAC" then
            local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName
            applyDroneProtectionNow(groupName)
            scheduleDroneProtection(groupName)
        end
    end
end

function CTDP.forceRestoreFARPs()
    for _, fob in pairs((CTDP.STATE.doc and CTDP.STATE.doc.fobs) or {}) do
        if fob and fob.alive ~= false then createOrRestoreFarpForFob(fob) end
    end
    writeState(true)
end

function CTDP.showStatus()
    local total, alive, dead, drones, jtac, aa = 0, 0, 0, 0, 0, 0
    local fobTotal, fobAlive, farpActive = 0, 0, 0

    for _, dep in pairs((CTDP.STATE.doc and CTDP.STATE.doc.deployments) or {}) do
        total = total + 1
        if dep.alive == false then dead = dead + 1 else alive = alive + 1 end
        if dep.ctldRole == "DRONE_JTAC" then drones = drones + 1 end
        if dep.ctldRole == "JTAC" then jtac = jtac + 1 end
        if dep.ctldRole == "AA_SYSTEM" then aa = aa + 1 end
    end

    for _, fob in pairs((CTDP.STATE.doc and CTDP.STATE.doc.fobs) or {}) do
        fobTotal = fobTotal + 1
        if fob.alive ~= false then fobAlive = fobAlive + 1 end
        if fob.farpActive then farpActive = farpActive + 1 end
    end

    trigger.action.outText(
        "CTLD_Persistance 2.8.0 PASSIVE SAFE FARP/DRONE\n" ..
        "Deployments Total: " .. tostring(total) .. "\n" ..
        "Deployments Vivos: " .. tostring(alive) .. "\n" ..
        "Deployments Muertos: " .. tostring(dead) .. "\n" ..
        "Drones: " .. tostring(drones) .. "\n" ..
        "JTAC: " .. tostring(jtac) .. "\n" ..
        "AA: " .. tostring(aa) .. "\n" ..
        "FOBs Total: " .. tostring(fobTotal) .. "\n" ..
        "FOBs Vivos: " .. tostring(fobAlive) .. "\n" ..
        "FARPs Activos: " .. tostring(farpActive) .. "\n" ..
        "JSON: " .. tostring(CTDP.CONFIG.FILE_PATH),
        15
    )
end

----------------------------------------------------------------
-- LOOP PRINCIPAL
----------------------------------------------------------------
local function mainLoop()
    if not CTDP.STATE.started then return nil end
    local t = now()

    if CTDP.STATE.injecting then
        if t <= CTDP.STATE.injectEndsAt then
            if (t - CTDP.STATE.lastInject) >= (tonumber(CTDP.CONFIG.INJECT_INTERVAL) or 1) then
                CTDP.STATE.lastInject = t
                injectFromJson()
            end
        else
            CTDP.STATE.injecting = false
            CTDP.STATE.writeEnabled = true
            rebuildIndexes()
            exportToJson()
            log("Ventana de inyeccion terminada. DCS toma control del JSON.", 8)
        end
    end

    if CTDP.STATE.writeEnabled then
        if (t - CTDP.STATE.lastExport) >= (tonumber(CTDP.CONFIG.EXPORT_INTERVAL) or 60) then
            exportToJson()
        end
    end

    return timer.getTime() + (tonumber(CTDP.CONFIG.MAIN_LOOP_INTERVAL) or 1)
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
local function start()
    if CTDP.STATE.started then return end

    CTDP.STATE.started = true
    CTDP.STATE.injecting = true
    CTDP.STATE.writeEnabled = false
    CTDP.STATE.injectEndsAt = now() + (tonumber(CTDP.CONFIG.INJECT_DURATION) or 30)
    CTDP.STATE.lastInject = -9999
    CTDP.STATE.lastExport = -9999
    CTDP.STATE.injectedGroupsThisSession = {}
    CTDP.STATE.injectedFobsThisSession = {}
    CTDP.STATE.passivePendingGroups = {}
    CTDP.STATE.passiveSeenGroups = {}

    -- Seguridad: no se toca ninguna funcion interna de CTLD.

    loadState()
    buildCtldIndexes()
    rebuildIndexes()
    installPassiveCtldCaptureModule()

    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)

    log("CTLD_Persistance 2.8.0 PASSIVE SAFE FARP/DRONE iniciado. Sin wrappers CTLD.", 10)
end

start()