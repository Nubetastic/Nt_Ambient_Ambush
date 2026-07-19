local RoadSpawn = {
    enabled = true
}

local function roadSpawnLog(message)
    if Config and Config.Debug then
        print(("[RoadSpawn] %s"):format(tostring(message)))
    end
end

local function vec2(x, y)
    return { x = x, y = y }
end

local function subVec(a, b)
    return vec2(a.x - b.x, a.y - b.y)
end

local function mulVec(a, scalar)
    return vec2(a.x * scalar, a.y * scalar)
end

local function lengthVec(a)
    return math.sqrt((a.x * a.x) + (a.y * a.y))
end

local function normalizeVec(a)
    local len = lengthVec(a)
    if len <= 0.0001 then
        return vec2(0.0, 0.0)
    end

    return vec2(a.x / len, a.y / len)
end

local function headingToVec(heading)
    local radians = math.rad(heading)
    return vec2(-math.sin(radians), math.cos(radians))
end

local function vecToCoords(baseCoords, offset)
    local groundFound, groundZ = GetGroundZFor_3dCoord(baseCoords.x + offset.x, baseCoords.y + offset.y, baseCoords.z + 50.0, false)
    return vector3(
        baseCoords.x + offset.x,
        baseCoords.y + offset.y,
        groundFound and groundZ or baseCoords.z
    )
end

local function isPointOnRoad(coords)
    return IsPointOnRoad(coords.x, coords.y, coords.z, 0)
end

local function getGroundCoords(x, y, fallbackZ)
    local groundFound, groundZ = GetGroundZFor_3dCoord(x, y, fallbackZ + 100.0, false)
    return vector3(x, y, groundFound and groundZ or fallbackZ)
end

