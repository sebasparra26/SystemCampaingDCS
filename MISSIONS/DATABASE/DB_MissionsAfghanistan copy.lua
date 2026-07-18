----------------------------------------------------------------
-- HDEV_MissionDB.lua
-- Base de datos de misiones
-- Compatible con HDEV_MissionSystem_Core v1.4.12
----------------------------------------------------------------

HDEV_MissionDB = HDEV_MissionDB or {}
local MDB = HDEV_MissionDB

MDB.VERSION = "1.4.13"

MDB.MISSIONS = {

    ----------------------------------------------------------------
    -- M01
    ----------------------------------------------------------------
    {
        id = "M01",
        order = 1,
        enabled = false,

        name = "Operación - Shadow Gate",
        shortName = "M01",
        generalObjective = "Retoma el control sobre la zona entre Bagram, Kabul y Bayman Captura las bases.\n",
                           

        briefing =
            "OBJETIVO:\n" ..
            "Tomar el control de la zona, Destruir el RADAR y capturar las bases\n\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Destruir el EWR.\n"..
            "2. Capturar la Base: Bagram.\n"..
            "3. Capturar la Base: Kabul.\n"..
            "3. Capturar la Base: bayman.\n"..
            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            "Objetivo EWR: 40.000.000\n" ..
            "Capturar Bagram: 100.000.000\n" ..
            "Capturar Kabul: 100.000.000\n" ..
            "Capturar Bayman: 100.000.000\n" ..
            "Mision Completada: 200.000.000\n\n" ..
            "IMPORTANTE:\n" ..
            "Coordenadas:\n" ..
            "Lat Long Decimal Minutes: N 34°47.620'   E 69°11.237'\n"..
                            "MGRS GRID: 42 S WD 17132 50179\n"..
                            "Altitude: 1538 m / 5046 feet\n",

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = 106269,
                z = 210836
            },

            zoneName = nil,

            title = "M01 - Operación - Shadow Gate",
            text =
                "MISION 01\n" ..
                "Retoma el control sobre la zona entre Bagram y Kabul, Captura las bases.\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M01 - Operación - Shadow Gate",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 1000, value = 1 },
            },
            onSuccess = {
                { flag = 1001, value = 1 },
            },
            onFail = {
                { flag = 1002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
            {
                id = "M01_REGLA_01",
                enabled = false,

                conditions = {
                    { flag = 1000, op = "==", value = 1 },
                    { flag = 1001, op = "==", value = 1 },
                },

                onTrue = {
                    { flag = 1002, value = 1 }
                },

                onFalse = {
                    { flag = 1002, value = 0 }
                }
            }
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {

             ------------------------------------------------------------
            -- OBJETIVO OBLIGATORIO: destruir grupo SAM completo
            -- IMPORTANTE:
            -- groupName debe ser el nombre exacto del grupo
            -- El core parcheado arma el objetivo cuando detecta el grupo por primera vez.
            -- Luego, si desaparece o queda en 0 unidades vivas, cuenta como destruido.
            ------------------------------------------------------------
            {
                id = "OBJ_DESTRUIR_GRUPO_EWR",
                name = "SAM",
                drawName = "Destruir el radar EWR",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_01_06_EWR",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 1004,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 1005,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 40000000
                }
            },
                        ------------------------------------------------------------
            -- OBJETIVO OPCIONAL: capturar una base
            -- coalition / value:
            -- 0 = neutral
            -- 1 = rojo
            -- 2 = azul
            ------------------------------------------------------------
             {
                 id = "OBJ_CAPTURAR_BASE_KABUL",
                 name = "Capturar Kabul",
                 drawName = "Capturar base: Kabul",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Kabul",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 1006,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 1007,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 100000000
                 }
             },
 {
                 id = "OBJ_CAPTURAR_BASE_BAGRAM",
                 name = "Capturar Bagram",
                 drawName = "Capturar base: Bagram",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Bagram",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 1008,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 1009,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 100000000
                 }
             },
             {
                 id = "OBJ_CAPTURAR_BASE_BAYMAN",
                 name = "Capturar Bagram",
                 drawName = "Capturar base: Bamyan",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Bamyan",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 1010,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 1011,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 100000000
                 }
             },

            ------------------------------------------------------------
            -- OBJETIVO COMPUESTO DE WAREHOUSE
            -- Lee contra SystemWarehousesPersistanceSinai.json
            ------------------------------------------------------------
            




           

            ------------------------------------------------------------
            -- EJEMPLO OPCIONAL: destruir una unidad concreta
            ------------------------------------------------------------
            -- {
            --     id = "OBJ_DESTRUIR_RADAR",
            --     name = "Destruir radar principal",
            --     enabled = true,
            --     requiredForMission = false,
            --
            --     monitor = {
            --         kind = "unit",
            --         unitName = "RADAR_PRINCIPAL_1",
            --         metric = "alive",
            --         op = "==",
            --         value = 0
            --     },
            --
            --     setFlagOnPass = {
            --         flag = 2005,
            --         value = 1,
            --         elseValue = 0
            --     },
            --
            --     reward = {
            --         enabled = true,
            --         coalition = 2,
            --         amount = 2500000
            --     }
            -- },

            ------------------------------------------------------------
            -- EJEMPLO OPCIONAL: una unidad debe llegar viva a una zona
            -- Puedes usar una Trigger Zone normal del editor.
            -- El objetivo pasa cuando la unidad indicada entra viva a la zona.
            ------------------------------------------------------------
             {
                 id = "OBJ_RADAR_LLEGA_VIVO_ZONA",
                 name = "Extraer personal activo de la base",
                 drawName = "Extraer personal activo de la base",
                 enabled = false,
                requiredForMission = false,
            
                 monitor = {
                    kind = "unit_alive_in_zone",
                     unitName = "US_TROOP",
                     -- o usa un grupo completo:
                     -- groupName = "US_TROOP_GROUP",
                     -- groupMode = "any", -- any | all | count
                     zoneName = "ACA",
                     op = "==",
                     value = 1,

                     -- Alternativa si no quieres usar zoneName:
                     -- point = { x = 425249, z = 391031 },
                     -- radius = 1000,

                     smoke = {
                         enabled = true,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = true,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "green",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },

                     cleanupOnPass = {
                         enabled = true,
                         delaySeconds = 20,

                         -- auto:
                         -- si usas groupName destruye el grupo
                         -- si usas unitName destruye la unidad
                         targetKind = "auto",

                         -- si al destruir unit falla, intenta destruir su grupo padre
                         fallbackToGroup = true
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 0000,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 0000,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                    coalition = 2,
                     amount = 500000
                 }
             },
        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 200000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M02
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------

    {
        id = "M02",
        order = 2,
        enabled = false,

                name = "Operación - Black Ridge",
        shortName = "M02",
        generalObjective = "En la region de Gardez tendra lugar una reunion de lideres Talibanes de algo nivel. destruyelos! \n",
                            "Humo Rojo sobre objetivos prioritarios\n",
                        

        briefing =
            "OBJETIVO:\n" ..
            "Ubica a los lideres Talibanes en la region de Gardez\n\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Buscar y destruir a: Abdul Hakim - MGRS GRID: 42 S WC 28479 32069 \n"..
            "2. Buscar y destruir a: Mujahid - MGRS GRID: 42 S WC 20305 07967\n"..
            "3. Buscar y destruir a: Karim Abdel - MGRS GRID: 42 S WC 11122 31084 \n"..
            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            "Abdul Hakim: 500.000.000\n" ..
            "Mujahid: 250.000.000\n" ..
            "Karim Abdel: 50.000.000\n" ..
            "Mision Completada: 1500.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -24742,
                z = 276896
            },

            zoneName = nil,

            title = "M02 - Operación - Black Ridge",
            text =
                "MISION 02\n" ..
                "Retoma el control sobre la zona entre Bagram y Kabul, Captura las bases.\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M02 - Operación - Black Ridge",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 2000, value = 1 },
            },
            onSuccess = {
                { flag = 2001, value = 1 },
            },
            onFail = {
                { flag = 2002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
            {
                id = "M01_REGLA_01",
                enabled = false,

                conditions = {
                    { flag = 1000, op = "==", value = 1 },
                    { flag = 1001, op = "==", value = 1 },
                },

                onTrue = {
                    { flag = 1002, value = 1 }
                },

                onFalse = {
                    { flag = 1002, value = 0 }
                }
            }
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {

           --01------------------------------------------------------------------
     {
                 id = "OBJ_DESTRUIR_UNIT_01",
                 name = "Buscar y destruir a: Abdul Hakim - MGRS GRID: 42 S WC 28479 32069 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_02_01_TALIBAN",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 2003,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 500000000
                 }
             }, 
       --02------------------------------------------------------------------
     {
                 id = "OBJ_DESTRUIR_UNIT_02",
                 name = "Buscar y destruir a: Mujahid - MGRS GRID: 42 S WC 20305 07967",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_02_02_TALIBAN",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 2004,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 250000000
                 }
             },
       --03------------------------------------------------------------------
     {
                 id = "OBJ_DESTRUIR_UNIT_03",
                 name = "Buscar y destruir a: Karim Abdel - MGRS GRID: 42 S WC 11122 31084",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_02_03_TALIBAN",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 2005,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 50000000
                 }
             },                          
             
        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 1500000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },

