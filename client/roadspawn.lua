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
    local maxSteps = math.max(1, math.ceil(totalDistance / nodeDistance) * 2)
    local currentCoords = originCoords
    local currentDirection = normalizeVec(headingToVec(startHeading))
    local tracedDistance = 0.0
    local points = {}

    for _ = 1, maxSteps do
        local bestCoords
        local bestDirection
        local bestScore
        local desiredX = currentCoords.x + (currentDirection.x * nodeDistance)
        local desiredY = currentCoords.y + (currentDirection.y * nodeDistance)

        for nthClosest = 1, 8 do
            local foundNode, nodeCoords, nodeHeading = GetNthClosestVehicleNodeFavourDirection(
                currentCoords.x,
                currentCoords.y,
                currentCoords.z,
                desiredX,
                desiredY,
                currentCoords.z,
                nthClosest,
                0,
                3.0,
                0
            )

            if foundNode and nodeCoords and type(nodeHeading) == "number" then
                local stepX = nodeCoords.x - currentCoords.x
                local stepY = nodeCoords.y - currentCoords.y
                local stepDistance = math.sqrt((stepX * stepX) + (stepY * stepY))
                local travelDirection = normalizeVec(vec2(stepX, stepY))
                local forwardDot = (currentDirection.x * travelDirection.x) + (currentDirection.y * travelDirection.y)
                local nodeDirection = normalizeVec(headingToVec(nodeHeading))
                local nodeHeadingDot = (currentDirection.x * nodeDirection.x) + (currentDirection.y * nodeDirection.y)
                local alreadyUsed = false

                if nodeHeadingDot < 0.0 then
                    nodeDirection = vec2(-nodeDirection.x, -nodeDirection.y)
                    nodeHeadingDot = -nodeHeadingDot
                end

                for index = math.max(1, #points - 4), #points do
                    local usedX = nodeCoords.x - points[index].x
                    local usedY = nodeCoords.y - points[index].y
                    if math.sqrt((usedX * usedX) + (usedY * usedY)) < 2.0 then
                        alreadyUsed = true
                        break
                    end
                end

                if not alreadyUsed and stepDistance >= 5.0 and stepDistance <= 35.0 and forwardDot > 0.0 then
                    local turnAmount = math.deg(math.acos(math.max(-1.0, math.min(1.0, forwardDot))))
                    local headingTurn = math.deg(math.acos(math.max(-1.0, math.min(1.0, nodeHeadingDot))))
                    local score = turnAmount + headingTurn + math.abs(nodeDistance - stepDistance)

                    if not bestScore or score < bestScore then
                        bestCoords = nodeCoords
                        bestDirection = nodeDirection
                        bestScore = score
                    end
                end
            end
        end

        if not bestCoords then break end

        local stepX = bestCoords.x - currentCoords.x
        local stepY = bestCoords.y - currentCoords.y
        tracedDistance = tracedDistance + math.sqrt((stepX * stepX) + (stepY * stepY))
        currentDirection = bestDirection
        currentCoords = bestCoords
        points[#points + 1] = bestCoords

        if tracedDistance >= totalDistance then break end
    end

    return points
end

local function getNextRoadPoint(coords, heading)
    local distance = Config.AmbushVariations.WagonEnemyBehindDistance
    local points = traceRoadPath(coords, heading, distance, distance)

    return points[1]
end

local function chooseFrontRoadPoint(playerCoords, playerHeading, roadPaths, mapDistance, minimumDistance)
    local forward = normalizeVec(headingToVec(playerHeading))
    local bestCoords
    local bestPath
    local bestIndex
    local bestScore

    for _, path in ipairs(roadPaths) do
        for index, coords in ipairs(path) do
            local offsetX = coords.x - playerCoords.x
            local offsetY = coords.y - playerCoords.y
            local forwardDistance = (offsetX * forward.x) + (offsetY * forward.y)
            local distance = math.sqrt((offsetX * offsetX) + (offsetY * offsetY))

            if forwardDistance > 0.0 and distance >= minimumDistance then
                local score = math.abs(mapDistance - distance)
                if not bestScore or score < bestScore then
                    bestCoords = coords
                    bestPath = path
                    bestIndex = index
                    bestScore = score
                end
            end
        end
    end

    return bestCoords, bestPath, bestIndex
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

    local foundRoadNode, _, roadHeading = GetClosestVehicleNodeWithHeading(
        bestCoords.x,
        bestCoords.y,
        bestCoords.z,
        0,
        3.0,
        0
    )
    local behindCoords = getNextRoadPoint(bestCoords, playerHeading or roadHeading or 0.0)

    return {
        coords = bestCoords,
        heading = foundRoadNode and roadHeading or playerHeading or 0.0,
        behindCoords = behindCoords,
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
    local targetCoords, chosenPath, targetIndex = chooseFrontRoadPoint(
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

    local roadHeading = playerHeading or 0.0
    local nextRoadPoint = chosenPath and (chosenPath[targetIndex + 1] or chosenPath[targetIndex - 1])
    if nextRoadPoint then
        local roadX = nextRoadPoint.x - targetCoords.x
        local roadY = nextRoadPoint.y - targetCoords.y
        roadHeading = math.deg(math.atan(-roadX, roadY)) % 360.0
    end
    local behindCoords = getNextRoadPoint(targetCoords, roadHeading)

    roadSpawnLog(("Road trace selected a point %.1fm in front of the player."):format(#(playerCoords - targetCoords)))

    return {
        coords = targetCoords,
        heading = roadHeading,
        behindCoords = behindCoords,
        points = chosenPath
    }
end