function GetRoadFailSpawnPoint(playerCoords, playerHeading)
    if not playerCoords then
        return nil
    end

    local roadConfig = Config and Config.RoadSpawn or {}
    local failConfig = roadConfig.RoadFail or {}
    local mapDistance = tonumber(roadConfig.MountedMapDistance) or 300
    local gridSize = math.max(1, math.floor(tonumber(failConfig.GridSize) or 5))
    local gridGap = tonumber(failConfig.GridGap) or 5

    if gridGap <= 0 then
        gridGap = 5
    end

    local forward = normalizeVec(headingToVec(playerHeading or 0.0))
    local right = vec2(forward.y, -forward.x)
    local centerOffset = (gridSize - 1) / 2
    local gridPoints = {}
    local roadPoints = {}

    for row = 0, gridSize - 1 do
        local forwardOffset = (row - centerOffset) * gridGap

        for column = 0, gridSize - 1 do
            local sideOffset = (column - centerOffset) * gridGap
            local distanceAhead = mapDistance + forwardOffset
            local x = playerCoords.x + (forward.x * distanceAhead) + (right.x * sideOffset)
            local y = playerCoords.y + (forward.y * distanceAhead) + (right.y * sideOffset)
            local coords = getGroundCoords(x, y, playerCoords.z)

            gridPoints[#gridPoints + 1] = coords
            if isPointOnRoad(coords) then
                roadPoints[#roadPoints + 1] = coords
            end
        end
    end

    local candidates = #roadPoints > 0 and roadPoints or gridPoints
    if #candidates == 0 then
        roadSpawnLog("Road-fail grid did not generate any usable points.")
        return nil
    end

    local chosenCoords = candidates[math.random(1, #candidates)]
    roadSpawnLog(("Road-fail grid selected %s point from %d road and %d total points."):format(
        #roadPoints > 0 and "a road" or "an off-road",
        #roadPoints,
        #gridPoints
    ))

    return {
        coords = chosenCoords,
        heading = playerHeading or 0.0,
        onRoad = #roadPoints > 0,
        points = gridPoints
    }
end

local function traceForwardRoadPath(originCoords, startHeading, totalDistance, nodeDistance)
    local maxSteps = math.max(1, math.floor(totalDistance / nodeDistance))
    local searchArcDegrees = 90
    local arcStepDegrees = 10
    local points = {}

    local currentCoords = originCoords
    local currentDirection = normalizeVec(headingToVec(startHeading))

    for _ = 1, maxSteps do
        local bestCandidate = nil
        local bestScore = nil

        for angle = -searchArcDegrees, searchArcDegrees, arcStepDegrees do
            local radians = math.rad(angle)
            local rotatedDirection = vec2(
                (currentDirection.x * math.cos(radians)) - (currentDirection.y * math.sin(radians)),
                (currentDirection.x * math.sin(radians)) + (currentDirection.y * math.cos(radians))
            )

            local nextCoords = vecToCoords(currentCoords, mulVec(normalizeVec(rotatedDirection), nodeDistance))
            if isPointOnRoad(nextCoords) then
                local score = math.abs(angle)
                if not bestScore or score < bestScore then
                    bestScore = score
                    bestCandidate = nextCoords
                end
            end
        end

        if not bestCandidate then
            break
        end

        points[#points + 1] = bestCandidate
        currentDirection = normalizeVec(subVec(vec2(bestCandidate.x, bestCandidate.y), vec2(currentCoords.x, currentCoords.y)))
        currentCoords = bestCandidate
    end

    return points
end

local function tailPoints(points, count)
    local tail = {}
    local startIndex = math.max(1, #points - count + 1)

    for i = startIndex, #points do
        tail[#tail + 1] = points[i]
    end

    return tail
end

local function scorePointSets(setA, setB)
    local count = math.min(#setA, #setB)
    local total = 0.0

    for i = 1, count do
        local dx = setA[i].x - setB[i].x
        local dy = setA[i].y - setB[i].y
        total = total + math.sqrt((dx * dx) + (dy * dy))
    end

    return total
end

local function chooseBestSet(scanA, scanB, scanC)
    local scoreAB = scorePointSets(scanA, scanB)
    local scoreAC = scorePointSets(scanA, scanC)
    local scoreBC = scorePointSets(scanB, scanC)

    local bestScore = scoreAB
    local bestPair = { scanA, scanB }

    if scoreAC < bestScore then
        bestScore = scoreAC
        bestPair = { scanA, scanC }
    end

    if scoreBC < bestScore then
        bestScore = scoreBC
        bestPair = { scanB, scanC }
    end

    local chosen = bestPair[1]
    local other = bestPair[2]
    if #other > #chosen then
        chosen = other
    end

    return chosen, bestScore
end

function GetRoadAmbushSpawnPoint(playerCoords, playerHeading, useMountedDistance)
    if not playerCoords then
        return nil
    end

    local roadConfig = Config and Config.RoadSpawn or {}
    local mapDistance = nil
    if useMountedDistance then
        mapDistance = tonumber(roadConfig.MountedMapDistance)
    else
        mapDistance = tonumber(roadConfig.FootMapDistance)
    end
    mapDistance = mapDistance or tonumber(roadConfig.MountedMapDistance) or tonumber(roadConfig.FootMapDistance) or 300
    local roadNodeDistance = tonumber(roadConfig.RoadNodeDistance) or 20

    if not isPointOnRoad(playerCoords) then
        roadSpawnLog("Player is not on a road, no spawn point generated.")
        return nil
    end

    local lengths = {
        mapDistance + (2 * roadNodeDistance),
        mapDistance + roadNodeDistance,
        mapDistance
    }

    local scans = {}
    for i, distance in ipairs(lengths) do
        local path = traceForwardRoadPath(playerCoords, playerHeading, distance, roadNodeDistance)
        scans[i] = tailPoints(path, 5)
    end

    local chosenSet, bestScore = chooseBestSet(scans[1], scans[2], scans[3])
    if not chosenSet or #chosenSet == 0 then
        roadSpawnLog("No usable road set was found.")
        return nil
    end

    local targetCoords = chosenSet[#chosenSet]
    if not targetCoords then
        return nil
    end

    local previousCoords = chosenSet[#chosenSet - 1] or playerCoords
    local heading = GetHeadingFromVector_2d(
        targetCoords.x - previousCoords.x,
        targetCoords.y - previousCoords.y
    )

    return {
        coords = targetCoords,
        heading = heading,
        score = bestScore,
        points = chosenSet
    }
end
