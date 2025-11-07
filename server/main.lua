-- ============================================
-- AMBIENT AMBUSH - MAIN SERVER SCRIPT
-- ============================================

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

-- Debug command to view all cached data
if Config.Debug then
    RegisterCommand('ambush:debug:cache', function(source, args, rawCommand)
        -- Trigger individual debug events
        TriggerEvent('ambush:server:debug:pedblips')
        

    end, false)
end