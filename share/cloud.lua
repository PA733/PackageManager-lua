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
        local data = ''
        local easy = curl.easy {
            url = str,
            writefunction = function (receive)
                data = data..receive
            end,
            progressfunction = function (size,downloaded,uks_1,uks_2)
                local Rec = proInfo
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
                io.write('\r',formatted,string.rep(' ',Rec.max_size - strlen))
            end,
            noprogress = false,
            ssl_verifypeer = false,
            timeout = 60
        }
        local msf = easy:perform()
        io.write(string.format('\r √ Completed, [%s] %sM/s (%sM).',string.rep('▰',20),SizeConv.Byte2Mb(msf:getinfo_speed_download()),SizeConv.Byte2Mb(msf:getinfo_size_download()))..string.rep(' ',8),'\n')
        pcall(completed_callback,{
            status = toBool(msf),
            code = msf:getinfo_response_code(),
            duration = msf:getinfo_total_time(),
            data = data
        })
        easy:close()

    end
}

return Cloud