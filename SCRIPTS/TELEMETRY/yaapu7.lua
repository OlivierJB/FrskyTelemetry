--
-- An FRSKY S.Port <passthrough protocol> based Telemetry script for Taranis X7
--
-- Copyright (C) 2018. Alessandro Apostoli
--   https://github.com/yaapu
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY, without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, see <http://www.gnu.org/licenses>.
-- 
-- Passthrough protocol reference:
--   https://cdn.rawgit.com/ArduPilot/ardupilot_wiki/33cd0c2c/images/FrSky_Passthrough_protocol.xlsx
--
-- Borrowed some code from the LI-xx BATTCHECK v3.30 script
--  http://frskytaranis.forumactif.org/t2800-lua-download-un-testeur-de-batterie-sur-la-radio


local cellfull, cellempty = 4.2, 3.00       
local cell = {0, 0, 0, 0, 0 ,0}                                                  
local cellsumfull, cellsumempty, cellsumtype, cellsum = 0, 0, 0, 0               

local i, cellmin, cellresult = 0, cellfull, 0, 0                                  
local thrOut = 0
local voltage = 0

local flightModes = {}
  flightModes[0]=""
  flightModes[1]="Stabilize"
  flightModes[2]="Acro"
  flightModes[3]="AltHold"
  flightModes[4]="Auto"
  flightModes[5]="Guided"
  flightModes[6]="Loiter"
  flightModes[7]="RTL"
  flightModes[8]="Circle"
  flightModes[9]=""
  flightModes[10]="Land"
  flightModes[11]=""
  flightModes[12]="Drift"
  flightModes[13]=""
  flightModes[14]="Sport"
  flightModes[15]="Flip"
  flightModes[16]="AutoTune"
  flightModes[17]="PosHold"
  flightModes[18]="Brake"
  flightModes[19]="Throw"
  flightModes[20]="Avoid"
  flightModes[21]="GuiNGPS"

local gpsStatuses = {}
  gpsStatuses[0]="NoGPS"
  gpsStatuses[1]="NoLock"
  gpsStatuses[2]="2DFIX"
  gpsStatuses[3]="3DFix"

local mavSeverity = {}
  mavSeverity[0]="EMR"
  mavSeverity[1]="ALR"
  mavSeverity[2]="CRT"
  mavSeverity[3]="ERR"
  mavSeverity[4]="WRN"
  mavSeverity[5]="NOT"
  mavSeverity[6]="INF"
  mavSeverity[7]="DBG"

local soundFileBasePath = "/SOUNDS/yaapu0/en"
local soundFiles = {}
	-- battery
	soundFiles["bat5"] = "bat5.wav"
	soundFiles["bat10"] = "bat10.wav"
	soundFiles["bat15"] = "bat15.wav"
	soundFiles["bat20"] = "bat20.wav"
	soundFiles["bat25"] = "bat25.wav"
	soundFiles["bat30"] = "bat30.wav"
	soundFiles["bat40"] = "bat40.wav"
	soundFiles["bat50"] = "bat50.wav"
	soundFiles["bat60"] = "bat60.wav"
	soundFiles["bat75"] = "bat75.wav"
	-- gps
	soundFiles["gpsfix"] = "gpsfix.wav"
	soundFiles["gpsnofix"] = "gpsnofix.wav"
	-- failsafe
	soundFiles["lowbat"] = "lowbat.wav"
	soundFiles["ekf"] = "ekf.wav"
	-- events
	soundFiles["yaapu"] = "yaapu.wav"
	soundFiles["landing"] = "landing.wav"
	soundFiles["armed"] = "armed.wav"
	soundFiles["disarmed"] = "disarmed.wav"
	-- events
	soundFiles["land"] = "land.wav"	
	soundFiles["auto"] = "auto.wav"
	soundFiles["stabilize"] = "stabilize.wav"	
	soundFiles["althold"] = "althold.wav"
	soundFiles["poshold"] = "poshold.wav"
	soundFiles["loiter"] = "loiter.wav"
	soundFiles["autotune"] = "autotune.wav"	
	soundFiles["rtl"] = "rtl.wav"
	soundFiles["autotune"] = "autotune.wav"	

  -- STATUS
local flightMode = 0
local simpleMode = 0
local landComplete = 0
local statusArmed = 0
local batteryFailsafe = 0
local lastBatteryFailsafe = 0
local ekfFailsafe = 0
local lastEkfFailsafe = 0
-- GPS
local numSats = 0
local gpsStatus = 0
local gpsHdopC = 100
local gpsHdopM = 0
local gpsAlt = 0
-- BATT
local battVolt = 0
local battCurrent = 0
local battMah = 0
-- HOME
local homeDist = 0
local homeAlt = 0
local homeAngle = -1
-- MESSAGES max 10 lines
local messageBuffer = "" 
local messageHistory = {}
local severity = 0
local messageIdx = 1
local messageDuplicate = 1
local lastMessage = ""
local lastMessageValue = 0
local lastMessageTime = 0
-- VELANDYAW
local vSpeed = 0
local hSpeed = 0
local yaw = 0
-- ROLLPITCH
local roll = 0
local pitch = 0
-- TELEMETRY
local SENSOR_ID,FRAME_ID,DATA_ID,VALUE
local mult = 0
local c1,c2,c3,c4
-- PARAMS
local paramId,paramValue
local frameType
local battFailsafeVoltage = 0
local battFailsafeCapacity = 0
local battCapacity = 0
--
local minX = 0
local maxX = 60
local minY = 9
local maxY = 55
--
local noTelemetryData = 1

