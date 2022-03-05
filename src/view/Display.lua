local class = require "libs.middleclass"
local Fsm = require "libs.SimpleFsm.Fsm"

local LogoScene = require "view.LogoScene"
local MainScene = require "view.MainScene"
local ManualScene = require "view.ManualScene"
local AutoScene = require "view.AutoScene"

------------------------------ Constructor ------------------------------
local Display = class("Display")
function Display:initialize(w, h)
	if w and h then
		self.w = w
		self.h = h
	else
		self.w, self.h = love.window.getMode()
	end
	
	self.fsm = Fsm()
	self.fsm:hookIntoLove()
	
	self.scenes = {
		logo_scene = LogoScene(),
		main_scene = MainScene(),
		manual_scene = ManualScene(),
		auto_scene = AutoScene(),
	}
	
	for k, v in pairs(self.scenes) do
		self.fsm:add(k, v)
	end
	
	self.fsm:goto("logo_scene")
end

------------------------------ API ------------------------------


------------------------------ Getters / Setters ------------------------------

return Display()
