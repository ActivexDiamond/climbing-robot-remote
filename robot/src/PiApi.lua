local class = require "libs.middleclass"

local AppData = require "AppData"

--Guard-clause for when running on a dev-machine, not an actual Pi,
--Periphery will not be installed and all calls to it's API will be
--	forwarded to blank versions.
--This facilitates development on non-Pi machines. 
local Serial, Gpio
do
	local succ, msg = pcall(require, "periphery")
	if succ then
		print("Loading Lua-Periphery for board functions")
		Serial = require("periphery").Serial
		Gpio = require("periphery").GPIO
	else
		print("Lua-Periphery not found. Loading a dummy version.")
		Serial = require("dummyPeriphery").Serial
		Gpio = require("dummyPeriphery").GPIO
		print(Serial)
		print(Serial(0, 9600))
	end
end

------------------------------ Helpers ------------------------------
local function microsecondSleep(ms)
	love.timer.sleep(ms / 1e6)
end

local function TimeoutTimer(timeout)
	return {
		timeout = timeout,
		startTime = love.timer.getTime(),
		
		shouldAbort = function(self)
			return love.timer.getTime() - self.startTime > self.timeout
		end,
		reset = function(self)
			self.startTime = love.timer.getTime()
		end,
	}
end

local function readPulseLength(pin, timeoutTimer)
	local failed = false
	local startTime, endTime
	local getTime = love.timer.getTime		--Localize to optimize call.
	--Read the length of the pulse from when the pin goes high,
	--	till when it comes back low.
	timeoutTimer:reset()
	while not pin:read() do
		if timeoutTimer:shouldAbort() then
			failed = true
			break
		end
		startTime = getTime()
	end
	timeoutTimer:reset()
	while pin:read() do
		if timeoutTimer:shouldAbort() then
			failed = true
			break
		end
		endTime = getTime()
	end
	return failed and 0 or endTime - getTime
end

------------------------------ Constructor ------------------------------
local PiApi = class("PiApi")
--Note: This class is a singleton.
function PiApi:initialize()
	self.ULTRASONIC_READ_TIMEOUT = 1000 / 1e6 --microseconds
	self.ultrasonicTimeoutTimer = TimeoutTimer(self.ULTRASONIC_READ_TIMEOUT)
	self:_initSerial()
	self:_initGpio()
end

------------------------------ Commands ------------------------------
PiApi.hardware = {
	pins = {
		ultrasonicLeftTrig = 	"GPIO.24",
		ultrasonicLeftEcho = 	"GPIO.25",
		 
		ultrasonicRightTrig = 	"GPIO.26",
		ultrasonicRightEcho = 	"GPIO.27",
		
		gyroscopeSda = 			"SDA.0",
		gyroscopeScl = 			"SDA.1",
	},
	
	modules = {
		ultrasonic =	{moduleTag = "HC-SR04",											count = 2,		groups = {'left',	'right'}		},
		gyroscope =		{moduleTag = "MPU9265",											count = 1,		groups = {}							},
		nano =			{moduleTag = "Arduino Nano ATMega368 (old bootloader)",			count = 3,		groups = {'usb',	'nc',	'nc'}	},
		},

	serial = {
		port = "dev/ttyUSB0",
		baudrate = 9600,
		eol = "\n",
		eoc = ";",
	},
}

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
	sensor_gyroscope_is_fallen ={code = "GF",		args = 0, rt = true},
}

------------------------------ Internals ------------------------------
---Sets up serial state. Must be called before any serial method becomes valid.
--Calling serial methods before this may or may not raise an error,
--	but is guranteed to fail.
function PiApi:_initSerial()
	local cfg = self.hardware.serial
	self.serial = Serial(cfg.port, cfg.baudrate)
	self.serial.eoc = cfg.eoc
end

---Recives a valid command name, converts it to it's respective code,
--	appends terminating characters and then transmits it to the Nano.
--Note: No validation is done on the cmdName, must be done by the user.
function PiApi:_transmitSerialCmd(code, ...)
	local args = {...}
	local str = code .. self.serial.eoc
	for i = 1, #args do
		str = str .. args[i] .. self.serial.eoc
	end
	print("Writing command to serial: " .. str)
	self.serial:write(str)	
end

---Sets up GPIO state for all pins in active use.
function PiApi:_initGpio()
	local pins = self.hardware.pins
	self.gpio = {
		ultrasonic = {
			left = {
				trig = Gpio(pins.ultrasonicLeftTrig, 'out'),
				echo = Gpio(pins.ultrasonicLeftEcho, 'in'),
			},
			right = {
				trig = Gpio(pins.ultrasonicRightTrig, 'out'),
				echo = Gpio(pins.ultrasonicRightEcho, 'in'),
			},
		},
	}
end

