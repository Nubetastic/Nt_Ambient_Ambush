-- ============================================
-- AMBIENT AMBUSH - MAIN CLIENT SCRIPT
-- ============================================

-- Note: ActiveAmbush and AmbushEndTime are now global variables defined in cleanup.lua
-- This allows the cleanup system to access them directly

-- State variables
cooldownEndTime = 0
ambushId = 0
missionCooldown = 0

-- Additional values from exports
AdditionalAmbushChance = 0
AdditionalPedCount = 0
PauseAmbush = false

-- Global group override for next ambush (string key into ConfigRegions.Groups)
groupOverwride = nil

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

local function GetRSGCore()
    if rawget(_G, 'RSGCore') then
        return RSGCore
    end

    if GetResourceState and GetResourceState('rsg-core') == 'started' then
        return exports['rsg-core']:GetCoreObject()
    end

    return nil
end

local function GetPlayerCash()
    local core = GetRSGCore()
    if not core or not core.Functions or not core.Functions.GetPlayerData then
        return 0
    end

    local playerData = core.Functions.GetPlayerData()
    local money = playerData and playerData.money
    if type(money) ~= "table" then
        return 0
    end

    return tonumber(money.cash) or 0
end

local function GetAmbushCashBonus()
    local moneyTick = tonumber(Config.AmbushChance.MoneyTick) or 0
    local moneyMax = tonumber(Config.AmbushChance.MoneyMax) or 0
    local currentCash = GetPlayerCash()

    if moneyTick <= 0 or currentCash <= 0 then
        return 0
    end

    return math.min(moneyMax, math.floor(currentCash / moneyTick))
end

local function GetAmbushWagonItemBonus()
    local itemTick = tonumber(Config.AmbushChance.ItemTick) or 0
    local itemMax = tonumber(Config.AmbushChance.ItemMax) or 0

    if itemTick <= 0 or itemMax <= 0 then
        return 0, 0
    end

    if not Config.OtherScripts or Config.OtherScripts.ntStables ~= true then
        return 0, 0
    end

    if not GetResourceState or GetResourceState('Nt_Stables') ~= 'started' then
        if Config.Debug then
            print("[Ambush] Nt_Stables is not started, skipping wagon item bonus")
        end
        return 0, 0
    end

    if not exports['Nt_Stables'] or not exports['Nt_Stables'].GetPlayerWagon then
        if Config.Debug then
            print("[Ambush] GetPlayerWagon export unavailable, skipping wagon item bonus")
        end
        return 0, 0
    end

    local okWagon, wagon = pcall(function()
        return exports['Nt_Stables']:GetPlayerWagon()
    end)

    if not okWagon then
        if Config.Debug then
            print("[Ambush] GetPlayerWagon export failed, skipping wagon item bonus")
        end
        return 0, 0
    end

    if not wagon or not DoesEntityExist(wagon) then
        if Config.Debug then
            print("[Ambush] Player has no wagon out, skipping wagon item bonus")
        end
        return 0, 0
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local wagonCoords = GetEntityCoords(wagon)
    local distance = #(playerCoords - wagonCoords)
    local maxDistance = tonumber(Config.AmbushChance.WagonCheckDist) or 25.0

    if Config.Debug then
        print(string.format("[Ambush] Wagon check: distance=%.2f maxDistance=%.2f", distance, maxDistance))
    end

    if distance > maxDistance then
        if Config.Debug then
            print("[Ambush] Wagon is too far away, skipping wagon item bonus")
        end
        return 0, 0
    end

    local ok, bonusItems = pcall(function()
        return lib.callback.await('Nt_Ambient_Ambush:server:GetWagonItemCount', false)
    end)

    if not ok then
        if Config.Debug then
            print("[Ambush] Wagon item count callback failed, skipping wagon item bonus")
        end
        return 0, 0
    end

    bonusItems = tonumber(bonusItems) or 0

    if bonusItems <= 0 then
        if Config.Debug then
            print("[Ambush] Wagon contains no configured items")
        end
        return 0, 0
    end

    local wagonBonus = math.min(itemMax, math.floor(bonusItems / itemTick))

    if Config.Debug then
        print(string.format("[Ambush] Wagon item count: %d, bonus: +%d%%", bonusItems, wagonBonus))
    end

    return wagonBonus, bonusItems
end

local function IsMissionLocationReserved(playerCoords)
    if not Config.OtherScripts or Config.OtherScripts.MissionsManager ~= true then
        return false
    end

    if not GetResourceState or GetResourceState('Nt_Missions_Manager') ~= 'started' then
        if Config.Debug then
            print("[Ambush] Missions Manager is not started, skipping reserved location check")
        end
        return false
    end

    local ok, isReserved = pcall(function()
        return exports['Nt_Missions_Manager']:CheckMissionLocation(playerCoords, 100)
    end)

    if not ok then
        if Config.Debug then
            print("[Ambush] Missions Manager location check failed, continuing ambush check")
        end
        return false
    end

    return isReserved == true
end

