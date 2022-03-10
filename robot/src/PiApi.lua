local class = require "libs.middleclass"

------------------------------ Constructor ------------------------------
local PiApi = class("PiApi")
--Note: This class is a singleton.
function PiApi:initialize()
end

------------------------------ Commands ------------------------------
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

end
---Recives a valid command name, converts it to it's respective code,
--	appends terminating characters and then transmits it to the Nano.
--Note: No validation is done on the cmdName, must be done by the user.
function PiApi:_transmitSerialCmd(cmdName)

end

---Sets up GPIO state for all pins in active use.
function PiApi:_initGpio()

end

---Returns the distance-value of an ultrasonic sensor.
-- @param target					#string		;	One of 'left' or 'right'.
-- @return							#number		;	Distance in centimeters.
function PiApi:_readUltrasonic(target)

end

------------------------------ Api ------------------------------
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

return PiApi
