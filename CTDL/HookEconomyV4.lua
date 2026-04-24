-- =============================
-- HDEV_CTLD_EconomyHook.lua
-- =============================

USAR_ECONOMIA_CTLD = false

HDEV_CTLD_Economy = HDEV_CTLD_Economy or {}

local C = HDEV_CTLD_Economy

C.debug = false
C.blockUnknownCrate = false
C.denyWhenEconomyMissing = true

C.pricesByDesc = {
    ["Abrams M1A2C"] = 1625000,
    ["Leopard 2A6M"] = 1250000,
    ["Chieftain MK3"] = 625000,
    ["Leclerc"] = 2250000,
    ["Merkava MK4"] = 1125000,
    ["T 90"] = 500000,
    ["T 80UD"] = 450000,
    ["T 72B3"] = 300000,
    ["T 72B"] = 225000,

    ["MLRS Himars"] = 1250000,
    ["Himars GMLRS CM"] = 437500,
    ["Himars GMLRS HE"] = 437500,
    ["SpGH DANA"] = 375000,
    ["T155 Firtina"] = 550000,
    ["Paladin"] = 425000,
    ["SPH 2S19 Msta"] = 625000,
    ["Smerch 300mm CM"] = 666666,
    ["Smerch 300mm HE"] = 833333,
    ["Uragan BM"] = 750000,
    ["Grad URAL"] = 350000,
    ["SAU Akatsia"] = 300000,
    ["SAU 2C9"] = 400000,

    ["Hummer - JTAC - $100,000"] = 100000,
    ["M-818 Ammo Truck - $100,000"] = 100000,
    ["M-818 Ammo Truck 2"] = 100000,
    ["M-818 Ammo Truck 3"] = 100000,
    ["M-818 Ammo Truck 4"] = 100000,
    ["M-978 Tanker - $100,000"] = 100000,
    ["SKP-11 - JTAC - $100,000"] = 100000,
    ["Ural-375 Ammo Truck - $100,000"] = 100000,
    ["KAMAZ Truck 2"] = 100000,
    ["Ural-375 Ammo Truck 3"] = 100000,
    ["Ural-375 Ammo Truck 4"] = 100000,
    ["KAMAZ Ammo Truck - $100,000"] = 100000,
    ["EWR Radar"] = 1333333,
    ["FOB Crate - Small"] = 333333,
    ["MQ-9 Repear - $ 10,000,000"] = 10000000,
    ["RQ-1A Predator - $ 10,000,000"] = 10000000,

    ["M1097 Avenger"] = 333333,
    ["M48 Chaparral"] = 600000,
    ["Roland ADS"] = 1000000,
    ["Roland Radar"] = 1000000,
    ["Gepard AAA"] = 666666,
    ["LPWS C-RAM"] = 1166666,
    ["9K33 Osa"] = 500000,
    ["9P31 Strela-1"] = 266666,
    ["9K35M Strela-10"] = 333333,
    ["9K331 Tor"] = 1166666,
    ["2K22 Tunguska"] = 1333333,

    ["HAWK Launcher - $ 2,200,000"] = 2200000,
    ["HAWK Search Radar - $ 3,000,000"] = 3000000,
    ["HAWK Track Radar - $ 2,500,000"] = 2500000,
    ["HAWK PCP - $ 1,500,000"] = 1500000,
    ["HAWK CWAR - $ 2,000,000"] = 2000000,
    ["HAWK Repair - $ 1,000,000"] = 1000000,

    ["NASAMS Launcher 120C - $ 3,800,000"] = 3800000,
    ["NASAMS Search/Track Radar - $ 3,200,000"] = 3200000,
    ["NASAMS Command Post - $ 2,200,000"] = 2200000,
    ["NASAMS Repair - $ 1,200,000"] = 1200000,

    ["KUB Launcher - $ 1,500,000"] = 1500000,
    ["KUB Radar - $ 2,000,000"] = 2000000,
    ["KUB Repair - $ 800,000"] = 800000,

    ["BUK Launcher - $ 2,800,000"] = 2800000,
    ["BUK Search Radar - $ 3,500,000"] = 3500000,
    ["BUK CC Radar - $ 2,800,000"] = 2800000,
    ["BUK Repair - $ 1,200,000"] = 1200000,

    ["Patriot Launcher - $ 4,500,000"] = 4500000,
    ["Patriot Radar - $ 6,000,000"] = 6000000,
    ["Patriot ECS - $ 3,500,000"] = 3500000,
    ["Patriot ICC - $ 3,000,000"] = 3000000,
    ["Patriot EPP - $ 2,500,000"] = 2500000,
    ["Patriot AMG (optional) - $ 2,000,000"] = 2000000,
    ["Patriot Repair - $ 1,500,000"] = 1500000,

    ["S-300 Grumble TEL C - $ 4,200,000"] = 4200000,
    ["S-300 Grumble Flap Lid-A TR - $ 5,500,000"] = 5500000,
    ["S-300 Grumble Clam Shell SR - $ 4,000,000"] = 4000000,
    ["S-300 Grumble Big Bird SR - $ 6,500,000"] = 6500000,
    ["S-300 Grumble C2 - $ 3,500,000"] = 3500000,
    ["S-300 Repair - $ 1,800,000"] = 1800000
}

