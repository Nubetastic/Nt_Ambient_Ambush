-- ============================================
-- AMBIENT AMBUSH - MAIN CLIENT SCRIPT
-- ============================================

-- Note: ActiveAmbush and AmbushEndTime are now global variables defined in cleanup.lua
-- This allows the cleanup system to access them directly

-- State variables
cooldownEndTime = 0
ambushId = 0

-- Additional values from exports
AdditionalAmbushChance = 0
AdditionalPedCount = 0
PauseAmbush = false

-- Global group override for next ambush (string key into ConfigRegions.Groups)
groupOverwride = nil

-- Blip override settings (nil = use config, true/false = override)
BlipOverrides = {
    PedBlip = nil,
    AreaBlip = nil
}

-- Global ambush roll value (set at start of each ambush check)
AmbushRoll = 0

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Check if it's night time in the game
function IsNightTime()
    local hour = GetClockHours()
    return hour >= 20 or hour < 6 -- Night time is between 8 PM and 6 AM
end

-- Get total ambush chance (base + additional + night bonus if applicable)
function GetTotalAmbushChance(region)
    local baseChance = Config.AmbushChance.Base
    local nightBonus = 0
    
    -- Add night bonus if it's night time and the region has night bonus enabled
    if IsNightTime() and region and region.NightBonus then
        nightBonus = Config.AmbushChance.NightAddedChance

    end
    
    return baseChance + nightBonus + AdditionalAmbushChance
end

-- Get cooldown duration
function GetTotalCooldown()
    return Config.BaseCooldown
end

-- Train/track detection helpers
function IsPlayerOnTrain()
    local ped = PlayerPedId()
    return Citizen.InvokeNative(0x6F972C1AB75A1ED0, ped) == true
end

function IsPlayerOnTracks()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local trackIndex = Citizen.InvokeNative(0x85D39F5E3B6D7EB0, coords.x, coords.y, coords.z)
    return trackIndex ~= nil and trackIndex ~= false
end

-- Check if player is in cooldown
function IsInCooldown()
    return GetGameTimer() < cooldownEndTime
end

-- Start cooldown timer
function StartCooldown(minutes)
    cooldownEndTime = GetGameTimer() + (minutes * 60 * 1000)
    
    if Config.Debug then
        print("[Ambush] Cooldown started for " .. minutes .. " minutes")
    end
end

-- Get player's current zone hash for a specific zone type
function GetPlayerZoneHash(zoneTypeId)
    local ped = PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(ped))
    local zoneHash = Citizen.InvokeNative(0x43AD8FC02B429D33, x, y, z, zoneTypeId)
    return zoneHash
end

-- Legacy zone-check helpers removed (superseded by minimal pipeline)

-- Minimal helpers based on UpdateGuide.md
-- Build a unique list of ZoneTypeIds used by towns and regions
function GetAllUniqueZoneTypeIds()
    local set = {}
    if ConfigRegions and ConfigRegions.Regions then
        for _, r in pairs(ConfigRegions.Regions) do
            if r.ZoneTypeId then set[r.ZoneTypeId] = true end
        end
    end
    if ConfigTowns and ConfigTowns.Towns then
        for _, t in pairs(ConfigTowns.Towns) do
            if t.ZoneTypeId then set[t.ZoneTypeId] = true end
        end
    end
    local list = {}
    for z, _ in pairs(set) do table.insert(list, z) end
    return list
end

-- Get player's zone hashes for a set of ZoneTypeIds
function GetPlayerZoneHashesForTypes(zoneTypeIds)
    local result = {}
    for _, z in ipairs(zoneTypeIds) do
        result[z] = GetPlayerZoneHash(z)
    end
    return result
end

-- Treat specific coordinate spheres as no-spawn (as if in town)
function IsInsideNoSpawnSphere(playerCoords)
    if not ConfigCoords or not ConfigCoords.Coords then return false end
    for center, radius in pairs(ConfigCoords.Coords) do
        if #(playerCoords - center) <= radius then
            if Config.Debug then
                print("[Ambush] Inside no-spawn sphere at " .. tostring(center) .. " (r=" .. tostring(radius) .. ")")
            end
            return true
        end
    end
    return false
end

-- Town match requires BOTH ZoneTypeId and zone hash (DistrictId) to match a config entry
function IsTownByConfig(playerZoneHashes)
    if not ConfigTowns or not ConfigTowns.Towns then return false end
    for _, town in pairs(ConfigTowns.Towns) do
        local playerHash = playerZoneHashes[town.ZoneTypeId]
        if type(playerHash) == "number" and playerHash ~= 0 and playerHash == town.DistrictId then
            if Config.Debug then
                print("[Ambush] Player is in town (config match): " .. tostring(town.Name))
            end
            return true
        end
    end
    return false
