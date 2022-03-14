do
  local bytemarkers = { {0x7FF,192}, {0xFFFF,224}, {0x1FFFFF,240} }
  function utf8(decimal)
    if decimal<128 then return string.char(decimal) end
    local charbytes = {}
    for bytes,vals in ipairs(bytemarkers) do
      if decimal<=vals[1] then
        for b=bytes+1,2,-1 do
          local mod = decimal%64
          decimal = (decimal-mod)/64
          charbytes[b] = string.char(128+mod)
        end
        charbytes[1] = string.char(vals[2]+decimal)
        break
      end
    end
    return table.concat(charbytes)
  end
end

local function utf8frompoints(...)
  local chars,arg={},{...}
  for i,n in ipairs(arg) do chars[i]=utf8(arg[i]) end
  return table.concat(chars)
end

print(utf8frompoints(72, 233, 108, 108, 246, 32, 8364, 8212))


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
			print("Got data! " .. data)
			print()
			print()
			print()
			print("t: " .. t)
			for k, v in pairs(type(t) == 'table' and t or {}) do
				print(k, v)
			end
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