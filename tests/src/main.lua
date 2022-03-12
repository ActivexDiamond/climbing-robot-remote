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
local function TimeoutTimer(timeout)
	return {
		timeout = timeout,
		startTime = love.timer.getTime(),
		
		shouldAbort = function(self)
			return love.timer.getTime() - self.startTime > self.timeout
		end,
		reset = function(self)
			self.startTime = love.timer.getTime()
		end,
	}
end

local function microsecondSleep(ms)
	love.timer.sleep(ms / 1e6)
end

local function readPulseLength(pin)
	local timeoutTimer = TimeoutTimer(3)
	local failed = false
	
	local startTime = 0 
	local endTime = 0
	local getTime = love.timer.getTime		--Localize to optimize call.
	--Read the length of the pulse from when the pin goes high,
	--	till when it comes back low.
	while not pin:read() do
		if timeoutTimer:shouldAbort() then
			failed = true
			break 
		end
		startTime = getTime()
	end
	timeoutTimer:reset()
	while pin:read() do
		if timeoutTimer:shouldAbort() or failed then 
			failed = true
			break 
		end
		endTime = getTime()
	end
	return failed and -1 or endTime - startTime
end


------------------------------ Ultrasonic Test ------------------------------
--Config
local fps = 5

--Pins

local trig = Gpio(16, 'out')
local echo = Gpio(18, 'in')

--local trig = Gpio(35, 'out')
--local echo = Gpio(37, 'in')

--local trig = Gpio("GPIO.24", 'out')
--local echo = Gpio("GPIO.25", 'in')

--API
local function readUltrasonic()
	--Clear out the trigger pin, giving it 2ms to do so.
	trig:write(false)
	love.timer.sleep(2)
	--Send a 10ms long pulse to the trgger pin.
	trig:write(true)
	love.timer.sleep(0.00001) 
	trig:write(false)
	
	--Read the length of the response pulse.
	local len = readPulseLength(echo)
	--Speed of sound in air, in centimeters, divided be 2, as the wave must travel to and fro.
	
	--local dist = len * 0.034 / 2
	local dist = len * 17150
	--distance = round(pulse_duration * 17150, 2) 
	
	local str = string.format("Distance to ultrasonic is %fcm.", dist)
	print(str)
	--TODO: Test this out on real hardware and confirm the results.
end

--State
local lastTime = 0

------------------------------ Core API ------------------------------
function love.load()
	print("Began running Climbing Robot hardware configuration tests (manual).")
end

function love.update(dt)
	if love.timer.getTime() - lastTime > 1/fps then
		print("Attempting to read ultrasonic.")
		readUltrasonic()
		lastTime = love.timer.getTime()
	end
end

