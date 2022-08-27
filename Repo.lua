--[[ ----------------------------------------

    [Main] Repo Instance.

--]] ----------------------------------------

local manager = RepoManager
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
---@param firstUpdate? boolean 是否为首次更新
---@return boolean
function Repo:update(firstUpdate)
    local uuid = self:getUUID()
    if not firstUpdate then
        firstUpdate = not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid))
    end
    local repo = self:getMeta()
    local repo_new = self:getMeta(true)
    if not (repo and repo_new) then
        return false
    end
    Log:Info('正在更新仓库 %s ...',repo.name)
    Log:Info('正在拉取描述文件...')
    if repo_new.status == 1 then
        Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',repo.name,uuid)
        return false
    elseif not firstUpdate and repo.updated >= repo_new.updated then
        Log:Info('仓库 %s 已是最新了，无需再更新。',repo.name)
        return true
    end
    local group = self:getUsingGroup()
    if not group then
        Log:Error('获取正在使用的资源组时出现错误！')
        return false
    end
    Log:Info('正在开始下载...')
    for n,class in pairs(group.classes) do
        if not (manager:isLegalName(class.name) and manager:isLegalName(group.name)) then
            local path = ('%s/cache/%s_%s_%s.json'):format(manager.dir,uuid,group.name,class.name)
            Log:Info('(%d/%d) 正在下载分类 %s 的软件包列表...',n,#group.classes,class.name)
            local file = Fs:open(path,"wb")
            local url = class.list
            if not Cloud:parseLink(class.list) then
                url = ('%sgroups/%s'):format(Fs:getFileAtDir(self:getLink()),class.list)
            end
            local res = Cloud:NewTask {
                url = url,
                writefunction = file
            }
            file:close()
            if not res then
                Log:Error('(%d/%d) 分类 %s 的软件包列表下载失败！',n,#group.classes,class.name)
                break
            end
        else
            Log:Warn('(%d/%d) 群组 %s 的分类 %s 存在不合法字符，跳过...',n,#group.classes,group.name,class.name)
        end
    end
    return true
end

---获取可用资源组
---@param updateMode? boolean
---@return table|nil
function Repo:getAvailableGroups(updateMode)
    local ver = BDS:getVersion()
    local can_use = {}
    for _,gp in pairs(self:getMeta(updateMode).root.groups) do
      if Version:match(ver,gp.required_game_version) then
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

---清除仓库缓存
---@return boolean
function Repo:purge()
    local prefix = self:getUUID() .. '_'
    return Fs:iterator(manager.dir..'/cache/',function (path,name)
        if name:sub(1,prefix:len()) == prefix then
            Fs:remove(path..name)
        end
    end)
end

---加载/重载缓存的软件包列表
---@return boolean
function Repo:loadPkgs()
    self.pkgs = {}
    local prefix = self:getUUID() .. '_'
    return Fs:iterator(manager.dir..'/cache/',function (path,name)
        if name:sub(1,prefix:len()) ~= prefix then
            return
        end
        local data = JSON:parse(path..name)
        if not (data and data.data) then
            Log:Error('加载 %s 时出错!',name)
            return
        end
        array.concat(self.pkgs,data.data)
    end)
end

---在仓库中执行搜索
---@param pattern string 关键词, 可以是模式匹配字符串
---@param matchBy? string **name** or uuid
---@param version? string 版本匹配表达式
---@param tags? table 要求包含tags列表
---@param limit? number 最大结果数量, 默认无限制
---@return table 结果
function Repo:search(pattern,matchBy,version,tags,limit)
    local rtn = {}
    matchBy = matchBy or 'name'
    version = version or '*'
    tags = tags or {}
    limit = limit or -1
    self:loadPkgs()
    local function matchTags(taggs)
        if #tags == 0 then
            return true
        end
        for _,tag in pairs(tags) do
            if array.fetch(taggs,tag) then
                return true
            end
        end
        return false
    end
    for _,info in pairs(self.pkgs) do
        if matchBy == 'name' then
            if info.name:find(pattern)
                and Version:match(info.version,version)
                and matchTags(info.tags)
            then
                rtn[#rtn+1] = info
            end
        elseif matchBy == 'uuid' then
            if info.uuid == pattern
                and Version:match(info.version,version)
                and matchTags(info.tags)
            then
                rtn[#rtn+1] = info
            end
        else
            Log:Error('未知的匹配方式 %s !',matchBy)
            break
        end
        if limit > 0 and #rtn >= limit then
            break
        end
    end
    return rtn
end

return Repo