---Returns the distance-value of an ultrasonic sensor. Module in use: HC-SR04
-- @param target					#string		;	One of 'left' or 'right'.
-- @return							#number		;	Distance in centimeters.
function PiApi:_readUltrasonic(target)
	--Grab the correct target.
	local trig = self.gpio.ultrasonic[target].trig
	local echo = self.gpio.ultrasonic[target].echo
	--Clear out the trigger pin, giving it 2ms to do so.
	trig:write(false)
	microsecondSleep(2)
	--Send a 10ms long pulse to the trgger pin.
	trig:write(true)
	microsecondSleep(10)
	trig:write(false)
	
	--Read the length of the response pulse.
	local len = readPulseLength(echo, self.ultrasonicTimeoutTimer)
	--Speed of sound in air, in centimeters, divided be 2, as the wave must travel to and fro.
	local dist = len * 0.034 / 2
	local str = string.format("Distance to [%s] ultrasonic is %fcm.",
			target, dist)
	print(str)
	--TODO: Test this out on real hardware and confirm the results.
end

---Returns the raw-reading of the gyroscope value. Module in use: MPU9265
function PiApi:_readGyroscope()
	--TODO: Implement.
end

------------------------------ API - System Specs ------------------------------
function PiApi:getCpuTemp()
	--TODO: Implement
	return "-1'C"
end

function PiApi:getGpuTemp()
	--TODO: Implement
	return "-1'C"
end

function PiApi:getCpuLoad()
	--TODO: Implement
	return "-1%"
end

function PiApi:getGpuLoad()
	--TODO: Implement
	return "-1%"
end

function PiApi:getRamUsage()
	--TODO: Implement
	return "0GB/0GB"
end

function PiApi:getDiskUsage()
	--TODO: Implement
	return "0GB/0GB"
end

------------------------------ API - System ------------------------------
---Quits this Love program.
-- @return						#bool		;	Always returns false, but if the quit event propgated fully program would simply exit before this returns.
function PiApi:quit()
	--Any clean-up or state-saving code would go here.
	love.event.quit()
	return false	--Would only ever be returned if the quit event was cancelled.
end

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
	self:_transmitSerialCmd(self.cmds.arm_forward.code, speed)
end

---Set the arm to move backwards at "speed" velocity.
function PiApi:armBackward(speed)
	self:_transmitSerialCmd(self.cmds.arm_backward.code, speed)
end

---Set the arm to move upwards at "speed" velocity.
function PiApi:armUp(speed)
	self:_transmitSerialCmd(self.cmds.arm_up.code, speed)
end

---Set the arm to move downwards at "speed" velocity.
function PiApi:armDown(speed)
	self:_transmitSerialCmd(self.cmds.arm_down.code, speed)
end

------------------------------ API - Wheel ------------------------------
---Halt all chasis (wheel) movement.
function PiApi:wheelStop()
	self:_transmitSerialCmd(self.cmds.wheel_stop.code)
end

---Move the chasis forwards at "speed" velocity.
function PiApi:wheelForward(speed)
	self:_transmitSerialCmd(self.cmds.wheel_forward.code, speed)
end

---Move the chasis backwards at "speed" velocity.
function PiApi:wheelBackward(speed)
	self:_transmitSerialCmd(self.cmds.wheel_backward.code, speed)
end

---Turn the chasis left at "speed" velocity.
function PiApi:wheelLeft(speed)
	self:_transmitSerialCmd(self.cmds.wheel_left.code, speed)
end

---Turn the chasis right at "speed" velocity.
function PiApi:wheelRight(speed)
	self:_transmitSerialCmd(self.cmds.wheel_right.code, speed)
end

-------------------------------- API - Cutters ------------------------------
---Set the angle of the cutter worm to "angle".
function PiApi:setCutterWormAngle(angle)
	self:_transmitSerialCmd(self.cmds.c_worm_set.code, angle)
end

---Set the angle of the cutter wheel to "angle".
function PiApi:setCutterWheelAngle(angle)
	self:_transmitSerialCmd(self.cmds.c_wheel_set.code, angle)
end

-------------------------------- API - Sensors ------------------------------
---Returns the distance-value of the left ultrasonic sensor.
-- @return						#number		;	Distance in centimeters.
function PiApi:readUltrasonicLeft()
	return self:_readUltrasonic('left')
end

---Returns the distance-value of the right ultrasonic sensor.
-- @return							#number		;	Distance in centimeters.
function PiApi:readUltrasonicRight()
	return self:_readUltrasonic('right')
end

---Returns whether the robot has tipped over too far to be able to manuever or not.
-- @return						#bool		;	Whether the robot can no longer manuever or not.
function PiApi:isFallen()
	local data = self:readGyroscope()
	--TODO: Implement.
end

return PiApi()
