Compilation of all code for project ClimbingRobot2.0

/////////////////Entering file: ChonkyBoi.ini/////////////////
[pi 3 B]
camera recording
image processing
making decisions when in auto mode
streaming all that info to the remote
receiving commands from the remote

[Arduino nano]
managing the motors (at a low level via the motor API)

The nano exposes an interface accessed via commands sent over the serial bus. 

There are commands to:
1- Move each motor seperately. Clockwise and counterclockwise.
2- Modify the speed of each motor seperately. 
3- Move each arm motor seperately. 
4- Modify the speed of each arm motor seperately.

[two Ultrasonic sensors] (front left and front right)
see ahead of the robot as well as to position myself perpendicular to any obstacles I intend to climb
; The 2 ultrasonics at the front are used to position himself correctly relevent to the obstacles he intends to climb. 

[Pi camera rev 1.3]
This is used for object detection (it detects and points out a few everyday objects as well as the 4 types of obstacles it can climb.)
; https://iotdesignpro.com/projects/raspberry-pi-object-detection-using-tensorflow-and-opencv
; I followed this for the object detection.

; The camera is used for the CNN and also for manually controlling the robot (so you can see from the comfort of your chair)



[deps]
TensorFlow for the CNN / object detection
OpenCV to speed up the above
And a few pre-trained models based on the COCO dataset (a large free dataset with 330k labelled images for everyday items)

[CNN bullshit]
I then also further trained that model adding in the 4 types of obstacles it can climb so it knows when it finds one and initiates the  appropriate climbing routine.
; (This is mostly a lie. It can't detect obstacles. I have to manually tell it. It can climb on its own after that, though.)
; But to justify it scientifically: Can you write a paragraph about how this is an example/placeholder and for future expansion our CNN can be trained with a dataset matching the environment we expect the robot to be traversing. 
; E.g. if we intend to have military usages we can train it to detect landmines, broken walls, weapons, etc...

[obstacles it can climb]
- A big boy box
- A big boy cylinder
; Both of those are as wide (or more) as the robot, as deep (or more) as the robot. And have a height of 20cm 

- A stair... Like... 2 steps max 5 cm each.... 
- A gap in the ground... 20cm... Like... Barely a dent. 

;So the above is actually the real capabilities of the guy (the client knows - no lies here). Can you make it sound better though? Like I don't mean lie but just phrase it nicely. For example skip the whole "as deep and as wide as him" part and just mention "It is capable of climbing and overcoming cylinder or cuboid obstacles with a height of 20cm or less." kind of thing.



[remote hardware]
4inch pi touchscreen
Pi zero W (might switch to a pi 3 B still not sure)
Simple lipo battery + charger. 

[remote software]
Home page

Manual mode
; (the CNN is turned off in manual mode as it can only handle like 1.2fps)

Obstacle climbing mode (if it can detect any of the 4 in front of it, it'll climb them.) 

constant camera feed

; the 2 pi's communicate over a local WiFi network



/////////////////Exiting file: ChonkyBoi.ini/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: nano_interface.ini/////////////////
[PINOUT]
WheelLeft   = A0
WheelRight  = A1
CutterWheel = A2
CutterWorm  = A3


[SUBSTRING COMMANDS]
AS			    = ArmStop

AF				  = ArmForward
AB				  = ArmBackward
AU				  = ArmUp
AD				  = ArmDown
speed		    int[0-255]      arduino PWM aka speed-percentile)

WS				  = WheelStop

WF				  = WheelForward
WB				  = WheelBackward
WL				  = WheelLeft
WR				  = WheelRight
degrees       int[75-255]   degrees for the wheel to turn. This is mapped to [90, 0]

CWorm		    = CutterWorm
cworm angle	  int[0, 5]     angle to set the cworm to. This is mapped to [10, 170]

CWheel      = CutterWheel
cwheel angle  int[0, 10]	  angle to set the cwheel to. This is mapped to [0, 180]


/////////////////Exiting file: nano_interface.ini/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: AppData.lua/////////////////
local AppData = {
	--Version
	MAJOR_VERSION = 1,
	MINOR_VERSION = 0,
	PATCH_VERSION = 0,
	PHASE = "beta",
	
	--Title
	PROJECT_NAME = "Robot Controller",
	
	--Directories
	ASSET_DIR = "assets/",
	
	--Networking Related
	openIp = "*",
	targetIp = nil,			--Set by _fetchTarget below.
	port = 9000,
	PING_INTERVAL = 1,
	PINGS_BEFORE_TIMEOUT = 3,
	
	--Target IP Config Related
	TARGET_IP_CONFIG_FILE = "target_ip.cfg",
	TARGET_IP_CONFIG_DEFAULT = "localhost",
	
	--Priviliages
	CAN_REBOOT_REMOTE = false,
	CAN_REBOOT_ROBOT = false,
}

function AppData:getVersionString()
	if self.PATCH_VERSION == 0 then
		return self.MAJOR_VERSION .. "." .. self.MINOR_VERSION ..
				"-" .. self.PHASE 
	else
		return self.MAJOR_VERSION .. "." .. self.MINOR_VERSION .. 
				"." .. self.PATCH_VESRSION "-" .. self.PHASE
	end
end

function AppData:_fetchTarget()
	local file = love.filesystem.newFile(self.TARGET_IP_CONFIG_FILE)
	file:open('r')
	self.targetIp = file:read()
	file:close()
	if not self.targetIp or #self.targetIp < 1 then
		self.targetIp = self.TARGET_IP_CONFIG_DEFAULT
	end
end

function AppData:updateTarget(newTarget)
	local file = love.filesystem.newFile(self.TARGET_IP_CONFIG_FILE)
	file:open("w")
	file:write(newTarget)
	file:close()
	
	self:_fetchTarget()		
end

AppData:_fetchTarget()
return AppData

/////////////////Exiting file: AppData.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: PeripheralApi.lua/////////////////
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


/////////////////Exiting file: PeripheralApi.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: PiApi.lua/////////////////
local class = require "libs.middleclass"

--[[
	Check PeripheralApi for a description of what the hell this is.
	
	Should this handle network init and such? Stick that in the PeripheralApi? Have a dedicated one? Up to you.
--]]
------------------------------ Constructor ------------------------------
local PiApi = class("PiApi")
function PiApi:initialize()
end

------------------------------ API ------------------------------


------------------------------ Getters / Setters ------------------------------

return PiApi()


/////////////////Exiting file: PiApi.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: UdpApi.lua/////////////////
local class = require "libs.middleclass"
local sock = require "libs.sock"

local AppData = require "AppData"


------------------------------ Heleprs ------------------------------

------------------------------ Constructor ------------------------------
local UdpApi = class("UdpApi")
--Note: This class is a singleton.
function UdpApi:initialize()
	self.ultrasonicLeftDistance = 0
	self.ultrasonicRightDistance = 0

	self.lastPing = 0
	self:reloadPeer()
end

------------------------------ Core API ------------------------------
function UdpApi:update(dt)
	self.rtVal = nil		--Clear any old unclaimed rtVals.
	self.client:update(dt)
	local timeout = AppData.PING_INTERVAL * AppData.PINGS_BEFORE_TIMEOUT
	if not self.client:isConnecting() and
			love.timer.getTime() - self.lastPing > timeout then
		self.client:disconnectNow()
	end
end

------------------------------ API ------------------------------
function UdpApi:reloadPeer()
	self.targetIp = AppData.targetIp
	self.port = AppData.port
	self.timeout = AppData.CONNECTION_TIMEOUT
	self:connect()
	self.lastPing = love.timer.getTime()
end

function UdpApi:connect()
	self.client = sock.newClient(self.targetIp, self.port)
	self.client:setTimeout(self.timeout)
	self:_injectEvents()
	self.client:connect()
end

function UdpApi:reconnect()
	if not (self.client:isConnected() or self.client:isConnecting()) then
		print("Reconnecting")
		self.client:connect()
	end	
end

function UdpApi:isConnected()
	return self.client:isConnected()
end

--- Attempt to fetch the rtVal produced by the last event sent.
-- @return 						#bool		;	Success.
-- @return 						#any		;	err-msg if failed. rtVal otherwise.
function UdpApi:fetchReturn(timeout)
	local startTime = love.timer.getTime()
	while self.rtVal == nil do
		self.client:update()
		if love.timer.getTime() - startTime > timeout then
			return false, "timed-out: Spent too long waiting for return value."
		end
	end
	--Clear the rtVal single-val buffer before returning.
	local rtVal = self.rtVal
	self.rtVal = nil
	return true, self.rtVal
end

function UdpApi:send(ev, data)
	self.client:send(ev, data)
end

------------------------------ Internals ------------------------------
function UdpApi:_injectEvents()
	
	for ev, callback in pairs(self.events) do
		self.client:on(ev, function(...) callback(self, ...) end)
	end
end

------------------------------ Getters / Setters ------------------------------
function UdpApi:getUltrasonicLeftDistance()
	return self.ultrasonicLeftDistance
end

function UdpApi:getUltrasonicRightDistance()
	return self.ultrasonicRightDistance
end

------------------------------ Events ------------------------------
UdpApi.events = {}

function UdpApi.events:connect()
	self.lastPing = love.timer.getTime()
	print("Successfully established a connection to: ", self.targetIp, self.port)
end

function UdpApi.events:disconnect()
	print("Disconnected from the server.")
end

function UdpApi.events:ping(timeStamp)
	self.lastPing = love.timer.getTime()
end

function UdpApi.events:rt(val)
	self.rtVal = val
end

function UdpApi.events:sensor_ultrasonic_left(dist)
	self.ultrasonicLeftDistance = dist
end

function UdpApi.events:sensor_ultrasonic_right(dist)
	self.ultrasonicRightDistance = dist
end

return UdpApi()

--[[
send cmd
rt vals
connect
reload ip + connect
timeout connection attempt


--]]

/////////////////Exiting file: UdpApi.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: conf.lua/////////////////
function love.conf(t)
  -- Commented out defaults shown below.
  -- See https://www.love2d.org/wiki/Config_Files for more information.

   t.identity = "robot_control"                    -- The name of the save directory (string)
   t.version = "11.1"                -- The L�VE version this game was made for (string)
  -- t.console = false                   -- Attach a console (boolean, Windows only)
   t.accelerometerjoystick = false      -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
  -- t.externalstorage = false           -- True to save files (and read from the save directory) in external storage on Android (boolean) 
  -- t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)

   t.window.title = "Robot Control"         -- The window title (string)
  -- t.window.icon = nil                 -- Filepath to an image to use as the window's icon (string)
   t.window.height = 320               -- The window height (number)
   t.window.width = 480                -- The window width (number)
   t.window.borderless = true         -- Remove all border visuals from the window (boolean)
  -- t.window.resizable = false          -- Let the window be user-resizable (boolean)
  -- t.window.minwidth = 1               -- Minimum window width if the window is resizable (number)
  -- t.window.minheight = 1              -- Minimum window height if the window is resizable (number)
  -- t.window.fullscreen = false         -- Enable fullscreen (boolean)
  -- t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
  -- t.window.vsync = true               -- Enable vertical sync (boolean)
  -- t.window.msaa = 0                   -- The number of samples to use with multi-sampled antialiasing (number)
  -- t.window.display = 1                -- Index of the monitor to show the window in (number)
  -- t.window.highdpi = false            -- Enable high-dpi mode for the window on a Retina display (boolean)
   t.window.x = 0                    -- The x-coordinate of the window's position in the specified display (number)
   t.window.y = 0                    -- The y-coordinate of the window's position in the specified display (number)

   t.modules.audio = false              -- Enable the audio module (boolean)
  -- t.modules.event = true              -- Enable the event module (boolean)
  -- t.modules.graphics = true           -- Enable the graphics module (boolean)
  -- t.modules.image = true              -- Enable the image module (boolean)
   t.modules.joystick = false           -- Enable the joystick module (boolean)
  -- t.modules.keyboard = true           -- Enable the keyboard module (boolean)
  -- t.modules.math = true               -- Enable the math module (boolean)
  -- t.modules.mouse = true              -- Enable the mouse module (boolean)
   t.modules.physics = false            -- Enable the physics module (boolean)
   t.modules.sound = false              -- Enable the sound module (boolean)
  -- t.modules.system = true             -- Enable the system module (boolean)
  -- t.modules.timer = true              -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
  -- t.modules.touch = true              -- Enable the touch module (boolean)
  -- t.modules.video = true              -- Enable the video module (boolean)
  -- t.modules.window = true             -- Enable the window module (boolean)
   t.modules.thread = false             -- Enable the thread module (boolean)
end


/////////////////Exiting file: conf.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ClassTemplate.lua/////////////////
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


/////////////////Exiting file: ClassTemplate.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ConsoleStringBuilder.lua/////////////////
local class = require "libs.middleclass"
local utils = require "libs.utils"

------------------------------ Constructor ------------------------------
local ConsoleStringBuilder = class("ConsoleStringBuilder")
function ConsoleStringBuilder:initialize(lines, charsPerLine)
	self.lines = lines
	self.charsPerLine = charsPerLine
	
	self.str = ""
end

------------------------------ API ------------------------------
function ConsoleStringBuilder:print(...)
	local args = {...}
	local str = ""
	if #args == 0 then
		str = "\n"
	else
		for k, v in ipairs(args) do
			str = str .. v .. " "
		end
		str = str:sub(1, -2)	--Remove trailing space.
	end
	self:_addString(str)
end

function ConsoleStringBuilder:clear()
	self.str = ""
end

