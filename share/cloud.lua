--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local curl = require "cURL"
local JSON = require "dkjson"
require "logger"

local Log = Logger:new('Cloud')

local SizeConv = {
    Byte2Mb = function (num,saveBit)
        saveBit = saveBit or 2
        return tonumber(string.format('%.'..saveBit..'f', num/1048576))
    end
}

Cloud = {
    Protocol = {
        ['Http'] = {
            prefix = { 'http://', 'https://' }
        },
        ['Lanzou'] = {
            prefix = { 'lanzou://' },
            servers = {
                'lanzoux.com',
                'lanzoui.com',
                'lanzouf.com',
                'lanzous.com'
            }
        },
        ['Ftp'] = {
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

--- 蓝奏云解析下载
---
--- *注意* 只支持单文件解析，目录解析暂不支持
---
---@param shareId string 分享ID，即分享链接末部分=
---@param passwd string 密码（如果有），可以为nil
---@param payload table 请求载荷
---@param callback function 回调函数
function Cloud.Protocol.Lanzou:get(shareId,passwd,payload,callback)

    local Log = Logger:new('Lanzou')
    local function getRedirect(url)
        local redic = curl.easy {
            url = url,
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
        redic:perform()
        local final_link = redic:getinfo_redirect_url()
        local code = redic:getinfo_response_code()
        redic:close()
        return code,final_link
    end

    for tryingNum,link in pairs(self.servers) do

        --- Init.
        Log:Debug('使用域名: %s',link)
        Log:Debug('正在解析分享: %s',shareId)
        local baseUrl = string.format('https://www.%s/',link)
        local url = string.format('%stp/%s',baseUrl,shareId)
        local data = ''

        --- Get lanzou page, get informations.
        local page = curl.easy {
            url = url,
            httpheader = {
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Encoding: gzip, deflate, sdch, br',
                'Accept-Language: zh-CN,zh;q=0.8'
            },
            writefunction = function (str)
                data = data..str
            end,
            useragent = Cloud.UA,
            accept_encoding = 'gzip,deflate',
            ssl_verifypeer = false,
            ssl_verifyhost = false,
            timeout = 15
        }
        page:perform()
        local page_rtncode = page:getinfo_response_code()
        page:close()

        --- Check page(server) status.
        if page_rtncode == 200 then

            if string.find(data,'文件取消分享了') then
                Log:Error('该文件分享链接已失效')
                callback {
                    status = false,
                    code = -1
                }
                return
            end

            if string.find(data,'pwd') then
                if not passwd then
                    Log:Error('提取码错误')
                    callback {
                        status = false,
                        code = -1
                    }
                    return
                end
                --- Get file over passcode.
                local sign = string.match(data,'\'sign\':\'([^\"]*)\',\'p\':pwd')
                if not sign then
                    Log:Error('SIGN获取失败')
                    callback {
                        status = false,
                        code = -1
                    }
                    return
                end
                local form = curl.form()
                form:add_content('action','downprocess')
                form:add_content('sign',sign)
                form:add_content('p',passwd)
                local response = ''
                local ajaxm = curl.easy {
                    url = string.format('https://wwa.%s/ajaxm.php',link),
                    httpheader = {
                        'Referer: '..baseUrl,
                        'Accept-Language:zh-CN,zh;q=0.9'
                    },
                    post = true,
                    httppost = form,
                    writefunction = function (str)
                        response = response..str
                    end,
                    useragent = Cloud.UA,
                    ssl_verifypeer = false,
                    ssl_verifyhost = false,
                    timeout = 15
                }
                ajaxm:perform()
                local ajax_rtncode = ajaxm:getinfo_response_code()
                ajaxm:close()
                form:free()
                if ajax_rtncode ~= 200 then
                    Log:Error('蓝奏云返回异常代码 %s，获取失败。',ajax_rtncode)
                    callback {
                        status = false,
                        code = -1
                    }
                    return
                end
                local rtn_stat,rtn_cont = pcall(JSON.decode,response)
                if rtn_stat and rtn_cont.zt == 1 then
                    local rtnCode,downUrl = getRedirect(string.format('%s/file/%s',rtn_cont.dom,rtn_cont.url))
                    Cloud.Protocol:Fetch(downUrl):get(downUrl,payload,callback)
                else
                    Log:Error('蓝奏云返回了错误的信息，获取失败。')
                    callback {
                        status = false,
                        code = -1
                    }
                    return
                end
                break
            else
                --- Get file direct.
                local downlink,fileId
                local lzReq = pcall(function()
                    --- file_name = string.match(data,'<div class="md">([^\"]*) <span class="mtt">')
                    --- release_date = string.match(data,'<span class="mt2">时间:</span>([^\"]*) <span')
                    --- uploader_name = string.match(data,'<span class="mt2">发布者:</span>([^\"]*) <span')
                    downlink = string.match(data,'href = \'([^\"]*)\' +')
                    assert(downlink)
                    fileId = string.match(data,'var loaddown = \'([^\"]*)\';')
                    fileId = string.match(fileId,'([^\"]*)\';')
                end)
                if not lzReq then
                    Log:Error('解析失败')
                    callback {
                        status = false,
                        code = -1
                    }
                    return
                end
                local redict_rtncode,final_link = getRedirect(downlink..fileId)
                if redict_rtncode ~= 302 then
                    Log:Error('无法访问蓝奏云提供的跳转链接，请检查模块更新。')
                    Log:Error('跳转链接: %s, 错误返回: %s',downlink,redict_rtncode)
                    callback {
                        status = false,
                        code = -1
                    }
                    return
                end
                Cloud.Protocol:Fetch(final_link):get(final_link,payload,callback)
                break
            end
        else
            Log:Warn('正在使用的蓝奏云链接似乎失效...')
            if tryingNum == #self.servers then
                Log:Error('所有蓝奏云服务器都无法访问，请检查模块更新。')
                callback {
                    status = false,
                    code = -1
                }
                return
            end
        end
    end
end

--- HTTP（s）下载
---@param url string 链接
---@param payload string 请求载荷
---@param callback function 回调函数
function Cloud.Protocol.Http:get(url,payload,callback)
    Log:Debug('下载: %s',url)
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
        timeout = 15
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