----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M03
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------

    {
        id = "M03",
        order = 3,
        enabled = false,

                name = "Operación - Ghost Route",
        shortName = "M03",
        generalObjective = "Rescatar al piloto derribado en el sector.\n",
                            "Humo Naranja sobre el objetivo a rescatar\n",
                        

        briefing =
            "OBJETIVO:\n" ..
            "Rescatar al piloto derribado en el sector. debes llevarlo a Sharana (20Km)\n\n\n" ..
            "Captura las bases indicadas para poder rescatar al piloto, Humo verde sobre zona de descargue.\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Capturar la Base: Sharana.\n"..
            "2. Capturar la Base: Urgoon Heliport.\n"..
            "3. Rescatar Piloto Caido\n"..
            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            "Capturar Sharana: 180.000.000\n" ..
            "Capturar Urgoon Heliport: 180.000.000\n" ..
            "Rescatar Piloto Caido: 200.000.000\n"..
            "Mision Completada: 2000.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -98695,
                z = 275582
            },

            zoneName = nil,

            title = "M03 - Operación - Ghost Route",
            text =
                "MISION 03\n" ..
                "Rescatar al piloto derribado en el sector.\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M03 - Operación - Ghost Route",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 3000, value = 1 },
            },
            onSuccess = {
                { flag = 3001, value = 1 },
            },
            onFail = {
                { flag = 3002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {

            {
                 id = "OBJ_CAPTURAR_BASE_URGOON",
                 name = "Capturar: Urgoon Heliport",
                 drawName = "Capturar: Urgoon Heliport",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Urgoon Heliport",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 3005,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 3006,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 180000000
                 }
             },

              {
                 id = "OBJ_CAPTURAR_BASE_Sharana",
                 name = "Capturar: Sharana",
                 drawName = "Capturar: Sharana",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Sharana",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 3007,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 3008,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 180000000
                 }
             },


           {
                 id = "RESCUE_PILOT_01",
                 name = "Rescatar piloto caido",
                 drawName = "Rescatar piloto caido",
                 enabled = true,
                requiredForMission = true,
            
                 monitor = {
                    kind = "unit_alive_in_zone",
                     unitName = "MT_03_04_Blue-1",
                     -- o usa un grupo completo:
                     -- groupName = "US_TROOP_GROUP",
                     -- groupMode = "any", -- any | all | count
                     zoneName = "R1",
                     op = "==",
                     value = 1,

                     -- Alternativa si no quieres usar zoneName:
                     -- point = { x = 425249, z = 391031 },
                     -- radius = 1000,

                     smoke = {
                         enabled = true,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = true,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "orange",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },

                     cleanupOnPass = {
                         enabled = true,
                         delaySeconds = 20,

                         -- auto:
                         -- si usas groupName destruye el grupo
                         -- si usas unitName destruye la unidad
                         targetKind = "auto",

                         -- si al destruir unit falla, intenta destruir su grupo padre
                         fallbackToGroup = true
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 3003,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 3004,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                    coalition = 2,
                     amount = 200000000
                 }
             },
     
             
        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 2000000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },
    
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M04
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------

    {
        id = "M04",
        order = 4,
        enabled = false,

                name = "Operación - Iron Valley",
        shortName = "M04",
        generalObjective = "Destruye los 7 Depositos de armas de los Insurgentes\n"..
                            "Lat Long Precise: N 32°36'49.94   E 65°52'31.85\n"..
                            "Lat Long Decimal Minutes: N 32°36.832'   E 65°52.530'\n"..
                            "MGRS GRID: 41 S QS 69830 12133'\n",
                        

        briefing =
            "OBJETIVO:\n" ..
            "Destruir los depositos de armas de los insurgentes en la región Tarinkot, 70 millas al norte de Kandahar\n\n\n" ..
            "Captura la base de  Tarinkot luego del ataque\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Destruir los Depositos de armas\n"..
            "2. Capturar la Base: Tarinkot\n"..

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..

            "Capturar Tarinkot: 200.000.000\n" ..
            "Mision Completada: 1500.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -146899,
                z = -29832
            },

            zoneName = nil,

            title = "M04 - Operación - Iron Valley",
            text =
                "MISION 04\n" ..
                "Destruye los 7 Depositos de armas de los Insurgentes Y recupera Tarinkot\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M04 - Operación - Iron Valley",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 4000, value = 1 },
            },
            onSuccess = {
                { flag = 4001, value = 1 },
            },
            onFail = {
                { flag = 4002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_01",
                 name = "Buscar y destruir Deposito 1: MGRS GRID: 41 S QS 69113 13695 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_01",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4005,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },
             
 -----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_02",
                 name = "Buscar y destruir Deposito 2: MGRS GRID: 41 S QS 69294 12968 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_02",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4006,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },             
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_03",
                 name = "Buscar y destruir Deposito 3: MGRS GRID: 41 S QS 70737 13602 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_03",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4007,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },             
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_04",
                 name = "Buscar y destruir Deposito 4: MGRS GRID: 41 S QS 70647 14348 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_04",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4008,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_05",
                 name = "Buscar y destruir Deposito 5: MGRS GRID: 41 S QS 70870 13764 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_05",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4008,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },             
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_06",
                 name = "Buscar y destruir Deposito 6: MGRS GRID: 41 S QS 70876 13753 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_06",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4008,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                 id = "OBJ_DESTRUIR_DEPOT_07",
                 name = "Buscar y destruir Deposito 7: MGRS GRID: 41 S QS 71821 09964 ",
                 enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_04_07",
                     metric = "alive",
                     op = "==",
                     value = 0
                 },

                 smoke = {
                         enabled = false,
                         refreshSeconds = 300,
                         stopOnPass = true,
                         autoZone = false,
                         autoTarget = true,
                         zoneColor = "green",
                         targetColor = "red",

                         -- Puedes sumar marcados manuales extra:
                         -- items = {
                         --     { targetKind = "zone", zoneName = "ACA", color = "green" },
                         --     { targetKind = "unit", unitName = "US_TROOP", color = "white" },
                         --     { targetKind = "group", groupName = "US_TROOP_GROUP", color = "white" },
                         -- }
                     },
            
                 setFlagOnPass = {
                   flag = 4008,
                    value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 500000000
                 }
             },                                        
      ---------------------------------BASE--------------------------------------------------------------------------------------------------      
     {
                 id = "OBJ_CAPTURAR_BASE_TARINKOT",
                 name = "Capturar Tarinkot",
                 drawName = "Capturar base: Tarinkot",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Tarinkot",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 4003,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 4004,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 200000000
                 }
             },
             
        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 1500000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },
    
