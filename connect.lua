resetwifi = 0
tmr.stop(0)
local f,e = loadfile("setup.lua")
if f==nil then
  print("SetupNotFound")
  DeviceName="DefaultDeviceName"
  SNTPServerDNS="pool.ntp.org"
end
local ok,e = pcall(f)
if not ok then
  print("error running setup file")
end
net.dns.resolve(SNTPServerDNS, function(sk, ip)
    if (ip == nil) then 
        print("DNS fail! - No SNTP lookup") 
        SNTPServer='172.0.0.1'
    else 
        SNTPServer=ip 
        print("SNTP Lookup Good")
    end
end)
wifi.setmode(wifi.STATION, save)

tmr.alarm(1,3000,1,function()

  local ip = wifi.sta.getip()
  if(ip==nil) then
       print("Offline")
       resetwifi = resetwifi + 1
       if(resetwifi==20) then
        print("SetupMode start")
        tmr.stop(1)
        wifi.setmode(wifi.STATIONAP)
        wifi.ap.config({ssid=DeviceName,auth=wifi.AUTH_OPEN})
        print("SetupMode run")
        enduser_setup.manual(true)
        enduser_setup.start(
            function()
                print("Connected to wifi as:" .. wifi.sta.getip())
                print("SetupModedone")
                wifi.setmode(wifi.STATION, save)
                resetwifi = 0
                tmr.start(1)
            end,
            function(err, str)
                print("enduser_setup: Err #" .. err .. ": " .. str)
            end
        );
       end
  else
       resetwifi = 0
       wifi.setmode(wifi.STATION, save)
       print(ip,wifi.sta.getmac())
       sntp.sync(SNTPServer,
        function(sec,usec,server)
         print('sync', sec, usec, server)
        end,
        function()
         print('failed!')
        end)
       math.randomseed( rtctime.get() )
       ip=nil
       tmr.stop(1)
       dofile('mqttmode.lua')
  end
end)
