require "/scripts/vec2.lua"

require "/interface/navigationtools/markers.lua"
require "/interface/navigationtools/buttons.lua"

RADIUS = 50
CENTRE = {52.5, 52.5}
BUTTON_POSITIONS = {
	blueMarker = {15, 40},
	greenMarker = {35, 40},
	redMarker = {55, 40},
	deleteMarker = {75, 40},
}


function init()
	--calibrationTimer = 0
	--sb.logInfo("sourceEntity pos %s", world.entityPosition(pane.sourceEntity()))
	canvas = widget.bindCanvas("canvas")

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
	-- Calibration helpers for checking the center is correct
	--calibrationTimer = calibrationTimer + dt
	--markers.drawAtPosWithColour(canvas, calculateMarkerDrawPos(calibrationTimer % 20, 0, 10), "white")
	--markers.drawAtPosWithColour(canvas, calculateMarkerDrawPos((calibrationTimer + 10) % 20, 0, 10), "white")

	local mousePos = canvas:mousePosition()
	buttons.updateHighlight(canvas, mousePos, showTooltip)
	if deleteMode then
		drawDeleteCursor(mousePos)
	end

	local worldWidth = world.size()[1]
	--sb.logInfo("worldwidth %s", worldWidth)
	local playerPos = getPlayerPos()
	drawAltitude(playerPos[2])
	drawMarkers(playerPos[1], worldWidth)
end


function getPlayerPos()
	return world.entityPosition(pane.sourceEntity())
end


function calculateMarkerDrawPos(xPos, referenceX, worldWidth)
	local angle = 2 * math.pi * (xPos - referenceX) / worldWidth
	local x = math.floor(math.sin(angle) * RADIUS + .5)
	local y = math.floor(math.cos(angle) * RADIUS + .5)
	return vec2.add({x, y}, CENTRE)
end


function drawAltitude(altitude)
	local format = "%d"
	if not world.terrestrial() then
		format = "%d?"
	end
	canvas:drawText(string.format(format, math.floor(altitude)), {position={70,81}, horizontalAnchor="right"}, 16, {255, 255, 255, 255})
end


function drawMarkers(playerX, worldWidth)
	markers.drawMarkers(
		canvas,
		function (markerPos)
			return calculateMarkerDrawPos(markerPos[1], playerX, worldWidth)
		end,
		showTooltip,
		function (markerPos)
			-- the compass only shows horizontal distance
			showDistance(world.magnitude({markerPos[1], 0}, {playerX, 0}))
		end
	)
end


function getMarkerIdNearCursor(cursorPos)
	local worldWidth = world.size()[1]
	local playerX = getPlayerPos()[1]
	return markers.getMarkerIdNearPosition(
		cursorPos,
		function (markerPos)
			return calculateMarkerDrawPos(markerPos[1], playerX, worldWidth)
		end
	)
end


function addMarkerAndOpenRenameDialog(markerColour, defaultLabel)
	local newMarkerId = markers.add(getPlayerPos(), markerColour, defaultLabel)
	openRenameDialog(newMarkerId)
end


function drawDeleteCursor(mousePos)
	canvas:drawImage("/interface/navigationtools/delete_cursor.png", mousePos, 1, nil, true)
end


function showTooltip(text)
	canvas:drawText(text, {position={16,38}}, 8, {255, 255, 255, 255})
end


function showDistance(distance)
	canvas:drawText(string.format("%d", math.floor(distance)), {position={62,28}, horizontalAnchor="right"}, 8, {50, 50, 50, 255})
end


function openRenameDialog(markerId)
	world.sendEntityMessage(config.getParameter("ownerId"), "RenameMarker", {markerId = markerId, initialName = ""})
end


-- Canvas callbacks

function canvasClickEvent(position, button, isButtonDown)
	if isButtonDown then
		--sb.logInfo("Button %s was pressed at %s", button, position)
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
	else
		--sb.logInfo("Button %s was released at %s", button, position)
	end
end


function dismissed()
	--sb.logInfo("Dismissed")
	world.sendEntityMessage(config.getParameter("ownerId"), "SurveyCompassClosed")
end