----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M05
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------

    {
        id = "M05",
        order = 5,
        enabled = false,

                name = "Operación - Dust Hammer",
        shortName = "M05",
        generalObjective = "Destruye la artilleria enemiga que nos ataca en Tarinkot\n"..
                            "Lat Long Precise: N 32°04'24.07   E 65°41'53.51\n"..
                            "Lat Long Decimal Minutes: N 32°04.401'   E 65°41.891'\n"..
                            "MGRS GRID: 41 S QR 54697 51752\n",
                        

        briefing =
            "OBJETIVO:\n" ..
            "Destruye la artilleria enemiga que nos ataca en Tarinkot\n\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Destruir los emplazamientos de artilleria - 1\n"..
            "2. Destruir los emplazamientos de artilleria - 2\n"..
            "3. Destruir los emplazamientos de artilleria - 3\n"..


            "Coordenadas Aporximadas\n\n"..
            "Ubicación 1\n"..
            "Lat Long Precise: N 32°08'52.20   E 65°26'52.26\n"..
            "Lat Long Decimal Minutes: N 32°08.870'   E 65°26.871\n"..
            "MGRS GRID: 41 S QR 30871 59447\n"..
            "Altitude: 1582 m / 5189 feet\n\n"..
            
            "Ubicación 2\n"..
            "Lat Long Precise: N 31°59'01.42   E 65°28'22.67\n"..
            "Lat Long Decimal Minutes: N 31°59.023'   E 65°28.377'\n"..
            "MGRS GRID: 41 R QR 33658 41304\n"..
            "Altitude: 1577 m / 5175 feet\n\n"..

            "Ubicación 3\n"..
            "Lat Long Precise: N 32°04'27.87   E 65°35'14.92\n"..
            "Lat Long Decimal Minutes: N 32°04.464'   E 65°35.248'\n"..
            "MGRS GRID: 41 S QR 44240 51613\n"..
            "Altitude: 1563 m / 5127 feet\n\n"..

            "Ubicación 4\n"..
            "Lat Long Precise: N 32°11'45.11   E 65°38'18.60\n"..
            "Lat Long Decimal Minutes: N 32°11.751'   E 65°38.310'\n"..
            "MGRS GRID: 41 S QR 48727 65198\n"..
            "Altitude: 1863 m / 6113 feet\n\n"..

            "Ubicación 5\n"..
            "Lat Long Precise: N 32°00'48.96   E 65°40'03.90\n"..
            "Lat Long Decimal Minutes: N 32°00.816'   E 65°40.065'\n"..
            "MGRS GRID: 41 S QR 51986 45054\n"..
            "Altitude: 1468 m / 4817 feet\n\n"..

            "Ubicación 6\n"..
            "Lat Long Precise: N 32°03'30.72   E 65°44'43.25\n"..
            "Lat Long Decimal Minutes: N 32°03.512'   E 65°44.720'\n"..
            "MGRS GRID: 41 S QR 59191 50221\n"..
            "Altitude: 1488 m / 4882 feet\n\n"..

            "Ubicación 7\n"..
            "Lat Long Precise: N 32°02'30.38   E 65°46'38.37\n"..
            "Lat Long Decimal Minutes: N 32°02.506'   E 65°46.639'\n"..
            "MGRS GRID: 41 S QR 62259 48439\n"..
            "Altitude: 1454 m / 4770 feet\n\n"..


            

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..

            "Emplazamiento de artilleria 1: 200.000.000\n" ..
            "Emplazamiento de artilleria 2: 200.000.000\n" ..
            "Emplazamiento de artilleria 3: 200.000.000\n" ..
            "Mision Completada: 1300.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -208891,
                z = -48880
            },

            zoneName = nil,

            title = "M05- Operación - Dust Hammer",
            text =
                "MISION 05\n" ..
                "Destruye los 7 Depositos de armas de los Insurgentes Y recupera Tarinkot\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M05 - Operación - Dust Hammer",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 5000, value = 1 },
            },
            onSuccess = {
                { flag = 5001, value = 1 },
            },
            onFail = {
                { flag = 5002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                id = "OBJ_DESTRUIR_GRUPO_SMERCH",
                name = "Destruir la Artilleria Enemiga - 01",
                drawName = "Destruir la Artilleria Enemiga - 01",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_05_01",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 5003,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 5004,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 200000000
                }
            },
  -----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                id = "OBJ_DESTRUIR_GRUPO_SMERCH_2",
                name = "Destruir la Artilleria Enemiga - 02",
                drawName = "Destruir la Artilleria Enemiga - 02",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_05_02",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 5005,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 5006,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 200000000
                }
            },

          -----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                id = "OBJ_DESTRUIR_GRUPO_SMERCH_3",
                name = "Destruir la Artilleria Enemiga - 03",
                drawName = "Destruir la Artilleria Enemiga - 03",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_05_03",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 5007,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 5008,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 200000000
                }
            },  

        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 1300000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },    