end

-- Match regions by BOTH ZoneTypeId and RegionHash, with Priority selection
function MatchRegions(playerZoneHashes)
    if not ConfigRegions or not ConfigRegions.Regions then return nil end
    local candidates = {}
    for _, region in pairs(ConfigRegions.Regions) do
        local playerHash = playerZoneHashes[region.ZoneTypeId]
        if type(playerHash) == "number" and playerHash ~= 0 and playerHash == region.RegionHash then
            table.insert(candidates, region)
        end
    end
    if #candidates == 0 then return nil end
    -- Keep only Priority=true if any exist
    local priority = {}
    for _, r in ipairs(candidates) do
        if r.Priority then table.insert(priority, r) end
    end
    if #priority > 0 then
        if Config.Debug then
            print("[Ambush] Region selected via Priority match: " .. tostring(priority[1].Name))
        end
        return priority[1]
    end
    if Config.Debug then
        print("[Ambush] Region selected (first match): " .. tostring(candidates[1].Name))
    end
    return candidates[1]
end

-- Get player's current state (New Hanover, Lemoyne, etc.)
function GetPlayerState()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Get current state ID
    -- Native: GET_MAP_ZONE_AT_COORDS (0x43AD8FC02B429D33)
    -- Parameter 4: 0 = State level (not 10, which is district level)
    -- Returns: Hash zoneHash
    local stateHash = Citizen.InvokeNative(0x43AD8FC02B429D33, playerCoords.x, playerCoords.y, playerCoords.z, 0)
    
    -- Check if we got a valid hash (should be a number)
    if type(stateHash) ~= "number" then
        if Config.Debug then
            print("[Ambush] Failed to get state hash (returned: " .. tostring(stateHash) .. ", type: " .. type(stateHash) .. ")")
        end
        return nil
    end
    
    if Config.Debug then
        print("[Ambush] Current state hash: " .. tostring(stateHash))
        print("[Ambush] Player coords: " .. tostring(playerCoords.x) .. ", " .. tostring(playerCoords.y) .. ", " .. tostring(playerCoords.z))
        
        -- Debug: print all configured state hashes for comparison
        print("[Ambush] Configured state hashes:")
        for stateKey, stateData in pairs(Config.States) do
            print("  - " .. stateData.Name .. ": " .. tostring(stateData.StateHash))
            if stateData.AlternateHashes then
                for _, altHash in ipairs(stateData.AlternateHashes) do
                    print("    (alt: " .. tostring(altHash) .. ")")
                end
            end
        end
    end
    
    -- Find matching state (check both main hash and alternate hashes)
    for stateKey, stateData in pairs(Config.States) do
        -- Check main state hash
        if stateHash == stateData.StateHash then
            if Config.Debug then
                print("[Ambush] Player is in state: " .. stateData.Name .. " (main hash)")
            end
            return stateData
        end
        
        -- Check alternate hashes if they exist
        if stateData.AlternateHashes then
            for _, altHash in ipairs(stateData.AlternateHashes) do
                if stateHash == altHash then
                    if Config.Debug then
                        print("[Ambush] Player is in state: " .. stateData.Name .. " (alternate hash: " .. tostring(altHash) .. ")")
                    end
                    return stateData
                end
            end
        end
    end
    
    -- Return nil if no state found
    if Config.Debug then
        print("[Ambush] Player is in unknown state (hash: " .. tostring(stateHash) .. ")")
    end
    return nil
end

-- Get player's current region (kept for reference/future use)
function GetPlayerRegion()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Get current region ID
    -- Native: GET_MAP_ZONE_AT_COORDS (0x43AD8FC02B429D33)
    -- Parameter 4: 0 = Region level
    -- Returns: Hash zoneHash
    local regionHash = Citizen.InvokeNative(0x43AD8FC02B429D33, playerCoords.x, playerCoords.y, playerCoords.z, 0)
    
    -- Check if we got a valid hash (should be a number)
    if type(regionHash) ~= "number" then
        if Config.Debug then
            print("[Ambush] Failed to get region hash (returned: " .. tostring(regionHash) .. ", type: " .. type(regionHash) .. ")")
        end
        return nil
    end
    
    if Config.Debug then
        print("[Ambush] Current region hash: " .. tostring(regionHash))
    end
    
    -- Find matching region
    for regionKey, regionData in pairs(Config.Regions) do
        if regionHash == regionData.RegionId then
            if Config.Debug then
                print("[Ambush] Player is in region: " .. regionKey)
            end
            return regionData
        end
    end
    
    -- Return nil if no region found
    if Config.Debug then
        print("[Ambush] Player is in unknown region (hash: " .. tostring(regionHash) .. ")")
    end
    return nil
end

