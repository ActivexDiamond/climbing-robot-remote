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