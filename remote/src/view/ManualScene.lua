local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local lume = require "libs.lume"

local AppData = require "AppData"
local PeripheralApi = require "PeripheralApi"

local State = require "libs.SimpleFsm.State"

------------------------------ Internal Constants ------------------------------
local DEFAULT_BUTTON_SIZE = 32
local DEFAULT_BUTTON_PAD = 0

------------------------------ Helper Methods ------------------------------
local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function imgButtonOpt(button_size, imgPath)
	return {
		id = imgPath,
		W = button_size,
		H = button_size,
		Image = {Path = imgPath},
	}
end

--Callback signature: f(newVal, oldVal, inc)
local function buttonStepper(val, inc, callback, label, buttonSize, buttonPad)
	buttonSize = buttonSize or DEFAULT_BUTTON_SIZE
	buttonPad = buttonPad or DEFAULT_BUTTON_PAD
	
	local offset = buttonSize + buttonPad
	local initX, initY = Slab.GetCursorPos()

	--Plus
	local plusOpt = imgButtonOpt(buttonSize, AppData.ASSET_DIR .. "plus.png")
	Slab.SetCursorPos(initX, initY)
	if Slab.Button(plusOpt.id, plusOpt) then
		callback(val + inc, val, inc)
	end
	--Val
	local xOffset = buttonSize * 0.5 - getTextW(val) / 2
	Slab.SetCursorPos(initX + xOffset, initY + offset * 1.2)
	Slab.Text(val)
	--Minus
	Slab.SetCursorPos(initX, initY + offset * 2)
	local minusOpt = imgButtonOpt(buttonSize, AppData.ASSET_DIR .. "minus.png")
	if Slab.Button(minusOpt.id, minusOpt) then
		callback(val - inc, val, -inc)
	end
	--Label	
	if label then
		local xOffset = buttonSize * 0.5 - getTextW(label) / 2
		Slab.SetCursorPos(initX + xOffset, initY + offset * 3)
		Slab.Text(label)	
	end
end

local function joystick(dirs, label, buttonSize, buttonPad)
	buttonSize = buttonSize or DEFAULT_BUTTON_SIZE
	buttonPad = buttonPad or DEFAULT_BUTTON_PAD
	local callback = dirs.callback or function(id) 
		print("[" .. id .. "] button was pressed.")
	end
	
	local initX, initY = Slab.GetCursorPos()
	local offset = buttonSize + buttonPad
	local rtVal
	--North
	Slab.SetCursorPos(initX + offset, initY)
	local n = dirs.north
	local nOpt = imgButtonOpt(buttonSize, n.imgPath)
	if Slab.Button(n.id, nOpt) then
		rtVal = n.callback and n.callback(n.id) or callback(n.id)
	end
	--Center
	
	local c = dirs.center
	if c then
		Slab.SetCursorPos(initX + offset, initY + offset) 
		local cOpt = imgButtonOpt(buttonSize, c.imgPath)
		if Slab.Button(c.id, cOpt) then
			rtVal = c.callback and c.callback(c.id) or callback(c.id)
		end
	end
	
	--South
	Slab.SetCursorPos(initX + offset, initY + offset * 2) 
	local s = dirs.south
	local sOpt = imgButtonOpt(buttonSize, s.imgPath)
	if Slab.Button(s.id, sOpt) then
		rtVal = s.callback and s.callback(s.id) or callback(s.id)
	end
	
	--Label
	if label then
		local xOffset = offset * 1.5 - getTextW(label) / 2 
		Slab.SetCursorPos(initX + xOffset, initY + offset * 3)
		Slab.Text(label)
	end
	
	--West
	Slab.SetCursorPos(initX, initY + offset)
	local w = dirs.west
	local wOpt = imgButtonOpt(buttonSize, w.imgPath)
	if Slab.Button(w.id, wOpt) then
		rtVal = w.callback and w.callback(w.id) or callback(w.id)
	end
	--East
	Slab.SetCursorPos(initX + offset * 2, initY + offset)
	local e = dirs.east
	local eOpt = imgButtonOpt(buttonSize, e.imgPath)
	if Slab.Button(e.id, eOpt) then
		rtVal = e.callback and e.callback(e.id) or callback(e.id)
	end
	
	return rtVal
