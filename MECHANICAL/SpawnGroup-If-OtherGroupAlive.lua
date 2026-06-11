if not mist then
    trigger.action.outText("ERROR: MIST no esta cargado.", 10)
    return
end

local grupoCarrier = "MT_07_CARRIER" -- Grupo del carrier ruso

local tiempoRevision = 5

local gruposAviones = {
    {
        base = "MT_07_SU33_01",
        actual = nil
    },
    {
        base = "MT_07_SU33_02",
        actual = nil
    }
}

local function grupoExiste(nombre)
    local g = Group.getByName(nombre)

    if g and g:isExist() then
        return true
    end

    return false
end

local function grupoVivo(nombre)
    local g = Group.getByName(nombre)

    if g and g:isExist() and g:getSize() > 0 then
        return true
    end

    return false
end

local function obtenerNombreClon(data)
    if type(data) == "string" then
        return data
    end

    if type(data) == "table" then
        return data.name or data.groupName
    end

    return nil
end

local function clonarGrupoAviones(item)
    local nuevo = mist.cloneGroup(item.base, true)
    local nombreNuevo = obtenerNombreClon(nuevo)

    if nombreNuevo then
        item.actual = nombreNuevo
        trigger.action.outText("Grupo creado: " .. item.actual, 5)
    else
        trigger.action.outText("ERROR: No se pudo clonar: " .. tostring(item.base), 8)
    end
end

local function revisar()
    -- Si el carrier no existe, no hacemos nada
    if not grupoExiste(grupoCarrier) then
        return timer.getTime() + tiempoRevision
    end

    -- Revisar cada grupo de aviones
    for _, item in ipairs(gruposAviones) do

        -- Si aun no existe su clon activo, lo crea
        if not item.actual then
            clonarGrupoAviones(item)

        -- Si el clon activo murio completo, crea otro
        elseif not grupoVivo(item.actual) then
            clonarGrupoAviones(item)
        end
    end

    return timer.getTime() + tiempoRevision
end

timer.scheduleFunction(revisar, nil, timer.getTime() + tiempoRevision)