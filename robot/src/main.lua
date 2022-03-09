local dummyServer = require "DummyServer"

function love.load()
	dummyServer.load()
end

function love.update(dt)
	dummyServer.update(dt)
end

function love.draw()
	local g2d = love.graphics
	--dummyServer:draw(g2d)
end