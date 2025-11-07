-- ============================================
-- AMBIENT AMBUSH - BLIP MANAGEMENT
-- ============================================

-- Note: BlipCache is now a global variable defined in cleanup.lua
-- This allows the cleanup system to manage blip removal centrally

local IsHost = false
local HostServerId = nil

-- ============================================
-- BLIP CREATION & MANAGEMENT
-- ============================================

-- Create a blip for an NPC
local function CreateNPCBlip(ped)
    if not DoesEntityExist(ped) then
        return nil
    end

    -- Check if entity is networked
    local isNetworked = NetworkGetEntityIsNetworked(ped)

    
    -- Create blip on the ped
    local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 1664425300, ped) -- BlipAddForEntity
    
    -- Make the blip visible on networked entities
    Citizen.InvokeNative(0xE37287EE358939C3, ped)
    -- Set blip sprite (enemy icon)
    SetBlipSprite(blip, Config.PedBlip.Sprite) -- SetBlipSprite
    
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Enemy")
    -- Set blip color - using direct hash value for reliability
    local colorHash = GetHashKey(Config.PedBlip.Color)
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, colorHash) -- SetBlipModifier
    

    
    -- Set blip scale
    Citizen.InvokeNative(0xD38744167B2FA257, blip, Config.PedBlip.Scale) -- SetBlipScale
    
    
    return blip
end


-- ============================================
-- CACHE MANAGEMENT
-- ============================================

-- Add network IDs to the blip cache
local function AddNetworkIdsToCache(networkIds)
    if not networkIds or type(networkIds) ~= "table" then
        return
    end
    
    for _, netId in ipairs(networkIds) do
        if not BlipCache[netId] then
            BlipCache[netId] = {
                netId = netId,
                ped = nil,
                blip = nil,
                lastCheck = 0
            }
            
        end
    end
end

-- Create blips for all cached network IDs (one-time creation)
local function CreateBlipsFromCache()


    for netId, data in pairs(BlipCache) do
        -- Try to get the ped from network ID
        if not data.ped or not DoesEntityExist(data.ped) then
            local entity = NetworkGetEntityFromNetworkId(netId)
            
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                data.ped = entity
                

            end
        end
        
        -- Create blip if we have a valid ped
        if data.ped and DoesEntityExist(data.ped) and not data.blip then
            data.blip = CreateNPCBlip(data.ped)

        end
    end
end

-- ============================================
-- PUBLIC FUNCTIONS
-- ============================================

-- Initialize blips for host (uses local network IDs)
function InitializeBlipsAsHost(networkIds)
    if not Config.EnableBlips or not Config.PedBlip.Enabled then
        return
    end
    if BlipOverrides.PedBlip == false then
        return
    end

    IsHost = true
    HostServerId = GetPlayerServerId(PlayerId())
    

    
    -- Add network IDs to cache
    AddNetworkIdsToCache(networkIds)
    
    -- Create blips immediately
    CreateBlipsFromCache()
end

-- Initialize blips for participant (requests network IDs from server)
function InitializeBlipsAsParticipant(hostServerId)
    if not Config.EnableBlips or not Config.PedBlip.Enabled then
        return
    end
    
    IsHost = false
    HostServerId = hostServerId
    

    
    -- Request network IDs from server
    TriggerServerEvent('ambush:server:requestNetworkIds', hostServerId)
end

-- ============================================
-- NETWORK EVENTS
-- ============================================

-- Receive network IDs from server (for participants)
RegisterNetEvent('ambush:client:receiveNetworkIds')
AddEventHandler('ambush:client:receiveNetworkIds', function(networkIds)
    if not Config.EnableBlips or not Config.PedBlip.Enabled then
        return
    end

    if BlipOverrides.PedBlip == false then
        return
    end

    -- Add to cache
    AddNetworkIdsToCache(networkIds)
    
    -- Create blips immediately
    CreateBlipsFromCache()
    
end)

-- Join an ambush as a participant
RegisterNetEvent('ambush:client:joinAmbush')
AddEventHandler('ambush:client:joinAmbush', function(hostServerId)
    if not Config.EnableBlips then
        return
    end
    if BlipOverrides.PedBlip == false then
        return
    end

    -- Initialize blips as participant
    if Config.PedBlip.Enabled then
        InitializeBlipsAsParticipant(hostServerId)
    end
    
    -- Initialize area blip as participant
    if Config.AreaBlip.Enabled then
        InitializeAreaBlipAsParticipant(hostServerId)
    end
end)