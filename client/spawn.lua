-- ============================================
-- AMBIENT AMBUSH - SPAWN SYSTEM
-- ============================================
-- This file contains all functions related to spawning NPCs for ambushes
-- Handles spawn position calculation, NPC creation, and ambush initialization

local enemyGroupHash = GetHashKey("Nt_Enemy")
local enemyNoBlipGroupHash = GetHashKey("Nt_Enemy_NoBlip")

CreateThread(function()
    AddRelationshipGroup("Nt_Enemy", enemyGroupHash)
    AddRelationshipGroup("Nt_Enemy_NoBlip", enemyNoBlipGroupHash)
end)

local function shouldAssignBlipGroup()
    if not Config.EnableBlips then
        return false
    end

    local override = BlipOverrides and BlipOverrides.PedBlip
    if override ~= nil then
        return override
    end

    return Config.PedBlip and Config.PedBlip.Enabled
end

-- ============================================
-- SPAWN POSITION FUNCTIONS
-- ============================================

-- Calculate spawn position based on player heading and angle
-- Uses native GetOffsetFromEntityInWorldCoords for accurate positioning
function GetSpawnPosition(playerCoords, playerHeading, angle, distance)
    local playerPed = PlayerPedId()
    
    -- Convert angle to radians
    local angleRad = math.rad(angle)
    
    -- Calculate X and Y offsets
    -- 0° = in front, 90° = right, 180° = behind, 270° = left
    local offsetX = math.sin(angleRad) * distance
    local offsetY = math.cos(angleRad) * distance
    
    -- Use native function for accurate world position
    local spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, offsetX, offsetY, 0.0)
    
    -- Sample ground Z at four nearby points, average, then spawn at +1
    local samples = {
        { x = spawnPos.x + 1.0, y = spawnPos.y + 1.0 },
        { x = spawnPos.x + 1.0, y = spawnPos.y - 1.0 },
        { x = spawnPos.x - 1.0, y = spawnPos.y + 1.0 },
        { x = spawnPos.x - 1.0, y = spawnPos.y - 1.0 },
    }
    local zSum, zCount = 0.0, 0
    for _, s in ipairs(samples) do
        local ok, z = GetGroundZFor_3dCoord(s.x, s.y, spawnPos.z + 100.0, false)
        if ok then
            zSum = zSum + z
            zCount = zCount + 1
        end
    end
    local groundZ
    if zCount > 0 then
        groundZ = zSum / zCount
    else
        groundZ = spawnPos.z
    end
    
    return vector3(spawnPos.x, spawnPos.y, groundZ + 1.0)
end



-- Calculate spawn position for the second group
function GetSecondGroupSpawnPosition(playerCoords, playerHeading, primaryGroupAngle)
    -- Keep the secondary group centered near the road spawn point; the fine spread is handled per-NPC.
    return playerCoords
end

-- ============================================
-- MOUNT FUNCTIONS
-- ============================================