-- Get random weapon from weighted table
function GetRandomWeapon(weaponTable)
    if #weaponTable == 0 then return nil end
    return weaponTable[math.random(1, #weaponTable)]
end

-- ============================================
-- MAIN AMBUSH LOOP
-- ============================================



-- ============================================
-- EXPORTS
-- ============================================

-- Export to allow other resources to add ambush chance
exports('AddAmbushChance', function(amount)
    if type(amount) == "number" then
        AdditionalAmbushChance = amount
        if Config.Debug then
            print("[Ambush] Additional ambush chance set to: " .. AdditionalAmbushChance)
        end
        return true
    end
    return false
end)

-- Export to allow other resources to add NPC count
exports('AddPedCount', function(amount)
    if type(amount) == "number" then
        AdditionalPedCount = amount
        if Config.Debug then
            print("[Ambush] Additional ped count set to: " .. AdditionalPedCount)
        end
        return true
    end
    return false
end)

-- Export to allow other resources to pause/unpause ambush checks
exports('PauseAmbushChecks', function(state)
    if type(state) == "boolean" then
        PauseAmbush = state
        if Config.Debug then
            print("[Ambush] Ambush checks " .. (PauseAmbush and "paused" or "resumed"))
        end
        return true
    end
    return false
end)

-- Export to allow other resources to override blip settings
exports('SetBlipOverrides', function(pedBlip, areaBlip)
    if type(pedBlip) == "boolean" then
        BlipOverrides.PedBlip = pedBlip
    end
    
    if type(areaBlip) == "boolean" then
        BlipOverrides.AreaBlip = areaBlip
    end
    
    if Config.Debug then
        print("[Ambush] Blip overrides set - PedBlip: " .. tostring(BlipOverrides.PedBlip) .. ", AreaBlip: " .. tostring(BlipOverrides.AreaBlip))
    end
    
    return true
end)

-- ============================================
-- SERVER EVENTS
-- ============================================

-- Event to handle area blip coordinates from server
RegisterNetEvent('ambush:client:setAreaBlipCoords')
AddEventHandler('ambush:client:setAreaBlipCoords', function(coords)
    if not Config.EnableBlips or not Config.AreaBlip.Enabled then
        return
    end
    
    -- Create area blip at the specified coordinates
    AreaBlip = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, coords.x, coords.y, coords.z, Config.AreaBlip.Radius)
    
    -- Set blip properties
    Citizen.InvokeNative(0x9CB1A1623062F402, AreaBlip, "Ambush") -- SetBlipName
    Citizen.InvokeNative(0x662D364ABF16DE2F, AreaBlip, GetHashKey(Config.AreaBlip.Color)) -- BlipAddModifier
    Citizen.InvokeNative(0x9B6A58FDB0024F12, AreaBlip, Config.AreaBlip.Scale) -- SetBlipScale
    Citizen.InvokeNative(0x45FF974EEE1C8734, AreaBlip, Config.AreaBlip.Alpha) -- SetBlipAlpha
    
    if Config.Debug then
        print("[Ambush] Created area blip from server coordinates")
    end
end)

-- Event to handle network IDs from server
RegisterNetEvent('ambush:client:addNetworkIds')
AddEventHandler('ambush:client:addNetworkIds', function(networkIds)
    if not Config.EnableBlips or not Config.PedBlip.Enabled then
        return
    end
    
    -- Create blips for each network ID
    for _, netId in ipairs(networkIds) do
        -- Get entity from network ID
        local entity = NetworkGetEntityFromNetworkId(netId)
        
        if DoesEntityExist(entity) then
            -- Create blip for entity
            local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, Config.PedBlip.Sprite, entity) -- BlipAddForEntity
            
            -- Set blip properties
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey(Config.PedBlip.Color)) -- BlipAddModifier
            Citizen.InvokeNative(0x9B6A58FDB0024F12, blip, Config.PedBlip.Scale) -- SetBlipScale
            
            -- Store blip in cache
            BlipCache[netId] = {
                blip = blip,
                entity = entity
            }
            
            if Config.Debug then
                print("[Ambush] Created blip for network ID: " .. netId)
            end
        else
            if Config.Debug then
                print("[Ambush] Entity does not exist for network ID: " .. netId)
            end
        end
    end
end)

-- Event to handle participant notification from server
RegisterNetEvent('ambush:client:notifyParticipant')
AddEventHandler('ambush:client:notifyParticipant', function(hostServerId)
    if Config.Debug then
        print("[Ambush] Received participant notification from host: " .. hostServerId)
    end
    
    -- Request network IDs from server
    TriggerServerEvent('ambush:server:requestNetworkIds', hostServerId)
end)

