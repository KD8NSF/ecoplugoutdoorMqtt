local f,e = loadfile("setup.lua")
if f==nil then
  print("SetupNotFound")
  DeviceName = "DefaultDeviceName"
  mqttBroker = "172.0.0.1"
  mqttUser = "none"
  mqttPass = "none"
  roomID = "1"
end
local ok,e = pcall(f)
if not ok then
  print("error running setup file")
end

-- Pin which the relay is connected to
relayPin = 6
gpio.mode(relayPin, gpio.OUTPUT)
gpio.write(relayPin, gpio.LOW)
 
 
-- Connected to switch with internal pullup enabled
buttonPin = 7
buttonDebounce = 250
gpio.mode(buttonPin, gpio.INPUT, gpio.PULLUP)
 
 
-- MQTT led
mqttLed=4
gpio.mode(mqttLed, gpio.OUTPUT)
gpio.write(mqttLed, gpio.HIGH)

-- MQTT led
powerLed=8
gpio.mode(powerLed, gpio.OUTPUT)
gpio.write(powerLed, gpio.LOW)

-- Default the Relay ON
print("Enabling Output")
gpio.write(relayPin, gpio.HIGH)
gpio.write(powerLed, gpio.HIGH)
 
-- Make a short flash with the led on MQTT activity
function mqttAct()
    if (gpio.read(mqttLed) == 1) then gpio.write(mqttLed, gpio.HIGH) end
    gpio.write(mqttLed, gpio.LOW)
    tmr.alarm(5, 50, 0, function() gpio.write(mqttLed, gpio.HIGH) end)
end
 
m = mqtt.Client("Sonoff-" .. DeviceName, 180, mqttUser, mqttPass)
m:lwt("/lwt", "Sonoff " .. DeviceName, 0, 0)
m:on("offline", function(con)
    ip = wifi.sta.getip()
    print ("MQTT reconnecting to " .. mqttBroker .. " from " .. ip)
    tmr.alarm(1, 10000, 0, function()
        node.restart();
        -- starts a reboot timer
    end)
end)
 
 
-- Pin to toggle the status
buttondebounced = 0
gpio.trig(buttonPin, "down",function (level)
    if (buttondebounced == 0) then
        buttondebounced = 1
        tmr.alarm(6, buttonDebounce, 0, function() buttondebounced = 0; end)
      
        --Change the state
        if (gpio.read(relayPin) == 1) then
            gpio.write(relayPin, gpio.LOW)
            gpio.write(powerLed, gpio.LOW)
            print("Was on, turning off")
        else
            gpio.write(relayPin, gpio.HIGH)
            gpio.write(powerLed, gpio.HIGH)
            print("Was off, turning on")
        end
         
        mqttAct()
        mqtt_update()
    end
end)
 
 
-- Update status to MQTT
function mqtt_update()
    if (gpio.read(relayPin) == 0) then
        m:publish("/home/".. roomID .."/" .. DeviceName .. "/state","OFF",0,0)
    else
        m:publish("/home/".. roomID .."/" .. DeviceName .. "/state","ON",0,0)
    end
end
  
-- On publish message receive event
m:on("message", function(conn, topic, data)
    mqttAct()
    print("Recieved:" .. topic .. ":" .. data)
        if (data=="ON") then
        print("Enabling Output")
        gpio.write(relayPin, gpio.HIGH)
        gpio.write(powerLed, gpio.HIGH)
    elseif (data=="OFF") then
        print("Disabling Output")
        gpio.write(relayPin, gpio.LOW)
        gpio.write(powerLed, gpio.LOW)
    else
        print("Invalid command (" .. data .. ")")
    end
    mqtt_update()
end)
 
 
-- Subscribe to MQTT
function mqtt_sub()
    mqttAct()
    m:subscribe("/home/".. roomID .."/" .. DeviceName,0, function(conn)
        print("MQTT subscribed to /home/".. roomID .."/" .. DeviceName)
    end)
end
 
tmr.alarm(0, 1000, 1, function()
    if wifi.sta.status() == 5 and wifi.sta.getip() ~= nil then  
        tmr.stop(0)
        m:connect(mqttBroker, 1883, 0, 1, function(conn)
            gpio.write(mqttLed, gpio.HIGH)
            tmr.stop(1)
            -- kills reboot timer
            print("MQTT connected to:" .. mqttBroker)
            mqtt_sub() -- run the subscription function
        end,
        function(conn, reason) 
            print("Rebooting - Mqtt failed reason: "..reason) 
            node.restart(); -- reboots on failure to initially connect
        end)
    end
 end)
