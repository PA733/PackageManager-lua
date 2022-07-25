--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

local driver = require "luasql.sqlite3"
local env = driver.sqlite3()
local package_db
local Log = Logger:new('Repo')
Repo = {
    dir_cfg = 'data/repo.json',
    dir = 'data/repositories/',
    dir_pkg = 'data/packages.db',
    loaded = {},
    --- use `self:getPriorityList()` to get me!
    priority = {}
}
PkgDB = {}

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
    package_db = env:connect(self.dir_pkg)
    return self.loaded ~= nil
end

function Repo:uninit()
    package_db:close()
    env:close()
    driver:close()
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
    Log:Info('正在清除软件包目录...')
    PkgDB:purge(uuid)
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

---获取正在使用的资源组对象
---@param uuid string
function Repo:getUsingGroup(uuid)
    if self:isExist(uuid) then
        return nil
    end
    local using = self.loaded[uuid].using
    for _,cont in pairs(self:getMeta(uuid).root.groups) do
        if cont.name == using then
            return cont
        end
    end
    return nil
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
        elseif meta.status == 1 then
            Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',meta.name,uuid)
            return false
        end
    end
    local hasErr = false
    local group = self:getUsingGroup(uuid)
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
                url = ('%s%s%s'):format(Fs:getFileAtDir(self.loaded[uuid].metafile),'multi/',cont.resource)
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
        for n,cont in pairs(downloaded) do
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
            Fs:writeTo(('%s%s.repo'):format(self.dir,uuid),JSON:stringify(meta))
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
---@param uuid string
---@param updateMode? boolean
---@return table|nil
function Repo:getAvailableGroups(uuid,updateMode)
    local meta = self:getMeta(uuid,updateMode)
    if not meta then
        return nil
    end
    local ver = BDS:getVersion()
    local can_use = {}
    for _,gp in pairs(meta.root.groups) do
      if ApplicableVersionChecker:check(ver,gp.required_game_version) then
        can_use[#can_use+1] = gp.name
      end
    end
    return can_use
end

---设置资源组
---@param uuid string
---@param name string
function Repo:setGroup(uuid,name)
    if not self:isExist(uuid) then
        return false
    end
    self.loaded[uuid].using = name
    return self:save()
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

function PkgDB:getAll()
    local result = package_db:execute[[
        SELECT name _id FROM sqlite_master WHERE type ='table'
    ]]
    local rtn = {}
    local name = result:fetch()
    while name do
        rtn[#rtn+1] = name
    end
    return rtn
end

---删除数据库中指定repoUUID的Class(Name)
---@param uuid string
---@param class string
function PkgDB:remove(uuid,class)
    return self:removeTbl(('%s__%s'):format(uuid,class))
end

function PkgDB:removeTbl(name)
    return package_db:execute(([[
        DROP TABLE "%s"
    ]]):format(name))
end

---添加一条软件包信息到本地数据库中
---@param repo_uuid string 指定仓库UUID
---@param name string 软件包名
---@param uuid string 软件包UUID
---@param version string 软件包版本
---@param contributors string 贡献者信息
---@param description string 简短解释
---@param selflink string 软件包下载链接
function PkgDB:append(repo_uuid,class,name,uuid,version,contributors,description,selflink)
    package_db:execute(([[	
        CREATE TABLE IF NOT EXISTS "%s__%s"(
            name TEXT NOT NULL,
            uuid TEXT NOT NULL,
            version TEXT NOT NULL,
            contributors TEXT NOT NULL,
            description TEXT NOT NULL,
            download TEXT NOT NULL
        )
    ]]):format(repo_uuid,class))
    package_db:execute(([[
        INSERT INTO "%s" VALUES('%s','%s','%s','%s','%s','%s')
    ]]):format(name,uuid,version,contributors,description,selflink))
end

---获取一个仓库在本地软件包列表中持有的所有表名
---@param uuid string
---@return table
function PkgDB:getAvailableClasses(uuid)
    local rtn = {}
    local result = PkgDB:getAll()
    local n = uuid .. '__'
    for _,name in pairs(result) do
        if name:sub(1,n:len()) == n then
            rtn[#rtn+1] = name
        end
    end
    return rtn
end

---删除一个仓库在本地列表中
---@param uuid string
function PkgDB:purge(uuid)
    local avail = self:getAvailableClasses(uuid)
    for _,name in pairs(avail) do
        self:removeTbl(name)
    end
end

---根据关键词搜索
---@param keyword string
---@return table
function PkgDB:search(keyword,onlyQueryTopRepo,messyMatch,byUUID)
    local rtn = {
        isTop = false,
        data = {}
    }
    local byWhat = 'name'
    if byUUID then
        byWhat = 'uuid'
    end
    local cmd = [[ SELECT * FROM "%s" WHERE %s="%s" ]]
    if messyMatch then
        cmd = [[ SELECT * FROM "%s" WHERE "%s" LIKE "%%%s%%" ]]
    end
    for n,uuid in pairs(Repo:getPriorityList()) do
        local classes = self:getAvailableClasses(uuid)
        for _,class in pairs(classes) do
            local res = package_db:execute(cmd):format(class,byWhat,keyword)
            local name,pk_uuid,version,contributors,description,download = res:fetch()
            while name do
                rtn.data[#rtn.data+1] = {
                    name = name,
                    uuid = pk_uuid,
                    version = version,
                    contributors = contributors,
                    description = description,
                    download = download
                }
                name,pk_uuid,version,contributors,description,download = res:fetch()
            end
        end
        if n == 1 and #rtn.data ~= 0 then --- top repo had result.
            rtn.isTop = true
            return rtn
            --- else query from other repositories.
        elseif onlyQueryTopRepo then
            return rtn
        end
    end
    return rtn
end

return Repo