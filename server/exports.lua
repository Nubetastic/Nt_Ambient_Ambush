-- Runtime no-spawn coordinate exports.

local dynamicCoords = {}

local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function normalizeCoords(coords)
    if coords == nil then
        return nil
    end

    local ok, x, y, z = pcall(function()
        return tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    end)

    if not ok or not isFiniteNumber(x) or not isFiniteNumber(y) or not isFiniteNumber(z) then
        return nil
    end

    return vector3(x, y, z)
end

local function coordKey(coords)
    return ('%.12g:%.12g:%.12g'):format(coords.x, coords.y, coords.z)
end

local function setConfigCoords(coords, range)
    -- Reuse an existing vector key when the same position is already configured.
    for configuredCoords in pairs(ConfigCoords.Coords) do
        if configuredCoords.x == coords.x and configuredCoords.y == coords.y and configuredCoords.z == coords.z then
            ConfigCoords.Coords[configuredCoords] = range
            return
        end
    end

    ConfigCoords.Coords[coords] = range
end

-- Server export: add or update a no-spawn sphere at runtime.
-- Usage: exports['Nt_Ambient_Ambush']:addCoords(coords, range)
exports('addCoords', function(coords, range)
    local normalizedCoords = normalizeCoords(coords)
    range = tonumber(range)

    if not normalizedCoords then
        print('[Ambush] ERROR: addCoords requires coords with finite x, y, and z values')
        return false
    end

    if not isFiniteNumber(range) or range <= 0 then
        print('[Ambush] ERROR: addCoords requires a positive numeric range')
        return false
    end

    setConfigCoords(normalizedCoords, range)
    dynamicCoords[coordKey(normalizedCoords)] = {
        coords = normalizedCoords,
        range = range
    }

    TriggerClientEvent('Nt_Ambient_Ambush:client:addCoords', -1, normalizedCoords, range)

    if Config.Debug then
        print(('[Ambush] Added no-spawn coords %s with range %s'):format(tostring(normalizedCoords), tostring(range)))
    end

    return true
end)

RegisterNetEvent('Nt_Ambient_Ambush:server:requestDynamicCoords', function()
    local entries = {}

    for _, entry in pairs(dynamicCoords) do
        entries[#entries + 1] = entry
    end

    TriggerClientEvent('Nt_Ambient_Ambush:client:syncCoords', source, entries)
end)
