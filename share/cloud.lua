--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local curl = require "cURL"

require "json-safe"
require "logger"
require "native-type-helper"

local Log = Logger:new('Cloud')

local SizeConv = {
    Byte2Mb = function (num,saveBit)
        saveBit = saveBit or 2
        return tonumber(('%.'..saveBit..'f'):format(num/1048576))
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
                'lanzoui.com',
                'lanzouj.com',
                'lanzoul.com',
                'lanzoup.com',
                'lanzouq.com',
                'lanzout.com',
                'lanzouv.com',
                'lanzouw.com',
                'lanzoux.com',
                'lanzouy.com',
            }
        }
        --- ['Ftp'] = {
        ---     prefix = { 'ftp://' }
        --- }
    },
    UA = "Mozilla/5.0 (Linux; Android 4.4.2; Nexus 4 Build/KOT49H) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.114 Mobile Safari/537.36"
}

---解析链接, 返回protocol名称
---@param url string 链接
---@return string|nil
function Cloud:parseLink(url)
    for name,protoObj in pairs(Cloud.Protocol) do
        if type(protoObj) == 'table' then
            for n,prefix in pairs(protoObj.prefix) do
                if url:sub(1,prefix:len()) == prefix then
                    return name
                end
            end
        end
    end
    return nil
end