local function econLog(msg)
    if C.debug then
        env.info("[HDEV_CTLD_ECON] " .. tostring(msg))
    end
end

local function toInt(v)
    v = tonumber(v) or 0
    if v < 0 then v = 0 end
    return math.floor(v)
end

local function fmtMoney(v)
    if HDEV_Economy and HDEV_Economy.formatMoney then
        return HDEV_Economy.formatMoney(v)
    end
    return "$" .. tostring(toInt(v))
end

local function msg(heli, text, seconds)
    if heli and ctld and ctld.displayMessageToGroup then
        ctld.displayMessageToGroup(heli, text, seconds or 10)
    end
end

function C.getPrice(crate)
    if not crate then
        return 0
    end

    local desc = crate.desc and tostring(crate.desc) or nil
    if desc and C.pricesByDesc[desc] then
        return toInt(C.pricesByDesc[desc])
    end

    return 0
end

function HDEV_CTLD_Economy_getDisplayPrice(crate)
    if not USAR_ECONOMIA_CTLD then
        return nil
    end

    local price = C.getPrice(crate)
    if price <= 0 then
        return nil
    end

    return fmtMoney(price)
end

function CTLD_ECONOMIA_HOOK(_args, heliOverride, crateOverride)
    if not USAR_ECONOMIA_CTLD then
        return true
    end

    local heli = heliOverride or (ctld and ctld.getTransportUnit and ctld.getTransportUnit(_args[1]))
    if not heli then
        econLog("No se pudo resolver heli")
        return not C.denyWhenEconomyMissing
    end

    local crate = crateOverride
    if not crate and ctld and ctld.crateLookupTable then
        crate = ctld.crateLookupTable[tostring(_args[2])]
    end

    if not crate then
        econLog("No se pudo resolver crate")
        return not C.blockUnknownCrate
    end

    local desc = crate.desc or "Crate desconocido"
    local cost = C.getPrice(crate)

    if cost <= 0 then
        if C.blockUnknownCrate then
            msg(heli, "Este crate no tiene precio configurado: " .. tostring(desc), 10)
            return false
        end
        return true
    end

    if not HDEV_Economy or not HDEV_Economy.spend then
        msg(heli, "Sistema economico no disponible.", 10)
        return false
    end

    local coalition = heli:getCoalition()
    local ok, saldoRestante = HDEV_Economy.spend(coalition, cost, "CTLD crate: " .. tostring(desc))

    if not ok then
        msg(heli,
            "Fondos insuficientes para " .. tostring(desc) ..
            " | Costo: " .. fmtMoney(cost) ..
            " | Saldo: " .. fmtMoney(saldoRestante),
            10
        )
        return false
    end

    msg(heli,
        "Crate comprado: " .. tostring(desc) ..
        " | Costo: " .. fmtMoney(cost) ..
        " | Saldo restante: " .. fmtMoney(saldoRestante),
        10
    )

    return true
end