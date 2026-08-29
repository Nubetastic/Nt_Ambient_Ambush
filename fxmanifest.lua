fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Nubetastic'
description 'Dynamic ambient ambush system for RedM - Creates random enemy encounters outside of towns'
version '1.2.0'

-- Shared configuration files
shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/configItems.lua',
    'shared/configRegions.lua',
    'shared/configTowns.lua',
    'shared/configCoords.lua',
    'shared/configWeapons.lua'
}

-- Client-side scripts
client_scripts {
    'client/dynamicCoords.lua',
    'client/cleanup.lua',
    'client/roadspawn.lua',
    'client/spawn.lua',
    'client/npcAI.lua',
    'client/playerMonitor.lua',
    'client/main.lua',
    'client/exports.lua',
    'client/utilities.lua',
}

-- Server-side scripts
server_scripts {
    'server/exports.lua',
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'rsg-core',
    'rsg-inventory'
}
