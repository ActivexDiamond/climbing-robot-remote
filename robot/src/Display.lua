local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local socket = require "socket"

local PiApi = require "PiApi"

local AppData = require "AppData"

------------------------------ Helpers ------------------------------
--Note: This function is available as part of love's math module
--	since version 11.3,
--This is placed here since at this time, this program runs on 11.1
local function colorFromBytes(r, g, b, a)
	local nr = r / 255
	local ng = g / 255
	local nb = b / 255
	local na = a and a / 255 or nil
	return nr, ng, nb, na
end

------------------------------ Constructor ------------------------------
local Display = class("Display")
--Note: This class is a singleton.
function Display:initialize()
	self.backgroundColor = {colorFromBytes(12, 1, 69)}
	love.graphics.setBackgroundColor(self.backgroundColor)
	--local succ, ip = pcall(os.execute, "ipconfig getifaddr en1")
	local succ, handle = pcall(io.popen, "ipconfig getifaddr en1") 
	if succ then
		local ip = handle:read("*a"):sub(1, -2)
		self.machineIp = ip
		handle:close()
	else
		self.machineIp = "failed-to-fetch"
	end
end

------------------------------ Constants ------------------------------
Display.SCREEN_W = 480
Display.SCREEN_H = 320
Display.LINE_H = 30
Display.STAT_INDENT = 130

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = Display.SCREEN_W,
	H = Display.SCREEN_H,
	AutoSizeWindow = false,
}

local isConfirming
local popupQuit = {
	id = "Quitting!",
	msg = "Are you sure you want to quit?\n\n  You can start the program back up\nby launching \"Robot Controller\"\nfrom your desktop.",
	Buttons = {"Quit!", "Cancel"},
	onClick = function(result)
		if result == "Quit!" then
			PiApi:quit()
		end
		return nil
	end
}

local popupRebootRobot = {
	id = "Rebooting Robot!",
	msg = "Are you sure you want to reboot the robot?\n\n  This may take a few minutes.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PiApi:reboot()
		end
		return nil
	end
}

------------------------------ Core API ------------------------------
function Display:update(dt)
	Slab.BeginWindow(window.id, window)
	--Monitoring - CPU
	Slab.Text("CPU: " .. PiApi:getCpuLoad())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 0)
	Slab.Text("CPU TEMP: " .. PiApi:getCpuTemp())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 0)
	Slab.Text("OPEN IP's: *")

	--Monitoring - GPU
	Slab.SetCursorPos(0, self.LINE_H * 1)
	Slab.Text("GPU: " .. PiApi:getGpuLoad())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 1)
	Slab.Text("GPU TEMP: " .. PiApi:getGpuTemp())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 1)
	Slab.Text("MACHINE IP: " .. self.machineIp)
		
	--Monitoring - Data
	Slab.SetCursorPos(0, self.LINE_H * 2)
	Slab.Text("RAM: " .. PiApi:getRamUsage())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 2)
	Slab.Text("DISK: " .. PiApi:getDiskUsage())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 2)
	Slab.Text("PORT: " .. AppData.port)	
	
	--Quit
	Slab.SetCursorPos(self.SCREEN_W - 205, self.SCREEN_H - 32)
	if Slab.Button("Quit") then
		isConfirming = popupQuit
	end

	--Reboot
	Slab.SetCursorPos(self.SCREEN_W - 105, self.SCREEN_H - 32)
	if Slab.Button("Reboot") then
		isConfirming = popupRebootRobot
	end

	if isConfirming then
		local result = Slab.MessageBox(isConfirming.id, isConfirming.msg, isConfirming)
		if result ~= "" then
			isConfirming = isConfirming.onClick(result)
		end
	end
			
	Slab.EndWindow()
end

function Display:draw(g2d)
	
end

return Display()