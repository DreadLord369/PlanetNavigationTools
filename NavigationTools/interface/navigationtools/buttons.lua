require "/scripts/vec2.lua"

buttons = {}

buttons.BUTTON_SIZE = 13

buttons.buttons = {}


function buttons.addStandardButtons(buttonPositions, onAddMarker, onRemoveMarker)
	buttons.addButton(buttonPositions.blueMarker, "Blue marker", function() onAddMarker('blue', "Blue marker") end)
	buttons.addButton(buttonPositions.greenMarker, "Green marker", function() onAddMarker('green', "Green marker") end)
	buttons.addButton(buttonPositions.redMarker, "Red marker", function() onAddMarker('red', "Red marker") end)
	buttons.addButton(buttonPositions.deleteMarker, "Delete marker", onRemoveMarker)
end


function buttons.addButton(position, tooltip, onClick)
	table.insert(buttons.buttons, {position=position, tooltip=tooltip, onClick=onClick})
end


function buttons.updateHighlight(canvas, mousePos, showTooltipFun)
	for i = 1, #buttons.buttons do
		local button = buttons.buttons[i]
		if buttons.isPositionOnButton(mousePos, button.position) then
			buttons.highlightButtonAtPos(canvas, button.position)
			showTooltipFun(button.tooltip)
			break
		end
	end
end


function buttons.handleClick(clickPos)
	for i = 1, #buttons.buttons do
		local button = buttons.buttons[i]
		if buttons.isPositionOnButton(clickPos, button.position) then
			button.onClick()
		end
	end
end


function buttons.isPositionOnButton(mousePos, buttonPos)
	local relMousePos = vec2.sub(mousePos, buttonPos)
	return relMousePos[1] > 0 and relMousePos[1] <= buttons.BUTTON_SIZE and relMousePos[2] > 0 and relMousePos[2] <= buttons.BUTTON_SIZE
end


function buttons.highlightButtonAtPos(canvas, buttonPos)
	canvas:drawImage("/interface/navigationtools/button_lit.png", buttonPos)
end
