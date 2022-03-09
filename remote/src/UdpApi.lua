local class = require "libs.middleclass"
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
	self.ip = AppData.server_ip
	self.port = AppData.port
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