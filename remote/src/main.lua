--[[
local sock = require "libs.sock"

local client = sock.newClient("localhost", 9000)

client:on("connect", function()
	print("Connected!")
end)

client:on("disconnect", function()
	print("Disconnected!")
end)

client:connect()

function love.update()
	client:update()
end

--]]

---[[
local Slab = require "libs.Slab"

local PeripheralApi = require "PeripheralApi"
local UdpApi = require "UdpApi"

local lovebird = require "libs.lovebird"
lovebird.update()					--To fix lovebird missing prints before the first love.update is called.

local Display
function love.load(args)
	Slab.SetINIStatePath(nil)	
	Slab.Initialize(args)
	
	Display = require "view.Display"	--Put it here to control when it initialize's. TODO: Figure out a cleaner way to do this.
	_G.Display = Display
end

local dur = 3
local lastTime = 0
function love.update(dt)
	lovebird.update(dt)
	UdpApi:update(dt)

	Slab.Update(dt)
	Display:update(dt)

	
	
--	if love.timer.getTime() - lastTime > dur then
--		lastTime = love.timer.getTime() 
--		if UdpApi.client:isConnected() then
--			UdpApi.client:send("hello")
--		end
--	end
end

function love.draw()
	local g2d = love.graphics
	Slab.Draw()
	Display:draw(g2d)
end

--]]

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