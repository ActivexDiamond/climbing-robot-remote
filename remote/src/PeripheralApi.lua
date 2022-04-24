local class = require "libs.middleclass"
local lume = require "libs.lume"

local UdpApi = require "UdpApi"

local AppData = require "AppData"

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
			
	Single-quotes are used for strings used as enums or constant-codes.
	Double-quotes are used for all other strings.
	
	Indentation: tabs
	Tab: 4-spaces
	Comments: 
		Punctuated.
		No leading-space.
		Long-lines are used as titled seprators for sections.
		Short-lines are used as title seperators for sub-sections.
	
	Variable Naming Order:
		commands: category_module_group_action
		Everything else is named using English ordering rules.
--]]

------------------------------ Helprs ------------------------------
local function cleanUpArmArg(self, speed)
	speed = speed or self.armSpeed
	if not speed then
		print("Arm speed was not set!")
		return false
	end
	
	return lume.clamp(speed, self.ARM_SPEED_MIN, self.ARM_SPEED_MAX)
end

local function cleanUpWheelArg(self, deg)
	deg = deg or self.wheelRotAmount
	if not deg then
		print("Wheel rotation amount was not set!")
		return false
	end
	
	return lume.clamp(deg, self.WHEEL_ROT_AMOUNT_MIN, self.WHEEL_ROT_AMOUNT_MAX)
end

------------------------------ Private State ------------------------------
--Exclusively used by PeripheralApi:reconnect()
local lastReconnectTime = 0

------------------------------ Constructor ------------------------------
local PeripheralApi = class("PeripheralApi")
--Note: This class is a singleton.
function PeripheralApi:initialize()
	--UDP Related
	self.return_timeout = 3		--in ms
	self.reconnectCooldown = 2

	--TODO: Change these to more sensible defaults.
	--Defaults - Speeds.
	self.armSpeed = 135
	self.wheelRotAmount = 155
	
	--Defaults - Cutters
	self.cutterWormAngle = 0
	self.cutterWheelAngle = 0
end