local function playSound(soundFile)
	playFile(soundFileBasePath .. "/" .. soundFiles[soundFile])
end

local function getValueOrDefault(value)
	local tmp = getValue(value)
	if tmp == nil then
		return 0
	end
	return tmp
end

local function pushMessage(severity, msg)
	if ( severity < 4) then
		playTone(400,300,0)
	else
		playTone(600,300,0)
	end
	local mm = msg
	if msg == lastMessage then
		messageDuplicate = messageDuplicate + 1
		if messageDuplicate > 1 then
			if string.len(mm) > 19 then
				mm = string.sub(mm,1,19)
				messageHistory[messageIdx - 1] = string.format("%d.%s %-20s (x%d)", messageIdx - 1, mavSeverity[severity], mm, messageDuplicate)
			else
				messageHistory[messageIdx - 1] = string.format("%d.%s %s (x%d)", messageIdx - 1, mavSeverity[severity], msg, messageDuplicate)
			end
		end
	else
		messageHistory[messageIdx] = string.format("[%02d:%s] %s", messageIdx, mavSeverity[severity], msg)
		messageIdx = messageIdx + 1
		lastMessage = msg
		messageDuplicate = 1
	end
	lastMessageTime = getTime() -- valore in secondi 
end

local seconds = 0
local lastTimerStart = 0
--
local function startTimer()
	lastTimerStart = getTime()/100
end

local function stopTimer()
	seconds = seconds + getTime()/100 - lastTimerStart
	lastTimerStart = 0
end

local function symTimer()
	thrOut = getValue("thr")
	if (thrOut > -500 ) then
		landComplete = 1
	else
		landComplete = 0
	end
end

local function symGPS()
	thrOut = getValue("thr")
	if (thrOut > 0 ) then
		numSats = 9
		gpsStatus = 3
		gpsHdopC = 11
		ekfFailsafe = 0
		batteryFailsafe = 0
		noTelemetryData = 0
	elseif thrOut > -500  then
		numSats = 6
		gpsStatus = 3
		gpsHdopC = 25
		ekfFailsafe = 1
		batteryFailsafe = 1
		noTelemetryData = 0
	else
		numSats = 0
		gpsStatus = 0
		gpsHdopC = 100
		ekfFailsafe = 0
		batteryFailsafe = 0
		noTelemetryData = 1
	end
end

local function symBatt()
	thrOut = getValue("thr")
	if (thrOut > 0 ) then
		LIPObatt = 1350 + ((thrOut)*0.01 * 30)
		LIPOcelm = LIPObatt/4
		battCurrent = 100 +  ((thrOut)*0.01 * 30)
		battVolt = LIPObatt*0.1
		battCapacity = 10500
		battMah = 5200
		flightMode = 1
		statusArmed = 1
		simpleMode = 1
		homeDist = math.abs(thrOut)*2
	end
end

-- simulates attitude by using channel 1 for roll, channel 2 for pitch and channel 4 for yaw
local function symAttitude()
	local rollCh = 0
	local pitchCh = 0
	local yawCh = 0
	-- roll [-1024,1024] ==> [-180,180]
	rollCh = getValue("ch1") * 0.175
	-- pitch [1024,-1024] ==> [-90,90]
	pitchCh = getValue("ch2") * 0.0878
	-- yaw [-1024,1024] ==> [0,360]
	yawCh = getValue("ch10")
	if ( yawCh >= 0) then
		yawCh = yawCh * 0.175
	else
		yawCh = 360 + (yawCh * 0.175)
	end
	roll = rollCh/3
	pitch = pitchCh/2
	yaw = yawCh
end

local function symHome()
	local yawCh = 0
	local S2Ch = 0
	-- home angle in deg [0-360]
	S2Ch = getValue("ch12")
	yawCh = getValue("ch4")
	homeAlt = yawCh
	vSpeed = yawCh * 0.1
	if ( yawCh >= 0) then
		yawCh = yawCh * 0.175
	else
		yawCh = 360 + (yawCh * 0.175)
	end
	if ( S2Ch >= 0) then
		S2Ch = S2Ch * 0.175
	else
		S2Ch = 360 + (S2Ch * 0.175)
	end
	if (thrOut > 0 ) then
		homeAngle = S2Ch
	else
		homeAngle = -1
	end	
	yaw = yawCh
