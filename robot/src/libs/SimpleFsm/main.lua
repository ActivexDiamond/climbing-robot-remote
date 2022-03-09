local Fsm = require "libs.SimpleFsm.Fsm"
local State = require "libs.SimpleFsm.State"

--Test
local state1 = State()
state1.update = function(dt) print("state1 update!") end
state1.enter = function(fsm, from, ...) print("entered state1 with vars: ", ...) end
state1.leave = function(fsm, to, ...) print("left state1") end

local state2 = State()
state2.update = function(dt) print("state2 update!") end
state2.enter = function(fsm, from, ...) print("entered state2 with vars: ", ...) end
state2.leave = function(fsm, to, ...) print("left state2") end

local fsm = Fsm()
fsm:add(state1)
fsm:add(state2)

function love.load(args)
	fsm:hookIntoLove()
	fsm:goto(state1)
	fsm:goto(state1)	--Does nothing.
	fsm:goto(state2)
	fsm:goto(state1, "Hello", "World!", 42)
end

function love.update(dt)
	print("Original update!")
end

function love.draw()
	local g2d = love.graphics
	print("Original draw!")
end