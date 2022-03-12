local m = {}

function m.Serial(port, baudrate)
	local self = {}
	self.port = port
	self.baudrate = baudrate
	
	function self:write(str)
		print("[dummyPeriphery/serial:write]: " .. str)
	end
	
	return self
end

function m.GPIO(pin, dir)
	local self = {}
	self.pin = pin
	self.dir = dir
	
	function self:write(state)
		local str = string.format("[dummyPeriphery/%s:write: ] %s",
				self.pin, state)
		print(str)
	end
	
	function self:read()
		local str = string.format("[dummyPeriphery/%s:read: ] hardcoded-true",
				self.pin)
		print(str)
		return true
	end
	return self
end

return m