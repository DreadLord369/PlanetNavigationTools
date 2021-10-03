require "/scripts/vec2.lua"

local _init = init
local _uninit = uninit
local _update = update
local _applyDamageRequest = applyDamageRequest
local isAlive = true

function init()
	_init()
end

function update(dt)
	_update(dt)

	if status.statusProperty("navigation_tools_teleporting") then
		local vel = mcontroller.velocity()
		if vel[1] * vel[1] >= 1 then
			status.setStatusProperty("navigation_tools_teleporting", false)
			-- sb.logInfo("&&&&&&&&&&&&&&&&&&&&&&&&&&& Just moved after teleporting in: (" .. vel[1] .. ", " .. vel[2] .. ") &&&&&&&&&&&&&&&&&&&&&&&&&&&")
		end
	end

	status.removeEphemeralEffect("fucheatdeathhandler")

	-- Use this to catch deaths that do not occur by damage being taken
	if isAlive then
		if not status.resourcePositive("health") then
			-- sb.logInfo("***** We Died - in update *****")
			isAlive = false
			status.setStatusProperty("navigation_tools_teleporting", true)
			world.sendEntityMessage(entity.id(), "AddDeathMarker", mcontroller.position())
		end
	else
		if status.resourcePositive("health") then
			-- This never appears to happen
			-- sb.logInfo("***** We Revived *****")
			isAlive = true
		end
	end
end

-- Use this to catch deaths caused by damage being taken
function applyDamageRequest(damageRequest)
	local hit = _applyDamageRequest(damageRequest)
	if next(hit) ~= nil and hit[1].hitType == "kill" then
			-- sb.logInfo("***** We Died - from damage *****")
			status.setStatusProperty("navigation_tools_teleporting", true)
			world.sendEntityMessage(entity.id(), "AddDeathMarker", mcontroller.position())
	end
	return hit
end
