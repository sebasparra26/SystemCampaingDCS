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
    -- PLANTILLA BASE PARA M03
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

            title = "M04 - Operación - Iron Valley",
            text =
                "MISION 04\n" ..
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


}



