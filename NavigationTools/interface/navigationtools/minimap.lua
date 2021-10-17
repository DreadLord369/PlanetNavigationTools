require "/scripts/vec2.lua"
require "/interface/navigationtools/markers.lua"
require "/scripts/navigationtools/minimap.lua"
require "/interface/navigationtools/buttons.lua"
require "/interface/navigationtools/tilestore.lua"

-- COLOURS = {
-- 	[TileStore.tileTypes.UNKNOWN] = {0, 0, 0, 255},
-- 	[TileStore.tileTypes.NOTHING] = {233, 255, 255, 255},
-- 	[TileStore.tileTypes.SOLID] = {215, 216, 219, 255},
-- 	[TileStore.tileTypes.BACKGROUND] = {102, 109, 121, 255},
-- 	[TileStore.tileTypes.LIQUID] = {37, 84, 162, 255},
-- }

local playerPosition

local teleporting = false
local resizing = false

function init()
	canvas = widget.bindCanvas("canvas")
	mapColors = config.getParameter("mapColors")
	COLOURS = {
		[TileStore.tileTypes.UNKNOWN] = mapColors.unknown,
		[TileStore.tileTypes.NOTHING] = mapColors.nothing,
		[TileStore.tileTypes.SOLID] = mapColors.solid,
		[TileStore.tileTypes.BACKGROUND] = mapColors.background,
		[TileStore.tileTypes.LIQUID] = mapColors.liquid,
	}
	MAP_REGION = config.getParameter("mapRegion")
	BUTTON_POSITIONS = config.getParameter("buttonPositions")
	TOOLTIP_POSITION = config.getParameter("tooltipPosition")
	DISTANCE_POSITION = config.getParameter("distancePosition")
	TOOLTIP_COLOUR = config.getParameter("tooltipColor")
	LOCK_ON_PLAYER = config.getParameter("lockOnPlayer")

	teleporting = false

	resizing = false

	currentMapPos = getRoundedPlayerPos()
	timeToNextLoad = 0.5
	deleteMode = false
	dragMode = false
	lastDragPos = nil
	tileStore = TileStore:new()
	markers.load()
	buttons.addStandardButtons(BUTTON_POSITIONS, addMarkerAndOpenRenameDialog, function() deleteMode = not deleteMode end)
	if BUTTON_POSITIONS.expandScreen then
		buttons.addButton(BUTTON_POSITIONS.expandScreen, "Expand", function()
			resizing = true
			world.sendEntityMessage(player.id(), "ExpandMiniMap")
			pane.dismiss()
		end)
	end
	if BUTTON_POSITIONS.contractScreen then
		buttons.addButton(BUTTON_POSITIONS.contractScreen, "Collapse", function()
			resizing = true
			world.sendEntityMessage(player.id(), "ContractMiniMap")
			pane.dismiss()
		end)
	end
	if BUTTON_POSITIONS.clearMap then
		buttons.addButton(BUTTON_POSITIONS.clearMap, "Clear map data", function()
			world.sendEntityMessage(player.id(), "ClearMiniMap")
		end)
	end
	if BUTTON_POSITIONS.clearDeaths then
		buttons.addButton(BUTTON_POSITIONS.clearDeaths, "Clear world deaths", function()
			world.sendEntityMessage(player.id(), "ClearDeathMarkers")
		end)
	end

	-- Let player entity know which mode to re-open after teleporting
	if BUTTON_POSITIONS.expandScreen then
		player.setProperty("navigation_tools_minimap_state", "small")
	elseif BUTTON_POSITIONS.contractScreen then
		player.setProperty("navigation_tools_minimap_state", "large")
	end
end

