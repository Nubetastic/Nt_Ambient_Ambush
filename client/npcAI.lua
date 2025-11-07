-- ============================================
-- AMBIENT AMBUSH - NPC AI SYSTEM
-- ============================================
-- This file contains all functions related to NPC AI behavior and combat
-- Handles targeting, combat behavior, and stuck NPC detection

-- ============================================
-- VOICE / BARK SYSTEM
-- ============================================

-- List of combat-appropriate bark lines for enemy NPCs
local CombatVoiceLines = {
    "GENERIC_INSULT_MED",
    "GENERIC_INSULT_HIGH",
    "GENERIC_SHOUT",
    "GENERIC_CURSE_LOW",
    "GENERIC_CURSE_MED",
    "GENERIC_THREAT",
}

-- Plays a random combat bark for an NPC (protected by caller via pcall)
function NPCCombatVoice(ped)
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end
    if not CombatVoiceLines or #CombatVoiceLines == 0 then return end
    local line = CombatVoiceLines[math.random(1, #CombatVoiceLines)]
    -- Prefer PlayAmbientSpeech1 if available; otherwise call native directly
    if PlayAmbientSpeech1 then
        PlayAmbientSpeech1(ped, line, "SPEECH_PARAMS_FORCE_SHOUTED")
    else
        -- Native: PlayAmbientSpeech1 (RDR2)
        Citizen.InvokeNative(0x8E04FEDD28D42462, ped, line, "SPEECH_PARAMS_FORCE_SHOUTED", 0)
    end
end

-- ============================================
-- PLAYER DETECTION FUNCTIONS
-- ============================================

-- Get all players within the ambush zone
function GetPlayersInAmbushZone(centerCoords, radius)
    local players = GetActivePlayers()
    local result = {}
    
    for _, playerId in ipairs(players) do
        local playerPed = GetPlayerPed(playerId)
        local playerCoords = GetEntityCoords(playerPed)
        
        if #(playerCoords - centerCoords) <= radius then
            table.insert(result, {
                id = playerId,
                serverId = GetPlayerServerId(playerId),
                ped = playerPed,
                coords = playerCoords,
                distance = #(playerCoords - centerCoords)
            })
        end
    end
    
    return result
end

-- Get all players within range of each NPC in the ambush
function GetPlayersAroundNPCs()
    if not ActiveAmbush or not ActiveAmbush.npcs then return {} end
    
    local players = GetActivePlayers()
    local result = {}
    local detectionRadius = 100.0 -- Detection radius around each NPC
    
    -- Initialize scanned status for each NPC
    local npcScanned = {}
    for _, npc in ipairs(ActiveAmbush.npcs) do
        npcScanned[npc] = false
    end
    
    -- Scan for players around each NPC
    for _, npc in ipairs(ActiveAmbush.npcs) do
        if DoesEntityExist(npc) and not IsEntityDead(npc) and not npcScanned[npc] then
            local npcCoords = GetEntityCoords(npc)
            npcScanned[npc] = true
            
            -- Find nearby NPCs to avoid redundant scans
            local nearbyNPCs = {}
            for _, otherNPC in ipairs(ActiveAmbush.npcs) do
                if DoesEntityExist(otherNPC) and not IsEntityDead(otherNPC) and not npcScanned[otherNPC] and otherNPC ~= npc then
                    local otherCoords = GetEntityCoords(otherNPC)
                    if #(npcCoords - otherCoords) <= detectionRadius / 2 then
                        table.insert(nearbyNPCs, otherNPC)
                        npcScanned[otherNPC] = true
                    end
                end
            end
            
            -- Scan for players around this NPC
            for _, playerId in ipairs(players) do
                local playerPed = GetPlayerPed(playerId)
                local playerCoords = GetEntityCoords(playerPed)
                
                if #(playerCoords - npcCoords) <= detectionRadius then
                    -- Check if player is already in result
                    local playerExists = false
                    for _, p in ipairs(result) do
                        if p.id == playerId then
                            playerExists = true
                            break
                        end
                    end
                    
                    -- Add player if not already in result
                    if not playerExists then
                        table.insert(result, {
                            id = playerId,
                            serverId = GetPlayerServerId(playerId),
                            ped = playerPed,
                            coords = playerCoords,
                            distance = #(playerCoords - npcCoords),
                            nearestNPC = npc
                        })
                    end
                end
            end
        end
    end
    
    return result
end

-- ============================================
-- NPC COMBAT MANAGEMENT
-- ============================================

-- Initialize NPC target cache when ambush is created
function InitializeNPCTargetCache()
    if not ActiveAmbush then return end
    
    -- Create target cache if it doesn't exist
    if not ActiveAmbush.npcTargets then
        ActiveAmbush.npcTargets = {}
    end
end

-- Assign a target to an NPC and engage in combat (throttled to prevent stutter)
function AssignTargetToNPC(npc, targetPed)
    if not DoesEntityExist(npc) or not DoesEntityExist(targetPed) then
        return false
    end

    if not ActiveAmbush then return false end

    -- Ensure caches exist
    ActiveAmbush.npcTargets = ActiveAmbush.npcTargets or {}
    ActiveAmbush.npcCommandState = ActiveAmbush.npcCommandState or {}

    local cooldown = (Config and Config.NPCTaskCooldown) -- ms
    local now = GetGameTimer()

    -- Avoid reissuing the same combat command to the same target too frequently
    local last = ActiveAmbush.npcCommandState[npc]
    if last and last.task == "combat" and last.target == targetPed and (now - last.time) < cooldown then
        return false
    end

    -- If already targeting this ped and in combat, skip reassignment
    local currentTargetPed = ActiveAmbush.npcTargets[npc]
    if currentTargetPed and currentTargetPed == targetPed and IsPedInCombat(npc) then
        return false
    end

    -- Only clear tasks if we need to switch targets or NPC isn't in combat
    if (not IsPedInCombat(npc)) or (currentTargetPed ~= targetPed) then
        ClearPedTasks(npc)
    end

    TaskCombatPed(npc, targetPed, 0, 16)

    -- Update caches
    ActiveAmbush.npcTargets[npc] = targetPed
    ActiveAmbush.npcCommandState[npc] = { task = "combat", target = targetPed, time = now }

    return true
end

-- Update targeting for all NPCs in the ambush
function UpdateTargeting()
    if not ActiveAmbush or not ActiveAmbush.npcs then
        return
    end
    
    -- Get players in the ambush zone (original method)
    local playersInZone = GetPlayersInAmbushZone(ActiveAmbush.coords, Config.AttackDistance)
    
    -- Get players around NPCs (new method)
    local playersAroundNPCs = GetPlayersAroundNPCs()
    
    -- Merge the two lists (avoiding duplicates)
    local allPlayers = {}
    
    -- Add players from zone first
    for _, player in ipairs(playersInZone) do
        allPlayers[player.id] = player
    end
    
    -- Add players from around NPCs (if not already added)
    for _, player in ipairs(playersAroundNPCs) do
        if not allPlayers[player.id] then
            allPlayers[player.id] = player
        end
    end
    
    -- Convert back to array
    local targetPlayers = {}
    for _, player in pairs(allPlayers) do
        table.insert(targetPlayers, player)
    end
    
    -- Update the target map in ActiveAmbush
    ActiveAmbush.targetMap = targetPlayers

    
    -- Assign targets to NPCs
    AssignTargetsToNPCs()
end

-- Assign targets to NPCs based on proximity and other factors
function AssignTargetsToNPCs()
    -- Minimal AI loop per update plan: iterate unified AmbushActors and task nearest player
    if not AmbushActors or #AmbushActors == 0 then
        return
    end

    local function acquireNearestPlayer(entity)
        local nearestPed = nil
        local nearestDist = 999999.0
        local eCoords = GetEntityCoords(entity)
        local leash = (Config and Config.AttackDistance) or 300.0
        for _, pid in ipairs(GetActivePlayers()) do
            local pped = GetPlayerPed(pid)
            if DoesEntityExist(pped) and not IsEntityDead(pped) then
                local pcoords = GetEntityCoords(pped)
                local d = #(pcoords - eCoords)
                if d < nearestDist and d <= leash then
                    nearestDist = d
                    nearestPed = pped
                end
            end
        end
        return nearestPed
    end

    for i = 1, #AmbushActors do
        local actor = AmbushActors[i]
        if actor and actor.entity and DoesEntityExist(actor.entity) and not IsEntityDead(actor.entity) then
            local target = acquireNearestPlayer(actor.entity)
            if target then
                -- Delegate combat tasking to centralized function which only issues TaskCombatPed on target change/initial set
                AssignTargetToNPC(actor.entity, target)
                -- 30% chance to make the NPC shout when acquiring/refreshing target
                local voice = math.random(1, 100)
                if voice > 70 then
                    pcall(NPCCombatVoice, actor.entity)
                end
            end
        end
    end
end

-- ============================================
-- STUCK NPC DETECTION AND FIXING
-- ============================================

-- Check if an NPC is stuck or not engaging properly
function CheckAndFixStuckNPCs()
    if not ActiveAmbush or not ActiveAmbush.npcs then
        return
    end
    
    -- Initialize target cache if it doesn't exist
    if not ActiveAmbush.npcTargets then
        ActiveAmbush.npcTargets = {}
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, npc in ipairs(ActiveAmbush.npcs) do
        if DoesEntityExist(npc) and not IsEntityDead(npc) then
            local npcCoords = GetEntityCoords(npc)
            local distanceToPlayer = #(npcCoords - playerCoords)
            
            -- Check if NPC is too far from player but not moving
            if distanceToPlayer > 20.0 and distanceToPlayer < 150.0 then
                -- Check if NPC is not moving
                local npcVelocity = GetEntityVelocity(npc)
                local speed = #vector3(npcVelocity.x, npcVelocity.y, npcVelocity.z)
                
                if speed < 0.1 then
                    -- NPC is likely stuck, reset its tasks
                    ClearPedTasks(npc)
                    
                    -- Force the NPC to move toward the player
                    TaskGoToEntity(npc, playerPed, -1, 2.0, 2.0, 0, 0)
                    
                    -- After a short delay, switch back to combat
                    Citizen.CreateThread(function()
                        
                        if DoesEntityExist(npc) and not IsEntityDead(npc) and DoesEntityExist(playerPed) then
                            -- Set combat attributes and assign target
                            AssignTargetToNPC(npc, playerPed)

                        end
                        Wait(1500)
                    end)
                end
            end
        end
    end
end

-- ============================================
-- BLIP MANAGEMENT
-- ============================================

-- Initialize blips for the ambush
function InitializeBlips()
    if not ActiveAmbush then
        return
    end
    
    -- Create area blip
    if Config.EnableBlips and (BlipOverrides.AreaBlip == nil and Config.AreaBlip.Enabled or BlipOverrides.AreaBlip == true) then
        -- Create area blip
        AreaBlip = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, ActiveAmbush.coords.x, ActiveAmbush.coords.y, ActiveAmbush.coords.z, Config.AreaBlip.Radius)
        
        -- Set blip properties
        Citizen.InvokeNative(0x9CB1A1623062F402, AreaBlip, "Ambush") -- SetBlipName
        Citizen.InvokeNative(0x662D364ABF16DE2F, AreaBlip, GetHashKey(Config.AreaBlip.Color)) -- BlipAddModifier
        Citizen.InvokeNative(0x9B6A58FDB0024F12, AreaBlip, Config.AreaBlip.Scale) -- SetBlipScale
        Citizen.InvokeNative(0x45FF974EEE1C8734, AreaBlip, Config.AreaBlip.Alpha) -- SetBlipAlpha
        
        -- Notify server of area blip coordinates for other players
        TriggerServerEvent('ambush:server:setAreaBlipCoords', ActiveAmbush.coords)
    end
    
    -- Create NPC blips
    if Config.EnableBlips and (BlipOverrides.PedBlip == nil and Config.PedBlip.Enabled or BlipOverrides.PedBlip == true) then
        for _, npc in ipairs(ActiveAmbush.npcs) do
            if DoesEntityExist(npc) then
                -- Create blip for NPC
                local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, Config.PedBlip.Sprite, npc) -- BlipAddForEntity
                
                -- Set blip properties
                Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey(Config.PedBlip.Color)) -- BlipAddModifier
                Citizen.InvokeNative(0x9B6A58FDB0024F12, blip, Config.PedBlip.Scale) -- SetBlipScale
                
                -- Store blip in cache
                local netId = NetworkGetNetworkIdFromEntity(npc)
                BlipCache[netId] = {
                    blip = blip,
                    entity = npc
                }
                
                -- Notify server of NPC network ID for other players
                TriggerServerEvent('ambush:server:addNetworkId', netId)
            end
        end
    end
end

-- ============================================
-- TARGETING UPDATE LOOP
-- ============================================

-- Start the targeting update loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.TargetingUpdateInterval)
        
        if ActiveAmbush and ActiveAmbush.npcs and #ActiveAmbush.npcs > 0 then
            -- Initialize target cache if it doesn't exist
            if not ActiveAmbush.npcTargets then
                ActiveAmbush.npcTargets = {}
            end
            
            -- Update targeting for all NPCs
            UpdateTargeting()
            
            -- Check for and fix stuck NPCs
            CheckAndFixStuckNPCs()
            
            -- Additional check for NPCs that might be not engaging
            for _, npc in ipairs(ActiveAmbush.npcs) do
                if DoesEntityExist(npc) and not IsEntityDead(npc) then
                    -- Check if NPC is in combat
                    if not IsPedInCombat(npc) then
                        -- If NPC is not in combat, force it to engage with the nearest player
                        local playerPed = PlayerPedId()
                        if DoesEntityExist(playerPed) then
                            -- Assign target to NPC
                            AssignTargetToNPC(npc, playerPed)
                            
                        end
                    end
                end
            end
        end
    end
end)