local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local AutoScene = class("AutoScene", State)
function AutoScene:initialize()
end

------------------------------ Core API ------------------------------
function AutoScene:update(dt)
end

function AutoScene:draw(g2d)
end

function AutoScene:enter(from, ...)
end

function AutoScene:leave(to)
end

------------------------------ Getters / Setters ------------------------------

return AutoScene
