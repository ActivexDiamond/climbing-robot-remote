local Slab = require "libs.Slab"

local PeripheralApi = require "PeripheralApi"

local lovebird = require "libs.lovebird"
lovebird.update()					--To fix lovebird missing prints before the first love.update is called.

local Display
function love.load(args)
	Slab.SetINIStatePath(nil)	
	Slab.Initialize(args)
	
	Display = require "view.Display"	--Put it here to control when it initialize's. TODO: Figure out a cleaner way to do this.
	_G.Display = Display
end


function love.update(dt)
	lovebird.update()
	Slab.Update(dt)
	Display:update(dt)
end

function love.draw()
	local g2d = love.graphics
	Slab.Draw()
	Display:draw(g2d)
end

--[[
--			Test Cases

PeripheralApi:_sendCmd("arm_stop")
PeripheralApi:_sendCmd("arm_forward", 120)
PeripheralApi:_sendCmd("arm_backward", 150)
PeripheralApi:_sendCmd("arm_stop", 5)
PeripheralApi:_sendCmd("arm_forward")
PeripheralApi:_sendCmd("foo")
--]]

--[[
			From PeripheralApi:_sendCmd() : The UdpApi:send(<...>) line.
			
Should this be changed so that all cmds get their args passed in as a table of args?
	(including 0-arg-cmds and 1-arg-cmds.)
	
--]]