local loaderPath = lfs.writedir() .. "Scripts\\HorizontDev\\SystemCampaingDCS\\CTDL\\CTDL_Load.lua"

local chunk, err = loadfile(loaderPath)
if not chunk then
    env.error("[HDEV-BOOT] No se pudo cargar CTDL_Load.lua: " .. tostring(err))
    trigger.action.outText("[HDEV-BOOT] Error cargando CTDL_Load.lua. Revisa ruta y nombre del archivo.", 15)
    return
end

local ok, runErr = pcall(chunk)
if not ok then
    env.error("[HDEV-BOOT] Error ejecutando CTDL_Load.lua: " .. tostring(runErr))
    trigger.action.outText("[HDEV-BOOT] Error ejecutando CTDL_Load.lua. Revisa dcs.log", 15)
end