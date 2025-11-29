-- ============================================
-- AMBIENT AMBUSH - EXPORT INTERFACE
-- ============================================

-- Export: Set additional ambush chance
-- @param chance - Number (0-100) representing additional percentage chance
-- @return boolean - Success status
-- NOTE: Additional chance is automatically reset to 0 after an ambush spawns
exports('SetAdditionalAmbushChance', function(chance)
    if type(chance) ~= "number" then
        print("[Ambush] ERROR: SetAdditionalAmbushChance requires a number parameter")
        return false
    end
    
    -- Clamp value between 0 and 100
    chance = math.max(0, math.min(100, chance))
    
    -- Set the additional chance
    AdditionalAmbushChance = chance
    
    -- Debug output if enabled
    if Config.Debug then
        print("[Ambush] Additional ambush chance set to: " .. chance .. "%")
        print("[Ambush] Base ambush chance: " .. Config.AmbushChance.Base .. "%")
        print("[Ambush] Total ambush chance is now: " .. (Config.AmbushChance.Base + AdditionalAmbushChance) .. "% (not including night bonus)")
    end
    
    return true
end)

-- Export for additional cooldown has been removed to simplify the system

-- ============================================
-- NEW EXPORTS
-- ============================================

-- Export: Reset ambush cooldown
-- @return boolean - Success status
exports('ResetAmbushCooldown', function()
    cooldownEndTime = 0
    
    if Config.Debug then
        print("[Ambush] Cooldown has been reset via export")
    end
    
    return true
end)

-- Export: Set ambush blip visibility for next ambush
-- @param blipType - String: "Ped", "Area", or "Both" (case-insensitive)
-- @param state - Boolean/String: true, false, or "Reset" (case-insensitive)
-- @return boolean - Success status
exports('SetAmbushBlips', function(blipType, state)
    -- Validate and normalize blipType
    if type(blipType) ~= "string" then
        print("[Ambush] ERROR: SetAmbushBlips requires blipType as string ('Ped', 'Area', or 'Both')")
        return false
    end
    blipType = blipType:lower()
    
    -- Normalize state to lowercase if it's a string
    if type(state) == "string" then
        state = state:lower()
    end
    
    -- Handle reset
    if state == "reset" then
        if blipType == "ped" then
            BlipOverrides.PedBlip = nil
        elseif blipType == "area" then
            BlipOverrides.AreaBlip = nil
        elseif blipType == "both" then
            BlipOverrides.PedBlip = nil
            BlipOverrides.AreaBlip = nil
        else
            print("[Ambush] ERROR: Invalid blipType '" .. blipType .. "'. Use 'Ped', 'Area', or 'Both'")
            return false
        end
        
        if Config.Debug then
            print("[Ambush] Blip overrides reset for: " .. blipType)
        end
        return true
    end
    
    -- Handle true/false
    if type(state) ~= "boolean" then
        print("[Ambush] ERROR: SetAmbushBlips state must be true, false, or 'Reset'")
        return false
    end
    
    -- Set overrides
    if blipType == "ped" then
        BlipOverrides.PedBlip = state
    elseif blipType == "area" then
        BlipOverrides.AreaBlip = state
    elseif blipType == "both" then
        BlipOverrides.PedBlip = state
        BlipOverrides.AreaBlip = state
    else
        print("[Ambush] ERROR: Invalid blipType '" .. blipType .. "'. Use 'Ped', 'Area', or 'Both'")
        return false
    end
    
    if Config.Debug then
        print("[Ambush] Blip override set - Type: " .. blipType .. ", State: " .. tostring(state))
    end
    
    return true
end)

-- Export: Set additional ped count for next ambush
-- @param count - Number: Additional peds to spawn (0 or positive)
-- @return boolean - Success status
exports('SetAdditionalAmbushPedCount', function(count)
    if type(count) ~= "number" then
        print("[Ambush] ERROR: SetAdditionalAmbushPedCount requires a number parameter")
        return false
    end
    
    -- Ensure non-negative
    count = math.max(0, math.floor(count))
    
    -- Set additional ped count
    AdditionalPedCount = count
    
    if Config.Debug then
        print("[Ambush] Additional ped count set to: " .. count)
        print("[Ambush] Total ped count range: " .. (Config.SpawnNum.BaseMin + count) .. " - " .. (Config.SpawnNum.BaseMax + count))
    end
    
    return true
end)

