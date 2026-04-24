----------------------------------------------------------------
-- HDEV_MissionDB.lua
-- Base de datos de misiones
-- Compatible con HDEV_MissionSystem_Core v1.4.1
----------------------------------------------------------------

HDEV_MissionDB = HDEV_MissionDB or {}
local MDB = HDEV_MissionDB

MDB.VERSION = "1.4.1"

MDB.MISSIONS = {

    ----------------------------------------------------------------
    -- M01
    ----------------------------------------------------------------
    {
        id = "M01",
        order = 1,
        enabled = true,

        name = "Rescate de 4 F-16, armamento y destruccion SAM",
        shortName = "M01",

        briefing =
            "OBJETIVO:\n" ..
            "Extraer recursos aereos desde la base indicada y destruir el grupo SAM.\n\n" ..
            "OBJETIVOS OBLIGATORIOS:\n" ..
            "1. Sacar 4 F-16C_50, 2 A-10C y armamento adicional del warehouse.\n" ..
            "2. Destruir el grupo SAM configurado.\n\n" ..
            "PAGOS:\n" ..
            "Objetivo de warehouse: 3.000.000\n" ..
            "Objetivo SAM: 9.999.999.999\n" ..
            "Mision completada: 500.000.000\n\n" ..
            "IMPORTANTE:\n" ..
            "Reemplaza BASE_AQUI, coordenadas y nombres reales segun tu mision.",

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
                x = 425249,
                z = 391031
            },

            zoneName = nil,

            title = "M01 - Rescate F-16",
            text =
                "MISION 01\n" ..
                "Rescate de recursos aereos y destruccion SAM\n\n" ..
                "Revisa F10 > Sistema de Misiones"
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
            -- OBJETIVO COMPUESTO DE WAREHOUSE
            ------------------------------------------------------------
            {
                id = "OBJ_MULTI_WAREHOUSE",
                name = "Sacar aviones y armamento",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "warehouse",
                    baseName = "BASE_AQUI",
                    mode = "all", -- all | any | sum

                    items = {
                        { category = "aircraft", itemName = "F-16C_50", removedAtLeast = 4 },
                        { category = "aircraft", itemName = "A-10C", removedAtLeast = 2 },
                        { category = "weapon",   itemName = "AIM-120C", removedAtLeast = 20 },
                        { category = "weapon",   itemName = "AIM-9X", removedAtLeast = 8 }
                    }

                    -- si usaras mode = "sum":
                    -- removedAtLeastTotal = 34
                },

                setFlagOnPass = {
                    flag = 2001,
                    value = 1,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 3000000
                }
            },

            ------------------------------------------------------------
            -- OBJETIVO OBLIGATORIO: destruir grupo SAM completo
            -- IMPORTANTE:
            -- groupName debe ser el nombre exacto del grupo
            -- El core 1.4.1 ya soporta requireExists=true correctamente
            -- cuando el grupo existio y luego fue destruido.
            ------------------------------------------------------------
            {
                id = "OBJ_DESTRUIR_GRUPO_SAM",
                name = "SAM",
                enabled = true,
                requiredForMission = true,

                monitor = {
                    kind = "group",
                    groupName = "01",
                    requireExists = true,
                    metric = "aliveUnits",
                    op = "==",
                    value = 0
                },

                setFlagOnPass = {
                    flag = 2008,
                    value = 22,
                    elseValue = 0
                },

                reward = {
                    enabled = true,
                    coalition = 2,
                    amount = 9999999999
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
            --         requireExists = true,
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
    -- PLANTILLA BASE PARA M02
    ----------------------------------------------------------------
    -- {
    --     id = "M02",
    --     order = 2,
    --     enabled = true,
    --
    --     name = "Nombre M02",
    --     shortName = "M02",
    --     briefing = "Briefing de la mision 02",
    --
    --     autoStart = true,
    --
    --     activationConditions = {
    --         { flag = 2101, op = "==", value = 1 }
    --     },
    --
    --     map = {
    --         enabled = true,
    --         mode = "zone",
    --         point = {
    --             x = 0,
    --             z = 0
    --         },
    --         zoneName = "ZONA_MISION_02",
    --         title = "M02",
    --         text = "Texto de mapa M02"
    --     },
    --
    --     flags = {
    --         onActivate = {
    --             { flag = 2200, value = 1 },
    --         },
    --         onSuccess = {
    --             { flag = 2201, value = 1 },
    --         },
    --         onFail = {
    --             { flag = 2202, value = 1 },
    --         }
    --     },
    --
    --     missionFlagRules = {
    --     },
    --
    --     validators = {
    --         warehouse = {
    --         },
    --         groupChecks = {
    --         },
    --         unitChecks = {
    --         }
    --     },
    --
    --     secondaryObjectives = {
    --     },
    --
    --     rewards = {
    --         enabled = true,
    --         coalition = 2,
    --         missionSuccessAmount = 10000000
    --     },
    --
    --     successConditions = {
    --     },
    --
    --     failConditions = {
    --     }
    -- },
}