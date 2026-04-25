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

                name = "Operación - Recuperación",
        shortName = "M01",
        generalObjective = "Captura, Neutraliza y extrae los recursos del enemigo\n"..
                            "Lat Long Decimal Minutes: N 69°17.588'   E 16°08.456'\n"..
                            "MGRS GRID: 33 W WS 45020 87468\n"..
                            "Altitude: 6 m / 21 feet\n",

        briefing =
            "OBJETIVO:\n" ..
            "Destruir el EWR, El barco y Extraer los recursos de su almacen.\n\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Destruir el EWR.\n"..
            "2. Destruir el barco enemigo.\n"..
            "3. Capturar la Base: Andoya.\n"..
            "4. Extraer los recursos del almacen y llevarlos a la base.\n\n" ..
            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
            "Objetivo EWR: 30.000.000\n" ..
            "Objetivo Barco enemigo: 60.000.000\n" ..
            "Extraer Elementos de la zona: 15.000.000\n" ..
            "Mision Completada: 500.000.000\n\n" ..
            "IMPORTANTE:\n" ..
            "Coordenadas:\n" ..
            "Lat Long Decimal Minutes: N 69°17.588'   E 16°08.456'\n"..
            "MGRS GRID: 33 W WS 45020 87468\n"..
            "Altitude: 6 m / 21 feet\n",

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
                x = 150940,
                z = -254283
            },

            zoneName = nil,

            title = "M01 - Operación - Recuperación",
            text =
                "MISION 01\n" ..
                "Captura, Neutraliza y extrae los recursos del enemigo\n\n" ..
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
            title = "M01 - Operación - Recuperación",
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
                { flag = 2100, value = 1 },
            },
            onSuccess = {
                { flag = 2101, value = 1 },
            },
            onFail = {
                { flag = 2102, value = 1 },
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
                id = "OBJ_DESTRUIR_GRUPO_SAM",
                name = "SAM",
                drawName = "Destruir el radar EWR",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "MT_01_EWR",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 2000,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 2001,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 30000000
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
                 id = "OBJ_CAPTURAR_BASE",
                 name = "Capturar Andoya",
                 drawName = "Capturar base Andoya",
                enabled = false,
                 requiredForMission = false,
            
                 monitor = {
                     kind = "base_capture",
                     baseName = "Andoya",
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
                     flag = 2004,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 2005,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = false,
                     coalition = 2,
                     amount = 50000000
                 }
             },

            {
                id = "OBJ_DESTRUIR_GRUPO_SHIP",
                name = "SHIP",
                drawName = "Destruir el barco enemigo",
                enabled = false,
                requiredForMission = false,

                monitor = {
                    kind = "group",
                    groupName = "MT_01_SHIP",
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 2002,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 2003,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 60000000
                }
            },

            ------------------------------------------------------------
            -- OBJETIVO COMPUESTO DE WAREHOUSE
            -- Lee contra SystemWarehousesPersistanceSinai.json
            ------------------------------------------------------------
            {
                id = "OBJ_MULTI_WAREHOUSE",
                name = "Sacar aviones y armamento",
                drawName = "Sacar aviones y armamento",
                enabled = false,
                requiredForMission = false,

                monitor = {
                    kind = "warehouse",
                    baseName = "Andoya",
                    mode = "all", -- all | any | sum

                    items = {
                        --AVIONES:
                        --{ category = "aircraft", itemName = "UH-1H", label = "UH-1H - HUEY", removedAtLeast = 1 },
                        { category = "aircraft", itemName = "AH-64D_BLK_II", label = "AH-64D - APACHE", removedAtLeast = 2 },
                        { category = "aircraft", itemName = "FA-18C_hornet", label = "FA-18C - HORNET", removedAtLeast = 2 },
                        { category = "aircraft", itemName = "F-16C_50", label = "F-16C - VIPER", removedAtLeast = 2 },
                        
                        --WEAPONS:
                        { category = "weapon",   itemName = "weapons.containers.AAQ-28_LITENING", label = "POD LITENING LEFT", removedAtLeast = 2 },
                        { category = "weapon",   itemName = "weapons.containers.aaq-28LEFT litening", label = "POD LITENING LEFT", removedAtLeast = 2 },
                        { category = "weapon",   itemName = "weapons.containers.ah-64d_radar", label = "FCR CONTROL APACHE", removedAtLeast = 2 },
                        { category = "weapon",   itemName = "weapons.containers.alq-184long", label = "POD CONTRAMEDIDAS ELECTRONICAS", removedAtLeast = 2 },
                        { category = "weapon",   itemName = "weapons.missiles.AIM_120C", label = "AIM 120 C", removedAtLeast = 40 },
                        { category = "weapon",   itemName = "weapons.missiles.AIM_9X", label = "AIM 9 X", removedAtLeast = 80 },

           
                    }

                    -- si usaras mode = "sum":
                    -- removedAtLeastTotal = 34
                },

                setFlagOnPass = {
                    flag = 2006,
                    value = 1,
                    elseValue = 0
                },

                setFlagOnActive = {
                    flag = 2007,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 15000000
                }
            },




           

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
                     flag = 2008,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 2009,
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
            missionSuccessAmount = 500000000
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
     {
         id = "M02",
         order = 2,
         enabled = true,
    
        name = "Operación - Pajaro Herido",
        shortName = "M02",
        generalObjective = "Rescata al técnico herido en la zona\n\n"..
                            "Lat Long Decimal Minutes: N 69°27.938'   E 25°30.347'\n"..
                            "MGRS GRID: 35 W MT 41511 06998\n"..
                            "Altitude: 130 m / 426 feet\n\n\n"..
                            "Llevalo a la base principal (BODO).\n\n",

        briefing =
            "OBJETIVO:\n" ..
            "Rescata al técnico herido en la zona, Asegura la zona para la llegada de los grupos de rescate.\n\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Rescata al técnico\n" ..

            "PAGOS:\n" ..
            --"Captura: 0 --\n" ..
         
            "IMPORTANTE:\n" ..
            "Coordenadas:\n" ..
            "Lat Long Decimal Minutes: N 69°27.938'   E 25°30.347'\n"..
            "MGRS GRID: 35 W MT 41511 06998\n"..
            "Altitude: 130 m / 426 feet\n",

        autoStart = true,
    
         --activationConditions = {
             --{ flag = 2101, op = "==", value = 1 }
         --},
    
         map = {
            enabled = true,
            mode = "point", -- point | zone

            point = {
                x = 169159,
                z = 113617
            },

            zoneName = nil,

            title = "M02 - Pajaro Herido",
            text =
                "MISION 02\n" ..
                "Rescata al técnico herido en la zona, Asegura la zona para la llegada de los grupos de rescate.\n\n" ..
                "Revisa F10 > Sistema de Misiones"
        },

         draw = {
            enabled = true,
            title = "M02 - Pajaro Herido",
            generalObjective = nil,
            offsetX = 5000,
            offsetZ = 2500,
            fontSize = 11,
            textColor = "black",
            fillColor = {176, 133, 0, 100},
            coalition = -1
        },
    
        flags = {
             onActivate = {
                { flag = 2200, value = 1 },
             },
            onSuccess = {
                { flag = 2201, value = 1 },
            },
            onFail = {
                { flag = 2202, value = 1 },
            }
        },
    
        missionFlagRules = {
         },
    
         validators = {
             warehouse = {
             },
             groupChecks = {
             },
             unitChecks = {
                {
            key = "TECNICO_HERIDO_MUERTO",
            unitName = "US_TROOP_01",
            metric = "alive",
            op = "==",
            value = 0,

            setFlagOnPass = {
                flag = 2999,
                value = 1,
                elseValue = 0
            }
        }
             }
         },
    
         secondaryObjectives = {
            {
                 id = "OBJ_RADAR_LLEGA_VIVO_ZONA",
                 name = "Rescata al técnico herido",
                 drawName = "Rescata al técnico herido",
                 enabled = true,
                requiredForMission = true,
            
                 monitor = {
                    kind = "unit_alive_in_zone",
                     unitName = "US_TROOP_01",
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
                     flag = 2006,
                     value = 1,
                     elseValue = 0
                 },
            
                 setFlagOnActive = {
                     flag = 2007,
                     value = 1,
                     elseValue = 0
                 },
            
                 reward = {
                     enabled = true,
                    coalition = 2,
                     amount = 5000000
                 }
             },
         },
    
         rewards = {
             enabled = true,
             coalition = 2,
             missionSuccessAmount = 10000000
         },
    
         successConditions = {
         },
    
         failConditions = {
            { flag = 2999, op = "==", value = 1 },
            
         }
     },
}