-- Internal horse spawn (fast, no mounting)
function SpawnHorseForNPC_Internal(spawnCoords)
    local horseModels = {
        "A_C_Horse_AmericanPaint_Greyovero",
        "A_C_Horse_AmericanStandardbred_Black",
        "A_C_Horse_Morgan_Bay",
        "A_C_Horse_TennesseeWalker_BlackRabicano",
        "A_C_Horse_KentuckySaddle_Grey"
    }
    
    local horseModel = horseModels[math.random(1, #horseModels)]
    local modelHash = GetHashKey(horseModel)
    
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        return nil
    end
    
    local offsetX = math.random(-2, 2)
    local offsetY = math.random(-2, 2)
    local horse = CreatePed(modelHash, spawnCoords.x + offsetX, spawnCoords.y + offsetY, spawnCoords.z, 0.0, true, false, false, false)
    local netId = 0
    
    if not DoesEntityExist(horse) then
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end
    
    SetEntityAsMissionEntity(horse, true, true)
    NetworkRegisterEntityAsNetworked(horse)
    netId = NetworkGetNetworkIdFromEntity(horse)
    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
    end
    Citizen.InvokeNative(0x283978A15512B2FE, horse, true) -- _SET_RANDOM_OUTFIT_VARIATION
    Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, 0x20359E53, true, true, true) -- _APPLY_SHOP_ITEM_TO_PED (saddle)
    
    return horse, netId
end

-- Function to spawn a horse for an NPC and mount it
function SpawnHorseForNPC(npc, spawnCoords)
    local horse, horseNetId = SpawnHorseForNPC_Internal(spawnCoords)
    
    if not horse or not DoesEntityExist(horse) then
        if Config.Debug then
            print("[Ambush] Failed to spawn horse for NPC " .. npc)
        end
        return nil, nil
    end
    
    Citizen.InvokeNative(0x028F76B6E78246EB, npc, horse, -1, true) -- SET_PED_ON_MOUNT
    
    if Config.Debug then
        print("[Ambush] Spawned horse " .. horse .. " for NPC " .. npc)
    end
    
    return horse, horseNetId
end

-- ============================================
-- NPC SPAWNING FUNCTIONS
-- ============================================

-- Get a random weapon from a weapon list
function GetRandomWeapon(weaponList)
    if not weaponList or #weaponList == 0 then
        return nil
    end
    
    return weaponList[math.random(1, #weaponList)]
end

-- Spawn a single NPC
function SpawnNPC(spawnCoords, enemyModel, weaponConfig, shouldMount, isHuman, preMount)
    -- If preMount is enabled, spawn horse first and mount NPC to it during creation
    local horse = nil
    local horseNetId = nil
    local horseSpawnCoords = spawnCoords
    
    if preMount then
        horse, horseNetId = SpawnHorseForNPC_Internal(spawnCoords)
        if horse and DoesEntityExist(horse) then
            horseSpawnCoords = GetEntityCoords(horse)
        else
            preMount = false
        end
    end
    
    -- Load model
    local modelHash = GetHashKey(enemyModel)
    RequestModel(modelHash)
    
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        if Config.Debug then
            print("[Ambush] Failed to load model: " .. enemyModel)
        end
        if horse and DoesEntityExist(horse) then
            DeleteEntity(horse)
        end
        return nil, nil, nil, nil
    end
    
    -- Create networked ped (5th parameter MUST be true for multiplayer)
    -- Parameters: modelHash, x, y, z, heading, isNetwork, bScriptHostPed, p7, p8
    local heading = math.random(0, 360)
    
    -- Use CreatePed_2 for RedM which is more reliable for networked entities
    local npc = Citizen.InvokeNative(0xD49F9B0955C367DE, modelHash, horseSpawnCoords.x, horseSpawnCoords.y, horseSpawnCoords.z, heading, true, false, false, false) -- CreatePed_2
    
    if not DoesEntityExist(npc) then
        SetModelAsNoLongerNeeded(modelHash)
        if horse and DoesEntityExist(horse) then
            DeleteEntity(horse)
        end
        return nil, nil, nil, nil
    end

    -- Set as mission entity to prevent despawning
    SetEntityAsMissionEntity(npc, true, true)
    
    
    -- If horse exists and we're pre-mounting, mount immediately
    if preMount and horse and DoesEntityExist(horse) then
        Citizen.InvokeNative(0x028F76B6E78246EB, npc, horse, -1, true) -- SET_PED_ON_MOUNT
        Wait(100)
    end
    
    -- Wait for entity to fully initialize (reduced from 100ms to 50ms)
    Wait(50)
    
    -- Ensure entity is networked properly
    local networkTimeout = 0
    while not NetworkGetEntityIsNetworked(npc) and networkTimeout < 100 do
        NetworkRegisterEntityAsNetworked(npc)
        Wait(10)
        networkTimeout = networkTimeout + 1
    end

    if not NetworkGetEntityIsNetworked(npc) then
        DeleteEntity(npc)
        return nil, nil, nil, nil
    end

    -- Get network ID and validate
    local netId = NetworkGetNetworkIdFromEntity(npc)

    if not netId or netId == 0 then
        DeleteEntity(npc)
        return nil, nil, nil, nil
    end

    -- Set network ID properties for proper synchronization
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetEntityVisible(npc, true)
    
    -- Set ped properties
    Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityCanBeDamaged(npc, true)
    
    local groupHash = shouldAssignBlipGroup() and enemyGroupHash or enemyNoBlipGroupHash
    SetPedRelationshipGroupHash(npc, groupHash)

    -- default humans
    if isHuman == nil then isHuman = true end
    
    -- Set flag for mounted NPCs (used for chasers)
    if shouldMount then
        -- Set flag to allow NPC to use mounts
        Citizen.InvokeNative(0x1913FE4CBF41C463, npc, 24, true) -- _SET_PED_CONFIG_FLAG (24 = can mount)
        
        -- Enable horse flag for the NPC
        Citizen.InvokeNative(0x1913FE4CBF41C463, npc, 297, true) -- _SET_PED_CONFIG_FLAG (297 = can use horse)
        
        -- Set flag to allow NPC to flee on mount
        Citizen.InvokeNative(0x1913FE4CBF41C463, npc, 223, true) -- _SET_PED_CONFIG_FLAG (223 = can flee on mount)
        
        -- Set flag to allow NPC to use vehicles
        Citizen.InvokeNative(0x1913FE4CBF41C463, npc, 251, true) -- _SET_PED_CONFIG_FLAG (251 = can use vehicles)
        
        if Config.Debug then
            print("[Ambush] NPC " .. npc .. " configured for mounted chase")
        end
    end
    
    -- Give weapons to humans only
    if isHuman and weaponConfig then
        -- Give melee weapon (check chance)
        if weaponConfig.Melee and ConfigWeapons.Melee[weaponConfig.Melee] then
            local meleeChance = weaponConfig.MeleeChance -- Default to 100% if not specified
            if math.random(1, 100) <= meleeChance then
                local melee = GetRandomWeapon(ConfigWeapons.Melee[weaponConfig.Melee])
                if melee then
                    local weaponCondition = math.random(25,75)/100
                    GiveWeaponToPed_2(npc, GetHashKey(melee), 1, false, true, 2, false, 0.5, 1.0, 0, false, weaponCondition, false)
                end
            end
        end
        
        -- Give sidearm (check chance)
        if weaponConfig.Sidearms and ConfigWeapons.Sidearms[weaponConfig.Sidearms] then
            local sidearmsChance = weaponConfig.SidearmsChance -- Default to 100% if not specified
            if math.random(1, 100) <= sidearmsChance then
                local sidearm = GetRandomWeapon(ConfigWeapons.Sidearms[weaponConfig.Sidearms])
                if sidearm then
                    local weaponCondition = math.random(25,75)/100
                    GiveWeaponToPed_2(npc, GetHashKey(sidearm), 1, false, true, 0, false, 0.5, 1.0, 0, false, weaponCondition, false)
                end
            end
        end
        
        -- Give longarm (check chance)
        if weaponConfig.Longarms and ConfigWeapons.Longarms[weaponConfig.Longarms] then
            local longarmsChance = weaponConfig.LongarmsChance -- Default to 50% if not specified
            if math.random(1, 100) <= longarmsChance then
                local longarm = GetRandomWeapon(ConfigWeapons.Longarms[weaponConfig.Longarms])
                if longarm then
                    local weaponCondition = math.random(25,75)/100
                    GiveWeaponToPed_2(npc, GetHashKey(longarm), 1, false, true, 1, false, 0.5, 1.0, 0, false, weaponCondition, false)
                end
            end
        end
    end

    -- Set combat attributes for humans only
    if isHuman then
        --SetPedCombatAttributes(npc, 46, true) -- Always fight
        SetPedCombatAttributes(npc, 0, true) -- Can use cover
        SetPedCombatAttributes(npc, 1, true) -- Can use vehicles
        SetPedCombatAttributes(npc, 2, true) -- Can do drivebys
        SetPedCombatAttributes(npc, 3, true) -- Can leave vehicle
        --SetPedCombatAttributes(npc, 5, true) -- Always fight
        SetPedCombatAttributes(npc, 16, true) -- bullet strafe
        SetPedCombatAttributes(npc, 12, true) -- cover blind fire
        SetPedCombatAttributes(npc, 58, true) -- disable flee from combat
        SetPedCombatAttributes(npc, 24, true) -- proximity fire rate
        SetPedCombatAttributes(npc, 42, true) -- can flank
        SetPedCombatAttributes(npc, 50, true) -- can charge
        SetPedCombatAttributes(npc, 91, true) -- Use range based weapon selection
        SetPedCombatAttributes(npc, 114, true) -- can execute target

        SetPedCombatRange(npc, 2) -- Attack Range
        --Citizen.InvokeNative(0x05CE6AF4DF071D23, npc, 2) -- ladder speed modifier, seems to fix melee speed issue.
        Citizen.InvokeNative(0xD77AE48611B7B10A, npc, Config.DamageModifier) -- SetPedDamageModifier
    end

    -- Return the NPC entity, network ID, and horse (if pre-mounted)
    return npc, netId, horse, horseNetId
end

-- ============================================
-- GROUP SPAWNING FUNCTIONS
-- ============================================

-- Spawn a group of NPCs at a specific position
function SpawnNPCGroup(spawnPosition, count, region, shouldMount)
    local npcs = {}
    local netIds = {}
    
    for i = 1, count do
        -- Add some randomness to the spawn position within the group
        local offsetX = math.random(-10, 10)
        local offsetY = math.random(-10, 10)
        local groupSpawnPos = vector3(
            spawnPosition.x + offsetX,
            spawnPosition.y + offsetY,
            spawnPosition.z
        )
        
        -- Select a random enemy model from the region
        local enemyModel = region.EnemyTypes[math.random(1, #region.EnemyTypes)]
        
        -- Spawn the NPC
        local npc, netId, horse, horseNetId = SpawnNPC(groupSpawnPos, enemyModel, region.Weapons, shouldMount)
        
        if npc and netId then
            table.insert(npcs, netId)
            table.insert(netIds, netId)
            
            -- If this NPC should be mounted, spawn a horse for it
            if shouldMount and not horse then
                local spawnedHorse = SpawnHorseForNPC(npc, groupSpawnPos)
                
                -- If horse spawned successfully, store it
                if spawnedHorse and DoesEntityExist(spawnedHorse) then
                    -- Initialize horses table if needed
                    if not ActiveAmbush.horses then
                        ActiveAmbush.horses = {}
                    end
                    
                    -- Store the horse
                    local spawnedHorseNetId = NetworkGetNetworkIdFromEntity(spawnedHorse)
                    if spawnedHorseNetId and spawnedHorseNetId ~= 0 then
                        table.insert(ActiveAmbush.horses, spawnedHorseNetId)
                    end
                    
                    -- Set the horse as mission entity
                    SetEntityAsMissionEntity(spawnedHorse, true, true)
                end
            elseif horse and DoesEntityExist(horse) then
                -- Horse already spawned (pre-mounted), store it
                if not ActiveAmbush.horses then
                    ActiveAmbush.horses = {}
                end
                table.insert(ActiveAmbush.horses, horseNetId or NetworkGetNetworkIdFromEntity(horse))
                SetEntityAsMissionEntity(horse, true, true)
            end
        end
    end
    
    return npcs, netIds
end

-- ============================================
-- MAIN AMBUSH SPAWNING FUNCTION
-- ============================================

-- Main function to spawn an ambush
function SpawnAmbush(region, playerCoords)
    -- New group-based spawn pipeline per update plan
    if not region then return end

    local hour = GetClockHours()

    -- Select group by time-of-day (new config uses Settings.Timofday)
    local function isTimeOfDayValid(settings, h)
        local tod = settings and settings.Timofday
        if not tod or tod == "Anytime" then return true end
        if tod == "Day" then return h >= 6 and h <= 19 end
        if tod == "Night" then return h >= 20 or h <= 5 end
        return true
    end

    local enemyGroups = region.EnemyGroups or {}

    -- If a global group override is set, map it into a temporary EnemyGroup using ConfigRegions.Groups
    if groupOverwride and ConfigRegions and ConfigRegions.Groups and ConfigRegions.Groups[groupOverwride] then
        local g = ConfigRegions.Groups[groupOverwride]
        -- Build a synthetic group that matches expected structure
        local temp = {
            Peds = g.Peds or g.Enemies or g.PedModels or g.PedList or g.Models or nil,
            Animals = g.Animals,
            Settings = g.Settings or {}
        }
        -- If Peds is still nil and the group is an animal-only group, keep as-is
        -- Insert at high priority by replacing enemyGroups with single entry table
        enemyGroups = { temp }
        if Config.Debug then
            print("[Ambush] Using override group '" .. tostring(groupOverwride) .. "' for next ambush")
        end
    end

    local valid = {}
    for name, group in pairs(enemyGroups) do
        if isTimeOfDayValid(group.Settings or {}, hour) then
            table.insert(valid, group)
        end
    end
    if #valid == 0 then
        if Config.Debug then print("[Ambush] No valid EnemyGroups for time-of-day") end
        return
    end
    local selected = valid[ math.random(1, #valid) ]

    -- Build spawn counts from Config.SpawnNum and nearby players
    local nearbyPlayers = GetPlayersInAmbushZone(playerCoords, Config.AttackDistance)
    local playerCount = #nearbyPlayers
    local base = math.random(Config.SpawnNum.BaseMin + (AdditionalPedCount or 0), Config.SpawnNum.BaseMax + (AdditionalPedCount or 0))
    if playerCount > 1 then
        for i = 1, playerCount - 1 do
            base = base + math.random(Config.SpawnNum.PerPlayerMin, Config.SpawnNum.PerPlayerMax)
        end
    end

    -- Composition and settings from new config (Timofday, Horse, flat weapon keys)
    local settings = selected.Settings or {}
    -- Apply group-level SpawnCountPer scaling (clamped to minimum 1)
    do
        local scp = tonumber(settings.SpawnCountPer)
        if scp and scp > 1 then
            base = math.max(1, math.floor(base / scp))
        end
    end
    local weaponConfig = {
        Melee = settings.Melee,
        MeleeChance = settings.MeleeChance or 100,
        Sidearms = settings.Sidearms,
        SidearmsChance = settings.SidearmsChance or 100,
        Longarms = settings.Longarms,
        LongarmsChance = settings.LongarmsChance or 50,
    }
    local horseEnabled = settings.Horse ~= false
    local plan = { peds = 0, animalsAlongside = 0, animalsStandalone = 0, horse = horseEnabled, weapons = weaponConfig }
    local ds = settings.DogSpawnChance

    local hasPeds = selected.Peds and #selected.Peds > 0
    local hasAnimals = selected.Animals and #selected.Animals > 0

    -- Determine group composition and total count
    local mixedNoDogs = false
    local totalCount = base

    if type(ds) == "number" then
        -- DogSpawnChance: spawn peds and roll animals alongside per ped during loops
        plan.peds = base
        plan.animalsAlongside = 0
    else
        if hasPeds and not hasAnimals then
            plan.peds = base
        elseif hasAnimals and not hasPeds then
            plan.animalsStandalone = base
        elseif hasPeds and hasAnimals then
            mixedNoDogs = true
        else
            plan.peds = base
        end
    end

    -- Begin execution
    local playerPed = PlayerPedId()
    local playerHeading = GetEntityHeading(playerPed)

    ambushId = ambushId + 1
    ActiveAmbush = {
        id = ambushId,
        coords = playerCoords,
        npcs = {},
        horses = {},
        npcTargets = {},
        hostPlayer = {
            id = PlayerId(),
            serverId = GetPlayerServerId(PlayerId()),
            ped = playerPed,
            coords = playerCoords
        },
        nearbyPlayers = nearbyPlayers,
        despawnTimer = nil
    }

    AmbushActors = {} -- unified cache per npcAI plan

    -- Spawn locations
    local roadConfig = Config and Config.RoadSpawn or {}
    local mountedMapDistance = tonumber(roadConfig.MountedMapDistance) or 300
    local minimumSpawnDistance = mountedMapDistance * 0.5
    local roadSpawnPoint = GetRoadAmbushSpawnPoint(playerCoords, playerHeading, plan.horse)
    local spawnCenterCoords = nil
    local spawnCenterHeading = playerHeading

    local function distanceFromPlayer(coords)
        local dx = coords.x - playerCoords.x
        local dy = coords.y - playerCoords.y
        return math.sqrt((dx * dx) + (dy * dy))
    end

    if roadSpawnPoint and roadSpawnPoint.coords then
        local spawnDistance = distanceFromPlayer(roadSpawnPoint.coords)

        if spawnDistance >= minimumSpawnDistance then
            spawnCenterCoords = roadSpawnPoint.coords
            spawnCenterHeading = roadSpawnPoint.heading or playerHeading
        else
            print(("[Ambush] Road spawn safety check failed: %.1fm is below the %.1fm minimum."):format(
                spawnDistance,
                minimumSpawnDistance
            ))
        end
    else
        print("[Ambush] Road spawn safety check failed: no road spawn point was generated.")
    end

    if not spawnCenterCoords then
        local failSpawnPoint = GetRoadFailSpawnPoint(playerCoords, playerHeading)
        if not failSpawnPoint or not failSpawnPoint.coords then
            print("[Ambush] Road-fail grid could not produce a spawn point; ambush spawn cancelled.")
            ActiveAmbush = nil
            AmbushActors = {}
            return
        end

        spawnCenterCoords = failSpawnPoint.coords
        spawnCenterHeading = failSpawnPoint.heading or playerHeading
    end

    local primaryGroupAngle = 90.0 + math.random(-15, 15)
    local primaryGroupPos = spawnCenterCoords
    local secondaryGroupPos = GetSecondGroupSpawnPosition(spawnCenterCoords, spawnCenterHeading, primaryGroupAngle)


    -- Helper to apply weapons to a ped using plan.weapons or region weapons
    local function applyWeapons(npc)
        local w = plan.weapons or region.Weapons
        if not w then return end
        -- Reuse SpawnNPC logic already applies weapons when weaponConfig passed
    end

    local function spawnOnePedAt(pos, mountFlag, preMount)
        local list = (selected.Peds and #selected.Peds > 0) and selected.Peds or {}
        if #list == 0 then return nil end
        local enemyModel = list[ math.random(1, #list) ]
        local npc, netId, horse, horseNetId = SpawnNPC(pos, enemyModel, plan.weapons, mountFlag == true, true, preMount == true)
        if npc and netId then
            table.insert(ActiveAmbush.npcs, netId)
            local mounted = mountFlag == true or preMount == true
            local actor = { netId = netId, type = "human", mounted = mounted, mountNetId = nil }
            table.insert(AmbushActors, actor)
            
            -- If mounted but not pre-mounted, spawn and mount horse now
            if mountFlag and not preMount then
                local spawnedHorse = SpawnHorseForNPC(npc, pos)
                if spawnedHorse and DoesEntityExist(spawnedHorse) then
                    local spawnedHorseNetId = NetworkGetNetworkIdFromEntity(spawnedHorse)
                    actor.mountNetId = spawnedHorseNetId
                    ActiveAmbush.horses = ActiveAmbush.horses or {}
                    if spawnedHorseNetId and spawnedHorseNetId ~= 0 then
                        table.insert(ActiveAmbush.horses, spawnedHorseNetId)
                    end
                    SetEntityAsMissionEntity(spawnedHorse, true, true)
                end
            -- If pre-mounted, the horse was already created in SpawnNPC
            elseif preMount and horse and DoesEntityExist(horse) then
                -- Horse already spawned and mounted in SpawnNPC, store it
                actor.mountNetId = horseNetId or NetworkGetNetworkIdFromEntity(horse)
                ActiveAmbush.horses = ActiveAmbush.horses or {}
                table.insert(ActiveAmbush.horses, actor.mountNetId)
                SetEntityAsMissionEntity(horse, true, true)
            end
        end
        return npc
    end

    local function spawnOneAnimalAt(pos)
        if not (selected.Animals and #selected.Animals > 0) then return nil end
        local model = selected.Animals[ math.random(1, #selected.Animals) ]
        local npc, netId, horse = SpawnNPC(pos, model, nil, false, false)
        if npc and netId then
            table.insert(ActiveAmbush.npcs, netId)
            table.insert(AmbushActors, { netId = netId, type = "animal", mounted = false, mountNetId = nil })
        end
        return npc
    end

    -- Prepare mixed list if needed (no DogSpawnChance and both Peds/Animals present)
    local combinedList = nil
    if mixedNoDogs then
        combinedList = {}
        if hasPeds then
            for _, m in ipairs(selected.Peds) do table.insert(combinedList, { kind = "ped", model = m }) end
        end
        if hasAnimals then
            for _, m in ipairs(selected.Animals) do table.insert(combinedList, { kind = "animal", model = m }) end
        end
    end

    -- Helper to spawn one from mixed list
    local function spawnOneMixedAt(pos, mountFlag, preMount)
        if not combinedList or #combinedList == 0 then return end
        local pick = combinedList[ math.random(1, #combinedList) ]
        if pick.kind == "ped" then
            return spawnOnePedAt(pos, mountFlag, preMount)
        else
            return spawnOneAnimalAt(pos)
        end
    end

    -- Distribute base count across two formations
    local primaryCount, secondaryCount
    if mixedNoDogs then
        primaryCount = math.ceil(totalCount * 0.6)
        secondaryCount = totalCount - primaryCount
    else
        local totalForSplit = (plan.peds > 0 and plan.peds or plan.animalsStandalone)
        primaryCount = math.ceil(totalForSplit * 0.6)
        secondaryCount = totalForSplit - primaryCount
    end

    local function buildSpawnPositions(groupPosition, count)
        local positions = {}

        for i = 1, count do
            local offset = vector3(math.random(-10, 10), math.random(-10, 10), 0)
            positions[i] = vector3(
                groupPosition.x + offset.x,
                groupPosition.y + offset.y,
                groupPosition.z
            )
        end

        return positions
    end

    local function findUnsafeSpawnPosition(primaryPositions, secondaryPositions)
        for _, positions in ipairs({ primaryPositions, secondaryPositions }) do
            for _, position in ipairs(positions) do
                local distance = distanceFromPlayer(position)
                if distance < minimumSpawnDistance then
                    return position, distance
                end
            end
        end

        return nil, nil
    end

    local primaryPositions = buildSpawnPositions(primaryGroupPos, primaryCount)
    local secondaryPositions = buildSpawnPositions(secondaryGroupPos, secondaryCount)
    local unsafePosition, unsafeDistance = findUnsafeSpawnPosition(primaryPositions, secondaryPositions)

    if unsafePosition then
        print(("[Ambush] Enemy spawn safety check failed: %.1fm is below the %.1fm minimum; remapping formation."):format(
            unsafeDistance,
            minimumSpawnDistance
        ))

        local failSpawnPoint = GetRoadFailSpawnPoint(playerCoords, playerHeading)
        if not failSpawnPoint or not failSpawnPoint.coords then
            print("[Ambush] Road-fail grid could not remap the unsafe formation; ambush spawn cancelled.")
            ActiveAmbush = nil
            AmbushActors = {}
            return
        end

        spawnCenterCoords = failSpawnPoint.coords
        spawnCenterHeading = failSpawnPoint.heading or playerHeading
        primaryGroupPos = spawnCenterCoords
        secondaryGroupPos = GetSecondGroupSpawnPosition(spawnCenterCoords, spawnCenterHeading, primaryGroupAngle)
        primaryPositions = buildSpawnPositions(primaryGroupPos, primaryCount)
        secondaryPositions = buildSpawnPositions(secondaryGroupPos, secondaryCount)

        unsafePosition, unsafeDistance = findUnsafeSpawnPosition(primaryPositions, secondaryPositions)
        if unsafePosition then
            print(("[Ambush] Remapped enemy coordinate is still unsafe at %.1fm; ambush spawn cancelled."):format(
                unsafeDistance
            ))
            ActiveAmbush = nil
            AmbushActors = {}
            return
        end
    end

    for i = 1, primaryCount do
        local pos = primaryPositions[i]
        local preMount = math.random(1, 100) <= Config.PreMountedPercentage
        
        if mixedNoDogs then
            spawnOneMixedAt(pos, plan.horse, plan.horse and preMount)
        elseif plan.peds > 0 then
            local ped = spawnOnePedAt(pos, plan.horse, plan.horse and preMount)
            if ped and type(ds) == "number" and hasAnimals then
                if math.random(1,100) <= ds then
                    spawnOneAnimalAt(pos)
                end
            end
        else
            spawnOneAnimalAt(pos)
        end
    end

    for i = 1, secondaryCount do
        local pos = secondaryPositions[i]
        local preMount = math.random(1, 100) <= Config.PreMountedPercentage
        
        if mixedNoDogs then
            spawnOneMixedAt(pos, plan.horse, plan.horse and preMount)
        elseif plan.peds > 0 then
            local ped = spawnOnePedAt(pos, plan.horse, plan.horse and preMount)
            if ped and type(ds) == "number" and hasAnimals then
                if math.random(1,100) <= ds then
                    spawnOneAnimalAt(pos)
                end
            end
        else
            spawnOneAnimalAt(pos)
        end
    end

    -- Blips and finalize
    if Config.Debug then
        print(string.format("[Ambush] Spawned %d entities (%d peds baseline)", #ActiveAmbush.npcs, plan.peds))
    end

    -- Register ambush with server for tracking
    TriggerServerEvent('ambush:server:registerAmbush', ambushId)

    -- Host notifies nearby participants to join this ambush.
    do
        local hostServerId = GetPlayerServerId(PlayerId())
        local participantServerIds = {}
        for _, p in ipairs(nearbyPlayers or {}) do
            local pid = p
            local sid = nil
            if type(p) == "table" then
                pid = p.id or p.playerId or p[1]
                sid = p.serverId
            end
            if not sid and pid ~= nil then
                sid = GetPlayerServerId(pid)
            end
            if sid and sid ~= hostServerId then
                TriggerServerEvent('ambush:server:notifyParticipant', sid, hostServerId, ambushId)
                table.insert(participantServerIds, sid)
            end
        end
        if #participantServerIds > 0 then
            TriggerServerEvent('ambush:server:notifyParticipantsCooldown', participantServerIds)
        end
    end

    StartAmbushMonitoring()
    StartCooldown(Config.BaseCooldown)

end
