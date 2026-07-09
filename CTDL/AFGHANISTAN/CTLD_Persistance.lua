----------------------------------------------------------------
-- HDEV_CTLDDeploymentPersistence_AFGHANISTAN.lua
-- Version 2.6.6
--
-- Persistencia de despliegues CTLD + FOB PACKAGE static heliport estilo Mission Editor.
--
-- Cargar despues de:
-- 1. MIST
-- 2. CTLD
-- 3. HookEconomyV2, si lo usas
--
-- IMPORTANTE V2.6.2:
-- - El FARP del paquete se crea como STATIC HELIPORT estilo Mission Editor.
-- - Usa type="FARP", shape_name="FARPS", category="Heliports".
-- - El mismo nombre se usa para StaticObject / Unit / Airbase.
-- - Frecuencia en MHz como el Mission Editor: 127.5, no 127500000.
-- - Luego intenta registrar Airbase/Warehouse y alimentar inventario.
-- - V2.6.6: aircraft/weapon usan el mismo formato que devuelve DCS:
--   ["UH-1H"] = 100, ["weapons.xxx"] = 100.
----------------------------------------------------------------

if not mist or not mist.dynAdd or not mist.getNextGroupId or not mist.getNextUnitId then
    trigger.action.outText("ERROR: MIST no esta cargado o faltan funciones basicas.", 15)
    return
end

if not ctld or not ctld.spawnCrateGroup or not ctld.spawnFOB then
    trigger.action.outText("ERROR: CTLD no esta cargado o faltan ctld.spawnCrateGroup / ctld.spawnFOB.", 15)
    return
end

HDEV_CTLDDeploymentPersistence = HDEV_CTLDDeploymentPersistence or {}
local CTDP = HDEV_CTLDDeploymentPersistence

----------------------------------------------------------------
-- CONFIGURACION
----------------------------------------------------------------
CTDP.CONFIG = {
    DEBUG = false,

    FILE_PATH = lfs.writedir() .. "Config\\HorizontDev\\AFGHANISTAN\\SystemCTLDDeploymentPersistenceAfghanistan.json",

    INJECT_DURATION = 30,
    INJECT_INTERVAL = 1,
    EXPORT_INTERVAL = 60,
    MAIN_LOOP_INTERVAL = 1,

    RUNTIME_PREFIX = "HDEV_CTLD_",
    FOB_RUNTIME_PREFIX = "HDEV_FOB_",
    HELIPORT_RUNTIME_SUFFIX = "_HELIPORT",

    ----------------------------------------------------------------
    -- NOMBRES DE FARPS RUNTIME
    -- V2.6.5: el FARP ya no se llama HDEV_FOB_X_HELIPORT.
    -- Se nombra por secuencia A-Z: ALFA FARP, BRAVO FARP, etc.
    -- Si se pasan de 26 FOBs: ALFA FARP 2, BRAVO FARP 2...
    ----------------------------------------------------------------
    FARP_NAME_MODE = "ALFA_ZULU",
    FARP_NAME_LIST = {
        "ALFA",
        "BRAVO",
        "CHARLIE",
        "DELTA",
        "ECO",
        "FOXTROT",
        "GOLF",
        "HOTEL",
        "INDIA",
        "JULIETT",
        "KILO",
        "LIMA",
        "MIKE",
        "NOVEMBER",
        "OSCAR",
        "PAPA",
        "QUEBEC",
        "ROMEO",
        "SIERRA",
        "TANGO",
        "UNIFORM",
        "VICTOR",
        "WHISKEY",
        "XRAY",
        "YANKEE",
        "ZULU"
    },

    MISSING_DEAD_GRACE = 10,
    RESTORE_CTLD_DELAY = 4,
    RESTORE_FOB_BEACON = true,

    ----------------------------------------------------------------
    -- PAQUETE FOB
    ----------------------------------------------------------------
    FOB_PACKAGE = {
        enabled = true,
        ctldOutpost = true,
        ctldWatchtower = true,

        farp = {
            enabled = true,
            mode = "static_heliport_editor_style",

            -- V2.6.2: segun el inspector del FARP del editor:
            -- type="FARP", shape_name="FARPS", category="Heliports".
            type = "FARP",
            shape_name = "FARPS",
            category = "Heliports",
            fallbackTypes = {
                -- Para esta prueba dejamos FARP como el camino principal.
                -- "Helipad Single"
            },

            offsetX = 70,
            offsetZ = 50,
            heading = 0,

            -- Radio/ATC del heliport.
            frequency = 127.5,
            modulation = 0,
            callsign = 1,

            -- Caracteristicas solicitadas.
            dynamicSpawn = true,
            allowHotStart = true,
            dynamicCargo = true,

            unlimitedFuel = true,
            unlimitedMunitions = true,
            unlimitedAircrafts = true,

            -- Intentamos registrar/alimentar el warehouse del static heliport.
            -- Esto sirve para diagnosticar si el bloqueo esta en:
            -- 1) StaticObject/Unit/Airbase.getByName
            -- 2) Warehouse
            -- 3) UI de Dynamic Slots
            touchWarehouse = true,

            warehouse = {
                enabled = true,

                -- Reintentos porque el Airbase/Warehouse puede tardar segundos en aparecer.
                applyDelay = 2,
                retryCount = 12,
                retryInterval = 2,

                -- Reaplica cada EXPORT_INTERVAL mientras el FOB este vivo.
                repeatTopupOnExport = true,

                -- V2.6.6: formato igual al JSON que devuelve DCS Warehouse:getInventory().
                -- aircraft = { ["UH-1H"] = 100 }
                -- weapon   = { ["weapons.adapters.lau-88"] = 100 }
                -- No usamos wsType aqui.
                aircraftAmount = 100,
                weaponAmount = 100,

                liquids = {
                    [0] = 999999999, -- jet_fuel
                    [1] = 999999999, -- gasoline
                    [2] = 999999999, -- methanol_mixture
                    [3] = 999999999  -- diesel
                },

                aircraft = {
                    ["UH-1H"] = 9999,
                    ["AH-64D_BLK_II"] = 9999,
                    ["OH58D"] = 9999,
                    ["CH-47Fbl1"] = 9999,
                    --["UH-60L"] = 9999,
                    ["SA342L"] = 9999,
                    ["SA342M"] = 9999,
                    ["SA342Minigun"] = 9999,
                    ["Mi-24P"] = 9999,
                    ["Ka-50_3"] = 9999,
                    ["Mi-8MT"] = 9999,
                    
                },

                -- DCS lo devuelve como inventory.weapon, por eso usamos singular.
                -- Puedes dejarlo vacio o pegar aqui exactamente lo que exporte DCS.
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
    },

    ----------------------------------------------------------------
    -- DRONES
    ----------------------------------------------------------------
    PROTECT_DRONES_ON_RESTORE = true,
    DRONE_PROTECTION_RETRIES = 10,
    DRONE_PROTECTION_INTERVAL = 1,
    DRONE_DEFAULT_SPEED = 80,

    ----------------------------------------------------------------
    -- FILTRO DE GUARDADO DE GRUPOS CTLD
    ----------------------------------------------------------------
    SAVE_MODE = "all", -- all | categories | units

    SAVE_CATEGORIES = {
        ["SAM Corto Alcance"] = false,
        ["SAM Medio Alcance"] = true,
        ["SAM Largo Alcance"] = false,
        ["Vehiculos de Combate"] = false,
        ["Soporte Logistico"] = true,
        ["Artilleria"] = false,
        ["Drones"] = true
    },

    SAVE_FOBS = true,

    SAVE_UNITS = {
        ["Hummer"] = true,
        ["SKP-11"] = true,
        ["MQ-9 Reaper"] = true,
        ["RQ-1A Predator"] = true
    },

    IGNORE_UNITS = {}
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
    byHeliportName = {},

    injectedThisSession = {},
    injectedFobsThisSession = {},

    wrapperInstalled = false,
    fobWrapperInstalled = false,
    eventHandlerRegistered = false,
    suppressFobCapture = false
}

----------------------------------------------------------------
-- LOG
----------------------------------------------------------------
local function log(msg, time)
    env.info("[CTLD_PERSIST] " .. tostring(msg))
    if CTDP.CONFIG.DEBUG then
        trigger.action.outText("[CTLD_PERSIST] " .. tostring(msg), time or 8)
    end
end

local function warn(msg)
    env.info("[CTLD_PERSIST] " .. tostring(msg))
end

----------------------------------------------------------------
-- UTILS
----------------------------------------------------------------
local function now()
    return timer.getTime()
end

local function deepCopy(tbl)
    if mist and mist.utils and mist.utils.deepCopy then
        return mist.utils.deepCopy(tbl)
    end
    if type(tbl) ~= "table" then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = deepCopy(v) end
    return out
end

local function safeReadFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local txt = f:read("*a")
    f:close()
    return txt
end

