# Zones

This script has 3 config files that controls where ambushes can spawn.

### This file lists areas ambushes can spawn in.
- configRegions.lua

### These files list areas ambushes CANNOT spawn in.
- ConfigTowns.lua
- ConfigCoords.lua


## Add Safe Zone

### By Region

You can add additonal zones by region to configTowns.lua
Any Zone Id can be used, but there are overlapping and nested zones.

```lua
    ["ZONE_NAME"] = {
        DistrictId = -1532919875,   -- District Id hash value
        ZoneTypeId = 11,            -- Zone Id related to the Ditrict Id hash value
        Name = "Zone Name"
    },
```
### By Vector3 Coords

Not every place has a well defined district ID.
You can use a vector3 coordinate instead of a district id, and a radius for the zone.

The example below has a radius of 100.

```lua
[vector3(2954.1907, 774.0586, 51.3938)] = 100, -- Stables by Van Horn
```

## Abmush Regions

Most map regions are covered, but they can be modified further.
Below is a subsection from the Lemoyne, Bluewater Marsh region. 

#### Regions
```lua
["Marsh1"] = {
        RegionHash = 10200028,  -- Matching RegionHash for Zone ID
        ZoneTypeId = 11,        -- Matching ID for RegionHash
        Priority = true,        -- Picked over other overlapping regions.
        Name = "Marsh1",
        NightBonus = true,      -- Additonal ambush chance at night
        EnemyTypes = {          -- custom list of enemies
             "g_m_m_uniswamp_01",
        },
        Weapons = {
            Melee = "Swamp",    -- Table of weapons taken from ConfigWeapons.Melee
            MeleeChance = 100,  -- Chance for an enemy to get a weapon from this table
            Sidearms = "",      -- Can be left blank
            SidearmsChance = 100,
            Longarms = "Swamp",
            LongarmsChance = 20
        }
    },
```
#### Enemies
A table of enemies or ConfigRegions.Enemies can be used to make a list of enemies.
```lua
        EnemyTypes = {  -- list of enemies
             "g_m_m_uniswamp_01",
        },
```
```lua
        EnemyTypes = ConfigRegions.Enemies['NEW_LIST'], -- Will then use the custom list.
```


## How to get District and Zone IDs

#### AAZone
AAZone will give a printout of district id's for each zone id at the players current location.

Below is an example of the printout at Fort Wallace.

```
ZoneType 1: hash= false
ZoneType 2: hash= false
ZoneType 3: hash= false
ZoneType 4: hash= false
ZoneType 5: hash= false
ZoneType 6: hash= false
ZoneType 7: hash= false
ZoneType 8: hash= false
ZoneType 9: hash= false
ZoneType 10: hash= 1835499550 | Region: Cumberland Forest
ZoneType 11: hash= -99881305
ZoneType 12: hash= false
```
Use AAZone around the target area to make sure the ID and hash is not for a zone that is overlapping.

```
ZoneType 11: hash= -99881305 | Town: Fort Wallace
```
Confirms Fort Wallace was added to the Town list.