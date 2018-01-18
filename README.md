# Yaapu Frsky Telemetry script

A lua based telemetry script for the Taranis X9D+ and X7 radio using the frsky passthrough protocol, requires OpenTX 2.2 and arducopter 3.5.x.

Tested on a pixracer with copter 3.5.3 and on a pixhawk clone with copter 3.5.4

![Taranis X9D+](https://github.com/yaapu/FrskyTelemetry/blob/master/IMAGES/screenshot_x9.JPG)

![Taranis X7](https://github.com/yaapu/FrskyTelemetry/blob/master/IMAGES/screenshot_x7.JPG)

## Features

 - artificial horizon with roll,pitch and yaw with numeric compass heading
 - battery voltage from 3 sources (in order of priority)
 - - frsky FLVSS voltage sensor if available (vs is displayed next to voltage)
 - - frsky analog port if available (a2 is displayed next to voltage)
 - - flight controller via telemetry (fc is displayed next to voltage)
 - battery lowest cell if available or cell average if not
 - battery current
 - battery capacity and battery capacity used in mAh and %
 - vertical speed on left side of HUD
 - altitude on right side of HUD 
 - gps altitude
 - gps fix status and hdop
 - flight time
 - rssi value
 - transmitter voltage
 - home distance
 - home heading as rotating triangle
 - mavlink messages with history accessible with +/- buttons short press
 
## Hardware requirements

Please refer to the arducopter wiki for information on how to configure your flight controller for passthrough protocol
 - http://ardupilot.org/copter/docs/common-frsky-passthrough.html

For information on how to connect the FrSky equipment together, please refer to 
 - http://ardupilot.org/copter/docs/common-frsky-telemetry.html#common-frsky-equipment
 - http://ardupilot.org/copter/docs/common-frsky-telemetry.html#frsky-cables

## Installation

The script is quite big and compilation on your radio may fail.
The safest way is to compile it on Companion and then copy the .luac compiled version to the SD card in the /SCRIPTS/TELEMETRY folder.
To enable sound files playback copy them to /SOUNDS/yaapu0/en folder.

## Notes

Speech sound files generated with https://soundoftext.com/
As of now only english is supported
