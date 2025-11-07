-- ============================================
-- AMBIENT AMBUSH - PED BLIP SERVER SCRIPT
-- ============================================

-- Cache structure: PedNetIDs[playerServerId] = { netId1, netId2, ... }
local PedNetIDs = {}

-- Cleanup timers: CleanupTimers[playerServerId] = timerId
local CleanupTimers = {}

-- ============================================
-- NETWORK ID CACHING
-- ============================================

-- Store network IDs for an ambush host
RegisterNetEvent('ambush:server:cacheNetworkIds')
AddEventHandler('ambush:server:cacheNetworkIds', function(networkIds)
    local src = source
    
    if not networkIds or type(networkIds) ~= "table" then
        if Config.Debug then
            print("[PedBlip Server] Invalid network IDs received from player " .. src)
        end
        return
    end
    
    -- Cache the network IDs for this player
    PedNetIDs[src] = networkIds
    
    if Config.Debug then
        print("[PedBlip Server] Cached " .. #networkIds .. " network IDs for player " .. src)
    end
end)

-- Request network IDs for a specific host player
RegisterNetEvent('ambush:server:requestNetworkIds')
AddEventHandler('ambush:server:requestNetworkIds', function(hostServerId)
    local src = source
    
    if not hostServerId then
        if Config.Debug then
            print("[PedBlip Server] Invalid host server ID requested by player " .. src)
        end
        return
    end
    
    -- Get cached network IDs for the host
    local networkIds = PedNetIDs[hostServerId]
    
    if networkIds and #networkIds > 0 then
        if Config.Debug then
            print("[PedBlip Server] Sending " .. #networkIds .. " network IDs to player " .. src .. " for host " .. hostServerId)
        end
        
        -- Send the network IDs back to the requesting client
        TriggerClientEvent('ambush:client:receiveNetworkIds', src, networkIds)
        
        -- Also tell the client to start cooldown (per missionFlow.md line 12)
        -- This handles players who join the ambush area AFTER it spawns
        -- Players who were in the area at spawn time already got cooldown via 'ambush:server:notifyParticipantsCooldown'
        TriggerClientEvent('ambush:client:startCooldown', src)
    else
        if Config.Debug then
            print("[PedBlip Server] No network IDs found for host " .. hostServerId .. " (requested by player " .. src .. ")")
        end
    end
end)

-- Ambush ended (all NPCs dead) - start 5-minute cleanup timer
RegisterNetEvent('ambush:server:ambushEnded')
AddEventHandler('ambush:server:ambushEnded', function()
    local src = source
    
    if not PedNetIDs[src] then
        if Config.Debug then
            print("[PedBlip Server] Player " .. src .. " reported ambush ended, but no cache found")
        end
        return
    end
    
    -- Cancel any existing cleanup timer
    if CleanupTimers[src] then
        if Config.Debug then
            print("[PedBlip Server] Cancelling existing cleanup timer for player " .. src)
        end
        CleanupTimers[src] = nil
    end
    
    if Config.Debug then
        print("[PedBlip Server] Ambush ended for player " .. src .. ", scheduling cleanup in 5 minutes")
    end
    
    -- Schedule cleanup after 5 minutes (300000 ms)
    CleanupTimers[src] = SetTimeout(300000, function()
        if PedNetIDs[src] then
            if Config.Debug then
                print("[PedBlip Server] 5-minute timer expired, clearing network IDs for player " .. src)
            end
            PedNetIDs[src] = nil
            CleanupTimers[src] = nil
        end
    end)
end)

-- Clear network IDs immediately (called when ambush is despawned early)
RegisterNetEvent('ambush:server:clearNetworkIds')
AddEventHandler('ambush:server:clearNetworkIds', function()
    local src = source
    
    -- Cancel cleanup timer if it exists
    if CleanupTimers[src] then
        if Config.Debug then
            print("[PedBlip Server] Cancelling cleanup timer for player " .. src)
        end
        CleanupTimers[src] = nil
    end
    
    if PedNetIDs[src] then
        if Config.Debug then
            print("[PedBlip Server] Cleared network IDs for player " .. src)
        end
        PedNetIDs[src] = nil
    end
end)

-- Clean up when player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    
    -- Cancel cleanup timer if it exists
    if CleanupTimers[src] then
        if Config.Debug then
            print("[PedBlip Server] Player " .. src .. " disconnected, cancelling cleanup timer")
        end
        CleanupTimers[src] = nil
    end
    
    if PedNetIDs[src] then
        if Config.Debug then
            print("[PedBlip Server] Player " .. src .. " disconnected, clearing their cached network IDs")
        end
        PedNetIDs[src] = nil
    end
end)

-- Debug command to view cached data
if Config.Debug then
    RegisterNetEvent('ambush:server:debug:pedblips')
    AddEventHandler('ambush:server:debug:pedblips', function()
        print("[PedBlip Server] === CACHED NETWORK IDs ===")
        local totalHosts = 0
        local totalPeds = 0
        
        for playerId, networkIds in pairs(PedNetIDs) do
            totalHosts = totalHosts + 1
            totalPeds = totalPeds + #networkIds
            print("  Player " .. playerId .. ": " .. #networkIds .. " peds")
        end
        
        print("[PedBlip Server] Total: " .. totalHosts .. " hosts, " .. totalPeds .. " peds")
        print("[PedBlip Server] ========================")
    end)
    
    RegisterCommand('ambush:debug:pedblips', function(source, args, rawCommand)
        TriggerEvent('ambush:server:debug:pedblips')
    end, false)
end