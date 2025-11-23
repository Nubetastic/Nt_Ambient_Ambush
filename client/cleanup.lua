-- ============================================
-- AMBIENT AMBUSH - CENTRALIZED CLEANUP SYSTEM
-- ============================================

-- ============================================
-- GLOBAL VARIABLES (shared across all files)
-- ============================================

-- Active ambush data
ActiveAmbush = nil

-- Ambush end time (for 5-minute loot timer)
AmbushEndTime = nil

-- Blip data
BlipCache = {}
AreaBlip = nil
AreaRadiusBlip = nil

-- ============================================
-- CLEANUP FUNCTIONS
-- ============================================

-- Remove all NPC blips
local function CleanupNPCBlips()
    if not Config.EnableBlips or not Config.PedBlip.Enabled then
        return
    end
    
    -- Remove all blips from cache
    for netId, data in pairs(BlipCache) do
        if data.blip and DoesBlipExist(data.blip) then
            Citizen.InvokeNative(0x86A652570E5F25DD, Citizen.PointerValueIntInitialized(data.blip)) -- RemoveBlip

        end
    end
    
    -- Clear the cache
    BlipCache = {}
    

end

-- Remove area blip
local function CleanupAreaBlip()
    if not Config.EnableBlips or not Config.AreaBlip.Enabled then
        return
    end
    
    -- Use the direct RemoveBlip native for more reliable cleanup
    if AreaBlip and DoesBlipExist(AreaBlip) then
        RemoveBlip(AreaBlip)
        AreaBlip = nil
    end
    
    if AreaRadiusBlip and DoesBlipExist(AreaRadiusBlip) then
        RemoveBlip(AreaRadiusBlip)
        AreaRadiusBlip = nil
    end
end

-- Delete all NPCs and their horses
local function DeleteAllNPCs()
    if not ActiveAmbush then
        return
    end
    
    -- Delete NPCs
    if ActiveAmbush.npcs then
        for _, npc in ipairs(ActiveAmbush.npcs) do
            if DoesEntityExist(npc) then
                DeleteEntity(npc)
            end
        end
    end
    
    -- Delete horses
    if ActiveAmbush.horses then
        for _, horse in ipairs(ActiveAmbush.horses) do
            if DoesEntityExist(horse) then
                DeleteEntity(horse)
                if Config.Debug then
                    print("[Cleanup] Deleted horse: " .. horse)
                end
            end
        end
    end
end

