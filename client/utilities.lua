-- ============================================
-- AMBIENT AMBUSH - TEST/DEBUG COMMANDS
-- ============================================

-- Only register commands when debug is enabled
if not Config.Debug then
    return
end

-- AdditionalAmbushChance is defined in client/main.lua as a global

-- ============================================
-- /AAChance <0-100>
-- Sets the extra ambush chance for quick testing
-- ============================================
RegisterCommand('AAChance', function(source, args, raw)
    if #args < 1 then
        print("[Ambush] Usage: /AAChance <0-100>")
        print("[Ambush] Current additional chance: " .. tostring(AdditionalAmbushChance or 0) .. "%")
        print("[Ambush] Base ambush chance: " .. tostring(Config.AmbushChance.Base) .. "%")
        print("[Ambush] Total ambush chance: " .. tostring((Config.AmbushChance.Base or 0) + (AdditionalAmbushChance or 0)) .. "% (not including night bonus)")
        return
    end

    local chance = tonumber(args[1])
    if not chance then
        print("[Ambush] ERROR: Invalid number provided")
        return
    end

    -- Clamp 0-100
    chance = math.max(0, math.min(100, chance))

    AdditionalAmbushChance = chance

    print("[Ambush] Additional ambush chance set to: " .. chance .. "%")
    print("[Ambush] Base ambush chance: " .. Config.AmbushChance.Base .. "%")
    print("[Ambush] Total ambush chance is now: " .. (Config.AmbushChance.Base + AdditionalAmbushChance) .. "% (not including night bonus)")
end, false)

print("[Ambush] Debug command registered: /AAChance <0-100>")

-- ============================================
-- /GetCoords
-- Prints the player's current coordinates in vector3 format
-- Useful for adding coordinate-based safe zones
-- ============================================
RegisterCommand('GetCoords', function(source, args, raw)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    print(string.format("[Ambush] Your coordinates: vector3(%.4f, %.4f, %.4f)", coords.x, coords.y, coords.z))
    print("[Ambush] Copy this to ConfigCoords.lua and add a radius value")
end, false)

print("[Ambush] Debug command registered: /GetCoords")

-- ============================================
-- Helper functions for /AAZone command
-- ============================================

local function getPlayerZoneHash(zoneTypeId)
    local ped = PlayerPedId()
    local x, y, z = table.unpack(GetEntityCoords(ped))
    return Citizen.InvokeNative(0x43AD8FC02B429D33, x, y, z, zoneTypeId)
end

local function findRegionByHash(hash)
    if not hash or not ConfigRegions or not ConfigRegions.Regions then return nil end
    for key, data in pairs(ConfigRegions.Regions) do
        if data.RegionHash == hash then
            return data
        end
    end
    return nil
end

local function findTownByHash(hash, zoneTypeId)
    if not hash or not ConfigTowns or not ConfigTowns.Towns then return nil end
    for key, data in pairs(ConfigTowns.Towns) do
        -- Match DistrictId; if a zoneTypeId is provided, also require ZoneTypeId to match
        if data.DistrictId == hash and (zoneTypeId == nil or data.ZoneTypeId == zoneTypeId) then
            return data
        end
    end
    return nil
end

-- ============================================
-- /AAZone
-- Prints all zone hashes for a set of zone type IDs at the player's coords once per command.
-- Adds name hints for known types: 1 (Town) and 10 (Region).
-- ============================================

-- Check exactly 12 zone types (1-12). Unknown IDs will typically return 0.
local ZONE_TYPE_IDS = {1,2,3,4,5,6,7,8,9,10,11,12}

RegisterCommand('AAZone', function(source, args, raw)
    for _, id in ipairs(ZONE_TYPE_IDS) do
        local hash = getPlayerZoneHash(id)
        local extra = ""

        -- Enrich with known mappings when available
        if type(hash) == 'number' and hash ~= 0 then
            local extras = {}

            -- Try region match for any zone type
            local region = findRegionByHash(hash)
            if region and region.Name then
                table.insert(extras, "Region: " .. tostring(region.Name))
            end

            -- Try town/settlement match for any zone type (don't force ZoneTypeId equality)
            local town = findTownByHash(hash, nil)
            if town and town.Name then
                table.insert(extras, "Town: " .. tostring(town.Name))
            end

            if #extras > 0 then
                extra = " | " .. table.concat(extras, " | ")
            end
        end

        print(("[Ambush] ZoneType %d: hash= %s%s"):format(id, tostring(hash), extra))
    end
end, false)

print("[Ambush] Debug command registered: /AAZone")