----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M06
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------    
{
        id = "M06",
        order = 6,
        enabled = false,

                name = "Operación - Copper Viper",
        shortName = "M06",
        generalObjective = "Toma el control sobre la zona de Kandahar y libera la ciudad.\n"..
                            "Lat Long Precise: N 31°36'28.00   E 65°42'34.02\n"..
                            "Lat Long Decimal Minutes: N 31°36.466'   E 65°42.567'\n"..
                            "MGRS GRID: 41 R QR 57049 00149\n",
                        

        briefing =
            "OBJETIVO:\n" ..
            "Toma el control sobre la zona de Kandahar y libera la ciudad.\n\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Limpia la Ciudad\n"..
            "2. Captura la base de Kandahar\n"..




            

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..

            "Limpiar la ciudad de Talibanes: 600.000.000\n" ..
            "Capturar Kandahar: 100.000.000\n" ..

            "Mision Completada: 1200.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -259508,
                z = -43101
            },

            zoneName = nil,

            title = "M06- Operación - Copper Viper",
            text =
                "MISION 06\n" ..
                "Toma el control sobre la zona de Kandahar y libera la ciudad.\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M06 - Operación - Copper Viper",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 6000, value = 1 },
            },
            onSuccess = {
                { flag = 6001, value = 1 },
            },
            onFail = {
                { flag = 6002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                id = "OBJ_DESTRUIR_GRUPO_MT06",
                name = "Destruir grupo de talibanes al alrededor de de Kandahar",
                drawName = "Destruir grupo de talibanes al alrededor de de Kandahar",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_06_04",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 6003,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 6004,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 600000000
                }
            },
