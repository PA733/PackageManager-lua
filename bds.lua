--[[ ----------------------------------------

    [Deps] Bedrock Server.

--]] ----------------------------------------

require "settings"
require "filesystem"
require "logger"

local Log = Logger:new('BDS')
BDS = {
    dir = '',
    version = {}
}

local function check_bds(path)
    return Fs:isExist(path..'/bedrock_server.exe') or Fs:isExist(path..'/bedrock_server_mod.exe')
end

local function search_bds(path)
    local rtn = {}
    local checked_dir = {}
    Fs:iterator(path,function (nowpath,file)
        if checked_dir[nowpath] then
            return
        end
        if check_bds(nowpath) then
            rtn[#rtn+1] = nowpath
        end
        checked_dir[nowpath] = 1
    end)
    return rtn
end

function BDS:init()
    local bdsdir = Settings:get('bds.running_directory')
    if bdsdir == '' or not check_bds(bdsdir) then
        local new_dir = ''
        Log:Warn('你的基岩版专用服务器路径尚未设定或无效，需要立即设定。')
        Log:Info('正在扫描...')
        local bds_list = search_bds('..')
        if #bds_list == 0 then
            bds_list = search_bds(os.getenv('USERPROFILE')..'/Desktop')
        end
        if #bds_list > 0 then
            local isFirstType = true
            while true do
                if not isFirstType then
                    Log:Error('输入错误，请重新输入。')
                end
                isFirstType = false
                Log:Info('找到 %s 个BDS，请选择：',#bds_list)
                Log:Print('[0] -> 手动输入')
                for n,path in pairs(bds_list) do
                    Log:Print('[%s] -> %s',n,path)
                end
                Log:Write('(0-%s) > ',#bds_list)
                local chosed = tonumber(io.read())
                if chosed then
                    if chosed > 0 and chosed < #bds_list then
                        new_dir = bds_list[chosed]
                    end
                    break
                end
            end
        else
            Log:Info('找不到BDS，请手动输入：')
        end
        if new_dir == '' then
            local isFirstType = true
            while true do
                if not isFirstType then
                    Log:Error('无法在您提供的目录下找到BDS，请重试')
                end
                isFirstType = false
                Log:Write('> ')
                local dir = io.read()
                if check_bds(dir) then
                    new_dir = dir
                    break
                end
            end
        end
        Settings:set('bds.running_directory',new_dir)
        Log:Info('设置成功')
    end
end

function BDS:getRunningDirectory()
    return self.dir
end

function BDS:getVersion()
    return self.version
end

return BDS