import socket
import time

IP = "192.168.0.143"
PORT = 9004

print("Setting up and binding server.")
server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
server.bind((IP, PORT))

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
	print("Sending data")
	server.sendto(msgBytes, (IP, PORT))
	time.sleep(2)
#	data, addr = server.recvfrom(1024)
#	print(data)


# text_send_server.py
#
#import socket
#import select
#import time
#
#HOST = 'localhost'
#PORT = 65439

#ACK_TEXT = 'text_received'
#conn = 0
#addr = 0
#
#
#def main():
#    # instantiate a socket object
#    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
#    print('socket instantiated')
#
#    # bind the socket
#    sock.bind((HOST, PORT))
#    print('socket binded')
#
#    # start the socket listening
#    sock.listen()
#    print('socket now listening')
#
#    # accept the socket response from the client, and get the connection object
#    conn, addr = sock.accept()      # Note: execution waits here until the client calls sock.connect()
#    print('socket accepted, got connection object')
#
#    myCounter = 0
#    while True:
#        message = 'message ' + str(myCounter)
#       print('sending: ' + message)
#        sendTextViaSocket(message, conn)
#        myCounter += 1
#        time.sleep(1)
#    # end while
## end function
#
#def sendTextViaSocket(message, sock):
#    # encode the text message
#    encodedMessage = bytes(message, 'utf-8')
#
#    # send the data via the socket to the server
#    try:
#        sock.sendall(encodedMessage)
#    except:
#        print("Pipe broken. Lost client. Waiting for new client.")
#        #sock.listen()
#        #conn, addr = sock.accept()      # Note: execution waits here until the client calls sock.connect()
#
#
#    # receive acknowledgment from the server
#    encodedAckText = sock.recv(1024)
#    ackText = encodedAckText.decode('utf-8')
#
#    # log if acknowledgment was successful
#    if ackText == ACK_TEXT:
#        print('server acknowledged reception of text')
#    else:
#        print('error: server has sent back ' + ackText)
#    # end if
## end function
#
#if __name__ == '__main__':
#    main()