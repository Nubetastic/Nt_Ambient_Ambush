-- Keeps runtime no-spawn coordinates synchronized with the server.

local function normalizeCoords(coords)
    if coords == nil then
        return nil
    end

    local ok, x, y, z = pcall(function()
        return tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    end)

    if not ok or not x or not y or not z then
        return nil
    end

    return vector3(x, y, z)
end

local function applyCoords(coords, range)
    coords = normalizeCoords(coords)
    range = tonumber(range)

    if not coords or not range or range <= 0 then
        return
    end

    -- Update an existing entry at this position instead of adding duplicate vector keys.
    for configuredCoords in pairs(ConfigCoords.Coords) do
        if configuredCoords.x == coords.x and configuredCoords.y == coords.y and configuredCoords.z == coords.z then
            ConfigCoords.Coords[configuredCoords] = range
            return
        end
    end

    ConfigCoords.Coords[coords] = range
end

RegisterNetEvent('Nt_Ambient_Ambush:client:addCoords', function(coords, range)
    applyCoords(coords, range)
end)

RegisterNetEvent('Nt_Ambient_Ambush:client:syncCoords', function(entries)
    for _, entry in ipairs(entries or {}) do
        applyCoords(entry.coords, entry.range)
    end
end)

CreateThread(function()
    TriggerServerEvent('Nt_Ambient_Ambush:server:requestDynamicCoords')
end)