------------------------------ Internals ------------------------------
function ConsoleStringBuilder:_addString(str)
	for i = 1, #str do
		local c = str:sub(i, i)
		self.str = self.str .. c
		--print(#self.str)
		if self:getRealStrLen() % self.charsPerLine == 0 then
			--print("str mod 0")
			self.str = self.str .. "\n"
			if self:getRealStrLen() == self.lines * self.charsPerLine then
				--print("out of screen")
				self.str = self.str:sub(self.charsPerLine + 2)
			end
		end
	end
end

------------------------------ Getters / Setters ------------------------------
function ConsoleStringBuilder:getContent()
	return self.str
end

--Returns the length of the screen counting only chars that are drawable
--	onto the screen. Currently, only removes "\n", sadly.
function ConsoleStringBuilder:getRealStrLen()
	return #utils.str.rem(self.str, "\n")
end


return ConsoleStringBuilder

/////////////////Exiting file: ConsoleStringBuilder.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: FilepathUtils.lua/////////////////
local FilepathUtils = {}

FilepathUtils.love = {}
FilepathUtils.love.path = {}
FilepathUtils.love.path.src = ""
FilepathUtils.love.path.saves = nil

FilepathUtils.love.path.istatsData = FilepathUtils.love.path.src .. "/istats/data/"
FilepathUtils.love.path.istatsDefaults = FilepathUtils.love.path.src .. "/istats/defaults/"
--FilepathUtils.love.path.istatsDefaultsIdv = FilepathUtils.love.path.src .. "/istats/defaults/idv/"
--FilepathUtils.love.path.istatsDefaultsInstv = FilepathUtils.love.path.src .. "/istats/defaults/instv/"

--FilepathUtils.lua = {}
--FilepathUtils.lua.path = {}
--FilepathUtils.lua.path.src = "src"
--FilepathUtils.lua.path.saves = nil
--
--FilepathUtils.lua.path.istatsData = FilepathUtils.lua.path.src .. "/istats/data/"

return FilepathUtils

/////////////////Exiting file: FilepathUtils.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Scheduler.lua/////////////////
local class = require "libs.cruxclass"

------------------------------ Helper Methods ------------------------------
local getTime = love.timer.getTime
local ins = table.insert
local rem = table.remove
local modf = math.modf
local floor = math.floor

local function findIndex(t, obj)
	for k, v in ipairs(t) do
		if obj == v then return k end
	end
	return false
end

local function execute(t, dt, i, interval, timeout, func, args)
	args = type(args) == 'table' and args or {args}
	if dt then 
		t.tdt[i] = t.tdt[i] + dt
		local r = interval == -1 and 0 or interval
		local per = math.min(t.tdt[i] / (timeout - r), 1)
		func(dt, per, unpack(args))
	else func(unpack(args)) end
end

local function remove(t, i)
	rem(t.wait,     i)
	rem(t.interval, i)
	rem(t.timeout,  i)
	rem(t.stamp,    i)
	rem(t.tdt,      i)
	rem(t.flag,     i)
	rem(t.last,     i)
	rem(t.runs,     i)
	rem(t.func,     i)
	rem(t.args,     i)
	rem(t.wrapup,   i)
	rem(t.wargs,    i)
end

local function yield(t, i)
	if t.wrapup[i] then execute(nil, nil, nil, nil, nil, t.wrapup[i], t.wargs[i]) end
	remove(t, i)
end

local function process(t, dt, i, wait, interval, timeout, stamp, flag, last, runs, func, args)
	local time = getTime()
	
	if time >= stamp + wait then								--If (at or post 'wait'); proceed 
		if interval == 0 then									--	If 'interval' == 0; single execution
			local dt = time - stamp								--
			execute(t, dt, i, interval, timeout, func, args)	--		Execute once; 'fdt' = time since initial scheduling
			return true											--		Yield
		elseif timeout == 0 or time <= stamp + timeout then		--	If (no timeout is set) or (within timeout); proceed
			if interval == -1 then								--		If interval == -1; execute every tick
				local fdt = flag == 0 and dt or time - stamp	--			'fdt' = (first run) ? tick-dt : time since initial scheduling 
				t.flag[i] = 0									--			Set 'first run' flag
				execute(t, fdt, i, interval, timeout, func, args)--			Execute
			else												--		If 'interval' set (not 0 and not -1); execute every 'interval' for 'timeout'
				local fdt, dif, reruns							--			[1]elaborated below
				if flag == -1 then								--
					fdt = time - stamp							--
					dif = time - stamp - wait					--
				else											--
					fdt = time - last							--
					dif = time - flag							--
				end												--
																--
				reruns = floor(dif / interval)					--
				dif = dif % interval							--
				if flag == -1 then reruns = reruns + 1 end		--
																--
--				print('dt', dt, 'fdt', fdt, 'dif', dif, 'flag', flag, 'reruns', reruns, 'interval', interval)
				for _i = 1, reruns do							--
					execute(t, _i == 1 and fdt or 0, i, interval, timeout, func, args)
					t.runs[i] = t.runs[i] + 1					--
--					if i == reruns then flag = time end			--
					if _i == reruns then						-- 
						dif = 0 								--
						t.last[i] = time						--
						t.flag[i] = time - dif					--						
					end											--
				end												--
--				print('dt', dt, 'fdt', fdt, 'dif', dif, 'flag', flag, 'reruns', reruns, 'interval', interval)
			end													--
		else													-- 
			if last ~= -1 then									--
				for _ = 1, (timeout / interval) - runs do		-- 
					execute(t, 0, i, interval, timeout, func, args)
				end												--
			end													--
			return true 										--
		end														--	If timed out; yield
	end
end

--[[
Execution:
once at or post 'wait':
	if interval == 0 -> execute then remove; //dt equals time - stamp  
	elseif interval == -1
		if timeout == 0 or within timeout, execute;	//dt if first time equals time - stamp
		else remove;								//else equals tick dt
		(repeat the above 'if' once every tick)
	else;
		execute every INTERVAL for TIMEOUT ; 
		if ticks took longer than INTERVAL -> execute multiple times per tick
		[1][elaborated below]

[1]
if timed out; yield
if flag == -1
	fdt = time - stamp
	dif = time - stamp - wait
else
	fdt = time - last
	dif = time - flag
	
reruns = floor(dif / interval)
dif = dif % interval

if flag == -1 then reruns++ end

for i = 1, reruns do
	execute(i == 1 and fdt or 0)		--if multiple executions in a row, the first is passed dt the rest are passed 0
	if i + 1 == reruns then flag = time end
end
last = flag
flag = flag - dif

[2] examples !!! outdated !!!
stamp = 30
wait = 5
interval = 1
flag = -1

------------ first run [time = 35.3] //since stamp = 5.3	;	since first run 0.3
fdt = 5.3
dif = 0.3
	reruns, dif = 0++, 0.3 [0.3 / 1 ; ++]
	
flag = 35.0

------------ second run [time = 36.8] //since stamp = 6.8	;	since first run 1.8
fdt = 1.8
dif 1.8
	reruns, dif = 1, 0.8 [1.8 / 1]
	
flag = 36.0

------------ third run [time = 38.3] //since stamp = 8.3	;	since first run 3.3
fdt = 1.8
dif = 2.3
	reruns, dif = 2, 0.3 [2.3 / 1]

flag = 38.0

------------ fourth run [time = 39.8] //since stamp = 9.8	;	since first run 4.8
fdt = 1.8
dif 1.8
	reruns, dif = 1, 0.8 [1.8 / 1]
	
flag = 39.0	
--]]
------------------------------ Constructor ------------------------------
local Scheduler = class("Scheduler")
function Scheduler:init()
	self.tasks = {wait = {}, interval = {}, timeout = {}, stamp = {}, tdt = {},
			flag = {}, last = {}, runs = {}, func = {}, args = {}, wrapup = {}, wargs = {}}
		
	self.gtasks = {wait = {}, interval = {}, timeout = {}, stamp = {}, tdt = {},
			flag = {}, last = {}, runs = {}, func = {}, args = {}, wrapup = {}, wargs = {}}		
end

------------------------------ Main Methods ------------------------------
--TODO: pass graphical tasks a 'g' param in place of 'dt'.
local function processAll(t, dt)
	local yielded = {}
	for i = 1, #t.func do	--All subtables of self.tasks should always be of equal length.
		local done = process(t, dt, i, t.wait[i], t.interval[i], t.timeout[i], t.stamp[i], 
				t.flag[i], t.last[i], t.runs[i], t.func[i], t.args[i])
		if done then ins(yielded, i) end
	end
		
	for i = 1, #yielded do	--Remove yielded entries in reverse order (so indices remain consistent during yielding)
		yield(t, yielded[#yielded + 1 - i])
	end
end

function Scheduler:tick(dt)
	processAll(self.tasks, dt)
end

local gPrevTime = 0, getTime()
function Scheduler:draw(g)
	local dt = getTime() - gPrevTime
	processAll(self.gtasks, dt)
	gPrevTime = getTime()
end

------------------------------ Schedule Method ------------------------------
function Scheduler:schedule(wait, interval, timeout, stamp, func, args, wrapup, wargs, graphical)
	local t = graphical and self.gtasks or self.tasks
	ins(t.wait,     wait     or 0)
	ins(t.interval, interval or 0)
	ins(t.timeout,  timeout  or 0)
	ins(t.stamp,    stamp    or getTime())
	ins(t.tdt,       0)
	ins(t.flag,     -1)
	ins(t.last,     -1)
	ins(t.runs,      0)
	ins(t.func,     func)
	ins(t.args,     args     or {})
	ins(t.wrapup,   wrapup)
	ins(t.wargs,    wargs    or {})
end

------------------------------ Schedule Shortcuts ------------------------------
function Scheduler:callAfter(wait, func, args, wrapup, wargs)
	self:schedule(wait, nil, nil, nil, func, args, wrapup, wargs)
end

function Scheduler:callFor(timeout, func, args, wrapup, wargs)
	self:schedule(nil, -1, timeout, nil, func, args, wrapup, wargs)
end

function Scheduler:callEvery(interval, func, args, wrapup, wargs)
	self:schedule(nil, interval, nil, nil, func, args, wrapup, wargs)
end

function Scheduler:callEveryFor(interval, timeout, func, args, wrapup, wargs)
	self:schedule(nil, interval, timeout, nil, func, args, wrapup, wargs)
end

------------------------------ Schedule Graphical Shortcuts ------------------------------
function Scheduler:gCallAfter(wait, func, args, wrapup, wargs)
	self:schedule(wait, nil, nil, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallFor(timeout, func, args, wrapup, wargs)
	self:schedule(nil, -1, timeout, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallEvery(interval, func, args, wrapup, wargs)
	self:schedule(nil, interval, nil, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallEveryFor(interval, timeout, func, args, wrapup, wargs)
	self:schedule(nil, interval, timeout, nil, func, args, wrapup, wargs, true)
end
------------------------------ Cancel Methods ------------------------------
function Scheduler:cancel(func)
	local i = type(func) == 'number' and func or findIndex(self.tasks.func, func)
	if i then remove(self.tasks, i) end
	--Graphical tasks:
	i = type(func) == 'number' and func or findIndex(self.gtasks.func, func)
	if i then remove(self.gtasks, i) end
end

function Scheduler:cancelAll()
	for i = 1, self.tasks.func do
		remove(self.tasks, i)
	end
	--Graphical tasks:
	for i = 1, self.gtasks.func do
		remove(self.gtasks, i)
	end
end
------------------------------ Yield Methods ------------------------------
function Scheduler:yield(func)
	local i = type(func) == 'number' and func or findIndex(self.tasks.func, func)
	if i then yield(self.tasks, i) end
	--Graphical tasks:
	i = type(func) == 'number' and func or findIndex(self.gtasks.func, func)
	if i then yield(self.gtasks, i) end
end

function Scheduler:yieldAll()
	for i = 1, self.tasks.func do
		yield(self.tasks, i)
	end
	--Graphical tasks:
	for i = 1, self.gtasks.func do
		yield(self.gtasks, i)
	end
end

return Scheduler()


/////////////////Exiting file: Scheduler.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Fsm.lua/////////////////
--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"
local State = require "libs.SimpleFsm.State"

------------------------------ Nil State ------------------------------
local NilState = class("NilState", State)

------------------------------ Constructor ------------------------------
local Fsm = class("Fsm")
function Fsm:initialize()
	local ns = NilState()
	self.states = {["nil"] = ns}
	self.curState = ns
end

------------------------------ Core API ------------------------------

--[[
Callbacks only have to be defined by the FSM for ones that wish to override the default hookIntoLove behavior.
Which is: 
	if self.curState and self.curState[callbackName] then 
		self.curState[callbackName](pass-all-default-love-params-for-callback)
--]]
function Fsm:draw()
	if not self.curState.draw then return end
	
	local g2d = love.graphics
	self.curState:draw(g2d)
end

function Fsm:at(id)
	if id then
		return self.states[id] == self.curState
	else
		for k, v in pairs(self.states) do
			if self.curState == v then return k end
		end
	end
end

function Fsm:goto(id, ...)
	local state = self.states[id]
	if not state then return false end
	if self.curState == state then return false end
	
	self.curState:leave(state)
	local previous = self.curState
	self.curState = state
	self.curState:enter(previous, ...)
	return true
end

function Fsm:add(id, state)
	if self.states[id] then return false end
	
	self.states[id] = state
	state:activate(self)
	return true
end

function Fsm:remove(id)
	local state = self.states[id]
	if not state then return false end
	
	if self.curState == state then self.curState = nil end

	state:destroy()
	self.states[id] = nil
	return true
end

------------------------------ Love Hook ------------------------------
local function hookLoveCallback(Fsm, loveStr, fsmStr)
	fsmStr = fsmStr or loveStr
	local preF = love[loveStr]
	
	love[loveStr] = function(...)
		if preF then preF(...) end
		
		if Fsm[fsmStr] then 
			Fsm[fsmStr](Fsm, ...)
		elseif Fsm.curState[fsmStr] then 
			Fsm.curState[fsmStr](Fsm.curState, ...)
		end
	end
end

function Fsm:hookIntoLove()
	hookLoveCallback(self, "update")
	hookLoveCallback(self, "draw")
	hookLoveCallback(self, "keypressed", "keyPressed")
	hookLoveCallback(self, "keyReleased", "keyReleased")
	hookLoveCallback(self, "mousemoved", "mouseMoved")
	hookLoveCallback(self, "mousePressed", "mousePressed")
	hookLoveCallback(self, "textinput", "textInput")
	hookLoveCallback(self, "wheelMoved", "wheelMoved")
	--TODO: Implement the rest.
end

------------------------------ Getters / Setters ------------------------------
function Fsm:getStates()
	return self.states
end

function Fsm:getCurrentState()
	return self.curState
end

return Fsm

--[[

state
current state
transitionTo

--]]


/////////////////Exiting file: Fsm.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: State.lua/////////////////
--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local State = class("State")
function State:initialize()
end

------------------------------ Core API ------------------------------
function State:update(dt)
end

function State:draw(g2d)
end

function State:enter(from, ...)
	print("Entered: " .. self.fsm:at())
end

function State:leave(to)
	--FIXME: fsm is nil.
	--print("Left: " .. self.fsm:at())
end

function State:activate(fsm)
	self.fsm = fsm
end

function State:destroy()
end

------------------------------ Getters / Setters ------------------------------

return State

--[[

activate
destroy
enter
leave
update
draw

--]]


/////////////////Exiting file: State.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: main.lua/////////////////
local Fsm = require "libs.SimpleFsm.Fsm"
local State = require "libs.SimpleFsm.State"

--Test
local state1 = State()
state1.update = function(dt) print("state1 update!") end
state1.enter = function(fsm, from, ...) print("entered state1 with vars: ", ...) end
state1.leave = function(fsm, to, ...) print("left state1") end

local state2 = State()
state2.update = function(dt) print("state2 update!") end
state2.enter = function(fsm, from, ...) print("entered state2 with vars: ", ...) end
state2.leave = function(fsm, to, ...) print("left state2") end

local fsm = Fsm()
fsm:add(state1)
fsm:add(state2)

function love.load(args)
	fsm:hookIntoLove()
	fsm:goto(state1)
	fsm:goto(state1)	--Does nothing.
	fsm:goto(state2)
	fsm:goto(state1, "Hello", "World!", 42)
end

function love.update(dt)
	print("Original update!")
end

function love.draw()
	local g2d = love.graphics
	print("Original draw!")
end

/////////////////Exiting file: main.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: cruxclass.lua/////////////////
local middleclass = {
  _VERSION = [[
  	- middleclass  v4.1.1 
  	- MixinEdit    v1.0.0 
  	- NamingRevamp v1.0.0
  ]],
  
  _DESCRIPTION = [[
	  - Middleclass:  Object Orientation for Lua.
	  - MixinEdit:    Updates isInstanceOf and isSubclassOf to handle mixins.
	  - NamingRevamp: Revamps middleclass's naming conventions to be more uniform.
  ]],
  
  _URL = [[
  	middleclass:  https://github.com/kikito/middleclass
  	MixinEdit:    https://github.com/ActivexDiamond/cruxclass
  	NamingRevamp: https://github.com/ActivexDiamond/cruxclass
  ]],
  
  _LICENSE = [[
    MIT LICENSE
    Copyright (c) 2011 Enrique GarcÃ­a Cota
    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]],
  
  _MIXIN_EDIT_CHANGES = [[
	  Mixin Additions:
	  	Mixins can also hold fields, not only methods.
	    Added array "mixins" to all classes.
	  	"include" updates "mixins" field with references
	  		towards the newly included mixins.
	  	
	  	"isInstanceOf" checks list of mixins, plus usual operation.
	  	"isSubclassOf" checks list of mixins, plus usual operation.
  ]],
  
  _NAMING_REVAMP_CHANGES = [[	
	  Naming Conventions Changes:
	  	+ New Conventions:
	  		identifier = keywords, fundamental methods.
	  		__identifier = lua metamethods, middleclass metamethods.
			__identifier__ = middleclass internal methods/data.  		
	  	
	  	Fundemental Methods:
		  	"initialise" renamed to "init".
		  	"isInstanceOf" renamed to "instanceof".
		  	"isSubclassOf" renamed to "subclassof".
	  	
	  	Middleclass Metamethods:
		  	"allocate" renamed to "__allocate".
		  	"new" renamed to "__new".
		  	"subclassed" renamed to "__subclassed".
		  	"included" renamed to "__included".
	  	
	  	Middleclass Internal Data:
	  		"name" renamed to "__name__".
	  		"subclasses" renamed to "__subclasses__".
	  		"__mixins__" renamed to "__mixins__".
	  		
	  	Middleclass Internal Methods:
		  	"__instanceDict" renamed to "__instanceDict__".
		  	"__declaredMethods__" renamed to "__declaredMethods__".
  ]],
  
  NAMING_REVAMP_PROPOSED_CONVENTIONS = [[
	Fields: 
		private: Enforced, possible getter/setter.
		protected: Technically public, 
			but mutable fields are never accessed directly.
		public: All caps,
			Only final fields are accessed directly.
	
	Methods:
		private: Enforced.
		protected: Technically public,
			prefixed with a single underscore.
		public: "Enforced".
	
	Examples:
		local x = 666			-- private
		self.x = 42				-- protected
		self.PIE = 3.14			-- public
		
		local function getX()	-- private
		self:_getX()			-- protected
		self:getX()				-- public
		
	Note: "Technically public", as in it CAN be accessed publicly,
	 	security wise, but should never be, following convention.
  ]] 
}

local function _createIndexWrapper(aClass, f)
  if f == nil then
    return aClass.__instanceDict__
  else
    return function(self, __name__)
      local value = aClass.__instanceDict__[__name__]

      if value ~= nil then
        return value
      elseif type(f) == "function" then
        return (f(self, __name__))
      else
        return f[__name__]
      end
    end
  end
end

local function _propagateInstanceMethod(aClass, __name__, f)
  f = __name__ == "__index" and _createIndexWrapper(aClass, f) or f
  aClass.__instanceDict__[__name__] = f

  for subclass in pairs(aClass.__subclasses__) do
    if rawget(subclass.__declaredMethods__, __name__) == nil then
      _propagateInstanceMethod(subclass, __name__, f)
    end
  end
end

local function _declareInstanceMethod(aClass, __name__, f)
  aClass.__declaredMethods__[__name__] = f

  if f == nil and aClass.super then
    f = aClass.super.__instanceDict__[__name__]
  end

  _propagateInstanceMethod(aClass, __name__, f)
end

local function _tostring(self) return "class " .. self.__name__ end
local function _call(self, ...) return self:__new(...) end

local function _createClass(__name__, super)
  local dict = {}
  dict.__index = dict

  local aClass = { __name__ = __name__, super = super, static = {},
                   __instanceDict__ = dict, __declaredMethods__ = {},
                   __subclasses__ = setmetatable({}, {__mode='k'}),
                   __mixins__ = {}  }

  if super then
    setmetatable(aClass.static, {
      __index = function(_,k)
        local result = rawget(dict,k)
        if result == nil then
          return super.static[k]
        end
        return result
      end
    })
  else
    setmetatable(aClass.static, { __index = function(_,k) return rawget(dict,k) end })
  end

  setmetatable(aClass, { __index = aClass.static, __tostring = _tostring,
                         __call = _call, __newindex = _declareInstanceMethod })

  return aClass
end

local function _tableContains(t, o) 	----------
	for _, v in ipairs(t or {}) do		----------
		if v == o then return true end  ----------
	end									----------
	return false						----------
end

local function _includeMixin(aClass, mixin)
  assert(type(mixin) == 'table', "mixin must be a table")

  -- If including the DefaultMixin, then class.__mixins__
  -- will at that point still be nil.
  -- DefaultMixin is not __included in class.__mixins__
  if aClass.__mixins__ then table.insert(aClass.__mixins__, mixin) end	--------------
    
  for name,method in pairs(mixin) do
    if name ~= "__included" and name ~= "static" then aClass[name] = method end
  end

  for name,method in pairs(mixin.static or {}) do
    aClass.static[name] = method
  end

  if type(mixin.__included)=="function" then mixin:__included(aClass) end
  return aClass
end

local DefaultMixin = {
  __tostring   = function(self) return "instance of " .. tostring(self.class) end,

  init   = function(self, ...) end,

  instanceof = function(self, aClass)
    return type(aClass) == 'table'
       and type(self) == 'table'
       and (self.class == aClass	
            or type(self.class) == 'table'
            and (_tableContains(self.class.__mixins__, aClass) ----------
	            or type(self.class.subclassof) == 'function'
	            and self.class:subclassof(aClass)))
  end,

  static = {
--  	__mixins__ = setmetatable({}, {__mode = 'k'})
    __mixins__ = {}, -------------------
    
    __allocate = function(self)
      assert(type(self) == 'table', "Make sure that you are using 'Class:__allocate' instead of 'Class.__allocate'")
      return setmetatable({ class = self }, self.__instanceDict__)
    end,

    __new = function(self, ...)
      assert(type(self) == 'table', "Make sure that you are using 'Class:__new' instead of 'Class.__new'")
      local instance = self:__allocate()
      instance:init(...)
      return instance
    end,

    subclass = function(self, __name__)
      assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
      assert(type(__name__) == "string", "You must provide a __name__(string) for your class")

      local subclass = _createClass(__name__, self)

      for methodName, f in pairs(self.__instanceDict__) do
        _propagateInstanceMethod(subclass, methodName, f)
      end
      subclass.init = function(instance, ...) return self.init(instance, ...) end

      self.__subclasses__[subclass] = true
      self:__subclassed(subclass)

      return subclass
    end,

    __subclassed = function(self, other) end,

    subclassof = function(self, other)
	  return type(self) == 'table' and
	  	 	 type(other) == 'table' and
		  	 	(_tableContains(self.__mixins__, other) or
		  	 	type(self.super) == 'table' and
	  	 		(self.super == other or
	  	 		self.super:subclassof(other)))
    end,

    include = function(self, ...)
      assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
      for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
      return self
    end    
  }
}

function middleclass.class(__name__, super)
  assert(type(__name__) == 'string', "A __name__ (string) is needed for the __new class")
  return super and super:subclass(__name__) or _includeMixin(_createClass(__name__), DefaultMixin)
end

setmetatable(middleclass, { __call = function(_, ...) return middleclass.class(...) end })

return middleclass

--[[
Old -> New
  __tostring
  initialise		->	init
  isInstanceOf  	->	instanceof
  
  class	
  
  static {
  	allocate		->	__allocate
  	new				->	__new
  	subclass
  	subclassed		->	__subclassed
  	isSubclassOf	->	subclassof
  	include
  	
  	[mixin]included ->	__included
  					[+]	__mixins__
  	
  	name			->	__name__
  	super	
  	__instanceDict	->	__instanceDict__
  	__declaredMethods>	__declaredMethods__
  	subclasses		-	 __subclasses__
  	
----------------------------------------

  	mthd = keywords: super, class, static
  					 instanceof, subclassof
			 fundementals: init, subclass, include
		
	__mthd =  metamethods: __tostring,
			  middleclass_metamethods: __allocate,
			  	__new, __subclassed, __included
			  		
		
	__mthd__ = middleclass_internal_methods: __instanceDict__,
					__declaredMethods__
			    middleclass_internal_data: __name__,
			    	__subclasses__, __mixins__		
			 
--]]

--[[
Fields: 
	private: Enforced, possible getter/setter.
	protected: Technically public, 
		but fields are never accessed directly.
	public: Fields are never public.

Methods:
	private: Enforced.
	protected: Technically public,
		prefixed with a single underscore.
	public: "Enforced".

Examples:
	local x = 3.14			-- private
	self.x = 42				-- protected
	
	local function getX()	-- private
	self:_getX()			-- protected
	self:getX()				-- public
--]]

/////////////////Exiting file: cruxclass.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: utils.lua/////////////////
local utils = {}
utils.t = {}
utils.str = {}

------------------------------ Misc. ------------------------------
function utils.class(name, ...)
	local function classIs(class, otherClass)
		for k, v in ipairs(class) do
			if v == otherClass then return true end
		end
		return false
	end
	local supers = {...}
	local inst, instClass = {}, {name}
	--append class names
	for _, superInst in ipairs(supers) do
		utils.t.append(instClass, superInst.class)
		
		local allowed = superInst.class.allowed
		local tAllowed = type(allowed) == 'table' and allowed or {allowed}
		utils.t.append(instClass.allowed or {}, tAllowed)
	end
	instClass.is = classIs
	
	--iterate over supers
	for _, superInst in ipairs(supers) do
		--raise error if not allowed
		local allowed = superInst.class.allowed
		--Possibilties: t->t	;	str->{str}	;	nil->{nil}
		local tAllowed = type(allowed) == 'table' and allowed or {allowed}
		local validChild = #tAllowed == 0;
		for _, a in ipairs(tAllowed) do
			if not validChild then
				validChild = classIs(instClass, a)
			end
		end
		assert(validChild, string.format("%s can only be subtyped by one of: %s",
				superInst.class[1], 
				table.concat(tAllowed, ", "))) 
		--appent members
		for k, v in pairs(superInst) do
			inst[k] = v
		end
	end
	
	inst.class = instClass
	--obj.class[1] == direct class
	--obj.class:is(str) == check full heirarchy
	return inst
end

------------------------------ Math ------------------------------
function utils.sign(x)
	return x == 0 and 0 or (x > 0 and 1 or -1)
end

function utils.map(x, min, max, nmin, nmax)
 return (x - min) * (nmax - nmin) / (max - min) + nmin
end

function utils.snap(grid, x, y)
	x = math.floor(x/grid) * grid
	y = y and math.floor(y/grid) * grid
	return x, y
end

function utils.dist(x1, y1, x2, y2)
	local d1 = (x1^2 + y1^2)
	return x2 and math.abs(d1 - (x2^2 + y2^2))^.5 or d1^.5
end

function utils.distSq(x1, y1, x2, y2)
	local d1 = (x1^2 + y1^2)
	return x2 and math.abs(d1 - (x2^2 + y2^2)) or d1
end

function utils.rectIntersects(x, y, w, h, ox, oy, ow, oh)
	return x < ox + ow and 
		y < oy + oh and 
		x + w > ox and
		y + h > oy
end

------------------------------ Files ------------------------------
function utils.listFiles(dir)
	local fs = love.filesystem
	local members = fs.getDirectoryItems(dir)
	
	local files = {}
	local shortNameFiles = {}
--	print("in dir: " .. dir)
	for k, member in ipairs(members) do
		local fullMember = dir .. '/' .. member
		local info = fs.getInfo(fullMember) 
		if info and info.type == 'file' and 
				member ~= ".DS_Store" then
			table.insert(files, fullMember)
			table.insert(shortNameFiles, member)
		end
	end
--	print("Finished dir.")
	return files, shortNameFiles
end

function utils.listDirItems(dir)
	local fs = love.filesystem
	local members = fs.getDirectoryItems(dir)
	
	local files = {}
	local shortNameFiles = {}
--	print("in dir: " .. dir)
	for k, member in ipairs(members) do
		local fullMember = dir .. '/' .. member
		local info = fs.getInfo(fullMember) 
		if info and member ~= ".DS_Store" then 
			table.insert(files, fullMember)
			table.insert(shortNameFiles, member)
		end
	end
--	print("Finished dir.")
	return files, shortNameFiles
end

------------------------------ Tables ------------------------------
function utils.t.contains(t, obj)
	for k, v in pairs(t) do
		if v == obj then return true end
	end
end

function utils.t.remove(t, obj)
	for k, v in pairs(t) do
		if v == obj then return table.remove(t, k) end
	end
	return nil
end

function utils.t.append(t1, t2)
	for k, v in ipairs(t2) do
		table.insert(t1, v)
	end
end

function utils.t.copy(t)
	local cpy = {}
	for k, v in pairs(t) do
		cpy[k] = v
	end
	return cpy
end

function utils.t.hardCopy(t)
	local cpy = {}
	for k, v in pairs(t) do
		if type(v) == 'table' then
			if v.clone then cpy[k] = v:clone()
			else cpy[k] = utils.t.copy(v) end
		else cpy[k] = v end
	end
	return cpy
end

------------------------------ Strings ------------------------------
function utils.str.sep(str, sep)
	sep = sep or '%s'
	local sepf = string.format("([^%s]*)(%s?)", sep, '%s')
	local t = {}
	for token, s in string.gmatch(str, sepf) do
		table.insert(t, token)
		if s == "" then return t end
	end
end

function utils.str.rem(str, token)
	return str:gsub(token .. "+", "")
end

return utils


/////////////////Exiting file: utils.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: main.lua/////////////////
--[[
local sock = require "libs.sock"

local client = sock.newClient("localhost", 9000)

client:on("connect", function()
	print("Connected!")
end)

client:on("disconnect", function()
	print("Disconnected!")
end)

client:connect()

function love.update()
	client:update()
end

--]]

---[[
local Slab = require "libs.Slab"

local PeripheralApi = require "PeripheralApi"
local UdpApi = require "UdpApi"

local lovebird = require "libs.lovebird"
lovebird.update()					--To fix lovebird missing prints before the first love.update is called.

local Display
function love.load(args)
	Slab.SetINIStatePath(nil)	
	Slab.Initialize(args)
	
	Display = require "view.Display"	--Put it here to control when it initialize's. TODO: Figure out a cleaner way to do this.
	_G.Display = Display
end

local dur = 3
local lastTime = 0
function love.update(dt)
	lovebird.update(dt)
	UdpApi:update(dt)

	Slab.Update(dt)
	Display:update(dt)

	
	
--	if love.timer.getTime() - lastTime > dur then
--		lastTime = love.timer.getTime() 
--		if UdpApi.client:isConnected() then
--			UdpApi.client:send("hello")
--		end
--	end
end

function love.draw()
	local g2d = love.graphics
	Slab.Draw()
	Display:draw(g2d)
end

--]]

--[[
--			Test Cases

PeripheralApi:_sendCmd("arm_stop")
PeripheralApi:_sendCmd("arm_forward", 120)
PeripheralApi:_sendCmd("arm_backward", 150)
PeripheralApi:_sendCmd("arm_stop", 5)
PeripheralApi:_sendCmd("arm_forward")
PeripheralApi:_sendCmd("foo")
--]]

--[[
			From PeripheralApi:_sendCmd() : The UdpApi:send(<...>) line.
			
Should this be changed so that all cmds get their args passed in as a table of args?
	(including 0-arg-cmds and 1-arg-cmds.)
	
--]]

/////////////////Exiting file: main.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: temp.lua/////////////////
local sock = require "libs.sock"

local AppData = require "AppData"


------------------------------ Heleprs ------------------------------

------------------------------ Constructor ------------------------------
local UdpApi = class("UdpApi")
--Note: This class is a singleton.
function UdpApi:initialize()
	self:reloadPeer()
end

------------------------------ Core API ------------------------------
function UdpApi:update(dt)
	self.rtVal = nil		--Clear any old unclaimed rtVals.
	self.client:update(dt)
end

------------------------------ API ------------------------------
function UdpApi:reloadPeer()
	self.ip = AppData.config.ip
	self.port = AppData.config.port
	self.target = self.ip .. ":" .. self.port
	self:connect()
end

function UdpApi:connect()
	self.client = sock.newClient(self.ip, self.port)
	self:_injectEvents()
end

--- Attempt to fetch the rtVal produced by the last event sent.
-- @return 						#bool		;	Success.
-- @return 						#any		;	err-msg if failed. rtVal otherwise.
function UdpApi:fetchReturn(timeout)
	local startTime = love.timer.getTime()
	while self.rtVal == nil do
		self.client:update()
		if love.timer.getTime() - startTime > timeout then
			return false, "timed-out: Spent too long waiting for return value."
		end
	end
	--Clear the rtVal single-val buffer before returning.
	local rtVal = self.rtVal
	self.rtVal = nil
	return true, self.rtVal
end

function UdpApi:send(ev, data)
	self.client:send(ev, data)
end

------------------------------ Internals ------------------------------
function UdpApi:_injectEvents()
	
	for ev, callback in pairs(self.events) do
		self.client:on(ev, function(...) callback(self, ...) end)
	end
end

------------------------------ Getters / Setters ------------------------------

------------------------------ Events ------------------------------
UdpApi.events = {}

function UdpApi.events:connect()
	print("Successfully established a connection to: ", self.ip, self.port)
end

function UdpApi.events:disconnect()
	print("Disconnected from the server.")
end

function UdpApi.events:onReturn(val)
	self.rtVal = val
end

return UdpApi()

--[[
send cmd
rt vals
connect
reload ip + connect
timeout connection attempt


--]]

/////////////////Exiting file: temp.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: AutoScene.lua/////////////////

local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"
local ConsoleStringBuilder = require "libs.ConsoleStringBuilder"
 
local PeripheralApi = require "PeripheralApi"


------------------------------ Local Constants ------------------------------
local CONSOLE_LINES = 5
local CONSOLE_CHARS_PER_LINE = 67

------------------------------ Helper Methods ------------------------------
local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function getTextH(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getHeight()
end

------------------------------ Constructor ------------------------------
local AutoScene = class("AutoScene", State)
function AutoScene:initialize()
	self.console = ConsoleStringBuilder(CONSOLE_LINES, CONSOLE_CHARS_PER_LINE)
end

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = love.graphics.getWidth(),
	H = love.graphics.getHeight(),
	AutoSizeWindow = false,
}

local _h = getTextH("foo") * CONSOLE_LINES
local consoleWindow = {
	id = "console",
	X = 0,
	Y = love.graphics.getHeight() - _h,
	--To prevent Slab.Textf's wrapped texted from displaying a (1 pixel) scroll bar.
	W = love.graphics.getWidth() - 1,
	H = _h,
	AutoSizeWindow = false,
	BgColor = {1, 1, 1, 0},
}

------------------------------ Core API ------------------------------
local lastPrint = 0
function AutoScene:update(dt)
	if love.timer.getTime() - lastPrint > 3 then
		local state = PeripheralApi:getAutoState()
		self:_echo(state)
		lastPrint = love.timer.getTime()
	end
	--Main Window
	Slab.BeginWindow(window.id, window)
	
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	Slab.SetCursorPos(consoleWindow.X, consoleWindow.Y - 20)
	Slab.Text("Console")
	Slab.EndWindow()
	
	--Console Window
	Slab.BeginWindow(consoleWindow.id, consoleWindow)
	Slab.PushFont(Display.fonts.ROBOTO_MONO_REGULAR)

	--Draw Console
	Slab.Text(self.console:getContent())

	Slab.PopFont()
	Slab.EndWindow()
end

function AutoScene:leave(to)
	self.console:clear()
end

function AutoScene:keyPressed(key)
	self:_echo(key)
end
------------------------------ Internals ------------------------------
function AutoScene:_echo(...)
	self.console:print(...)
end

------------------------------ Getters / Setters ------------------------------

return AutoScene

--[=[
local loremStr = 
[[Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut
labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi 
ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum
dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
]]
			
--]=]

/////////////////Exiting file: AutoScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Display.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local Fsm = require "libs.SimpleFsm.Fsm"

local LogoScene = require "view.LogoScene"
local MainScene = require "view.MainScene"
local ManualScene = require "view.ManualScene"
local AutoScene = require "view.AutoScene"
local TargetChangeScene = require "view.TargetChangeScene"

local PeripheralApi = require "PeripheralApi"

------------------------------ Constructor ------------------------------
local Display = class("Display")
function Display:initialize(w, h)
	if w and h then
		self.w = w
		self.h = h
	else
		self.w, self.h = love.window.getMode()
	end
	

	
	
	self.fonts = {
		SYMBOLA = love.graphics.newFont("assets/Symbola.ttf"),
		ROBOTO_MONO_REGULAR = love.graphics.newFont("assets/roboto_mono/RobotoMono-Regular.ttf"),
		ROBOTO_MONO_BOLD = love.graphics.newFont("assets/roboto_mono/RobotoMono-Bold.ttf"),
		ROBOTO_MONO_ITALIC = love.graphics.newFont("assets/roboto_mono/RobotoMono-Italic.ttf"),
		ROBOTO_MONO_LIGHT = love.graphics.newFont("assets/roboto_mono/RobotoMono-Light.ttf"),
	}
	
	self.fsm = Fsm()
	self.fsm:hookIntoLove()
	
	self.scenes = {
		logo_scene = LogoScene(),
		main_scene = MainScene(),
		manual_scene = ManualScene(),
		auto_scene = AutoScene(),
		target_change_scene = TargetChangeScene(),
	}
	
	for k, v in pairs(self.scenes) do
		self.fsm:add(k, v)
	end
	
	self.fsm:goto("logo_scene")
end

------------------------------ API ------------------------------
function Display:update(dt)
	if not (self.fsm:at("logo_scene") or self.fsm:at("target_change_scene")) and 
			not PeripheralApi:ping() then
		self.fsm:goto("main_scene")
	end
end

function Display:draw(g2d)
	--Enable if any drawing is done outside of Slab.
	--love.graphics.setFont(self.fonts.ROBOTO_MONO_BOLD)
end

------------------------------ Getters / Setters ------------------------------

return Display()


/////////////////Exiting file: Display.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: LogoScene.lua/////////////////
local class = require "libs.middleclass"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local LogoScene = class("LogoScene", State)
function LogoScene:initialize()
	self.duration = 0.3

	self.logo = love.graphics.newImage("assets/a_lab_logo.png")
end

------------------------------ Core API ------------------------------

local percentageLast
function LogoScene:update(dt)
	--TODO: Proper loading bar.
	local percentage = math.floor(self.age / self.duration * 100)
	if percentage ~= percentageLast then
		print(string.format("Loading: %%%d", percentage))
		percentageLast = percentage
	end
	
	self.age = self.age + dt
	if self.age > self.duration then
		print("Loading: %100")
		print("Finished loading!")
		self.fsm:goto("main_scene")
	end
end

function LogoScene:draw(g2d)
	g2d.draw(self.logo, 0, 0)
end

function LogoScene:enter(from, ...)
	State.enter(self, from, ...)
	self.age = 0
end

function LogoScene:leave(to)
	State.leave(self, to)
	self.age = 0
end

------------------------------ Getters / Setters ------------------------------

return LogoScene

/////////////////Exiting file: LogoScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: MainScene.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local socket = require "socket"

local PeripheralApi = require "PeripheralApi"
local AppData = require "AppData"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------
local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function getTextH(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getHeight()
end

------------------------------ Constructor ------------------------------
local MainScene = class("MainScene", State)
function MainScene:initialize()
	--Fetch Client Ip
	self.machineIp = socket.dns.toip(socket.dns.gethostname())
	
	--Offline Label Animation
	self.dotTimeDur = 0.3
	self.dotsLen = 7
	
	self.dotTime = 0
	self.dots = ""	
end

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = love.graphics.getWidth(),
	H = love.graphics.getHeight(),
	AutoSizeWindow = false,
}

local isConfirming
local popupQuit = {
	id = "Quitting!",
	msg = "Are you sure you want to quit?\n\n  You can start the program back up\nby launching \"Robot Controller\"\nfrom your desktop.",
	Buttons = {"Quit!", "Cancel"},
	onClick = function(result)
		if result == "Quit!" then
			PeripheralApi:quit()
		end
		return nil
	end
}

local popupRebootRemote = {
	id = "Rebooting Remote!",
	msg = "Are you sure you want to reboot the remote?\n\n  This may take a few minutes.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PeripheralApi:rebootRemote()
		end
		return nil
	end
}

local popupRebootRobot = {
	id = "Rebooting Robot!",
	msg = "Are you sure you want to reboot the robot?\n\n  This may take a few minutes,\nduring which the remote will be unfunctional.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PeripheralApi:rebootRobot()
		end
		return nil
	end
}

------------------------------ Core API ------------------------------
function MainScene:update(dt)
	Slab.BeginWindow(window.id, window)
	
	--Prj Name
	local prjNameXPos = window.W - getTextW(AppData.PROJECT_NAME) - 40
	Slab.SetCursorPos(prjNameXPos, 0)
	Slab.Text(AppData.PROJECT_NAME)
	Slab.SetCursorPos(prjNameXPos - 7, getTextH("foo"))
	if Slab.Button("Change Target") then
		self.fsm:goto("target_change_scene")
	end
	Slab.SetCursorPos(0, 0)
	--Version
	Slab.Text("Version: " .. AppData:getVersionString())
	--Server Info
	Slab.Text("Machine (Client) IP: " .. self.machineIp)
	Slab.Text("Target (Server) IP: " .. AppData.targetIp)
	Slab.Text("Port: " .. AppData.port)
	
	--Status
	local statusStr = PeripheralApi:ping() and "Robot Status: online" or "Robot Status: offline"
	local statusXPos = window.W / 2 - getTextW(statusStr) / 2
	local statusYPos = getTextH(statusStr) * 3
	--Slab.SetCursorPos(statusXPos, statusYPos)
	Slab.NewLine()
	Slab.Text(statusStr)
	
	--Offline Label
	--Slab.SetCursorPos(statusXPos, statusYPos + getTextH(statusStr))
	if not PeripheralApi:ping() then
		Slab.Text("Reconnecting." .. self.dots)
		self.dotTime = self.dotTime + dt
		if self.dotTime > self.dotTimeDur then
			self.dotTime = 0
			self.dots = self.dots .. "."
			if #self.dots > self.dotsLen then
				self.dots = ""
			end
		end
	else
		self.dotTime = 0
		self.dots = ""
	end
	
	--Modes - Manual
	local modesYPos = window.H / 2
	local modesXOffset = 100
	Slab.SetCursorPos(modesXOffset, modesYPos)
	if Slab.Button("Manual") then
		self.fsm:goto("manual_scene")
	end
	
	--Auto - Modes
	local autoW = getTextW("Automatic") + 16
	local autoX = window.W - modesXOffset - autoW
	Slab.SetCursorPos(autoX, modesYPos)
	if Slab.Button("Automatic") then
		self.fsm:goto("auto_scene")
	end
	
	--Bottom Toolbar - Quit
	local bottomY = window.H - getTextH("FOO") * 2
	Slab.SetCursorPos(0, bottomY)
	if Slab.Button("Quit") then
		isConfirming = popupQuit
	end
	
	--Bottom Toolbar - Reboot Remote
	local rebootX = 220
	Slab.SetCursorPos(rebootX, bottomY)
	
	if Slab.Button("Reboot Remote") then
		isConfirming = popupRebootRemote
	end
	
	--Bottom Toolbar - Reboot Robot
	Slab.SameLine()
	if Slab.Button("Reboot Robot") then
		isConfirming = popupRebootRobot
	end

	if isConfirming then
		local result = Slab.MessageBox(isConfirming.id, isConfirming.msg, isConfirming)
		if result ~= "" then
			isConfirming = isConfirming.onClick(result)
		end
	end
	
	Slab.EndWindow()
	
	PeripheralApi:reconnet()		--Will get ignored if client is already connected.
end

------------------------------ Getters / Setters ------------------------------

return MainScene


/////////////////Exiting file: MainScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ManualScene.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local lume = require "libs.lume"

local AppData = require "AppData"
local PeripheralApi = require "PeripheralApi"

local State = require "libs.SimpleFsm.State"

------------------------------ Internal Constants ------------------------------
local DEFAULT_BUTTON_SIZE = 32
local DEFAULT_BUTTON_PAD = 0

------------------------------ Helper Methods ------------------------------
local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function imgButtonOpt(button_size, imgPath)
	return {
		id = imgPath,
		W = button_size,
		H = button_size,
		Image = {Path = imgPath},
	}
end

--Callback signature: f(newVal, oldVal, inc)
local function buttonStepper(val, inc, callback, label, buttonSize, buttonPad)
	buttonSize = buttonSize or DEFAULT_BUTTON_SIZE
	buttonPad = buttonPad or DEFAULT_BUTTON_PAD
	
	local offset = buttonSize + buttonPad
	local initX, initY = Slab.GetCursorPos()

	--Plus
	local plusOpt = imgButtonOpt(buttonSize, AppData.ASSET_DIR .. "plus.png")
	Slab.SetCursorPos(initX, initY)
	if Slab.Button(plusOpt.id, plusOpt) then
		callback(val + inc, val, inc)
	end
	--Val
	local xOffset = buttonSize * 0.5 - getTextW(val) / 2
	Slab.SetCursorPos(initX + xOffset, initY + offset * 1.2)
	Slab.Text(val)
	--Minus
	Slab.SetCursorPos(initX, initY + offset * 2)
	local minusOpt = imgButtonOpt(buttonSize, AppData.ASSET_DIR .. "minus.png")
	if Slab.Button(minusOpt.id, minusOpt) then
		callback(val - inc, val, -inc)
	end
	--Label	
	if label then
		local xOffset = buttonSize * 0.5 - getTextW(label) / 2
		Slab.SetCursorPos(initX + xOffset, initY + offset * 3)
		Slab.Text(label)	
	end
end

local function joystick(dirs, label, buttonSize, buttonPad)
	buttonSize = buttonSize or DEFAULT_BUTTON_SIZE
	buttonPad = buttonPad or DEFAULT_BUTTON_PAD
	local callback = dirs.callback or function(id) 
		print("[" .. id .. "] button was pressed.")
	end
	
	local initX, initY = Slab.GetCursorPos()
	local offset = buttonSize + buttonPad
	local rtVal
	--North
	Slab.SetCursorPos(initX + offset, initY)
	local n = dirs.north
	local nOpt = imgButtonOpt(buttonSize, n.imgPath)
	if Slab.Button(n.id, nOpt) then
		rtVal = n.callback and n.callback(n.id) or callback(n.id)
	end
	--Center
	
	local c = dirs.center
	if c then
		Slab.SetCursorPos(initX + offset, initY + offset) 
		local cOpt = imgButtonOpt(buttonSize, c.imgPath)
		if Slab.Button(c.id, cOpt) then
			rtVal = c.callback and c.callback(c.id) or callback(c.id)
		end
	end
	
	--South
	Slab.SetCursorPos(initX + offset, initY + offset * 2) 
	local s = dirs.south
	local sOpt = imgButtonOpt(buttonSize, s.imgPath)
	if Slab.Button(s.id, sOpt) then
		rtVal = s.callback and s.callback(s.id) or callback(s.id)
	end
	
	--Label
	if label then
		local xOffset = offset * 1.5 - getTextW(label) / 2 
		Slab.SetCursorPos(initX + xOffset, initY + offset * 3)
		Slab.Text(label)
	end
	
	--West
	Slab.SetCursorPos(initX, initY + offset)
	local w = dirs.west
	local wOpt = imgButtonOpt(buttonSize, w.imgPath)
	if Slab.Button(w.id, wOpt) then
		rtVal = w.callback and w.callback(w.id) or callback(w.id)
	end
	--East
	Slab.SetCursorPos(initX + offset * 2, initY + offset)
	local e = dirs.east
	local eOpt = imgButtonOpt(buttonSize, e.imgPath)
	if Slab.Button(e.id, eOpt) then
		rtVal = e.callback and e.callback(e.id) or callback(e.id)
	end
	
	return rtVal
end

------------------------------ Constructor ------------------------------
local ManualScene = class("ManualScene", State)
function ManualScene:initialize()
	self.buttonSize = 24
	self.buttonPad = 4
	self.buttonOffset = self.buttonSize + self.buttonPad
	
	self.foo = 0
	self.fooMin = 0
	self.fooMax = 5
end

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = love.graphics.getWidth(),
	H = love.graphics.getHeight(),
	AutoSizeWindow = false,
}

------------------------------ Core API ------------------------------
function ManualScene:update(dt)
	Slab.BeginWindow(window.id, window)
	
	--Back
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	--Ultrasonics
	--local leftStr = string.format("LEFT-HC-SR04:    %.2fcm", PeripheralApi:getLeftUltrasonic())
	--Slab.Text(leftStr)
	--local rightStr = string.format("RIGHT-HC-SR04: %.2fcm", PeripheralApi:getRightUltrasonic())
	--Slab.Text(rightStr)
	
	--Chasis Joystick
	Slab.SetCursorPos(self.buttonOffset, window.H - self.buttonOffset * 4.5)
	joystick({
		center = {id = "stop", imgPath = AppData.ASSET_DIR .. "stop.png",
			callback = function() PeripheralApi:stopWheel()
			end
		},
		north = {id = "forward", imgPath = AppData.ASSET_DIR .. "forward.png"},
		south = {id = "backward", imgPath = AppData.ASSET_DIR .. "backward.png"},
		west = {id = "left", imgPath = AppData.ASSET_DIR .. "left.png"},
		east = {id = "right", imgPath = AppData.ASSET_DIR .. "right.png"},
		callback = function(dir)
			PeripheralApi:moveWheel(dir)
		end,
	}, "Chasis\n[mov]", self.buttonSize, self.buttonPad)

	--Wheel Rot Amount
	Slab.SetCursorPos(self.buttonOffset * 4.7, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getWheelRotAmount(), 10, function(newVal, oldVal, inc)
		PeripheralApi:setWheelRotAmount(newVal)
	end, "Wheel\n  [rot]", self.buttonSize, self.buttonPad)
	
	--Cutter Wheel Angle
	Slab.SetCursorPos(self.buttonOffset * 6.9, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getCutterWheelAngle(), 1, function(newVal, oldVal, inc)
		PeripheralApi:setCutterWheelAngle(newVal)
	end, "CWheel\n  [ang]", self.buttonSize, self.buttonPad)
	--Cutter Worm Angle
	Slab.SetCursorPos(self.buttonOffset * 9.1, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getCutterWormAngle(), 1, function(newVal, oldVal, inc)
		PeripheralApi:setCutterWormAngle(newVal)
	end, "CWorm\n  [ang]", self.buttonSize, self.buttonPad)

	--Arm Speed
	Slab.SetCursorPos(self.buttonOffset * 11.3, window.H - self.buttonOffset * 4.5)
	buttonStepper(PeripheralApi:getArmSpeed(), 15, function(newVal, oldVal, inc)
		PeripheralApi:setArmSpeed(newVal)
	end, "Arm\n[spd]", self.buttonSize, self.buttonPad)
				
	--Arm Joystick
	Slab.SetCursorPos(window.W - self.buttonOffset * 4, window.H - self.buttonOffset * 4.5)
	joystick({
		center = {id = "stop", imgPath = AppData.ASSET_DIR .. "stop.png",
			callback = function() PeripheralApi:stopArm()
			end
		},
		north = {id = "forward", imgPath = AppData.ASSET_DIR .. "forward.png"},
		south = {id = "backward", imgPath = AppData.ASSET_DIR .. "backward.png"},
		west = {id = "up", imgPath = AppData.ASSET_DIR .. "up.png"},
		east = {id = "down", imgPath = AppData.ASSET_DIR .. "down.png"},
		callback = function(dir)
			PeripheralApi:moveArm(dir)
		end, 
	}, "Arm\n[mov]", self.buttonSize, self.buttonPad)
		
	Slab.EndWindow()
end

------------------------------ Getters / Setters ------------------------------

return ManualScene


/////////////////Exiting file: ManualScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: TargetChangeScene.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"

local State = require "libs.SimpleFsm.State"
 
local AppData = require "AppData"

------------------------------ Local Constants ------------------------------
local DEFAULT_BUTTON_SIZE = 24
local DEFAULT_BUTTON_PAD = 4
local SCREEN_W = 480
local SCREEN_H = 320


------------------------------ Helper Methods ------------------------------
local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function getTextH(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getHeight()
end

------------------------------ Constructor ------------------------------
local TargetChangeScene = class("TargetChangeScene", State)
function TargetChangeScene:initialize()
	self.keypadLayout = {
		{"1", "2", "3",},
		{"4", "5", "6",},
		{"7", "8", "9",},
		{".", "0", "<-", "OK",},
	}
	self.MAX_TARGET_LEN = 15
	
	self.newTarget = ""
end

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = love.graphics.getWidth(),
	H = love.graphics.getHeight(),
	AutoSizeWindow = false,
}

local keypadButton = {
	W = DEFAULT_BUTTON_SIZE,
	H = DEFAULT_BUTTON_SIZE,
}

------------------------------ Core API ------------------------------
function TargetChangeScene:update(dt)
	--Main Window
	Slab.BeginWindow(window.id, window)
	
	if Slab.Button("Back") then
		self.fsm:goto("main_scene")
	end
	
	local offset = DEFAULT_BUTTON_SIZE + DEFAULT_BUTTON_PAD	

	local initX = SCREEN_W / 2 - #self.keypadLayout * offset
	local initY = SCREEN_H / 2 - #self.keypadLayout[1] * offset

	for i = 1, #self.keypadLayout do
		local row = self.keypadLayout[i]
		for j = 1, #row do
			local x = initX + j * offset
			local y = initY + i * offset
			Slab.SetCursorPos(x, y)
			local key = row[j]
			if Slab.Button(key, keypadButton) then
				self:_pressed(key)
			end
		end
	end
	
	Slab.SetCursorPos(100, 80)
	Slab.Text("Target: " .. self.newTarget)
	Slab.SetCursorPos(0, SCREEN_H - 24)
	Slab.Text("Note: Set to an empty field to default to \"localhost\".")
	
	Slab.EndWindow()
end

function TargetChangeScene:leave(to)
	self.newTarget = ""
end

------------------------------ Internals ------------------------------
function TargetChangeScene:_pressed(key)
	if key == "OK" then
		AppData:updateTarget(self.newTarget)
		self.fsm:goto("main_scene")	
	elseif key == "<-" then
		self.newTarget = self.newTarget:sub(1, -2)
	elseif #self.newTarget < self.MAX_TARGET_LEN then
		self.newTarget = self.newTarget .. key
	end
end

------------------------------ Getters / Setters ------------------------------

return TargetChangeScene


/////////////////Exiting file: TargetChangeScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: AppData.lua/////////////////
local AppData = {
	--Version
	MAJOR_VERSION = 1,
	MINOR_VERSION = 0,
	PATCH_VERSION = 0,
	PHASE = "beta",
	
	--Title
	PROJECT_NAME = "Robot Controller",
	
	--Directories
	ASSET_DIR = "assets/",
	
	--Networking Related
	openIp = "*",
	targetIp = nil,			--Set by _fetchTarget below.
	port = 9000,
	PING_INTERVAL = 1,
	PINGS_BEFORE_TIMEOUT = 3,
	
	--Target IP Config Related
	TARGET_IP_CONFIG_FILE = "target_ip.cfg",
	TARGET_IP_CONFIG_DEFAULT = "localhost",
	
	--Priviliages
	CAN_REBOOT_REMOTE = false,
	CAN_REBOOT_ROBOT = false,
}

function AppData:getVersionString()
	if self.PATCH_VERSION == 0 then
		return self.MAJOR_VERSION .. "." .. self.MINOR_VERSION ..
				"-" .. self.PHASE 
	else
		return self.MAJOR_VERSION .. "." .. self.MINOR_VERSION .. 
				"." .. self.PATCH_VESRSION "-" .. self.PHASE
	end
end

function AppData:_fetchTarget()
	local file = love.filesystem.newFile(self.TARGET_IP_CONFIG_FILE)
	file:open('r')
	self.targetIp = file:read()
	file:close()
	if not self.targetIp or #self.targetIp < 1 then
		self.targetIp = self.TARGET_IP_CONFIG_DEFAULT
	end
end

function AppData:updateTarget(newTarget)
	local file = love.filesystem.newFile(self.TARGET_IP_CONFIG_FILE)
	file:open("w")
	file:write(newTarget)
	file:close()
	
	self:_fetchTarget()		
end

AppData:_fetchTarget()
return AppData

/////////////////Exiting file: AppData.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: PeripheralApi.lua/////////////////
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
--]]

------------------------------ Heleprs ------------------------------
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

------------------------------ Constructor ------------------------------
local PeripheralApi = class("PeripheralApi")
--Note: This class is a singleton.
function PeripheralApi:initialize()
	--UDP Related
	self.return_timeout = 3000		--in ms

	--TODO: Change these to more sensible defaults.
	--Defaults - Speeds.
	self.armSpeed = 135
	self.wheelRotAmount = 155
	--Defaults - Angles.
	self.cutterWormAngle = 0
	self.cutterWheelAngle = 0
end

------------------------------ Commands ------------------------------
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
	c_worm_set =				{code = "CWheel",	args = 1, rt = false},
	
	sys_reboot =				{code = "SR",		args = 0, rt = false},
	
	sensor_ultrasonic_left = 	{code = "UL",		args = 0, rt = true},
	sensor_ultrasonic_right =	{code = "UR",		args = 0, rt = true},
	sensor_gyro_is_fallen =		{code = "GF",		args = 0, rt = true},
}

------------------------------ Internals ------------------------------
function PeripheralApi:_sendCmd(cmdName, ...)
	local args = {...}
	local cmd = self.cmds[cmdName]
	if not cmd then
		local errStr = "Tried to execute [%s] and failed as command is invalid!" 
		print(errStr:format(cmdName))
		return false
	end
	if cmd.args ~= #args then
		local errStr = "Tried to execute [%s] with [%d args] and failed as command requires [%d args]"
		print(errStr:format(cmdName, #args, cmd.args))
		return false
	end
	
	print("Exeucting command:", cmd.code, table.concat(args))
	--Yes, this could be changes to "=< 1" -> "unpack",
	--	but this communicates the logic more cleanly.
	if cmd.args == 0 then
		UdpApi:send(cmd.code)
	elseif cmd.args == 1 then
		--Commands with a single arg, get it sent in as is.
		UdpApi:send(cmd.code, unpack(args))
	else
		--Commands with a more than 1 arg, get it sent in bunbled up in a table.
		UdpApi:send(cmd.code, args)
	end
	
	if cmd.rt then
		return UdpApi:fetchReturn(self.return_timeout)
	else
		return nil, "got-nil: Command has no return value. It is running as expected."
	end
	
	return true	
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
-- @param fps=maxxed-out		#number		; 	fps of the video. Should provide a default. Heck, you can skip implementing this one if you want.
function PeripheralApi:drawCnnVideoStream(x, y, w, h, fps)
	--TODO: Implement.
end

------------------------------ API - Sensors ------------------------------
---Use the gyroscope to check whether the robot is able to continue moving or has fallen over. 
-- Note: I'm guessing you either hardcode values into this, or slap some param in :init(config) to allow some tweaking for this?
-- @return 						#bool		;	Whether it has fallen.
function PeripheralApi:isFallen()
	return self:_sendCmd("sensor_gyro_is_fallen")
end

---Returns the distance from the left ultrasonic to the nearest object. In centimeters.
-- @return 						#number		;	Distance in cm.
function PeripheralApi:readLeftUltrasonic()
	return self:_sendCmd("sensor_ultrasonic_left")
end

---Returns the distance from the right ultrasonic to the nearest object. In centimeters.
-- @return 						#number		;	Distance in cm.
function PeripheralApi:readRightUltrasonic()
	return self:_sendCmd("sensor_ultrasonic_right")
end

------------------------------ API - Networking ------------------------------
---Checks if the remote is currently connected to the robot. Returns a bool, not the delay.
-- @return 						#bool		;	Whether the robot is connected or not.
function PeripheralApi:ping()
	--TODO: Implement.
	return not love.keyboard.isDown('p')
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
	if AppData.CAN_REBOOT then
		os.execute("reboot")
	else
		print("Rebooting is currently disabled! To enable: Access <prj_loc>/remote/src/AppData.lua and change CAN_REBOOT to \"true\".")
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

function PeripheralApi:moveWheel(dir, deg)
	deg = cleanUpWheelArg(self, deg)
	if not deg then return false end
	local cmdName = "wheel_" .. dir
	return self:_sendCmd(cmdName, deg)
end

------------------------------ API - Movement - Cutters ------------------------------
---Unlike the getters/setters below; those actually set the position of the cutters to their arg.
--		These are not some default-y or stateful setup.
-- @param deg=0						#number		;	Angle of the cutter-worm.
function PeripheralApi:setCutterWormAngle(deg)
	deg = deg or 0
	deg = lume.clamp(deg, self.CUTTER_WORM_ANGLE_MIN, self.CUTTER_WORM_ANGLE_MAX)
	--Note: This variable is only kept so that the getter works which is only used
	--		to display this value to the user in the GUI. The robot does not actually allow
	--		getting the cutter angle.
	if self:_sendCmd("c_worm_set", deg) then
		self.cutterWormAngle = deg
		return true
	end
	return false
end
function PeripheralApi:getCutterWormAngle()
	return self.cutterWormAngle
end

---Same concept as (set/get)cutterWormAngle.
-- @param deg=0						#number		;	Angle of the cutter-wheel.
function PeripheralApi:setCutterWheelAngle(deg)
	deg = deg or 0
	deg = lume.clamp(deg, self.CUTTER_WHEEL_ANGLE_MIN, self.CUTTER_WHEEL_ANGLE_MAX)
	--Note: This variable is only kept so that the getter works which is only used
	--		to display this value to the user in the GUI. The robot does not actually allow
	--		getting the cutter angle.
	if self:_sendCmd("c_wheel_set", deg) then
		self.cutterWheelAngle = deg
		return true
	end
	return false
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

--You know how the robot works. Do you think I missed anything?
return PeripheralApi()


/////////////////Exiting file: PeripheralApi.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: PiApi.lua/////////////////
local class = require "libs.middleclass"

local AppData = require "AppData"

--Guard-clause for when running on a dev-machine, not an actual Pi,
--Periphery will not be installed and all calls to it's API will be
--	forwarded to blank versions.
--This facilitates development on non-Pi machines. 
local Serial, Gpio
--local FORCE_DUMMY = true
do
	local succ, msg = pcall(require, "periphery")
	if succ and not FORCE_DUMMY then
		print("Loading Lua-Periphery for board functions")
		Serial = require("periphery").Serial
		Gpio = require("dummyPeriphery").GPIO
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
		ultrasonicLeftTrig = 	24,			--"GPIO.24"
		ultrasonicLeftEcho = 	25,			--"GPIO.25"
		 
		ultrasonicRightTrig = 	26,			--"GPIO.26"
		ultrasonicRightEcho = 	27,			--"GPIO.27"
		
		gyroscopeSda = 			"SDA.0",
		gyroscopeScl = 			"SDA.1",
	},
	
	modules = {
		ultrasonic =	{moduleTag = "HC-SR04",											count = 2,		groups = {'left',	'right'}		},
		gyroscope =		{moduleTag = "MPU9265",											count = 1,		groups = {}							},
		nano =			{moduleTag = "Arduino Nano ATMega368 (old bootloader)",			count = 3,		groups = {'usb',	'nc',	'nc'}	},
		},

	serial = {
		port = "/dev/ttyUSB0",
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
	self.serialEoc = cfg.eoc
end

---Recives a valid command name, converts it to it's respective code,
--	appends terminating characters and then transmits it to the Nano.
--Note: No validation is done on the cmdName, must be done by the user.
function PiApi:_transmitSerialCmd(code, ...)
	local args = {...}
	local str = code .. self.serialEoc
	for i = 1, #args do
		str = str .. args[i] .. self.serialEoc
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
	local dist = len * 17150
	return dist

	--TODO: Test this out on real hardware and confirm the results.
end

---Returns the raw-reading of the gyroscope value. Module in use: MPU9265
function PiApi:_readGyroscope()
	--TODO: Implement.
end

------------------------------ Core - System Specs ------------------------------
function PiApi:update(dt)
	local buf = self.serial:read(self.serial:input_waiting())
	if #buf > 0 then
		print("[nano/] " .. buf)
	end
		
end

------------------------------ API - System Specs ------------------------------
function PiApi:getCpuTemp()
	--TODO: Implement
	return "40.2'C"
end

function PiApi:getGpuTemp()
	--TODO: Implement
	return "38.3'C"
end

function PiApi:getCpuLoad()
	--TODO: Implement
	return "83%"
end

function PiApi:getGpuLoad()
	--TODO: Implement
	return "95%"
end

function PiApi:getRamUsage()
	--TODO: Implement
	return "0.5GB/8GB"
end

function PiApi:getDiskUsage()
	--TODO: Implement
	return "15GB/32GB"
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


/////////////////Exiting file: PiApi.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: UdpApi.lua/////////////////
local class = require "libs.middleclass"
local sock = require "libs.sock"

local PiApi = require "PiApi"
local Scheduler = require "libs.Scheduler"

local AppData = require "AppData"

------------------------------ Private Values ------------------------------
local lastUltrasonicUpdate = 0
------------------------------ Heleprs ------------------------------
local function peerToString(peer)
	return string.format("{%s}", table.concat(peer, ", "))
end

------------------------------ Constructor ------------------------------
local UdpApi = class("UdpApi")
--Note: This class is a singleton.
function UdpApi:initialize()
	self.ULTRASONIC_UPDATE_INTERVAL = 2
	self:_initServer()
end

------------------------------ Internals ------------------------------
function UdpApi:_initServer()
	self.openIp = AppData.openIp
	self.port = AppData.port
	self.server = sock.newServer(self.openIp, self.port)
	self:_injectEvents()
	Scheduler:callEvery(AppData.PING_INTERVAL, function()
		self:pingAll()
	end)
end

------------------------------ Core API ------------------------------
function UdpApi:update(dt)
	if love.timer.getTime() - lastUltrasonicUpdate > self.ULTRASONIC_UPDATE_INTERVAL then
		local distLeft = PiApi:readUltrasonicLeft()
		local distRight = PiApi:readUltrasonicRight()
		
		self:sendToAll("sensor_ultrasonic_left", distLeft)
		self:sendToAll("sensor_ultrasonic_right", distRight)
		lastUltrasonicUpdate = love.timer.getTime()
	end
	
	self.server:update(dt)
end

------------------------------ API ------------------------------
function UdpApi:pingAll()
	self:sendToAll("ping")
end

function UdpApi:sendToAll(ev, data)
	self.server:sendToAll(ev, data)
end

function UdpApi:sendToPeer(ev, data, peer)
	self.server:sendToAll(ev, data)
end

function UdpApi:sendToAllBut(ev, data, exc)
	self.server:sendToAll(ev, data)
end

------------------------------ Internals ------------------------------
function UdpApi:_injectEvents()
	for ev, callback in pairs(self.events) do
		self.server:on(ev, function(...) callback(self, ...) end)
	end
end

------------------------------ Getters / Setters ------------------------------

------------------------------ Events ------------------------------
UdpApi.events = {}

--Connection
function UdpApi.events:connect(msg, peer)
	local str = string.format("Client has connected! [client=%s]",
			peerToString(peer))
	print(str) 
end

function UdpApi.events:disconnect(msg, peer)
	local str = string.format("Client has disconnected! [client=%s]",
			peerToString(peer))
	print(str) 
end

--Sys
function UdpApi.events:sys_reboot()
	PiApi:reboot()
end

--Arm
function UdpApi.events:arm_stop()
	PiApi:armStop()
end

function UdpApi.events:arm_forward(speed)
	PiApi:armForward(speed)
end

function UdpApi.events:arm_backward(speed)
	PiApi:armBackward(speed)
end

function UdpApi.events:arm_up(speed)
	PiApi:armUp(speed)
end

function UdpApi.events:arm_down(speed)
	PiApi:armDown(speed)
end

--Wheel
function UdpApi.events:wheel_stop()
	PiApi:wheelStop()
end

function UdpApi.events:wheel_forward(speed)
	PiApi:wheelForward(speed)
end

function UdpApi.events:wheel_backward(speed)
	PiApi:wheelBackward(speed)
end

function UdpApi.events:wheel_left(speed)
	PiApi:wheelLeft(speed)
end

function UdpApi.events:wheel_right(speed)
	PiApi:wheelRight(speed)
end

--Cutters
function UdpApi.events:c_worm_set(angle)
	PiApi:setCutterWormAngle(angle)
end

function UdpApi.events:c_wheel_set(angle)
	PiApi:setCutterWheelAngle(angle)
end

--Sensors
function UdpApi.events:sensor_gyroscope_is_fallen()
	PiApi:isFallen()
end

return UdpApi()



/////////////////Exiting file: UdpApi.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: conf.lua/////////////////
function love.conf(t)
  -- Commented out defaults shown below.
  -- See https://www.love2d.org/wiki/Config_Files for more information.

   t.identity = "robot_server"                    -- The name of the save directory (string)
   t.version = "11.1"                -- The L�VE version this game was made for (string)
  -- t.console = false                   -- Attach a console (boolean, Windows only)
   t.accelerometerjoystick = false      -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
  -- t.externalstorage = false           -- True to save files (and read from the save directory) in external storage on Android (boolean) 
  -- t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)

   t.window.title = "Robot Server"         -- The window title (string)
  -- t.window.icon = nil                 -- Filepath to an image to use as the window's icon (string)
   t.window.height = 320                 -- The window height (number)
   t.window.width = 480                  -- The window width (number)
   t.window.borderless = true            -- Remove all border visuals from the window (boolean)
  -- t.window.resizable = false          -- Let the window be user-resizable (boolean)
  -- t.window.minwidth = 1               -- Minimum window width if the window is resizable (number)
  -- t.window.minheight = 1              -- Minimum window height if the window is resizable (number)
  -- t.window.fullscreen = false         -- Enable fullscreen (boolean)
  -- t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
  -- t.window.vsync = true               -- Enable vertical sync (boolean)
  -- t.window.msaa = 0                   -- The number of samples to use with multi-sampled antialiasing (number)
  -- t.window.display = 1                -- Index of the monitor to show the window in (number)
  -- t.window.highdpi = false            -- Enable high-dpi mode for the window on a Retina display (boolean)
   t.window.x = 0                        -- The x-coordinate of the window's position in the specified display (number)
   t.window.y = 0                        -- The y-coordinate of the window's position in the specified display (number)

   t.modules.audio = false               -- Enable the audio module (boolean)
  -- t.modules.event = true              -- Enable the event module (boolean)
  -- t.modules.graphics = true           -- Enable the graphics module (boolean)
  -- t.modules.image = true               -- Enable the image module (boolean)
   t.modules.joystick = false            -- Enable the joystick module (boolean)
  -- t.modules.keyboard = true           -- Enable the keyboard module (boolean)
  -- t.modules.math = true               -- Enable the math module (boolean)
  -- t.modules.mouse = true              -- Enable the mouse module (boolean)
   t.modules.physics = false             -- Enable the physics module (boolean)
   t.modules.sound = false               -- Enable the sound module (boolean)
  -- t.modules.system = true             -- Enable the system module (boolean)
  -- t.modules.timer = true              -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
  -- t.modules.touch = true              -- Enable the touch module (boolean)
   t.modules.video = false               -- Enable the video module (boolean)
  -- t.modules.window = true             -- Enable the window module (boolean)
   t.modules.thread = false              -- Enable the thread module (boolean)
end


/////////////////Exiting file: conf.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: deprecated_Display.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local socket = require "socket"

local ConsoleStringBuilder = require "libs.ConsoleStringBuilder"
local PiApi = require "PiApi"

local AppData = require "AppData"

------------------------------ Local Constants ------------------------------
local CONSOLE_LINES = 9
local CONSOLE_CHARS_PER_LINE = 67

------------------------------ Helpers ------------------------------
--Note: This function is available as part of love's math module
--	since version 11.3,
--This is placed here since at this time, this program runs on 11.1
local function colorFromBytes(r, g, b, a)
	local nr = r / 255
	local ng = g / 255
	local nb = b / 255
	local na = a and a / 255 or nil
	return nr, ng, nb, na
end

local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function getTextH(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getHeight()
end

------------------------------ Constructor ------------------------------
local Display = class("Display")
--Note: This class is a singleton.
function Display:initialize()
	love.graphics.setBackgroundColor(self.BACKGROUND_COLOR)
	--local succ, ip = pcall(os.execute, "ipconfig getifaddr en1")
	local succ, handle = pcall(io.popen, "ipconfig getifaddr en1") 
	if succ then
		local ip = handle:read("*a"):sub(1, -2)
		self.machineIp = ip
		handle:close()
	else
		self.machineIp = "failed-to-fetch"
	end
	
	self.fonts = {
		ROBOTO_MONO_REGULAR = love.graphics.newFont("assets/roboto_mono/RobotoMono-Regular.ttf"),
	}
		
	self.console = ConsoleStringBuilder(CONSOLE_LINES, CONSOLE_CHARS_PER_LINE)
		
end

------------------------------ Constants ------------------------------
Display.BACKGROUND_COLOR = {colorFromBytes(32, 31, 99)}

Display.SCREEN_W = 480
Display.SCREEN_H = 320
Display.LINE_H = 30
Display.STAT_INDENT = 130

local CONSOLE_LINES = 15
local CONSOLE_CHARS_PER_LINE = 67

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = Display.SCREEN_W,
	H = Display.SCREEN_H,
	AutoSizeWindow = false,
	BgColor = Display.BACKGROUND_COLOR,
}

local _h = getTextH("foo") * CONSOLE_LINES
local consoleWindow = {
	id = "console",
	X = 0,
	Y = Display.SCREEN_H - _h,
	--To prevent Slab.Textf's wrapped texted from displaying a (1 pixel) scroll bar.
	W = love.graphics.getWidth() - 1,
	H = _h,
	AutoSizeWindow = false,
	BgColor = Display.BACKGROUND_COLOR,
}

local isConfirming
local popupQuit = {
	id = "Quitting!",
	msg = "Are you sure you want to quit?\n\n  You can start the program back up\nby launching \"Robot Controller\"\nfrom your desktop.",
	Buttons = {"Quit!", "Cancel"},
	onClick = function(result)
		if result == "Quit!" then
			PiApi:quit()
		end
		return nil
	end
}

local popupRebootRobot = {
	id = "Rebooting Robot!",
	msg = "Are you sure you want to reboot the robot?\n\n  This may take a few minutes.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PiApi:reboot()
		end
		return nil
	end
}

------------------------------ Core API ------------------------------
function Display:update(dt)
	Slab.BeginWindow(window.id, window)
	--Monitoring - CPU
	Slab.Text("CPU: " .. PiApi:getCpuLoad())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 0)
	Slab.Text("CPU TEMP: " .. PiApi:getCpuTemp())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 0)
	Slab.Text("OPEN IP's: *")

	--Monitoring - GPU
	Slab.SetCursorPos(0, self.LINE_H * 1)
	Slab.Text("GPU: " .. PiApi:getGpuLoad())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 1)
	Slab.Text("GPU TEMP: " .. PiApi:getGpuTemp())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 1)
	Slab.Text("MACHINE IP: " .. self.machineIp)
		
	--Monitoring - Data
	Slab.SetCursorPos(0, self.LINE_H * 2)
	Slab.Text("RAM: " .. PiApi:getRamUsage())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 2)
	Slab.Text("DISK: " .. PiApi:getDiskUsage())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 2)
	Slab.Text("PORT: " .. AppData.port)	
	
	--Quit
	Slab.SetCursorPos(self.SCREEN_W - 205, self.SCREEN_H - 32)
	if Slab.Button("Quit") then
		isConfirming = popupQuit
	end

	--Reboot
	Slab.SetCursorPos(self.SCREEN_W - 105, self.SCREEN_H - 32)
	if Slab.Button("Reboot") then
		isConfirming = popupRebootRobot
	end

	if isConfirming then
		local result = Slab.MessageBox(isConfirming.id, isConfirming.msg, isConfirming)
		if result ~= "" then
			isConfirming = isConfirming.onClick(result)
		end
	end
		
	Slab.EndWindow()
	
	Slab.BeginWindow(consoleWindow.id, consoleWindow)
	Slab.PushFont(self.fonts.ROBOTO_MONO_REGULAR)
	
	Slab.Text(self.console:getContent())
	
	Slab.PopFont()	
	Slab.EndWindow()
