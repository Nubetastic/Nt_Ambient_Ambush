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

-- Base chance for ambush to spawn (percentage, 0-100)
-- This is checked every CheckInterval seconds when player is outside towns
Config.AmbushChance = {
    Base  = 1,
    NightAddedChance = 10 -- Chance added to base during night, if area is enabled.
}

-- How often to check for ambush spawns (in seconds)
Config.CheckInterval = 30 -- Every 1 minute

-- Base cooldown after an ambush spawns (in minutes)
Config.BaseCooldown = 15

-- Number of NPCs to spawn per ambush
-- BaseMin/Max: Base number of NPCs for the host player
-- PerPlayerMin/Max: Additional NPCs per nearby player
Config.SpawnNum = {
    BaseMin = 3,
    BaseMax = 5,
    PerPlayerMin = 1,
    PerPlayerMax = 3
}


-- Distance from player to spawn NPCs (in meters)
Config.SpawnLeftDistance = 100
Config.SpawnRightDistance = 100
Config.MissionDespawnDistance = 1000 -- Allows for a chase.

-- Percentage of NPCs to spawn at extended distance for mounted players
Config.MountedPlayerSpawnPercentage = 50 -- 50% of NPCs will spawn at extended distance

    
-- Percentage of NPCs that spawn on left (rest spawn on right)
-- 50 = 50% on left, 50% on right
Config.LeftSpawnPercentage = 50

-- ============================================
-- COMBAT SETTINGS
-- ============================================

-- Distance at which NPCs will attack players (in meters)
Config.AttackDistance = 400 -- Player scan distance from mission center.

-- How often to update NPC targeting (in milliseconds)
Config.TargetingUpdateInterval = 1500

-- Throttle duplicate commands to reduce stutter (in milliseconds)
Config.NPCTaskCooldown = 1500
Config.NPCGoToCooldown = 2000

-- Damage modifier for NPCs (1.0 = normal, 0.5 = half damage, 2.0 = double damage)
Config.DamageModifier = 1.5

-- ============================================
-- BLIP SETTINGS
-- ============================================

-- Master switch to enable/disable all blips
Config.EnableBlips = true

-- Individual NPC blip settings
Config.PedBlip = {
    Enabled = true,
    Sprite = -1350763423,
    Color = "BLIP_MODIFIER_ENEMY", -- Red color
    Scale = .75
}

-- Area blip settings (shows a circle around the ambush area)
Config.AreaBlip = {
    Enabled = true,
    Sprite = -1282792512, -- Circle/radius blip
    Color = "BLIP_MODIFIER_MP_COLOR_2", -- Red color
    Scale = 1.0,
    Alpha = 128, -- Semi-transparent
    Radius = 200.0 -- Match with attack distance (Config.AttackDistance)
}