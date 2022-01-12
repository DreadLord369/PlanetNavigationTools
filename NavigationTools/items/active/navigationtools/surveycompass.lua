function init()
	self.compassOpen = false
	message.setHandler("SurveyCompassClosed", function(...)
		self.compassOpen = false
	end)
	message.setHandler("RenameMarker", function(_, _, renameArgs)
		openRenameDialog(renameArgs.markerId, renameArgs.initialName)
	end)
end

function activate(fireMode, shiftHeld)
	if fireMode == "primary" and not self.compassOpen then
		openCompass()
		self.compassOpen = true
	end
end

function openCompass()
	status.setStatusProperty("navigation_tools_teleporting", false)
	local configData = root.assetJson("/interface/navigationtools/compassgui.config")
	configData.ownerId = activeItem.ownerEntityId()
	activeItem.interact("ScriptPane", configData, activeItem.ownerEntityId())
end

function openRenameDialog(markerId, initialName)
	local configData = root.assetJson("/interface/navigationtools/renamemarkergui.config")
	configData.markerId = markerId
	configData.initialName = initialName
	activeItem.interact("ScriptPane", configData, activeItem.ownerEntityId())
end

function update(dt)
end

function uninit()

end