--------------------------------------            
{
                 id = "OBJ_CAPTURAR_BASE_KANDAHAR",
                 name = "Capturar Kandahar",
                 drawName = "Capturar base: Kandahar",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Kandahar",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 6005,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 6006,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                     coalition = 2,
                     amount = 100000000
                 }
             },

        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 1200000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    }, 
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M07
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------    
{
        id = "M07",
        order = 7,
        enabled = false,

                name = "Operación - Silent Spear",
        shortName = "M07",
        generalObjective = "Toma la base de Camp Bastion y limpia las ciudades de Girishk, Lashkar Gah y Garmsir\n",

                        

        briefing =
            "OBJETIVO:\n" ..
            "Los Talibanes se han reitado hacia las ciudades Girishk, Lashkar Gah y Garmsir.\n" ..
            "Captura posiciones para realizar el ataque y limpiar las ciudades.\n\n\n"..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Captura Camp Bastion\n\n"..
            "2. Libera la ciudad de Girishk\n\n"..
            "Lat Long Precise: N 31°49'32.48   E 64°33'53.33\n"..
            "MGRS GRID: 41 R PR 48092 22181\n\n"..


            "3. Libera la ciudad de Lashkar Gah\n\n"..
            "Lat Long Precise: N 31°35'26.88   E 64°22'27.98\n"..
            "MGRS GRID: 41 R PQ 30402 95899\n\n"..

            "4. Libera la ciudad de Garmsir\n\n"..
            "Lat Long Precise: N 31°07'05.55   E 64°12'41.37\n"..
            "MGRS GRID: 41 R PQ 15517 43333\n\n"..
            

            

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            "Capturar Camp Bastion: 500.000.000\n" ..
            "Limpiar la ciudad de Girishk: 200.000.000\n" ..
            "Limpiar la ciudad de Lashkar Gah: 200.000.000\n" ..
            "Limpiar la ciudad de Garmsir: 200.000.000\n" ..
            

            "Mision Completada: 2000.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -278313,
                z = -181055
            },

            zoneName = nil,

            title = "M07- Operación - Silent Spear",
            text =
                "MISION 07\n" ..
                "Los Talibanes se han reitado hacia las ciudades Girishk, Lashkar Gah y Garmsir.\n" ..
                "Captura posiciones para realizar el ataque y limpiar las ciudades.\n\n\n"..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M07 - Operación - Copper Viper",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 7000, value = 1 },
            },
            onSuccess = {
                { flag = 7001, value = 1 },
            },
            onFail = {
                { flag = 7002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {
--------------------------------------            
{
                 id = "OBJ_CAPTURAR_BASE_CAMP_BASTION",
                 name = "Capturar Camp Bastion",
                 drawName = "Capturar base: Camp Bastion",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Camp Bastion",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 7009,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 7010,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,    
                     coalition = 2,
                     amount = 500000000
                 }
             },
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                id = "OBJ_DESTRUIR_GRUPO_MT07",
                name = "Destruir grupo de talibanes al alrededor de Girishk",
                drawName = "Destruir grupo de talibanes al alrededor de Girishk",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_07_01",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 7003,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 7004,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 200000000
                }
            },
