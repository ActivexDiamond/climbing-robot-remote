
local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"
local ConsoleStringBuilder = require "libs.ConsoleStringBuilder"
 
local PeripheralApi = require "PeripheralApi"


------------------------------ Local Constants ------------------------------
local CONSOLE_LINES = 5
local CONSOLE_CHARS_PER_LINE = 67

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
local AutoScene = class("AutoScene", State)
function AutoScene:initialize()
	self.console = ConsoleStringBuilder(CONSOLE_LINES, CONSOLE_CHARS_PER_LINE)
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

local _h = getTextH("foo") * CONSOLE_LINES
local consoleWindow = {
	id = "console",
	X = 0,
	Y = love.graphics.getHeight() - _h,
	--To prevent Slab.Textf's wrapped texted from displaying a (1 pixel) scroll bar.
	W = love.graphics.getWidth() - 1,
	H = _h,
	AutoSizeWindow = false,
	BgColor = {1, 1, 1, 0},
}

------------------------------ Core API ------------------------------
function AutoScene:update(dt)
	--Main Window
	Slab.BeginWindow(window.id, window)
	
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	Slab.SetCursorPos(consoleWindow.X, consoleWindow.Y - 20)
	Slab.Text("Console")
	Slab.EndWindow()
	
	--Console Window
	Slab.BeginWindow(consoleWindow.id, consoleWindow)
	Slab.PushFont(Display.fonts.ROBOTO_MONO_REGULAR)

	
	--Draw Console
	Slab.Text(self.console:getContent())
	Slab.PopFont()
	Slab.EndWindow()
end

function AutoScene:leave(to)
	self.console:clear()
end

function AutoScene:keyPressed(key)
	self:_echo(key)
end
------------------------------ Internals ------------------------------
function AutoScene:_echo(...)
	self.console:print(...)
end

------------------------------ Getters / Setters ------------------------------

return AutoScene

--[=[
local loremStr = 
[[Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut
labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi 
ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum
dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
]]
			
--]=]