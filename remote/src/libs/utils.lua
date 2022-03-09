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
