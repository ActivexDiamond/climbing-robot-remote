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

------------------------------ Heleprs ------------------------------
local function clamp(x, min, max)
	--TODO: Test this. Might've made a typo or such.
	return math.min(x, math.max(x, min), max)
end

local function cleanUpArmArg(self, speed)
	speed = speed or self.armSpeed
	if not speed then
		print("Speed was not set!")
		return false
	end
	
	return clamp(speed, self.armSpeedMin, self.armSpeedMax)
end
------------------------------ Constructor ------------------------------
local PeripheralApi = class("PeripheralApi")
---This guy's constructor. I put what info I'm guessing this guy needs. Feel free to add/remove as you see fit.
-- Note: This guy is a singleton.
-- @param config				#table		;	A config table holding all the data needed for this class.
function PeripheralApi:init(config)
	self.ip = config.ip
	self.port = config.port
	self.target = self.ip .. ":" .. self.port		--unnecessary?
	
	--Constants.
	--Speeds.
	self.armSpeedMin = 0
	self.armSpeedMax = 255
	
	self.wheelRotAmountMin = 75
	self.wheelRotAmountMax = 255
	
	--Angle sets.
	self.cutterWormAngleIn = 0
	self.cutterWormAngleMax = 5
	
	self.cutterWheelAngleMin = 0
	self.cutterWheelAngleMax = 10
	
	--A bunch of defaults.
	--TODO: Change these to actual sensible defaults.
	--Speeds.
	self.armSpeed = 128
	self.wheelRotAmount = 155
	--Angle sets.
	self.cutterWormAngle = 0
	self.cutterWheelAngle = 0
end

------------------------------ API - Video ------------------------------
--Gets called inside love.draw (ideally at 60fps) and should draw the video stream onto the screen.
-- @param x						#number		;	Screen-coord to start drawing at.
-- @param y						#number		;	Screen-coord to start drawing at.
-- @param w						#number		;	Resolution in pixels.
-- @param h						#number		;	Resolution in pixels.
-- @param fps=maxxed-out		#number		; 	fps of the video. Should provide a default. Heck, you can skip implementing this one if you want.
function PeripheralApi:drawCnnVideoStream(x, y, w, h, fps)
	--TODO: Implement.
end

------------------------------ API - Sensors ------------------------------
---Use the gyroscope to check whether the robot is able to continue moving or has fallen over. 
-- Note: I'm guessing you either hardcode values into this, or slap some param in :init(config) to allow some tweaking for this?
-- @return 						#bool		;	Whether it has fallen.
function PeripheralApi:isFallen()
	--TODO: Implement.
	return false
end

---Returns the distance from the left ultrasonic to the nearest object. In centimeters.
-- @return 						#number		;	Distance in cm.
function PeripheralApi:readLeftUltrasonic()
	--TODO: Implement.
	return 20
end

---Returns the distance from the right ultrasonic to the nearest object. In centimeters.
-- @return 						#number		;	Distance in cm.
function PeripheralApi:readRightUltrasonic()
	--TODO: Implement.
	return 20
end

------------------------------ API - Networking ------------------------------
---Checks if the remote is currently connected to the robot. Returns a bool, not the delay.
-- @return 						#bool		;	Whether the robot is connected or not.
function PeripheralApi:ping()
	--TODO: Implement.
	return true
end

------------------------------ API - System ------------------------------
---Quits this Love program.
-- @return						#bool		;	Always returns false, but if the quit event propgated fully program would simply exit before this returns.
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

------------------------------ API - Movement - Arm ------------------------------
---Calls the AU commands with arg1=speed.
-- @param speed=self.armSpeed	#number		;	Arm speed. Maybe out of it's normal range, in which case it is clamped silently.
-- @return						#bool		;	If speed and self.armSpeed were both nil, fails (does nothing, no err). 
-- 		Return value reflects whether the command was sent to the robot or not.
-- 		NOT whether the robot actually responded/did it. The robot does NOT ping back.
function PeripheralApi:armUp(speed)
	speed = cleanUpArmArg(self, speed)
	if not speed then return false end
	--TODO: Replace this line with actual code.
	print("moved arm up by: " .. speed)
	return true	
end
---Same as armUp.
function PeripheralApi:armDown(speed)
	speed = cleanUpArmArg(self, speed)
	if not speed then return false end
	--TODO: Replace this line with actual code.
	print("moved arm down by: " .. speed)
	return true	
end
---Same as armUp.
function PeripheralApi:armForward(speed)
	speed = cleanUpArmArg(self, speed)
	if not speed then return false end
	--TODO: Replace this line with actual code.
	print("moved arm forwards by: " .. speed)
	return true	
end
---Same as armUp.
function PeripheralApi:armBackward(speed)
	speed = cleanUpArmArg(self, speed)
	if not speed then return false end
	--TODO: Replace this line with actual code.
	print("moved arm backwards by: " .. speed)
	return true	
end

------------------------------ API - Movement - Wheels ------------------------------
function PeripheralApi:wheelStop()
	print("Stopped all wheels.")
end
function PeripheralApi:wheelRight()
	print("Turning right.")
end
function PeripheralApi:wheelLeft()
	print("Turning left.")
end

------------------------------ API - Movement - Cutters ------------------------------
---Unlike the getters/setters below; those actually set the position of the cutters to their arg.
--		These are not some default-y or stateful setup.
-- @param deg=0						#number		;	Angle of the cutter-worm.
function PeripheralApi:setCutterWormAngle(deg)
	deg = deg or 0
	deg = clamp(deg, self.cutterWormAngleMin, self.cutterWormAngleMax)
	--Note: This variable is only kept so that the getter works which is only used
	--		to display this value to the user in the GUI. The robot does not actually allow
	--		getting the cutter angle.
	self.cutterWormAngle = deg
	print("Set the cutter-worm's angle to: " .. deg) 
end
function PeripheralApi:getCutterWormAngle()
	return self.cutterWormAngle
end

---Same concept as (set/get)cutterWormAngle.
-- @param deg=0						#number		;	Angle of the cutter-wheel.
function PeripheralApi:setCutterWheelAngle(deg)
	deg = deg or 0
	deg = clamp(deg, self.cutterWheelAngleMin, self.cutterWheelAngleMax)
	--Note: This variable is only kept so that the getter works which is only used
	--		to display this value to the user in the GUI. The robot does not actually allow
	--		getting the cutter angle.
	self.cutterWheelAngle = deg
	print("Set the cutter-wheels's angle to: " .. deg)
end
function PeripheralApi:getCutterWheelAngle()
	return self.cutterWheelAngle
end

------------------------------ Getters / Setters ------------------------------
---Sets the speed used by the arm movement methods which accept a speed arg.
--This will basically be a default for when they are called with no speed arg.
--If they are called with one, that takes priority.
--"speed" may be nil, but if it is, and an arm movement method is called (which requires
--	a speed-arg) is called with no args; a warning is shown to the user, with no action occuring. 
--This should allow values outside it's range, and simply clamp them.
function PeripheralApi:setArmSpeed(speed)
	self.armSpeed = speed
end
function PeripheralApi:getArmSpeed()
	return self.armSpeed
end

---Same concept as armSpeed.
function PeripheralApi:setWheelRotAmount(deg)
	self.wheelRotAmount = deg
end
function PeripheralApi:getWheelRotAmount()
	return self.wheelRotAmount
end

--You know how the robot works. Do you think I missed anything?
return PeripheralApi()
