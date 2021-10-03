require "/scripts/vec2.lua"
require "/interface/navigationtools/markers.lua"
require "/interface/navigationtools/buttons.lua"


MAX_PROBE_HEIGHT = 1400
MIN_PROBE_HEIGHT = 600

CENTRE = {47.5, 58.5}
MAX_RADIUS = 44
MIN_RADIUS = 10
COLOUR_GROUND = {81,217,81,255}
COLOUR_UNKNOWN = {33,68,33,255}
COLOUR_LIQUID = {0,72,255,255}

BUTTON_POSITIONS = {
	blueMarker = {10, 0},
	greenMarker = {30, 0},
	redMarker = {50, 0},
	deleteMarker = {70, 0},
}


function init()
	canvas = widget.bindCanvas("canvas")
	timeToNextLoad = 0
	deleteMode = false
	markers.load()
	buttons.addStandardButtons(BUTTON_POSITIONS, addMarkerAndOpenRenameDialog, function() deleteMode = not deleteMode end)
end


function update(dt)
	-- Close when teleporting out to avoid stack overflow, player entity will reopen when teleport is finished
	startedTeleporting = status.statusProperty("navigation_tools_teleporting") or false

	if startedTeleporting then
		pane.dismiss()
		return
	end

	canvas:clear()
	timeToNextLoad = timeToNextLoad - dt
	if timeToNextLoad <= 0 then
		loadSurfaceMap()
		timeToNextLoad = 1.0
	end

	if not world.terrestrial() then
		canvas:drawText("???", {position={41, 62}}, 8, COLOUR_GROUND)
	end

	local worldWidth = world.size()[1]
	local playerPos = getPlayerPos()
	if surfaceMap then
		drawWorld(playerPos, worldWidth)
	else
		drawUnknownWorld()
	end
	currentToolTipText = nil
	local mousePos = canvas:mousePosition()
	buttons.updateHighlight(canvas, mousePos, showTooltipDelayed)
	if deleteMode then
		drawDeleteCursor(mousePos)
	end
	drawPlayer(playerPos, worldWidth)
	drawMarkers(playerPos, worldWidth)
	if currentToolTipText then
		showTooltip(currentToolTipText)
	end
end


function loadSurfaceMap()
	local newVersion = world.getProperty("navigation_tools_surfacemap_version")
	if newVersion ~= surfaceMapVersion then
		sb.logInfo("Loaded surface map")
		surfaceMap = world.getProperty("navigation_tools_surfacemap")
		surfaceMapVersion = newVersion
	end
end


