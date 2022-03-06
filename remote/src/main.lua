local Slab = require "libs.Slab"

local lovebird = require "libs.lovebird"
lovebird.update()					--To fix lovebird missing prints before the first love.update is called.

local Display
function love.load(args)
	Slab.SetINIStatePath(nil)	
	Slab.Initialize(args)
	
	Display = require "view.Display"	--Put it here to control when it initialize's. TODO: Figure out a cleaner way to do this.
	_G.Display = Display
end

function love.update(dt)
	lovebird.update()
	Slab.Update(dt)
end

function love.draw()
	Slab.Draw()
end
