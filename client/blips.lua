-- AMBIENT AMBUSH - BLIP MANAGEMENT
-- ============================================

RegisterNetEvent('ambush:client:joinAmbush')
AddEventHandler('ambush:client:joinAmbush', function(hostServerId, ambushId)
    if not Config.EnableBlips then
        return
    end

    TriggerServerEvent('ambush:server:addPlayerToAmbush', hostServerId, ambushId)

    if Config.AreaBlip and Config.AreaBlip.Enabled then
        if not BlipOverrides or BlipOverrides.AreaBlip ~= false then
            InitializeAreaBlipAsParticipant(hostServerId)
        end
    end
end)