-- Get total ambush chance (base + regional + additional + night + money + wagon bonuses)
function GetTotalAmbushChance(region)
    local baseChance = Config.AmbushChance.Base
    local regionalBonus = tonumber(region.RegionalAmbushChance) or 0
    local nightBonus = 0
    local cashBonus = GetAmbushCashBonus()
    local wagonBonus = 0
    local wagonItemCount = 0
    
    -- Add night bonus if it's night time and the region has night bonus enabled
    if IsNightTime() and region and region.NightBonus then
        nightBonus = Config.AmbushChance.NightAddedChance

    end

    wagonBonus, wagonItemCount = GetAmbushWagonItemBonus()

    local totalChance = baseChance + regionalBonus + nightBonus + cashBonus + wagonBonus + (tonumber(AdditionalAmbushChance) or 0)
    return totalChance, {
        regionalBonus = regionalBonus,
        nightBonus = nightBonus,
        cashBonus = cashBonus,
        wagonBonus = wagonBonus,
        wagonItemCount = wagonItemCount,
    }
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

-- ============================================
-- SERVER EVENTS
-- ============================================

RegisterNetEvent('ambush:client:joinAmbush')
AddEventHandler('ambush:client:joinAmbush', function(hostServerId, ambushId)
    TriggerServerEvent('ambush:server:addPlayerToAmbush', hostServerId, ambushId)
end)

-- Event to handle cooldown notification from server
RegisterNetEvent('ambush:client:startCooldown')
AddEventHandler('ambush:client:startCooldown', function(minutes)
    if Config.Debug then
        print("[Ambush] Received cooldown notification from server")
    end
    
    missionCooldown = 0
    -- Start cooldown
    StartCooldown(minutes or Config.BaseCooldown)
end)

-- ============================================
-- CLEANUP
-- ============================================

-- Check if all NPCs in the ambush are dead
function AreAllNPCsDead()
    if not ActiveAmbush or not ActiveAmbush.npcs then return false end
    
    for _, npcNetId in ipairs(ActiveAmbush.npcs) do
        local npc = ResolveAmbushEntity(npcNetId)
        if npc == 0 or not DoesEntityExist(npc) then
            return false
        end
        if not IsEntityDead(npc) then
            return false
        end
    end
    
    return true
end

-- Despawn the current ambush (now uses centralized cleanup)
function DespawnAmbush()
    PerformAmbushCleanup()
end

-- ============================================
-- MAIN AMBUSH CHECK LOOP
-- ============================================

function CheckForAmbush()
    -- Train/tracks early-outs
    if IsPedInAnyTrain(PlayerPedId()) ~= false then
        return
    end
    
    local playerCoords = GetEntityCoords(PlayerPedId())

    -- Don't check if already in an active ambush or if ambushes are paused
    if ActiveAmbush or PauseAmbush or Citizen.InvokeNative(0x6F972C1AB75A1ED0, source) or Citizen.InvokeNative(0x857ACB0AB4BD0D55, source) then
        return
    end

    -- Don't check if in cooldown
    if GetGameTimer() < cooldownEndTime then
        if Config.Debug then
            local remainingTime = math.ceil((cooldownEndTime - GetGameTimer()) / 1000 / 60)
            print("[Ambush] In cooldown, " .. remainingTime .. " minutes remaining")
        end
        return
    end
    
    -- New minimal zone-checking pipeline per UpdateGuide.md
    local playerPed = PlayerPedId()

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

    -- Check if player is in reserved space.
    local isReserved = IsMissionLocationReserved(playerCoords)
    if isReserved then
        if Config.Debug then
            print("[Ambush] Player is in reserved space, skipping ambush check")
        end
        return
    end

    -- Calculate total chance including night, money, wagon, and external bonuses
    local totalChance, bonusBreakdown = GetTotalAmbushChance(region)
    
    -- Random roll for this check stored globally
    AmbushRoll = math.random(100)
    
    if Config.Debug then
        print("[Ambush] In region: " .. region.Name)
        print("[Ambush] Regional ambush chance: +" .. tostring(bonusBreakdown.regionalBonus) .. "%")
        if IsNightTime() and region.NightBonus then
            print("[Ambush] Night bonus active in this region")
        end
        print("[Ambush] Cash bonus: +" .. tostring(bonusBreakdown.cashBonus or 0) .. "%")
        print("[Ambush] Wagon item bonus: +" .. tostring(bonusBreakdown.wagonBonus or 0) .. "% (" .. tostring(bonusBreakdown.wagonItemCount or 0) .. " matching items)")
        if AdditionalAmbushChance > 0 then
            print("[Ambush] Additional ambush chance: +" .. AdditionalAmbushChance .. "%")
        end
        print("[Ambush] Roll: " .. AmbushRoll .. " / " .. totalChance)
    end
    
    -- If roll is successful, spawn ambush
    if AmbushRoll <= totalChance then
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        if Config.Debug then
            print("[Ambush] Ambush triggered!")
        end
        
        local ambushSpawned = SpawnAmbush(region, playerCoords)
        StartCooldown(ambushSpawned and Config.BaseCooldown or Config.FailCooldown)
        
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
        if missionCooldown ~= 0 then
            Wait(missionCooldown)
        else
            local timer = Config.CheckInterval
            while timer > 0 do
                timer = timer - 1 - missionCooldown
                Wait(1000)
            end
        end
        CheckForAmbush()
    end
end)



-- Cleanup on resource stop (now uses centralized cleanup)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if ActiveAmbush then
            PerformAmbushCleanup()
        end
    end
end)
