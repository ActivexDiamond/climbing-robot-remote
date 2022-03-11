--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local State = class("State")
function State:initialize()
end

------------------------------ Core API ------------------------------
function State:update(dt)
end

function State:draw(g2d)
end

function State:enter(from, ...)
	print("Entered: " .. self.fsm:at())
end

function State:leave(to)
	--FIXME: fsm is nil.
	--print("Left: " .. self.fsm:at())
end

function State:activate(fsm)
	self.fsm = fsm
end

function State:destroy()
end

------------------------------ Getters / Setters ------------------------------

return State

--[[

activate
destroy
enter
leave
update
draw

--]]
