# Exports

Some exports will reset their values after an ambush occurs.
It is always good to manually reset values at the end of a script mission in the event an ambush does not take place during the script mission.
## SetAdditionalAmbushChance
```lua
exports['Nt_Ambient_Ambush']:SetAdditionalAmbushChance(chance)
```
**Parameters:**
- `chance` (number): Additional chance for an ambush to occur. Range is from 0 to 1.
**Returns:**
- `boolean`: Success status (true if set successfully)

## ResetAmbushCooldown
```lua
exports['Nt_Ambient_Ambush']:ResetAmbushCooldown()
```
**Returns:**
- `boolean`: Success status (true if reset successfully)
**Use:**
- This will reset the players ambush cooldown to ensure they will not be in cooldown during the script mission.
- Ambushes will not spawn while the ambush cooldown is active.

## SetAdditionalAmbushPedCount
```lua
exports['Nt_Ambient_Ambush']:SetAdditionalAmbushPedCount(count)
```
**Parameters:**
- `count` (number): Number of additional NPCs that can spawn with each ambush.
**Returns:**
- `boolean`: Success status (true if set successfully)

## ForceAmbush
```lua
exports['Nt_Ambient_Ambush']:ForceAmbush()
```
**Returns:**
- `boolean`: Success status (true if forced successfully)
**Use:**
- Forces an ambush to occur at the players current coords. Can be used to force an ambush at a target time/location.
- This will by bypass safe areas.

## PauseAmbushForPlayer
```lua
exports['Nt_Ambient_Ambush']:PauseAmbushForPlayer(bool)
```
**Parameters:**
- `true`: Pause ambushes for player
- `false`: Unpause ambushes for player
**Returns:**
- `boolean`: Success status (true if paused/unpaused successfully)

## SetAmbushBlips
```lua
exports['Nt_Ambient_Ambush']:SetAmbushBlips(blipType, state)
```
**Parameters:**
- `blipType` (string): Type of blip to control
  - "Ped": Controls enemy NPC blips
  - "Area": Controls the area radius blip
  - "Both": Controls both blip types
- `state` (boolean or string): Visibility state
  - `true`: Enable blips
  - `false`: Disable blips
  - "Reset": Reset to config default settings
**Returns:**
- `boolean`: Success status (true if set successfully)

## SetAmbushPeds
```lua
exports['Nt_Ambient_Ambush']:SetAmbushPeds(groupName)
```
**Parameters:**
- `groupName` (string): Key from `ConfigRegions.Groups` to use for the next ambush.
**Returns:**
- `boolean`: Success status (true if set successfully)
**Reset:**
- nil will reset it.
**Use:**
- Forces the next ambush to use the specified group from `ConfigRegions.Groups`.
- Override persists until the ambush finishes; it resets automatically on ambush cleanup.
- Ensure the provided key exists; supports ped or animal groups as defined in your config.



## SetAmbushPeds
```lua
exports['Nt_Ambient_Ambush']:SetMissionCooldown(Num)
```
**Parameters:**
- `Num` (number): Any positive number
**Returns:**
- `boolean`: Success status (true if set successfully)
**Reset:**
- 0 will reset it.
**Use:**
- Allows ambient ambushes to have long timers and mission use to be on short timers.
- This will temporarily override the config value for `Config.Mission.Cooldown`.