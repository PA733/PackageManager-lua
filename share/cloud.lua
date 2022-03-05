--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local curl = require "cURL"
require "logger"

local Log = Logger:new('Cloud')
local SizeConv = {
    Byte2Mb = function (num,saveBit)
        saveBit = saveBit or 2
        return tonumber(string.format('%.'..saveBit..'f', num/1048576))
    end
}

Cloud = {
    MakeDownload = function (str,completed_callback)
        local proInfo = {
            recording = {},
            call_times = 0,
            average_speed = 0,
            max_size = 0,
            steps = { '○','◔','◑','◕','●' },
            step = 1,
            progress = string.rep('▱',20),
            size_vaild = false,
            completed = false
        }
        local start_time = os.time()
        local data = ''
        local easy = curl.easy {
            url = str,
            writefunction = function (receive)
                data = data..receive
            end,
            progressfunction = function (size,downloaded,uks_1,uks_2)
                local Rec = proInfo
                if Rec.completed then
                    return
                end
                Rec.call_times = Rec.call_times + 1
                local time = os.time()
                local speed = Rec.average_speed
                if not Rec.recording[time] or (size~=0 and not Rec.size_vaild) then
                    --- calc avg speed.
                    local add_t,add_d = 0,0
                    for i = time-3,time do
                        if Rec.recording[i] and Rec.recording[i-1] then
                            add_t = add_t + 1
                            add_d = add_d + (Rec.recording[i]-Rec.recording[i-1])
                        end
                    end
                    speed = SizeConv.Byte2Mb(add_d/add_t)
                    Rec.average_speed = speed or Rec.average_speed
                    --- calc progress
                    if size ~= 0 then
                        Rec.size_vaild = true
                        Rec.progress = string.gsub(string.rep('▱',20),'▱','▰',math.floor(20*(downloaded/size)))
                    end
                end
                Rec.recording[time] = downloaded
                if Rec.call_times % 10 == 0 then
                    -- next step.
                    Rec.step = Rec.step + 1
                    if Rec.step > #Rec.steps then
                        Rec.step = 1
                    end
                end
                local formatted = string.format(' %s Downloading [%s] %sM/s (%sM/%sM)',Rec.steps[Rec.step],Rec.progress,Rec.average_speed,SizeConv.Byte2Mb(downloaded),SizeConv.Byte2Mb(size))
                local strlen = string.len(formatted)
                if Rec.max_size < strlen then
                    Rec.max_size = strlen
                end
                if size == downloaded and size ~= 0 then
                    Rec.completed = true
                    formatted = string.format(' √ Completed, [%s] %sM/s (%sM).',Rec.progress,Rec.average_speed,SizeConv.Byte2Mb(downloaded))
                end
                io.write('\r',formatted,string.rep(' ',Rec.max_size - strlen))
            end,
            noprogress = false,
            ssl_verifypeer = false
        }
        easy:perform()
        io.write(string.rep(' ',20),'\n')
        easy:close()
        completed_callback{
            duration = os.time() - start_time + 1,
            data = data
        }

    end
}

return Cloud