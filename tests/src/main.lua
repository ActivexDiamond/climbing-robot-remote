--Guard-clause for when running on a dev-machine, not an actual Pi,
--Periphery will not be installed and all calls to it's API will be
--	forwarded to blank versions.
--This facilitates development on non-Pi machines. 
local Serial, Gpio
do
	local succ, msg = pcall(require, "periphery")
	if succ then
		Serial = require("periphery").Serial
		Gpio = require("periphery").GPIO
	else
		Serial = require("dummyPeriphery").Serial
		Gpio = require("dummyPeriphery").GPIO
	end
end

------------------------------ Helpers ------------------------------
local function microsecondSleep(ms)
	love.timer.sleep(ms / 1e6)
end

local function readPulseLength(pin)
	local startTime, endTime
	local getTime = love.timer.getTime		--Localize to optimize call.
	--Read the length of the pulse from when the pin goes high,
	--	till when it comes back low.
	while not pin:read() do
		startTime = getTime()
	end
	while pin:read() do
		endTime = getTime()
	end
	return endTime - startTime
end


------------------------------ Ultrasonic Test ------------------------------
--Config
local fps = 5

--Pins
local trig = Gpio(35, 'out')
local echo = Gpio(37, 'in')

--local trig = Gpio("GPIO.24", 'out')
--local echo = Gpio("GPIO.25", 'in')

--API
local function readUltrasonic()
	--Clear out the trigger pin, giving it 2ms to do so.
	trig:write(false)
	microsecondSleep(2)
	--Send a 10ms long pulse to the trgger pin.
	trig:write(true)
	microsecondSleep(10)
	trig:write(false)
	
	--Read the length of the response pulse.
	local len = readPulseLength(echo)
	--Speed of sound in air, in centimeters, divided be 2, as the wave must travel to and fro.
	local dist = len * 0.034 / 2
	local str = string.format("Distance to ultrasonic is %fcm.", dist)
	print(str)
	--TODO: Test this out on real hardware and confirm the results.
end

--State
local lastTime = 0

------------------------------ Core API ------------------------------
function love.update(dt)
	if love.timer.getTime() - lastTime > 1000/fps then
		readUltrasonic()
		lastTime = love.timer.getTime()
	end
end

