# Control System
This chapter will go over the various parts of hardware and software that needed to be implemented in order to allow the robot to overcome obstacles in it's path, by climbing over those obstacles.

The below document is written for version "1.0.0-beta" of the control system. If using a different version, the information reflected here may not be perfectly accurate. Accuracy is only guaranteed for the matching version.
## Preview
A thorough list of hardware components and libraries/frameworks used has already been presented in a previous chapter, thus; below will just be a brief list recalling those components. Note, this will only list the components that are relevant to the Control System and **not** all components of the robot.

### Hardware
#### Robot
1. A **Raspberry Pi 3B+** is placed inside the robot and acts as;
	- The machine **hosting the robot's server**, to allow for remote access.
	- A flagship controller that handles the --- **computationally expensive --- image processing** required for environment-recognition (The machine learning model mentioned in the previous chapter.). The resultant data is then transmitted out to the remote.
	- Implements the **control API** used by the remote.
2. A **Raspberry Pi Camera Rev 1.3** used by the ML module and to provide a video-feed to the user.
3. 2x HC-SR04 **ultrasonic sensors** used to provide the control system with distance- and angle-checks.
4. An **Arduino Nano** used to offload motor-control functionality from the Pi 3B+ and expose it through a simple serial interface.
5. An MPU-9050 **3-axis gyroscope** used to provide the control system with spatial awareness checks.
6. As for a power source, all these modules simply share the **same power-line as the robot's motors**.
#### Remote
1. A **Raspberry Pi Zero W** is placed inside the remote, and used for;
	- Establishing a connection to the server from dedicated hardware.
	- Performing all the control-logic required.
	- Providing a user-interface to the robot.
	- Displaying a live-video feed to the user.
	- Storing the user-defined maneuvers for obstacle-navigation as well as executing them. (Note that a computer is needed to define those scripts.)
2. An RPi 4i WaveShare Display **touchscreen** for user I/O.
3. A 5V 8Ah **power source** to drive the remote.
### Software
1. L2D is used for the following aspects:
	- **Window management** for user-interface.
	- **Graphics** for the user-interface.
	- As a **mathematical operations library**.
	- **Platform-independent code**.
	- **Cross-platform exporting** (Windows, MacOS, Unix, Android, iOS and HTML5 platforms.) Which allows the remote to run on almost any device, and not only the dedicated remote.
	- **File System I/O** for saving and loading user-defined maneuvers.
2. **MiddleClass** is used to natively introduce OOP paradigms into Lua, which was critical for the architecture of both programs.
3. **Bitser** is used for natively serializing and de-serializing Lua values, including complex tables, which needed to:
	- Transmit commands over the internet.
	- (with the aid of rxi-JSON) save and load user-defined maneuvers.
4. **rxi-JSON** is used to parse JSON files into Lua tables, and to format Lua tables as JSON files. This is used in conjunction with Bitser to save and load user-defined maneuvers.
5. **Lume** is used to provide various small utility and helper functions that are used throughout this project.
6. **LuaSocket** is used to fulfill the program's networking needs. It provides interfaces for many networking protocols, of which two were used; *UDP Sockets* and *HTTP Requests*. It is a non-native module, written in C.
7. **Sock** is used to provide an abstraction layer over LuaSocket. It provides the following (note that it provides those features for *UDP* and *TCP* sockets, but only the former was utilized.)
	- Hosting, serving, and managing clients.
	- Connecting to servers.
	- Managing "*client<->server events*" and providing a clean API for polling them.
9. **LoveBird** is used to establish a remote-console for both devices, facilitating remote debugging and monitoring once the project has been deployed.
10. **SLAB** is used to satisfy all of the program's GUI-needs. It is an Immediate-Mode GUI library.
### Custom Software
This project also had requirements which were not met by any currently available tools, and as such; the following libraries were custom-written to fulfill those requirements and enable execution of this project to complete.

1. **CruxClass** is a modified version of MiddleClass that, mainly, extends it's support for mixins.
2. **Scheduler** is a timing-library that can be used to schedule task execution; at specific times, with delay, for a specific duration, and/or with a specific number of executions. These four rules can be mixed-and-matched as well as chained; tasks can be chained to the ending of other tasks. This library was written to manage the following:
	- Timing-related aspects of networking (polling, pinging, timeout-checks, etc...).
	- To schedule update-messages to periodically sync the two devices used.
	- To pose hard-limits on some commands, particularly, getters, to prevent abuse from within user-written maneuvers.
	- Its API is also exposed from within the environment available to user-written maneuvers allowing those scripts to take advantage of its full potential.
3. **ConsoleStringer** was written to facilitate the management and drawing of the console seen on the robot's debug screen as well as on the remote's automatic-mode screen. The latter is quite critical to the operation of the program, as it is the main (non-debug mode) way to track the robot's actions, script usage, its AI's decision-making process, etc...
4. **FilePathUtils** provides utilities and abstractions over L2D's file I/O, as well as Lua's native I/O. More specifically, it provides the following:
	- A unification API covering L2D's and Lua's file I/Os.
	- Short-hands for accessing files within the working directory and the save directory.
	- A stateful API for setting a currently-targeted directory.
	- The ability to register custom paths for user-defined short-hands.
	- Directory format unification across all target platforms.