end

local function processTelemetry()
  SENSOR_ID,FRAME_ID,DATA_ID,VALUE = sportTelemetryPop()
	--
	--FRAME_ID = 0x10
	--DATA_ID = 0x5002
	--VALUE = 0xf4006b8
	--
	--FRAME_ID = 0x10
	--DATA_ID = 0x5004
	--VALUE = 0x168000
	--
	if ( FRAME_ID == 0x10) then
		noTelemetryData = 0
		if ( DATA_ID == 0x5006) then -- ROLLPITCH 
			-- roll [0,1800] ==> [-180,180]
			roll = (bit32.extract(VALUE,0,11) - 900) * 0.2 
			-- pitch [0,900] ==> [-90,90]
			pitch = (bit32.extract(VALUE,11,10) - 450) * 0.2
		elseif ( DATA_ID == 0x5005) then -- VELANDYAW 
			vSpeed = bit32.extract(VALUE,1,7) * (10^bit32.extract(VALUE,0,1))
			if (bit32.extract(VALUE,8,1) == 1) then
				vSpeed = -vSpeed
			end
			hSpeed = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1))
			yaw = bit32.extract(VALUE,17,11) * 0.2
		elseif ( DATA_ID == 0x5001) then -- AP STATUS 
			flightMode = bit32.extract(VALUE,0,5)
			simpleMode = bit32.extract(VALUE,5,2)
			landComplete = bit32.extract(VALUE,7,1)
			statusArmed = bit32.extract(VALUE,8,1)
			batteryFailsafe = bit32.extract(VALUE,9,1)
			ekfFailsafe = bit32.extract(VALUE,10,2)
		elseif ( DATA_ID == 0x5002) then -- GPS STATUS 
			numSats = bit32.extract(VALUE,0,4)
			gpsStatus = bit32.extract(VALUE,4,2)
			gpsHdopC = bit32.extract(VALUE,7,7) * (10^bit32.extract(VALUE,6,1)) -- dm
			gpsAlt = bit32.extract(VALUE,24,7) * (10^bit32.extract(VALUE,22,2)) -- dm
			if (bit32.extract(VALUE,31,1) == 1) then
				gpsAlt = gpsAlt * -1
			end
		elseif ( DATA_ID == 0x5003) then -- BATT 
			battVolt = bit32.extract(VALUE,0,9)
			battCurrent = bit32.extract(VALUE,10,7) * (10^bit32.extract(VALUE,9,1))
			battMah = bit32.extract(VALUE,17,15)
		elseif ( DATA_ID == 0x5004) then -- HOME 
			homeDist = bit32.extract(VALUE,2,10) * (10^bit32.extract(VALUE,0,2))
			homeAlt = bit32.extract(VALUE,14,10) * (10^bit32.extract(VALUE,12,2)) * 0.1
			if (bit32.extract(VALUE,24,1) == 1) then
				homeAlt = homeAlt * -1
			end
			homeAngle = bit32.extract(VALUE, 25,  7) * 3
		elseif ( DATA_ID == 0x5000) then -- MESSAGES 
			if (VALUE ~= lastMessageValue) then
				lastMessageValue = VALUE
				c1 = bit32.extract(VALUE,0,7)
				c2 = bit32.extract(VALUE,8,7)
				c3 = bit32.extract(VALUE,16,7)
				c4 = bit32.extract(VALUE,24,7)
				messageBuffer = messageBuffer .. string.char(c4)
				messageBuffer = messageBuffer .. string.char(c3)
				messageBuffer = messageBuffer .. string.char(c2)
				messageBuffer = messageBuffer .. string.char(c1)
				if (c1 == 0 or c2 == 0 or c3 == 0 or c4 == 0) then
					severity = (bit32.extract(VALUE,15,1) * 4) + (bit32.extract(VALUE,23,1) * 2) + (bit32.extract(VALUE,30,1) * 1)
					pushMessage( severity, messageBuffer)
					messageBuffer = ""
				end
			end
		elseif ( DATA_ID == 0x5007) then -- PARAMS
			paramId = bit32.extract(VALUE,24,4)
			paramValue = bit32.extract(VALUE,0,24)
			if paramId == 1 then
				frameType = paramValue
			elseif paramId == 2 then
				battFailsafeVoltage = paramValue
			elseif paramId == 3 then
				battFailsafeCapacity = paramValue
			elseif paramId == 4 then
				battCapacity = paramValue
			end
		end
	end
end

local function telemetryEnabled()
	if getValue("RxBt") == 0 then
		noTelemetryData = 1
	end
	return true
	--return noTelemetryData == 0
end

local battSource = "na"

