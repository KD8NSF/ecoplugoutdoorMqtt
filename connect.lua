resetwifi = 0
tmr.stop(0)

tmr.alarm(1,3000,1,function()

  local ip = wifi.sta.getip()
  if(ip==nil) then
       print("Offline")
       resetwifi = resetwifi + 1
       if(resetwifi==20) then
        print("SetupMode start")
        tmr.stop(1)
        wifi.setmode(wifi.STATIONAP)
        wifi.ap.config({ssid="IgnoredByFW",auth=wifi.AUTH_OPEN})
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
       print(ip,wifi.sta.getmac())
	   -- dont forget to set your local/refered SNTP Server below thats why this line is so long so people dont skip it
       sntp.sync('PICKYOUROWNSNTPSEVER',
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