5. **LightFSMs** is used to satisfy the project's need for a Finite State Machine. It was used to manage the following aspects:
	- Menu-navigation and switching.
	- Connectivity-locks.
	- The AI sub-system.
	- It is also exposed to the user-written maneuvers' environment.

## Program
This section will deal with explaining the two programs forming the core of the control system.
### Robot
This section will elaborate on the program that is on the robot's side, which from here-on shall be referred to simply as "the robot".
#### Networking
Most of the networking aspects of the program are implemented in `{prj_dir}/robot/src/UdpApi.lua`
##### Initialization
Sock is used to setup a UDP socket over which most (All but processed image data) will be transmitted.
Within 60 seconds of completing it's booting-sequence, the robot will have initialized a UDP server open on all of it's IP addresses, and bound to the port 9000.
Note that the above open-IP-addresses and port are the defaults, and that can be changed by accessing the following two fields inside `{prj_dir}/robot/src/AppData.lua`:
- `openIp` for the open addresses.
- `port` for the bound port.

This can technically be done at runtime but success is not guaranteed.
If it is done before launch, success is guaranteed.
##### Connect & Disconnect
Once a client has connected, no more will be accepted, and it will be pinged once per second. Should the client fail to respond to 3 consecutive pings, it will be deemed unresponsive and be disconnected.
As with above, those are defaults which can be modified by accessing `{prj_dir}/robot/src/AppData.lua` and changing:
- `PING_INTERVAL` for the frequency of pings. (unit: sec)
- `PINGS_BEFORE_TIMEOUT` for the number of pins before a client is disconnected.
##### Update Limits
`UdpApi` is also responsible for posing hard limits on some commands, such as fetching the distances of the ultrasonic, to prevent client code from overloading or abusing the robot.
##### API Abstraction
`UdpApi` is also responsible for providing an abstraction layer between networking messages and `PiApi` (the internal API layer for all system-calls) by routing any network events, which map to commands, to their respective methods inside `PiApi`
#### Image Processing
This aspect of the control system is written in Python 3, as opposed to the usual Lua.
##### Purpose
The feed of the robot's camera is fed into an ML model in order to detect, recognize and then classify a long list of objects. This is an absolutely central aspect of the entire control system and is what is used to trigger any and all maneuvering scripts.
##### Method
The camera feed is fed into a *TensorFlow* pipeline for recognition. This pipeline takes in one frame at a time, captured at 5fps (due to the Pi's very limited computational power).

*OpenCV* is also used to greatly optimize and speed up the process (without OpenCV the highest speed reached was a mere 1.3fps).

*Numpy* is used as the mathematical library of choice for tasks such as cropping, expanding, scaling, bloat-ifying and convert images (the camera feed's frames) between various format's required in different steps of the process.

The TensorFlow model then outputs a list of objects that have been detected, each containing the following fields:
- A two-dimensional point describing the top-left corner of an axis-aligned bounding-box containing the found object.
- An integer describing the width of the AABB. (unit: screen-pixels)
- An integer describing the width of the AABB. (unit: screen-pixels)
- A decimal in the range `[0, 1)`  describing the accuracy (i.e. confidence-level) of this object's label.
- An alphanumeric string describing the label that was assigned to this object in the training-set.
##### The ML Model Used
A *CNN* (Convolutional Neural Network) machine learning model is implemented using **TensorFlow's Object Detection API**  which is an open-source framework built on top of TensorFlow itself.
It provides a number of detection models, pre-trained models, includes a number of datasets and also offers many abstractions and wrappers for various ML models.

OpenCV is then used to optimize the model's operation.

The model implemented was trained on the *COCO* (Common Objects In Context) dataset, which is a large-scale object detection, segmentation, and captioning dataset released under the **Creative Commons Attribution 4.0** license.
##### Further Potential
The robot's image processing model can (and should) be trained differently based on the environment it is expected to operate in, to significantly increase the number of obstacles which it can detect, and thus overcome.
##### Transmission
The data produced by the ML model is converted into a JSON-formatted file and is then temporary stored until a newer frame has been processed, at which point the newer frame takes it place.

The remote is free to send `HTTP GET` requests to the robot (over the same IP and port as the UDP socket, but with the port incremented by one.) at anytime to receive the aforementioned JSON file as a `application/x-www-form-urlencoded` string.
##### Usage In Maneuvering Scripts
The CNN's object detection is what is used to trigger user-written maneuvering scripts while in automatic-mode.

The scripts must define a `label` and `minimum accuracy` upon which to be triggered.

If two, or more, scripts share the same `label`, the one with a higher `minimum accuracy` that is still within the required limit will be chosen.
If two, or more, scripts share the same `label` and `minimum accuracy` then an error is thrown.
#### Sensors & Spatial Data
The robot is fitted
#### Motors API
#### Debug Menu

### Remote
This section will elaborate on the program that is on the remote's side, which from here-on shall be referred to simply as "the remote".
#### Networking
#### Image Data Transmission
#### Menus
##### Main Menu
##### IP Menu
##### Manual Mode Menu
##### Automatic Mode Menu
### Automatic Mode
### User-Written Maneuvers
#### Introductory
#### Example
#### Full API 
### Common
#### Networking Commands
