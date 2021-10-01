debug = {}

function debug.timeGetSetProperty(name, value)
	local setStart = os.clock()
	world.setProperty("navigation_tools_storetest", value)
	local setEnd = os.clock()
	local getStart = os.clock()
	world.setProperty("navigation_tools_storetest", value)
	local getEnd = os.clock()
	world.setProperty("navigation_tools_storetest", nil)
	sb.logInfo("Stored %s, set %s get %s", name, (setEnd - setStart) * 1000, (getEnd - getStart) * 1000)
end
