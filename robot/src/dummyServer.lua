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
server:on("sensor_gyro_is_fallen", function(angle)
	print(CMDS.sensor_gyro_is_fallen.code, angle)
end)




return {load = load, update = update}