local function ensureDirectoryForFile(path)
    if not lfs or not lfs.mkdir or not path or path == "" then return false end
    local separator = path:find("/") and "/" or "\\"
    local parts = {}
    for part in string.gmatch(path, "[^\\/]+") do parts[#parts + 1] = part end
    if #parts <= 1 then return false end
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

local function sortedKeys(tbl)
    local keys = {}
    for k, _ in pairs(tbl or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
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
    if next(value) == nil then return "{}" end

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

local function lowerText(v)
    return string.lower(tostring(v or ""))
end

local function insertUnique(list, value)
    if not list or not value or value == "" then return false end
    for _, current in ipairs(list) do
        if current == value then return false end
    end
    table.insert(list, value)
    return true
end

local function removeFromList(list, value)
    if not list or not value then return end
    local i = 1
    while i <= #list do
        if list[i] == value then table.remove(list, i) else i = i + 1 end
    end
end

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

local function airbaseExistsByName(name)
    if not name or name == "" or not Airbase or not Airbase.getByName then return nil end
    local ok, ab = pcall(function() return Airbase.getByName(name) end)
    if ok and ab then return ab end
    return nil
end

local function unitAlive(unit)
    if not unit then return false end
    local okExist, exists = pcall(function() return unit:isExist() end)
    if not okExist or not exists then return false end
    local okLife, life = pcall(function() return unit:getLife() end)
    if not okLife then return false end
    return (tonumber(life) or 0) > 0
end

local function groupHasAliveUnits(groupName)
    local grp = groupExistsByName(groupName)
    if not grp then return false end
    local ok, units = pcall(function() return grp:getUnits() end)
    if not ok or not units then return false end
    for _, unit in ipairs(units) do
        if unitAlive(unit) then return true end
    end
    return false
end

local function staticAlive(staticName)
    local st = staticExistsByName(staticName)
    if not st then return false end
    local okLife, life = pcall(function() return st:getLife() end)
    if okLife and tonumber(life) then return tonumber(life) > 0 end
    return true
end

local function getObjectName(obj)
    if not obj then return nil end
    local ok, name = pcall(function() return obj:getName() end)
    if ok then return name end
    return nil
end

local function getGroupName(group)
    return getObjectName(group)
end

local function getUnitName(unit)
    return getObjectName(unit)
end

local function getUnitType(unit)
    if not unit then return nil end
    local ok, typeName = pcall(function() return unit:getTypeName() end)
    if ok then return typeName end
    return nil
end

local function getObjectPoint(obj)
    if not obj then return nil end
    local ok, point = pcall(function() return obj:getPoint() end)
    if ok and point then
        return { x = tonumber(point.x) or 0, y = tonumber(point.y) or 0, z = tonumber(point.z) or 0 }
    end
    return nil
end

local function getUnitHeading(unit)
    if mist and mist.getHeading then
        local ok, heading = pcall(function() return mist.getHeading(unit, true) end)
        if ok and tonumber(heading) then return tonumber(heading) end
    end
    local ok, pos = pcall(function() return unit:getPosition() end)
    if ok and pos and pos.x then
        local h = 0
        if math.atan2 then h = math.atan2(pos.x.z, pos.x.x) else h = math.atan(pos.x.z, pos.x.x) end
        if h < 0 then h = h + math.pi * 2 end
        return h
    end
    return 0
end

local function getUnitLife(unit)
    local life, life0 = 0, 0
    local okLife, resultLife = pcall(function() return unit:getLife() end)
    if okLife and tonumber(resultLife) then life = tonumber(resultLife) end
    local okLife0, resultLife0 = pcall(function() return unit:getLife0() end)
    if okLife0 and tonumber(resultLife0) then life0 = tonumber(resultLife0) end
    return life, life0
end

local function getCoalitionCountryFromObject(obj)
    local coalitionValue = 2
    local countryValue = country.id.USA or 2
    if obj then
        local okCoal, coal = pcall(function() return obj:getCoalition() end)
        if okCoal and tonumber(coal) then coalitionValue = tonumber(coal) end
        local okCountry, countryResult = pcall(function() return obj:getCountry() end)
        if okCountry and tonumber(countryResult) then countryValue = tonumber(countryResult) end
    end
    return coalitionValue, countryValue
end

local function getCoalitionFromCountry(countryValue)
    if coalition and coalition.getCountryCoalition then
        local ok, result = pcall(function() return coalition.getCountryCoalition(countryValue) end)
        if ok and tonumber(result) then return tonumber(result) end
    end
    return 2
end

local function destroyStaticIfExists(name)
    local st = staticExistsByName(name)
    if st then pcall(function() st:destroy() end) end
end

local function destroyGroupIfExists(groupName)
    local grp = groupExistsByName(groupName)
    if grp then pcall(function() grp:destroy() end) end
end

local function makeRuntimeName(id)
    return CTDP.CONFIG.RUNTIME_PREFIX .. tostring(id)
end

local function makeFobRuntimeName(id)
    return CTDP.CONFIG.FOB_RUNTIME_PREFIX .. tostring(id)
end

local function getFarpSequenceIndex(fob)
    if fob then
        local n = tonumber(fob.id) or tonumber(fob.fobId) or tonumber(fob.key)
        if n then
            return math.max(1, math.floor(n))
        end

        local candidates = {
            tostring(fob.id or ""),
            tostring(fob.runtimeStaticName or ""),
            tostring(fob.name or "")
        }

        for _, txt in ipairs(candidates) do
            local digits = txt:match("(%d+)$")
            if digits then
                local parsed = tonumber(digits)
                if parsed then
                    return math.max(1, math.floor(parsed))
                end
            end
        end
    end

    return mist.getNextUnitId()
end

local function makeHeliportRuntimeName(fob)
    local mode = tostring(CTDP.CONFIG.FARP_NAME_MODE or "")

    if mode == "ALFA_ZULU" then
        local list = CTDP.CONFIG.FARP_NAME_LIST or {}
        local count = #list

        if count > 0 then
            local idx = getFarpSequenceIndex(fob)
            local pos = ((idx - 1) % count) + 1
            local cycle = math.floor((idx - 1) / count) + 1
            local base = tostring(list[pos]) .. " FARP"

            if cycle > 1 then
                return base .. " " .. tostring(cycle)
            end

            return base
        end
    end

    local base = tostring(fob.runtimeStaticName or makeFobRuntimeName(fob.id))
    return base .. tostring(CTDP.CONFIG.HELIPORT_RUNTIME_SUFFIX or "_HELIPORT")
end

----------------------------------------------------------------
-- JSON STATE
----------------------------------------------------------------
local function createEmptyDoc()
    return {
        meta = {
            source = "HDEV CTLD Deployment Persistence",
            version = "2.6.6",
            missionTime = now(),
            updatedBy = "DCS"
        },
        counters = { nextId = 1, nextFobId = 1 },
        deployments = {},
        fobs = {}
    }
end

local function cleanRuntimeFields(doc)
    if not doc then return end
    if type(doc.deployments) == "table" then
        for _, dep in pairs(doc.deployments or {}) do dep.injectedThisSession = nil end
    end
    if type(doc.fobs) == "table" then
        for _, fob in pairs(doc.fobs or {}) do fob.injectedThisSession = nil end
    end
end

local function normalizeDoc(doc)
    if type(doc) ~= "table" then doc = createEmptyDoc() end
    doc.meta = doc.meta or {}
    doc.counters = doc.counters or {}
    doc.deployments = doc.deployments or {}
    doc.fobs = doc.fobs or {}
    cleanRuntimeFields(doc)
    if not tonumber(doc.counters.nextId) then doc.counters.nextId = 1 end
    if not tonumber(doc.counters.nextFobId) then doc.counters.nextFobId = 1 end
    return doc
end

local function loadState()
    local txt = safeReadFile(CTDP.CONFIG.FILE_PATH)
    if not txt then
        CTDP.STATE.doc = createEmptyDoc()
        CTDP.STATE.dirty = true
        log("JSON no existe. Se creara uno nuevo.", 8)
        return
    end
    local data, err = decodeJson(txt)
    if not data then
        CTDP.STATE.doc = createEmptyDoc()
        CTDP.STATE.dirty = true
        log("No se pudo leer JSON. Se creara uno nuevo. Error: " .. tostring(err), 10)
        return
    end
    CTDP.STATE.doc = normalizeDoc(data)
    log("JSON cargado correctamente.", 6)
end

local function writeState(force)
    if not CTDP.STATE.doc then CTDP.STATE.doc = createEmptyDoc() end
    cleanRuntimeFields(CTDP.STATE.doc)
    if not force and not CTDP.STATE.dirty then return true end

    CTDP.STATE.doc.meta = CTDP.STATE.doc.meta or {}
    CTDP.STATE.doc.meta.source = "HDEV CTLD Deployment Persistence"
    CTDP.STATE.doc.meta.version = "2.6.6"
    CTDP.STATE.doc.meta.missionTime = now()
    CTDP.STATE.doc.meta.updatedBy = "DCS"
    CTDP.STATE.doc.meta.injectDuration = CTDP.CONFIG.INJECT_DURATION
    CTDP.STATE.doc.meta.exportInterval = CTDP.CONFIG.EXPORT_INTERVAL
    CTDP.STATE.doc.meta.saveFobs = CTDP.CONFIG.SAVE_FOBS
    CTDP.STATE.doc.meta.fobPackage = CTDP.CONFIG.FOB_PACKAGE and true or false
    CTDP.STATE.doc.meta.farpMode = CTDP.CONFIG.FOB_PACKAGE and CTDP.CONFIG.FOB_PACKAGE.farp and CTDP.CONFIG.FOB_PACKAGE.farp.mode or nil

    local txt = encodeJsonValue(CTDP.STATE.doc, 0)
    local ok = safeWriteFile(CTDP.CONFIG.FILE_PATH, txt)
    if ok then
        CTDP.STATE.dirty = false
        CTDP.STATE.lastExport = now()
        return true
    end
    warn("No se pudo escribir JSON: " .. tostring(CTDP.CONFIG.FILE_PATH))
    return false
end

local function nextDeploymentId()
    local doc = CTDP.STATE.doc or createEmptyDoc()
    CTDP.STATE.doc = doc
    doc.counters = doc.counters or {}
    doc.deployments = doc.deployments or {}
    local n = tonumber(doc.counters.nextId) or 1
    local id
    repeat
        id = string.format("CTLD_DEPLOY_%06d", n)
        n = n + 1
    until not doc.deployments[id]
    doc.counters.nextId = n
    return id
end

local function nextFobId()
    local doc = CTDP.STATE.doc or createEmptyDoc()
    CTDP.STATE.doc = doc
    doc.counters = doc.counters or {}
    doc.fobs = doc.fobs or {}
    local n = tonumber(doc.counters.nextFobId) or 1
    local id
    repeat
        id = string.format("CTLD_FOB_%06d", n)
        n = n + 1
    until not doc.fobs[id]
    doc.counters.nextFobId = n
    return id
end

----------------------------------------------------------------
-- INDICES CTLD
----------------------------------------------------------------
local function buildCtldIndexes()
    CTDP.STATE.unitToCategory = {}
    CTDP.STATE.unitToCrate = {}
    for categoryName, list in pairs(ctld.spawnableCrates or {}) do
        for _, crate in ipairs(list or {}) do
            if crate.unit then
                CTDP.STATE.unitToCategory[tostring(crate.unit)] = tostring(categoryName)
                CTDP.STATE.unitToCrate[tostring(crate.unit)] = {
                    categoryName = tostring(categoryName),
                    unit = crate.unit,
                    desc = crate.desc,
                    weight = crate.weight,
                    cratesRequired = crate.cratesRequired,
                    side = crate.side
                }
            end
        end
    end
    log("Indice CTLD construido. Unidades indexadas: " .. tostring(#sortedKeys(CTDP.STATE.unitToCategory)), 6)
end

local function getCategoryForUnitType(typeName)
    if not typeName then return nil end
    return CTDP.STATE.unitToCategory[tostring(typeName)]
end

local function getCrateInfoForUnitType(typeName)
    if not typeName then return nil end
    return CTDP.STATE.unitToCrate[tostring(typeName)]
end

local function shouldPersistTypes(types)
    if CTDP.CONFIG.SAVE_MODE == "all" then return true, "all" end
    for _, typeName in ipairs(types or {}) do
        local t = tostring(typeName or "")
        if t ~= "" and not CTDP.CONFIG.IGNORE_UNITS[t] then
            if CTDP.CONFIG.SAVE_UNITS[t] then return true, "unit:" .. t end
            local categoryName = getCategoryForUnitType(t)
            if CTDP.CONFIG.SAVE_MODE == "categories" and categoryName and CTDP.CONFIG.SAVE_CATEGORIES[categoryName] == true then
                return true, "category:" .. categoryName
            end
        end
    end
    if CTDP.CONFIG.SAVE_MODE == "units" then return false, "no unit match" end
    return false, "no category match"
end

----------------------------------------------------------------
-- ROLES CTLD / DRONES / JTAC
----------------------------------------------------------------
local function isCtldJtacType(typeName)
    if not typeName then return false end
    local t = lowerText(typeName)
    for _, jtacPattern in ipairs(ctld.jtacUnitTypes or {}) do
        local p = lowerText(jtacPattern)
        if p ~= "" and string.find(t, p, 1, true) then return true end
    end
    return false
end

local function isCtldDroneType(typeName)
    local t = tostring(typeName or "")
    local tl = string.lower(t)
    return t == "MQ-9 Reaper"
        or t == "RQ-1A Predator"
        or string.find(tl, "mq%-9", 1, false) ~= nil
        or string.find(tl, "rq%-1", 1, false) ~= nil
        or string.find(tl, "reaper", 1, true) ~= nil
        or string.find(tl, "predator", 1, true) ~= nil
end

local function deploymentContainsDrone(dep)
    if not dep then return false end
    if dep.ctldRole == "DRONE_JTAC" then return true end
    if dep.crateUnit and isCtldDroneType(dep.crateUnit) then return true end
    for _, typeName in ipairs(dep.types or {}) do if isCtldDroneType(typeName) then return true end end
    if dep.groupData and dep.groupData.units then
        for _, unitData in ipairs(dep.groupData.units) do if isCtldDroneType(unitData.type) then return true end end
    end
    return false
end

local function deploymentContainsJtac(dep)
    if not dep then return false end
    if dep.ctldRole == "JTAC" or dep.ctldRole == "DRONE_JTAC" then return true end
    if dep.crateUnit and isCtldJtacType(dep.crateUnit) then return true end
    for _, typeName in ipairs(dep.types or {}) do if isCtldJtacType(typeName) then return true end end
    if dep.groupData and dep.groupData.units then
        for _, unitData in ipairs(dep.groupData.units) do if isCtldJtacType(unitData.type) then return true end end
    end
    if deploymentContainsDrone(dep) then return true end
    return false
end

local function getFreshLaserCode()
    ctld.jtacGeneratedLaserCodes = ctld.jtacGeneratedLaserCodes or {}
    local code = table.remove(ctld.jtacGeneratedLaserCodes, 1)
    if code then
        table.insert(ctld.jtacGeneratedLaserCodes, code)
        return tonumber(code)
    end
    return 1688
end

----------------------------------------------------------------
-- DRONE PROTECTION
----------------------------------------------------------------
local function buildDroneOrbitRoute(x, z)
    local alt = tonumber(ctld.jtacDroneAltitude) or 2000
    local speed = tonumber(CTDP.CONFIG.DRONE_DEFAULT_SPEED) or 80
    return {
        points = {
            [1] = {
                alt = alt,
                action = "Turning Point",
                alt_type = "BARO",
                properties = { addopt = {} },
                speed = speed,
                task = {
                    id = "ComboTask",
                    params = {
                        tasks = {
                            [1] = {
                                enabled = true,
                                auto = false,
                                id = "WrappedAction",
                                number = 1,
                                params = { action = { id = "EPLRS", params = { value = true, groupId = 0 } } }
                            },
                            [2] = {
                                number = 2,
                                auto = false,
                                id = "Orbit",
                                enabled = true,
                                params = { altitude = alt, pattern = "Circle", speed = speed }
                            },
                            [3] = {
                                enabled = true,
                                auto = false,
                                id = "WrappedAction",
                                number = 3,
                                params = { action = { id = "Option", params = { value = true, name = 6 } } }
                            }
                        }
                    }
                },
                type = "Turning Point",
                ETA = 0,
                ETA_locked = true,
                y = z,
                x = x,
                speed_locked = true,
                formation_template = ""
            }
        }
    }
end

local function setControllerCommandSafe(controller, commandId, value)
    if not controller then return false end
    local ok = pcall(function()
        controller:setCommand({ id = commandId, params = { value = value } })
    end)
    return ok
end

local function setAirOptionSafe(controller, optionId, optionValue)
    if not controller or optionId == nil or optionValue == nil then return false end
    local ok = pcall(function() controller:setOption(optionId, optionValue) end)
    return ok
end

local function protectControllerAsDrone(controller)
    if not controller then return false end
    setControllerCommandSafe(controller, "SetImmortal", true)
    setControllerCommandSafe(controller, "SetInvisible", true)
    setControllerCommandSafe(controller, "SetUnlimitedFuel", true)
    if AI and AI.Option and AI.Option.Air and AI.Option.Air.id and AI.Option.Air.val then
        if AI.Option.Air.id.ROE and AI.Option.Air.val.ROE then
            setAirOptionSafe(controller, AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_HOLD)
        end
        if AI.Option.Air.id.REACTION_ON_THREAT and AI.Option.Air.val.REACTION_ON_THREAT then
            setAirOptionSafe(controller, AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.NO_REACTION)
        end
    end
    return true
end

local function applyDroneProtectionNow(dep, groupName)
    if CTDP.CONFIG.PROTECT_DRONES_ON_RESTORE ~= true then return false end
    if not deploymentContainsDrone(dep) then return false end
    local grp = Group.getByName(groupName)
    if not grp or not grp:isExist() then return false end

    local okGroupController, groupController = pcall(function() return grp:getController() end)
    if okGroupController and groupController then protectControllerAsDrone(groupController) end

    local units = grp:getUnits() or {}
    for _, unit in ipairs(units) do
        if unit and unit:isExist() and unit.getController then
            local okUnitController, unitController = pcall(function() return unit:getController() end)
            if okUnitController and unitController then protectControllerAsDrone(unitController) end
        end
    end

    dep.ctldRole = "DRONE_JTAC"
    dep.droneProtected = true
    dep.updatedAt = now()
    CTDP.STATE.dirty = true
    env.info("[CTLD_PERSIST] Proteccion aplicada a dron: " .. tostring(groupName))
    if CTDP.CONFIG.DEBUG then trigger.action.outText("[CTLD_PERSIST] Proteccion aplicada a dron: " .. tostring(groupName), 6) end
    return true
end

local function scheduleDroneProtection(dep, groupName)
    if not dep or not groupName or not deploymentContainsDrone(dep) then return end
    local retries = tonumber(CTDP.CONFIG.DRONE_PROTECTION_RETRIES) or 10
    local interval = tonumber(CTDP.CONFIG.DRONE_PROTECTION_INTERVAL) or 1
    for i = 0, retries do
        timer.scheduleFunction(function()
            applyDroneProtectionNow(dep, groupName)
            return nil
        end, nil, timer.getTime() + (i * interval))
    end
end

----------------------------------------------------------------
-- RESTAURAR LOGICA CTLD RUNTIME
----------------------------------------------------------------
local function restoreJTACIfNeeded(dep, groupName)
    if not dep or not groupName or not ctld or not ctld.JTACStart then return false end
    if not deploymentContainsJtac(dep) then return false end

    local code = tonumber(dep.jtacLaserCode) or getFreshLaserCode() or 1688
    dep.jtacLaserCode = code
    dep.ctldRole = deploymentContainsDrone(dep) and "DRONE_JTAC" or "JTAC"

    timer.scheduleFunction(function()
        local grp = Group.getByName(groupName)
        if grp and grp:isExist() then
            applyDroneProtectionNow(dep, groupName)
            ctld.JTACStart(groupName, code)
            applyDroneProtectionNow(dep, groupName)
            env.info("[CTLD_PERSIST] JTAC restaurado: " .. tostring(groupName) .. " | code=" .. tostring(code))
            if CTDP.CONFIG.DEBUG then trigger.action.outText("[CTLD_PERSIST] JTAC restaurado: " .. tostring(groupName) .. " | code=" .. tostring(code), 8) end
        end
        return nil
    end, nil, timer.getTime() + 2)

    CTDP.STATE.dirty = true
    return true
end

local function restoreAASystemIfNeeded(dep, groupName)
    if not dep or not groupName or not ctld then return false end
    if not ctld.getAATemplate or not ctld.getAASystemDetails then return false end
    local grp = Group.getByName(groupName)
    if not grp or not grp:isExist() then return false end

    local units = grp:getUnits() or {}
    local selectedTemplate = nil
    for _, unit in ipairs(units) do
        if unit and unit:isExist() and unit:getLife() > 0 then
            local aaTemplate = ctld.getAATemplate(unit:getTypeName())
            if aaTemplate then selectedTemplate = aaTemplate break end
        end
    end
    if not selectedTemplate then return false end

    ctld.completeAASystems = ctld.completeAASystems or {}
    ctld.completeAASystems[groupName] = ctld.getAASystemDetails(grp, selectedTemplate)
    dep.ctldRole = "AA_SYSTEM"
    dep.ctldAASystemName = selectedTemplate.name or "AA_SYSTEM"
    CTDP.STATE.dirty = true
    log("Sistema AA restaurado en CTLD: " .. tostring(groupName) .. " | sistema=" .. tostring(dep.ctldAASystemName), 8)
    return true
end

local function restoreCtldRuntimeForDeployment(dep, groupName)
    if not dep or not groupName then return end
    local protectedDrone = applyDroneProtectionNow(dep, groupName)
    local restoredJtac = restoreJTACIfNeeded(dep, groupName)
    local restoredAA = restoreAASystemIfNeeded(dep, groupName)
    if protectedDrone or restoredJtac or restoredAA then writeState(true) end
end

----------------------------------------------------------------
-- CAPTURA DE GRUPOS CTLD
----------------------------------------------------------------
local function captureGroupData(group, forcedName)
    if not group then return nil end
    local groupName = forcedName or getGroupName(group)
    if not groupName then return nil end
    local okUnits, units = pcall(function() return group:getUnits() end)
    if not okUnits or not units or #units == 0 then return nil end

    local groupCategory = Group.Category.GROUND
    local okCat, cat = pcall(function() return group:getCategory() end)
    if okCat and cat ~= nil then groupCategory = cat end

    local firstAliveUnit = nil
    for _, unit in ipairs(units) do if unitAlive(unit) then firstAliveUnit = unit break end end
    firstAliveUnit = firstAliveUnit or units[1]

    local coalitionValue, countryValue = getCoalitionCountryFromObject(firstAliveUnit)
    local groupData = {
        visible = false,
        hidden = false,
        name = groupName,
        task = groupCategory == Group.Category.AIRPLANE and "Reconnaissance" or "Ground Nothing",
        tasks = {},
        route = {},
        units = {},
        category = groupCategory,
        country = countryValue
    }

    local unitTypes = {}
    for i, unit in ipairs(units) do
        if unitAlive(unit) then
            local p = unit:getPoint()
            local typeName = getUnitType(unit)
            local life, life0 = getUnitLife(unit)
            unitTypes[#unitTypes + 1] = typeName
            local unitData = {
                type = typeName,
                name = getUnitName(unit) or (groupName .. "_U" .. tostring(i)),
                x = p.x,
                y = p.z,
                heading = getUnitHeading(unit),
                skill = "Excellent",
                life = life,
                life0 = life0
            }
            if groupCategory == Group.Category.AIRPLANE then
                unitData.alt = p.y
                unitData.alt_type = "BARO"
                unitData.speed = tonumber(CTDP.CONFIG.DRONE_DEFAULT_SPEED) or 80
            end
            groupData.units[#groupData.units + 1] = unitData
        end
    end
    if #groupData.units == 0 then return nil end
    return groupData, coalitionValue, countryValue, groupCategory, unitTypes
end

local function deploymentAlreadyExistsForGroup(groupName)
    if not groupName or not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then return nil end
    for id, dep in pairs(CTDP.STATE.doc.deployments) do
        if dep.originalGroupName == groupName or dep.activeGroupName == groupName or dep.runtimeGroupName == groupName then return id end
    end
    return nil
end

local function indexDeployment(dep)
    if not dep or not dep.id then return end
    for _, name in ipairs({ dep.originalGroupName, dep.activeGroupName, dep.runtimeGroupName }) do
        if name and name ~= "" then CTDP.STATE.byGroupName[name] = dep.id end
    end
    if dep.groupData and dep.groupData.units then
        for _, unitData in ipairs(dep.groupData.units) do
            if unitData.name then CTDP.STATE.byUnitName[unitData.name] = dep.id end
        end
    end
    if dep.runtimeGroupName then
        for i = 1, 40 do CTDP.STATE.byUnitName[dep.runtimeGroupName .. "_U" .. tostring(i)] = dep.id end
    end
end

local function indexFob(fob)
    if not fob or not fob.id then return end
    for _, name in ipairs({ fob.originalStaticName, fob.activeStaticName, fob.runtimeStaticName, fob.fobName }) do
        if name and name ~= "" then CTDP.STATE.byStaticName[name] = fob.id end
    end
    if fob.package and fob.package.farp then
        for _, name in ipairs({ fob.package.farp.name, fob.package.farp.groupName, fob.package.farp.unitName }) do
            if name and name ~= "" then
                CTDP.STATE.byHeliportName[name] = fob.id
                CTDP.STATE.byStaticName[name] = fob.id
            end
        end
    end
end

local function rebuildIndexes()
    CTDP.STATE.byGroupName = {}
    CTDP.STATE.byUnitName = {}
    CTDP.STATE.byStaticName = {}
    CTDP.STATE.byHeliportName = {}
    if CTDP.STATE.doc and CTDP.STATE.doc.deployments then
        for _, dep in pairs(CTDP.STATE.doc.deployments) do indexDeployment(dep) end
    end
    if CTDP.STATE.doc and CTDP.STATE.doc.fobs then
        for _, fob in pairs(CTDP.STATE.doc.fobs) do indexFob(fob) end
    end
end

local function recordCtldSpawnedGroup(groupName, typesFromCtld, heliName)
    if CTDP.STATE.injecting then return end
    local group = groupExistsByName(groupName)
    if not group then log("No se pudo capturar. Grupo no existe: " .. tostring(groupName), 8) return end

    local groupData, coalitionValue, countryValue, groupCategory, unitTypes = captureGroupData(group, groupName)
    if not groupData then log("No se pudo capturar groupData: " .. tostring(groupName), 8) return end

    local typesToEvaluate = {}
    for _, t in ipairs(typesFromCtld or {}) do if t then typesToEvaluate[#typesToEvaluate + 1] = t end end
    for _, t in ipairs(unitTypes or {}) do if t then typesToEvaluate[#typesToEvaluate + 1] = t end end

    local allowed, reason = shouldPersistTypes(typesToEvaluate)
    if not allowed then
        if CTDP.CONFIG.DEBUG then log("Ignorado por filtro: " .. tostring(groupName) .. " | " .. tostring(reason), 6) end
        return
    end

    local existingId = deploymentAlreadyExistsForGroup(groupName)
    if existingId then
        local existing = CTDP.STATE.doc.deployments[existingId]
        if existing then
            existing.alive = true
            existing.activeGroupName = groupName
            existing.groupData = groupData
            existing.coalition = coalitionValue
            existing.country = countryValue
            existing.groupCategory = groupCategory
            existing.lastSeenAt = now()
            existing.updatedAt = now()
            existing.lastReason = reason
            existing.injectedThisSession = nil
            if deploymentContainsDrone(existing) then
                existing.ctldRole = "DRONE_JTAC"
                existing.jtacLaserCode = existing.jtacLaserCode or getFreshLaserCode()
            elseif deploymentContainsJtac(existing) then
                existing.ctldRole = "JTAC"
                existing.jtacLaserCode = existing.jtacLaserCode or getFreshLaserCode()
            end
            indexDeployment(existing)
            CTDP.STATE.dirty = true
            writeState(true)
            log("Despliegue actualizado: " .. tostring(existingId) .. " | " .. tostring(reason), 8)
        end
        return
    end

    local id = nextDeploymentId()
    local runtimeName = makeRuntimeName(id)
    local mainType, mainCategory, mainDesc, mainWeight = nil, nil, nil, nil
    for _, t in ipairs(typesToEvaluate) do
        local info = getCrateInfoForUnitType(t)
        if info then
            mainType = info.unit
            mainCategory = info.categoryName
            mainDesc = info.desc
            mainWeight = info.weight
            break
        end
    end

    local dep = {
        id = id,
        enabled = true,
        alive = true,
        source = "CTLD",
        captureMethod = "spawnCrateGroup_wrapper",
        reason = reason,
        crateUnit = mainType,
        crateDesc = mainDesc,
        crateWeight = mainWeight,
        categoryName = mainCategory,
        originalGroupName = groupName,
        activeGroupName = groupName,
        runtimeGroupName = runtimeName,
        heliName = heliName,
        coalition = coalitionValue,
        country = countryValue,
        groupCategory = groupCategory,
        createdAt = now(),
        updatedAt = now(),
        lastSeenAt = now(),
        destroyedAt = nil,
        destroyReason = nil,
        types = typesToEvaluate,
        groupData = groupData
    }

    if deploymentContainsDrone(dep) then
        dep.ctldRole = "DRONE_JTAC"
        dep.jtacLaserCode = getFreshLaserCode()
        dep.droneProtected = false
    elseif deploymentContainsJtac(dep) then
        dep.ctldRole = "JTAC"
        dep.jtacLaserCode = getFreshLaserCode()
    end

    CTDP.STATE.doc.deployments[id] = dep
    indexDeployment(dep)
    CTDP.STATE.dirty = true
    writeState(true)
    log("Despliegue CTLD guardado: " .. tostring(id) .. " | grupo=" .. tostring(groupName) .. " | " .. tostring(reason), 10)
end

----------------------------------------------------------------
-- FOB PACKAGE: STATIC HELIPORT / FARP ESTILO MISSION EDITOR
----------------------------------------------------------------
local function getFobPackageConfig()
    return CTDP.CONFIG.FOB_PACKAGE or {}
end

local function getFobFarpConfig()
    local pkg = getFobPackageConfig()
    return pkg.farp or {}
end

local function fobPackageEnabled()
    local pkg = getFobPackageConfig()
    return pkg.enabled == true
end

local function fobPackageFarpEnabled()
    local farp = getFobFarpConfig()
    return fobPackageEnabled() and farp.enabled == true
end

local function getFarpPointForFob(fob, fobPoint)
    if not fobPoint then return nil end
    local farpCfg = getFobFarpConfig()
    local ox = tonumber(farpCfg.offsetX) or 90
    local oz = tonumber(farpCfg.offsetZ) or 0
    return {
        x = (tonumber(fobPoint.x) or 0) + ox,
        y = tonumber(fobPoint.y) or 0,
        z = (tonumber(fobPoint.z) or 0) + oz
    }
end

local function getDistance2D(a, b)
    if not a or not b then return 999999999 end
    local ax = tonumber(a.x) or 0
    local az = tonumber(a.z) or tonumber(a.y) or 0
    local bx = tonumber(b.x) or 0
    local bz = tonumber(b.z) or tonumber(b.y) or 0
    local dx, dz = ax - bx, az - bz
    return math.sqrt(dx * dx + dz * dz)
end

local function buildFarpTypeList()
    local farpCfg = getFobFarpConfig()
    local list = {}

    -- V2.6.2: el FARP real del editor exportado por el inspector usa type="FARP".
    -- Por eso FARP siempre va primero, aunque el usuario cambie la config por error.
    list[#list + 1] = "FARP"

    if farpCfg.type and farpCfg.type ~= "" and farpCfg.type ~= "FARP" then
        list[#list + 1] = farpCfg.type
    end

    for _, t in ipairs(farpCfg.fallbackTypes or {}) do
        if t and t ~= "" then
            local exists = false
            for _, current in ipairs(list) do
                if current == t then exists = true break end
            end
            if not exists then list[#list + 1] = t end
        end
    end

    return list
end

local function getShapeNameForFarpType(farpType)
    local farpCfg = getFobFarpConfig()

    if farpType == "FARP" then
        return farpCfg.shape_name or "FARPS"
    end

    if farpType == "Helipad Single" then
        return "farp"
    end

    if farpType == "Invisible FARP" then
        return farpCfg.shape_name or "FARPS"
    end

    return farpCfg.shape_name or "FARPS"
end

local function normalizeHeliportFrequency(freq)
    local f = tonumber(freq) or 127.5

    -- El FARP del editor exportado tiene heliport_frequency = 127.5.
    -- Si alguien pasa 127500000 por versiones anteriores, lo convertimos a MHz.
    if f > 1000000 then
        f = f / 1000000
    end

    return f
end

local function ensureFobPackageFields(fob)
    if not fob then return end
    fob.package = fob.package or {}
    fob.package.enabled = fobPackageEnabled()
    fob.package.ctldOutpost = true
    fob.package.ctldWatchtower = true

    local farpCfg = getFobFarpConfig()
    local farpName = makeHeliportRuntimeName(fob)

    fob.package.farp = fob.package.farp or {}
    fob.package.farp.enabled = fobPackageFarpEnabled()
    fob.package.farp.mode = "static_heliport_editor_style"

    -- V2.6.2: mismo nombre para StaticObject / Unit / Airbase, como el Mission Editor.
    fob.package.farp.name = fob.package.farp.name or farpName
    fob.package.farp.groupName = fob.package.farp.groupName or fob.package.farp.name
    fob.package.farp.unitName = fob.package.farp.unitName or fob.package.farp.name

    fob.package.farp.offsetX = tonumber(farpCfg.offsetX) or 90
    fob.package.farp.offsetZ = tonumber(farpCfg.offsetZ) or 0
    fob.package.farp.heading = tonumber(farpCfg.heading) or 0
    fob.package.farp.frequency = normalizeHeliportFrequency(farpCfg.frequency)
    fob.package.farp.modulation = tonumber(farpCfg.modulation) or 0
    fob.package.farp.callsign = tonumber(farpCfg.callsign) or 1
    fob.package.farp.shape_name = farpCfg.shape_name or "FARPS"
    fob.package.farp.category = farpCfg.category or "Heliports"
    fob.package.farp.dynamicSpawn = farpCfg.dynamicSpawn == true
    fob.package.farp.allowHotStart = farpCfg.allowHotStart == true
    fob.package.farp.dynamicCargo = farpCfg.dynamicCargo == true
    fob.package.farp.unlimitedFuel = farpCfg.unlimitedFuel == true
    fob.package.farp.unlimitedMunitions = farpCfg.unlimitedMunitions == true
    fob.package.farp.unlimitedAircrafts = farpCfg.unlimitedAircrafts == true
    fob.package.farp.touchWarehouse = true
end

----------------------------------------------------------------
-- WAREHOUSE DEL STATIC HELIPORT
----------------------------------------------------------------
local function getRuntimeFarpWarehouseConfig()
    local farpCfg = getFobFarpConfig()
    return farpCfg.warehouse or {}
end

local function runtimeFarpWarehouseEnabled()
    local farpCfg = getFobFarpConfig()
    local whCfg = getRuntimeFarpWarehouseConfig()
    return farpCfg.touchWarehouse == true and whCfg.enabled == true
end

local function getRuntimeHeliportAirbase(farp)
    if not farp then return nil, nil end

    -- El inspector del FARP bueno mostro que Airbase.getByName usa el MISMO nombre.
    local names = {
        farp.name,
        farp.unitName,
        farp.groupName
    }

    for _, name in ipairs(names) do
        local ab = airbaseExistsByName(name)
        if ab then
            return ab, name
        end
    end

    return nil, nil
end

local function getWarehouseFromAirbase(ab)
    if not ab or not ab.getWarehouse then
        return nil, "airbase_without_getWarehouse"
    end

    local ok, wh = pcall(function()
        return ab:getWarehouse()
    end)

    if ok and wh then
        return wh, nil
    end

    return nil, tostring(wh)
end

local function safeWarehouseAddItem(warehouse, ws, amount)
    if not warehouse or not ws or amount == nil then
        return false, "missing_warehouse_ws_or_amount"
    end

    local qty = tonumber(amount) or 0
    if qty <= 0 then
        return false, "amount_zero"
    end

    if Warehouse and Warehouse.addItem then
        local ok, err = pcall(function()
            Warehouse.addItem(warehouse, ws, qty)
        end)

        if ok then
            return true, nil
        end

        local fallbackReason = tostring(err)

        if warehouse.setItem then
            local okSet, errSet = pcall(function()
                warehouse:setItem(ws, qty)
            end)

            if okSet then
                return true, nil
            end

            return false, fallbackReason .. " | setItem=" .. tostring(errSet)
        end

        return false, fallbackReason
    end

    if warehouse.setItem then
        local okSet, errSet = pcall(function()
            warehouse:setItem(ws, qty)
        end)

        if okSet then
            return true, nil
        end

        return false, tostring(errSet)
    end

    return false, "Warehouse.addItem_and_warehouse.setItem_not_available"
end

local function safeWarehouseSetItemName(warehouse, itemName, amount)
    if not warehouse or not warehouse.setItem then
        return false, "warehouse_without_setItem"
    end

    if type(itemName) ~= "string" or itemName == "" then
        return false, "invalid_item_name"
    end

    local qty = tonumber(amount) or 0

    local ok, err = pcall(function()
        warehouse:setItem(itemName, qty)
    end)

    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function isArrayTable(tbl)
    if type(tbl) ~= "table" then return false end
    local count = 0
    local maxIndex = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then return false end
        count = count + 1
        if k > maxIndex then maxIndex = k end
    end
    return count == maxIndex
end

local function safeWarehouseSetLiquid(warehouse, liquidId, amount)
    if not warehouse or not warehouse.setLiquidAmount then
        return false, "warehouse_without_setLiquidAmount"
    end

    local id = tonumber(liquidId)
    if id == nil then
        return false, "invalid_liquid_id"
    end

    local qty = tonumber(amount) or 0

    local ok, err = pcall(function()
        warehouse:setLiquidAmount(id, qty)
    end)

    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function applyRuntimeFarpWarehouseNow(fob)
    if not runtimeFarpWarehouseEnabled() then
        return false
    end

    if not fob or not fob.package or not fob.package.farp then
        return false
    end

    local farp = fob.package.farp
    local whCfg = getRuntimeFarpWarehouseConfig()

    local ab, abName = getRuntimeHeliportAirbase(farp)

    farp.airbaseRegistered = ab and true or false
    farp.airbaseName = abName

    if not ab then
        farp.warehouseRegistered = false
        farp.warehouseLastError = "airbase_not_registered"
        farp.warehouseUpdatedAt = now()
        CTDP.STATE.dirty = true
        return false
    end

    local warehouse, whErr = getWarehouseFromAirbase(ab)

    if not warehouse then
        farp.warehouseRegistered = false
        farp.warehouseLastError = "warehouse_not_available:" .. tostring(whErr)
        farp.warehouseUpdatedAt = now()
        CTDP.STATE.dirty = true
        return false
    end

    farp.warehouseRegistered = true
    farp.warehouseLastError = nil

    local liquidsOk = 0
    local liquidsFail = 0
    local itemsOk = 0
    local itemsFail = 0
    local errors = {}

    for liquidId, amount in pairs(whCfg.liquids or {}) do
        local ok, err = safeWarehouseSetLiquid(warehouse, liquidId, amount)

        if ok then
            liquidsOk = liquidsOk + 1
        else
            liquidsFail = liquidsFail + 1
            errors[#errors + 1] = "liquid " .. tostring(liquidId) .. ": " .. tostring(err)
        end
    end

    local function applyItemMapOrLegacyList(label, cfgTable, defaultAmount)
        if type(cfgTable) ~= "table" then
            return
        end

        if isArrayTable(cfgTable) then
            -- Compatibilidad con formato viejo: { label="UH-1H", ws={...}, amount=99 }
            for _, item in ipairs(cfgTable) do
                if type(item) == "table" and item.ws then
                    local ok, err = safeWarehouseAddItem(warehouse, item.ws, item.amount or defaultAmount)
                    if ok then
                        itemsOk = itemsOk + 1
                    else
                        itemsFail = itemsFail + 1
                        errors[#errors + 1] = label .. " " .. tostring(item.label or item.name or "?") .. ": " .. tostring(err)
                    end
                elseif type(item) == "string" then
                    local ok, err = safeWarehouseSetItemName(warehouse, item, defaultAmount)
                    if ok then
                        itemsOk = itemsOk + 1
                    else
                        itemsFail = itemsFail + 1
                        errors[#errors + 1] = label .. " " .. tostring(item) .. ": " .. tostring(err)
                    end
                end
            end
            return
        end

        -- Formato nuevo, igual al JSON DCS:
        -- aircraft = { ["UH-1H"] = 100 }
        -- weapon   = { ["weapons.adapters.lau-88"] = 100 }
        for itemName, amount in pairs(cfgTable) do
            local ok, err = safeWarehouseSetItemName(warehouse, itemName, amount)
            if ok then
                itemsOk = itemsOk + 1
            else
                itemsFail = itemsFail + 1
                errors[#errors + 1] = label .. " " .. tostring(itemName) .. ": " .. tostring(err)
            end
        end
    end

    applyItemMapOrLegacyList("aircraft", whCfg.aircraft or {}, whCfg.aircraftAmount or 100)
    applyItemMapOrLegacyList("weapon", whCfg.weapon or whCfg.weapons or {}, whCfg.weaponAmount or 100)

    farp.warehouseLiquidsOk = liquidsOk
    farp.warehouseLiquidsFail = liquidsFail
    farp.warehouseItemsOk = itemsOk
    farp.warehouseItemsFail = itemsFail
    farp.warehouseApplied = true
    farp.warehouseUpdatedAt = now()

    if #errors > 0 then
        farp.warehouseLastError = table.concat(errors, " | ")
    else
        farp.warehouseLastError = nil
    end

    CTDP.STATE.dirty = true

    log(
        "Warehouse aplicado a static heliport " .. tostring(farp.name) ..
        " | liquidsOK=" .. tostring(liquidsOk) ..
        " | itemsOK=" .. tostring(itemsOk) ..
        " | airbase=" .. tostring(farp.airbaseName),
        8
    )

    return true
end

local function scheduleRuntimeFarpWarehouseApply(fob)
    if not runtimeFarpWarehouseEnabled() then
        return
    end

    if not fob or not fob.package or not fob.package.farp then
        return
    end

    local whCfg = getRuntimeFarpWarehouseConfig()
    local delay = tonumber(whCfg.applyDelay) or 2
    local retryCount = tonumber(whCfg.retryCount) or 12
    local retryInterval = tonumber(whCfg.retryInterval) or 2

    for i = 1, retryCount do
        timer.scheduleFunction(function()
            applyRuntimeFarpWarehouseNow(fob)
            return nil
        end, nil, timer.getTime() + delay + ((i - 1) * retryInterval))
    end
end

local function unitExistsByNameLocal(name)
    if not name or not Unit or not Unit.getByName then return nil end
    local ok, u = pcall(function()
        return Unit.getByName(name)
    end)
    if ok and u then
        return u
    end
    return nil
end

local function findRuntimeHeliportObject(farp)
    if not farp then return nil, nil end

    local names = {
        farp.name,
        farp.unitName,
        farp.groupName
    }

    -- Orden del FARP real del editor: StaticObject, Unit, Airbase. Group normalmente es nil.
    for _, name in ipairs(names) do
        local st = staticExistsByName(name)
        if st then return st, "static" end
    end

    for _, name in ipairs(names) do
        local u = unitExistsByNameLocal(name)
        if u then return u, "unit" end
    end

    for _, name in ipairs(names) do
        local ab = airbaseExistsByName(name)
        if ab then return ab, "airbase" end
    end

    for _, name in ipairs(names) do
        local grp = groupExistsByName(name)
        if grp then return grp, "group" end
    end

    return nil, nil
end

local function destroyRuntimeHeliportForFob(fob)
    if not fob or not fob.package or not fob.package.farp then return end
    local farp = fob.package.farp

    -- El FARP estilo editor debe morir como StaticObject. Group normalmente no existe.
    destroyStaticIfExists(farp.name)
    if farp.unitName and farp.unitName ~= farp.name then destroyStaticIfExists(farp.unitName) end
    if farp.groupName and farp.groupName ~= farp.name then destroyGroupIfExists(farp.groupName) end
    destroyGroupIfExists(farp.name)

    for _, name in ipairs({ farp.name, farp.unitName, farp.groupName }) do
        if name then
            CTDP.STATE.byHeliportName[name] = nil
            CTDP.STATE.byStaticName[name] = nil
        end
    end

    farp.active = false
    farp.destroyedAt = now()
    CTDP.STATE.dirty = true
end

local function verifyRuntimeHeliportForFob(fob, targetPoint)
    if not fob or not fob.package or not fob.package.farp then return end
    local farp = fob.package.farp

    timer.scheduleFunction(function()
        local obj, objType = findRuntimeHeliportObject(farp)
        if not obj then
            farp.active = false
            farp.lastError = "static_heliport_not_found_after_spawn"
            farp.updatedAt = now()
            CTDP.STATE.dirty = true
            writeState(true)
            log("Static heliport no encontrado despues del spawn: " .. tostring(farp.name), 10)
            return nil
        end

        local point = getObjectPoint(obj)
        if point then
            farp.point = point
            farp.distanceToTarget = getDistance2D(point, targetPoint)
        end

        farp.objectTypeFound = objType
        local ab, abName = getRuntimeHeliportAirbase(farp)
        farp.airbaseRegistered = ab and true or false
        farp.airbaseName = abName
        farp.unitRegistered = unitExistsByNameLocal(farp.name) and true or false
        farp.staticRegistered = staticExistsByName(farp.name) and true or false
        farp.groupRegistered = groupExistsByName(farp.name) and true or false
        farp.active = true
        farp.lastSeenAt = now()
        farp.updatedAt = now()
        farp.lastError = nil

        CTDP.STATE.byHeliportName[farp.name] = fob.id
        CTDP.STATE.byStaticName[farp.name] = fob.id
        if farp.unitName then
            CTDP.STATE.byHeliportName[farp.unitName] = fob.id
            CTDP.STATE.byStaticName[farp.unitName] = fob.id
        end
        if farp.groupName then
            CTDP.STATE.byHeliportName[farp.groupName] = fob.id
            CTDP.STATE.byStaticName[farp.groupName] = fob.id
        end

        CTDP.STATE.dirty = true
        applyRuntimeFarpWarehouseNow(fob)
        writeState(true)

        log(
            "Static heliport confirmado FOB " .. tostring(fob.id) ..
            " | " .. tostring(farp.name) ..
            " | obj=" .. tostring(objType) ..
            " | static=" .. tostring(farp.staticRegistered) ..
            " | unit=" .. tostring(farp.unitRegistered) ..
            " | airbase=" .. tostring(farp.airbaseRegistered),
            10
        )

        return nil
    end, nil, timer.getTime() + 2)
end

local function buildRuntimeHeliportStaticData(fob, farpType, farpPoint)
    local farpCfg = getFobFarpConfig()
    local farpName = makeHeliportRuntimeName(fob)
    local farpUnitName = farpName
    local farpGroupName = farpName

    local heading = tonumber(farpCfg.heading) or 0
    local frequency = normalizeHeliportFrequency(farpCfg.frequency)
    local modulation = tonumber(farpCfg.modulation) or 0
    local callsignId = tonumber(farpCfg.callsign) or 1
    local shapeName = getShapeNameForFarpType(farpType)

    local dynamicSpawn = farpCfg.dynamicSpawn == true
    local allowHotStart = farpCfg.allowHotStart == true
    local dynamicCargo = farpCfg.dynamicCargo == true
    local unlimitedFuel = farpCfg.unlimitedFuel == true
    local unlimitedMunitions = farpCfg.unlimitedMunitions == true
    local unlimitedAircrafts = farpCfg.unlimitedAircrafts == true

    local countryId = tonumber(fob.country) or (country.id.USA or 2)

    -- Estructura calcada al inspector del FARP del Mission Editor.
    -- MIST copiara units[1] al top-level antes de llamar coalition.addStaticObject.
    local unit = {
        category = "Heliports",
        type = farpType or "FARP",
        shape_name = shapeName,
        name = farpUnitName,
        unitId = mist.getNextUnitId(),
        x = farpPoint.x,
        y = farpPoint.z,
        heading = heading,
        heliport_callsign_id = callsignId,
        heliport_frequency = frequency,
        heliport_modulation = modulation,
        tasks = {},

        -- Banderas extra para dynamic spawn / cargo / warehouse.
        dynamicSpawn = dynamicSpawn,
        allowHotStart = allowHotStart,
        dynamicCargo = dynamicCargo,
        unlimitedFuel = unlimitedFuel,
        unlimitedMunitions = unlimitedMunitions,
        unlimitedAircrafts = unlimitedAircrafts
    }

    local staticData = {
        country = countryId,
        countryId = countryId,
        category = "Heliports",
        type = farpType or "FARP",
        shape_name = shapeName,
        name = farpName,
        unitId = unit.unitId,
        groupId = mist.getNextGroupId(),
        x = farpPoint.x,
        y = farpPoint.z,
        heading = heading,
        dead = false,
        hidden = false,
        canCargo = false,

        heliport_callsign_id = callsignId,
        heliport_frequency = frequency,
        heliport_modulation = modulation,

        dynamicSpawn = dynamicSpawn,
        allowHotStart = allowHotStart,
        dynamicCargo = dynamicCargo,
        unlimitedFuel = unlimitedFuel,
        unlimitedMunitions = unlimitedMunitions,
        unlimitedAircrafts = unlimitedAircrafts,

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
                    y = farpPoint.z
                }
            }
        },

        units = {
            [1] = unit
        }
    }

    return staticData, farpName, farpGroupName, farpUnitName
end

local function addStaticHeliportObject(countryId, staticData)
    -- Preferimos mist.dynAddStatic porque ya normaliza country, ids y shape_name.
    if mist and mist.dynAddStatic then
        local okMist, resultMist = pcall(function()
            return mist.dynAddStatic(staticData)
        end)

        if okMist and resultMist then
            return true, resultMist, "mist.dynAddStatic"
        end

        -- Si MIST fallo, dejamos el error y probamos API directa.
        local mistErr = resultMist

        local okDirect, resultDirect = pcall(function()
            return coalition.addStaticObject(countryId, staticData)
        end)

        if okDirect and resultDirect then
            return true, resultDirect, "coalition.addStaticObject_after_mist_error:" .. tostring(mistErr)
        end

        return false, "mist=" .. tostring(mistErr) .. " | direct=" .. tostring(resultDirect), "failed"
    end

    local okDirect, resultDirect = pcall(function()
        return coalition.addStaticObject(countryId, staticData)
    end)

    if okDirect and resultDirect then
        return true, resultDirect, "coalition.addStaticObject"
    end

    return false, tostring(resultDirect), "failed"
end

local function spawnRuntimeHeliportForFob(fob, fobPoint)
    if not fobPackageFarpEnabled() then return false end
    if not fob or not fob.id or not fobPoint then return false end

    ensureFobPackageFields(fob)

    local farpPoint = getFarpPointForFob(fob, fobPoint)
    if not farpPoint then return false end

    destroyRuntimeHeliportForFob(fob)

    local lastError = nil
    local usedType = nil
    local usedMethod = nil
    local farpName = makeHeliportRuntimeName(fob)
    local farpGroupName = farpName
    local farpUnitName = farpName

    for _, farpType in ipairs(buildFarpTypeList()) do
        local farpData
        farpData, farpName, farpGroupName, farpUnitName = buildRuntimeHeliportStaticData(fob, farpType, farpPoint)

        local ok, result, method = addStaticHeliportObject(tonumber(fob.country) or (country.id.USA or 2), farpData)

        if ok and result then
            usedType = farpType
            usedMethod = method

            fob.package = fob.package or {}
            fob.package.farp = {
                enabled = true,
                mode = "static_heliport_editor_style",
                name = farpName,
                groupName = farpGroupName,
                unitName = farpUnitName,
                type = usedType,
                shape_name = farpData.shape_name,
                category = farpData.category,
                point = farpPoint,
                targetPoint = farpPoint,
                active = true,
                dynamicSpawn = farpData.dynamicSpawn,
                allowHotStart = farpData.allowHotStart,
                dynamicCargo = farpData.dynamicCargo,
                unlimitedFuel = farpData.unlimitedFuel,
                unlimitedMunitions = farpData.unlimitedMunitions,
                unlimitedAircrafts = farpData.unlimitedAircrafts,
                frequency = farpData.heliport_frequency,
                modulation = farpData.heliport_modulation,
                callsign = farpData.heliport_callsign_id,
                touchWarehouse = true,
                warehouseRegistered = false,
                warehouseApplied = false,
                staticRegistered = false,
                unitRegistered = false,
                airbaseRegistered = false,
                groupRegistered = false,
                createdAt = now(),
                lastSpawnAt = now(),
                spawnMethod = usedMethod,
                rawResultType = type(result)
            }

            CTDP.STATE.byHeliportName[farpName] = fob.id
            CTDP.STATE.byStaticName[farpName] = fob.id
            CTDP.STATE.dirty = true

            verifyRuntimeHeliportForFob(fob, farpPoint)
            scheduleRuntimeFarpWarehouseApply(fob)

            log(
                "Static heliport estilo editor creado para FOB " .. tostring(fob.id) ..
                " | " .. tostring(farpName) ..
                " | type=" .. tostring(usedType) ..
                " | shape=" .. tostring(farpData.shape_name) ..
                " | freq=" .. tostring(farpData.heliport_frequency) ..
                " | method=" .. tostring(usedMethod),
                12
            )

            return true
        else
            lastError = result
            log("Fallo creando static heliport type=" .. tostring(farpType) .. " | error=" .. tostring(result), 8)
        end
    end

    fob.package = fob.package or {}
    fob.package.farp = fob.package.farp or {}
    fob.package.farp.enabled = true
    fob.package.farp.mode = "static_heliport_editor_style"
    fob.package.farp.name = farpName
    fob.package.farp.groupName = farpGroupName
    fob.package.farp.unitName = farpUnitName
    fob.package.farp.point = farpPoint
    fob.package.farp.active = false
    fob.package.farp.lastError = tostring(lastError)
    fob.package.farp.updatedAt = now()
    CTDP.STATE.dirty = true

    log("No se pudo crear static heliport para FOB " .. tostring(fob.id) .. " | error=" .. tostring(lastError), 12)
    return false
end

local function restoreRuntimeHeliportForFob(fob)
    if not fob or fob.alive == false then return false end
    local point = fob.point
    if not point then return false end
    return spawnRuntimeHeliportForFob(fob, point)
end

local function updateRuntimeHeliportFromWorld(fob)
    if not fob or not fob.package or not fob.package.farp then return end
    local farp = fob.package.farp
    local obj, objType = findRuntimeHeliportObject(farp)
    if obj then
        local point = getObjectPoint(obj)
        if point then farp.point = point end
        farp.objectTypeFound = objType
        local ab, abName = getRuntimeHeliportAirbase(farp)
        farp.airbaseRegistered = ab and true or false
        farp.airbaseName = abName
        farp.staticRegistered = staticExistsByName(farp.name) and true or false
        farp.unitRegistered = unitExistsByNameLocal(farp.name) and true or false
        farp.groupRegistered = groupExistsByName(farp.name) and true or false
        farp.active = true
        farp.lastSeenAt = now()
        farp.updatedAt = now()
        farp.lastError = nil
        CTDP.STATE.dirty = true
        return
    end
    farp.active = false
    farp.missingAt = now()
    farp.updatedAt = now()
    farp.lastError = "static_heliport_missing"
    CTDP.STATE.dirty = true
end

----------------------------------------------------------------
-- FOB PERSISTENCE
----------------------------------------------------------------
local function getFobByStaticName(staticName)
    if not staticName or not CTDP.STATE.doc or not CTDP.STATE.doc.fobs then return nil, nil end
    for id, fob in pairs(CTDP.STATE.doc.fobs) do
        if fob.originalStaticName == staticName or fob.activeStaticName == staticName or fob.runtimeStaticName == staticName or fob.fobName == staticName then
            return id, fob
        end
        if fob.package and fob.package.farp then
            if fob.package.farp.name == staticName or fob.package.farp.groupName == staticName or fob.package.farp.unitName == staticName then
                return id, fob
            end
        end
    end
    return nil, nil
end

local function getFobById(id)
    if not id or not CTDP.STATE.doc or not CTDP.STATE.doc.fobs then return nil end
    return CTDP.STATE.doc.fobs[id]
end

local function destroyFobBeaconGroups(fob)
    if not fob or not fob.beacon then return end
    for _, groupName in ipairs({ fob.beacon.vhfGroup, fob.beacon.uhfGroup, fob.beacon.fmGroup }) do
        local grp = groupExistsByName(groupName)
        if grp then pcall(function() grp:destroy() end) end
    end
end

local function removeFobFromCtldTables(fobName)
    if not fobName then return end
    ctld.logisticUnits = ctld.logisticUnits or {}
    ctld.builtFOBS = ctld.builtFOBS or {}
    ctld.fobBeacons = ctld.fobBeacons or {}
    removeFromList(ctld.logisticUnits, fobName)
    removeFromList(ctld.builtFOBS, fobName)
    ctld.fobBeacons[fobName] = nil
end

local function restoreFobRuntimeTables(fob, staticName, point)
    if not fob or not staticName or not point then return false end
    ctld.logisticUnits = ctld.logisticUnits or {}
    ctld.builtFOBS = ctld.builtFOBS or {}
    ctld.fobBeacons = ctld.fobBeacons or {}
    ctld.deployedRadioBeacons = ctld.deployedRadioBeacons or {}

    insertUnique(ctld.logisticUnits, staticName)

    if ctld.troopPickupAtFOB == true or fob.troopPickupAtFOB == true then
        insertUnique(ctld.builtFOBS, staticName)
        fob.troopPickupAtFOB = true
    end

    if CTDP.CONFIG.RESTORE_FOB_BEACON and ctld.createRadioBeacon then
        ctld.beaconCount = tonumber(ctld.beaconCount) or 0
        ctld.beaconCount = ctld.beaconCount + 1
        local beaconName = fob.beaconName or ("FOB Beacon #" .. tostring(ctld.beaconCount))
        local okBeacon, beaconDetails = pcall(function()
            return ctld.createRadioBeacon(point, tonumber(fob.coalition) or 2, tonumber(fob.country) or (country.id.USA or 2), beaconName, nil, true)
        end)
        if okBeacon and beaconDetails then
            fob.beaconName = beaconName
            fob.beacon = {
                vhf = beaconDetails.vhf,
                uhf = beaconDetails.uhf,
                fm = beaconDetails.fm,
                vhfGroup = beaconDetails.vhfGroup,
                uhfGroup = beaconDetails.uhfGroup,
                fmGroup = beaconDetails.fmGroup,
                text = beaconDetails.text,
                battery = beaconDetails.battery,
                coalition = beaconDetails.coalition
            }
            ctld.fobBeacons[staticName] = { vhf = beaconDetails.vhf, uhf = beaconDetails.uhf, fm = beaconDetails.fm }
        else
            log("No se pudo restaurar beacon FOB: " .. tostring(staticName) .. " | " .. tostring(beaconDetails), 8)
        end
    end
    return true
end

local function recordFobBuild(staticName, countryValue, coalitionValue, point)
    if not CTDP.CONFIG.SAVE_FOBS then return end
    if CTDP.STATE.injecting then return end
    if CTDP.STATE.suppressFobCapture then return end

    local st = staticExistsByName(staticName)
    if not st then log("FOB no capturado. Static no existe: " .. tostring(staticName), 8) return end
    local fobPoint = point or getObjectPoint(st)
    if not fobPoint then log("FOB no capturado. Sin punto: " .. tostring(staticName), 8) return end

    local existingId, existing = getFobByStaticName(staticName)
    if existing then
        existing.alive = true
        existing.activeStaticName = staticName
        existing.originalStaticName = existing.originalStaticName or staticName
        existing.point = fobPoint
        existing.coalition = tonumber(coalitionValue) or existing.coalition or 2
        existing.country = tonumber(countryValue) or existing.country or (country.id.USA or 2)
        existing.updatedAt = now()
        existing.lastSeenAt = now()
        existing.troopPickupAtFOB = ctld.troopPickupAtFOB and true or false
        existing.ctldRole = "FOB"
        ensureFobPackageFields(existing)
        spawnRuntimeHeliportForFob(existing, fobPoint)
        indexFob(existing)
        CTDP.STATE.dirty = true
        writeState(true)
        log("FOB actualizado: " .. tostring(existingId) .. " | " .. tostring(staticName), 8)
        return
    end

    local id = nextFobId()
    local runtimeName = makeFobRuntimeName(id)
    local fob = {
        id = id,
        enabled = true,
        alive = true,
        source = "CTLD",
        captureMethod = "spawnFOB_wrapper",
        ctldRole = "FOB",
        originalStaticName = staticName,
        activeStaticName = staticName,
        runtimeStaticName = runtimeName,
        fobName = staticName,
        coalition = tonumber(coalitionValue) or 2,
        country = tonumber(countryValue) or (country.id.USA or 2),
        point = fobPoint,
        troopPickupAtFOB = ctld.troopPickupAtFOB and true or false,
        createdAt = now(),
        updatedAt = now(),
        lastSeenAt = now(),
        destroyedAt = nil,
        destroyReason = nil
    }

    ensureFobPackageFields(fob)
    spawnRuntimeHeliportForFob(fob, fobPoint)

    if ctld.fobBeacons and ctld.fobBeacons[staticName] then
        fob.beacon = deepCopy(ctld.fobBeacons[staticName])
    end

    CTDP.STATE.doc.fobs[id] = fob
    indexFob(fob)
    CTDP.STATE.dirty = true
    writeState(true)
    log("FOB CTLD guardado como paquete runtime_heliport: " .. tostring(id) .. " | " .. tostring(staticName), 10)
end

local function restoreFobFromJson(fob)
    if not fob or fob.enabled == false or fob.alive == false then return false end
    if not fob.id then return false end
    if CTDP.STATE.injectedFobsThisSession[fob.id] == true then return false end
    local point = fob.point
    if not point then log("FOB sin punto, no se puede inyectar: " .. tostring(fob.id), 8) return false end

    fob.runtimeStaticName = fob.runtimeStaticName or makeFobRuntimeName(fob.id)
    ensureFobPackageFields(fob)
    local runtimeName = fob.runtimeStaticName

    local existing = staticExistsByName(runtimeName)
    if existing and staticAlive(runtimeName) then
        fob.activeStaticName = runtimeName
        CTDP.STATE.injectedFobsThisSession[fob.id] = true
        restoreFobRuntimeTables(fob, runtimeName, point)
        restoreRuntimeHeliportForFob(fob)
        indexFob(fob)
        return false
    end

    destroyStaticIfExists(runtimeName)
    if fob.originalStaticName and fob.originalStaticName ~= runtimeName then destroyStaticIfExists(fob.originalStaticName) end
    destroyFobBeaconGroups(fob)

    local unitId
    if ctld.getNextUnitId then unitId = ctld.getNextUnitId() else unitId = mist.getNextUnitId() end

    CTDP.STATE.suppressFobCapture = true
    local okSpawn, result = pcall(function()
        if ctld._HDEV_CTDP_originalSpawnFOB then
            return ctld._HDEV_CTDP_originalSpawnFOB(tonumber(fob.country) or (country.id.USA or 2), unitId, point, runtimeName)
        else
            return ctld.spawnFOB(tonumber(fob.country) or (country.id.USA or 2), unitId, point, runtimeName)
        end
    end)
    CTDP.STATE.suppressFobCapture = false

    if not okSpawn then log("Error inyectando FOB " .. tostring(fob.id) .. ": " .. tostring(result), 10) return false end

    local spawnedFob = result or staticExistsByName(runtimeName)
    if not spawnedFob then log("FOB no aparecio tras spawn: " .. tostring(runtimeName), 8) return false end

    local activeName = getObjectName(spawnedFob) or runtimeName
    fob.activeStaticName = activeName
    fob.lastInjectedAt = now()
    fob.lastSeenAt = now()
    fob.updatedAt = now()
    fob.ctldRole = "FOB"
    fob.injectedThisSession = nil

    restoreFobRuntimeTables(fob, activeName, point)
    restoreRuntimeHeliportForFob(fob)

    CTDP.STATE.injectedFobsThisSession[fob.id] = true
    indexFob(fob)
    CTDP.STATE.dirty = true
    log("FOB paquete runtime_heliport inyectado: " .. tostring(fob.id) .. " | " .. tostring(activeName), 10)
    return true
end

local function updateFobFromWorld(fob)
    if not fob or fob.alive == false then return end
    fob.injectedThisSession = nil
    ensureFobPackageFields(fob)

    local staticName = fob.activeStaticName or fob.runtimeStaticName or fob.originalStaticName
    local st = staticExistsByName(staticName)
    if st and staticAlive(staticName) then
        local point = getObjectPoint(st)
        if point then fob.point = point end
        fob.lastSeenAt = now()
        fob.updatedAt = now()
        fob.troopPickupAtFOB = fob.troopPickupAtFOB or (ctld.troopPickupAtFOB and true or false)
        updateRuntimeHeliportFromWorld(fob)
        indexFob(fob)
        CTDP.STATE.dirty = true
        return
    end

    local lastSeen = tonumber(fob.lastSeenAt) or tonumber(fob.createdAt) or now()
    local missingFor = now() - lastSeen
    if missingFor >= (tonumber(CTDP.CONFIG.MISSING_DEAD_GRACE) or 10) then
        fob.alive = false
        fob.destroyedAt = now()
        fob.destroyReason = "missing_on_export"
        fob.updatedAt = now()
        fob.injectedThisSession = nil
        removeFobFromCtldTables(staticName)
        destroyRuntimeHeliportForFob(fob)
        CTDP.STATE.dirty = true
    end
end

----------------------------------------------------------------
-- WRAPPERS CTLD
----------------------------------------------------------------
local function installCtldSpawnWrapper()
    if CTDP.STATE.wrapperInstalled then return end
    if ctld._HDEV_CTDP_originalSpawnCrateGroup then CTDP.STATE.wrapperInstalled = true return end

    ctld._HDEV_CTDP_originalSpawnCrateGroup = ctld.spawnCrateGroup
    ctld.spawnCrateGroup = function(_heli, _positions, _types, _hdgs)
        local spawnedGroup = ctld._HDEV_CTDP_originalSpawnCrateGroup(_heli, _positions, _types, _hdgs)
        local groupName, heliName = nil, nil
        local typesCopy = {}

        if spawnedGroup and spawnedGroup.getName then
            local okName, resultName = pcall(function() return spawnedGroup:getName() end)
            if okName then groupName = resultName end
        end
        if _heli and _heli.getName then
            local okHeli, resultHeli = pcall(function() return _heli:getName() end)
            if okHeli then heliName = resultHeli end
        end
        for _, t in ipairs(_types or {}) do typesCopy[#typesCopy + 1] = t end

        if groupName then
            timer.scheduleFunction(function()
                recordCtldSpawnedGroup(groupName, typesCopy, heliName)
                return nil
            end, nil, timer.getTime() + 1)
        else
            log("CTLD spawneo algo, pero no pude leer el nombre del grupo.", 8)
        end
        return spawnedGroup
    end

    CTDP.STATE.wrapperInstalled = true
    log("Wrapper instalado sobre ctld.spawnCrateGroup.", 8)
end

local function installCtldFobWrapper()
    if CTDP.STATE.fobWrapperInstalled then return end
    if ctld._HDEV_CTDP_originalSpawnFOB then CTDP.STATE.fobWrapperInstalled = true return end

    ctld._HDEV_CTDP_originalSpawnFOB = ctld.spawnFOB
    ctld.spawnFOB = function(_country, _unitId, _point, _name)
        local spawnedFob = ctld._HDEV_CTDP_originalSpawnFOB(_country, _unitId, _point, _name)
        local staticName = _name

        if spawnedFob and spawnedFob.getName then
            local okName, resultName = pcall(function() return spawnedFob:getName() end)
            if okName and resultName then staticName = resultName end
        end

        local pointCopy = nil
        if _point then pointCopy = { x = tonumber(_point.x) or 0, y = tonumber(_point.y) or 0, z = tonumber(_point.z) or 0 } end
        local countryCopy = tonumber(_country) or (country.id.USA or 2)
        local coalitionCopy = getCoalitionFromCountry(countryCopy)

        if staticName then
            timer.scheduleFunction(function()
                recordFobBuild(staticName, countryCopy, coalitionCopy, pointCopy)
                return nil
            end, nil, timer.getTime() + 1)
        end
        return spawnedFob
    end

    CTDP.STATE.fobWrapperInstalled = true
    log("Wrapper instalado sobre ctld.spawnFOB.", 8)
end

----------------------------------------------------------------
-- MUERTE / EVENTOS
----------------------------------------------------------------
local function getDeploymentById(id)
    if not id or not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then return nil end
    return CTDP.STATE.doc.deployments[id]
end

local function findDeploymentIdFromGroupName(groupName)
    if not groupName then return nil end
    if CTDP.STATE.byGroupName[groupName] then return CTDP.STATE.byGroupName[groupName] end
    if not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then return nil end
    for id, dep in pairs(CTDP.STATE.doc.deployments) do
        if dep.originalGroupName == groupName or dep.activeGroupName == groupName or dep.runtimeGroupName == groupName then return id end
    end
    return nil
end

local function findFobIdFromStaticName(staticName)
    if not staticName then return nil end
    if CTDP.STATE.byStaticName[staticName] then return CTDP.STATE.byStaticName[staticName] end
    if CTDP.STATE.byHeliportName[staticName] then return CTDP.STATE.byHeliportName[staticName] end
    local id = select(1, getFobByStaticName(staticName))
    return id
end

local function markDeploymentDestroyed(id, reason)
    local dep = getDeploymentById(id)
    if not dep or dep.alive == false then return end
    dep.alive = false
    dep.destroyedAt = now()
    dep.destroyReason = reason or "dead"
    dep.updatedAt = now()
    dep.injectedThisSession = nil
    CTDP.STATE.dirty = true
    writeState(true)
    log("Despliegue destruido: " .. tostring(id), 8)
end

local function markFobDestroyed(id, reason)
    local fob = getFobById(id)
    if not fob or fob.alive == false then return end
    local staticName = fob.activeStaticName or fob.runtimeStaticName or fob.originalStaticName
    fob.alive = false
    fob.destroyedAt = now()
    fob.destroyReason = reason or "dead"
    fob.updatedAt = now()
    fob.injectedThisSession = nil
    removeFobFromCtldTables(staticName)
    destroyFobBeaconGroups(fob)
    destroyRuntimeHeliportForFob(fob)
    CTDP.STATE.dirty = true
    writeState(true)
    log("FOB paquete destruido: " .. tostring(id), 8)
end

local function checkDeploymentDestroyed(id)
    local dep = getDeploymentById(id)
    if not dep or dep.alive == false then return end
    local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName
    if groupHasAliveUnits(groupName) then return end
    markDeploymentDestroyed(id, "group_dead")
end

local function checkFobDestroyed(id)
    local fob = getFobById(id)
    if not fob or fob.alive == false then return end
    local staticName = fob.activeStaticName or fob.runtimeStaticName or fob.originalStaticName
    if staticAlive(staticName) then return end
    markFobDestroyed(id, "fob_dead")
end

local function registerDeathEventHandler()
    if CTDP.STATE.eventHandlerRegistered then return end
    world.addEventHandler({
        onEvent = function(_, event)
            if not event or not event.id then return end
            if event.id ~= world.event.S_EVENT_DEAD and event.id ~= world.event.S_EVENT_CRASH then return end
            local obj = event.initiator or event.target
            if not obj then return end

            local objectName = getObjectName(obj)
            local fobId = findFobIdFromStaticName(objectName)
            if fobId then
                timer.scheduleFunction(function()
                    checkFobDestroyed(fobId)
                    return nil
                end, nil, timer.getTime() + 2)
                return
            end

            local id = nil
            local unitName = getUnitName(obj)
            if unitName and CTDP.STATE.byUnitName[unitName] then id = CTDP.STATE.byUnitName[unitName] end
            if not id and obj.getGroup then
                local ok, grp = pcall(function() return obj:getGroup() end)
                if ok and grp then id = findDeploymentIdFromGroupName(getGroupName(grp)) end
            end
            if id then
                timer.scheduleFunction(function()
                    checkDeploymentDestroyed(id)
                    return nil
                end, nil, timer.getTime() + 2)
            end
        end
    })
    CTDP.STATE.eventHandlerRegistered = true
    log("Event handler de muerte registrado.", 6)
end

----------------------------------------------------------------
-- INYECCION DE GRUPOS DESDE JSON
----------------------------------------------------------------
local function prepareGroupDataForSpawn(dep)
    if not dep or type(dep.groupData) ~= "table" then return nil end
    local gd = deepCopy(dep.groupData)
    local runtimeName = dep.runtimeGroupName or makeRuntimeName(dep.id)
    gd.name = runtimeName
    gd.groupId = nil
    gd.clone = true
    gd.country = tonumber(dep.country) or tonumber(gd.country) or 2
    gd.category = tonumber(dep.groupCategory) or tonumber(gd.category) or Group.Category.GROUND
    gd.units = gd.units or {}

    for i, unitData in ipairs(gd.units) do
        unitData.name = runtimeName .. "_U" .. tostring(i)
        unitData.unitId = nil
        unitData.life = nil
        unitData.life0 = nil
        if not unitData.skill then unitData.skill = "Excellent" end
    end

    if deploymentContainsDrone(dep) and gd.units and gd.units[1] then
        local u = gd.units[1]
        gd.category = Group.Category.AIRPLANE
        gd.task = "Reconnaissance"
        u.skill = "High"
        u.speed = tonumber(CTDP.CONFIG.DRONE_DEFAULT_SPEED) or 80
        u.alt = tonumber(u.alt) or tonumber(ctld.jtacDroneAltitude) or 2000
        u.alt_type = "BARO"
        u.livery_id = u.livery_id or "'camo' scheme"
        u.payload = u.payload or { pylons = {}, fuel = 1300, flare = 0, chaff = 0, gun = 100 }
        gd.route = buildDroneOrbitRoute(u.x, u.y)
    end

    return gd
end

local function scheduleCtldRestore(dep, groupName)
    if not dep or not groupName then return end
    timer.scheduleFunction(function()
        restoreCtldRuntimeForDeployment(dep, groupName)
        return nil
    end, nil, timer.getTime() + (tonumber(CTDP.CONFIG.RESTORE_CTLD_DELAY) or 4))
end

local function injectDeployment(dep)
    if not dep or dep.enabled == false or dep.alive == false or not dep.id then return false end
    if CTDP.STATE.injectedThisSession[dep.id] == true then return false end
    dep.injectedThisSession = nil
    dep.runtimeGroupName = dep.runtimeGroupName or makeRuntimeName(dep.id)

    local existing = groupExistsByName(dep.runtimeGroupName)
    if existing and groupHasAliveUnits(dep.runtimeGroupName) then
        dep.activeGroupName = dep.runtimeGroupName
        CTDP.STATE.injectedThisSession[dep.id] = true
        indexDeployment(dep)
        applyDroneProtectionNow(dep, dep.runtimeGroupName)
        scheduleDroneProtection(dep, dep.runtimeGroupName)
        scheduleCtldRestore(dep, dep.runtimeGroupName)
        return false
    end

    destroyGroupIfExists(dep.runtimeGroupName)
    local groupData = prepareGroupDataForSpawn(dep)
    if not groupData or not groupData.units or #groupData.units == 0 then
        log("No hay groupData valido para inyectar: " .. tostring(dep.id), 8)
        return false
    end

    local ok, result = pcall(function() return mist.dynAdd(groupData) end)
    if not ok or not result then log("Error inyectando " .. tostring(dep.id) .. ": " .. tostring(result), 10) return false end

    local spawnedName = nil
    if type(result) == "table" then spawnedName = result.name or result.groupName elseif type(result) == "string" then spawnedName = result end
    spawnedName = spawnedName or groupData.name

    dep.activeGroupName = spawnedName
    CTDP.STATE.injectedThisSession[dep.id] = true
    dep.lastInjectedAt = now()
    dep.lastSeenAt = now()
    dep.updatedAt = now()
    dep.injectedThisSession = nil
    indexDeployment(dep)
    CTDP.STATE.dirty = true
    log("Despliegue inyectado: " .. tostring(dep.id) .. " | " .. tostring(spawnedName), 8)

    applyDroneProtectionNow(dep, spawnedName)
    scheduleDroneProtection(dep, spawnedName)
    scheduleCtldRestore(dep, spawnedName)
    return true
end

local function injectFromJson()
    if not CTDP.STATE.doc then return end
    local count, fobCount = 0, 0
    if CTDP.STATE.doc.deployments then
        for _, id in ipairs(sortedKeys(CTDP.STATE.doc.deployments)) do
            if injectDeployment(CTDP.STATE.doc.deployments[id]) then count = count + 1 end
        end
    end
    if CTDP.STATE.doc.fobs then
        for _, id in ipairs(sortedKeys(CTDP.STATE.doc.fobs)) do
            if restoreFobFromJson(CTDP.STATE.doc.fobs[id]) then fobCount = fobCount + 1 end
        end
    end
    if count > 0 or fobCount > 0 then writeState(true) end
end

----------------------------------------------------------------
-- EXPORTACION
----------------------------------------------------------------
local function updateDeploymentFromWorld(dep)
    if not dep or dep.alive == false then return end
    dep.injectedThisSession = nil
    local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName
    local grp = groupExistsByName(groupName)

    if grp and groupHasAliveUnits(groupName) then
        local groupData, coalitionValue, countryValue, groupCategory, unitTypes = captureGroupData(grp, groupName)
        if groupData then
            dep.groupData = groupData
            dep.coalition = coalitionValue
            dep.country = countryValue
            dep.groupCategory = groupCategory
            dep.types = unitTypes
            dep.lastSeenAt = now()
            dep.updatedAt = now()
            dep.injectedThisSession = nil
            if deploymentContainsDrone(dep) then
                dep.ctldRole = "DRONE_JTAC"
                dep.jtacLaserCode = dep.jtacLaserCode or getFreshLaserCode()
            elseif deploymentContainsJtac(dep) then
                dep.ctldRole = "JTAC"
                dep.jtacLaserCode = dep.jtacLaserCode or getFreshLaserCode()
            end
            indexDeployment(dep)
            CTDP.STATE.dirty = true
        end
        return
    end

    local lastSeen = tonumber(dep.lastSeenAt) or tonumber(dep.createdAt) or now()
    local missingFor = now() - lastSeen
    if missingFor >= (tonumber(CTDP.CONFIG.MISSING_DEAD_GRACE) or 10) then
        dep.alive = false
        dep.destroyedAt = now()
        dep.destroyReason = "missing_on_export"
        dep.updatedAt = now()
        dep.injectedThisSession = nil
        CTDP.STATE.dirty = true
    end
end

local function exportToJson()
    if not CTDP.STATE.doc then return end
    rebuildIndexes()
    if CTDP.STATE.doc.deployments then
        for _, id in ipairs(sortedKeys(CTDP.STATE.doc.deployments)) do updateDeploymentFromWorld(CTDP.STATE.doc.deployments[id]) end
    end
    if CTDP.STATE.doc.fobs then
        for _, id in ipairs(sortedKeys(CTDP.STATE.doc.fobs)) do updateFobFromWorld(CTDP.STATE.doc.fobs[id]) end
    end
    cleanRuntimeFields(CTDP.STATE.doc)
    writeState(true)
end

----------------------------------------------------------------
-- API
----------------------------------------------------------------
function CTDP.forceSave()
    exportToJson()
end

function CTDP.forceRestoreFOBs()
    if not CTDP.STATE.doc or not CTDP.STATE.doc.fobs then return end
    for _, id in ipairs(sortedKeys(CTDP.STATE.doc.fobs)) do restoreFobFromJson(CTDP.STATE.doc.fobs[id]) end
    writeState(true)
end

function CTDP.forceProtectDrones()
    if not CTDP.STATE.doc or not CTDP.STATE.doc.deployments then return end
    for _, dep in pairs(CTDP.STATE.doc.deployments) do
        if dep and dep.alive ~= false and deploymentContainsDrone(dep) then
            local groupName = dep.activeGroupName or dep.runtimeGroupName or dep.originalGroupName
            applyDroneProtectionNow(dep, groupName)
            scheduleDroneProtection(dep, groupName)
        end
    end
    writeState(true)
end

function CTDP.forceRestoreRuntimeHeliports()
    if not CTDP.STATE.doc or not CTDP.STATE.doc.fobs then return end
    for _, fob in pairs(CTDP.STATE.doc.fobs) do
        if fob and fob.alive ~= false then
            ensureFobPackageFields(fob)
            restoreRuntimeHeliportForFob(fob)
        end
    end
    writeState(true)
end

function CTDP.forceApplyRuntimeFarpWarehouses()
    if not CTDP.STATE.doc or not CTDP.STATE.doc.fobs then return end
    for _, fob in pairs(CTDP.STATE.doc.fobs) do
        if fob and fob.alive ~= false and fob.package and fob.package.farp then
            applyRuntimeFarpWarehouseNow(fob)
        end
    end
    writeState(true)
end

-- Alias con nombres nuevos para V2.6.2.
CTDP.forceRestoreStaticHeliports = CTDP.forceRestoreRuntimeHeliports
CTDP.forceApplyStaticFarpWarehouses = CTDP.forceApplyRuntimeFarpWarehouses


function CTDP.showStatus()
    local total, alive, dead, jtac, drone, aa = 0, 0, 0, 0, 0, 0
    local totalFob, aliveFob, deadFob, heliTotal, heliActive, heliAirbase, heliWarehouse = 0, 0, 0, 0, 0, 0, 0

    if CTDP.STATE.doc and CTDP.STATE.doc.deployments then
        for _, dep in pairs(CTDP.STATE.doc.deployments) do
            total = total + 1
            if dep.alive == false then dead = dead + 1 else alive = alive + 1 end
            if dep.ctldRole == "DRONE_JTAC" then drone = drone + 1 elseif dep.ctldRole == "JTAC" then jtac = jtac + 1 elseif dep.ctldRole == "AA_SYSTEM" then aa = aa + 1 end
        end
    end

    if CTDP.STATE.doc and CTDP.STATE.doc.fobs then
        for _, fob in pairs(CTDP.STATE.doc.fobs) do
            totalFob = totalFob + 1
            if fob.alive == false then deadFob = deadFob + 1 else aliveFob = aliveFob + 1 end
            if fob.package and fob.package.farp and fob.package.farp.enabled then
                heliTotal = heliTotal + 1
                if fob.package.farp.active then heliActive = heliActive + 1 end
                if fob.package.farp.airbaseRegistered then heliAirbase = heliAirbase + 1 end
                if fob.package.farp.warehouseRegistered then heliWarehouse = heliWarehouse + 1 end
            end
        end
    end

    trigger.action.outText(
        "CTLD Persistence V2.6.6\n" ..
        "Deployments Total: " .. tostring(total) .. "\n" ..
        "Deployments Vivos: " .. tostring(alive) .. "\n" ..
        "Deployments Destruidos: " .. tostring(dead) .. "\n" ..
        "JTAC: " .. tostring(jtac) .. "\n" ..
        "Drones JTAC: " .. tostring(drone) .. "\n" ..
        "AA Systems: " .. tostring(aa) .. "\n" ..
        "FOB Total: " .. tostring(totalFob) .. "\n" ..
        "FOB Vivos: " .. tostring(aliveFob) .. "\n" ..
        "FOB Destruidos: " .. tostring(deadFob) .. "\n" ..
        "Static Heliports Total: " .. tostring(heliTotal) .. "\n" ..
        "Static Heliports Activos: " .. tostring(heliActive) .. "\n" ..
        "Static Heliports AirbaseRegistered: " .. tostring(heliAirbase) .. "\n" ..
        "Static Heliports WarehouseRegistered: " .. tostring(heliWarehouse) .. "\n" ..
        "JSON: " .. tostring(CTDP.CONFIG.FILE_PATH),
        15
    )
end

----------------------------------------------------------------
-- LOOP
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
            log("Ventana de inyeccion finalizada. DCS toma control del JSON.", 8)
        end
    end

    if CTDP.STATE.writeEnabled then
        if (t - CTDP.STATE.lastExport) >= (tonumber(CTDP.CONFIG.EXPORT_INTERVAL) or 60) then exportToJson() end
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
    CTDP.STATE.injectedThisSession = {}
    CTDP.STATE.injectedFobsThisSession = {}
    CTDP.STATE.suppressFobCapture = false

    loadState()
    cleanRuntimeFields(CTDP.STATE.doc)
    buildCtldIndexes()
    rebuildIndexes()
    installCtldSpawnWrapper()
    installCtldFobWrapper()
    registerDeathEventHandler()

    timer.scheduleFunction(mainLoop, nil, timer.getTime() + 1)

    log("Sistema iniciado V2.6.1 RUNTIME HELIPORT + WAREHOUSE. Inyectando JSON durante " .. tostring(CTDP.CONFIG.INJECT_DURATION) .. " segundos.", 10)
end

start()