local function calcBattery()
	local battA2 = 0
	local cellCount = 3;
	--
	cellmin = cellfull
	cellResult = getValue("Cels")                          

	if type(cellResult) == "table" then                     
		battSource="vs"
		cellsum = 0                                         
		for i = 1, #cell do cell[i] = 0 end                 
			cellsumtype = #cellResult                           
		for i, v in pairs(cellResult) do                    
			cellsum = cellsum + v                             
			cell[i] = v                                       
			if cellmin > v then                               
				cellmin = v
			end
		end -- end for
	else
		-- cels is not defined let's check if A2 is defined
		cellmin = 0
		battA2 = getValue("A2")
		--
		if battA2 > 0 then
			battSource="a2"
				if battA2 > 21 then
					cellCount = 6
				elseif battA2 > 17 then
					cellCount = 5
				elseif battA2 > 13 then
					cellCount = 4
				else
					cellCount = 3
				end
			--
			cellmin = battA2/cellCount
			cellsum = battA2
		else
			-- A2 is not defined, last chance is battVolt
			if battVolt > 0 then
				battSource="fc"
				cellsum = battVolt*0.1
				if cellsum > 21 then
					cellCount = 6
				elseif cellsum > 17 then
					cellCount = 5
				elseif cellsum > 13 then
					cellCount = 4
				else
					cellCount = 3
				end
				--
				cellmin = cellsum/cellCount
			end
		end
	end -- end if
	--
	LIPOcelm = cellmin*100
	LIPObatt = cellsum*100
end

local function drawBattery()
	if (battCapacity > 0) then
		LIPOperc = (1 - (battMah/battCapacity))*100
	else
		LIPOperc = 0
	end
	lcd.drawRectangle(maxX+1,17,28,16,SOLID)
	lcd.drawFilledRectangle(maxX+1,17,28,16,SOLID)
	-- display battery voltage
	lcd.drawText(maxX + 28, 19, "v", SMLSIZE+RIGHT+INVERS)
	lcd.drawNumber(lcd.getLastLeftPos(), 18, LIPObatt, PREC2+RIGHT+INVERS)   
	-- display battery current
	lcd.drawText(maxX + 28, 26, "A", SMLSIZE+RIGHT+INVERS)
	lcd.drawNumber(lcd.getLastLeftPos(), 26, battCurrent, SMLSIZE+PREC1+RIGHT+INVERS)

	-- display lowest cell voltage
	if LIPOcelm < 350 then
		lcd.drawNumber(maxX + 30, 16, LIPOcelm, DBLSIZE+BLINK+PREC2)    
	else
		lcd.drawNumber(maxX + 30, 16, LIPOcelm, DBLSIZE+PREC2)      
	end
	lcd.drawText(lcd.getLastRightPos(), 17, "v", SMLSIZE)
	lcd.drawText(128, 25, battSource, SMLSIZE+RIGHT)

	-- display capacity %
	local yy = 48
	lcd.drawText(128, yy, "Ah", SMLSIZE+RIGHT)
	lcd.drawNumber(lcd.getLastLeftPos(), yy, battCapacity/100, SMLSIZE+PREC1+RIGHT)  
	lcd.drawText(lcd.getLastLeftPos(), yy, "/", SMLSIZE+RIGHT)
	lcd.drawNumber(lcd.getLastLeftPos(), yy, battMah/100, SMLSIZE+PREC1+RIGHT)  
	--
	lcd.drawRectangle(maxX +1,yy-2,17,12,SOLID)
	lcd.drawFilledRectangle(maxX +1,yy-2,17,12,SOLID)
	--
	lcd.drawText(maxX+17, yy, "%", SMLSIZE+INVERS+RIGHT)
	lcd.drawNumber(lcd.getLastLeftPos(), yy-1, LIPOperc, INVERS+RIGHT)       
end

local function drawFlightMode()
	lcd.drawFilledRectangle(0,0, 128, 9, SOLID)
	lcd.drawRectangle(0, 0, 128, 9, SOLID)

	if (not telemetryEnabled()) then
		lcd.drawFilledRectangle((128-100)/2,18, 100, 30, SOLID)
		lcd.drawText(17, 29, "no telemetry data", INVERS)
		return
	end

	local strMode = flightModes[flightMode]
	--
	lcd.drawText(1, 1, strMode, SMLSIZE+INVERS)

	if ( simpleMode == 1) then
		lcd.drawText(lcd.getLastRightPos(), 1, "(S)", SMLSIZE+INVERS)
	end

	if (statusArmed == 1) then
		lcd.drawText(18, 47, "ARMED", SMLSIZE+INVERS)
	else
		lcd.drawText(18, 47, "DISARMED", SMLSIZE+INVERS+BLINK)
	end
end

