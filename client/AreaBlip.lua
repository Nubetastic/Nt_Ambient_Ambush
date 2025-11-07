-- ============================================
-- AMBIENT AMBUSH - AREA BLIP MANAGEMENT
-- ============================================

-- Note: AreaBlip and AreaRadiusBlip are now global variables defined in cleanup.lua
-- This allows the cleanup system to manage blip removal centrally

local IsHost = false
local HostServerId = nil
local AreaBlipCoords = nil

-- ============================================
-- AREA BLIP CREATION & MANAGEMENT
-- ============================================

-- Create an area blip at the specified coordinates
local function CreateAreaBlip(coords)
    if not coords or not coords.x or not coords.y or not coords.z then

        return nil
    end
    

    
    -- Create a blip at the coordinates
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z) -- BlipAddForCoords
    
    if not blip or blip == 0 then
        return nil
    end
    

    
    -- Set blip sprite (circle/radius)
    Citizen.InvokeNative(0x74F74D3207ED525C, blip, Config.AreaBlip.Sprite, 0) -- SetBlipSprite
    
    -- Set blip color - using direct hash value for reliability
    local colorHash = GetHashKey(Config.AreaBlip.Color)
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, colorHash) -- SetBlipModifier
    

    
    -- Set blip scale
    Citizen.InvokeNative(0xD38744167B2FA257, blip, Config.AreaBlip.Scale) -- SetBlipScale
    
    -- Set blip alpha (transparency)
    Citizen.InvokeNative(0x45FF974EEE1C8734, blip, Config.AreaBlip.Alpha) -- SetBlipAlpha
    
    -- Set blip name to "Ambush"
    local textEntry = CreateVarString(10, "LITERAL_STRING", "Ambush")
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, textEntry) -- SetBlipName
    

    
    -- Set blip radius - using the correct native for radius blips
    -- This creates a radius blip at the coordinates with the specified radius
    -- Store it in the global AreaRadiusBlip variable for cleanup
    AreaRadiusBlip = Citizen.InvokeNative(0x45F13B7E0A15C880, -1282792512, coords.x, coords.y, coords.z, Config.AreaBlip.Radius) -- _SET_BLIP_ROTATION (used for radius in RDR2)
    
    -- Set the radius area color to red
    if AreaRadiusBlip then
        local radiusColorHash = GetHashKey("BLIP_MODIFIER_MP_COLOR_2") -- Red color
        Citizen.InvokeNative(0x662D364ABF16DE2F, AreaRadiusBlip, radiusColorHash) -- SetBlipModifier for radius
        

    end
    

    

    
    return blip
end

-- Remove the area blip
local function RemoveAreaBlip()
    if AreaBlip and DoesBlipExist(AreaBlip) then
        RemoveBlip(AreaBlip)

        AreaBlip = nil
    end
    
    if AreaRadiusBlip and DoesBlipExist(AreaRadiusBlip) then
        RemoveBlip(AreaRadiusBlip)

        AreaRadiusBlip = nil
    end
end

-- ============================================
-- PUBLIC FUNCTIONS
-- ============================================

-- Initialize area blip as host
function InitializeAreaBlipAsHost(coords)
    if not Config.EnableBlips or not Config.AreaBlip.Enabled then
        return
    end
    if BlipOverrides.AreaBlip == false then
        return
    end

    IsHost = true
    HostServerId = GetPlayerServerId(PlayerId())
    AreaBlipCoords = coords
    

    
    -- Remove any existing area blip
    RemoveAreaBlip()
    
    -- Create new area blip
    AreaBlip = CreateAreaBlip(coords)
    
    -- Share area blip coordinates with other players
    TriggerServerEvent('ambush:server:shareAreaBlipCoords', coords)
end

-- Initialize area blip as participant
function InitializeAreaBlipAsParticipant(hostServerId)
    if not Config.EnableBlips or not Config.AreaBlip.Enabled then
        return
    end
    if BlipOverrides.AreaBlip == false then
        return
    end
    
    IsHost = false
    HostServerId = hostServerId
    

    
    -- Remove any existing area blip
    RemoveAreaBlip()
    
    -- Request area blip coordinates from server
    TriggerServerEvent('ambush:server:requestAreaBlipCoords', hostServerId)
end



-- ============================================
-- NETWORK EVENTS
-- ============================================

-- Receive area blip coordinates from server (for participants)
RegisterNetEvent('ambush:client:receiveAreaBlipCoords')
AddEventHandler('ambush:client:receiveAreaBlipCoords', function(coords)
    if not Config.EnableBlips or not Config.AreaBlip.Enabled then
        return
    end
    if BlipOverrides.AreaBlip == false then
        return
    end
    
    if Config.Debug then
        print("[Area Blip] Received area blip coords from server: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)
    end
    
    -- Store coordinates
    AreaBlipCoords = coords
    
    -- Remove any existing area blip
    RemoveAreaBlip()
    
    -- Create new area blip
    AreaBlip = CreateAreaBlip(coords)
end)