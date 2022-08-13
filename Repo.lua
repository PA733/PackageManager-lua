--[[ ----------------------------------------

    [Main] Repo Instance.

--]] ----------------------------------------

local driver = require "luasql.sqlite3"
local manager = RepoManager
local env = driver.sqlite3()
local Log = Logger:new('Repo')

---@class Repo
Repo = {}

---获取仓库的UUID
---@return string
function Repo:getUUID()
    return self.uuid
end

---仓库是否已启用?
---@return boolean
function Repo:isEnabled()
    return self.enabled
end

---获取仓库自述文件下载链接
---@return string
function Repo:getLink()
    return self.metafile
end

---获取指定仓库自述文件
---@param updateMode? boolean
---@return table|nil
function Repo:getMeta(updateMode)
    updateMode = updateMode or false
    local uuid = self:getUUID()
    local res = ''
    if not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid)) then
        updateMode = true
    end
    if updateMode then
        Cloud:NewTask {
            url = self:getLink(),
            writefunction = function (str)
                res = res .. str
            end
        }
    else
        res = Fs:readFrom(('%s%s.repo'):format(manager.dir,uuid))
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
        Fs:writeTo(('%s%s.repo'):format(manager.dir,uuid),JSON:stringify(obj,true))
    end
    return obj
end

---获取正在使用的资源组对象
---@return table|nil
function Repo:getUsingGroup()
    local using = self.using
    for _,cont in pairs(self:getMeta().root.groups) do
        if cont.name == using then
            return cont
        end
    end
    return nil
end

---获取指定仓库的名称
---@return string
function Repo:getName()
    return self:getMeta().name
end

---获取指定仓库优先级
---@return integer
function Repo:getPriority()
    local id = self:getUUID()
    for sort,uuid in pairs(manager:getPriorityList()) do
        if uuid == id then
            return sort
        end
    end
    return #manager:getAllEnabled()
end

---设置指定仓库状态
---@param enable boolean 开启或关闭
---@return boolean
function Repo:setStatus(enable)
    if #manager:getAllEnabled() == 1 and not enable then
        Log:Error('无法更新 %s 状态，至少启用一个仓库。')
        return false
    end
    self.enabled = enable
    manager:save(self)
    Log:Info('仓库 %s 的启用状态已更新为 %s。')
    return true
end

---设定仓库优先级
---@param isDown? boolean
---@return boolean
function Repo:movePriority(isDown)
    local uuid = self:getUUID()
    array.remove(manager.priority,uuid)
    if not isDown then
        table.insert(manager.priority,1,uuid)
    else
        table.insert(manager.priority,uuid)
    end
    return true
end

---设置资源组
---@param name string
function Repo:setUsingGroup(name)
    self.using = name
    return manager:save(self)
end

---更新指定仓库软件包列表
---@param firstUpdate boolean 是否为首次更新
---@return boolean
function Repo:update(firstUpdate)
    local uuid = self:getUUID()
    if not firstUpdate then
        firstUpdate = not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid))
    end
    local repo = self:getMeta()
    if not repo then
        return false
    end
    Log:Info('正在更新仓库 %s ...',repo.name)
    Log:Info('正在拉取描述文件...')
    local meta
    if not firstUpdate then
        local old_meta = self:getMeta()
        meta = self:getMeta(true)
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
        meta = self:getMeta(true)
        if not meta then
            return false
        elseif meta.status == 1 then
            Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',meta.name,uuid)
            return false
        end
    end
    local hasErr = false
    local group = self:getUsingGroup()
    if not group then
        Log:Error('获取正在使用的资源组时出现错误！')
        return false
    end
    local downloaded = {}
    Log:Info('正在开始下载...')
    for n,cont in pairs(group.classes) do
        if not cont:match("[%c,%p]") then
            local dbpath = Temp:getFile()
            Log:Info('(%d/%d) 正在下载分类 %s 的数据库...',n,#group.classes,cont.name)
            local dbfile = Fs:open(dbpath,"wb")
            local url = cont.resource
            if not Cloud:parseLink(cont.resource) then
                url = ('%s%s%s'):format(Fs:getFileAtDir(self:getLink()),'multi/',cont.resource)
            end
            local res = Cloud:NewTask {
                url = url,
                writefunction = dbfile
            }
            dbfile:close()
            if not res then
                Log:Error('(%d/%d) 分类 %s 的数据库下载失败！',n,#group.classes,cont.name)
                hasErr = true
                break
            end
            downloaded[#downloaded+1] = {cont.name,dbfile}
        else
            Log:Warn('(%d/%d) 分类 %s 存在不合法字符，跳过...',n,#group.classes,cont.name)
        end
    end
    if not hasErr then
        Log:Info('正在导入数据库...')
        for _,cont in pairs(downloaded) do
            local db = env:connect(cont[2])
            local result = db:execute[[
                SELECT * FROM packages
            ]]
            PkgDB:remove(uuid,cont[1])
            local name,sw_uuid,version,contributors,description,selflink = result:fetch()
            while name do
                PkgDB:append(uuid,cont[1],name,sw_uuid,version,contributors,description,selflink)
                name,sw_uuid,version,contributors,description,selflink = result:fetch()
            end
        end
        if not hasErr then
            Fs:writeTo(('%s%s.repo'):format(manager.dir,uuid),JSON:stringify(meta))
            Log:Info('仓库自述文件已更新。')
            return true
        else
            Log:Error('导入数据库时出错！')
        end
    else
        Log:Error('下载文件时出错!')
    end
    return false
end

---获取可用资源组
---@param updateMode? boolean
---@return table|nil
function Repo:getAvailableGroups(updateMode)
    local ver = BDS:getVersion()
    local can_use = {}
    for _,gp in pairs(self:getMeta(updateMode).root.groups) do
      if ApplicableVersionChecker:check(ver,gp.required_game_version) then
        can_use[#can_use+1] = gp.name
      end
    end
    return can_use
end

---获取仓库提供的MiltiFile的下载链接
---@param name string `PdbHashTable` | `SpeedTest`
---@return string|nil
function Repo:getMultiResource(name)
    local uuid = manager:getPriorityList()[1]
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
        url = ('%s%s%s'):format(Fs:getFileAtDir(self:getLink()),'multi/',item.file)
    end
    return url
end

return Repo