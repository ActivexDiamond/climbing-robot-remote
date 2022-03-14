import socket
import time

OPEN_IP = ""
TARGET_IP = "192.168.0.143"
PORT = 9004

print("Setting up and binding server.")
server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server.bind((OPEN_IP, PORT))

print("Entering recv loop.")

str = """
local t = {{}}
t.msg = {}
t.timestamp = {}
return t
"""
msg = str.format("Hello!", 2)
msgBytes = bytes(msg, "utf-8")

while 1:
	print("Listening for ping.")
	bytesAddressPair = server.recvfrom(1024)
	message = bytesAddressPair[0]
	address = bytesAddressPair[1]
    
	print("Message from {}:{}".format(address, message))

	print("Sending data")
	server.sendto(msgBytes, address)
	time.sleep(2)