local function drawHome()
	local xx = maxX + 2
	local yy = 10
	--
	lcd.drawLine(xx,13,xx + 8,13, SOLID, 0)
	-- left arrow
	lcd.drawLine(xx+1,12,xx + 2,11, SOLID, 0)
	lcd.drawLine(xx+1,14,xx + 2,15, SOLID, 0)
	-- right arrow
	lcd.drawLine(xx+7,12,xx + 6,11, SOLID, 0)
	lcd.drawLine(xx+7,14,xx + 6,15, SOLID, 0)

	lcd.drawNumber(xx + 11, yy, homeDist, SMLSIZE)
	lcd.drawText(lcd.getLastRightPos(), yy, "m",SMLSIZE)
end

local function drawMessage()
	lcd.drawFilledRectangle(0,55, 212, 9, SOLID)
	lcd.drawRectangle(0, 55, 212, 9, SOLID)
	local now = getTime()
	if (now - lastMessageTime ) > 300 then
		lcd.drawText(1, 56, messageHistory[messageIdx-1],SMLSIZE+INVERS)
	else
		lcd.drawText(1, 56, messageHistory[messageIdx-1],SMLSIZE+INVERS+BLINK)
	end
end

local function drawAllMessages()
	local idx = 1
	if (messageIdx <= 6) then
		for i = 1, messageIdx - 1 do
			lcd.drawText(1, 1+10*(idx - 1), messageHistory[i],SMLSIZE)
			idx = idx+1
		end
	else
		for i = messageIdx - 6,messageIdx - 1 do
			lcd.drawText(1, 1+10*(idx-1), messageHistory[i],SMLSIZE)
			idx = idx+1
		end
	end
end

local function drawGPSStatus()
	local xx = 89
	local yy = 33
	--
	lcd.drawRectangle(xx,yy - 1,50,15,SOLID)
	--
	local strStatus = gpsStatuses[gpsStatus] 
	--
	local flags = BLINK
	if gpsStatus  > 2 then
		lcd.drawFilledRectangle(xx,yy - 1,50,15,SOLID)
		if homeAngle ~= -1 then
			flags = 0
		end
	
		lcd.drawText(xx + 2, yy, strStatus, SMLSIZE+INVERS)
		lcd.drawNumber(128, yy, numSats, SMLSIZE+INVERS+RIGHT)
		lcd.drawText(xx + 2, yy + 7, "Hdop ", SMLSIZE+INVERS)
		--
		if gpsHdopC > 100 then
			lcd.drawText(128, yy + 7, "10+", SMLSIZE+INVERS+RIGHT+flags)
		else
			lcd.drawNumber(128, yy + 7, gpsHdopC , SMLSIZE+INVERS+RIGHT+PREC1+flags)
		end
	else
		lcd.drawText(xx + 5, yy + 3, strStatus, BLINK)
	end
end

local function drawGrid()
	lcd.drawLine(maxX, 0, maxX, 63, SOLID, 0)
end

local timerRunning = 0

local function checkLandingStatus()
	if ( timerRunning == 0 and landComplete == 1 and lastTimerStart == 0) then
		startTimer()
	end
	if (timerRunning == 1 and landComplete == 0 and lastTimerStart ~= 0) then
		stopTimer()
		playSound("landing")
	end
	timerRunning = landComplete
end
local flightTime = 0

local function calcFlightTime()
	local elapsed = 0
	if ( lastTimerStart ~= 0) then
		elapsed = getTime()/100 - lastTimerStart
	end
	flightTime = elapsed + seconds
end

-- draws a line centered at ox,oy with given angle and length W/O CROPPING
local function drawLine(ox,oy,angle,len,style,maxX,maxY)
	local xx = math.cos(math.rad(angle)) * len * 0.5
	local yy = math.sin(math.rad(angle)) * len * 0.5

	local x1 = ox - xx
	local x2 = ox + xx
	local y1 = oy - yy
	local y2 = oy + yy
	--
	lcd.drawLine(x1,y1,x2,y2, style,0)
end

-- draws a line centered at ox,oy with given angle and length WITH CROPPING
local function drawCroppedLine(ox,oy,angle,len,style,maxX,maxY)
	--
	local xx = math.cos(math.rad(angle)) * len * 0.5
	local yy = math.sin(math.rad(angle)) * len * 0.5
	--
	local x1 = ox - xx
	local x2 = ox + xx
	local y1 = oy - yy
	local y2 = oy + yy
	--
	if (x1 >= maxX and x2 >= maxX) then
		return
	end
	if (x1 >= maxX) then
		y1 = y1 - math.tan(math.rad(angle)) * (maxX - x1)
		x1 = maxX - 1
	end
	if (x2 >= maxX) then
		y2 = y2 + math.tan(math.rad(angle)) * (maxX - x2)
		x2 = maxX - 1
	end
	lcd.drawLine(x1,y1,x2,y2, style,0)
end

