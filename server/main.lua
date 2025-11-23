-- ============================================
-- AMBIENT AMBUSH - MAIN SERVER SCRIPT
-- ============================================

-- ============================================
-- AMBUSH TRACKING SYSTEM
-- ============================================

-- Active ambushes tracked by server
-- Key: string format "hostServerId_ambushId"
-- Value: {
--   hostServerId = number,
--   ambushId = number,
--   createdAt = GetGameTimer(),
--   playersInAmbush = {serverId, serverId, ...}
-- }
local ActiveAmbushes = {}

-- Register a new ambush on the server
RegisterNetEvent('ambush:server:registerAmbush')
AddEventHandler('ambush:server:registerAmbush', function(ambushId)
    local hostServerId = source
    local key = hostServerId .. "_" .. ambushId
    
    if not ambushId or ambushId <= 0 then
        if Config.Debug then
            print("[Ambush Server] Invalid ambush ID from host " .. hostServerId)
        end
        return
    end
    
    ActiveAmbushes[key] = {
        hostServerId = hostServerId,
        ambushId = ambushId,
        createdAt = GetGameTimer(),
        playersInAmbush = { hostServerId }
    }
    
    if Config.Debug then
        print(string.format("[Ambush Server] Registered ambush %d from host %d", ambushId, hostServerId))
    end
end)

-- Add a player to an active ambush
RegisterNetEvent('ambush:server:addPlayerToAmbush')
AddEventHandler('ambush:server:addPlayerToAmbush', function(hostServerId, ambushId)
    local playerServerId = source
    local key = hostServerId .. "_" .. ambushId
    
    if ActiveAmbushes[key] then
        -- Check if player is already in the list
        local alreadyIn = false
        for _, id in ipairs(ActiveAmbushes[key].playersInAmbush) do
            if id == playerServerId then
                alreadyIn = true
                break
            end
        end
        
        if not alreadyIn then
            table.insert(ActiveAmbushes[key].playersInAmbush, playerServerId)
            if Config.Debug then
                print(string.format("[Ambush Server] Player %d joined ambush %d (total: %d)", playerServerId, ambushId, #ActiveAmbushes[key].playersInAmbush))
            end
        end
    end
end)

-- Validate if an ambush still exists
RegisterNetEvent('ambush:server:validateAmbush')
AddEventHandler('ambush:server:validateAmbush', function(hostServerId, ambushId, callback)
    local key = hostServerId .. "_" .. ambushId
    local exists = ActiveAmbushes[key] ~= nil
    
    if Config.Debug and not exists then
        print(string.format("[Ambush Server] Ambush %d from host %d no longer tracked", ambushId, hostServerId))
    end
    
    TriggerClientEvent('ambush:client:ambushValidationResponse', source, exists)
end)

-- Clear ambush from server when it ends
RegisterNetEvent('ambush:server:clearAmbush')
AddEventHandler('ambush:server:clearAmbush', function(ambushId)
    local hostServerId = source
    local key = hostServerId .. "_" .. ambushId
    
    if ActiveAmbushes[key] then
        ActiveAmbushes[key] = nil
        if Config.Debug then
            print(string.format("[Ambush Server] Cleared ambush %d from host %d", ambushId, hostServerId))
        end
    end
end)

-- Notify a participant to join an ambush
-- This is triggered by the host when they detect a new player in range
RegisterNetEvent('ambush:server:notifyParticipant')
AddEventHandler('ambush:server:notifyParticipant', function(participantServerId, hostServerId)
    if not participantServerId or not hostServerId then
        if Config.Debug then
            print("[Ambush Server] Invalid participant or host server ID")
        end
        return
    end
    
    if Config.Debug then
        print(string.format("[Ambush Server] Notify participant %s to join host %s", participantServerId, hostServerId))
    end
    
    -- Tell the participant to initialize blips
    TriggerClientEvent('ambush:client:joinAmbush', participantServerId, hostServerId)
end)

-- Notify participants to start cooldown when ambush spawns
-- This is triggered by the host after scanning for players at spawn time
RegisterNetEvent('ambush:server:notifyParticipantsCooldown')
AddEventHandler('ambush:server:notifyParticipantsCooldown', function(participantServerIds)
    local src = source
    
    if not participantServerIds or type(participantServerIds) ~= "table" then
        if Config.Debug then
            print("[Ambush Server] Invalid participant server IDs received from host " .. src)
        end
        return
    end
    
    if Config.Debug then
        print(string.format("[Ambush Server] Host %s will notify %d participants to start cooldown", src, #participantServerIds))
    end
    
    -- Notify each participant to start cooldown
    for _, participantId in ipairs(participantServerIds) do

        TriggerClientEvent('ambush:client:startCooldown', participantId)
    end
end)

-- Handle cleanup notification from host client and broadcast to other clients
RegisterNetEvent('ambush:server:notifyClientsCleanup')
AddEventHandler('ambush:server:notifyClientsCleanup', function(clientServerIds)
    local src = source
    
    if not clientServerIds or type(clientServerIds) ~= "table" then
        if Config.Debug then
            print("[Ambush Server] Invalid client server IDs received from host " .. src)
        end
        return
    end
    
    if Config.Debug then
        print(string.format("[Ambush Server] Host %s requesting cleanup for %d other clients", src, #clientServerIds))
    end
    
    for _, clientId in ipairs(clientServerIds) do
        TriggerClientEvent('ambush:client:performCleanup', clientId)
    end
end)

-- Debug command to view all cached data
if Config.Debug then
    RegisterCommand('ambush:debug:cache', function(source, args, rawCommand)
        -- Trigger individual debug events
        TriggerEvent('ambush:server:debug:pedblips')
        

    end, false)
end