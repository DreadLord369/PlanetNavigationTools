markers = {}

local yearSeconds = 60 * 60 * 24 * 365
local daySeconds = 60 * 60 * 24
local hourSeconds = 60 * 60
local minuteSeconds = 60

markers.MARKER_IMAGES = {
	blue = "/interface/navigationtools/marker_blue.png",
	green = "/interface/navigationtools/marker_green.png",
	red = "/interface/navigationtools/marker_red.png",
	yellow = "/interface/navigationtools/marker_yellow.png",
	white = "/interface/navigationtools/marker_white.png",
	purple = "/interface/navigationtools/marker_purple.png",
	death = "/interface/navigationtools/tombstone_marker.png"
}

-- Load markers from world
function markers.load()
	markers.markers = world.getProperty("navigation_tools_markers") or {}
end


-- Load markers to world
function markers.store()
	world.setProperty("navigation_tools_markers", markers.markers)
end


-- Add a marker and return the new marker id
function markers.add(markerPos, colour, label)
	markers.load()
	local mid = sb.makeUuid()
	markers.markers[mid] = {pos=markerPos, colour=colour, label=label, time=player.playTime()}
	markers.store()
	return mid
end

-- delete a marker with a given id
function markers.delete(markerId)
	markers.load()
	markers.markers[markerId] = nil
	markers.store()
end

-- delete several markers with the given ids
function markers.deleteBulk(markerIds)
	markers.load()
	for i, markerId in ipairs(markerIds) do
		markers.markers[markerId] = nil
	end
	markers.store()
end

-- UI helpers

function markers.drawMarkers(canvas, calculateDrawPosFun, showTooltipFun, showDistanceFun)
	local mousePos = canvas:mousePosition()
	local closestMarker = nil;
	local closestMarkerDist = 99;
	for mid, marker in pairs(markers.markers) do
		-- sb.logInfo("marker %s", marker)
		local position = calculateDrawPosFun(marker.pos)
		markers.drawAtPosWithColour(canvas, position, marker.colour)
		local diff = vec2.sub(position, mousePos)
		local dist = vec2.dot(diff, diff)
		if dist < 16 and dist < closestMarkerDist then
			closestMarker = marker
			closestMarkerDist = dist
		end
	end
	if closestMarker then
		if closestMarker.label:find("^time", 1, true) ~= nil then
			local elapsed = player.playTime() - closestMarker.time
			local suffix = "s"
			
			if elapsed >= yearSeconds then
				elapsed = "1+"
				suffix = "y"
			else
				if elapsed >= daySeconds then
					elapsed = elapsed / daySeconds
					suffix = "d"
				elseif elapsed >= hourSeconds then
					elapsed = elapsed / hourSeconds
					suffix = "h"
				elseif elapsed >= minuteSeconds then
					elapsed = elapsed / minuteSeconds
					suffix = "m"
				end
				elapsed = math.floor(elapsed)
			end
			
			showTooltipFun(closestMarker.label:gsub("%^time", elapsed .. suffix .. " ago"))
		else
			showTooltipFun(closestMarker.label)
		end
		showDistanceFun(closestMarker.pos)
	end
end

function markers.drawAtPosWithColour(canvas, uiPos, colour)
	canvas:drawImage(markers.MARKER_IMAGES[colour], uiPos, 1, nil, true)
end


function markers.getMarkerIdNearPosition(uiPos, calculateDrawPosFun)
	local closestMarkerId = nil;
	local closestMarkerDist = 99;
	for mid, marker in pairs(markers.markers) do
		local position = calculateDrawPosFun(marker.pos)
		local diff = vec2.sub(position, uiPos)
		local dist = vec2.dot(diff, diff)
		if dist < 16 and dist < closestMarkerDist then
			closestMarkerId = mid
			closestMarkerDist = dist
		end
	end
	return closestMarkerId;
end