local function drawFailsafe()
	if ekfFailsafe > 0 then
		if lastEkfFailsafe == 0 then
			playSound("ekf")
		end
		lcd.drawText(maxX/2 - 28, 47, "EKF FAILSAFE", SMLSIZE+INVERS+BLINK)
	end
	if batteryFailsafe > 0 then
		if lastBatteryFailsafe == 0 then
			playSound("lowbat")
		end
		lcd.drawText(maxX/2 - 28, 47, "BAT FAILSAFE", SMLSIZE+INVERS+BLINK)
	end
	lastEkfFailsafe = ekfFailsafe
	lastBatteryFailsafe = batteryFailsafe
end

local function drawPitch()
	local y = 0
	local p = pitch
	-- horizon min max +/- 30°
	if ( pitch > 0) then
		if (pitch > 30) then
			p = 30
		end
	else
		if (pitch < -30) then
			p = -30
		end
	end
	-- y normalized at 32 +/-20  (0.75 = 20/32)
	y = 32 + 0.75*p
	-- horizon, lower half of HUD filled in grey
	--lcd.drawFilledRectangle(minX,y,maxX-minX,maxY-y + 1,GREY_DEFAULT)
	--
	-- center indicators for vSpeed and alt
	local width = 17
	lcd.drawLine(minX,32 - 5,minX + width,32 - 5, SOLID, 0)
	lcd.drawLine(minX,32 + 4,minX + width,32 + 4, SOLID, 0)
	lcd.drawLine(minX + width + 1,32 + 4,minX + width + 5,32, SOLID, 0)
	lcd.drawLine(minX + width + 1,32 - 4,minX + width + 5,32, SOLID, 0)
	lcd.drawPoint(minX + width + 5,32)
	--
	lcd.drawLine(maxX - width - 1,32 - 5,maxX - 1,32 - 5,SOLID,0)
	lcd.drawLine(maxX - width - 1,32 + 4,maxX - 1,32 + 4,SOLID,0)
	lcd.drawLine(maxX - width - 2,32 + 4,maxX - width - 6,32, SOLID, 0)
	lcd.drawLine(maxX - width - 2,32 - 4,maxX - width - 6,32, SOLID, 0)
	lcd.drawPoint(maxX - width - 6,32)
	-- center value based on char count
	if homeAlt > 0 then
		if homeAlt < 10 then -- 2 digits with decimal
			lcd.drawNumber(maxX - 1,32 - 3,homeAlt * 10,SMLSIZE+PREC1+RIGHT)
		else -- 3 digits
			lcd.drawNumber(maxX - 1 + 2,32 - 3,homeAlt,SMLSIZE+RIGHT)
		end
	else
		if homeAlt > -10 then -- 1 digit with sign
			lcd.drawNumber(maxX - 1,32 - 3,homeAlt * 10,SMLSIZE+PREC1+RIGHT)
		else -- 3 digits with sign
			lcd.drawNumber(maxX - 1,32 - 3,homeAlt,SMLSIZE+RIGHT)
		end
	end
	--
	if (vSpeed > 999) then
		lcd.drawNumber(minX + 1,32 - 3,vSpeed*0.1,SMLSIZE)
	elseif (vSpeed < -99) then
		lcd.drawNumber(minX + 1,32 - 3,vSpeed * 0.1,SMLSIZE)
	else
		lcd.drawNumber(minX + 1,32 - 3,vSpeed,SMLSIZE+PREC1)
	end
	-- up pointing center arrow
	local x = math.floor(maxX/2)
	lcd.drawLine(x-10,34 + 5,x ,34 ,SOLID,0)
	lcd.drawLine(x+1 ,34 ,x + 10, 34 + 5,SOLID,0)
end

local function drawRoll()
	local r = -roll
	local r2 = 10 --vertical distance between roll horiz segments
	local cx,cy,dx,dy,ccx,ccy,cccx,cccy
	-- no roll ==> segments are vertical, offsets are multiples of r2
	if ( roll == 0) then
		dx=0
		dy=pitch
		cx=0
		cy=r2
		ccx=0
		ccy=2*r2
		cccx=0
		cccy=3*r2
	else
		-- center line offsets
		dx = math.cos(math.rad(90 - r)) * -pitch 
		dy = math.sin(math.rad(90 - r)) * pitch
		-- 1st line offsets
		cx = math.cos(math.rad(90 - r)) * r2
		cy = math.sin(math.rad(90 - r)) * r2
		-- 2nd line offsets
		ccx = math.cos(math.rad(90 - r)) * 2 * r2
		ccy = math.sin(math.rad(90 - r)) * 2 * r2
		-- 3rd line offsets
		cccx = math.cos(math.rad(90 - r)) * 3 * r2
		cccy = math.sin(math.rad(90 - r)) * 3 * r2
	end
	local x = math.floor(maxX/2)
	drawCroppedLine(dx + x - cccx,dy + 32 + cccy,r,4,DOTTED,maxX,maxY)
	drawCroppedLine(dx + x - ccx,dy + 32 + ccy,r,6,DOTTED,maxX,maxY)
	drawCroppedLine(dx + x - cx,dy + 32 + cy,r,9,DOTTED,maxX,maxY)
	drawCroppedLine(dx + x,dy + 32,r,16,SOLID,maxX,maxY)
	drawCroppedLine(dx + x + cx,dy + 32 - cy,r,9,DOTTED,maxX,maxY)
	drawCroppedLine(dx + x + ccx,dy + 32 - ccy,r,6,DOTTED,maxX,maxY)
	drawCroppedLine(dx + x + cccx,dy + 32 - cccy,r,4,DOTTED,maxX,maxY)
