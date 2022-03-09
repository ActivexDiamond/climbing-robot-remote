--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"
local State = require "libs.SimpleFsm.State"

------------------------------ Nil State ------------------------------
local NilState = class("NilState", State)

------------------------------ Constructor ------------------------------
local Fsm = class("Fsm")
function Fsm:initialize()
	local ns = NilState()
	self.states = {["nil"] = ns}
	self.curState = ns
end

------------------------------ Core API ------------------------------

--[[
Callbacks only have to be defined by the FSM for ones that wish to override the default hookIntoLove behavior.
Which is: 
	if self.curState and self.curState[callbackName] then 
		self.curState[callbackName](pass-all-default-love-params-for-callback)
--]]
function Fsm:draw()
	if not self.curState.draw then return end
	
	local g2d = love.graphics
	self.curState:draw(g2d)
end

function Fsm:at(id)
	if id then
		return self.states[id] == self.curState
	else
		for k, v in pairs(self.states) do
			if self.curState == v then return k end
		end
	end
end

function Fsm:goto(id, ...)
	local state = self.states[id]
	if not state then return false end
	if self.curState == state then return false end
	
	self.curState:leave(state)
	local previous = self.curState
	self.curState = state
	self.curState:enter(previous, ...)
	return true
end

function Fsm:add(id, state)
	if self.states[id] then return false end
	
	self.states[id] = state
	state:activate(self)
	return true
end

function Fsm:remove(id)
	local state = self.states[id]
	if not state then return false end
	
	if self.curState == state then self.curState = nil end

	state:destroy()
	self.states[id] = nil
	return true
end

------------------------------ Love Hook ------------------------------
local function hookLoveCallback(Fsm, loveStr, fsmStr)
	fsmStr = fsmStr or loveStr
	local preF = love[loveStr]
	
	love[loveStr] = function(...)
		if preF then preF(...) end
		
		if Fsm[fsmStr] then 
			Fsm[fsmStr](Fsm, ...)
		elseif Fsm.curState[fsmStr] then 
			Fsm.curState[fsmStr](Fsm.curState, ...)
		end
	end
end

function Fsm:hookIntoLove()
	hookLoveCallback(self, "update")
	hookLoveCallback(self, "draw")
	hookLoveCallback(self, "keypressed", "keyPressed")
	hookLoveCallback(self, "keyReleased", "keyReleased")
	hookLoveCallback(self, "mousemoved", "mouseMoved")
	hookLoveCallback(self, "mousePressed", "mousePressed")
	hookLoveCallback(self, "textinput", "textInput")
	hookLoveCallback(self, "wheelMoved", "wheelMoved")
	--TODO: Implement the rest.
end

------------------------------ Getters / Setters ------------------------------
function Fsm:getStates()
	return self.states
end

function Fsm:getCurrentState()
	return self.curState
end

return Fsm

--[[

state
current state
transitionTo

--]]
