local class = require "libs.middleclass"
local utils = require "libs.utils"

------------------------------ Constructor ------------------------------
local ConsoleStringBuilder = class("ConsoleStringBuilder")
function ConsoleStringBuilder:initialize(lines, charsPerLine)
	self.lines = lines
	self.charsPerLine = charsPerLine
	
	self.str = ""
end

------------------------------ API ------------------------------
function ConsoleStringBuilder:print(...)
	local args = {...}
	local str = ""
	if #args == 0 then
		str = "\n"
	else
		for k, v in ipairs(args) do
			str = str .. v .. " "
		end
		str = str:sub(1, -2)	--Remove trailing space.
	end
	self:_addString(str)
end

function ConsoleStringBuilder:clear()
	self.str = ""
end

------------------------------ Internals ------------------------------
function ConsoleStringBuilder:_addString(str)
	for i = 1, #str do
		local c = str:sub(i, i)
		self.str = self.str .. c
		--print(#self.str)
		if self:getRealStrLen() % self.charsPerLine == 0 then
			--print("str mod 0")
			self.str = self.str .. "\n"
			if self:getRealStrLen() == self.lines * self.charsPerLine then
				--print("out of screen")
				self.str = self.str:sub(self.charsPerLine + 2)
			end
		end
	end
end

------------------------------ Getters / Setters ------------------------------
function ConsoleStringBuilder:getContent()
	return self.str
end

--Returns the length of the screen counting only chars that are drawable
--	onto the screen. Currently, only removes "\n", sadly.
function ConsoleStringBuilder:getRealStrLen()
	return #utils.str.rem(self.str, "\n")
end


return ConsoleStringBuilder