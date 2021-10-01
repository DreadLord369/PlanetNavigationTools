function activate(fireMode, shiftHeld)
	if fireMode == "primary" then
		world.sendEntityMessage(player.id(), "OpenMiniMap")
	end
end
