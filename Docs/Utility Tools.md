# Utility Tools

## /AAZone
This tool will list the zones ID's and hashes at the players current location.
This is used to find the zone and Id of a specific area, for a safe area or ambush region.

Example Printout:
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

More information on using /AAZone is in Zones.md

## /GetCoords

This will print out the players current location in a Vector3 format.
This would be used to update configCoords.lua to add a new coord location.

## /AAChance
This will set the Aditional Ambush Chance for the players next ambush.
This can be used to test different chances for a set path a player will take during a scripted mission.