-----------------------------------------------------------------------------------------------------------------------------------------------------------
{
                id = "OBJ_DESTRUIR_GRUPO_MT07_02",
                name = "Destruir grupo de talibanes al alrededor de Laskhar Gah",
                drawName = "Destruir grupo de talibanes al alrededor de Laskhar Gah",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_07_02",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 7005,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 7006,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 200000000
                }
            },
-----------------------------------------------------------------------------------------------------------------------------------------------------------            
{
                id = "OBJ_DESTRUIR_GRUPO_MT07_03",
                name = "Destruir grupo de talibanes al alrededor de Garmsir",
                drawName = "Destruir grupo de talibanes al alrededor de Garmsir",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_07_03",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 7007,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 7008,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 200000000
                }
            },



        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 2000000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },       
    
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M08
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------    
{
        id = "M08",
        order = 8,
        enabled = false,

                name = "Operación - Red Dagger",
        shortName = "M08",
        generalObjective = "Toma la base de Chaghcharan.\n",

                        

        briefing =
            "OBJETIVO:\n" ..
            "Toma la base de Chaghcharan.\n" ..

            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Captura Chaghcharan\n\n"..

            

            

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            --"Capturar Camp Bastion: 500.000.000\n" ..

            

            "Mision Completada: 3.000.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = 63093,
                z = -91664
            },

            zoneName = nil,

            title = "M08- Operación - Red Dagger",
            text =
                "MISION 08\n" ..
                "Toma la base de Chaghcharan.\n" ..
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M08 - Operación - Red Dagger",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 8000, value = 1 },
            },
            onSuccess = {
                { flag = 8001, value = 1 },
            },
            onFail = {
                { flag = 8002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {
--------------------------------------            
{
                 id = "OBJ_CAPTURAR_BASE_CAMP_Chaghcharan",
                 name = "Capturar Chaghcharan",
                 drawName = "Capturar base: Chaghcharan",
                enabled = true,
                 requiredForMission = true,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Chaghcharan",
                    op = "==",
                     coalition = 2,
            
                     smoke = {
                         enabled = false,
                         refreshSeconds = 240,
                         stopOnPass = true,
                         autoTarget = true,
                         captureColor = "orange"
            
                         -- items = {
                         --     { targetKind = "airbase", airbaseName = "Khalkhalah Air Base", color = "orange" },
                        --     { targetKind = "zone", zoneName = "Z_CAPTURA_154", color = "orange" },
                         -- }
                     }
                 },
            
                 setFlagOnPass = {
                     flag = 8004,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 8005,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,    
                     coalition = 2,
                     amount = 500000000
                 }
             },
-----------------------------------------------------------------------------------------------------------------------------------------------------------


        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 3000000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },       
        ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- PLANTILLA BASE PARA M09
    ----------------------------------------------------------------
    ----------------------------------------------------------------
    ----------------------------------------------------------------
 ----------------------------------------------------------------    
{
        id = "M09",
        order = 9,
        enabled = false,

                name = "Operación - Night Talon",
        shortName = "M09",
        generalObjective = "Hemos descubierto documentos que nos indican 10 posibles ubicaciones de OSAMA BIN LADEN\n"..
                           "Busca en las posibles locaciones y bombardea los sitios.\n\n"..

                           "Ubicación 01: MGRS GRID: 41 S NT 84037 27160\n" ..
                "Ubicación 02: MGRS GRID: 41 S QT 15435 28678\n" ..  
                "Ubicación 03: MGRS GRID: 41 S QT 46660 70361\n" .. 
                "Ubicación 04: MGRS GRID: 41 S QT 12197 94579\n" .. 
                "Ubicación 05: MGRS GRID: 41 S QU 70522 16362\n" ..
                "Ubicación 06: MGRS GRID: 42 S UD 14291 45388\n" ..      
                "Ubicación 07: MGRS GRID: 42 S UC 03678 51910\n" .. 
                "Ubicación 08: MGRS GRID: 41 S PT 13032 20596\n" ..  
                "Ubicación 09: MGRS GRID: 41 S QT 56387 24903\n" .. 
                "Ubicación 10: MGRS GRID: 42 S TD 72295 16029\n\n\n",

                        

        briefing =
            "OBJETIVO:\n" ..
            "Encuentra el Escondite de OSAMA BIN LADEN\n" ..

            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Neutraliza al Objetivo\n\n"..

            "COORDENADAS\n\n" ..
                "Ubicación 01: MGRS GRID: 41 S NT 84037 27160\n" ..
                "Ubicación 02: MGRS GRID: 41 S QT 15435 28678\n" ..  
                "Ubicación 03: MGRS GRID: 41 S QT 46660 70361\n" .. 
                "Ubicación 04: MGRS GRID: 41 S QT 12197 94579\n" .. 
                "Ubicación 05: MGRS GRID: 41 S QU 70522 16362\n" ..
                "Ubicación 06: MGRS GRID: 42 S UD 14291 45388\n" ..      
                "Ubicación 07: MGRS GRID: 42 S UC 03678 51910\n" .. -- 
                "Ubicación 08: MGRS GRID: 41 S PT 13032 20596\n" ..  
                "Ubicación 09: MGRS GRID: 41 S QT 56387 24903\n" .. 
                "Ubicación 10: MGRS GRID: 42 S TD 72295 16029\n" .. 



            

            

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            --"Capturar Camp Bastion: 500.000.000\n" ..

            

            "Mision Completada: 3.000.000.000\n\n" ..
            "IMPORTANTE:\n",
            

        autoStart = true,

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE ACTIVACION
        -- La secuencia base ya valida que la anterior este completada.
        ----------------------------------------------------------------
        activationConditions = {
            -- ejemplo:
            -- { flag = 1500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- MARK EN F10
        -- mode = "point" o "zone"
        ----------------------------------------------------------------
        map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = -8834,
                z = -105270
            },

            zoneName = nil,

            title = "M09- Operación - Night Talon",  
            text =
                "MISION 09\n" ..
                "Encuentra el Escondite de OSAMA BIN LADEN\n" ..
                "Ubicación 01: MGRS GRID: 41 S NT 84037 27160\n" ..
                "Ubicación 02: MGRS GRID: 41 S QT 15435 28678\n" ..  
                "Ubicación 03: MGRS GRID: 41 S QT 46660 70361\n" .. 
                "Ubicación 04: MGRS GRID: 41 S QT 12197 94579\n" .. 
                "Ubicación 05: MGRS GRID: 41 S QU 70522 16362\n" ..
                "Ubicación 06: MGRS GRID: 42 S UD 14291 45388\n" ..      
                "Ubicación 07: MGRS GRID: 42 S UC 03678 51910\n" ..  
                "Ubicación 08: MGRS GRID: 41 S PT 13032 20596\n" ..  
                "Ubicación 09: MGRS GRID: 41 S QT 56387 24903\n" .. 
                "Ubicación 10: MGRS GRID: 42 S TD 72295 16029\n" .. 
                "Revisa F10 > Sistema de Misiones"
        },

        ----------------------------------------------------------------
        -- DRAW DINAMICO EN F10
        -- Se posiciona tomando como ancla el punto de map y sumando offsetX/Z
        -- Muestra solo objetivos obligatorios pendientes:
        -- enabled = true y requiredForMission = true
        ----------------------------------------------------------------
        draw = {
            enabled = true,
            title = "M09 - Operación - Night Talon",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },

        ----------------------------------------------------------------
        -- FLAGS DE ESTADO DE ESTA MISION
        ----------------------------------------------------------------
        flags = {
            onActivate = {
                { flag = 9000, value = 1 },
            },
            onSuccess = {
                { flag = 9001, value = 1 },
            },
            onFail = {
                { flag = 9002, value = 1 },
            },
        },

        ----------------------------------------------------------------
        -- REGLAS INTERNAS DE FLAGS DE ESTA MISION
        -- Estas SI son por mision, no globales.
        ----------------------------------------------------------------
        missionFlagRules = {
           
        },

        ----------------------------------------------------------------
        -- VALIDADORES TECNICOS
        -- Sirven para chequeos auxiliares y seteo de flags
        -- No completan la mision solos, salvo que uses esas flags
        -- en successConditions o en reglas internas.
        ----------------------------------------------------------------
        validators = {
            warehouse = {
                -- ejemplo:
                -- {
                --     key = "SALIDA_AIM120",
                --     baseName = "BASE_AQUI",
                --     category = "weapon",
                --     itemName = "AIM-120C",
                --     removedAtLeast = 8,
                --     setFlagOnPass = {
                --         flag = 2010,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            groupChecks = {
                -- ejemplo:
                -- {
                --     key = "GRUPO_ESCOLTA_VIVO",
                --     groupName = "GrupoEscolta_AQUI",
                --     metric = "aliveUnits", -- aliveUnits | totalUnits | lifeSum | lifePercent
                --     op = ">=",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2002,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            },

            unitChecks = {
                -- ejemplo:
                -- {
                --     key = "UNIDAD_RADAR_VIVA",
                --     unitName = "Radar_AQUI",
                --     metric = "alive", -- alive | life | life0 | lifePercent
                --     op = "==",
                --     value = 1,
                --     setFlagOnPass = {
                --         flag = 2003,
                --         value = 1,
                --         elseValue = 0
                --     }
                -- }
            }
        },

        ----------------------------------------------------------------
        -- OBJETIVOS SECUNDARIOS
        -- Cada objetivo puede pagar o no
        -- Cada objetivo puede poner flags o no
        -- Cada objetivo puede ser obligatorio o no
        ----------------------------------------------------------------
        secondaryObjectives = {
--------------------------------------            
------------------------------------------------------------
            -- EJEMPLO OPCIONAL: destruir una unidad concreta
            ------------------------------------------------------------
             {
                 id = "OBJ_DESTRUIR_OSAMA",
            name = "Objetivo: OSAMA BIN LADEN",
                 enabled = true,
                requiredForMission = true,
            
                 monitor = {
                     kind = "unit",
                     unitName = "MT_09_01",
                     metric = "alive",
                    op = "==",
                     value = 0
                 },
            
                 setFlagOnPass = {
                     flag = 9005,
                     value = 1,
                     elseValue = 0
             },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 99999999999999999999
                 }
             },
-----------------------------------------------------------------------------------------------------------------------------------------------------------


        },

        ----------------------------------------------------------------
        -- PAGO FINAL POR COMPLETAR LA MISION
        ----------------------------------------------------------------
        rewards = {
            enabled = true,
            coalition = 2,
            missionSuccessAmount = 3000000000
        },

        ----------------------------------------------------------------
        -- CONDICIONES EXTRA DE EXITO
        -- Se suman a los objetivos obligatorios
        ----------------------------------------------------------------
        successConditions = {
            -- ejemplo:
            -- { flag = 2500, op = "==", value = 1 }
        },

        ----------------------------------------------------------------
        -- CONDICIONES DE FALLO
        ----------------------------------------------------------------
        failConditions = {
            -- ejemplo:
            -- { flag = 2999, op = "==", value = 1 }
        }
    },       
}



