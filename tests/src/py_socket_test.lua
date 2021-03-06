local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end



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
			local vals = json.decode(t)
			print(dump(vals))
			--for k, v in pairs(type(vals) == 'table' and vals or {}) do
			--	if 
			--	print(k, v)
			--end
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