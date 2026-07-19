-- ============================================
-- AMBIENT AMBUSH - PLAYER DEATH MONITOR
-- ============================================

local DeathState = {}
local DeathCheckDelay = 1500

local function IsAmbushNPC(entity)
    if not ActiveAmbush or not ActiveAmbush.npcs or not entity or entity == 0 then
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if not netId or netId == 0 then
        return false
    end

    for _, npcNetId in ipairs(ActiveAmbush.npcs) do
        if npcNetId == netId then
            return true
        end
    end

    return false
end

local function GetCachedAmbushPlayers()
    if not ActiveAmbush then
        return {}
    end

    return ActiveAmbush.cachedZonePlayers or {}
end

local function HandlePlayerDeath(playerData)
    if not playerData or not playerData.serverId or not playerData.ped then
        return
    end

    if not DoesEntityExist(playerData.ped) then
        DeathState[playerData.serverId] = nil
        return
    end

    if not IsEntityDead(playerData.ped) then
        DeathState[playerData.serverId] = nil
        return
    end

    local state = DeathState[playerData.serverId]
    if not state then
        state = {
            startedAt = GetGameTimer(),
            processed = false
        }
        DeathState[playerData.serverId] = state
    end

    if state.processed then
        return
    end

    local elapsed = GetGameTimer() - state.startedAt
    if elapsed < DeathCheckDelay then
        return
    end

    local killer = GetPedSourceOfDeath(playerData.ped)
    if killer and killer ~= 0 and DoesEntityExist(killer) and IsAmbushNPC(killer) then
        state.processed = true
        TriggerServerEvent('ambush:server:applyNpcKillPenalty')

        if Config and Config.Debug then
            print(string.format("[Ambush] NPC kill detected for player %s, requesting cash penalty", tostring(playerData.serverId)))
        end
    else
        if elapsed < 5000 then
            return
        end

        state.processed = true
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)

        if not ActiveAmbush or not ActiveAmbush.cachedZonePlayers then
            DeathState = {}
        else
            local trackedPlayers = GetCachedAmbushPlayers()
            local activePlayers = {}

            for _, playerData in ipairs(trackedPlayers) do
                if playerData and playerData.serverId then
                    activePlayers[playerData.serverId] = true
                    HandlePlayerDeath(playerData)
                end
            end

            for serverId, _ in pairs(DeathState) do
                if not activePlayers[serverId] then
                    DeathState[serverId] = nil
                end
            end
        end
    end
end)