function update(dt)
	canvas:clear()

	-- Close when teleporting out to avoid stack overflow, player entity will reopen when teleport is finished
	teleporting = status.statusProperty("navigation_tools_teleporting") or false

	if teleporting then
		-- sb.logInfo("#*#*#*#* minimap: teleporting *#*#*#*#")
		pane.dismiss()
		return
	end

	local hp = status.resource("health")
	if hp <= 0 then
		-- sb.logInfo("#*#*#*#* minimap: player died - health = " .. hp .. " *#*#*#*#")
		status.setStatusProperty("navigation_tools_teleporting", true)
		if playerPosition then
			-- sb.logInfo("#*#*#*#* minimap: player position is known *#*#*#*#")
			-- world.sendEntityMessage(player.id(), "AddDeathMarker", playerPosition) -- doesn't seem to work
			minimap.addDeathMarker(playerPosition)
		else
			-- sb.logInfo("#*#*#*#* minimap: player position is unknown *#*#*#*#")
		end
		return
	end

	-- sb.logInfo("#*#*#*#* minimap: Running *#*#*#*#")

	local mousePos = canvas:mousePosition()
	local worldSize = world.size()
	local roundedPlayerPos = getRoundedPlayerPos()
	if roundedPlayerPos == nil then
		-- sb.logInfo("#*#*#*#* minimap: couldn't find player pos *#*#*#*#")
		status.setStatusProperty("navigation_tools_teleporting", true)
		return
	end

	timeToNextLoad = timeToNextLoad - dt
	if timeToNextLoad <= 0 then
		markers.load()
		tileStore:reloadTiles()
		timeToNextLoad = 0.5
	end

	if LOCK_ON_PLAYER then
		currentMapPos = roundedPlayerPos
	elseif dragMode and mousePos[1] > 0 then
		currentMapPos = vec2.add(currentMapPos, vec2.sub(lastDragPos, mousePos))
		lastDragPos = mousePos
	end
	local leftBottomCornerWorldPos = borderPosFromCenter(MAP_REGION, currentMapPos)
	drawMap(MAP_REGION, leftBottomCornerWorldPos)
	currentToolTipText = nil
	currentToolTipDistance = nil
	buttons.updateHighlight(canvas, mousePos, showTooltipDelayed)
	if deleteMode then
		drawDeleteCursor(mousePos)
	end
	drawPlayer(roundedPlayerPos, currentMapPos, MAP_REGION, worldSize)
	drawMarkers(currentMapPos, MAP_REGION, worldSize)
	if currentToolTipText then
		showTooltip(currentToolTipText)
	end
	if currentToolTipDistance then
		showDistance(currentToolTipDistance)
	end
end

-- Calculate the world position at the borders to center a position in the rectangle
-- x might be negative here
function borderPosFromCenter(uiRect, centerWorldPos)
	local mapWidth = uiRect[3] - uiRect[1]
	local mapHeight = uiRect[4] - uiRect[2]
	local leftWorldX = centerWorldPos[1] - (mapWidth >> 1)
	local bottomWorldY = centerWorldPos[2] - (mapHeight >> 1)
	return {leftWorldX, bottomWorldY}
end

function drawMap(uiRect, leftBottomCornerWorldPos)
	local mapWidth = uiRect[3] - uiRect[1]
	local mapHeight = uiRect[4] - uiRect[2]
	local worldWidth = world.size()[1]
	for i = 0, mapHeight - 1 do
		drawMapRow(uiRect[1], uiRect[2] + i, mapWidth, world.xwrap(leftBottomCornerWorldPos[1]), leftBottomCornerWorldPos[2] + i, worldWidth)
	end
end

function drawMapRow(uiX, uiY, length, worldX, worldY, worldWidth)
	--sb.logInfo("pp %s", getPlayerPos())
	--sb.logInfo("dr %s, %s, %s, %s, %s, %s", uiX, uiY, length, worldX, worldY, worldWidth)
	local block, blocki, nvalid = tileStore:getRowArray(worldX & ~7, worldY)
	local tiles8 = (block[blocki] or 0) >> ((worldX & 7) << 3)
	local tiles8left = 8 - (worldX & 7)
	local lineStart = {uiX, uiY}
	local lineValue = tiles8 & 255

	for i = uiX, uiX + length - 1 do
		local value = tiles8 & 255
		if value ~= lineValue then
			-- draw old line and start new
			canvas:drawLine(lineStart, {i, uiY}, COLOURS[lineValue], 2)
			lineStart = {i, uiY}
			lineValue = value
		end
		tiles8left = tiles8left - 1
		worldX = worldX + 1
		if worldX == worldWidth then
			-- force reload when the world wraps
			worldX = 0
			tiles8left = 0
			nvalid = 1
		end
		if tiles8left == 0 then
			nvalid = nvalid - 1
			if nvalid == 0 then
				-- worldX should be 8 divisible here
				block, blocki, nvalid = tileStore:getRowArray(worldX, worldY)
			else
				blocki = blocki + 1
			end
			tiles8 = block[blocki] or 0
			--sb.logInfo("nt %s %s %s", blocki, nvalid, tiles8)
			tiles8left = 8
		else
			tiles8 = tiles8 >> 8
		end
	end
	-- Draw final line
	canvas:drawLine(lineStart, {uiX + length, uiY}, COLOURS[lineValue], 2)
end

