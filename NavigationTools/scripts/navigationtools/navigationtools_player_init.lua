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
			openMiniMap()
		end
	end)
	message.setHandler("ExpandMiniMap", function(_, _)
		openMiniMapLarge()
	end)
	message.setHandler("ContractMiniMap", function(_, _)
		openMiniMap()
	end)

	minimap.tileStore = TileStore:new()
	minimap.init(...)

	lastDeathTime = nil

	player.setProperty("navigation_tools_teleporting", false)

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
	end

	if size == "small" then
		openMiniMap()
	elseif size == "large" then
		openMiniMapLarge()
	end
end

function openMiniMap()
	local configData = root.assetJson("/interface/navigationtools/minimapgui.config")
	player.interact("ScriptPane", configData)
end

function openMiniMapLarge()
	local configData = root.assetJson("/interface/navigationtools/minimapguilarge.config")
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

function teleportOut(...)
	-- sb.logInfo("#*#*#*#* player_init: TELEPORTING OUT *#*#*#*#")
	player.setProperty("navigation_tools_teleporting", true)
	_teleportOut(...)
end