end

local function roundTo(val,int)
	return math.floor(val/int) * int
end

local function drawYaw()
	local northX = math.floor(maxX/2) - 2
	local offset = northX - 4
	local yawRounded =  math.floor(yaw)
	local yawWindow = roundTo(yaw,10)
	local maxXHalf = math.floor(maxX/2)
	local yawWindowOn = false
	local flags = SMLSIZE
	if (not(yawWindow == 0 or yawWindow == 90 or yawWindow == 180 or yawWindow == 270 or yawWindow == 360)) then
		yawWindowOn = true
	end
	--
	if (yawRounded == 0 or yawRounded == 360) then
		lcd.drawText(northX - offset, minY+1, "W", SMLSIZE)
		lcd.drawText(northX, minY+1, "N", flags)
		lcd.drawText(northX + offset, minY+1, "E", SMLSIZE)
	elseif (yawRounded == 90) then
		lcd.drawText(northX - offset, minY+1, "N", SMLSIZE)
		lcd.drawText(northX, minY+1, "E", flags)
		lcd.drawText(northX + offset, minY+1, "S", SMLSIZE)
	elseif (yawRounded == 180) then
		lcd.drawText(northX - offset, minY+1, "W", SMLSIZE)
		lcd.drawText(northX, minY+1, "S", flags)
		lcd.drawText(northX + offset, minY+1, "E", SMLSIZE)
	elseif (yawRounded == 270) then
		lcd.drawText(northX - offset, minY+1, "S", SMLSIZE)
		lcd.drawText(northX, minY+1, "W", flags)
		lcd.drawText(northX + offset, minY+1, "N", SMLSIZE)
	elseif ( yaw > 0 and yaw < 90) then
		northX = (maxXHalf - 2) - 0.3*yaw
		lcd.drawText(northX, minY+1, "N", flags)
		lcd.drawText(northX + offset, minY+1, "E", SMLSIZE)
		if (yaw > 75) then
			lcd.drawText(northX + offset + offset, minY+1, "S", SMLSIZE)
		end
	elseif ( yaw > 90 and yaw < 180) then
		northX = (maxXHalf - 2) - 0.3*(yaw - 180)
		lcd.drawText(northX - offset, minY+1, "E", SMLSIZE)
		lcd.drawText(northX, minY+1, "S", flags)
		if (yaw > 170) then
			lcd.drawText(northX + offset, minY+1, "W", SMLSIZE)
		end
	elseif ( yaw > 180 and yaw < 270) then
		northX = (maxXHalf - 2) - 0.3*(yaw - 270)
		lcd.drawText(northX, minY+1, "W", SMLSIZE)
		lcd.drawText(northX - offset, minY+1, "S", flags)
		if (yaw < 190) then
			lcd.drawText(northX - offset - offset, minY+1, "E", SMLSIZE)
		end
	elseif ( yaw > 270 and yaw < 360) then
		northX = (maxXHalf - 2) - 0.3*(yaw - 360)
		lcd.drawText(northX, minY+1, "N", SMLSIZE)
		lcd.drawText(northX - offset, minY+1, "W", flags)
		if (yaw < 290) then
			lcd.drawText(northX - offset - offset, minY+1, "S", SMLSIZE)
		end
		if (yaw > 345) then
			lcd.drawText(northX + offset, minY+1, "E", SMLSIZE)
		end
	end
	lcd.drawLine(minX, minY +7, maxX, minY+7, SOLID, 0)
	--
	local xx = 0
	if ( yaw < 10) then
		xx = 3
	elseif (yaw < 100) then
		xx = 0
	else
		xx = -3
	end
	lcd.drawNumber(minX + offset + xx, minY, yaw, MIDSIZE+INVERS) 
end

local function drawHud()
	drawPitch()
	drawRoll()
	drawYaw()
end

local function drawHomeDirection()
	local ox = maxX + 14
	local oy = 41
	local angle = math.floor(homeAngle - yaw)
	if ( math.abs(angle) > 45 and math.abs(angle) < 315) then
		oy = 39
	end
	
	local r1 = 8
	local r2 = 5
	local x1 = ox + r1 * math.cos(math.rad(angle - 90)) 
	local y1 = oy + r1 * math.sin(math.rad(angle - 90))
	local x2 = ox + r2 * math.cos(math.rad(angle - 90 + 120)) 
	local y2 = oy + r2 * math.sin(math.rad(angle - 90 + 120))
	local x3 = ox + r2 * math.cos(math.rad(angle - 90 - 120)) 
	local y3 = oy + r2 * math.sin(math.rad(angle - 90 - 120))
	--
	lcd.drawLine(x1,y1,x2,y2,SOLID,1)
	lcd.drawLine(x1,y1,x3,y3,SOLID,1)
	lcd.drawLine(ox,oy,x2,y2,SOLID,1)
	lcd.drawLine(ox,oy,x3,y3,SOLID,1)
