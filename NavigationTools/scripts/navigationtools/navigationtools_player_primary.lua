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
end