function drawPlayer(playerPos, referencePos, uiRect, worldSize)
	local playerDrawPos = calculateDrawPos(playerPos, referencePos, uiRect, worldSize)
	markers.drawAtPosWithColour(canvas, playerDrawPos, 'purple')
	local mousePos = canvas:mousePosition()
	local diff = vec2.sub(playerDrawPos, mousePos)
	local dist = vec2.dot(diff, diff)
	if dist < 16 then
		showTooltipDelayed("Player")
	end
end


function drawMarkers(referencePos, uiRect, worldSize)
	markers.drawMarkers(
		canvas,
		function (markerPos)
			return calculateDrawPos(markerPos, referencePos, uiRect, worldSize)
		end,
		showTooltipDelayed,
		function (markerPos)
			showDistanceDelayed(world.magnitude(markerPos, getPlayerPos()))
		end
	)
end

function calculateDrawPos(worldPos, referencePos, uiRect, worldSize)
	local halfWorldWidth = worldSize[1] >> 1
	-- relative x-pos in [-worldWidth/2, worldWidth/2]
	-- sb.logInfo("nil: " .. tostring(worldPos == nil))
	local relativeXPos = (worldPos[1] - referencePos[1] + halfWorldWidth) % worldSize[1] - halfWorldWidth
	local relativeYPos = worldPos[2] - referencePos[2]
	local centerX = uiRect[1] + ((uiRect[3] - uiRect[1]) >> 1)
	local centerY = uiRect[2] + ((uiRect[4] - uiRect[2]) >> 1)
	return {
		math.max(uiRect[1], math.min(uiRect[3], centerX + relativeXPos)),
		math.max(uiRect[2], math.min(uiRect[4], centerY + relativeYPos)),
	}
end

function getMarkerIdNearCursor(cursorPos)
	local worldSize = world.size()
	return markers.getMarkerIdNearPosition(
		cursorPos,
		function (markerPos)
			return calculateDrawPos(markerPos, currentMapPos, MAP_REGION, worldSize)
		end
	)
end

function getPlayerPos()
	newPlayerPosition = world.entityPosition(player.id())
	playerPosition = newPlayerPosition or playerPosition -- hold onto this for when we die (this is called every update)
	return newPlayerPosition
end

function getRoundedPlayerPos()
	local playerPos = getPlayerPos()
	if playerPos ~= nil then
		return {math.floor(playerPos[1] + 0.5), math.floor(playerPos[2] + 0.5)}
	else
		return nil
	end
end

-- callback to set the current tooltip, so we only show one tooltip at a time (latest wins)
function showTooltipDelayed(text)
	currentToolTipText = text
end

function showTooltip(text)
	canvas:drawRect({21, 1, 120, 12}, {0, 0, 0, 128})
	canvas:drawText(text, {position=TOOLTIP_POSITION}, 8, TOOLTIP_COLOUR)
end

function showDistanceDelayed(distance)
	currentToolTipDistance = distance
end

function showDistance(distance)
	canvas:drawText(string.format("%d", math.floor(distance)), {position=DISTANCE_POSITION, horizontalAnchor="right"}, 8, TOOLTIP_COLOUR)
end

function drawDeleteCursor(mousePos)
	canvas:drawImage("/interface/navigationtools/delete_cursor.png", mousePos, 1, nil, true)
end

function addMarkerAndOpenRenameDialog(markerColour, defaultLabel)
	local newMarkerId = markers.add(getPlayerPos(), markerColour, defaultLabel)
	openRenameDialog(newMarkerId)
end

function openRenameDialog(markerId)
	world.sendEntityMessage(player.id(), "RenameMarker", {markerId = markerId, initialName = ""})
end

function canvasClickEvent(position, button, isButtonDown)
	if isButtonDown then
		if button == 0 then
			if deleteMode then
				local markerIdToDelete = getMarkerIdNearCursor(position)
				if markerIdToDelete then
					markers.delete(markerIdToDelete)
				end
			end

			buttons.handleClick(position)

			if position[1] >= MAP_REGION[1] and position[1] <= MAP_REGION[3] and position[2] >= MAP_REGION[2] and position[2] <= MAP_REGION[4] then
				dragMode = true
				lastDragPos = position
			end
		else
			deleteMode = false
		end
	else
		dragMode = false
	end
end

function dismissed()
	if not resizing and not teleporting and player.getProperty("navigation_tools_minimap_state") ~= "large" then
		player.setProperty("navigation_tools_minimap_state", "closed")
	elseif not resizing and not teleporting and player.getProperty("navigation_tools_minimap_state") == "large" then
		world.sendEntityMessage(player.id(), "ContractMiniMap")
	end
end
