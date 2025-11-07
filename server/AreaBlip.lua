-- ============================================
-- AMBIENT AMBUSH - AREA BLIP SERVER SCRIPT
-- ============================================

-- Cache structure: AreaBlipCoords[playerServerId] = { x, y, z }
local AreaBlipCoords = {}

-- ============================================
-- AREA BLIP COORDINATE CACHING
-- ============================================

-- Store area blip coordinates for an ambush host
RegisterNetEvent('ambush:server:shareAreaBlipCoords')
AddEventHandler('ambush:server:shareAreaBlipCoords', function(coords)
    local src = source
    
    if not coords or not coords.x or not coords.y or not coords.z then
        if Config.Debug then
            print("[Area Blip Server] Invalid coordinates received from player " .. src)
        end
        return
    end
    
    -- Cache the coordinates for this player
    AreaBlipCoords[src] = coords
    
    if Config.Debug then
        print("[Area Blip Server] Cached area blip coordinates for player " .. src .. ": " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)
    end
end)

-- Request area blip coordinates for a specific host player
RegisterNetEvent('ambush:server:requestAreaBlipCoords')
AddEventHandler('ambush:server:requestAreaBlipCoords', function(hostServerId)
    local src = source
    
    if not hostServerId then
        if Config.Debug then
            print("[Area Blip Server] Invalid host server ID requested by player " .. src)
        end
        return
    end
    
    -- Get cached coordinates for the host
    local coords = AreaBlipCoords[hostServerId]
    
    if coords then
        if Config.Debug then
            print("[Area Blip Server] Sending area blip coordinates to player " .. src .. " for host " .. hostServerId)
        end
        
        -- Send the coordinates back to the requesting client
        TriggerClientEvent('ambush:client:receiveAreaBlipCoords', src, coords)
    else
        if Config.Debug then
            print("[Area Blip Server] No area blip coordinates found for host " .. hostServerId .. " (requested by player " .. src .. ")")
        end
    end
end)

-- Clear area blip coordinates (called when ambush is despawned)
RegisterNetEvent('ambush:server:clearAreaBlipCoords')
AddEventHandler('ambush:server:clearAreaBlipCoords', function()
    local src = source
    
    if AreaBlipCoords[src] then
        if Config.Debug then
            print("[Area Blip Server] Cleared area blip coordinates for player " .. src)
        end
        AreaBlipCoords[src] = nil
    end
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    
    if AreaBlipCoords[src] then
        if Config.Debug then
            print("[Area Blip Server] Player " .. src .. " disconnected, clearing their cached area blip coordinates")
        end
        AreaBlipCoords[src] = nil
    end
end)