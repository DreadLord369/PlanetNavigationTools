require "/scripts/vec2.lua"
require "/scripts/messageutil.lua"
require "/scripts/navigationtools/minimap.lua"
require "/interface/navigationtools/tilestore.lua"

local _init = init
local _uninit = uninit
local _update = update
local isAlive = true
local _teleportOut = teleportOut
local lastDeathTime = nil

local playerPosition

function init(...)
	if _init then
		_init(...)
	end

	sb.logInfo("----- Navigation Tools Player Init -----")

	message.setHandler("ClearMiniMap", function(...)
		promises:add(player.confirm(root.assetJson("/interface/confirmation/navigationtools/clearMinimapConfirmation.config")), function (choice)
			if choice then
				minimap.tileStore:clearAllTiles(world.size())
			end
		end)
	end)
	message.setHandler("AddDeathMarker", function(_, _, position)
		-- This will catch instances where a death caused by damage was captured twice, and only create 1 death marker
		if lastDeathTime == nil or player.playTime() - lastDeathTime >= 5.0 then
			minimap.addDeathMarker(position)
		end
		lastDeathTime = player.playTime()
	end)
	message.setHandler("ClearDeathMarkers", function(_, _, deathMarkerId)
		promises:add(player.confirm(root.assetJson("/interface/confirmation/navigationtools/deleteDeathMarkerConfirmation.config")), function (choice)
			if choice then
				minimap.clearDeathMarkers()
			end
		end)
	end)
	message.setHandler("RenameMarker", function(_, _, renameArgs)
		openRenameDialog(renameArgs.markerId, renameArgs.initialName)
	end)
	message.setHandler("OpenMiniMap", function(_, _)
		if player.getProperty("navigation_tools_minimap_state") == "closed" then
			openMiniMap("small")
		end
	end)
	message.setHandler("ExpandMiniMap", function(_, _)
		openMiniMap("large")
	end)
	message.setHandler("ContractMiniMap", function(_, _)
		openMiniMap("small")
	end)

	minimap.tileStore = TileStore:new()
	minimap.init(...)

	updatePlayerPos()

	lastDeathTime = nil

	if player.getProperty("navigation_tools_minimap_state") == nil then
		-- sb.logInfo("#*#*#*#* player: No existing minimap state *#*#*#*#")
		player.setProperty("navigation_tools_minimap_state", "closed")
		co = nil
	elseif player.getProperty("navigation_tools_minimap_state") == "small" then
		-- sb.logInfo("#*#*#*#* player: Existing minimap state was 'small' *#*#*#*#")
		co = coroutine.create(openMiniMapDelayed)
		coroutine.resume(co, "small", 5.0)
	elseif player.getProperty("navigation_tools_minimap_state") == "large" then
		-- sb.logInfo("#*#*#*#* player: Existing minimap state was 'large' *#*#*#*#")
		co = coroutine.create(openMiniMapDelayed)
		coroutine.resume(co, "small", 5.0)
	elseif player.getProperty("navigation_tools_minimap_state") == "closed" then
		-- sb.logInfo("#*#*#*#* player: Existing minimap state was 'closed' *#*#*#*#")
		co = nil
	end

	sb.logInfo("----- End Navigation Tools Player Init -----")
end

function openMiniMapDelayed(size, seconds)
	local startTime = os.time()
	local diff = os.difftime(os.time(), startTime)
	while diff < seconds do
		coroutine.yield("#*#*#*#* player: Waiting to open minimap (" .. size .. "): " .. tostring(diff) .. "/" .. tostring(seconds) .. " *#*#*#*#")
		diff = os.difftime(os.time(), startTime)

		-- Break early if we register that we are already moving after teleport
		if not status.statusProperty("navigation_tools_teleporting") then
			diff = seconds
		end
	end

	openMiniMap(size)
end

function openMiniMap(size)
	size = size or "small"
	local configData = {}
	if size == "small" then
		configData = root.assetJson("/interface/navigationtools/minimapgui.config")
	else
		configData = root.assetJson("/interface/navigationtools/minimapguilarge.config")
	end
	
	status.setStatusProperty("navigation_tools_teleporting", false)
	player.interact("ScriptPane", configData)
end

function openRenameDialog(markerId, initialName)
	local configData = root.assetJson("/interface/navigationtools/renamemarkergui.config")
	configData.markerId = markerId
	configData.initialName = initialName
	player.interact("ScriptPane", configData)
end

function update(dt)
	if _update then
		_update(dt)
	end

	local hp = status.resource("health")
	if hp <= 0 then
		sb.logInfo("#*#*#*#* player_init: update(): player died - health = " .. hp .. " *#*#*#*#")
		status.setStatusProperty("navigation_tools_teleporting", true)
		if playerPosition then
			sb.logInfo("#*#*#*#* player_init: update(): player position is known *#*#*#*#")
			-- world.sendEntityMessage(player.id(), "AddDeathMarker", playerPosition) -- doesn't seem to work
			minimap.addDeathMarker(playerPosition)
		else
			sb.logInfo("#*#*#*#* player_init: update(): player position is unknown *#*#*#*#")
		end
		return
	end

	updatePlayerPos()

	promises:update()

	minimap.update(dt)

	if co and coroutine.status(co) ~= "dead" then
		local success, info = coroutine.resume(co)
		-- sb.logInfo(tostring(info))
		if coroutine.status(co) == "dead" then
			co = nil
		end
	end
end

function updatePlayerPos()
	local newPlayerPosition = world.entityPosition(player.id())
	playerPosition = newPlayerPosition or playerPosition
end

function teleportOut(...)
	-- sb.logInfo("#*#*#*#* player_init: TELEPORTING OUT *#*#*#*#")
	status.setStatusProperty("navigation_tools_teleporting", true)
	_teleportOut(...)
end

function uninit(...)
	local hp = status.resource("health")
	sb.logInfo("#*#*#*#* player_uninit: health = " .. hp .. " *#*#*#*#")
	status.setStatusProperty("navigation_tools_teleporting", true)
	if hp <= 0 then
		sb.logInfo("#*#*#*#* player_uninit: player died - health = " .. hp .. " *#*#*#*#")
		if playerPosition then
			sb.logInfo("#*#*#*#* player_uninit: player position is known *#*#*#*#")
			minimap.addDeathMarker(playerPosition)
		else
			sb.logInfo("#*#*#*#* player_uninit: player position is unknown - no death marker created *#*#*#*#")
		end
	end
	
	_uninit(...)
end
