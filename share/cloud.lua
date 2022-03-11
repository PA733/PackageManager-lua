--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local curl = require "cURL"
require "logger"

local SizeConv = {
    Byte2Mb = function (num,saveBit)
        saveBit = saveBit or 2
        return tonumber(string.format('%.'..saveBit..'f', num/1048576))
    end
}

local id_count = 0
function PtoId()
    id_count = id_count + 1
    return id_count
end

Cloud = {
    Protocol = {
        ['Http'] = {
            id = PtoId(),
            prefix = { 'http://', 'https://' }
        },
        ['Lanzou'] = {
            id = PtoId(),
            prefix = { 'lanzou://' }
        },
        ['Ftp'] = {
            id = PtoId(),
            prefix = { 'ftp://' }
        }
    },
    UA = "Mozilla/5.0 (Linux; Android 8.0; Pixel 2 Build/OPD3.170816.012) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.51 Mobile Safari/537.36 Edg/99.0.1150.30"
}


--- 选择合适的下载协议
---@param url string
function Cloud.Protocol:Fetch(url)
    for key,value in pairs(self) do
        if type(value) == 'table' then
            for n,prefix in pairs(value.prefix) do
                if string.sub(url,1,string.len(prefix)) == prefix then
                    return value
                end
            end
        end
    end
    return nil
end

local LzLog = Logger:new('Lanzou')

--- 蓝奏云解析下载
---@param shareId string 分享ID，即分享链接末部分
---@param subdomain string 自定义子域名（如果有），可以为nil
---@param passwd string 密码（如果有），可以为nil
---@param payload table 请求载荷
---@param callback function 回调函数
function Cloud.Protocol.Lanzou:get(shareId,subdomain,passwd,payload,callback)
    subdomain = subdomain or 'www'
    local links = {
        "lanzoux.com",
        "lanzoui.com",
        "lanzous.com"
    }
    for n,link in pairs(links) do
        LzLog:Debug('使用域名: %s',link)
        LzLog:Debug('正在解析分享: %s',shareId)
        local url = string.format('https://%s.%s/tp/%s',subdomain,link,shareId)
        local data = ''
        local page = curl.easy {
            url = url,
            httpheader = {
                "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
                "Accept-Encoding: gzip, deflate, sdch, br",
                "Accept-Language: zh-CN,zh;q=0.8"
            },
            writefunction = function (str)
                data = data..str
            end,
            useragent = Cloud.UA,
            accept_encoding = 'gzip,deflate',
            ssl_verifypeer = false,
            ssl_verifyhost = false,
            timeout = 5
        }
        page:perform()
        page:close()
        if string.find(data,'文件取消分享了') then
            LzLog:Error('该文件分享链接已失效')
            callback {
                status = false,
                code = -1001
            }
            return
        end
        local file_name,release_date,uploader_name,downlink,fileId
        local lzReq = pcall(function()
            file_name = string.match(data,'<div class="md">([^\"]*) <span class="mtt">')
            release_date = string.match(data,'<span class="mt2">时间:</span>([^\"]*) <span')
            uploader_name = string.match(data,'<span class="mt2">发布者:</span>([^\"]*) <span')
            downlink = string.match(data,'href = \'([^\"]*)\' +')
            fileId = string.match(data,'var loaddown = \'([^\"]*)\';')
            fileId = string.match(fileId,'([^\"]*)\';')
        end)
        if not lzReq then
            LzLog:Error('解析失败')
            callback {
                status = false,
                code = -1002
            }
            return
        end
        LzLog:Debug('文件名: %s',file_name)
        LzLog:Debug('发布日期: %s',release_date)
        LzLog:Debug('上传者: %s',uploader_name)
        LzLog:Debug('跳转链接: %s',downlink)
        LzLog:Debug('下载ID: %s',fileId)
        local redirect = curl.easy {
            url = downlink..fileId,
            httpheader = {
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
                'Accept-Encoding: gzip, deflate',
                'Accept-Language: zh-CN,zh;q=0.9',
                'Cache-Control: no-cache',
                'Connection: keep-alive',
                'Pragma: no-cache',
                'Upgrade-Insecure-Requests: 1'
            },
            ssl_verifypeer = false
        }
        redirect:perform()
        local final_link = redirect:getinfo_redirect_url()
        LzLog:Debug('下载链接: %s',final_link)
        redirect:close()
        self:HttpGet(final_link,payload,callback)
        break
    end
end

--- HTTP（s）下载
---@param url string 链接
---@param payload string 请求载荷
---@param callback function 回调函数
function Cloud.Protocol.Http:get(url,payload,callback)
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
    payload.ua = payload.ua or Cloud.UA
    payload.accept_encoding = payload.accept_encoding or "gzip,deflate"
    local easy = curl.easy {
        url = url,
        httpheader = payload.header,
        useragent = payload.ua,
        accept_encoding = payload.accept_encoding,
        writefunction = payload.writefunction,
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
        ssl_verifyhost = false,
        timeout = 60
    }
    local msf = easy:perform()
    io.write(string.format('\r √ Completed, [%s] %sM/s (%sM).',string.rep('▰',20),SizeConv.Byte2Mb(msf:getinfo_speed_download()),SizeConv.Byte2Mb(msf:getinfo_size_download()))..string.rep(' ',8),'\n')
    callback {
        status = toBool(msf),
        code = msf:getinfo_response_code(),
        duration = msf:getinfo_total_time()
    }
    easy:close()

end

function Cloud.Protocol.Ftp:get()
    -- TODO.
end

return Cloud