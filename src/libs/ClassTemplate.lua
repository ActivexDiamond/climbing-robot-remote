============================== Obj + Super ==============================
local class = require "libs.cruxclass"
local Super = require "x"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local Object = class("Unnamed", Super)
function Object:init()
	Super.init(self)
end

------------------------------ Getters / Setters ------------------------------

return Object

============================== Obj ==============================
local class = require "libs.cruxclass"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local Object = class("Unnamed")
function Object:init()
end

------------------------------ Getters / Setters ------------------------------

return Object

============================== Obj + Thing ==============================
local class = require "libs.cruxclass"
local Thing = require "template.Thing"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local Object = class("Unnamed", Thing)
function Object:init(id)
	Thing.init(self, id)
end

------------------------------ Getters / Setters ------------------------------

return Object