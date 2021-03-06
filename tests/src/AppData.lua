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