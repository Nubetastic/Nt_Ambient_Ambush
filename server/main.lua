-- ============================================
-- AMBIENT AMBUSH - MAIN SERVER SCRIPT
-- ============================================

local function GetRSGCore()
    if rawget(_G, 'RSGCore') then
        return RSGCore
    end

    if GetResourceState and GetResourceState('rsg-core') == 'started' then
        return exports['rsg-core']:GetCoreObject()
    end

    return nil
end

local NpcPenaltyCache = {}
local NpcPenaltyGracePeriod = 10 * 60 * 1000

local function GetWagonInventoryItems(stashId)
    if not stashId then
        return nil, 'invalid-stash'
    end

    if GetResourceState and GetResourceState('rsg-inventory') == 'started' and exports['rsg-inventory'] and exports['rsg-inventory'].GetInventory then
        local ok, inventory = pcall(function()
            return exports['rsg-inventory']:GetInventory(stashId)
        end)

        if ok and inventory and inventory.items then
            return inventory.items, 'rsg-inventory-export'
        end
    end

    return nil, 'missing'
end

local function CountConfiguredWagonItems(stashItems)
    local configured = {}
    local matched = {}
    local total = 0

    for _, itemName in ipairs(ConfigItems and ConfigItems.Items or {}) do
        configured[tostring(itemName):lower()] = true
    end

    for _, itemData in pairs(stashItems or {}) do
        if itemData and itemData.name then
            local itemName = tostring(itemData.name):lower()
            local amount = tonumber(itemData.amount) or 0

            if amount > 0 and configured[itemName] then
                total = total + amount
                matched[#matched + 1] = string.format('%s x%d', itemName, amount)
            end
        end
    end

    return total, matched
end

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

local function IsPlayerInActiveAmbush(playerServerId)
    for _, ambushData in pairs(ActiveAmbushes) do
        for _, participantId in ipairs(ambushData.playersInAmbush or {}) do
            if participantId == playerServerId then
                return true
            end
        end
    end

    return false
end

lib.callback.register('Nt_Ambient_Ambush:server:GetWagonItemCount', function(source)
    local src = source

    if not Config.OtherScripts or Config.OtherScripts.ntStables ~= true then
        return 0
    end

    local core = GetRSGCore()

    if not core or not core.Functions or not core.Functions.GetPlayer then
        if Config.Debug then
            print(string.format("[Ambush Server] Wagon item count request from %d failed: RSGCore unavailable", src))
        end
        return 0
    end

    local Player = core.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData then
        if Config.Debug then
            print(string.format("[Ambush Server] Wagon item count request from %d failed: player not found", src))
        end
        return 0
    end

    if not GetResourceState or GetResourceState('Nt_Stables') ~= 'started' then
        if Config.Debug then
            print(string.format("[Ambush Server] Wagon item count request from %d failed: Nt_Stables is not started", src))
        end
        return 0
    end

    local activeWagonId = tonumber(Player.PlayerData.metadata and Player.PlayerData.metadata.stable_active_wagon)
    if not activeWagonId then
        local activeRide = Player.PlayerData.metadata and Player.PlayerData.metadata.stable_active_ride
        if type(activeRide) == 'table' and activeRide.type == 'wagon' then
            activeWagonId = tonumber(activeRide.wagonId)
        end
    end

    if Config.Debug then
        print(string.format(
            "[Ambush Server] Wagon item check from %d: activeWagonId=%s playerCitizenId=%s",
            src,
            tostring(activeWagonId),
            tostring(Player.PlayerData.citizenid)
        ))
    end

    if not activeWagonId then
        if Config.Debug then
            print(string.format("[Ambush Server] Wagon item count denied for %d: no active Nt_Stables wagon found", src))
        end
        return 0
    end

    local stashId = ('wagon_%s'):format(activeWagonId)
    local inventory, inventorySource = GetWagonInventoryItems(stashId)
    if not inventory then
        if Config.Debug then
            print(string.format("[Ambush Server] No inventory found for wagon stash %s (source: %s)", stashId, tostring(inventorySource)))
        end
        return 0
    end

    local itemCount, matchedItems = CountConfiguredWagonItems(inventory)

    if Config.Debug then
        print(string.format("[Ambush Server] Wagon stash %s loaded via %s", stashId, tostring(inventorySource)))
        print(string.format("[Ambush Server] Wagon stash %s matching item count: %d", stashId, itemCount))
        if #matchedItems > 0 then
            print("[Ambush Server] Wagon matching items: " .. table.concat(matchedItems, ", "))
        end
    end

    return itemCount
end)

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

-- Get all players in an ambush (for cleanup notification)
RegisterNetEvent('ambush:server:getAmbushPlayers')
AddEventHandler('ambush:server:getAmbushPlayers', function(ambushId)
    local hostServerId = source
    local key = hostServerId .. "_" .. ambushId
    
    if ActiveAmbushes[key] then
        local playersInAmbush = ActiveAmbushes[key].playersInAmbush
        if Config.Debug then
            print(string.format("[Ambush Server] Returning %d players for ambush %d from host %d", #playersInAmbush, ambushId, hostServerId))
        end
        TriggerClientEvent('ambush:client:ambushPlayersResponse', hostServerId, playersInAmbush)
    else
        if Config.Debug then
            print(string.format("[Ambush Server] Ambush %d from host %d not found for player list", ambushId, hostServerId))
        end
        TriggerClientEvent('ambush:client:ambushPlayersResponse', hostServerId, {})
    end
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

-- Remove a portion of cash when a player is killed by an ambush NPC
RegisterNetEvent('ambush:server:applyNpcKillPenalty')
AddEventHandler('ambush:server:applyNpcKillPenalty', function()
    local core = GetRSGCore()
    if not core or not core.Functions or not core.Functions.GetPlayer then
        return
    end

    local src = source
    if not IsPlayerInActiveAmbush(src) then
        return
    end

    local now = GetGameTimer()
    local cachedAt = NpcPenaltyCache[src]
    if cachedAt and (now - cachedAt) < NpcPenaltyGracePeriod then
        return
    end

    local Player = core.Functions.GetPlayer(src)
    if not Player or not Player.Functions or not Player.Functions.GetMoney or not Player.Functions.RemoveMoney then
        return
    end

    local cash = tonumber(Player.Functions.GetMoney('cash')) or 0
    if cash <= 0 then
        return
    end

    local removePercent = tonumber(Config.PlayerPenalties and Config.PlayerPenalties.RemoveCash) or 0
    if removePercent <= 0 then
        return
    end

    local amountToRemove = math.floor(cash * (removePercent / 100))
    if amountToRemove < 1 then
        amountToRemove = 1
    end

    amountToRemove = math.min(amountToRemove, cash)

    if amountToRemove > 0 then
        Player.Functions.RemoveMoney('cash', amountToRemove, 'ambush-npc-kill')
        NpcPenaltyCache[src] = now
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Money Stolen',
            description = "$ " .. amountToRemove .. " was stolen by ambush NPCs.",
            type = 'inform',
            duration = 10000
        })
        if Config.Debug then
            print(string.format("[Ambush Server] Removed $%d cash from player %d after ambush NPC kill", amountToRemove, src))
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Wait(60 * 1000)

        local now = GetGameTimer()
        for src, cachedAt in pairs(NpcPenaltyCache) do
            if (now - cachedAt) >= NpcPenaltyGracePeriod then
                NpcPenaltyCache[src] = nil
            end
        end
    end
end)

-- Notify a participant to join an ambush
-- This is triggered by the host when they detect a new player in range
RegisterNetEvent('ambush:server:notifyParticipant')
AddEventHandler('ambush:server:notifyParticipant', function(participantServerId, hostServerId, ambushId)
    if not participantServerId or not hostServerId or not ambushId then
        if Config.Debug then
            print("[Ambush Server] Invalid participant, host server ID, or ambush ID")
        end
        return
    end
    
    if Config.Debug then
        print(string.format("[Ambush Server] Notify participant %s to join host %s for ambush %d", participantServerId, hostServerId, ambushId))
    end
    
    -- Tell the participant to join the active ambush.
    TriggerClientEvent('ambush:client:joinAmbush', participantServerId, hostServerId, ambushId)
end)

-- Notify participants to start cooldown when ambush spawns
-- This is triggered by the host after scanning for players at spawn time
RegisterNetEvent('ambush:server:notifyParticipantsCooldown')
AddEventHandler('ambush:server:notifyParticipantsCooldown', function(participantServerIds, minutes)
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

    local cooldownMinutes = tonumber(minutes) == Config.FailCooldown and Config.FailCooldown or nil
    
    -- Notify each participant to start cooldown
    for _, participantId in ipairs(participantServerIds) do

        TriggerClientEvent('ambush:client:startCooldown', participantId, cooldownMinutes)
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

-- Get players in ambush for cleanup notification
RegisterNetEvent('ambush:server:getPlayersForCleanup')
AddEventHandler('ambush:server:getPlayersForCleanup', function(hostServerId, ambushId)
    local key = hostServerId .. "_" .. ambushId
    
    if ActiveAmbushes[key] then
        local playersInAmbush = ActiveAmbushes[key].playersInAmbush
        
        if Config.Debug then
            print(string.format("[Ambush Server] Notifying %d players of cleanup for ambush %d", #playersInAmbush, ambushId))
        end
        
        -- Notify only the players in this specific ambush
        for _, playerId in ipairs(playersInAmbush) do
            TriggerClientEvent('ambush:client:startCooldown', playerId)
        end
    else
        if Config.Debug then
            print(string.format("[Ambush Server] Ambush %d from host %d not found for cleanup notification", ambushId, hostServerId))
        end
    end
end)
