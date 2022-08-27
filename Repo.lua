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
---@param netMode? boolean
---@return table|nil
function Repo:getMeta(netMode)
    netMode = netMode or false
    local uuid = self:getUUID()
    local res = ''
    if not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid)) then
        netMode = true
    end
    if netMode then
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
    return obj
end

---获取正在使用的资源组对象
---@return ResourceGroup|nil
function Repo:getUsingGroup()
    return ResourceGroup:fromList(self:getMeta().root.groups,self.using)
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

---获取仓库最近更新的时间戳
---@return integer
function Repo:getLastUpdated()
    return self:getUsingGroup():getLastUpdated()
end

---更新指定仓库软件包列表
---@param firstUpdate? boolean 是否为首次更新
---@return boolean
function Repo:update(firstUpdate)
    local uuid = self:getUUID()
    if not firstUpdate then
        firstUpdate = not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid))
    end
    local meta_new = self:getMeta(true)
    if not meta_new then
        return false
    end
    local name = self:getName()
    Log:Info('正在更新仓库 %s ...',name)
    Log:Info('正在拉取描述文件...')
    local group = self:getUsingGroup()
    if not group then
        Log:Error('获取正在使用的资源组时出现错误！')
        return false
    end
    local net_group = ResourceGroup:fromList(meta_new.root.groups,group:getName())
    if not net_group then
        Log:Error('远端没有本地正在使用的资源组，建议重新添加该仓库。')
        return false
    end
    if meta_new.status == 1 then
        Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',name,uuid)
        return false
    elseif not firstUpdate and self:getLastUpdated() >= net_group:getLastUpdated() then
        Log:Info('仓库 %s 已是最新了，无需再更新。',name)
        return true
    end
    Log:Info('正在开始下载...')
    local hasErr = false
    for n,class in pairs(group.classes) do
        if manager:isLegalName(class.name) and manager:isLegalName(group.name) then
            local path = ('%s/cache/%s_%s_%s.json'):format(manager.dir,uuid,group.name,class.name)
            Log:Info('(%d/%d) 正在下载分类 %s 的软件包列表...',n,#group.classes,class.name)
            local file = Fs:open(path,"wb")
            local url = class.list
            if not Cloud:parseLink(class.list) then
                url = ('%sgroups/%s/%s'):format(Fs:getFileAtDir(self:getLink()),group.name,class.list)
            end
            local res = Cloud:NewTask {
                url = url,
                writefunction = file
            }
            file:close()
            if not res then
                Log:Error('(%d/%d) 分类 %s 的软件包列表下载失败！',n,#group.classes,class.name)
                hasErr = true
                break
            end
        else
            Log:Warn('(%d/%d) 分组 %s 的分类 %s 存在不合法字符，跳过...',n,#group.classes,group.name,class.name)
        end
    end
    if not hasErr then
        Fs:writeTo(('%s%s.repo'):format(manager.dir,uuid),JSON:stringify(meta_new,true))
    end
    return true
end

---获取可用资源组
---@param netMode? boolean
---@return string[]|nil
function Repo:getAvailableGroups(netMode)
    local ver = BDS:getVersion()
    local can_use = {}
    for _,gp in pairs(self:getMeta(netMode).root.groups) do
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
    local item = self:getMeta().multi[name]
    if not item.enable then
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

---@class ResourceGroup
ResourceGroup = {
    name = 'NULL',
    required_game_version = 'NULL',
    classes = {}
}

---从多个group列表中创建资源组对象
---@param list table
---@param name string
---@return ResourceGroup|nil
function ResourceGroup:fromList(list,name)
    for _,group in pairs(list) do
        if group.name == name then
            return self:create(group)
        end
    end
    return nil
end

---从表中创建资源组对象
---@param tab table
---@return ResourceGroup|nil
function ResourceGroup:create(tab)
    if not Version:match(BDS:getVersion(),tab.required_game_version) then
        return nil
    end
    local origin = {}
    setmetatable(origin,self)
    self.__index = self
    origin.name = tab.name
    origin.classes = tab.classes
    return origin
end

---获取资源组名称
---@return string
function ResourceGroup:getName()
    return self.name
end

---通过名称获取资源类信息
---@param name string
---@return table|nil
function ResourceGroup:getClass(name)
    for _,class in pairs(self.classes) do
        if class.name == name then
            return class
        end
    end
    return nil
end

---获取上一次更新时间
---@return integer
function ResourceGroup:getLastUpdated()
    local rtn = 0
    for _,ins in pairs(self.classes) do
        if ins.updated > rtn then
            rtn = ins.updated
        end
    end
    return rtn
end

return Repo