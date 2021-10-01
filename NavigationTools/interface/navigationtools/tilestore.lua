-- backing for the mini mapper tile store

TileStore = {}

TileStore.TILE_CACHE_SIZE = 4

TileStore.tileTypes = {
	UNKNOWN = 0, -- or nil
	NOTHING = 1,
	SOLID = 2,
	BACKGROUND = 3,
	LIQUID = 4,
}

function TileStore:new()
	local newTileStore = {
		tileBlocks = {},
		versions = {},
		dirtyTileBlocks = {},
		accessedOrder = {},
		tileCacheSize = self.TILE_CACHE_SIZE,
	}
	setmetatable(newTileStore, self)
	self.__index = self
	return newTileStore
end

-- Get a tile value
function TileStore:getTile(xPos, yPos)
	local blockId = self:getBlockIdForPos(xPos, yPos)
	local blockIndex = self:getBlockIndexForPos(xPos, yPos)
	local block = self:ensureBlockInCache(blockId)
	self:setMostRecentlyUsedBlock(blockId)
	local tiles8 = block[blockIndex] or 0
	local bitPos = (xPos & 7) << 3
	return (tiles8 >> bitPos) & 255
end

-- Set a tile value
function TileStore:setTile(xPos, yPos, value)
	local blockId = self:getBlockIdForPos(xPos, yPos)
	local blockIndex = self:getBlockIndexForPos(xPos, yPos)
	local block = self:ensureBlockInCache(blockId)
	if #block == 0 then
		-- sparse blocks work badly when JSON encoded through world.setProperty,
		-- so make sure blocks are either empty or full
		self:makeEmptyBlock(block)
	end
	self:setMostRecentlyUsedBlock(blockId)
	local tiles8 = block[blockIndex] or 0
	local bitPos = (xPos & 7) << 3
	local newTiles8 = tiles8 & ~(255 << bitPos) | (value << bitPos)
	if tiles8 ~= newTiles8 then
		--sb.logInfo("Mapped %s,%s to %s,%s,%s", xPos, yPos, blockId, blockIndex, bitPos)
		block[blockIndex] = newTiles8
		self.dirtyTileBlocks[blockId] = true
	end
end


-- Get array of packed values for efficient drawing.
-- xPos should probably be divisible by 8
-- Returns an array, a start index, and the number of 8-rows that can be used
function TileStore:getRowArray(xPos, yPos)
	--if (xPos & 7) ~= 0 then sb.logInfo("xPos %s not divisible by 8", xPos) end
	local blockId = self:getBlockIdForPos(xPos, yPos)
	local blockIndex = self:getBlockIndexForPos(xPos, yPos)
	local block = self:ensureBlockInCache(blockId)
	self:setMostRecentlyUsedBlock(blockId)
	return block, blockIndex, 32 - ((xPos >> 3) & 31)
end


-- Fill out block with zeroes
function TileStore:makeEmptyBlock(block)
	for i = 1, 32 * 256 do
		block[i] = 0
	end
end


-- Get the id of the 256x256 block that holds this position
function TileStore:getBlockIdForPos(xPos, yPos)
	local xTile = xPos >> 8
	local yTile = yPos >> 8
	return (xTile << 8) | yTile
end


-- Get the index within the block for the 8-tile row that holds this position
function TileStore:getBlockIndexForPos(xPos, yPos)
	-- +1 to make 1-indexed
	return (((yPos & 255) << 5) | ((xPos & 255) >> 3)) + 1
end


-- Load block into cache if not present, and return the block
function TileStore:ensureBlockInCache(blockId)
	local block = self.tileBlocks[blockId]
	if block ~= nil then
		return block
	else
		self:makeRoomForNewBlock()
		return self:loadBlock(blockId)
	end
end


-- Make sure there are less than the max number of cached tile blocks in the cache
function TileStore:makeRoomForNewBlock()
	while #self.accessedOrder >= self.tileCacheSize do
		self:evictBlock(self.accessedOrder[#self.accessedOrder])
	end
end


-- Load a tile block from a world property
function TileStore:loadBlock(blockId)
	local previousVersion = self.versions[blockId]
	local version = world.getProperty(string.format("navigation_tools_minimap_bv%s", blockId)) or 1
	if version == previousVersion then
		return self.tileBlocks[blockId]
	end
	local block = world.getProperty(string.format("navigation_tools_minimap_b%s", blockId)) or {}
	self.tileBlocks[blockId] = block
	self.versions[blockId] = version
	if not previousVersion then
		self:setMostRecentlyUsedBlock(blockId)
	end
	--sb.logInfo("Loaded block %s v%s", blockId, version)
	return block
end


-- Reload changed tiles in cache
function TileStore:reloadTiles()
	for i = 1, #self.accessedOrder do
		self:loadBlock(self.accessedOrder[i])
	end
end


-- Save tile block to world property, if it has been changed since loading
function TileStore:flushBlock(blockId)
	if self.dirtyTileBlocks[blockId] then
		self.versions[blockId] = self.versions[blockId] + 1
		world.setProperty(string.format("navigation_tools_minimap_b%s", blockId), self.tileBlocks[blockId])
		world.setProperty(string.format("navigation_tools_minimap_bv%s", blockId), self.versions[blockId])
		self.dirtyTileBlocks[blockId] = false
		--sb.logInfo("Flushed block %s v%s", blockId, self.versions[blockId])
	end
end


-- Clear all tiles within world boundaries
function TileStore:clearAllTiles(worldSize)
	for xPos = 0, worldSize[1], 256 do
		for yPos = 0, worldSize[2], 256 do
			local blockId = self:getBlockIdForPos(xPos, yPos)
			world.setProperty(string.format("navigation_tools_minimap_b%s", blockId), nil)
			world.setProperty(string.format("navigation_tools_minimap_bv%s", blockId), nil)
			--sb.logInfo("Cleared %s", blockId)
		end
	end
	self.tileBlocks = {}
	self.versions = {}
	self.dirtyTileBlocks = {}
	self.accessedOrder = {}
	--sb.logInfo("Fully cleared %s", self)
end


-- Flush all changed blocks
function TileStore:flushAll()
	--sb.logInfo("Dirty tiles pre flush %s", self.dirtyTileBlocks)
	for i = 1, #self.accessedOrder do
		self:flushBlock(self.accessedOrder[i])
	end
	--sb.logInfo("Dirty tiles post flush %s", self.dirtyTileBlocks)
end


-- Remove a tile block from cache, making sure any changes are saved first
function TileStore:evictBlock(blockId)
	self:flushBlock(blockId)
	self.dirtyTileBlocks[blockId] = nil
	self.tileBlocks[blockId] = nil
	self.versions[blockId] = nil
	for i = 1, #self.accessedOrder do
		if self.accessedOrder[i] == blockId then
			table.remove(self.accessedOrder, i)
			break
		end
	end
end


-- Mark a block as recently used, to prevent eviction
function TileStore:setMostRecentlyUsedBlock(blockId)
	if self.accessedOrder[1] ~= blockId then
		for i = 1, #self.accessedOrder do
			if self.accessedOrder[i] == blockId then
				table.remove(self.accessedOrder, i)
				break
			end
		end
		table.insert(self.accessedOrder, 1, blockId)
	end
end
