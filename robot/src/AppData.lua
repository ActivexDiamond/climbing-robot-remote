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
	
	--client_ip = "localhost",
	server_ip = "localhost",
	port = "9000",
	
	--Priviliages
	CAN_REBOOT = false,
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