-- Main cleanup function - cleans up everything
function PerformAmbushCleanup()

    
    -- Cleanup NPC blips
    CleanupNPCBlips()
    
    -- Notify server to clear the ambush from tracking
    if ActiveAmbush then
        TriggerServerEvent('ambush:server:clearAmbush', ActiveAmbush.id)
    end
    
    -- Notify server to clear network IDs
    TriggerServerEvent('ambush:server:clearNetworkIds')
    
    -- Cleanup area blip
    CleanupAreaBlip()
    
    -- Notify server to clear area blip coordinates
    TriggerServerEvent('ambush:server:clearAreaBlipCoords')
    
    -- Delete all NPCs
    DeleteAllNPCs()
    
    -- Notify other clients in the ambush to clean up
    if ActiveAmbush and ActiveAmbush.nearbyPlayers then
        local otherPlayerIds = {}
        local myServerId = GetPlayerServerId(PlayerId())
        
        for _, cachedPlayer in ipairs(ActiveAmbush.nearbyPlayers) do
            if cachedPlayer.serverId ~= myServerId then
                table.insert(otherPlayerIds, cachedPlayer.serverId)
            end
        end
        
        if #otherPlayerIds > 0 then
            TriggerServerEvent('ambush:server:notifyClientsCleanup', otherPlayerIds)
            if Config.Debug then
                print("[Cleanup] Notifying " .. #otherPlayerIds .. " other clients to cleanup")
            end
        end
    end
    
    -- Clear ambush data
    if ActiveAmbush then
        if ActiveAmbush.targetMap then
            ActiveAmbush.targetMap = nil
        end
        if ActiveAmbush.npcTargets then
            ActiveAmbush.npcTargets = nil
        end
    end
    ActiveAmbush = nil
    AmbushEndTime = nil
    
    -- Reset all export overrides to default values after ambush ends
    BlipOverrides.PedBlip = nil
    BlipOverrides.AreaBlip = nil
    AdditionalPedCount = 0
    AdditionalAmbushChance = 0
    
    -- Reset group override after ambush ends
    groupOverwride = nil

end

-- Cleanup blips only (when NPCs die but bodies remain for looting)
-- NOTE: This function is kept for compatibility but the monitoring loop now handles this directly
function CleanupBlipsOnly()

end

-- ============================================
-- VALIDATION SYSTEM
-- ============================================

-- Track if we're waiting for ambush validation response
local validationPending = false
local validationTimeout = 0

-- Handle ambush validation response from server
RegisterNetEvent('ambush:client:ambushValidationResponse')
AddEventHandler('ambush:client:ambushValidationResponse', function(exists)
    validationPending = false
    validationTimeout = 0
    
    -- If ambush no longer exists on server, perform cleanup
    if not exists then
        if Config.Debug then
            print("[Cleanup] Server validation failed - ambush not tracked, performing cleanup")
        end
        PerformAmbushCleanup()
    end
end)

-- Validate ambush with server every second
local function ValidateAmbushWithServer()
    if not ActiveAmbush then
        return
    end
    
    -- If validation is already pending, check timeout
    if validationPending then
        validationTimeout = validationTimeout + 1
        -- If we've been waiting 5 seconds without response, cleanup
        if validationTimeout > 5 then
            if Config.Debug then
                print("[Cleanup] Server validation timeout - performing cleanup")
            end
            PerformAmbushCleanup()
        end
        return
    end
    
    -- Send validation request to server
    validationPending = true
    validationTimeout = 0
    TriggerServerEvent('ambush:server:validateAmbush', ActiveAmbush.hostPlayer.serverId, ActiveAmbush.id)
end

-- ============================================
-- MONITORING SYSTEM
-- ============================================

-- Check if all NPCs are dead
local function AreAllNPCsDead()
    if not ActiveAmbush or not ActiveAmbush.npcs then
        return false
    end
    
    for _, npc in ipairs(ActiveAmbush.npcs) do
        if DoesEntityExist(npc) and not IsEntityDead(npc) then
            return false
        end
    end
    
    return true
end

-- Check if all cached mission players are outside the mission despawn distance
local function AreAllPlayersOutsideMissionArea()
    if not ActiveAmbush or not ActiveAmbush.coords or not ActiveAmbush.nearbyPlayers then
        return false
    end
    
    -- Check each cached player from when the mission started
    for _, cachedPlayer in ipairs(ActiveAmbush.nearbyPlayers) do
        -- Get current player ped
        local currentPed = GetPlayerPed(cachedPlayer.id)
        if DoesEntityExist(currentPed) then
            local currentCoords = GetEntityCoords(currentPed)
            local distance = #(ActiveAmbush.coords - currentCoords)
            
            -- If any cached player is still within the mission despawn distance, return false
            if distance <= Config.MissionDespawnDistance then

                return false
            end
        end
    end
    

    
    return true
end

-- Check if any players are near NPCs
local function ArePlayersNearNPCs()
    if not ActiveAmbush or not ActiveAmbush.npcs then
        return false
    end
    
    -- Get all active players
    local players = GetActivePlayers()
    local debugPrinted = false
    
    -- Check each NPC for nearby players
    for _, npc in ipairs(ActiveAmbush.npcs) do
        if DoesEntityExist(npc) and not IsEntityDead(npc) then
            local npcCoords = GetEntityCoords(npc)
            
            -- Check if any player is near this NPC
            for _, playerId in ipairs(players) do
                local playerPed = GetPlayerPed(playerId)
                if DoesEntityExist(playerPed) and not IsEntityDead(playerPed) then
                    local playerCoords = GetEntityCoords(playerPed)
                    
                    -- If player is within detection radius of NPC, they're still in the mission area
                    if #(playerCoords - npcCoords) <= 100.0 then
                        -- Reduced debug output - only print once per check
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Main monitoring loop
local function MonitorAmbush()
    if not ActiveAmbush then
        return
    end
    
    -- Validate ambush with server every second while active
    ValidateAmbushWithServer()
    
    -- First check if players are near NPCs (new method)
    if ArePlayersNearNPCs() then
        -- Players are near NPCs, don't despawn
        -- Debug message is now handled in ArePlayersNearNPCs() to reduce spam
    -- Then check if all cached mission players are outside the mission area (original method)
    elseif AreAllPlayersOutsideMissionArea() then
        PerformAmbushCleanup()
        return
    -- New: End mission if all cached players are dead or outside area
    elseif (function()
        if not ActiveAmbush or not ActiveAmbush.coords or not ActiveAmbush.nearbyPlayers then
            return false
        end
        for _, cachedPlayer in ipairs(ActiveAmbush.nearbyPlayers) do
            local ped = GetPlayerPed(cachedPlayer.id)
            if DoesEntityExist(ped) then
                if not IsEntityDead(ped) then
                    local playerCoords = GetEntityCoords(ped)
                    local distance = #(ActiveAmbush.coords - playerCoords)
                    if distance <= Config.MissionDespawnDistance then
                        return false
                    end
                end
            end
        end
        return true
    end)() then
        PerformAmbushCleanup()
        return
    end
    
    -- Check if we're in the loot timer phase (NPCs dead, waiting for cleanup)
    if AmbushEndTime then
        -- Check if cleanup timer has expired
        if GetGameTimer() >= AmbushEndTime then

            PerformAmbushCleanup()
            return
        end
        
        -- Continue monitoring every 5 seconds during loot phase
        Citizen.SetTimeout(5000, MonitorAmbush)
        return
    end
    
    -- Update targeting for NPCs if they're still alive
    if not AreAllNPCsDead() then
        -- Call the improved AssignTargetsToNPCs function to update targeting
        AssignTargetsToNPCs()
        
        -- Debug message for targeting is now handled in AssignTargetsToNPCs() to reduce spam
    else
        -- All NPCs are dead, proceed with cleanup
        -- Remove area blip immediately when all NPCs die
        CleanupAreaBlip()
        
        -- Remove NPC blips
        CleanupNPCBlips()
        
        -- Notify server to start cleanup timer
        TriggerServerEvent('ambush:server:ambushEnded')
        
        -- Set local cleanup timer (5 minutes)
        AmbushEndTime = GetGameTimer() + (5 * 60 * 1000)
        
        if Config.Debug then
            print("[Cleanup] Area blip removed, 5-minute loot timer started")
        end
    end
    
    -- Continue monitoring every 5 seconds
    Citizen.SetTimeout(5000, MonitorAmbush)
end

-- Start monitoring an ambush
function StartAmbushMonitoring()
    if Config.Debug then
        print("[Cleanup] Starting ambush monitoring (checking every 5 seconds)")
    end
    
    Citizen.SetTimeout(5000, MonitorAmbush)
end

-- ============================================
-- CLIENT EVENTS
-- ============================================

-- Handle cleanup notification from server
RegisterNetEvent('ambush:client:performCleanup')
AddEventHandler('ambush:client:performCleanup', function()
    if Config.Debug then
        print("[Cleanup] Received cleanup notification from server")
    end
    
    PerformAmbushCleanup()
end)

-- ============================================
-- RESOURCE STOP CLEANUP
-- ============================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if Config.Debug then
            print("[Cleanup] Resource stopping, performing cleanup")
        end
        
        -- Force direct blip cleanup before general cleanup
        if AreaBlip and DoesBlipExist(AreaBlip) then
            RemoveBlip(AreaBlip)
            AreaBlip = nil
            if Config.Debug then
                print("[Cleanup] Resource stop: Directly removed area blip")
            end
        end
        
        if AreaRadiusBlip and DoesBlipExist(AreaRadiusBlip) then
            RemoveBlip(AreaRadiusBlip)
            AreaRadiusBlip = nil
            if Config.Debug then
                print("[Cleanup] Resource stop: Directly removed area radius blip")
            end
        end
        
        -- Perform general cleanup
        PerformAmbushCleanup()
    end
end)