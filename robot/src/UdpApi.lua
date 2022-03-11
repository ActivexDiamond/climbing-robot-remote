local class = require "libs.middleclass"
local sock = require "libs.sock"

local PiApi = require "PiAPi"
local AppData = require "AppData"


------------------------------ Heleprs ------------------------------
local function peerToString(peer)
	return string.format("{%s}", table.concat(peer, ", "))
end

------------------------------ Constructor ------------------------------
local UdpApi = class("UdpApi")
--Note: This class is a singleton.
function UdpApi:initialize()
	self:_initServer()
end

------------------------------ Internals ------------------------------
function UdpApi:_initServer()
	self.openIp = AppData.openIp
	self.port = AppData.port
	self.server = sock.newServer(self.openIp, self.port)
	self:_injectEvents()
end

------------------------------ Core API ------------------------------
function UdpApi:update(dt)
	self.server:update(dt)
end

------------------------------ API ------------------------------
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
	PiApi:cutterWormSet(angle)
end

function UdpApi.events:c_wheel_set(angle)
	PiApi:cutterWheelSet(angle)
end

--Sensors
function UdpApi.events:sensor_ultrasonic_left()
	PiApi:readLeftUltrasonic()
end

function UdpApi.events:sensor_ultrasonic_right()
	PiApi:readRightUltrasonic()
end

function UdpApi.events:sensor_gyroscope_is_fallen()
	PiApi:isFallen()
end

return UdpApi()

