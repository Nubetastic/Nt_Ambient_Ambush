local function roadSpawnLog(message)
    if Config and Config.Debug then
        print(("[RoadSpawn] %s"):format(tostring(message)))
    end
end

local function vec2(x, y)
    return { x = x, y = y }
end

local function normalizeVec(value)
    local length = math.sqrt((value.x * value.x) + (value.y * value.y))
    if length <= 0.0001 then return vec2(0.0, 0.0) end
    return vec2(value.x / length, value.y / length)
end

local function headingToVec(heading)
    local radians = math.rad(heading)
    return vec2(-math.sin(radians), math.cos(radians))
end

local function getGroundCoords(x, y, fallbackZ)
    local groundFound, groundZ = GetGroundZFor_3dCoord(x, y, fallbackZ + 100.0, false)
    return vector3(x, y, groundFound and groundZ or fallbackZ)
end

local function getRoadCoords(baseCoords, direction, distance)
    local coords = getGroundCoords(
        baseCoords.x + (direction.x * distance),
        baseCoords.y + (direction.y * distance),
        baseCoords.z
    )

    if IsPointOnRoad(coords.x, coords.y, coords.z, 0) then return coords end
end

local function getSpawnDistances(useMountedDistance)
    local roadConfig = Config and Config.RoadSpawn or {}
    local mapDistance

    if useMountedDistance then
        mapDistance = tonumber(roadConfig.MountedMapDistance)
    else
        mapDistance = tonumber(roadConfig.FootMapDistance)
    end

    mapDistance = mapDistance or tonumber(roadConfig.MountedMapDistance) or tonumber(roadConfig.FootMapDistance) or 300

    return mapDistance, math.max(1, tonumber(roadConfig.RoadNodeDistance) or 20)
end

local function traceRoadPath(originCoords, startHeading, totalDistance, nodeDistance)
    local maxSteps = math.max(1, math.ceil(totalDistance / nodeDistance))
    local currentCoords = originCoords
    local currentDirection = normalizeVec(headingToVec(startHeading))
    local points = {}

    for _ = 1, maxSteps do
        local bestCoords
        local bestAngle

        for angle = -90, 90, 10 do
            local radians = math.rad(angle)
            local direction = normalizeVec(vec2(
                (currentDirection.x * math.cos(radians)) - (currentDirection.y * math.sin(radians)),
                (currentDirection.x * math.sin(radians)) + (currentDirection.y * math.cos(radians))
            ))
            local roadCoords = getRoadCoords(currentCoords, direction, nodeDistance)

            if roadCoords and (not bestAngle or math.abs(angle) < bestAngle) then
                bestCoords = roadCoords
                bestAngle = math.abs(angle)
            end
        end

        if not bestCoords then break end

        currentDirection = normalizeVec(vec2(bestCoords.x - currentCoords.x, bestCoords.y - currentCoords.y))
        currentCoords = bestCoords
        points[#points + 1] = bestCoords
    end

    return points
end

local function chooseFrontRoadPoint(playerCoords, playerHeading, roadPaths, mapDistance, minimumDistance)
    local forward = normalizeVec(headingToVec(playerHeading))
    local bestCoords
    local bestPath
    local bestScore

    for _, path in ipairs(roadPaths) do
        for _, coords in ipairs(path) do
            local offsetX = coords.x - playerCoords.x
            local offsetY = coords.y - playerCoords.y
            local forwardDistance = (offsetX * forward.x) + (offsetY * forward.y)
            local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

            if forwardDistance > 0.0 and distance >= minimumDistance then
                local score = math.abs(mapDistance - distance)
                if not bestScore or score < bestScore then
                    bestCoords = coords
                    bestPath = path
                    bestScore = score
                end
            end
        end
    end

    return bestCoords, bestPath
end

function GetRoadFailSpawnPoint(playerCoords, playerHeading, useMountedDistance)
    if not playerCoords then return nil end

    local roadConfig = Config and Config.RoadSpawn or {}
    local failConfig = roadConfig.RoadFail or {}
    local mapDistance, nodeDistance = getSpawnDistances(useMountedDistance)
    local minimumDistance = mapDistance * 0.5
    local gridSize = math.max(1, math.floor(tonumber(failConfig.GridSize) or 5))
    local gridGap = tonumber(failConfig.GridGap) or 5

    if gridGap <= 0 then gridGap = 5 end

    local forward = normalizeVec(headingToVec(playerHeading or 0.0))
    local right = vec2(forward.y, -forward.x)
    local centerOffset = (gridSize - 1) / 2
    local bestCoords
    local bestScore
    local gridPoints = {}

    for searchDistance = mapDistance, minimumDistance, -nodeDistance do
        for row = 0, gridSize - 1 do
            local forwardOffset = (row - centerOffset) * gridGap

            for column = 0, gridSize - 1 do
                local sideOffset = (column - centerOffset) * gridGap
                local distanceAhead = searchDistance + forwardOffset
                local x = playerCoords.x + (forward.x * distanceAhead) + (right.x * sideOffset)
                local y = playerCoords.y + (forward.y * distanceAhead) + (right.y * sideOffset)
                local coords = getGroundCoords(x, y, playerCoords.z)
                local offsetX = coords.x - playerCoords.x
                local offsetY = coords.y - playerCoords.y
                local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

                gridPoints[#gridPoints + 1] = coords

                if distance >= minimumDistance and IsPointOnRoad(coords.x, coords.y, coords.z, 0) then
                    local score = math.abs(mapDistance - distance)
                    if not bestScore or score < bestScore then
                        bestCoords = coords
                        bestScore = score
                    end
                end
            end
        end
    end

    if not bestCoords then
        roadSpawnLog(("Road fallback found no road point in front of the player after checking %d points."):format(#gridPoints))
        return nil
    end

    roadSpawnLog(("Road fallback selected a point %.1fm in front of the player."):format(#(playerCoords - bestCoords)))

    return {
        coords = bestCoords,
        heading = playerHeading or 0.0,
        onRoad = true,
        points = gridPoints
    }
end

function GetRoadAmbushSpawnPoint(playerCoords, playerHeading, useMountedDistance)
    if not playerCoords then return nil end

    local mapDistance, roadNodeDistance = getSpawnDistances(useMountedDistance)
    local minimumDistance = mapDistance * 0.5
    local foundRoadStart, roadStartCoords, roadStartHeading = GetClosestVehicleNodeWithHeading(
        playerCoords.x,
        playerCoords.y,
        playerCoords.z,
        0,
        3.0,
        0
    )

    if not foundRoadStart or not roadStartCoords or type(roadStartHeading) ~= "number" then
        roadSpawnLog("No nearby vehicle road node was found.")
        return nil
    end

    local traceDistance = mapDistance + roadNodeDistance
    local roadPaths = {
        traceRoadPath(roadStartCoords, roadStartHeading, traceDistance, roadNodeDistance),
        traceRoadPath(roadStartCoords, (roadStartHeading + 180.0) % 360.0, traceDistance, roadNodeDistance)
    }
    local targetCoords, chosenPath = chooseFrontRoadPoint(
        playerCoords,
        playerHeading or 0.0,
        roadPaths,
        mapDistance,
        minimumDistance
    )

    if not targetCoords then
        roadSpawnLog("Road traces found no valid point in front of the player.")
        return nil
    end

    roadSpawnLog(("Road trace selected a point %.1fm in front of the player."):format(#(playerCoords - targetCoords)))

    return {
        coords = targetCoords,
        heading = playerHeading or 0.0,
        points = chosenPath
    }
end