---获取所有支持的协议
---@return table
function Cloud:getAllProtocol()
    local rtn = {}
    for k,v in pairs(self.Protocol) do
        if type(v) == 'table' then
            rtn[#rtn+1] = k
        end
    end
    return rtn
end

--- 创建新任务
---
--- **HTTP** `https://hengaaaa.ugly/114.zip`
---
--- **LANZOU** `lanzou://tiansuohao2:pwd=humo`
---
---@param dict table 需提供 url, writefunction, 可选 ua, header。
---@return any
function Cloud:NewTask(dict)
    local name = self:parseLink(dict.url)
    if not name then
        Log:Error('正在解析无法识别的URL：%s',dict.url)
        return false
    end
    local protocol = self.Protocol[name]
    if dict.payload then
        for k,v in pairs(dict.payload) do
            dict.k = v
        end
        dict.payload = nil
    end
    if name == 'Http' then
        return protocol:get(dict.url,dict)
    elseif name == 'Lanzou' then
        local tmp = dict.url:split(':')
        local shareId = tmp[2]:sub(3)
        if shareId:sub(-1) == '/' then
            shareId = shareId:sub(1,shareId:len()-1)
        end
        local passwd
        if tmp[3] then
            passwd = tmp[3]:split('=')
            if passwd then passwd = passwd[2] end 
        end
        return protocol:get(shareId,passwd,dict)
    end
end

--- 蓝奏云解析下载
---
--- *注意* 只支持单文件解析，目录解析暂不支持
---
---@param shareId string 分享ID, 即分享链接末部分
---@param passwd? string 密码(如果有), 可以为nil
---@param payload table 请求载荷
function Cloud.Protocol.Lanzou:get(shareId,passwd,payload)
    local L = Logger:new('Lanzou')
    local function getRedirect(url)
        local redic = curl.easy {
            url = url,
            httpheader = {
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
                'Cache-Control: no-cache',
                'Connection: keep-alive',
                'Pragma: no-cache',
                'Upgrade-Insecure-Requests: 1'
            },
            accept_encoding = 'gzip, deflate, br',
            ssl_verifypeer = false,
            ssl_verifyhost = false
        }
        redic:perform()
        local final_link = redic:getinfo_redirect_url()
        local code = redic:getinfo_response_code()
        redic:close()
        return code,final_link
    end

    for tryingNum,link in pairs(self.servers) do

        --- Init.
        local baseUrl = ('https://www.%s/tp/'):format(link)
        local url = ('%s%s'):format(baseUrl,shareId)
        local data = ''

        --- Get lanzou page, get informations.
        local page = curl.easy {
            url = url,
            httpheader = {
                'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
                'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6'
            },
            writefunction = function (str)
                data = data..str
            end,
            useragent = Cloud.UA,
            accept_encoding = 'gzip, deflate, br',
            ssl_verifypeer = false,
            ssl_verifyhost = false,
            timeout = 15
        }
        page:perform()
        local page_rtncode = page:getinfo_response_code()
        page:close()
        --- Check page(server) status.
        if page_rtncode == 200 then

            if data:find('文件取消分享了') then
                L:Error('该文件分享链接已失效')
                return false
            end

            if data:find('pwd') then
                if not passwd then
                    L:Error('提取码错误')
                    return false
                end
                --- Get file over passcode.
                local sign = data:match('action=downprocess&sign=([^\"]*)&p=')
                if not sign then
                    L:Error('Sign获取失败')
                    return false
                end
                local form = curl.form()
                form:add_content('action','downprocess')
                form:add_content('sign',sign)
                form:add_content('p',passwd)
                local response = ''
                local ajaxm = curl.easy {
                    url = ('%sajaxm.php'):format(baseUrl),
                    httpheader = {
                        'Accept: application/json, text/javascript, */*',
                        'Accept-Language: zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
                        ('Referer: %s%s'):format(baseUrl,shareId),
                        'X-Requested-With: XMLHttpRequest'

                    },
                    accept_encoding = 'gzip, deflate, br',
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
                    L:Error('蓝奏云返回异常代码 %s，获取失败。',ajax_rtncode)
                    return false
                end
                local rtn = JSON.parse(response)
                if rtn and rtn.zt == 1 then
                    local _,downUrl = getRedirect(('%s/file/%s'):format(rtn.dom,rtn.url))
                    print(downUrl)
                    
                    return Cloud:NewTask {
                        url = downUrl,
                        payload = payload
                    }
                else
                    L:Error('蓝奏云返回了错误的信息，获取失败。')
                    return false
                end
                break
            else
                --- Get file download link.
                local downlink,fileId
                local lzReq = pcall(function()
                    data = data:gsub('\n',''):gsub(' ','')
                    -- print(data)
                    downlink = data:match(";varpototo='([^\"]*)';varspototo")
                    fileId = data:match(";varspototo='([^\"]*)';//vardomianload")
                    assert(downlink and fileId)
                end)
                if not lzReq then
                    L:Error('解析失败，请检查模块更新。')
                    return false
                end
                local redict_rtncode,final_link = getRedirect(downlink..fileId)
                if redict_rtncode ~= 302 then
                    L:Error('无法访问蓝奏云提供的跳转链接，请检查模块更新。')
                    L:Error('跳转链接: %s, 错误返回: %s',downlink,redict_rtncode)
                    return false
                end
                return Cloud:NewTask {
                    url = final_link,
                    payload = payload
                }
            end
        else
            L:Warn('%s 似乎失效...',link)
            if tryingNum == #self.servers then
                L:Error('所有蓝奏云服务器都无法访问，请检查模块更新。')
                return false
            end
        end
    end
end

--- HTTP (s) 下载
---@param url string 链接
---@param payload table 请求载荷
function Cloud.Protocol.Http:get(url,payload)
    -- Log:Debug('下载: %s',url)
    local blocks = 40
    local proInfo = {
        recording = {},
        call_times = 0,
        average_speed = 0,
        max_size = 0,
        steps = { '○','◔','◑','◕','●' },
        step = 1,
        progress = ('━'):rep(blocks),
        size_vaild = false,
        completed = false
    }
    payload.ua = payload.ua or Cloud.UA
    local easy = curl.easy {
        url = url,
        httpheader = payload.header,
        useragent = payload.ua,
        accept_encoding = 'gzip, deflate, br',
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
                    Rec.progress = ('—'):rep(blocks):gsub('—','━',math.floor(blocks*(downloaded/size)))
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
            local formatted = (' %s Downloading %s %sM/s (%sM/%sM)'):format(Rec.steps[Rec.step],Rec.progress,Rec.average_speed,SizeConv.Byte2Mb(downloaded),SizeConv.Byte2Mb(size))
            local strlen = formatted:len()
            if Rec.max_size < strlen then
                Rec.max_size = strlen
            end
            --io.write('\r',formatted,(' '):rep(Rec.max_size - strlen))
        end,
        noprogress = false,
        ssl_verifypeer = false,
        ssl_verifyhost = false,
        timeout = 15
    }
    local msf = easy:perform()
    --io.write(('\r √ Completed, %s %sM/s (%sM).'):format(('━'):rep(blocks),SizeConv.Byte2Mb(msf:getinfo_speed_download()),SizeConv.Byte2Mb(msf:getinfo_size_download()))..(' '):rep(8),'\n')
    easy:close()
    return true
end

return Cloud