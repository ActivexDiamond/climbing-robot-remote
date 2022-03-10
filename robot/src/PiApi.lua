local class = require "libs.middleclass"

local AppData = require "AppData"

------------------------------ Constructor ------------------------------
local PiApi = class("PiApi")
--Note: This class is a singleton.
function PiApi:initialize()
	--TODO: Implement.
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
PiApi.cmds = {
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
	sensor_gyro_is_fallen =		{code = "GF",		args = 0, rt = true},
}

------------------------------ Internals ------------------------------
---Sets up serial state. Must be called before any serial method becomes valid.
--Calling serial methods before this may or may not raise an error,
--	but is guranteed to fail.
function PiApi:_initSerial()
	--TODO: Implement.
end

---Recives a valid command name, converts it to it's respective code,
--	appends terminating characters and then transmits it to the Nano.
--Note: No validation is done on the cmdName, must be done by the user.
function PiApi:_transmitSerialCmd(cmdName)
	--TODO: Implement.
end

---Sets up GPIO state for all pins in active use.
function PiApi:_initGpio()
	--TODO: Implement.
end

---Returns the distance-value of an ultrasonic sensor. Module in use: HC-SR04
-- @param target					#string		;	One of 'left' or 'right'.
-- @return							#number		;	Distance in centimeters.
function PiApi:_readUltrasonic(target)
	--TODO: Implement.
end

---Returns the raw-reading of the gyroscope value. Module in use: MPU9265
function PiApi:_readGyro()
	--TODO: Implement.
end

------------------------------ API - Sys ------------------------------
function PiApi:reboot()
	--Halt the robot (check if it's moving and if so cancel all move commands.) then reboot.
	if AppData.CAN_REBOOT_ROBOT then
		self:armStop()
		self:wheelStop()
		os.execute("reboot")
	else
		print("Rebooting is currently disabled! To enable: Access <prj_loc>/remote/src/AppData.lua and change CAN_REBOOT_ROBOT to \"true\".")
	end
end	

------------------------------ API - Arm ------------------------------
---Halt all arm movement.
function PiApi:armStop()
	self:_transmitSerialCmd(self.cmds.arm_stop.code)
end

---Set the arm to move forwards at "speed" velocity.
function PiApi:armForward(speed)
	self:_transmitSerialCmd(self.cmds.arm_forward.code)
	self:_transmitSerialCmd(speed)
end

---Set the arm to move backwards at "speed" velocity.
function PiApi:armBackward(speed)
	self:_transmitSerialCmd(self.cmds.arm_backward.code)
	self:_transmitSerialCmd(speed)
end

---Set the arm to move upwards at "speed" velocity.
function PiApi:armUp(speed)
	self:_transmitSerialCmd(self.cmds.arm_up.code)
	self:_transmitSerialCmd(speed)
end

---Set the arm to move downwards at "speed" velocity.
function PiApi:armDown(speed)
	self:_transmitSerialCmd(self.cmds.arm_down.code)
	self:_transmitSerialCmd(speed)
end

------------------------------ API - Wheel ------------------------------
---Halt all chasis (wheel) movement.
function PiApi:wheelStop()
	self:_transmitSerialCmd(self.cmds.wheel_stop.code)
end

---Move the chasis forwards at "speed" velocity.
function PiApi:wheelForward(speed)
	self:_transmitSerialCmd(self.cmds.wheel_forward.code)
	self:_transmitSerialCmd(speed)
end

---Move the chasis backwards at "speed" velocity.
function PiApi:wheelBackward(speed)
	self:_transmitSerialCmd(self.cmds.wheel_backward.code)
	self:_transmitSerialCmd(speed)
end

---Turn the chasis left at "speed" velocity.
function PiApi:wheelleft(speed)
	self:_transmitSerialCmd(self.cmds.wheel_left.code)
	self:_transmitSerialCmd(speed)
end

---Turn the chasis right at "speed" velocity.
function PiApi:wheelright(speed)
	self:_transmitSerialCmd(self.cmds.wheel_right.code)
	self:_transmitSerialCmd(speed)
end

-------------------------------- API - Cutters ------------------------------
---Set the angle of the cutter worm to "angle".
function PiApi:setCutterWormAngle(angle)
	self:_transmitSerialCmd(self.cmds.c_worm_set.code)
	self:_transmitSerialCmd(angle)	
end

---Set the angle of the cutter wheel to "angle".
function PiApi:setCutterWheelAngle(angle)
	self:_transmitSerialCmd(self.cmds.c_wheel_set.code)
	self:_transmitSerialCmd(angle)	
end

-------------------------------- API - Sensors ------------------------------
---Returns the distance-value of the left ultrasonic sensor.
-- @return						#number		;	Distance in centimeters.
function PiApi:getUltrasonicLeft()
	return self:_readUltrasonic('left')
end

---Returns the distance-value of the right ultrasonic sensor.
-- @return							#number		;	Distance in centimeters.
function PiApi:getUltrasonicRight()
	return self:_readUltrasonic('right')
end

---Returns whether the robot has tipped over too far to be able to manuever or not.
-- @return						#bool		;	Whether the robot can no longer manuever or not.
function PiApi:isFallen()
	local data = self:readGyro()
	--TODO: Implement.
end

return PiApi
