local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local Fsm = require "libs.SimpleFsm.Fsm"

local LogoScene = require "view.LogoScene"
local MainScene = require "view.MainScene"

local PeripheralApi = require "PeripheralApi"

------------------------------ Constructor ------------------------------
local Display = class("Display")
function Display:initialize(w, h)
	if w and h then
		self.w = w
		self.h = h
	else
		self.w, self.h = love.window.getMode()
	end
	
	self.fonts = {
		ROBOTO_MONO_REGULAR = love.graphics.newFont("assets/roboto_mono/RobotoMono-Regular.ttf"),
	}
	
	self.fsm = Fsm()
	self.fsm:hookIntoLove()
	
	self.scenes = {
		logo_scene = LogoScene(),
		main_scene = MainScene(),
	}
	
	for k, v in pairs(self.scenes) do
		self.fsm:add(k, v)
	end
	
	self.fsm:goto("logo_scene")
end

------------------------------ API ------------------------------
function Display:update(dt)
end

function Display:draw(g2d)
	--Enable if any drawing is done outside of Slab.
	--love.graphics.setFont(self.fonts.ROBOTO_MONO_BOLD)
end

------------------------------ Getters / Setters ------------------------------

return Display()