-- Event to handle cooldown notification from server
RegisterNetEvent('ambush:client:startCooldown')
AddEventHandler('ambush:client:startCooldown', function()
    if Config.Debug then
        print("[Ambush] Received cooldown notification from server")
    end
    
    -- Start cooldown
    StartCooldown(GetTotalCooldown())
end)

-- Event to handle ambush end notification from server
RegisterNetEvent('ambush:client:ambushEnded')
AddEventHandler('ambush:client:ambushEnded', function()
    if Config.Debug then
        print("[Ambush] Received ambush end notification from server")
    end
    
    -- Cleanup blips
    CleanupNPCBlips()
    CleanupAreaBlip()
end)

-- ============================================
-- CLEANUP
-- ============================================

-- Check if all NPCs in the ambush are dead
function AreAllNPCsDead()
    if not ActiveAmbush or not ActiveAmbush.npcs then return false end
    
    for _, npc in ipairs(ActiveAmbush.npcs) do
        if DoesEntityExist(npc) and not IsEntityDead(npc) then
            return false
        end
    end
    
    return true
end

-- Despawn the current ambush (now uses centralized cleanup)
function DespawnAmbush()
    PerformAmbushCleanup()
end

-- Notify server that ambush has ended (all NPCs dead) - now uses centralized cleanup
function NotifyAmbushEnded()
    CleanupBlipsOnly()
end

-- ============================================
-- MAIN AMBUSH CHECK LOOP
-- ============================================

function CheckForAmbush()
    -- Train/tracks early-outs
    if IsPlayerOnTrain() or IsPlayerOnTracks() then
        return
    end
    -- Don't check if already in an active ambush or if ambushes are paused
    if ActiveAmbush or PauseAmbush or Citizen.InvokeNative(0x6F972C1AB75A1ED0, source) then
        return
    end
    
    -- Don't check if in cooldown
    if IsInCooldown() then
        if Config.Debug then
            local remainingTime = math.ceil((cooldownEndTime - GetGameTimer()) / 1000 / 60)
            print("[Ambush] In cooldown, " .. remainingTime .. " minutes remaining")
        end
        return
    end
    
    -- New minimal zone-checking pipeline per UpdateGuide.md
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    -- Treat certain coordinate spheres as towns (no-spawn)
    if IsInsideNoSpawnSphere(playerCoords) then
        return
    end

    -- Build the set of relevant ZoneTypeIds and fetch the player's hashes once
    local zoneTypes = GetAllUniqueZoneTypeIds()
    local playerZoneHashes = GetPlayerZoneHashesForTypes(zoneTypes)

    -- Town gating: if any configured town matches BOTH ZoneTypeId and DistrictId, skip
    if IsTownByConfig(playerZoneHashes) then
        return
    end

    -- Region selection: require BOTH ZoneTypeId and RegionHash; apply Priority selection
    local region = MatchRegions(playerZoneHashes)
    if not region then
        return
    end

    -- Calculate total chance including night bonus if applicable
    local totalChance = GetTotalAmbushChance(region)
    
    -- Random roll for this check stored globally
    AmbushRoll = math.random(100)
    
    if Config.Debug then
        print("[Ambush] In region: " .. region.Name)
        if IsNightTime() and region.NightBonus then
            print("[Ambush] Night bonus active in this region")
        end
        print("[Ambush] Roll: " .. AmbushRoll .. " / " .. totalChance)
    end
    
    -- If roll is successful, spawn ambush
    if AmbushRoll <= totalChance then
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        if Config.Debug then
            print("[Ambush] Ambush triggered!")
        end
        
        -- Spawn the ambush
        SpawnAmbush(region, playerCoords)
        
        -- Start cooldown
        StartCooldown(GetTotalCooldown())
        
        -- Reset additional ambush chance after spawn
        -- This prevents external scripts from having to manage cleanup
        if AdditionalAmbushChance > 0 then
            if Config.Debug then
                print("[Ambush] Resetting additional ambush chance from " .. AdditionalAmbushChance .. "% to 0%")
            end
            AdditionalAmbushChance = 0
        end
    end
end

-- ============================================
-- INITIALIZATION
-- ============================================

Citizen.CreateThread(function()
    if Config.Debug then
        print("[Ambush] Ambient Ambush system initialized")
    end
    
    -- Main check loop
    while true do
        Wait(Config.CheckInterval * 1000)
        CheckForAmbush()
    end
end)

-- Event handler for starting cooldown when joining an ambush as a participant
RegisterNetEvent('ambush:client:startCooldown')
AddEventHandler('ambush:client:startCooldown', function()
    if Config.Debug then
        print("[Ambush] Starting cooldown as participant in another player's ambush")
    end
    
    -- Start cooldown
    StartCooldown(GetTotalCooldown())
end)

-- Cleanup on resource stop (now uses centralized cleanup)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if ActiveAmbush then
            PerformAmbushCleanup()
        end
    end
end)