-- Export: Set ambush peds group for next ambush
-- @param groupName - String key in ConfigRegions.Groups, or nil/"Reset" to clear override
-- @return boolean - Success status
exports('SetAmbushPeds', function(groupName)
    -- Allow reset by passing nil or the string "Reset" (case-insensitive)
    if groupName == nil or (type(groupName) == 'string' and groupName:lower() == 'reset') then
        groupOverwride = nil
        if Config.Debug then
            print('[Ambush] Next ambush group override has been reset')
        end
        return true
    end

    -- Validate string input
    if type(groupName) ~= 'string' then
        print('[Ambush] ERROR: SetAmbushPeds requires a string group name or nil/"Reset" to clear')
        return false
    end

    -- Validate group exists in config
    if not ConfigRegions or not ConfigRegions.Groups or not ConfigRegions.Groups[groupName] then
        print("[Ambush] ERROR: Unknown group '" .. tostring(groupName) .. "' in ConfigRegions.Groups")
        return false
    end

    -- Set override
    groupOverwride = groupName
    if Config.Debug then
        print('[Ambush] Next ambush group override set to: ' .. groupName)
    end
    return true
end)

-- Export: Pause or resume ambush system
-- @param state - Boolean: true to pause ambushes, false to resume
-- @return boolean - Success status
exports('PauseAmbushForPlayer', function(state)
    if type(state) ~= "boolean" then
        print("[Ambush] ERROR: PauseAmbushForPlayer requires a boolean parameter (true or false)")
        return false
    end
    
    -- Set pause state
    PauseAmbush = state
    
    if Config.Debug then
        if state then
            print("[Ambush] Ambush system PAUSED via export")
        else
            print("[Ambush] Ambush system RESUMED via export")
        end
    end
    
    return true
end)

-- Export: Force spawn an ambush immediately
-- @return boolean - Success status
exports('ForceAmbush', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Build zone type list
    local zoneTypeIds = GetAllUniqueZoneTypeIds()
    if #zoneTypeIds == 0 then
        print("[Ambush] ERROR: No zone types configured")
        return false
    end
    
    -- Get player's zone hashes
    local playerZoneHashes = GetPlayerZoneHashesForTypes(zoneTypeIds)
    
    -- Check if in no-spawn sphere
    if IsInsideNoSpawnSphere(playerCoords) then
        if Config.Debug then
            print("[Ambush] ForceAmbush failed - player in no-spawn sphere")
        end
        return false
    end
    
    -- Check if in town
    if IsTownByConfig(playerZoneHashes) then
        if Config.Debug then
            print("[Ambush] ForceAmbush failed - player in town")
        end
        return false
    end
    
    -- Match region
    local region = MatchRegions(playerZoneHashes)
    if not region then
        if Config.Debug then
            print("[Ambush] ForceAmbush failed - no matching region")
        end
        return false
    end
    
    -- Check if ambush already active
    if ActiveAmbush then
        if Config.Debug then
            print("[Ambush] ForceAmbush failed - ambush already active")
        end
        return false
    end
    
    if Config.Debug then
        print("[Ambush] ForceAmbush triggered in region: " .. region.Name)
    end
    
    -- Spawn the ambush
    SpawnAmbush(region, playerCoords)
    
    -- Start cooldown
    StartCooldown(Config.BaseCooldown)
    
    -- Reset additional ambush chance after spawn
    AdditionalAmbushChance = 0
    
    return true
end)

-- ============================================
-- DEBUG COMMANDS (moved to client/test.lua)
-- ============================================

-- AAChance and AARegion commands now live in client/test.lua and
-- are only registered when Config.Debug is true.

-- Export: Set temporary cooldown time
exports('SetMissionCooldown', function(tempCooldown)

    -- Ensure non-negative
    if type(tempCooldown) == "number" then
        missionCooldown = tempCooldown * 1000 or 0
        return true
    else
        return false
    end
end)