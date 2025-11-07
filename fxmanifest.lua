fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Nubetastic'
description 'Dynamic ambient ambush system for RedM - Creates random enemy encounters outside of towns'
version '1.0.0'

-- Shared configuration files
shared_scripts {
    'shared/config.lua',
    'shared/configRegions.lua',
    'shared/configTowns.lua',
    'shared/configCoords.lua',
    'shared/configWeapons.lua'
}

-- Client-side scripts
client_scripts {
    'client/cleanup.lua',
    'client/spawn.lua',
    'client/npcAI.lua',
    'client/main.lua',
    'client/blips.lua',
    'client/AreaBlip.lua',
    'client/exports.lua',
    'client/utilities.lua'
}

-- Server-side scripts
server_scripts {
    'server/main.lua',
    'server/PedBlip.lua',
    'server/AreaBlip.lua'
}
