local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local PeripheralApi = require "PeripheralApi"
local AppData = require "AppData"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper ------------------------------
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
local MainScene = class("MainScene", State)
function MainScene:initialize()
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
function MainScene:update(dt)
	Slab.BeginWindow(window.id, window)
	
	--Version
	Slab.Text("Version: " .. AppData:getVersionString())
	--Prj Name
	local prjNameXPos = window.W - getTextW(AppData.PROJECT_NAME) - 10
	Slab.SetCursorPos(prjNameXPos, 0)
	Slab.Text(AppData.PROJECT_NAME)
	
	--Status
	local statusStr = PeripheralApi:ping() and "Robot Status: live" or "Robot Status: offline"
	local statusXPos = window.W / 2 - getTextW(statusStr) / 2
	local statusYPos = getTextH(statusStr) * 3
	Slab.SetCursorPos(statusXPos, statusYPos)
	Slab.Text(statusStr)
			
	--Modes - Manual
	local modesYPos = window.H / 2
	local modesXOffset = 100
	Slab.SetCursorPos(modesXOffset, modesYPos)
	if Slab.Button("Manual") then
		self.fsm:goto("manual_scene")
	end
	
	--Auto - Modes
	local autoW = getTextW("Automatic") + 16
	local autoX = window.W - modesXOffset - autoW
	Slab.SetCursorPos(autoX, modesYPos)
	if Slab.Button("Automatic") then
		self.fsm:goto("auto_scene")
	end
	
	--Reboot Remote
	local bottomY = window.H - getTextH("FOO")
	Slab.SetCursorPos(0, bottomY)
	if Slab.Button("Quit") then
		PeripheralApi:quit()
	end
	
	--Quit
	
	Slab.EndWindow()
end

function MainScene:draw(g2d)
end

function MainScene:enter(from, ...)
	print("Entered MainScene.")
end

function MainScene:leave(to)
	print("Left MainScene.")
end

------------------------------ Getters / Setters ------------------------------

return MainScene