function drawWorld(playerPos, worldWidth)
	local ground = surfaceMap.ground
	local stepSize = worldWidth / #ground

	-- solid ground
	local previousPointHeight = ground[#ground]
	local previousPoint = calculateDrawPos({-1 * stepSize, previousPointHeight > 0 and previousPointHeight or MIN_PROBE_HEIGHT}, playerPos[1], worldWidth)
	local thisPointHeight = nil
	local thisPointPos = nil
	for i = 1, #ground do
		thisPointHeight = ground[i]
		thisPoint = calculateDrawPos({(i - 1) * stepSize, thisPointHeight > 0 and thisPointHeight or MIN_PROBE_HEIGHT}, playerPos[1], worldWidth)
		if thisPointHeight < 0 and previousPointHeight < 0 then
			canvas:drawLine(previousPoint, thisPoint, COLOUR_UNKNOWN, 2)
		elseif thisPointHeight >= 0 and previousPointHeight >= 0 then
			canvas:drawLine(previousPoint, thisPoint, COLOUR_GROUND, 2)
		end
		previousPointHeight = thisPointHeight
		previousPoint = thisPoint
	end

	-- liquid
	local liquid = surfaceMap.liquid
	previousPointHeight = liquid[#liquid]
	previousPoint = calculateDrawPos({-1 * stepSize, previousPointHeight}, playerPos[1], worldWidth)
	for i = 1, #liquid do
		thisPointHeight = liquid[i]
		thisPoint = calculateDrawPos({(i - 1) * stepSize, thisPointHeight}, playerPos[1], worldWidth)
		if thisPointHeight >= 0 and previousPointHeight >= 0 then
			canvas:drawLine(previousPoint, thisPoint, COLOUR_LIQUID, 2)
		end
		previousPointHeight = thisPointHeight
		previousPoint = thisPoint
	end
end


function drawUnknownWorld()
	local resolution = 200
	for i = 1, resolution do
		local thisPoint = calculateDrawPos({i - 1, MIN_PROBE_HEIGHT}, 0, resolution)
		local nextPoint = calculateDrawPos({i, MIN_PROBE_HEIGHT}, 0, resolution)
		canvas:drawLine(thisPoint, nextPoint, COLOUR_UNKNOWN, 2)
	end
end


function drawPlayer(playerPos, worldWidth)
	local playerDrawPos = calculateDrawPos(playerPos, playerPos[1], worldWidth)
	markers.drawAtPosWithColour(canvas, playerDrawPos, 'purple')
	local mousePos = canvas:mousePosition()
	local diff = vec2.sub(playerDrawPos, mousePos)
	local dist = vec2.dot(diff, diff)
	if dist < 16 then
		showTooltipDelayed("Player")
	end
end

function drawMarkers(playerPos, worldWidth)
	markers.drawMarkers(
		canvas,
		function (markerPos)
			return calculateDrawPos(markerPos, playerPos[1], worldWidth)
		end,
		showTooltipDelayed,
		function (markerPos)
			showDistance(world.magnitude(markerPos, playerPos))
		end
	)
end


function calculateDrawPos(worldPos, referenceX, worldWidth)
	local angle = 2 * math.pi * (worldPos[1] - referenceX) / worldWidth
	local radius = math.min(worldPos[2] / MAX_PROBE_HEIGHT * MAX_RADIUS, MAX_RADIUS)
	local x = math.floor(math.sin(angle) * radius + .5)
	local y = math.floor(math.cos(angle) * radius + .5)
	return vec2.add({x, y}, CENTRE)
end


function getMarkerIdNearCursor(cursorPos)
	local worldWidth = world.size()[1]
	local playerX = getPlayerPos()[1]
	return markers.getMarkerIdNearPosition(
		cursorPos,
		function (markerPos)
			return calculateDrawPos(markerPos, playerX, worldWidth)
		end
	)
end


function getPlayerPos()
	return world.entityPosition(pane.sourceEntity())
end

-- callback to set the current tooltip, so we only show one tooltip at a time (latest wins)
function showTooltipDelayed(text)
	currentToolTipText = text
end

function showTooltip(text)
	canvas:drawText(text, {position={4, 23}}, 8, COLOUR_GROUND)
end


function showDistance(distance)
	canvas:drawText(string.format("%d", math.floor(distance)), {position={90, 23}, horizontalAnchor="right"}, 8, COLOUR_GROUND)
end


function drawDeleteCursor(mousePos)
	canvas:drawImage("/interface/navigationtools/delete_cursor.png", mousePos, 1, nil, true)
end


function addMarkerAndOpenRenameDialog(markerColour, defaultLabel)
	local newMarkerId = markers.add(getPlayerPos(), markerColour, defaultLabel)
	openRenameDialog(newMarkerId)
end


function openRenameDialog(markerId)
	world.sendEntityMessage(config.getParameter("ownerId"), "RenameMarker", {markerId = markerId, initialName = ""})
end


function canvasClickEvent(position, button, isButtonDown)
	if isButtonDown then
		if button == 0 then
			if deleteMode then
				local markerIdToDelete = getMarkerIdNearCursor(position)
				if markerIdToDelete then
					markers.delete(markerIdToDelete)
					deleteMode = false
				end
			end

			buttons.handleClick(position)
		else
			deleteMode = false
		end
	end
end


function dismissed()
	--sb.logInfo("Dismissed")
	world.sendEntityMessage(config.getParameter("ownerId"), "SurfaceMapperClosed")
end
