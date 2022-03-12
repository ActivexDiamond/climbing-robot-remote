local class = require "libs.middleclass"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local LogoScene = class("LogoScene", State)
function LogoScene:initialize()
	self.duration = 0.3

	self.logo = love.graphics.newImage("assets/a_lab_logo.png")
end

------------------------------ Core API ------------------------------

local percentageLast
function LogoScene:update(dt)
	--TODO: Proper loading bar.
	local percentage = math.floor(self.age / self.duration * 100)
	if percentage ~= percentageLast then
		print(string.format("Loading: %%%d", percentage))
		percentageLast = percentage
	end
	
	self.age = self.age + dt
	if self.age > self.duration then
		print("Loading: %100")
		print("Finished loading!")
		self.fsm:goto("main_scene")
	end
end

function LogoScene:draw(g2d)
	g2d.draw(self.logo, 0, 0)
end

function LogoScene:enter(from, ...)
	State.enter(self, from, ...)
	self.age = 0
end

function LogoScene:leave(to)
	State.leave(self, to)
	self.age = 0
end

------------------------------ Getters / Setters ------------------------------

return LogoScene