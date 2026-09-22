-- ============================================
-- AMBIENT AMBUSH - MAIN CONFIGURATION
-- ============================================

Config = {}

-- ============================================
-- DEBUG SETTINGS
-- ============================================

-- Enable debug messages in console
Config.Debug = false

-- ============================================
-- AMBUSH SPAWN SETTINGS
-- ============================================

Config.OtherScripts = {
    -- Optional integrations. Set either option to false if that resource is not used.
    MissionsManager = true, -- https://github.com/Nubetastic/Nt_Missions_Manager
    ntStables = true,
}

-- Base chance for ambush to spawn (percentage, 0-100)
-- This is checked every CheckInterval seconds when player is outside towns
Config.AmbushChance = {
    Base  = 0,
    NightAddedChance = 5, -- Chance added to base during night, if area is enabled.
    MoneyTick = 200, -- adds 1 to ambush chance for every $100 player has on them. (max 10)
    MoneyMax = 10,
    ItemTick = 1, -- adds 1 to ambush chance for every 1 items player has on them. (max 15)
    ItemMax = 15,
    WagonCheckDist = 25,
}

Config.PlayerPenalties = {
    RemoveCash = math.random(1,10) -- A random percentage of the total cash they are carrying is removed on death.
}

Config.Buckets = {0, 100} -- Ambushes can only happen if client is in this bucket range.

-- How often to check for ambush spawns (in seconds)
Config.CheckInterval = 5 --* 60  -- Every 5 minutes

-- Base cooldown after an ambush spawns (in minutes)
Config.BaseCooldown = 60
Config.FailCooldown = 5

-- Number of NPCs to spawn per ambush
-- BaseMin/Max: Base number of NPCs for the host player
-- PerPlayerMin/Max: Additional NPCs per nearby player
Config.SpawnNum = {
    BaseMin = 2,
    BaseMax = 4,
    PerPlayerMin = 1,
    PerPlayerMax = 2
}

-- Distance from player to spawn NPCs (in meters)
Config.MissionDespawnDistance = 350 -- Allows for a chase.

-- Road-based spawn mapping used to find a stable ambush point ahead of the player
Config.RoadSpawn = {
    MountedMapDistance = 300, -- spawn coords distance down the road
    FootMapDistance = 150, -- spawn coords distance down the road
    RoadNodeDistance = 20,
    RoadFail = {
        GridSize = 5, -- 5x5 grid
        GridGap = 5, -- 5 distance between points.
    }
}

Config.AmbushVariations = {
    WagonModels = {
        "wagon05x",
        "supplywagon",
        "wagon02x",
        "wagon03x",
        "chuckwagon000x",
    },
    WagonApproachDistance = 35,
    WagonEnemySideDistance = 30,
    WagonEnemyBehindDistance = 10,
    RoadSideDistance = 6,
    RoadSideAttackDistance = 60,
    WagonChance = 100,
    RoadSideChance = 0,
}

-- Percentage of NPCs that spawn pre-mounted for faster engagement
-- These bypass the horse-mounting delay
Config.PreMountedPercentage = 100 -- 100% of NPCs spawn already on horses

    
-- ============================================
-- COMBAT SETTINGS
-- ============================================

-- Distance at which NPCs will attack players (in meters)
Config.AttackDistance = 350 -- Player scan distance from mission center.

-- How often to update NPC targeting (in milliseconds)
Config.TargetingUpdateInterval = 1500

-- Throttle duplicate commands to reduce stutter (in milliseconds)
Config.NPCTaskCooldown = 1500
Config.NPCGoToCooldown = 2000

--  modifier for NPCs (1.0 = normal, 0.5 = half damage, 2.0 = double damage)
Config.DamageModifier = 2.0
