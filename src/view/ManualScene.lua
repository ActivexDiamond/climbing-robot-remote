local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local ManualScene = class("ManualScene", State)
function ManualScene:initialize()
end

------------------------------ Core API ------------------------------
function ManualScene:update(dt)
end

function ManualScene:draw(g2d)
end

function ManualScene:enter(from, ...)
end

function ManualScene:leave(to)
end

------------------------------ Getters / Setters ------------------------------

return ManualScene
