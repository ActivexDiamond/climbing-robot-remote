local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local ManualScene = class("ManualScene", State)
function ManualScene:initialize()
end

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = love.graphics.getWidth(),
	H = love.graphics.getHeight()
}

------------------------------ Core API ------------------------------
function ManualScene:update(dt)
	Slab.BeginWindow(window.id, window)
	
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	Slab.EndWindow()
end

function ManualScene:draw(g2d)
end

function ManualScene:enter(from, ...)
end

function ManualScene:leave(to)
end

------------------------------ Getters / Setters ------------------------------

return ManualScene
