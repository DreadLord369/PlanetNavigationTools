--require "/interface/navigationtools/debug.lua"
require "/scripts/vec2.lua"

MAX_PROBE_HEIGHT = 1400
MIN_PROBE_HEIGHT = 600
RESOLUTION = 200

TOO_LOW_HEIGHT = -1
UNKNOWN_HEIGHT = -2

function init()
	self.surfaceMapOpen = false
	message.setHandler("SurfaceMapperClosed", function(...)
		self.surfaceMapOpen = false
	end)
	message.setHandler("RenameMarker", function(_, _, renameArgs)
		openRenameDialog(renameArgs.markerId, renameArgs.initialName)
	end)

	-- don't read properties in init, seems like they sometimes are not loaded yet
	--loadSurfaceMap()
	surfaceMapLoaded = false
	surfaceMapUpdated = false
	surfaceMapVersion = 1
	timeToNextStore = 1.0
	lastProbedPosition = {-1, -1}

	--debug.timeGetSetProperty("map", surfaceMap)
	--debug.timeGetSetProperty("int", 456)
	--debug.timeGetSetProperty("string", "a short string")
	--debug.timeGetSetProperty("res100", emptyHeightMap(100))
	--debug.timeGetSetProperty("res1000", emptyHeightMap(1000))
end

function activate(fireMode, shiftHeld)
	if fireMode == "primary" and not self.surfaceMapOpen then
		openSurfaceMap()
		self.surfaceMapOpen = true
	end
end

function openSurfaceMap()
	status.setStatusProperty("navigation_tools_teleporting", false)
	local configData = root.assetJson("/interface/navigationtools/surfacemapgui.config")
	configData.ownerId = activeItem.ownerEntityId()
	activeItem.interact("ScriptPane", configData, activeItem.ownerEntityId())
end


function openRenameDialog(markerId, initialName)
	local configData = root.assetJson("/interface/navigationtools/renamemarkergui.config")
	configData.markerId = markerId
	configData.initialName = initialName
	activeItem.interact("ScriptPane", configData, activeItem.ownerEntityId())
end


function update(dt, fireMode, shiftHeld)
	if not surfaceMapLoaded then
		loadSurfaceMap()
		surfaceMapLoaded = true
	end
	if not surfaceMap then
		return
	end
	local playerPosition = getPlayerPos()
	local worldWidth = world.size()[1]
	if isAtSurfaceLayerHeight(playerPosition[2]) and not vec2.eq(playerPosition, lastProbedPosition) then
		local closestIndex = getClosestIndex(playerPosition[1], worldWidth)
		probeAndUpdate(closestIndex, playerPosition[2], worldWidth)
		probeAndUpdate(closestIndex - 1, playerPosition[2], worldWidth)
		probeAndUpdate(closestIndex + 1, playerPosition[2], worldWidth)
		lastProbedPosition = playerPosition
	end

	if surfaceMapUpdated then
		timeToNextStore = timeToNextStore - dt
		if timeToNextStore <= 0 then
			timeToNextStore = 1.0
			storeSurfaceMap()
			surfaceMapUpdated = false
		end
	end
end


function uninit()

end


function loadSurfaceMap()
	surfaceMap = world.getProperty("navigation_tools_surfacemap")
	if not surfaceMap then
		if world.getProperty("navigation_tools_surfacemap_version") then
			sb.logInfo("Wanted to clobbber everything, %s", surfaceMap)
		else
			sb.logInfo("Made new map %s", surfaceMap)
			surfaceMap = {
				ground = emptyHeightMap(RESOLUTION),
				liquid = emptyHeightMap(RESOLUTION),
			}
		end
	end
end


function storeSurfaceMap()
	sb.logInfo("stored surface map")
	world.setProperty("navigation_tools_surfacemap", surfaceMap)
	surfaceMapVersion = surfaceMapVersion + 1
	world.setProperty("navigation_tools_surfacemap_version", surfaceMapVersion)
end


function emptyHeightMap(length)
	local t = {}
	for i = 1, length do
		t[i] = UNKNOWN_HEIGHT
	end
	return t
end


function getPlayerPos()
	return world.entityPosition(activeItem.ownerEntityId())
end


function probeAndUpdate(index, playerY, worldWidth)
	local x = xPosForIndex(index, worldWidth)
	local sh, lh = probeHeightAtPos({x, playerY})
	if sh ~= nil then
		updateSurfaceHeight(index, sh)
	end
	if lh ~= nil then
		updateLiquidHeight(index, lh)
	end
end

function updateSurfaceHeight(index, surfaceHeight)
	local index1 = (index % RESOLUTION) + 1
	if surfaceMap.ground[index1] ~= surfaceHeight then
		surfaceMap.ground[index1] = surfaceHeight
		surfaceMapUpdated = true
	end
end


function updateLiquidHeight(index, surfaceHeight)
	local index1 = (index % RESOLUTION) + 1
	if surfaceMap.liquid[index1] ~= surfaceHeight then
		surfaceMap.liquid[index1] = surfaceHeight
		surfaceMapUpdated = true
	end
end


function getClosestIndex(xPos, worldWidth)
	local index = math.floor(xPos / worldWidth * RESOLUTION + 0.5)
	if index < RESOLUTION then
		return index
	else
		return index - RESOLUTION
	end
end


function xPosForIndex(index, worldWidth)
	if index >= RESOLUTION then
		index = index - RESOLUTION
	elseif index < 0 then
		index = index + RESOLUTION
	end
	return math.floor(index * worldWidth / RESOLUTION + 0.5)
end


function isAtSurfaceLayerHeight(yPos)
	return MIN_PROBE_HEIGHT <= yPos and yPos <= MAX_PROBE_HEIGHT
end


function probeHeightAtPos(position)
	--if position[1] ~= world.xwrap(position[1]) then
		--sb.logInfo("Scanning abnormal position %s", position)
	--end
	-- assumes position is between MIN_PROBE_HEIGHT and MAX_PROBE_HEIGHT
	local collisionsUp = world.collisionBlocksAlongLine(position, {position[1],MAX_PROBE_HEIGHT}, {"Null", "Block"}, 1)
	--sb.logInfo("Checked up and found %s with %s", collisionsUp, #collisionsUp > 0 and world.material(collisionsUp[1], 'foreground'))
	if #collisionsUp == 1 and world.material(collisionsUp[1], 'foreground') then
		-- found a roof, not eligible for scan
		return nil, nil
	end

	local surfaceHeight = nil
	local collisionsDown = world.collisionBlocksAlongLine(position, {position[1],MIN_PROBE_HEIGHT}, {"Null", "Block"}, 1)
	if collisionsDown == 0 then
		-- Surface goes below minimum probe height
		surfaceHeight = TOO_LOW_HEIGHT
	elseif #collisionsDown == 1 and world.material(collisionsDown[1], 'foreground') ~= nil then
		surfaceHeight = collisionsDown[1][2]
	end

	local liquidHeight = nil
	if world.liquidAt(position) == nil then
		local liquidMinHeight = surfaceHeight or MIN_PROBE_HEIGHT
		local liquidsDown = world.liquidAlongLine(position, {position[1], liquidMinHeight})
		if #liquidsDown > 0 then
			liquidHeight = liquidsDown[1][1][2]
		elseif surfaceHeight then
			liquidHeight = TOO_LOW_HEIGHT
		end
	end
	--sb.logInfo("surface %s %s", surfaceHeight, liquidHeight)
	return surfaceHeight, liquidHeight
end
