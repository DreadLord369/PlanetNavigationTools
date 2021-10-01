require "/scripts/vec2.lua"
require "/interface/navigationtools/markers.lua"
require "/interface/navigationtools/tilestore.lua"

local _uninit = uninit

minimap = {}

--      ijk
--     h6789
--     g501a
--     f432b
--      edc
SCAN_ORDER = {
	{0, 0}, -- 0
	{4, 0}, -- 1
	{4, -4}, -- 2
	{0, -4}, -- 3
	{-4, -4}, -- 4
	{-4, 0}, -- 5
	{-4, 4}, -- 6
	{0, 4}, -- 7
	{4, 4}, -- 8
	{8, 4}, -- 9
	{8, 0}, -- a
	{8, -4}, -- b
	{4, -8}, -- c
	{0, -8}, -- d
	{-4, -8}, -- e
	{-8, -4}, -- f
	{-8, 0}, -- g
	{-8, 4}, -- h
	{-4, 8}, -- i
	{0, 8}, -- j
	{4, 8}, -- k
}

function minimap.init(...)
	timeToNextStore = 0.5
	scanIndex = 1
	scanHalfIndex = math.floor(#SCAN_ORDER / 2)

	markers.load()
end

function minimap.update(dt)
	local playerPosition = getPlayerPos()
	local worldWidth = world.size()[1]
	local playerScanPos = getScanPosNearPos(playerPosition)
	
	local posToScan = playerScanPos
	if scanIndex == 1 then
		for i = 1, scanHalfIndex-1 do
			posToScan = vec2.add(playerScanPos, SCAN_ORDER[i])
			scan4x4Block(posToScan)
		end
		scanIndex = scanHalfIndex
	else
		for i = scanHalfIndex, #SCAN_ORDER do
			posToScan = vec2.add(playerScanPos, SCAN_ORDER[i])
			scan4x4Block(posToScan)
		end
		scanIndex = 1
	end

	timeToNextStore = timeToNextStore - dt
	if timeToNextStore <= 0 then
		timeToNextStore = 0.5
		minimap.tileStore:flushAll()
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

function scan4x4Block(position)
	for i = 0, 3 do
		for j = 0, 3 do
			scanPos({position[1] + i, position[2] + j})
		end
	end
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
