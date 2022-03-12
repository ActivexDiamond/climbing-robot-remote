local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"
 
local AppData = require "AppData"

------------------------------ Local Constants ------------------------------
local DEFAULT_BUTTON_SIZE = 24
local DEFAULT_BUTTON_PAD = 4
local SCREEN_W = 480
local SCREEN_H = 320


------------------------------ Helper Methods ------------------------------
local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function getTextH(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getHeight()
end

------------------------------ Constructor ------------------------------
local TargetChangeScene = class("TargetChangeScene", State)
function TargetChangeScene:initialize()
	self.keypadLayout = {
		{"1", "2", "3",},
		{"4", "5", "6",},
		{"7", "8", "9",},
		{".", "0", "<-", "OK",},
	}
	self.MAX_TARGET_LEN = 15
	
	self.newTarget = ""
end

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = love.graphics.getWidth(),
	H = love.graphics.getHeight(),
	AutoSizeWindow = false,
}

local keypadButton = {
	W = DEFAULT_BUTTON_SIZE,
	H = DEFAULT_BUTTON_SIZE,
}

------------------------------ Core API ------------------------------
function TargetChangeScene:update(dt)
	--Main Window
	Slab.BeginWindow(window.id, window)
	
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	local offset = DEFAULT_BUTTON_SIZE + DEFAULT_BUTTON_PAD	

	local initX = SCREEN_W / 2 - #self.keypadLayout * offset
	local initY = SCREEN_H / 2 - #self.keypadLayout[1] * offset

	for i = 1, #self.keypadLayout do
		local row = self.keypadLayout[i]
		for j = 1, #row do
			local x = initX + j * offset
			local y = initY + i * offset
			Slab.SetCursorPos(x, y)
			local key = row[j]
			if Slab.Button(key, keypadButton) then
				self:_pressed(key)
			end
		end
	end
	
	Slab.SetCursorPos(100, 80)
	Slab.Text("Target: " .. self.newTarget)
	Slab.SetCursorPos(0, SCREEN_H - 24)
	Slab.Text("Note: Set to an empty field to default to \"localhost\".")
	
	Slab.EndWindow()
end

function TargetChangeScene:leave(to)
	self.newTarget = ""
end

------------------------------ Internals ------------------------------
function TargetChangeScene:_pressed(key)
	if key == "OK" then
		AppData:updateTarget(self.newTarget)
		self.fsm:goto("main_scene")	
	elseif key == "<-" then
		self.newTarget = self.newTarget:sub(1, -2)
	elseif #self.newTarget < self.MAX_TARGET_LEN then
		self.newTarget = self.newTarget .. key
	end
end

------------------------------ Getters / Setters ------------------------------

return TargetChangeScene