end

local function drawFlightTime()
	lcd.drawText(maxX, 1, "T:", SMLSIZE+INVERS)
	lcd.drawTimer(lcd.getLastRightPos(), 1, flightTime, SMLSIZE+INVERS)
end

local function drawRSSI()
	local rssi = getRSSI()
	lcd.drawText(128, 1, rssi, SMLSIZE+INVERS+RIGHT)
	lcd.drawText(lcd.getLastLeftPos(), 1, "Rssi:", SMLSIZE+INVERS+RIGHT)
end

local function drawTxVoltage()
	txVId=getFieldInfo("tx-voltage").id
	txV = getValue(txVId)*10  

	lcd.drawText(128, 10, "v", SMLSIZE+RIGHT)
	lcd.drawNumber(lcd.getLastLeftPos(), 10, txV, SMLSIZE+PREC1+RIGHT)
	lcd.drawText(lcd.getLastLeftPos(), 10, "Tx:", SMLSIZE+RIGHT)
end
--

local lastStatusArmed = 0
local lastGpsStatus = 0
local lastFlightMode = 0
local lastBattLevel = 0
local batLevel = 99
local batLevels = {}
	batLevels[10]=0
	batLevels[9]=5
	batLevels[8]=10
	batLevels[7]=15
	batLevels[6]=20
	batLevels[5]=25
	batLevels[4]=30
	batLevels[3]=40
	batLevels[2]=50
	batLevels[1]=60
	batLevels[0]=75
	
local function checkSoundEvents()
	if (battCapacity > 0) then
		batLevel = (1 - (battMah/battCapacity))*100
	else
		batLevel = 99
	end

	if batLevel < (batLevels[lastBattLevel] + 1) and lastBattLevel <= 9 then
		playSound("bat"..batLevels[lastBattLevel])
		lastBattLevel = lastBattLevel + 1
	end
	
	if statusArmed == 1 and lastStatusArmed == 0 then
		lastStatusArmed = statusArmed
		playSound("armed")
	elseif statusArmed == 0 and lastStatusArmed == 1 then
		lastStatusArmed = statusArmed
		playSound("disarmed")
	end
	
	if gpsStatus > 2 and lastGpsStatus <= 2 then
		lastGpsStatus = gpsStatus
		playSound("gpsfix")
	elseif gpsStatus <= 2 and lastGpsStatus > 2 then
		lastGpsStatus = gpsStatus
		playSound("gpsnofix")
	end

	if flightMode ~= lastFlightMode then
		lastFlightMode = flightMode
		if flightMode == 1 then
			playSound("stabilize")
		elseif flightMode == 3 then
			playSound("althold")
		elseif flightMode == 4 then
			playSound("auto")
		elseif flightMode == 6 then
			playSound("loiter")
		elseif flightMode == 7 then
			playSound("rtl")
		elseif flightMode == 10 then
			playSound("land")
		elseif flightMode == 16 then
			playSound("autotune")
		elseif flightMode == 17 then
			playSound("poshold")
		end	
	end
end
--------------------------------------------------------------------------------
-- loop FUNCTIONS
--------------------------------------------------------------------------------
local showMessages = false
local showConfig = false
--
local function background()
	processTelemetry()
end
--
local clock = 0
--
local function symMode()
	symAttitude()
	symTimer()
	symHome()
	symGPS()
	symBatt()
end
--
local function run(event) 
	processTelemetry()
	if event == EVT_ENTER_BREAK  then
		showMessages = not showMessages
	end
	--
	if (clock % 8 == 0) then
		calcBattery()
		calcFlightTime()
		checkSoundEvents()		
		clock = 0
	end
	lcd.clear()
	if showMessages then
		processTelemetry()
		drawAllMessages()
	else
		for r=1,3
		do
			processTelemetry()
			lcd.clear()
			symMode()
			drawHud()
			drawGrid()
			drawBattery()
			drawGPSStatus()
			checkLandingStatus()
			drawMessage()
			drawHomeDirection()
			drawHome()
			drawFlightMode()
			drawFailsafe()
			drawFlightTime()
			drawTxVoltage()
			drawRSSI()
		end
	end
	clock = clock + 1
end

local function init()
	pushMessage(6,"Yaapu X7 script v1.0")
end

--------------------------------------------------------------------------------
-- SCRIPT END
--------------------------------------------------------------------------------
return {run=run,  background=background, init=init}