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
            api = 'https://api-lanzou.amd.rocks/?url=%s&pwd=%s'
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
    local url = ('https://www.lanzouy.com/%s'):format(shareId)
    passwd = passwd or ''
    local L = Logger:new('LanZou')
    L:Info('正在获取下载链接...')
    local res = ''
    Cloud:NewTask {
        url = self.api:format(url,passwd),
        writefunction = function (data)
            res = res .. data
        end,
        quiet = true
    }
    res = JSON.parse(res)
    if not res then
        L:Error('获取下载链接失败，API返回了错误的信息。')
        return
    end
    if res.code ~= 200 then
        L:Error('获取下载链接失败 (%s:%s)',res.code,res.msg)
        return
    end
    L:Info('正在下载: %s',res.name)
    return Cloud:NewTask {
        url = res.downUrl,
        writefunction = payload.writefunction
    }

end

--- HTTP (s) 下载
---@param url string 链接
---@param payload table 请求载荷
function Cloud.Protocol.Http:get(url,payload)
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
    payload.quiet = payload.quiet or false
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
            local prog
            if size ~= 0 then
                prog = math.floor(downloaded/size*100)
            else
                prog = 0
            end
            local formatted = (' %s %.3d%% %s %.2fM/s (%sM/%sM)'):format(Rec.steps[Rec.step],prog,Rec.progress,Rec.average_speed,SizeConv.Byte2Mb(downloaded),SizeConv.Byte2Mb(size))
            local strlen = formatted:len()
            if Rec.max_size < strlen then
                Rec.max_size = strlen
            end
            io.write('\r',formatted,(' '):rep(Rec.max_size - strlen))
        end,
        noprogress = payload.quiet,
        ssl_verifypeer = false,
        ssl_verifyhost = false
    }
    local msf = easy:perform()
    if not payload.quiet then
        io.write(('\r √ 100%% %s %.2fM/s  (%sM).'):format(('━'):rep(blocks),SizeConv.Byte2Mb(msf:getinfo_speed_download()),SizeConv.Byte2Mb(msf:getinfo_size_download()))..(' '):rep(15),'\n')
    end
    easy:close()
    return true
end

return Cloud