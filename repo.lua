--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "JSON"
require "filesystem"
require "version"
require "logger"
require "cloud"

local Log = Logger:new('Repo')
Repo = {
    loaded = {}
}

local function fetch(uuid)
    for i,res in pairs(Repo.loaded) do
        if res.uuid == uuid then
            return i
        end
    end
    return nil
end

function Repo:init()
    self.loaded = JSON.parse(Fs:readFrom('data/repo.json')).repo
    return true
end

function Repo:save()
    Fs:writeTo('data/repo.json',JSON.stringify {
        format_version = Version:getNum(0),
        repo = self.loaded
    })
end

function Repo:isExist(uuid)
    return fetch(uuid) ~= nil
end

function Repo:add(uuid,name,metafile,isEnabled)
    if self:isExist(uuid) then
        Log:Error('该仓库与现有的某个仓库的UUID冲突，可能重复添加了？')
        return false
    end
    self.loaded[#self.loaded+1] = {
        uuid = uuid,
        name = name,
        metafile = metafile,
        enabled = isEnabled or false
    }
    self:save()
    Fs:mkdir('data/repositories/'..uuid..'/classes')
    return true
end

function Repo:setStatus(uuid,isEnabled)
    local pos = fetch(uuid)
    if pos then
        self.loaded[pos].enabled = isEnabled
        self:save()
        return true
    end
    Log:Error('正在为一个不存在的仓库（%s）设定开关状态。',uuid)
    return false
end

function Repo:remove(uuid)
    local pos = fetch(uuid)
    if pos then
        Fs:rmdir('data/repositories/'..uuid,true)
        table.remove(self.loaded,pos)
        self:save()
        return true
    end
    Log:Error('正在删除一个不存在的仓库（%s）。',uuid)
    return false
end

function Repo:getAll()
    local rtn = {}
    for a,b in pairs(self.loaded) do
        rtn[#rtn+1] = b.uuid
    end
    return rtn
end

function Repo:getName(uuid)
    local pos = fetch(uuid)
    if pos then
        return self.loaded[pos].name
    end
    Log:Error('正在获取一个不存在的仓库的名称（%s）',uuid)
    return nil
end

function Repo:getLink(uuid)
    local pos = fetch(uuid)
    if pos then
        return self.loaded[pos].metafile
    end
    Log:Error('正在获取一个不存在的自述文件链接（%s）',uuid)
    return nil
end

function Repo:getAllEnabled()
    local rtn = {}
    for pos,cont in pairs(self.loaded) do
        if cont.enabled then
            rtn[#rtn+1] = cont.uuid
        end
    end
    return rtn
end

function Repo:update(uuid)
    local repo = fetch(uuid)
    Log:Info('正在更新仓库 %s ...',repo.name)
    Log:Info('正在拉取描述文件...')
    local result,text_result
    result = Cloud:NewTask {
        url = repo.metafile,
        writefunction = function (str)
            text_result = text_result .. str
        end
    }
    if result then
        Log:Error('描述文件下载失败！')
        return false
    end
    local cond = JSON.parse(text_result)
    if not cond then
        Log:Error('描述文件解析失败！')
        return false
    end
    if cond.format_version ~= Version:getNum(1) then
        Log:Error('描述文件的版本与管理器不匹配！')
        return false
    end
end

function Repo:fetchSoftware(uuid,condition)
    
end

return Repo