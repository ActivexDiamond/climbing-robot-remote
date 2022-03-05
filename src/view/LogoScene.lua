local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local LogoScene = class("LogoScene", State)
function LogoScene:initialize()
	self.duration = 0.3
	
	self.logo = love.graphics.newImage("assets/a_lab_logo.png")
end

------------------------------ Core API ------------------------------
function LogoScene:update(dt)
	print(string.format("age: %.3f", self.age))
	self.age = self.age + dt
	if self.age > self.duration then
		print("aged out")
		self.fsm:goto("main_scene")
	end
end

function LogoScene:draw(g2d)
	g2d.draw(self.logo, 0, 0)
end

function LogoScene:enter(from, ...)
	self.age = 0
	print("Entered LogoScene.")
end

function LogoScene:leave(to)
	print("Left logoScene.")
end

------------------------------ Getters / Setters ------------------------------

return LogoScene