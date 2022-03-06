local class = require "libs.middleclass"
local PiApi = require "PiApi"

------------------------------ Class Description ------------------------------

--[[
	This is a class providing high-level access to the hardware, for both;
		- The Pi inside the remote.
		- The Pi inside the robot (which would be accessed over WiFi.)
		
	You don't really have to make this all that robust or anything. I don't need it to gracefully recover from network errors, etc...
	As long as it doesn't crash TOO much.
		- Preferable optional bonus: Just having an error raised by all error-y situations with a message like "Internal network error. Please reboot."
			or something would be nice. Doesn't need to have different error messages for different errors, etc...
			just a single general one would be a bliss. And even if not, still fine.
			
	I also took the liberty of making a PiApi class that would hold more low-level stuff such as direct GPIO access, etc...
	I don't actually need that or anything, I'll only be using this one, I made that while sketching this out.
	So, feel free to make as many classes as you need, stick all the internal code in this one alone, etc...
	Use any structure you want, etc... All I need is this one to be a singleton (heck, can skip singleton'ing it if you want) and the functions listed below.
	How you go about implementing them is up to you. 

--]]

------------------------------ Conventions ------------------------------

--[[	
	Naming conventions I'm using:
	
	ExampleClass (pascal case for classes)
	ExampleClass.lua (pascal case with the same name as the class, for class files.)
	One class per file.
	
	exampleObject	(camal case)
	exampleVariable (camal case)
	etc...
	
	Planets (pascal case, enum)
	
	CONST_VARIABLE (uppercase)
	
	As for privacy:
		globals -> pls dont ;(
		methods (static and non-static use the same conventions):
			getPlayerHealth()	-> public method
			_getPlayerStuff()	-> protected method (class + children only)
			private method 		-> same as above
			
		members:
			all class members are always protected. I only ever access them using get/set.
--]]

------------------------------ Constructor ------------------------------
local PeripheralApi = class("PeripheralApi")
---This guy's constructor. I put what info I'm guessing this guy needs. Feel free to add/remove as you see fit.
-- Note: This guy is a singleton.
-- @param config	#table		;	A config table holding all the data needed for this class.
function PeripheralApi:init(config)
	self.ip = config.ip
	self.port = config.port
	self.target = self.ip .. ":" .. self.port		--unnecessary?
end

------------------------------ API - Video ------------------------------
--Gets called inside love.draw (ideally at 60fps) and should draw the video stream onto the screen.
-- @param x			#number		;	Screen-coord to start drawing at.
-- @param y			#number		;	Screen-coord to start drawing at.
-- @param w			#number		;	Resolution in pixels.
-- @param h			#number		;	Resolution in pixels.
-- @param fps		#number		; 	fps of the video. Should provide a default. Heck, you can skip implementing this one if you want.
function PeripheralApi:drawCnnVideoStream(x, y, w, h, fps)
	--TODO: Implement.
end

------------------------------ API - Sensors ------------------------------
---Use the gyroscope to check whether the robot is able to continue moving or has fallen over. 
-- Note: I'm guessing you either hardcode values into this, or slap some param in :init(config) to allow some tweaking for this?
-- @return 			#bool		;	Whether it has fallen.
function PeripheralApi:isFallen()
	--TODO: Implement.
	return false
end

---Returns the distance from the left ultrasonic to the nearest object. In centimeters.
-- @return 			#number		;	Distance in cm.
function PeripheralApi:readLeftUltrasonic()
	--TODO: Implement.
	return 20
end

---Returns the distance from the right ultrasonic to the nearest object. In centimeters.
-- @return 			#number		;	Distance in cm.
function PeripheralApi:readRightUltrasonic()
	--TODO: Implement.
	return 20
end

------------------------------ API - Networking ------------------------------
---Checks if the remote is currently connected to the robot. Returns a bool, not the delay.
-- @return 			#bool		;	Whether the robot is connected or not.
function PeripheralApi:ping()
	--TODO: Implement.
	return true
end

------------------------------ API - System ------------------------------
---Quits this Love program.
-- @return			#bool		;	Always returns false, but if the quit event propgated fully program would simply exit before this returns.
function PeripheralApi:quit()
	--Any clean-up or state-saving code would go here.
	love.event.quit()
	return false	--Would only ever be returned if the quit event was cancelled.
end

---Self explanatory.
function PeripheralApi:rebootRemote()
	--TODO: Implement.
	--Halt the robot (check if it's moving and if so cancel all move commands.) then reboot.
	print("Rebooting remote!")
end

---Self explanatory.
function PeripheralApi:rebootRobot()
	--TODO: Implement.
	--Halt the robot (check if it's moving and if so cancel all move commands.) then reboot it. 
	print("Rebooting robot!")
end
------------------------------ Getters / Setters ------------------------------
--Are any needed here?

--You know how the robot works. Do you think I missed anything?
return PeripheralApi()