------------------------------ Commands ------------------------------
---[cmds]					#table
--	Is a list of all valid commands for communication between all 3 devices.
--
--[cmds.x] (the key x)		#string			;	(herenby referred to as "command-name")
--	Is an alphanumeric word,
-- 		or words used to represent the action to be performed.
--	It is written as: category_module_group_action,
--		with any empty or non-relevant fields left empty.
--	It should be human-readable and descriptive of the action.
--	Lastly, it is used by both Pi devices (as WebSocket event names!) to direct
--		their logic and communicate.
--		
--[cmds.x] (the value of x)	#table
--	Is a table holding all data descriping the command in thorough detail.
--	
--[cmds.x.code]				#string
--	Is an abbreviated version of the command-name used to communicate
--		between the Pi 3 B (robot-based-server) and the Arduino Nano (robot-based-motor-controls.
--	It is abbreviated to compensate for the low-speed and high-error-chance of
--		the serial coms used to communicate with the Nano. 
--	Further, it is abbreviated to save precious space on the Nano to allow more
--		space for further expansion.
--		
--[cmds.x.args]				#number
--	Represents the number of arguments that the command requires.
--	As of this version, optional/default arguments are NOT supported.
--	
--[cmds.x.rt]				#bool
--	Whether the command requests a return value after it's execution or not.
--	Note that all commands which request a return value are blocking operations
--	
---Note: The [cmds.x.code] is NOT used by the remote in any way,
--	and it is not even aware of it's existence.
--It is only here to make debugging easier.
PeripheralApi.cmds = {
	arm_stop =					{code = "AS",		args = 0, rt = false},
	arm_forward =				{code = "AF",		args = 1, rt = false},
	arm_backward =				{code = "AB",		args = 1, rt = false},
	arm_up =					{code = "AU",		args = 1, rt = false},
	arm_down =					{code = "AD",		args = 1, rt = false},
	
	wheel_stop =				{code = "WS",		args = 0, rt = false},
	wheel_forward =				{code = "WF",		args = 1, rt = false},
	wheel_backward =			{code = "WB",		args = 1, rt = false},
	wheel_left =				{code = "WL",		args = 1, rt = false},
	wheel_right =				{code = "WR",		args = 1, rt = false},
	
	c_worm_set =				{code = "CWorm",	args = 1, rt = false},
	c_wheel_set =				{code = "CWheel",	args = 1, rt = false},

	sys_reboot =				{code = "SR",		args = 0, rt = false},
	
	sensor_ultrasonic_left = 	{code = "UL",		args = 0, rt = true},
	sensor_ultrasonic_right =	{code = "UR",		args = 0, rt = true},
	sensor_gyroscope_is_fallen ={code = "GF",		args = 0, rt = true},
}

------------------------------ Internals ------------------------------
function PeripheralApi:_sendCmd(cmdName, ...)
	local args = {...}
	local cmd = self.cmds[cmdName]
	if not cmd then
		local errStr = "Tried to execute [%s] and failed as command is invalid!" 
		print(errStr:format(cmdName))
		return false, "invalid-cmd"
	end
	if cmd.args ~= #args then
		local errStr = "Tried to execute [%s] with [%d args] and failed as command requires [%d args]"
		print(errStr:format(cmdName, #args, cmd.args))
		return false, "improper-args"
	end
	
	print("Exeucting command:", cmdName, table.concat(args))
	--Yes, this could be changes to "=< 1" -> "unpack",
	--	but this communicates the logic more cleanly.
	if cmd.args == 0 then
		UdpApi:send(cmdName)
	elseif cmd.args == 1 then
		--Commands with a single arg, get it sent in as is.
		UdpApi:send(cmdName, unpack(args))
	else
		--Commands with a more than 1 arg, get it sent in bunbled up in a table.
		UdpApi:send(cmdName, args)
	end
	
	if cmd.rt then
		return UdpApi:fetchReturn(self.return_timeout)
	else
		return nil, "got-nil: Command has no return value. It is running as expected."
	end
end

------------------------------ API - Hardware Constants ------------------------------
--Speed CLamps
PeripheralApi.ARM_SPEED_MIN = 0
PeripheralApi.ARM_SPEED_MAX = 255

PeripheralApi.WHEEL_ROT_AMOUNT_MIN = 75
PeripheralApi.WHEEL_ROT_AMOUNT_MAX = 255

--Angle Clamps
PeripheralApi.CUTTER_WORM_ANGLE_MIN = 0
PeripheralApi.CUTTER_WORM_ANGLE_MAX = 5

PeripheralApi.CUTTER_WHEEL_ANGLE_MIN = 0
PeripheralApi.CUTTER_WHEEL_ANGLE_MAX = 10
	
------------------------------ API - Video ------------------------------
--Gets called inside love.draw (ideally at 60fps) and should draw the video stream onto the screen.
-- @param x						#number		;	Screen-coord to start drawing at.
-- @param y						#number		;	Screen-coord to start drawing at.
-- @param w						#number		;	Resolution in pixels.
-- @param h						#number		;	Resolution in pixels.
-- @param fps=maxed-out		#number		; 	fps of the video. Should provide a default. Heck, you can skip implementing this one if you want.
function PeripheralApi:drawCnnVideoStream(x, y, w, h, fps)
	--TODO: Implement.
end

------------------------------ API - Sensors ------------------------------
---Use the gyroscope to check whether the robot is able to continue moving or has fallen over. 
-- Note: I'm guessing you either hardcode values into this, or slap some param in :init(config) to allow some tweaking for this?
-- @return 						#bool		;	Whether it has fallen.
function PeripheralApi:isFallen()
	return self:_sendCmd("sensor_gyroscop_is_fallen")
end

---Returns the distance from the left ultrasonic to the nearest object. In centimeters.
-- @return 						#number		;	Distance in cm.
function PeripheralApi:getLeftUltrasonic()
	return UdpApi:getUltrasonicLeftDistance()
end

---Returns the distance from the right ultrasonic to the nearest object. In centimeters.
-- @return 						#number		;	Distance in cm.
function PeripheralApi:getRightUltrasonic()
	return UdpApi:getUltrasonicRightDistance()
end

------------------------------ API - Networking ------------------------------
---Checks if the remote is currently connected to the robot. Returns a bool, not the delay.
-- @return 						#bool		;	Whether the robot is connected or not.
function PeripheralApi:ping()
	if AppData.DEBUG_PING_FORCE_TRUE then
		return true
	end

	return UdpApi:isConnected()
end

function PeripheralApi:reconnet()
	if love.timer.getTime() - lastReconnectTime > self.reconnectCooldown then
		lastReconnectTime = love.timer.getTime()
		UdpApi:reconnect()
	end
end

------------------------------ API - State ------------------------------
function PeripheralApi:getAutoState()
	--Check state of terrain and climbable obstacles.
	if self.currentState == (self.states and self.states[1] or nil) then
		return "Failed to identify terrain. Continuing to process CNN feed."
	else
		return self.states[self.currentState]
	end	
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
	--Halt the robot (check if it's moving and if so cancel all move commands.) then reboot.
	if AppData.CAN_REBOOT_REMOTE then
		self:armStop()
		self:wheelStop()
		os.execute("reboot")
	else
		print("Rebooting is currently disabled! To enable: Access <prj_loc>/remote/src/AppData.lua and change CAN_REBOOT_REMOTE to \"true\".")
	end
end

---Self explanatory.
function PeripheralApi:rebootRobot()
	--Halt the robot (check if it's moving and if so cancel all move commands.) then reboot it. 
	return self:_sendCmd("sys_reboot")
end

------------------------------ API - Movement - Arm ------------------------------
---Calls the AU commands with arg1=speed.
-- @param speed=self.armSpeed	#number		;	Arm speed. Maybe out of it's normal range, in which case it is clamped silently.
-- @return						#bool		;	If speed and self.armSpeed were both nil, fails (does nothing, no err). 
-- 		Return value reflects whether the command was sent to the robot or not.
-- 		NOT whether the robot actually responded/did it. The robot does NOT ping back.
function PeripheralApi:stopArm()
	return self:_sendCmd("arm_stop")
end

function PeripheralApi:moveArm(dir, speed)
	speed = cleanUpArmArg(self, speed)
	if not speed then return false end
	local cmdName = "arm_" .. dir
	return self:_sendCmd(cmdName, speed)
end

------------------------------ API - Movement - Wheels ------------------------------
function PeripheralApi:stopWheel()
	return self:_sendCmd("wheel_stop")
end

function PeripheralApi:moveWheel(dir, angle)
	angle = cleanUpWheelArg(self, angle)
	if not angle then return false end
	local cmdName = "wheel_" .. dir
	return self:_sendCmd(cmdName, angle)
end

------------------------------ API - Movement - Cutters ------------------------------
---Unlike the getters/setters below; those actually set the position of the cutters to their arg.
--		These are not some default-y or stateful setup.
-- @param deg=0						#number		;	Angle of the cutter-worm.
function PeripheralApi:setCutterWormAngle(angle)
	angle = angle or 0
	angle = lume.clamp(angle, self.CUTTER_WORM_ANGLE_MIN, self.CUTTER_WORM_ANGLE_MAX)
	self.cutterWormAngle = angle
	self:_sendCmd("c_worm_set", angle)
end
function PeripheralApi:getCutterWormAngle()
	return self.cutterWormAngle
end

---Same concept as (set/get)cutterWormAngle.
-- @param deg=0						#number		;	Angle of the cutter-wheel.
function PeripheralApi:setCutterWheelAngle(deg)
	deg = deg or 0
	deg = lume.clamp(deg, self.CUTTER_WHEEL_ANGLE_MIN, self.CUTTER_WHEEL_ANGLE_MAX)
	self.cutterWheelAngle = deg
	self:_sendCmd("c_wheel_set", deg)
end
function PeripheralApi:getCutterWheelAngle()
	return self.cutterWheelAngle
end

------------------------------ Getters / Setters ------------------------------
---Sets the speed used by the arm movement methods which accept a speed arg.
--This will basically be a default for when they are called with no speed arg.
--If they are called with one, that takes priority.
--This should allow values outside it's range, and simply clamp them.
function PeripheralApi:setArmSpeed(speed)
	self.armSpeed = lume.clamp(speed, self.ARM_SPEED_MIN, self.ARM_SPEED_MAX)
end

function PeripheralApi:getArmSpeed()
	return self.armSpeed
end

---Same concept as armSpeed.
function PeripheralApi:setWheelRotAmount(deg)
	self.wheelRotAmount = lume.clamp(deg, self.WHEEL_ROT_AMOUNT_MIN,self.WHEEL_ROT_AMOUNT_MAX)
end

function PeripheralApi:getWheelRotAmount()
	return self.wheelRotAmount
end

return PeripheralApi()
