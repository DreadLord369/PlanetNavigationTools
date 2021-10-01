function init()
	widget.setText("markerName", config.getParameter("initialName"))
end

function update(dt)
end

function rename()
	local markerId = config.getParameter("markerId")
	local markers = world.getProperty("navigation_tools_markers") or {}
	if markers[markerId] then
		markers[markerId].label = widget.getText("markerName")
		world.setProperty("navigation_tools_markers", markers)
	end
	pane.dismiss()
end

function markerName()
end
