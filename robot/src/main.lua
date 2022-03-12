--[[
local sock = require "libs.sock"

local server = sock.newServer("*", 9000)
server:on("connect", function()
	print("Client connected!")
end)
server:on("disconnect", function()
	print("Client disconnected!")
end)

function love.update()
	server:update()
end

--]]

---[[


local Slab = require "libs.Slab"

local UdpApi = require "UdpApi"
local Scheduler = require "libs.Scheduler"

--local dummyServer = require "DummyServer"


function love.load()
	Slab.SetINIStatePath(nil)
	Slab.Initialize()
	--dummyServer.load()
	
	local Display = require "view.Display"
	_G.Display = Display
end

local fps = 5
local lastTime = 0
function love.update(dt)
		
	Slab.Update(dt)
	
	UdpApi:update()
	--dummyServer.update(dt)
	Display:update(dt)
	Scheduler:tick(dt)
end

function love.draw()
	local g2d = love.graphics
	Display:draw(g2d)
	Slab.Draw()
	--dummyServer:draw(g2d)
end

function love.keypressed(k)
	if k == 'p' then print(math.random()) end
end
--]]
