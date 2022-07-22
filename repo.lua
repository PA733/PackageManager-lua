--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "json-safe"
require "filesystem"
require "version"
require "logger"
require "cloud"
require "native-type-helper"

local Log = Logger:new('Repo')
Repo = {
    dir_cfg = 'data/repo.json',
    dir = 'data/repositories/',
    loaded = {},
    --- use `self:getPriorityList()` to get me!
    priority = {}
}

function Repo:init()
    Fs:mkdir('data/repositories')
    if not Fs:isExist(self.dir_cfg) then
        Fs:writeTo(self.dir_cfg,JSON:stringify {
            format_version = Version:getNum(2),
            priority = {},
            repos = {}
        })
    end
    self.loaded = JSON:parse(Fs:readFrom(self.dir_cfg)).repos
    return self.loaded ~= nil
end

---保存仓库列表
function Repo:save()
    Fs:writeTo(self.dir_cfg,JSON:stringify({
        format_version = Version:getNum(2),
        priority = self.priority,
        repos = self.loaded
    },true))
end

---判断指定仓库是否存在
---@param uuid string
---@return boolean
function Repo:isExist(uuid)
    return self.loaded[uuid] ~= nil
end

---添加一个仓库
---@param uuid string
---@param metafile string 自述文件下载链接
---@param isEnabled? boolean
---@return boolean
function Repo:add(uuid,metafile,group,isEnabled)
    isEnabled = isEnabled or true
    if self:isExist(uuid) then
        Log:Error('该仓库与现有的某个仓库的UUID冲突，可能重复添加了？')
        return false
    end
    self.loaded[uuid] = {
        using = group,
        metafile = metafile,
        enabled = isEnabled
    }
    self:save()
    if isEnabled then
        self:update(uuid,true)
    end
    return true
end

---开启或关闭指定仓库
---@param uuid string
---@param isEnabled boolean
---@return boolean
function Repo:setStatus(uuid,isEnabled)
    if #self:getAllEnabled() == 1 and not isEnabled then
        Log:Error('无法更新 %s 状态，至少启用一个仓库。')
        return false
    end
    if self:isExist(uuid) then
        self.loaded[uuid].enabled = isEnabled
        self:save()
        Log:Info('仓库 %s 的启用状态已更新为 %s。')
        return true
    end
    Log:Error('正在为一个不存在的仓库 (%s) 设定开关状态。',uuid)
    return false
end

---删除指定仓库
---@param uuid string
---@return boolean
function Repo:remove(uuid)
    if not self:isExist(uuid) then
        Log:Error('正在删除一个不存在的仓库 (%s)',uuid)
        return false
    end
    if #self:getAllEnabled() <= 1 and self:isEnabled(uuid) then
        Log:Error('若要删除 %s, 必须先启用另一个仓库。',self:getName(uuid))
        return false
    end
    Fs:rmdir(self.dir..uuid)
    self.loaded[uuid] = nil
    self:save()
    return true
end

