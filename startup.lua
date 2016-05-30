local GPIO0 = 3
local debounceDelay = 50
local DHT11AlarmId    = 0
local debounceAlarmId = 1
local DHT11readFreq = 10000





-- setup I2c and connect display
function init_i2c_display()
    -- SDA and SCL can be assigned freely to available GPIOs
    local sda = 2 -- GPIO14
    local scl = 1 -- GPIO12
    local sla = 0x3c -- 0x3c or 0x3d
    i2c.setup(0, sda, scl, i2c.SLOW)
    disp = u8g.ssd1306_64x48_i2c(sla)
end

-- graphic test components
function prepare()
    disp:setFont(u8g.font_6x10)
    disp:setFontRefHeightExtendedText()
    disp:setDefaultForegroundColor()
    disp:setFontPosTop()
end

function readTemp()
    pin = 4
    status, temp, humi, temp_dec, humi_dec = dht.read(pin)
    if status == dht.OK then
        -- Float firmware using this example
        print("DHT Temperature:"..temp..";".."Humidity:"..humi)
    
    elseif status == dht.ERROR_CHECKSUM then
        print( "DHT Checksum error." )
    elseif status == dht.ERROR_TIMEOUT then
        print( "DHT timed out." )
    end

    return temp, humi
end


function ascii_1()
    local x, y, s
    disp:drawStr(0, 0, "ASCII page 1")
    for y = 0, 5, 1 do
        for x = 0, 15, 1 do
            s = y*16 + x + 32
            disp:drawStr(x*7, y*10+10, string.char(s))
        end
    end
end

function draw(temp, humi)
    prepare()
    disp:drawStr(0, 0, "Temp: "..temp.."C")
    disp:drawStr(0, 24, "Humi: "..humi.."%")
end

function loop()

    disp.sleepOff(disp)
    disp:firstPage()
    temp, humi = readTemp()
    repeat
        draw(temp, humi)
    until disp:nextPage() == false

    -- retrigger timer to give room for system housekeeping
    -- tmr.start(DHT11AlarmId)

end



function pressed()
    -- don't react to any interupts from now on and wait 50ms until the interrupt for the up event is enabled
    -- within that 50ms the switch may bounce to its heart's content
    gpio.trig(GPIO0, "none")
    tmr.alarm(debounceAlarmId, debounceDelay, tmr.ALARM_SINGLE, function()
        if gpio.read(GPIO0) == 1 then
            -- GPIO is currently not pressed. re-arm.....
            gpio.trig(GPIO0, "down", pressed)
        else
            print("Pressed...")
            loop()
            tmr.alarm(debounceAlarmId, DHT11readFreq, tmr.ALARM_SINGLE, function()
                disp.sleepOn(disp)
                gpio.trig(GPIO0, "down", pressed)
            end)
        end
    end)
end



print("--- Temp Monitor ---")
init_i2c_display()
prepare()
loop()

-- setup further reads on the back of button presses
gpio.mode(GPIO0, gpio.INT, gpio.PULLUP)
gpio.trig(GPIO0, "down", pressed)
tmr.alarm(debounceAlarmId, DHT11readFreq, tmr.ALARM_SINGLE, function()
    disp.sleepOn(disp)
    gpio.trig(GPIO0, "down", pressed)
end)