end

------------------------------ Constructor ------------------------------
local ManualScene = class("ManualScene", State)
function ManualScene:initialize()
	self.buttonSize = 24
	self.buttonPad = 4
	self.buttonOffset = self.buttonSize + self.buttonPad
	
	self.foo = 0
	self.fooMin = 0
	self.fooMax = 5
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

------------------------------ Core API ------------------------------
function ManualScene:update(dt)
	Slab.BeginWindow(window.id, window)
	
	--Back
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	--Ultrasonics
	--local leftStr = string.format("LEFT-HC-SR04:    %.2fcm", PeripheralApi:getLeftUltrasonic())
	--Slab.Text(leftStr)
	--local rightStr = string.format("RIGHT-HC-SR04: %.2fcm", PeripheralApi:getRightUltrasonic())
	--Slab.Text(rightStr)
	
	--Chasis Joystick
	Slab.SetCursorPos(self.buttonOffset, window.H - self.buttonOffset * 4.5)
	joystick({
		center = {id = "stop", imgPath = AppData.ASSET_DIR .. "stop.png",
			callback = function() PeripheralApi:stopWheel()
			end
		},
		north = {id = "forward", imgPath = AppData.ASSET_DIR .. "forward.png"},
		south = {id = "backward", imgPath = AppData.ASSET_DIR .. "backward.png"},
		west = {id = "left", imgPath = AppData.ASSET_DIR .. "left.png"},
		east = {id = "right", imgPath = AppData.ASSET_DIR .. "right.png"},
		callback = function(dir)
			PeripheralApi:moveWheel(dir)
		end,
	}, "Chassis\n[mov]", self.buttonSize, self.buttonPad)

	--Wheel Rot Amount
	Slab.SetCursorPos(self.buttonOffset * 4.7, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getWheelRotAmount(), 10, function(newVal, oldVal, inc)
		PeripheralApi:setWheelRotAmount(newVal)
	end, "Wheel\n  [rot]", self.buttonSize, self.buttonPad)
	
	--Cutter Wheel Angle
	Slab.SetCursorPos(self.buttonOffset * 6.9, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getCutterWheelAngle(), 1, function(newVal, oldVal, inc)
		PeripheralApi:setCutterWheelAngle(newVal)
	end, "CWheel\n  [ang]", self.buttonSize, self.buttonPad)
	--Cutter Worm Angle
	Slab.SetCursorPos(self.buttonOffset * 9.1, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getCutterWormAngle(), 1, function(newVal, oldVal, inc)
		PeripheralApi:setCutterWormAngle(newVal)
	end, "CWorm\n  [ang]", self.buttonSize, self.buttonPad)

	--Arm Speed
	Slab.SetCursorPos(self.buttonOffset * 11.3, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getArmSpeed(), 15, function(newVal, oldVal, inc)
		PeripheralApi:setArmSpeed(newVal)
	end, "Arm\n[spd]", self.buttonSize, self.buttonPad)
				
	--Arm Joystick
	Slab.SetCursorPos(window.W - self.buttonOffset * 4, window.H - self.buttonOffset * 4.5)
	joystick({
		center = {id = "stop", imgPath = AppData.ASSET_DIR .. "stop.png",
			callback = function() PeripheralApi:stopArm()
			end
		},
		north = {id = "forward", imgPath = AppData.ASSET_DIR .. "forward.png"},
		south = {id = "backward", imgPath = AppData.ASSET_DIR .. "backward.png"},
		west = {id = "up", imgPath = AppData.ASSET_DIR .. "up.png"},
		east = {id = "down", imgPath = AppData.ASSET_DIR .. "down.png"},
		callback = function(dir)
			PeripheralApi:moveArm(dir)
		end, 
	}, "Arm\n[mov]", self.buttonSize, self.buttonPad)
		
	Slab.EndWindow()
end

------------------------------ Getters / Setters ------------------------------

return ManualScene
