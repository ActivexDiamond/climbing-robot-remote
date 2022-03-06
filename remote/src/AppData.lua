local AppData = {
	MAJOR_VERSION = 1,
	MINOR_VERSION = 0,
	PATCH_VERSION = 0,
	PHASE = "beta",
	
	PROJECT_NAME = "Robot Controller"
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