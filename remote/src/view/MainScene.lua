local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local socket = require "socket"

local PeripheralApi = require "PeripheralApi"
local AppData = require "AppData"

local State = require "libs.SimpleFsm.State"

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
local MainScene = class("MainScene", State)
function MainScene:initialize()
	--Fetch Client Ip
	self.machineIp = socket.dns.toip(socket.dns.gethostname())
	
	--Offline Label Animation
	self.dotTimeDur = 0.3
	self.dotsLen = 7
	
	self.dotTime = 0
	self.dots = ""	
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

local isConfirming
local popupQuit = {
	id = "Quitting!",
	msg = "Are you sure you want to quit?\n\n  You can start the program back up\nby launching \"Robot Controller\"\nfrom your desktop.",
	Buttons = {"Quit!", "Cancel"},
	onClick = function(result)
		if result == "Quit!" then
			PeripheralApi:quit()
		end
		return nil
	end
}

local popupRebootRemote = {
	id = "Rebooting Remote!",
	msg = "Are you sure you want to reboot the remote?\n\n  This may take a few minutes.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PeripheralApi:rebootRemote()
		end
		return nil
	end
}

local popupRebootRobot = {
	id = "Rebooting Robot!",
	msg = "Are you sure you want to reboot the robot?\n\n  This may take a few minutes,\nduring which the remote will be unfunctional.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PeripheralApi:rebootRobot()
		end
		return nil
	end
}

------------------------------ Core API ------------------------------
function MainScene:update(dt)
	Slab.BeginWindow(window.id, window)
	
	--Prj Name
	local prjNameXPos = window.W - getTextW(AppData.PROJECT_NAME) - 10
	Slab.SetCursorPos(prjNameXPos, 0)
	Slab.Text(AppData.PROJECT_NAME)
	Slab.SetCursorPos(prjNameXPos - 7, getTextH("foo"))
	if Slab.Button("Change Target") then
		self.fsm:goto("target_change_scene")
	end
	Slab.SetCursorPos(0, 0)
	--Version
	Slab.Text("Version: " .. AppData:getVersionString())
	--Server Info
	Slab.Text("Machine (Client) IP: " .. self.machineIp)
	Slab.Text("Target (Server) IP: " .. AppData.targetIp)
	Slab.Text("Port: " .. AppData.port)
	
	--Status
	local statusStr = PeripheralApi:ping() and "Robot Status: online" or "Robot Status: offline"
	local statusXPos = window.W / 2 - getTextW(statusStr) / 2
	local statusYPos = getTextH(statusStr) * 3
	--Slab.SetCursorPos(statusXPos, statusYPos)
	Slab.NewLine()
	Slab.Text(statusStr)
	
	--Offline Label
	--Slab.SetCursorPos(statusXPos, statusYPos + getTextH(statusStr))
	if not PeripheralApi:ping() then
		Slab.Text("Reconnecting." .. self.dots)
		self.dotTime = self.dotTime + dt
		if self.dotTime > self.dotTimeDur then
			self.dotTime = 0
			self.dots = self.dots .. "."
			if #self.dots > self.dotsLen then
				self.dots = ""
			end
		end
	else
		self.dotTime = 0
		self.dots = ""
	end
	
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
	
	--Bottom Toolbar - Quit
	local bottomY = window.H - getTextH("FOO") * 2
	Slab.SetCursorPos(0, bottomY)
	if Slab.Button("Quit") then
		isConfirming = popupQuit
	end
	
	--Bottom Toolbar - Reboot Remote
	local rebootX = 220
	Slab.SetCursorPos(rebootX, bottomY)
	
	if Slab.Button("Reboot Remote") then
		isConfirming = popupRebootRemote
	end
	
	--Bottom Toolbar - Reboot Robot
	Slab.SameLine()
	if Slab.Button("Reboot Robot") then
		isConfirming = popupRebootRobot
	end

	if isConfirming then
		local result = Slab.MessageBox(isConfirming.id, isConfirming.msg, isConfirming)
		if result ~= "" then
			isConfirming = isConfirming.onClick(result)
		end
	end
	
	Slab.EndWindow()
	
	PeripheralApi:reconnet()		--Will get ignored if client is already connected.
end

------------------------------ Getters / Setters ------------------------------

return MainScene