end

function Display:draw(g2d)
	
end

return Display()

/////////////////Exiting file: deprecated_Display.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: dummyPeriphery.lua/////////////////
local m = {}

function m.Serial(port, baudrate)
	local self = {}
	self.port = port
	self.baudrate = baudrate
	
	function self:write(str)
		print("[dummyPeriphery/serial:write]: " .. str)
	end
	
	function self:read(len)
		local str = ""
		for i = 1, len do
			str = str .. "0"
		end
		return str
	end
	
	function self:input_waiting()
		return 0
	end
	return self
end

function m.GPIO(pin, dir)
	local self = {}
	self.pin = pin
	self.dir = dir
	
	function self:write(state)
--		local str = string.format("[dummyPeriphery/%s:write: ] %s",
--				self.pin, state)
--		print(str)
	end
	
	function self:read()
--		local str = string.format("[dummyPeriphery/%s:read: ] hardcoded-true",
--				self.pin)
--		print(str)
		return true
	end
	return self
end

return m

/////////////////Exiting file: dummyPeriphery.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: dummyServer.lua/////////////////
local sock = require "libs.sock"
local Scheduler = require "libs.Scheduler"

local AppData = require "AppData"

------------------------------ Commands ------------------------------
local CMDS = {
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

------------------------------ Upvalues ------------------------------
local server

------------------------------ Setup ------------------------------
local ip = "*"
local port = AppData.port
server = sock.newServer("*", port)


------------------------------ Core API ------------------------------
local function load()
	print("Started running server on: " .. ip .. ":" .. port)
	Scheduler:callEvery(AppData.PING_INTERVAL, function()
		server:sendToAll("ping", love.timer.getTime())
	end)
end


local function update(dt)
	server:update(dt)
	Scheduler:tick(dt) 
end

------------------------------ Events ------------------------------
--Connection
server:on("connect", function(...)
	printArgs(...)
	print("Client has connected!")
end)
server:on("disconnect", function(...)
	printArgs(...)
	print("Client has disconnected!")
end)

--Arm
server:on("arm_stop", function()
	print(CMDS.arm_stop.code)
end)

server:on("arm_forward", function(speed)
	print(CMDS.arm_forward.code, speed)
end)
server:on("arm_backward", function(speed)
	print(CMDS.arm_backward.code, speed)
end)
server:on("arm_up", function(speed)
	print(CMDS.arm_up.code, speed)
end)
server:on("arm_down", function(speed)
	print(CMDS.arm_down.code, speed)
end)

--Wheel
server:on("wheel_stop", function()
	print(CMDS.wheel_stop.code)
end)

server:on("wheel_forward", function(speed)
	print(CMDS.wheel_forward.code, speed)
end)
server:on("wheel_backward", function(speed)
	print(CMDS.wheel_backward.code, speed)
end)
server:on("wheel_left", function(speed)
	print(CMDS.wheel_left.code, speed)
end)
server:on("wheel_right", function(speed)
	print(CMDS.wheel_right.code, speed)
end)
--Cutter
server:on("c_worm_set", function(angle)
	print(CMDS.c_worm_set.code, angle)
end)

server:on("c_wheel_set", function(angle)
	print(CMDS.c_wheel_set.code, angle)
end)

--Sensor
server:on("sensor_ultrasonic_left", function(angle)
	print(CMDS.sensor_ultrasonic_left.code, angle)
end)
server:on("sensor_ultrasonic_right", function(angle)
	print(CMDS.sensor_ultrasonic_right.code, angle)
end)
server:on("sensor_gyroscope_is_fallen", function(angle)
	print(CMDS.sensor_gyroscope_is_fallen.code, angle)
end)




return {load = load, update = update}

/////////////////Exiting file: dummyServer.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ClassTemplate.lua/////////////////
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


/////////////////Exiting file: ClassTemplate.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ConsoleStringBuilder.lua/////////////////
local class = require "libs.middleclass"
local utils = require "libs.utils"

------------------------------ Constructor ------------------------------
local ConsoleStringBuilder = class("ConsoleStringBuilder")
function ConsoleStringBuilder:initialize(lines, charsPerLine)
	self.lines = lines
	self.charsPerLine = charsPerLine
	
	self.str = ""
end

------------------------------ API ------------------------------
function ConsoleStringBuilder:print(...)
	local args = {...}
	local str = ""
	if #args == 0 then
		str = "\n"
	else
		for k, v in ipairs(args) do
			str = str .. v .. " "
		end
		str = str:sub(1, -2)	--Remove trailing space.
	end
	self:_addString(str .. '\n')
end

function ConsoleStringBuilder:clear()
	self.str = ""
end

------------------------------ Internals ------------------------------
function ConsoleStringBuilder:_addString(str)
	for i = 1, #str do
		local c = str:sub(i, i)
		if c == "\n" then
			repeat
				self.str = self.str .. " "
			until self:getRealStrLen() % self.charsPerLine == 0
			self.str = self.str .. "\n"
			if self:getRealStrLen() == self.lines * self.charsPerLine then
				--print("out of screen")
				self.str = self.str:sub(self.charsPerLine + 2)
			end		
		else
			self.str = self.str .. c
			--print(#self.str)
			if self:getRealStrLen() % self.charsPerLine == 0 then
				--print("str mod 0")
				self.str = self.str .. "\n"
				if self:getRealStrLen() == self.lines * self.charsPerLine then
					--print("out of screen")
					self.str = self.str:sub(self.charsPerLine + 2)
				end
			end
		end
	end
end

------------------------------ Getters / Setters ------------------------------
function ConsoleStringBuilder:getContent()
	return self.str
end

--Returns the length of the screen counting only chars that are drawable
--	onto the screen. Currently, only removes "\n", sadly.
function ConsoleStringBuilder:getRealStrLen()
	return #utils.str.rem(self.str, "\n")
end


return ConsoleStringBuilder

/////////////////Exiting file: ConsoleStringBuilder.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: FilepathUtils.lua/////////////////
local FilepathUtils = {}

FilepathUtils.love = {}
FilepathUtils.love.path = {}
FilepathUtils.love.path.src = ""
FilepathUtils.love.path.saves = nil

FilepathUtils.love.path.istatsData = FilepathUtils.love.path.src .. "/istats/data/"
FilepathUtils.love.path.istatsDefaults = FilepathUtils.love.path.src .. "/istats/defaults/"
--FilepathUtils.love.path.istatsDefaultsIdv = FilepathUtils.love.path.src .. "/istats/defaults/idv/"
--FilepathUtils.love.path.istatsDefaultsInstv = FilepathUtils.love.path.src .. "/istats/defaults/instv/"

--FilepathUtils.lua = {}
--FilepathUtils.lua.path = {}
--FilepathUtils.lua.path.src = "src"
--FilepathUtils.lua.path.saves = nil
--
--FilepathUtils.lua.path.istatsData = FilepathUtils.lua.path.src .. "/istats/data/"

return FilepathUtils

/////////////////Exiting file: FilepathUtils.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Scheduler.lua/////////////////
local class = require "libs.cruxclass"

------------------------------ Helper Methods ------------------------------
local getTime = love.timer.getTime
local ins = table.insert
local rem = table.remove
local modf = math.modf
local floor = math.floor

local function findIndex(t, obj)
	for k, v in ipairs(t) do
		if obj == v then return k end
	end
	return false
end

local function execute(t, dt, i, interval, timeout, func, args)
	args = type(args) == 'table' and args or {args}
	if dt then 
		t.tdt[i] = t.tdt[i] + dt
		local r = interval == -1 and 0 or interval
		local per = math.min(t.tdt[i] / (timeout - r), 1)
		func(dt, per, unpack(args))
	else func(unpack(args)) end
end

local function remove(t, i)
	rem(t.wait,     i)
	rem(t.interval, i)
	rem(t.timeout,  i)
	rem(t.stamp,    i)
	rem(t.tdt,      i)
	rem(t.flag,     i)
	rem(t.last,     i)
	rem(t.runs,     i)
	rem(t.func,     i)
	rem(t.args,     i)
	rem(t.wrapup,   i)
	rem(t.wargs,    i)
end

local function yield(t, i)
	if t.wrapup[i] then execute(nil, nil, nil, nil, nil, t.wrapup[i], t.wargs[i]) end
	remove(t, i)
end

local function process(t, dt, i, wait, interval, timeout, stamp, flag, last, runs, func, args)
	local time = getTime()
	
	if time >= stamp + wait then								--If (at or post 'wait'); proceed 
		if interval == 0 then									--	If 'interval' == 0; single execution
			local dt = time - stamp								--
			execute(t, dt, i, interval, timeout, func, args)	--		Execute once; 'fdt' = time since initial scheduling
			return true											--		Yield
		elseif timeout == 0 or time <= stamp + timeout then		--	If (no timeout is set) or (within timeout); proceed
			if interval == -1 then								--		If interval == -1; execute every tick
				local fdt = flag == 0 and dt or time - stamp	--			'fdt' = (first run) ? tick-dt : time since initial scheduling 
				t.flag[i] = 0									--			Set 'first run' flag
				execute(t, fdt, i, interval, timeout, func, args)--			Execute
			else												--		If 'interval' set (not 0 and not -1); execute every 'interval' for 'timeout'
				local fdt, dif, reruns							--			[1]elaborated below
				if flag == -1 then								--
					fdt = time - stamp							--
					dif = time - stamp - wait					--
				else											--
					fdt = time - last							--
					dif = time - flag							--
				end												--
																--
				reruns = floor(dif / interval)					--
				dif = dif % interval							--
				if flag == -1 then reruns = reruns + 1 end		--
																--
--				print('dt', dt, 'fdt', fdt, 'dif', dif, 'flag', flag, 'reruns', reruns, 'interval', interval)
				for _i = 1, reruns do							--
					execute(t, _i == 1 and fdt or 0, i, interval, timeout, func, args)
					t.runs[i] = t.runs[i] + 1					--
--					if i == reruns then flag = time end			--
					if _i == reruns then						-- 
						dif = 0 								--
						t.last[i] = time						--
						t.flag[i] = time - dif					--						
					end											--
				end												--
--				print('dt', dt, 'fdt', fdt, 'dif', dif, 'flag', flag, 'reruns', reruns, 'interval', interval)
			end													--
		else													-- 
			if last ~= -1 then									--
				for _ = 1, (timeout / interval) - runs do		-- 
					execute(t, 0, i, interval, timeout, func, args)
				end												--
			end													--
			return true 										--
		end														--	If timed out; yield
	end
end

--[[
Execution:
once at or post 'wait':
	if interval == 0 -> execute then remove; //dt equals time - stamp  
	elseif interval == -1
		if timeout == 0 or within timeout, execute;	//dt if first time equals time - stamp
		else remove;								//else equals tick dt
		(repeat the above 'if' once every tick)
	else;
		execute every INTERVAL for TIMEOUT ; 
		if ticks took longer than INTERVAL -> execute multiple times per tick
		[1][elaborated below]

[1]
if timed out; yield
if flag == -1
	fdt = time - stamp
	dif = time - stamp - wait
else
	fdt = time - last
	dif = time - flag
	
reruns = floor(dif / interval)
dif = dif % interval

if flag == -1 then reruns++ end

for i = 1, reruns do
	execute(i == 1 and fdt or 0)		--if multiple executions in a row, the first is passed dt the rest are passed 0
	if i + 1 == reruns then flag = time end
end
last = flag
flag = flag - dif

[2] examples !!! outdated !!!
stamp = 30
wait = 5
interval = 1
flag = -1

------------ first run [time = 35.3] //since stamp = 5.3	;	since first run 0.3
fdt = 5.3
dif = 0.3
	reruns, dif = 0++, 0.3 [0.3 / 1 ; ++]
	
flag = 35.0

------------ second run [time = 36.8] //since stamp = 6.8	;	since first run 1.8
fdt = 1.8
dif 1.8
	reruns, dif = 1, 0.8 [1.8 / 1]
	
flag = 36.0

------------ third run [time = 38.3] //since stamp = 8.3	;	since first run 3.3
fdt = 1.8
dif = 2.3
	reruns, dif = 2, 0.3 [2.3 / 1]

flag = 38.0

------------ fourth run [time = 39.8] //since stamp = 9.8	;	since first run 4.8
fdt = 1.8
dif 1.8
	reruns, dif = 1, 0.8 [1.8 / 1]
	
flag = 39.0	
--]]
------------------------------ Constructor ------------------------------
local Scheduler = class("Scheduler")
function Scheduler:init()
	self.tasks = {wait = {}, interval = {}, timeout = {}, stamp = {}, tdt = {},
			flag = {}, last = {}, runs = {}, func = {}, args = {}, wrapup = {}, wargs = {}}
		
	self.gtasks = {wait = {}, interval = {}, timeout = {}, stamp = {}, tdt = {},
			flag = {}, last = {}, runs = {}, func = {}, args = {}, wrapup = {}, wargs = {}}		
end

------------------------------ Main Methods ------------------------------
--TODO: pass graphical tasks a 'g' param in place of 'dt'.
local function processAll(t, dt)
	local yielded = {}
	for i = 1, #t.func do	--All subtables of self.tasks should always be of equal length.
		local done = process(t, dt, i, t.wait[i], t.interval[i], t.timeout[i], t.stamp[i], 
				t.flag[i], t.last[i], t.runs[i], t.func[i], t.args[i])
		if done then ins(yielded, i) end
	end
		
	for i = 1, #yielded do	--Remove yielded entries in reverse order (so indices remain consistent during yielding)
		yield(t, yielded[#yielded + 1 - i])
	end
end

function Scheduler:tick(dt)
	processAll(self.tasks, dt)
end

local gPrevTime = 0, getTime()
function Scheduler:draw(g)
	local dt = getTime() - gPrevTime
	processAll(self.gtasks, dt)
	gPrevTime = getTime()
end

------------------------------ Schedule Method ------------------------------
function Scheduler:schedule(wait, interval, timeout, stamp, func, args, wrapup, wargs, graphical)
	local t = graphical and self.gtasks or self.tasks
	ins(t.wait,     wait     or 0)
	ins(t.interval, interval or 0)
	ins(t.timeout,  timeout  or 0)
	ins(t.stamp,    stamp    or getTime())
	ins(t.tdt,       0)
	ins(t.flag,     -1)
	ins(t.last,     -1)
	ins(t.runs,      0)
	ins(t.func,     func)
	ins(t.args,     args     or {})
	ins(t.wrapup,   wrapup)
	ins(t.wargs,    wargs    or {})
end

------------------------------ Schedule Shortcuts ------------------------------
function Scheduler:callAfter(wait, func, args, wrapup, wargs)
	self:schedule(wait, nil, nil, nil, func, args, wrapup, wargs)
end

function Scheduler:callFor(timeout, func, args, wrapup, wargs)
	self:schedule(nil, -1, timeout, nil, func, args, wrapup, wargs)
end

function Scheduler:callEvery(interval, func, args, wrapup, wargs)
	self:schedule(nil, interval, nil, nil, func, args, wrapup, wargs)
end

function Scheduler:callEveryFor(interval, timeout, func, args, wrapup, wargs)
	self:schedule(nil, interval, timeout, nil, func, args, wrapup, wargs)
end

------------------------------ Schedule Graphical Shortcuts ------------------------------
function Scheduler:gCallAfter(wait, func, args, wrapup, wargs)
	self:schedule(wait, nil, nil, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallFor(timeout, func, args, wrapup, wargs)
	self:schedule(nil, -1, timeout, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallEvery(interval, func, args, wrapup, wargs)
	self:schedule(nil, interval, nil, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallEveryFor(interval, timeout, func, args, wrapup, wargs)
	self:schedule(nil, interval, timeout, nil, func, args, wrapup, wargs, true)
end
------------------------------ Cancel Methods ------------------------------
function Scheduler:cancel(func)
	local i = type(func) == 'number' and func or findIndex(self.tasks.func, func)
	if i then remove(self.tasks, i) end
	--Graphical tasks:
	i = type(func) == 'number' and func or findIndex(self.gtasks.func, func)
	if i then remove(self.gtasks, i) end
end

function Scheduler:cancelAll()
	for i = 1, self.tasks.func do
		remove(self.tasks, i)
	end
	--Graphical tasks:
	for i = 1, self.gtasks.func do
		remove(self.gtasks, i)
	end
end
------------------------------ Yield Methods ------------------------------
function Scheduler:yield(func)
	local i = type(func) == 'number' and func or findIndex(self.tasks.func, func)
	if i then yield(self.tasks, i) end
	--Graphical tasks:
	i = type(func) == 'number' and func or findIndex(self.gtasks.func, func)
	if i then yield(self.gtasks, i) end
end

function Scheduler:yieldAll()
	for i = 1, self.tasks.func do
		yield(self.tasks, i)
	end
	--Graphical tasks:
	for i = 1, self.gtasks.func do
		yield(self.gtasks, i)
	end
end

return Scheduler()


/////////////////Exiting file: Scheduler.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Fsm.lua/////////////////
--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"
local State = require "libs.SimpleFsm.State"

------------------------------ Nil State ------------------------------
local NilState = class("NilState", State)

------------------------------ Constructor ------------------------------
local Fsm = class("Fsm")
function Fsm:initialize()
	local ns = NilState()
	self.states = {["nil"] = ns}
	self.curState = ns
end

------------------------------ Core API ------------------------------

--[[
Callbacks only have to be defined by the FSM for ones that wish to override the default hookIntoLove behavior.
Which is: 
	if self.curState and self.curState[callbackName] then 
		self.curState[callbackName](pass-all-default-love-params-for-callback)
--]]
function Fsm:draw()
	if not self.curState.draw then return end
	
	local g2d = love.graphics
	self.curState:draw(g2d)
end

function Fsm:at(id)
	if id then
		return self.states[id] == self.curState
	else
		for k, v in pairs(self.states) do
			if self.curState == v then return k end
		end
	end
end

function Fsm:goto(id, ...)
	local state = self.states[id]
	if not state then return false end
	if self.curState == state then return false end
	
	self.curState:leave(state)
	local previous = self.curState
	self.curState = state
	self.curState:enter(previous, ...)
	return true
end

function Fsm:add(id, state)
	if self.states[id] then return false end
	
	self.states[id] = state
	state:activate(self)
	return true
end

function Fsm:remove(id)
	local state = self.states[id]
	if not state then return false end
	
	if self.curState == state then self.curState = nil end

	state:destroy()
	self.states[id] = nil
	return true
end

------------------------------ Love Hook ------------------------------
local function hookLoveCallback(Fsm, loveStr, fsmStr)
	fsmStr = fsmStr or loveStr
	local preF = love[loveStr]
	
	love[loveStr] = function(...)
		if preF then preF(...) end
		
		if Fsm[fsmStr] then 
			Fsm[fsmStr](Fsm, ...)
		elseif Fsm.curState[fsmStr] then 
			Fsm.curState[fsmStr](Fsm.curState, ...)
		end
	end
end

function Fsm:hookIntoLove()
	hookLoveCallback(self, "update")
	hookLoveCallback(self, "draw")
	hookLoveCallback(self, "keypressed", "keyPressed")
	hookLoveCallback(self, "keyReleased", "keyReleased")
	hookLoveCallback(self, "mousemoved", "mouseMoved")
	hookLoveCallback(self, "mousePressed", "mousePressed")
	hookLoveCallback(self, "textinput", "textInput")
	hookLoveCallback(self, "wheelMoved", "wheelMoved")
	--TODO: Implement the rest.
end

------------------------------ Getters / Setters ------------------------------
function Fsm:getStates()
	return self.states
end

function Fsm:getCurrentState()
	return self.curState
end

return Fsm

--[[

state
current state
transitionTo

--]]


/////////////////Exiting file: Fsm.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: State.lua/////////////////
--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local State = class("State")
function State:initialize()
end

------------------------------ Core API ------------------------------
function State:update(dt)
end

function State:draw(g2d)
end

function State:enter(from, ...)
	print("Entered: " .. self.fsm:at())
end

function State:leave(to)
	--FIXME: fsm is nil.
	--print("Left: " .. self.fsm:at())
end

function State:activate(fsm)
	self.fsm = fsm
end

function State:destroy()
end

------------------------------ Getters / Setters ------------------------------

return State

--[[

activate
destroy
enter
leave
update
draw

--]]


/////////////////Exiting file: State.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: main.lua/////////////////
local Fsm = require "libs.SimpleFsm.Fsm"
local State = require "libs.SimpleFsm.State"

--Test
local state1 = State()
state1.update = function(dt) print("state1 update!") end
state1.enter = function(fsm, from, ...) print("entered state1 with vars: ", ...) end
state1.leave = function(fsm, to, ...) print("left state1") end

local state2 = State()
state2.update = function(dt) print("state2 update!") end
state2.enter = function(fsm, from, ...) print("entered state2 with vars: ", ...) end
state2.leave = function(fsm, to, ...) print("left state2") end

local fsm = Fsm()
fsm:add(state1)
fsm:add(state2)

function love.load(args)
	fsm:hookIntoLove()
	fsm:goto(state1)
	fsm:goto(state1)	--Does nothing.
	fsm:goto(state2)
	fsm:goto(state1, "Hello", "World!", 42)
end

function love.update(dt)
	print("Original update!")
end

function love.draw()
	local g2d = love.graphics
	print("Original draw!")
end

/////////////////Exiting file: main.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: utils.lua/////////////////
local utils = {}
utils.t = {}
utils.str = {}

------------------------------ Misc. ------------------------------
function utils.class(name, ...)
	local function classIs(class, otherClass)
		for k, v in ipairs(class) do
			if v == otherClass then return true end
		end
		return false
	end
	local supers = {...}
	local inst, instClass = {}, {name}
	--append class names
	for _, superInst in ipairs(supers) do
		utils.t.append(instClass, superInst.class)
		
		local allowed = superInst.class.allowed
		local tAllowed = type(allowed) == 'table' and allowed or {allowed}
		utils.t.append(instClass.allowed or {}, tAllowed)
	end
	instClass.is = classIs
	
	--iterate over supers
	for _, superInst in ipairs(supers) do
		--raise error if not allowed
		local allowed = superInst.class.allowed
		--Possibilties: t->t	;	str->{str}	;	nil->{nil}
		local tAllowed = type(allowed) == 'table' and allowed or {allowed}
		local validChild = #tAllowed == 0;
		for _, a in ipairs(tAllowed) do
			if not validChild then
				validChild = classIs(instClass, a)
			end
		end
		assert(validChild, string.format("%s can only be subtyped by one of: %s",
				superInst.class[1], 
				table.concat(tAllowed, ", "))) 
		--appent members
		for k, v in pairs(superInst) do
			inst[k] = v
		end
	end
	
	inst.class = instClass
	--obj.class[1] == direct class
	--obj.class:is(str) == check full heirarchy
	return inst
end

------------------------------ Math ------------------------------
function utils.sign(x)
	return x == 0 and 0 or (x > 0 and 1 or -1)
end

function utils.map(x, min, max, nmin, nmax)
 return (x - min) * (nmax - nmin) / (max - min) + nmin
end

function utils.snap(grid, x, y)
	x = math.floor(x/grid) * grid
	y = y and math.floor(y/grid) * grid
	return x, y
end

function utils.dist(x1, y1, x2, y2)
	local d1 = (x1^2 + y1^2)
	return x2 and math.abs(d1 - (x2^2 + y2^2))^.5 or d1^.5
end

function utils.distSq(x1, y1, x2, y2)
	local d1 = (x1^2 + y1^2)
	return x2 and math.abs(d1 - (x2^2 + y2^2)) or d1
end

function utils.rectIntersects(x, y, w, h, ox, oy, ow, oh)
	return x < ox + ow and 
		y < oy + oh and 
		x + w > ox and
		y + h > oy
end

------------------------------ Files ------------------------------
function utils.listFiles(dir)
	local fs = love.filesystem
	local members = fs.getDirectoryItems(dir)
	
	local files = {}
	local shortNameFiles = {}
--	print("in dir: " .. dir)
	for k, member in ipairs(members) do
		local fullMember = dir .. '/' .. member
		local info = fs.getInfo(fullMember) 
		if info and info.type == 'file' and 
				member ~= ".DS_Store" then
			table.insert(files, fullMember)
			table.insert(shortNameFiles, member)
		end
	end
--	print("Finished dir.")
	return files, shortNameFiles
end

function utils.listDirItems(dir)
	local fs = love.filesystem
	local members = fs.getDirectoryItems(dir)
	
	local files = {}
	local shortNameFiles = {}
--	print("in dir: " .. dir)
	for k, member in ipairs(members) do
		local fullMember = dir .. '/' .. member
		local info = fs.getInfo(fullMember) 
		if info and member ~= ".DS_Store" then 
			table.insert(files, fullMember)
			table.insert(shortNameFiles, member)
		end
	end
--	print("Finished dir.")
	return files, shortNameFiles
end

------------------------------ Tables ------------------------------
function utils.t.contains(t, obj)
	for k, v in pairs(t) do
		if v == obj then return true end
	end
end

function utils.t.remove(t, obj)
	for k, v in pairs(t) do
		if v == obj then return table.remove(t, k) end
	end
	return nil
end

function utils.t.append(t1, t2)
	for k, v in ipairs(t2) do
		table.insert(t1, v)
	end
end

function utils.t.copy(t)
	local cpy = {}
	for k, v in pairs(t) do
		cpy[k] = v
	end
	return cpy
end

function utils.t.hardCopy(t)
	local cpy = {}
	for k, v in pairs(t) do
		if type(v) == 'table' then
			if v.clone then cpy[k] = v:clone()
			else cpy[k] = utils.t.copy(v) end
		else cpy[k] = v end
	end
	return cpy
end

------------------------------ Strings ------------------------------
function utils.str.sep(str, sep)
	sep = sep or '%s'
	local sepf = string.format("([^%s]*)(%s?)", sep, '%s')
	local t = {}
	for token, s in string.gmatch(str, sepf) do
		table.insert(t, token)
		if s == "" then return t end
	end
end

function utils.str.rem(str, token)
	return str:gsub(token .. "+", "")
end

return utils


/////////////////Exiting file: utils.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: main.lua/////////////////
--[[
local sock = require "libs.sock"

local server = sock.newServer("*", 9000)
server:on("connect", function()
	print("Client connected!")
end)
server:on("disconnect", function()
	print("Client disconnected!")
end)

function love.update()
	server:update()
end

--]]

---[[


local Slab = require "libs.Slab"

local Scheduler = require "libs.Scheduler"

local UdpApi = require "UdpApi"
local PiApi = require "PiApi"

--local dummyServer = require "DummyServer"


function love.load()
	Slab.SetINIStatePath(nil)
	Slab.Initialize()
	--dummyServer.load()
	
	local Display = require "view.Display"
	_G.Display = Display
end

local fps = 5
local lastTime = 0
function love.update(dt)
		
	Slab.Update(dt)
	
	UdpApi:update(dt)
	PiApi:update(dt)
	--dummyServer.update(dt)
	Display:update(dt)
	Scheduler:tick(dt)
end

function love.draw()
	local g2d = love.graphics
	Display:draw(g2d)
	Slab.Draw()
	--dummyServer:draw(g2d)
end

function love.keypressed(k)
	if k == 'p' then print(math.random()) end
end
--]]


/////////////////Exiting file: main.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Display.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local Fsm = require "libs.SimpleFsm.Fsm"

local LogoScene = require "view.LogoScene"
local MainScene = require "view.MainScene"

local PeripheralApi = require "PeripheralApi"

------------------------------ Constructor ------------------------------
local Display = class("Display")
function Display:initialize(w, h)
	if w and h then
		self.w = w
		self.h = h
	else
		self.w, self.h = love.window.getMode()
	end
	
	self.fonts = {
		ROBOTO_MONO_REGULAR = love.graphics.newFont("assets/roboto_mono/RobotoMono-Regular.ttf"),
	}
	
	self.fsm = Fsm()
	self.fsm:hookIntoLove()
	
	self.scenes = {
		logo_scene = LogoScene(),
		main_scene = MainScene(),
	}
	
	for k, v in pairs(self.scenes) do
		self.fsm:add(k, v)
	end
	
	self.fsm:goto("logo_scene")
end

------------------------------ API ------------------------------
function Display:update(dt)
end

function Display:draw(g2d)
	--Enable if any drawing is done outside of Slab.
	--love.graphics.setFont(self.fonts.ROBOTO_MONO_BOLD)
end

------------------------------ Getters / Setters ------------------------------

return Display()


/////////////////Exiting file: Display.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: LogoScene.lua/////////////////
local class = require "libs.middleclass"

local State = require "libs.SimpleFsm.State"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local LogoScene = class("LogoScene", State)
function LogoScene:initialize()
	self.duration = 0.3

	self.logo = love.graphics.newImage("assets/a_lab_logo.png")
end

------------------------------ Core API ------------------------------

local percentageLast
function LogoScene:update(dt)
	--TODO: Proper loading bar.
	local percentage = math.floor(self.age / self.duration * 100)
	if percentage ~= percentageLast then
		print(string.format("Loading: %%%d", percentage))
		percentageLast = percentage
	end
	
	self.age = self.age + dt
	if self.age > self.duration then
		print("Loading: %100")
		print("Finished loading!")
		self.fsm:goto("main_scene")
	end
end

function LogoScene:draw(g2d)
	g2d.draw(self.logo, 0, 0)
end

function LogoScene:enter(from, ...)
	State.enter(self, from, ...)
	self.age = 0
end

function LogoScene:leave(to)
	State.leave(self, to)
	self.age = 0
end

------------------------------ Getters / Setters ------------------------------

return LogoScene

/////////////////Exiting file: LogoScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: MainScene.lua/////////////////
local class = require "libs.middleclass"
local Slab = require "libs.Slab"
local socket = require "socket"

local State = require "libs.SimpleFsm.State"

local ConsoleStringBuilder = require "libs.ConsoleStringBuilder"
local PiApi = require "PiApi"

local AppData = require "AppData"

------------------------------ Local Constants ------------------------------
local CONSOLE_LINES = 15
local CONSOLE_CHARS_PER_LINE = 67

------------------------------ Helpers ------------------------------
--Note: This function is available as part of love's math module
--	since version 11.3,
--This is placed here since at this time, this program runs on 11.1
local function colorFromBytes(r, g, b, a)
	local nr = r / 255
	local ng = g / 255
	local nb = b / 255
	local na = a and a / 255 or nil
	return nr, ng, nb, na
end

local function getTextW(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getWidth()
end

local function getTextH(str)
	local font = love.graphics.getFont()
	local text = love.graphics.newText(font, str)
	return text:getHeight()
end

------------------------------ Constructor ------------------------------
local MainScene = class("MainScene", State)
--Note: This class is a singleton.
function MainScene:initialize()
	love.graphics.setBackgroundColor(self.BACKGROUND_COLOR)
	
	local os = love.system.getOS()
	print(os)
	local cmd
	if os == "OS X" then
		cmd = "ipconfig getifaddr en1"
	elseif os == "Linux" then
		cmd = "hostname -I"
	else
		cmd = "echo Auto-IP grab not supported for your OS."
	end
		
	local succ, handle = pcall(io.popen, cmd) 
	if succ then
		local ip = handle:read("*a"):sub(1, -2)
		self.machineIp = ip
		handle:close()
	else
		self.machineIp = "failed-to-fetch"
	end

	self:_wrapPrint()	
end

------------------------------ Workaround ------------------------------
--The below line should exist in the constructor of this class.
--It is layed out here as a workaround for a bug in L2D relating
--	to re-assigning the native "print" function.
--FIXME: Remove once the bug has been fixed.
MainScene.console = ConsoleStringBuilder(CONSOLE_LINES, CONSOLE_CHARS_PER_LINE)

do
	local prt = print
	print = function(...)
		prt(...)
		MainScene.console:print(...)
	end
end

------------------------------ Constants ------------------------------
MainScene.BACKGROUND_COLOR = {colorFromBytes(32, 31, 99)}

MainScene.SCREEN_W = 480
MainScene.SCREEN_H = 320
MainScene.LINE_H = 30
MainScene.STAT_INDENT = 130

local CONSOLE_LINES = 15
local CONSOLE_CHARS_PER_LINE = 67

------------------------------ Widget Options ------------------------------
local window = {
	id = "main",
	X = 0,
	Y = 0,
	W = MainScene.SCREEN_W,
	H = MainScene.SCREEN_H,
	AutoSizeWindow = false,
	AllowFocus = false,
	BgColor = MainScene.BACKGROUND_COLOR,
}

local _h = getTextH("foo") * CONSOLE_LINES
local consoleWindow = {
	id = "console",
	X = 0,
	Y = MainScene.SCREEN_H - _h,
	--To prevent Slab.Textf's wrapped texted from displaying a (1 pixel) scroll bar.
	W = love.graphics.getWidth() - 1,
	H = _h,
	AutoSizeWindow = false,
	BgColor = MainScene.BACKGROUND_COLOR,
}

local isConfirming
local popupQuit = {
	id = "Quitting!",
	msg = "Are you sure you want to quit?\n\n  You can start the program back up\nby launching \"Robot Controller\"\nfrom your desktop.",
	Buttons = {"Quit!", "Cancel"},
	onClick = function(result)
		if result == "Quit!" then
			PiApi:quit()
		end
		return nil
	end
}

local popupRebootRobot = {
	id = "Rebooting Robot!",
	msg = "Are you sure you want to reboot the robot?\n\n  This may take a few minutes.",
	Buttons = {"Reboot!", "Cancel"},
	onClick = function(result)
		if result == "Reboot!" then
			PiApi:reboot()
		end
		return nil
	end
}

------------------------------ Core API ------------------------------
function MainScene:update(dt)
	Slab.BeginWindow(window.id, window)
	--Monitoring - CPU
	Slab.Text("CPU: " .. PiApi:getCpuLoad())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 0)
	Slab.Text("CPU TEMP: " .. PiApi:getCpuTemp())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 0)
	Slab.Text("OPEN IP's: *")

	--Monitoring - GPU
	Slab.SetCursorPos(0, self.LINE_H * 1)
	Slab.Text("GPU: " .. PiApi:getGpuLoad())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 1)
	Slab.Text("GPU TEMP: " .. PiApi:getGpuTemp())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 1)
	Slab.Text("MACHINE IP: " .. self.machineIp)
		
	--Monitoring - Data
	Slab.SetCursorPos(0, self.LINE_H * 2)
	Slab.Text("RAM: " .. PiApi:getRamUsage())
	Slab.SetCursorPos(self.STAT_INDENT, self.LINE_H * 2)
	Slab.Text("DISK: " .. PiApi:getDiskUsage())
	Slab.SetCursorPos(self.STAT_INDENT * 2, self.LINE_H * 2)
	Slab.Text("PORT: " .. AppData.port)	
	
	--Quit
	Slab.SetCursorPos(self.SCREEN_W - 205, 80)
	if Slab.Button("Quit") then
		isConfirming = popupQuit
	end

	--Reboot
	Slab.SetCursorPos(self.SCREEN_W - 105, 80)
	if Slab.Button("Reboot") then
		isConfirming = popupRebootRobot
	end

	if isConfirming then
		local result = Slab.MessageBox(isConfirming.id, isConfirming.msg, isConfirming)
		if result ~= "" then
			isConfirming = isConfirming.onClick(result)
		end
	end
		
	Slab.EndWindow()
	
	Slab.BeginWindow(consoleWindow.id, consoleWindow)
	Slab.PushFont(Display.fonts.ROBOTO_MONO_REGULAR)
	
	Slab.Text(self.console:getContent())
	
	Slab.PopFont()	
	Slab.EndWindow()
end

------------------------------ Internals ------------------------------
function MainScene:_wrapPrint()
	--FIXME: Add this back in once the l2D fs initializing bug is fixed.
end

------------------------------ Getters / Setters ------------------------------

return MainScene

/////////////////Exiting file: MainScene.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: AppData.lua/////////////////
local AppData = {
	--Version
	MAJOR_VERSION = 1,
	MINOR_VERSION = 0,
	PATCH_VERSION = 0,
	PHASE = "beta",
	
	--Title
	PROJECT_NAME = "Robot Controller",
	
	--Directories
	ASSET_DIR = "assets/",
	
	--Networking Related
	openIp = "*",
	targetIp = "localhost",
	port = 9000,
	PING_INTERVAL = 1,
	PINGS_BEFORE_TIMEOUT = 3,
	
	--Priviliages
	CAN_REBOOT_REMOTE = false,
	CAN_REBOOT_ROBOT = false,
}

function AppData:getVersionString()
	if self.PATCH_VERSION == 0 then
		return self.MAJOR_VERSION .. "." .. self.MINOR_VERSION ..
				"-" .. self.PHASE 
	else
		return self.MAJOR_VERSION .. "." .. self.MINOR_VERSION .. 
				"." .. self.PATCH_VESRSION "-" .. self.PHASE
	end
end

return AppData

/////////////////Exiting file: AppData.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: bare_ultrasonic_test.lua/////////////////


/////////////////Exiting file: bare_ultrasonic_test.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: conf.lua/////////////////
function love.conf(t)
  -- Commented out defaults shown below.
  -- See https://www.love2d.org/wiki/Config_Files for more information.

   t.identity = "robot_tests"                    -- The name of the save directory (string)
   t.version = "11.1"                -- The L�VE version this game was made for (string)
  -- t.console = false                   -- Attach a console (boolean, Windows only)
   t.accelerometerjoystick = false      -- Enable the accelerometer on iOS and Android by exposing it as a Joystick (boolean)
  -- t.externalstorage = false           -- True to save files (and read from the save directory) in external storage on Android (boolean) 
  -- t.gammacorrect = false              -- Enable gamma-correct rendering, when supported by the system (boolean)

   t.window.title = "Robot Tests"         -- The window title (string)
  -- t.window.icon = nil                 -- Filepath to an image to use as the window's icon (string)
  -- t.window.height = 600               -- The window height (number)
  -- t.window.width = 800                -- The window width (number)
  -- t.window.borderless = false         -- Remove all border visuals from the window (boolean)
  -- t.window.resizable = false          -- Let the window be user-resizable (boolean)
  -- t.window.minwidth = 1               -- Minimum window width if the window is resizable (number)
  -- t.window.minheight = 1              -- Minimum window height if the window is resizable (number)
  -- t.window.fullscreen = false         -- Enable fullscreen (boolean)
  -- t.window.fullscreentype = "desktop" -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
  -- t.window.vsync = true               -- Enable vertical sync (boolean)
  -- t.window.msaa = 0                   -- The number of samples to use with multi-sampled antialiasing (number)
  -- t.window.display = 1                -- Index of the monitor to show the window in (number)
  -- t.window.highdpi = false            -- Enable high-dpi mode for the window on a Retina display (boolean)
  -- t.window.x = nil                    -- The x-coordinate of the window's position in the specified display (number)
  -- t.window.y = nil                    -- The y-coordinate of the window's position in the specified display (number)

   t.modules.audio = false               -- Enable the audio module (boolean)
  -- t.modules.event = true              -- Enable the event module (boolean)
   t.modules.graphics = false           -- Enable the graphics module (boolean)
   t.modules.image = false               -- Enable the image module (boolean)
   t.modules.joystick = false            -- Enable the joystick module (boolean)
  -- t.modules.keyboard = true           -- Enable the keyboard module (boolean)
  -- t.modules.math = true               -- Enable the math module (boolean)
  -- t.modules.mouse = true              -- Enable the mouse module (boolean)
   t.modules.physics = false             -- Enable the physics module (boolean)
   t.modules.sound = false               -- Enable the sound module (boolean)
  -- t.modules.system = true             -- Enable the system module (boolean)
  -- t.modules.timer = true              -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
  -- t.modules.touch = true              -- Enable the touch module (boolean)
   t.modules.video = false               -- Enable the video module (boolean)
   t.modules.window = false             -- Enable the window module (boolean)
   t.modules.thread = false              -- Enable the thread module (boolean)
end


/////////////////Exiting file: conf.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ClassTemplate.lua/////////////////
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


/////////////////Exiting file: ClassTemplate.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ConsoleStringBuilder.lua/////////////////
local class = require "libs.middleclass"
local utils = require "libs.utils"

------------------------------ Constructor ------------------------------
local ConsoleStringBuilder = class("ConsoleStringBuilder")
function ConsoleStringBuilder:initialize(lines, charsPerLine)
	self.lines = lines
	self.charsPerLine = charsPerLine
	
	self.str = ""
end

------------------------------ API ------------------------------
function ConsoleStringBuilder:print(...)
	local args = {...}
	local str = ""
	if #args == 0 then
		str = "\n"
	else
		for k, v in ipairs(args) do
			str = str .. v .. " "
		end
		str = str:sub(1, -2)	--Remove trailing space.
	end
	self:_addString(str)
end

function ConsoleStringBuilder:clear()
	self.str = ""
end

------------------------------ Internals ------------------------------
function ConsoleStringBuilder:_addString(str)
	for i = 1, #str do
		local c = str:sub(i, i)
		self.str = self.str .. c
		--print(#self.str)
		if self:getRealStrLen() % self.charsPerLine == 0 then
			--print("str mod 0")
			self.str = self.str .. "\n"
			if self:getRealStrLen() == self.lines * self.charsPerLine then
				--print("out of screen")
				self.str = self.str:sub(self.charsPerLine + 2)
			end
		end
	end
end

------------------------------ Getters / Setters ------------------------------
function ConsoleStringBuilder:getContent()
	return self.str
end

--Returns the length of the screen counting only chars that are drawable
--	onto the screen. Currently, only removes "\n", sadly.
function ConsoleStringBuilder:getRealStrLen()
	return #utils.str.rem(self.str, "\n")
end


return ConsoleStringBuilder

/////////////////Exiting file: ConsoleStringBuilder.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: FilepathUtils.lua/////////////////
local FilepathUtils = {}

FilepathUtils.love = {}
FilepathUtils.love.path = {}
FilepathUtils.love.path.src = ""
FilepathUtils.love.path.saves = nil

FilepathUtils.love.path.istatsData = FilepathUtils.love.path.src .. "/istats/data/"
FilepathUtils.love.path.istatsDefaults = FilepathUtils.love.path.src .. "/istats/defaults/"
--FilepathUtils.love.path.istatsDefaultsIdv = FilepathUtils.love.path.src .. "/istats/defaults/idv/"
--FilepathUtils.love.path.istatsDefaultsInstv = FilepathUtils.love.path.src .. "/istats/defaults/instv/"

--FilepathUtils.lua = {}
--FilepathUtils.lua.path = {}
--FilepathUtils.lua.path.src = "src"
--FilepathUtils.lua.path.saves = nil
--
--FilepathUtils.lua.path.istatsData = FilepathUtils.lua.path.src .. "/istats/data/"

return FilepathUtils

/////////////////Exiting file: FilepathUtils.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Scheduler.lua/////////////////
local class = require "libs.cruxclass"

------------------------------ Helper Methods ------------------------------
local getTime = love.timer.getTime
local ins = table.insert
local rem = table.remove
local modf = math.modf
local floor = math.floor

local function findIndex(t, obj)
	for k, v in ipairs(t) do
		if obj == v then return k end
	end
	return false
end

local function execute(t, dt, i, interval, timeout, func, args)
	args = type(args) == 'table' and args or {args}
	if dt then 
		t.tdt[i] = t.tdt[i] + dt
		local r = interval == -1 and 0 or interval
		local per = math.min(t.tdt[i] / (timeout - r), 1)
		func(dt, per, unpack(args))
	else func(unpack(args)) end
end

local function remove(t, i)
	rem(t.wait,     i)
	rem(t.interval, i)
	rem(t.timeout,  i)
	rem(t.stamp,    i)
	rem(t.tdt,      i)
	rem(t.flag,     i)
	rem(t.last,     i)
	rem(t.runs,     i)
	rem(t.func,     i)
	rem(t.args,     i)
	rem(t.wrapup,   i)
	rem(t.wargs,    i)
end

local function yield(t, i)
	if t.wrapup[i] then execute(nil, nil, nil, nil, nil, t.wrapup[i], t.wargs[i]) end
	remove(t, i)
end

local function process(t, dt, i, wait, interval, timeout, stamp, flag, last, runs, func, args)
	local time = getTime()
	
	if time >= stamp + wait then								--If (at or post 'wait'); proceed 
		if interval == 0 then									--	If 'interval' == 0; single execution
			local dt = time - stamp								--
			execute(t, dt, i, interval, timeout, func, args)	--		Execute once; 'fdt' = time since initial scheduling
			return true											--		Yield
		elseif timeout == 0 or time <= stamp + timeout then		--	If (no timeout is set) or (within timeout); proceed
			if interval == -1 then								--		If interval == -1; execute every tick
				local fdt = flag == 0 and dt or time - stamp	--			'fdt' = (first run) ? tick-dt : time since initial scheduling 
				t.flag[i] = 0									--			Set 'first run' flag
				execute(t, fdt, i, interval, timeout, func, args)--			Execute
			else												--		If 'interval' set (not 0 and not -1); execute every 'interval' for 'timeout'
				local fdt, dif, reruns							--			[1]elaborated below
				if flag == -1 then								--
					fdt = time - stamp							--
					dif = time - stamp - wait					--
				else											--
					fdt = time - last							--
					dif = time - flag							--
				end												--
																--
				reruns = floor(dif / interval)					--
				dif = dif % interval							--
				if flag == -1 then reruns = reruns + 1 end		--
																--
--				print('dt', dt, 'fdt', fdt, 'dif', dif, 'flag', flag, 'reruns', reruns, 'interval', interval)
				for _i = 1, reruns do							--
					execute(t, _i == 1 and fdt or 0, i, interval, timeout, func, args)
					t.runs[i] = t.runs[i] + 1					--
--					if i == reruns then flag = time end			--
					if _i == reruns then						-- 
						dif = 0 								--
						t.last[i] = time						--
						t.flag[i] = time - dif					--						
					end											--
				end												--
--				print('dt', dt, 'fdt', fdt, 'dif', dif, 'flag', flag, 'reruns', reruns, 'interval', interval)
			end													--
		else													-- 
			if last ~= -1 then									--
				for _ = 1, (timeout / interval) - runs do		-- 
					execute(t, 0, i, interval, timeout, func, args)
				end												--
			end													--
			return true 										--
		end														--	If timed out; yield
	end
end

--[[
Execution:
once at or post 'wait':
	if interval == 0 -> execute then remove; //dt equals time - stamp  
	elseif interval == -1
		if timeout == 0 or within timeout, execute;	//dt if first time equals time - stamp
		else remove;								//else equals tick dt
		(repeat the above 'if' once every tick)
	else;
		execute every INTERVAL for TIMEOUT ; 
		if ticks took longer than INTERVAL -> execute multiple times per tick
		[1][elaborated below]

[1]
if timed out; yield
if flag == -1
	fdt = time - stamp
	dif = time - stamp - wait
else
	fdt = time - last
	dif = time - flag
	
reruns = floor(dif / interval)
dif = dif % interval

if flag == -1 then reruns++ end

for i = 1, reruns do
	execute(i == 1 and fdt or 0)		--if multiple executions in a row, the first is passed dt the rest are passed 0
	if i + 1 == reruns then flag = time end
end
last = flag
flag = flag - dif

[2] examples !!! outdated !!!
stamp = 30
wait = 5
interval = 1
flag = -1

------------ first run [time = 35.3] //since stamp = 5.3	;	since first run 0.3
fdt = 5.3
dif = 0.3
	reruns, dif = 0++, 0.3 [0.3 / 1 ; ++]
	
flag = 35.0

------------ second run [time = 36.8] //since stamp = 6.8	;	since first run 1.8
fdt = 1.8
dif 1.8
	reruns, dif = 1, 0.8 [1.8 / 1]
	
flag = 36.0

------------ third run [time = 38.3] //since stamp = 8.3	;	since first run 3.3
fdt = 1.8
dif = 2.3
	reruns, dif = 2, 0.3 [2.3 / 1]

flag = 38.0

------------ fourth run [time = 39.8] //since stamp = 9.8	;	since first run 4.8
fdt = 1.8
dif 1.8
	reruns, dif = 1, 0.8 [1.8 / 1]
	
flag = 39.0	
--]]
------------------------------ Constructor ------------------------------
local Scheduler = class("Scheduler")
function Scheduler:init()
	self.tasks = {wait = {}, interval = {}, timeout = {}, stamp = {}, tdt = {},
			flag = {}, last = {}, runs = {}, func = {}, args = {}, wrapup = {}, wargs = {}}
		
	self.gtasks = {wait = {}, interval = {}, timeout = {}, stamp = {}, tdt = {},
			flag = {}, last = {}, runs = {}, func = {}, args = {}, wrapup = {}, wargs = {}}		
end

------------------------------ Main Methods ------------------------------
--TODO: pass graphical tasks a 'g' param in place of 'dt'.
local function processAll(t, dt)
	local yielded = {}
	for i = 1, #t.func do	--All subtables of self.tasks should always be of equal length.
		local done = process(t, dt, i, t.wait[i], t.interval[i], t.timeout[i], t.stamp[i], 
				t.flag[i], t.last[i], t.runs[i], t.func[i], t.args[i])
		if done then ins(yielded, i) end
	end
		
	for i = 1, #yielded do	--Remove yielded entries in reverse order (so indices remain consistent during yielding)
		yield(t, yielded[#yielded + 1 - i])
	end
end

function Scheduler:tick(dt)
	processAll(self.tasks, dt)
end

local gPrevTime = 0, getTime()
function Scheduler:draw(g)
	local dt = getTime() - gPrevTime
	processAll(self.gtasks, dt)
	gPrevTime = getTime()
end

------------------------------ Schedule Method ------------------------------
function Scheduler:schedule(wait, interval, timeout, stamp, func, args, wrapup, wargs, graphical)
	local t = graphical and self.gtasks or self.tasks
	ins(t.wait,     wait     or 0)
	ins(t.interval, interval or 0)
	ins(t.timeout,  timeout  or 0)
	ins(t.stamp,    stamp    or getTime())
	ins(t.tdt,       0)
	ins(t.flag,     -1)
	ins(t.last,     -1)
	ins(t.runs,      0)
	ins(t.func,     func)
	ins(t.args,     args     or {})
	ins(t.wrapup,   wrapup)
	ins(t.wargs,    wargs    or {})
end

------------------------------ Schedule Shortcuts ------------------------------
function Scheduler:callAfter(wait, func, args, wrapup, wargs)
	self:schedule(wait, nil, nil, nil, func, args, wrapup, wargs)
end

function Scheduler:callFor(timeout, func, args, wrapup, wargs)
	self:schedule(nil, -1, timeout, nil, func, args, wrapup, wargs)
end

function Scheduler:callEvery(interval, func, args, wrapup, wargs)
	self:schedule(nil, interval, nil, nil, func, args, wrapup, wargs)
end

function Scheduler:callEveryFor(interval, timeout, func, args, wrapup, wargs)
	self:schedule(nil, interval, timeout, nil, func, args, wrapup, wargs)
end

------------------------------ Schedule Graphical Shortcuts ------------------------------
function Scheduler:gCallAfter(wait, func, args, wrapup, wargs)
	self:schedule(wait, nil, nil, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallFor(timeout, func, args, wrapup, wargs)
	self:schedule(nil, -1, timeout, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallEvery(interval, func, args, wrapup, wargs)
	self:schedule(nil, interval, nil, nil, func, args, wrapup, wargs, true)
end

function Scheduler:gCallEveryFor(interval, timeout, func, args, wrapup, wargs)
	self:schedule(nil, interval, timeout, nil, func, args, wrapup, wargs, true)
end
------------------------------ Cancel Methods ------------------------------
function Scheduler:cancel(func)
	local i = type(func) == 'number' and func or findIndex(self.tasks.func, func)
	if i then remove(self.tasks, i) end
	--Graphical tasks:
	i = type(func) == 'number' and func or findIndex(self.gtasks.func, func)
	if i then remove(self.gtasks, i) end
end

function Scheduler:cancelAll()
	for i = 1, self.tasks.func do
		remove(self.tasks, i)
	end
	--Graphical tasks:
	for i = 1, self.gtasks.func do
		remove(self.gtasks, i)
	end
end
------------------------------ Yield Methods ------------------------------
function Scheduler:yield(func)
	local i = type(func) == 'number' and func or findIndex(self.tasks.func, func)
	if i then yield(self.tasks, i) end
	--Graphical tasks:
	i = type(func) == 'number' and func or findIndex(self.gtasks.func, func)
	if i then yield(self.gtasks, i) end
end

function Scheduler:yieldAll()
	for i = 1, self.tasks.func do
		yield(self.tasks, i)
	end
	--Graphical tasks:
	for i = 1, self.gtasks.func do
		yield(self.gtasks, i)
	end
end

return Scheduler()


/////////////////Exiting file: Scheduler.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: Fsm.lua/////////////////
--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"
local State = require "libs.SimpleFsm.State"

------------------------------ Nil State ------------------------------
local NilState = class("NilState", State)

------------------------------ Constructor ------------------------------
local Fsm = class("Fsm")
function Fsm:initialize()
	local ns = NilState()
	self.states = {["nil"] = ns}
	self.curState = ns
end

------------------------------ Core API ------------------------------

--[[
Callbacks only have to be defined by the FSM for ones that wish to override the default hookIntoLove behavior.
Which is: 
	if self.curState and self.curState[callbackName] then 
		self.curState[callbackName](pass-all-default-love-params-for-callback)
--]]
function Fsm:draw()
	if not self.curState.draw then return end
	
	local g2d = love.graphics
	self.curState:draw(g2d)
end

function Fsm:at(id)
	if id then
		return self.states[id] == self.curState
	else
		for k, v in pairs(self.states) do
			if self.curState == v then return k end
		end
	end
end

function Fsm:goto(id, ...)
	local state = self.states[id]
	if not state then return false end
	if self.curState == state then return false end
	
	self.curState:leave(state)
	local previous = self.curState
	self.curState = state
	self.curState:enter(previous, ...)
	return true
end

function Fsm:add(id, state)
	if self.states[id] then return false end
	
	self.states[id] = state
	state:activate(self)
	return true
end

function Fsm:remove(id)
	local state = self.states[id]
	if not state then return false end
	
	if self.curState == state then self.curState = nil end

	state:destroy()
	self.states[id] = nil
	return true
end

------------------------------ Love Hook ------------------------------
local function hookLoveCallback(Fsm, loveStr, fsmStr)
	fsmStr = fsmStr or loveStr
	local preF = love[loveStr]
	
	love[loveStr] = function(...)
		if preF then preF(...) end
		
		if Fsm[fsmStr] then 
			Fsm[fsmStr](Fsm, ...)
		elseif Fsm.curState[fsmStr] then 
			Fsm.curState[fsmStr](Fsm.curState, ...)
		end
	end
end

function Fsm:hookIntoLove()
	hookLoveCallback(self, "update")
	hookLoveCallback(self, "draw")
	hookLoveCallback(self, "keypressed", "keyPressed")
	hookLoveCallback(self, "keyReleased", "keyReleased")
	hookLoveCallback(self, "mousemoved", "mouseMoved")
	hookLoveCallback(self, "mousePressed", "mousePressed")
	hookLoveCallback(self, "textinput", "textInput")
	hookLoveCallback(self, "wheelMoved", "wheelMoved")
	--TODO: Implement the rest.
end

------------------------------ Getters / Setters ------------------------------
function Fsm:getStates()
	return self.states
end

function Fsm:getCurrentState()
	return self.curState
end

return Fsm

--[[

state
current state
transitionTo

--]]


/////////////////Exiting file: Fsm.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: State.lua/////////////////
--As of writing this (2022-03-04) this is the latest/best version of this Fsm.

local class = require "libs.middleclass"

------------------------------ Helper Methods ------------------------------

------------------------------ Constructor ------------------------------
local State = class("State")
function State:initialize()
end

------------------------------ Core API ------------------------------
function State:update(dt)
end

function State:draw(g2d)
end

function State:enter(from, ...)
	print("Entered: " .. self.fsm:at())
end

function State:leave(to)
	--FIXME: fsm is nil.
	--print("Left: " .. self.fsm:at())
end

function State:activate(fsm)
	self.fsm = fsm
end

function State:destroy()
end

------------------------------ Getters / Setters ------------------------------

return State

--[[

activate
destroy
enter
leave
update
draw

--]]


/////////////////Exiting file: State.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: main.lua/////////////////
local Fsm = require "libs.SimpleFsm.Fsm"
local State = require "libs.SimpleFsm.State"

--Test
local state1 = State()
state1.update = function(dt) print("state1 update!") end
state1.enter = function(fsm, from, ...) print("entered state1 with vars: ", ...) end
state1.leave = function(fsm, to, ...) print("left state1") end

local state2 = State()
state2.update = function(dt) print("state2 update!") end
state2.enter = function(fsm, from, ...) print("entered state2 with vars: ", ...) end
state2.leave = function(fsm, to, ...) print("left state2") end

local fsm = Fsm()
fsm:add(state1)
fsm:add(state2)

function love.load(args)
	fsm:hookIntoLove()
	fsm:goto(state1)
	fsm:goto(state1)	--Does nothing.
	fsm:goto(state2)
	fsm:goto(state1, "Hello", "World!", 42)
end

function love.update(dt)
	print("Original update!")
end

function love.draw()
	local g2d = love.graphics
	print("Original draw!")
end

/////////////////Exiting file: main.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: cruxclass.lua/////////////////
local middleclass = {
  _VERSION = [[
  	- middleclass  v4.1.1 
  	- MixinEdit    v1.0.0 
  	- NamingRevamp v1.0.0
  ]],
  
  _DESCRIPTION = [[
	  - Middleclass:  Object Orientation for Lua.
	  - MixinEdit:    Updates isInstanceOf and isSubclassOf to handle mixins.
	  - NamingRevamp: Revamps middleclass's naming conventions to be more uniform.
  ]],
  
  _URL = [[
  	middleclass:  https://github.com/kikito/middleclass
  	MixinEdit:    https://github.com/ActivexDiamond/cruxclass
  	NamingRevamp: https://github.com/ActivexDiamond/cruxclass
  ]],
  
  _LICENSE = [[
    MIT LICENSE
    Copyright (c) 2011 Enrique GarcÃ­a Cota
    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  ]],
  
  _MIXIN_EDIT_CHANGES = [[
	  Mixin Additions:
	  	Mixins can also hold fields, not only methods.
	    Added array "mixins" to all classes.
	  	"include" updates "mixins" field with references
	  		towards the newly included mixins.
	  	
	  	"isInstanceOf" checks list of mixins, plus usual operation.
	  	"isSubclassOf" checks list of mixins, plus usual operation.
  ]],
  
  _NAMING_REVAMP_CHANGES = [[	
	  Naming Conventions Changes:
	  	+ New Conventions:
	  		identifier = keywords, fundamental methods.
	  		__identifier = lua metamethods, middleclass metamethods.
			__identifier__ = middleclass internal methods/data.  		
	  	
	  	Fundemental Methods:
		  	"initialise" renamed to "init".
		  	"isInstanceOf" renamed to "instanceof".
		  	"isSubclassOf" renamed to "subclassof".
	  	
	  	Middleclass Metamethods:
		  	"allocate" renamed to "__allocate".
		  	"new" renamed to "__new".
		  	"subclassed" renamed to "__subclassed".
		  	"included" renamed to "__included".
	  	
	  	Middleclass Internal Data:
	  		"name" renamed to "__name__".
	  		"subclasses" renamed to "__subclasses__".
	  		"__mixins__" renamed to "__mixins__".
	  		
	  	Middleclass Internal Methods:
		  	"__instanceDict" renamed to "__instanceDict__".
		  	"__declaredMethods__" renamed to "__declaredMethods__".
  ]],
  
  NAMING_REVAMP_PROPOSED_CONVENTIONS = [[
	Fields: 
		private: Enforced, possible getter/setter.
		protected: Technically public, 
			but mutable fields are never accessed directly.
		public: All caps,
			Only final fields are accessed directly.
	
	Methods:
		private: Enforced.
		protected: Technically public,
			prefixed with a single underscore.
		public: "Enforced".
	
	Examples:
		local x = 666			-- private
		self.x = 42				-- protected
		self.PIE = 3.14			-- public
		
		local function getX()	-- private
		self:_getX()			-- protected
		self:getX()				-- public
		
	Note: "Technically public", as in it CAN be accessed publicly,
	 	security wise, but should never be, following convention.
  ]] 
}

local function _createIndexWrapper(aClass, f)
  if f == nil then
    return aClass.__instanceDict__
  else
    return function(self, __name__)
      local value = aClass.__instanceDict__[__name__]

      if value ~= nil then
        return value
      elseif type(f) == "function" then
        return (f(self, __name__))
      else
        return f[__name__]
      end
    end
  end
end

local function _propagateInstanceMethod(aClass, __name__, f)
  f = __name__ == "__index" and _createIndexWrapper(aClass, f) or f
  aClass.__instanceDict__[__name__] = f

  for subclass in pairs(aClass.__subclasses__) do
    if rawget(subclass.__declaredMethods__, __name__) == nil then
      _propagateInstanceMethod(subclass, __name__, f)
    end
  end
end

local function _declareInstanceMethod(aClass, __name__, f)
  aClass.__declaredMethods__[__name__] = f

  if f == nil and aClass.super then
    f = aClass.super.__instanceDict__[__name__]
  end

  _propagateInstanceMethod(aClass, __name__, f)
end

local function _tostring(self) return "class " .. self.__name__ end
local function _call(self, ...) return self:__new(...) end

local function _createClass(__name__, super)
  local dict = {}
  dict.__index = dict

  local aClass = { __name__ = __name__, super = super, static = {},
                   __instanceDict__ = dict, __declaredMethods__ = {},
                   __subclasses__ = setmetatable({}, {__mode='k'}),
                   __mixins__ = {}  }

  if super then
    setmetatable(aClass.static, {
      __index = function(_,k)
        local result = rawget(dict,k)
        if result == nil then
          return super.static[k]
        end
        return result
      end
    })
  else
    setmetatable(aClass.static, { __index = function(_,k) return rawget(dict,k) end })
  end

  setmetatable(aClass, { __index = aClass.static, __tostring = _tostring,
                         __call = _call, __newindex = _declareInstanceMethod })

  return aClass
end

local function _tableContains(t, o) 	----------
	for _, v in ipairs(t or {}) do		----------
		if v == o then return true end  ----------
	end									----------
	return false						----------
end

local function _includeMixin(aClass, mixin)
  assert(type(mixin) == 'table', "mixin must be a table")

  -- If including the DefaultMixin, then class.__mixins__
  -- will at that point still be nil.
  -- DefaultMixin is not __included in class.__mixins__
  if aClass.__mixins__ then table.insert(aClass.__mixins__, mixin) end	--------------
    
  for name,method in pairs(mixin) do
    if name ~= "__included" and name ~= "static" then aClass[name] = method end
  end

  for name,method in pairs(mixin.static or {}) do
    aClass.static[name] = method
  end

  if type(mixin.__included)=="function" then mixin:__included(aClass) end
  return aClass
end

local DefaultMixin = {
  __tostring   = function(self) return "instance of " .. tostring(self.class) end,

  init   = function(self, ...) end,

  instanceof = function(self, aClass)
    return type(aClass) == 'table'
       and type(self) == 'table'
       and (self.class == aClass	
            or type(self.class) == 'table'
            and (_tableContains(self.class.__mixins__, aClass) ----------
	            or type(self.class.subclassof) == 'function'
	            and self.class:subclassof(aClass)))
  end,

  static = {
--  	__mixins__ = setmetatable({}, {__mode = 'k'})
    __mixins__ = {}, -------------------
    
    __allocate = function(self)
      assert(type(self) == 'table', "Make sure that you are using 'Class:__allocate' instead of 'Class.__allocate'")
      return setmetatable({ class = self }, self.__instanceDict__)
    end,

    __new = function(self, ...)
      assert(type(self) == 'table', "Make sure that you are using 'Class:__new' instead of 'Class.__new'")
      local instance = self:__allocate()
      instance:init(...)
      return instance
    end,

    subclass = function(self, __name__)
      assert(type(self) == 'table', "Make sure that you are using 'Class:subclass' instead of 'Class.subclass'")
      assert(type(__name__) == "string", "You must provide a __name__(string) for your class")

      local subclass = _createClass(__name__, self)

      for methodName, f in pairs(self.__instanceDict__) do
        _propagateInstanceMethod(subclass, methodName, f)
      end
      subclass.init = function(instance, ...) return self.init(instance, ...) end

      self.__subclasses__[subclass] = true
      self:__subclassed(subclass)

      return subclass
    end,

    __subclassed = function(self, other) end,

    subclassof = function(self, other)
	  return type(self) == 'table' and
	  	 	 type(other) == 'table' and
		  	 	(_tableContains(self.__mixins__, other) or
		  	 	type(self.super) == 'table' and
	  	 		(self.super == other or
	  	 		self.super:subclassof(other)))
    end,

    include = function(self, ...)
      assert(type(self) == 'table', "Make sure you that you are using 'Class:include' instead of 'Class.include'")
      for _,mixin in ipairs({...}) do _includeMixin(self, mixin) end
      return self
    end    
  }
}

function middleclass.class(__name__, super)
  assert(type(__name__) == 'string', "A __name__ (string) is needed for the __new class")
  return super and super:subclass(__name__) or _includeMixin(_createClass(__name__), DefaultMixin)
end

setmetatable(middleclass, { __call = function(_, ...) return middleclass.class(...) end })

return middleclass

--[[
Old -> New
  __tostring
  initialise		->	init
  isInstanceOf  	->	instanceof
  
  class	
  
  static {
  	allocate		->	__allocate
  	new				->	__new
  	subclass
  	subclassed		->	__subclassed
  	isSubclassOf	->	subclassof
  	include
  	
  	[mixin]included ->	__included
  					[+]	__mixins__
  	
  	name			->	__name__
  	super	
  	__instanceDict	->	__instanceDict__
  	__declaredMethods>	__declaredMethods__
  	subclasses		-	 __subclasses__
  	
----------------------------------------

  	mthd = keywords: super, class, static
  					 instanceof, subclassof
			 fundementals: init, subclass, include
		
	__mthd =  metamethods: __tostring,
			  middleclass_metamethods: __allocate,
			  	__new, __subclassed, __included
			  		
		
	__mthd__ = middleclass_internal_methods: __instanceDict__,
					__declaredMethods__
			    middleclass_internal_data: __name__,
			    	__subclasses__, __mixins__		
			 
--]]

--[[
Fields: 
	private: Enforced, possible getter/setter.
	protected: Technically public, 
		but fields are never accessed directly.
	public: Fields are never public.

Methods:
	private: Enforced.
	protected: Technically public,
		prefixed with a single underscore.
	public: "Enforced".

Examples:
	local x = 3.14			-- private
	self.x = 42				-- protected
	
	local function getX()	-- private
	self:_getX()			-- protected
	self:getX()				-- public
--]]

/////////////////Exiting file: cruxclass.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: utils.lua/////////////////
local utils = {}
utils.t = {}
utils.str = {}

------------------------------ Misc. ------------------------------
function utils.class(name, ...)
	local function classIs(class, otherClass)
		for k, v in ipairs(class) do
			if v == otherClass then return true end
		end
		return false
	end
	local supers = {...}
	local inst, instClass = {}, {name}
	--append class names
	for _, superInst in ipairs(supers) do
		utils.t.append(instClass, superInst.class)
		
		local allowed = superInst.class.allowed
		local tAllowed = type(allowed) == 'table' and allowed or {allowed}
		utils.t.append(instClass.allowed or {}, tAllowed)
	end
	instClass.is = classIs
	
	--iterate over supers
	for _, superInst in ipairs(supers) do
		--raise error if not allowed
		local allowed = superInst.class.allowed
		--Possibilties: t->t	;	str->{str}	;	nil->{nil}
		local tAllowed = type(allowed) == 'table' and allowed or {allowed}
		local validChild = #tAllowed == 0;
		for _, a in ipairs(tAllowed) do
			if not validChild then
				validChild = classIs(instClass, a)
			end
		end
		assert(validChild, string.format("%s can only be subtyped by one of: %s",
				superInst.class[1], 
				table.concat(tAllowed, ", "))) 
		--appent members
		for k, v in pairs(superInst) do
			inst[k] = v
		end
	end
	
	inst.class = instClass
	--obj.class[1] == direct class
	--obj.class:is(str) == check full heirarchy
	return inst
end

------------------------------ Math ------------------------------
function utils.sign(x)
	return x == 0 and 0 or (x > 0 and 1 or -1)
end

function utils.map(x, min, max, nmin, nmax)
 return (x - min) * (nmax - nmin) / (max - min) + nmin
end

function utils.snap(grid, x, y)
	x = math.floor(x/grid) * grid
	y = y and math.floor(y/grid) * grid
	return x, y
end

function utils.dist(x1, y1, x2, y2)
	local d1 = (x1^2 + y1^2)
	return x2 and math.abs(d1 - (x2^2 + y2^2))^.5 or d1^.5
end

function utils.distSq(x1, y1, x2, y2)
	local d1 = (x1^2 + y1^2)
	return x2 and math.abs(d1 - (x2^2 + y2^2)) or d1
end

function utils.rectIntersects(x, y, w, h, ox, oy, ow, oh)
	return x < ox + ow and 
		y < oy + oh and 
		x + w > ox and
		y + h > oy
end

------------------------------ Files ------------------------------
function utils.listFiles(dir)
	local fs = love.filesystem
	local members = fs.getDirectoryItems(dir)
	
	local files = {}
	local shortNameFiles = {}
--	print("in dir: " .. dir)
	for k, member in ipairs(members) do
		local fullMember = dir .. '/' .. member
		local info = fs.getInfo(fullMember) 
		if info and info.type == 'file' and 
				member ~= ".DS_Store" then
			table.insert(files, fullMember)
			table.insert(shortNameFiles, member)
		end
	end
--	print("Finished dir.")
	return files, shortNameFiles
end

function utils.listDirItems(dir)
	local fs = love.filesystem
	local members = fs.getDirectoryItems(dir)
	
	local files = {}
	local shortNameFiles = {}
--	print("in dir: " .. dir)
	for k, member in ipairs(members) do
		local fullMember = dir .. '/' .. member
		local info = fs.getInfo(fullMember) 
		if info and member ~= ".DS_Store" then 
			table.insert(files, fullMember)
			table.insert(shortNameFiles, member)
		end
	end
--	print("Finished dir.")
	return files, shortNameFiles
end

------------------------------ Tables ------------------------------
function utils.t.contains(t, obj)
	for k, v in pairs(t) do
		if v == obj then return true end
	end
end

function utils.t.remove(t, obj)
	for k, v in pairs(t) do
		if v == obj then return table.remove(t, k) end
	end
	return nil
end

function utils.t.append(t1, t2)
	for k, v in ipairs(t2) do
		table.insert(t1, v)
	end
end

function utils.t.copy(t)
	local cpy = {}
	for k, v in pairs(t) do
		cpy[k] = v
	end
	return cpy
end

function utils.t.hardCopy(t)
	local cpy = {}
	for k, v in pairs(t) do
		if type(v) == 'table' then
			if v.clone then cpy[k] = v:clone()
			else cpy[k] = utils.t.copy(v) end
		else cpy[k] = v end
	end
	return cpy
end

------------------------------ Strings ------------------------------
function utils.str.sep(str, sep)
	sep = sep or '%s'
	local sepf = string.format("([^%s]*)(%s?)", sep, '%s')
	local t = {}
	for token, s in string.gmatch(str, sepf) do
		table.insert(t, token)
		if s == "" then return t end
	end
end

function utils.str.rem(str, token)
	return str:gsub(token .. "+", "")
end

return utils


/////////////////Exiting file: utils.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: main.lua/////////////////
--require "ultrasonic_test"
--require "serial_test"
require "py_socket_test"

/////////////////Exiting file: main.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: py_socket_test.lua/////////////////
local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end



local socket = require "socket"
local json = require "libs.json"

local IP = "192.168.0.113"
local PORT = 9004

print("Client running.")
local client = socket.udp()
client:settimeout(0)
print("Setting peer name.")
client:setpeername(IP, PORT)
client:send("ping")

print("Entering listening loop.")
function love.update(dt) 
	local data, err
	repeat
		data, err = client:receive()
		if data then
			local t = json.decode(data)
			local vals = json.decode(t)
			print(dump(vals))
			--for k, v in pairs(type(vals) == 'table' and vals or {}) do
			--	if 
			--	print(k, v)
			--end
		else
			print("Got error from recieve: " .. err)
		end
	until not data
	love.timer.sleep(2)
	print("Pinging server.")
	client:send("ping")
end

--[[
local sock = require "libs.sock"

-- client.lua
local client
function love.load()
    -- Creating a new client on localhost:22122
    client = sock.newClient("192.168.0.113", 9004)
    
    -- Called when a connection is made to the server
    client:on("connect", function(data)
        print("Client connected to the server.")
    end)
    
    -- Called when the client disconnects from the server
    client:on("disconnect", function(data)
        print("Client disconnected from the server.")
    end)

    -- Custom callback, called whenever you send the event from the server
    client:on("hello", function(msg)
        print("The server replied: " .. msg)
    end)

    client:connect()
    
    --  You can send different types of data
    client:send("greeting", "Hello, my name is Inigo Montoya.")
    client:send("isShooting", true)
    client:send("bulletsLeft", 1)
    client:send("position", {
        x = 465.3,
        y = 50,
    })
end

function love.update(dt)
    client:update()
end

--]]

/////////////////Exiting file: py_socket_test.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: serial_test.lua/////////////////
local Serial = require('periphery').Serial

-- Open /dev/ttyUSB0 with baudrate 115200, and defaults of 8N1, no flow control
local serial = Serial("/dev/ttyUSB0", 9600)

serial:write("Hello World!")

-- Read up to 128 bytes with 500ms timeout
local buf = serial:read(128, 500)
print(string.format("read %d bytes: _%s_", #buf, buf))

serial:close()

/////////////////Exiting file: serial_test.lua/////////////////
//--------------------------------------------------------------------------------------------------------
/////////////////Entering file: ultrasonic_test.lua/////////////////
--Guard-clause for when running on a dev-machine, not an actual Pi,
--Periphery will not be installed and all calls to it's API will be
--	forwarded to blank versions.
--This facilitates development on non-Pi machines. 
local Serial, Gpio
do
	local succ, msg = pcall(require, "periphery")
	if succ then
		Serial = require("periphery").Serial
		Gpio = require("periphery").GPIO
	else
		Serial = require("dummyPeriphery").Serial
		Gpio = require("dummyPeriphery").GPIO
	end
end

------------------------------ Helpers ------------------------------
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

local function microsecondSleep(ms)
	love.timer.sleep(ms / 1e6)
end

local function readPulseLength(pin)
	local timeoutTimer = TimeoutTimer(3)
	local failed = false
	
	local startTime = 0 
	local endTime = 0
	local getTime = love.timer.getTime		--Localize to optimize call.
	--Read the length of the pulse from when the pin goes high,
	--	till when it comes back low.
	while not pin:read() do
		if timeoutTimer:shouldAbort() then
			failed = true
			break 
		end
		startTime = getTime()
	end
	timeoutTimer:reset()
	while pin:read() do
		if timeoutTimer:shouldAbort() or failed then 
			failed = true
			break 
		end
		endTime = getTime()
	end
	return failed and -1 or endTime - startTime
end


------------------------------ Ultrasonic Test ------------------------------
--Config
local fps = 5

--Pins

local trig = Gpio(16, 'out')
local echo = Gpio(18, 'in')

--local trig = Gpio(35, 'out')
--local echo = Gpio(37, 'in')

--local trig = Gpio("GPIO.24", 'out')
--local echo = Gpio("GPIO.25", 'in')

--API
local function readUltrasonic()
	--Clear out the trigger pin, giving it 2ms to do so.
	trig:write(false)
	love.timer.sleep(2)
	--Send a 10ms long pulse to the trgger pin.
	trig:write(true)
	love.timer.sleep(0.00001) 
	trig:write(false)
	
	--Read the length of the response pulse.
	local len = readPulseLength(echo)
	--Speed of sound in air, in centimeters, divided be 2, as the wave must travel to and fro.
	
	--local dist = len * 0.034 / 2
	local dist = len * 17150
	--distance = round(pulse_duration * 17150, 2) 
	
	local str = string.format("Distance to ultrasonic is %fcm.", dist)
	print(str)
	--TODO: Test this out on real hardware and confirm the results.
end

--State
local lastTime = 0

------------------------------ Core API ------------------------------
function love.load()
	print("Began running Climbing Robot hardware configuration tests (manual).")
end

function love.update(dt)
	if love.timer.getTime() - lastTime > 1/fps then
		print("Attempting to read ultrasonic.")
		readUltrasonic()
		lastTime = love.timer.getTime()
	end
end



/////////////////Exiting file: ultrasonic_test.lua/////////////////
//--------------------------------------------------------------------------------------------------------