---获取所有已添加的仓库
---@return table
function Repo:getAll()
    local rtn = {}
    for uuid,_ in pairs(self.loaded) do
        rtn[#rtn+1] = uuid
    end
    return rtn
end

---获取指定仓库的名称
---@param uuid string
---@return string|nil
function Repo:getName(uuid)
    if self:isExist(uuid) then
        return self:getMeta(uuid).name
    end
    Log:Error('正在获取一个不存在的仓库的名称 (%s)',uuid)
    return nil
end

---获取指定仓库自述文件下载链接
---@param uuid string
---@return string|nil
function Repo:getLink(uuid)
    if self:isExist(uuid) then
        return self.loaded[uuid].metafile
    end
    Log:Error('正在获取一个不存在的仓库的自述文件链接 (%s)',uuid)
    return nil
end

---获取当前已启用仓库UUID列表
---@return table
function Repo:getAllEnabled()
    local rtn = {}
    for uuid,res in pairs(self.loaded) do
        if res.enabled then
            rtn[#rtn+1] = uuid
        end
    end
    return rtn
end

---仓库是否已启用?
---@param uuid string
---@return boolean
function Repo:isEnabled(uuid)
    if not self:isExist(uuid) then
        return false
    end
    return self.loaded[uuid].enabled
end

---刷新优先级表
function Repo:getPriorityList()
    local added = {}
    local all = self:getAllEnabled()
    added = array.create(#all,0)
    for n,uuid in pairs(all) do
        local ck = array.fetch(self.priority,uuid)
        if ck then
            table.insert(added,ck,uuid)
        else
            table.insert(added,uuid)
        end
    end
    self.priority = {}
    for p,uuid in pairs(added) do
        if uuid and uuid ~= 0 then
            self.priority[#self.priority+1] = uuid
        end
    end
    self:save()
    return self.priority
end

---设定仓库优先级
---@param uuid string
---@param isDown? boolean
---@return boolean
function Repo:movePriority(uuid,isDown)
    if not self:isEnabled(uuid) then
        return false
    end
    array.remove(self.priority,uuid)
    if not isDown then
        table.insert(self.priority,1,uuid)
    else
        table.insert(self.priority,uuid)
    end
    return true
end

---获取指定仓库优先级
---@param uuid string
---@return integer|nil
function Repo:getPriority(uuid)
    if not self:isExist(uuid) then
        Log:Error('正在获取一个不存在的仓库的优先级 (%s)',uuid)
        return nil
    end
    for p,_uuid in pairs(self:getPriorityList()) do
        if _uuid == uuid then
            return p
        end
    end
end

---获取指定仓库自述文件
---@param uuid string
---@param updateMode? boolean
function Repo:getMeta(uuid,updateMode)
    if not self:isExist(uuid) then
        Log:Error('正在获取不存在仓库的自述文件 (%s)',uuid)
        return nil
    end
    updateMode = updateMode or false
    local res = ''
    if not Fs:isExist(('%s%s.repo'):format(self.dir,uuid)) then
        updateMode = true
    end
    if updateMode then
        Cloud:NewTask {
            url = self.loaded[uuid].metafile,
            writefunction = function (str)
                res = res .. str
            end
        }
    else
        res = Fs:readFrom(('%s%s.repo'):format(self.dir,uuid))
    end
    local obj = JSON:parse(res)
    if not obj then
        Log:Error('描述文件解析失败。')
        return nil
    end
    if obj.format_version ~= Version:getNum(2) then
        Log:Error('描述文件的版本与管理器不匹配！')
        return nil
    end
    if updateMode then
        Fs:writeTo(('%s%s.repo'):format(self.dir,uuid),JSON:stringify(obj,true))
    end
    return obj
end

---更新指定仓库软件包列表
---@param uuid string
---@return boolean
function Repo:update(uuid,firstUpdate)
    if not firstUpdate then
        firstUpdate = not Fs:isExist(('%s%s.repo'):format(self.dir,uuid))
    end
    local repo = self:getMeta(uuid)
    if not repo then
        return false
    end
    Log:Info('正在更新仓库 %s ...',repo.name)
    Log:Info('正在拉取描述文件...')
    local meta
    if not firstUpdate then
        local old_meta = self:getMeta(uuid)
        meta = self:getMeta(uuid,true)
        if not (old_meta and meta) then
            return false
        end
        if meta.status == 1 then
            Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',meta.name,uuid)
            return false
        end
        if old_meta.updated == meta.updated then
            Log:Info('仓库 %s 已是最新了，无需再更新。',meta.name)
            return true
        end
    else
        meta = self:getMeta(uuid,true)
        if not meta then
            return false
        end
        if meta.status == 1 then
            Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',meta.name,uuid)
            return false
        end
    end
    local hasErr = false
    for n,cont in pairs(meta.root.classes) do
        if cont.broadcast then
            local dbpath = ('%s%s/classes/%s.db'):format(self.dir,uuid,cont.name)
            Log:Info('正在下载分类 %s 数据库...',cont.name)
            local dbfile = Fs:open(dbpath,"wb")
            local url = cont.resource
            if not Cloud:parseLink(cont.resource) then
                url = ('%s%s%s'):format(Fs:getFileAtDir(self.loaded[uuid].metafile),'multi/',cont.resource)
            end
            local res = Cloud:NewTask {
                url = url,
                writefunction = dbfile
            }
            dbfile:close()
            if not res then
                Log:Error('分类 %s 的数据库下载失败！',cont.name)
                hasErr = true
                Fs:remove(dbpath)
            end
        end
    end
    if not hasErr then
        Fs:writeTo(('%s%s.repo'):format(self.dir,uuid),JSON:stringify(meta))
        return true
    end
    return false
end

---@alias MultiFileType
---|>'"PdbHashTable"'   # PDB-SHA1版本对照表
---| '"SpeedTest"'      # 测速文件

---获取仓库提供的MiltiFile的下载链接
---@param name MultiFileType
---@return string|nil
function Repo:getMultiResource(name)
    local uuid = self:getPriorityList()[1]
    local meta = self:getMeta(uuid)
    if not meta then
        return nil
    end
    local item = meta.multi[name]
    if not item.enable then
        Log:Error('当前仓库没有提供 %s。',name)
        return nil
    end
    local url = item.file
    if not Cloud:parseLink(item.file) then
        url = ('%s%s%s'):format(Fs:getFileAtDir(self.loaded[uuid].metafile),'multi/',item.file)
    end
    return url
end

---根据关键词搜索
---@param keyword string
function Repo:search(keyword)
    
end

return Repo