require "/scripts/vec2.lua"
require "/interface/navigationtools/markers.lua"
require "/interface/navigationtools/tilestore.lua"

local _uninit = uninit

minimap = {}
minimap.radius = 22
local circle = {}
local circleRowIndices = {}

local timeToNextScan = 0.2
local shouldScan = false

function minimap.init(...)
	timeToNextStore = 0.5
	timeToNextScan = 0.3
	shouldScan = false

	minimap.calculateCircle()
	scanIntervalIndex = math.ceil(#circle / 8.0)

	markers.load()
end

function minimap.calculateCircle(r)
	r = r or minimap.radius
	circle = {}
	circleRowIndices = {}
	local x = r
	local y = 0
	local r2 = r * r

	addCircleXY(x, y)
	while x > y do
		if 2 * (RE(x, y, r2) + (2 * y + 1)) + (1 - 2 * x) > 0 then
			x = x - 1
			y = y + 1
		else
			-- x remains the same
			y = y + 1
		end
		addCircleXY(x, y)
	end

	-- sb.logInfo("$$$$$$$$$$$$$$$ Circle area: " .. #circle .. " $$$$$$$$$$$$$$$")
end

function addCircleXY(x, y)
	-- Draw a horizontal line to fill the circle at that y position
	if not circleRowIndices[y] then
		circleRowIndices[y] = x
		for i = -x, x do
			table.insert(circle, {i, y})
			table.insert(circle, {i, -y})
		end
	elseif circleRowIndices[y] < x then -- This should never occur due to the way we're calculating the octant
		-- Add x positions that were not caught by the line drawing
		table.insert(circle, {x, y})
		table.insert(circle, {-x, y})
		table.insert(circle, {x, -y})
		table.insert(circle, {-x, -y})
	end
	-- Draw a horizontal line to fill the circle at that mirrored y position
	if not circleRowIndices[x] then
		circleRowIndices[x] = y
		for i = -y, y do
			table.insert(circle, {i, x})
			table.insert(circle, {i, -x})
		end
	elseif circleRowIndices[x] < y then
		-- Add x positions that were not caught by the line drawing
		table.insert(circle, {y, x})
		table.insert(circle, {-y, x})
		table.insert(circle, {y, -x})
		table.insert(circle, {-y, -x})
	end
end

function RE(x, y, r2)
	return (x * x) + (y * y) - r2
end

function minimap.update(dt)
	timeToNextScan = timeToNextScan - dt
	if timeToNextScan <= 0 then
		shouldScan = true
		timeToNextScan = 0.33
	end

	if shouldScan then
		if not co or coroutine.status(co) == 'dead' then
			shouldScan = false
			co = coroutine.create(scanOverTime)
			coroutine.resume(co, getPlayerPos())
		end
	end

	if co and coroutine.status(co) ~= 'dead' then
		coroutine.resume(co)
	end

	timeToNextStore = timeToNextStore - dt
	if timeToNextStore <= 0 then
		timeToNextStore = 0.5
		minimap.tileStore:flushAll()
	end
end

function scanOverTime(playerPosition)
	local worldWidth = world.size()[1]
	local playerScanPos = getScanPosNearPos(playerPosition)
	
	local posToScan = playerScanPos

	local scanIndex = 1

	while scanIndex > 0 do
		local endScanIndex = scanIndex + scanIntervalIndex
		if endScanIndex > #circle then
			endScanIndex = #circle
		end
		for i = scanIndex, endScanIndex do
			posToScan = vec2.add(playerScanPos, circle[i])
			scanPos(posToScan)
		end
		scanIndex = endScanIndex + 1
		if scanIndex > #circle then
			scanIndex = 0
		end
	end
end

function minimap.addDeathMarker(position)
	position = position or getPlayerPos()
	local newMarkerId = markers.add(position, "death", "R.I.P: ^time")
end

function minimap.clearDeathMarkers()
	markers.load()
	local midsToDelete = {}
	for mid, marker in pairs(markers.markers) do
		if marker.colour == "death" then
			table.insert(midsToDelete, mid)
		end
	end
	markers.deleteBulk(midsToDelete)
end

function uninit()
	if _uninit then
		_uninit()
	end

	minimap.tileStore:flushAll()
end

function getScanPosNearPos(position)
	return {math.floor(position[1] + 0.5), math.floor(position[2] + 0.5)}
end

function getPlayerPos()
	return world.entityPosition(player.id())
end

function scanPos(position)
	position = world.xwrap(position)
	local value = valueAtPos(position)
	if value ~= nil then
		minimap.tileStore:setTile(position[1], position[2], value)
	end
end

function valueAtPos(position)
	local liquid = world.liquidAt(position) 
	if liquid and liquid[2] > 0.4 then
		--sb.logInfo("liquid %s", liquid)
		return TileStore.tileTypes.LIQUID
	end
	local foreground = world.material(position, 'foreground')
	if foreground == nil then
		return nil
	end
	if foreground ~= false then
		return TileStore.tileTypes.SOLID
	elseif world.material(position, 'background') then
		return TileStore.tileTypes.BACKGROUND
	else
		return TileStore.tileTypes.NOTHING
	end
end
