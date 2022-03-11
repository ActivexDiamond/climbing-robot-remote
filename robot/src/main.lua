local Slab = require "libs.Slab"

--local dummyServer = require "DummyServer"

local Display = require "Display"

function love.load()
	Slab.SetINIStatePath(nil)
	Slab.Initialize()
	--dummyServer.load()
end

function love.update(dt)
	Slab.Update(dt)
	
	--dummyServer.update(dt)
	Display:update(dt)
end

function love.draw()
	local g2d = love.graphics
	Display:draw(g2d)
	Slab.Draw()
	--dummyServer:draw(g2d)
end