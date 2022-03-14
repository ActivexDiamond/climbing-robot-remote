local socket = require "socket"

local IP = "192.168.0.113"
local PORT = 9004

print("Client running.")
local client = socket.udp()
client:settimeout(0)
print("Setting peer name.")
client:setpeername(IP, PORT)

print("Entering listening loop.")
function love.update(dt) 
	local data, msg
	repeat
		data, msg = client:receive()
		if data then
			print("data: " .. data)
		end
		if msg then
			print("msg: " .. msg)
		end
	until not data
	love.timer.sleep(2)
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