-- ============================================
-- WEAPON DEFINITIONS
-- ============================================
-- Define weapon lists that can be referenced by regions
-- Each list contains weapons with weighted distribution (duplicates = higher chance)

ConfigWeapons = {}

-- ============================================
-- MELEE WEAPONS
-- ============================================

ConfigWeapons.Melee = {
    ["Common"] = {
        "WEAPON_MELEE_KNIFE",
    },
    ["Swamp"] = {
        "WEAPON_MELEE_MACHETE",
    },
}

-- ============================================
-- SIDEARMS
-- ============================================

ConfigWeapons.Sidearms = {
    ["Common"] = {
        -- Cattleman Revolver: ~36% chance (most common)
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        -- Double-Action Revolver: ~29% chance
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_DOUBLEACTION",
        -- Schofield Revolver: ~21% chance
        "WEAPON_REVOLVER_SCHOFIELD",
        "WEAPON_REVOLVER_SCHOFIELD",
        "WEAPON_REVOLVER_SCHOFIELD",
        -- Semi-Auto Pistol: ~7% chance
        "WEAPON_PISTOL_SEMIAUTO",
        -- Mauser Pistol: ~7% chance (rarest)
        "WEAPON_PISTOL_MAUSER"
    },
    ["Outlaws"] = {
        -- More aggressive loadout with better weapons
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_SCHOFIELD",
        "WEAPON_REVOLVER_SCHOFIELD",
        "WEAPON_REVOLVER_SCHOFIELD",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_PISTOL_SEMIAUTO",
        "WEAPON_PISTOL_SEMIAUTO",
        "WEAPON_PISTOL_MAUSER",
    },
    ["Banditos"] = {
        -- Mexican bandits
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_SCHOFIELD",
    },
    ["Mountain"] = {
        -- Mountain men with older weapons
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_CATTLEMAN",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_DOUBLEACTION",
        "WEAPON_REVOLVER_SCHOFIELD",
    },
    
}

-- ============================================
-- LONGARMS
-- ============================================

ConfigWeapons.Longarms = {
    ["Common"] = {
        -- Carbine Repeater: ~43% chance (most common)
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        -- Bolt-Action Rifle: ~21% chance
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        -- Winchester Repeater: ~14% chance
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_REPEATER_WINCHESTER",
        -- Henry Repeater: ~14% chance
        "WEAPON_REPEATER_HENRY",
        "WEAPON_REPEATER_HENRY",
        -- Carcano Sniper: ~7% chance (rarest)
        "WEAPON_SNIPERRIFLE_CARCANO",
    },
    ["Outlaws"] = {
        -- More dangerous weapons
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_REPEATER_HENRY",
        "WEAPON_SNIPERRIFLE_CARCANO",
        -- Removed unsupported weapon: WEAPON_SNIPERRIFLE_ROLLINGBLOCK
    },
    ["Banditos"] = {
        -- Mexican bandits
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_REPEATER_WINCHESTER",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_REPEATER_HENRY",
    },
    ["Mountain"] = {
        -- Mountain men with hunting rifles
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_RIFLE_BOLTACTION",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_CARBINE",
        "WEAPON_REPEATER_WINCHESTER",
        -- Removed unsupported weapons: WEAPON_SNIPERRIFLE_ROLLINGBLOCK, WEAPON_RIFLE_SPRINGFIELD
        "WEAPON_SNIPERRIFLE_CARCANO", -- Added supported alternative
    },
    ["Shotguns"] = {
        -- Shotgun-heavy loadout for swamp/close quarters
        "WEAPON_SHOTGUN_DOUBLEBARREL",
        "WEAPON_SHOTGUN_DOUBLEBARREL",
        "WEAPON_SHOTGUN_DOUBLEBARREL",
        "WEAPON_SHOTGUN_PUMP",
        "WEAPON_SHOTGUN_PUMP",
        "WEAPON_SHOTGUN_REPEATING",
        "WEAPON_REPEATER_CARBINE",
    },
    ["Swamp"] = {
        "WEAPON_BOW",
    },
}