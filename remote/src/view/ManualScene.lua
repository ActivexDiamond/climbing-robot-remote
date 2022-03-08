local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local PeripheralApi = require "PeripheralApi"

local State = require "libs.SimpleFsm.State"

------------------------------ Internal Constants ------------------------------
local BUTTON_SIZE = 32

------------------------------ Helper Methods ------------------------------
local function buttonStepper(val, inc, callback)
	if Slab.Button("+") then
		callback(val + inc, val, inc)
	end
	
	Slab.Text(val)
	
	if Slab.Button("-") then
		callback(val - inc, val, -inc)
	end
end

local function dirButtonOpt(imgPath)
	return {
		id = imgPath,
		W = BUTTON_SIZE,
		H = BUTTON_SIZE,
		Image = {Path = imgPath},
	}
end

local function joystick(label, dirs)
	local callback = dirs.callback or function(id) 
		print("[" .. i .. "] button was pressed.")
	end
	
	local initX, initY = Slab.GetCursorPos()
	local rtVal
	--North
	Slab.SetCursorPos(initX, initY)
	local n = dirs.north
	local nOpt = dirButtonOpt(n.imgPath)
	if Slab.Button(n.id, nOpt) then
		rtVal = n.callback and n.callback(n.id) or callback(n.id)
	end
	--South
	Slab.NewLine()						--Skip the center square.
	local s = dirs.south
	local sOpt = dirButtonOpt(s.imgPath)
	if Slab.Button(s.id, sOpt) then
		rtVal = s.callback and s.callback(s.id) or callback(s.id)
	end
	
	--Label
	Slab.NewLine()						--Leave 1 empty space.
	Slab.Text(label)
	
	--West
	Slab.SetCursorPos(initX, initY + BUTTON_SIZE)
	local w = dirs.west
	local wOpt = dirButtonOpt(w.imgPath)
	if Slab.Button(w.id, wOpt) then
		rtVal = w.callback and w.callback(w.id) or callback(w.id)
	end
	--East
	Slab.SetCursorPos(initX + BUTTON_SIZE * 3, initY + BUTTON_SIZE)
	local e = dirs.east
	local eOpt = dirButtonOpt(e.imgPath)
	if Slab.Button(e.id, eOpt) then
		rtVal = e.callback and e.callback(e.id) or callback(e.id)
	end
	
	return rtVal
end

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

	if Slab.Button("plus", {
		W = 32,
		H = 32,
		Image = {Path = "assets/plus.png"}
	}) then
		print("plus")
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
