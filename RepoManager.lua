--[[ ----------------------------------------

    [Main] Repoistroy Manager.

--]] ----------------------------------------

local driver = require "luasql.sqlite3"
local env = driver.sqlite3()
local Log = Logger:new('RepoManager')

---@class RepoManager
RepoManager = {
    dir = 'data/repositories/',
    dir_cfg = 'data/repo.json',
    dir_db = 'data/packages.db',
    loaded = {},
    database = nil,
    --- use `self:getPriorityList()` to get me!
    priority = {}
}

---初始化
---@return boolean
function RepoManager:init()
    Fs:mkdir('data/repositories')
    if not Fs:isExist(self.dir_cfg) then
        Fs:writeTo(self.dir_cfg,JSON:stringify {
            format_version = Version:getNum(2),
            priority = {},
            repos = {}
        })
    end
    self.loaded = JSON:parse(Fs:readFrom(self.dir_cfg)).repos
    self.database = env:connect(self.dir_db)
    return self.loaded ~= nil
end

---反初始化
function RepoManager:uninit()
    self.database:close()
    env:close()
    driver:close()
end

---添加一个仓库
---@param uuid string
---@param metafile string 自述文件下载链接
---@param isEnabled? boolean
---@return Repo
function RepoManager:add(uuid,metafile,group,isEnabled)
    isEnabled = isEnabled or true
    local repo = self:get(uuid)
    if repo then
        Log:Error('该仓库与现有的某个仓库的UUID冲突，可能重复添加了？')
        return repo
    end
    self.loaded[uuid] = {
        using = group,
        metafile = metafile,
        enabled = isEnabled
    }
    repo = self:get(uuid)
    assert(repo)
    self:save()
    if isEnabled then
        repo:update(true)
    end
    return repo
end

---删除仓库
---@param uuid string
---@return boolean
function RepoManager:remove(uuid)
    local repo = self:get(uuid)
    if not repo then
        Log:Error('正在删除不存在的仓库 %s。',uuid)
        return false
    end
    if #self:getAllEnabled() <= 1 then
        Log:Error('若要删除 %s, 必须先启用另一个仓库。',repo:getName())
        return false
    end
    Log:Info('正在清除软件包目录...')
    PkgDB:purge(uuid)
    Fs:rmdir(self.dir..uuid)
    self.loaded[uuid] = nil
    self:save()
    return true
end

---获取仓库对象
---@param uuid string UUID
---@return Repo|nil
function RepoManager:get(uuid)
    local origin = {}
    local data = self.loaded[uuid]
    if not data then
        return nil
    end
    setmetatable(origin,self)
    self.__index = self
    origin.uuid = uuid
    origin.enabled = data.enabled
    origin.metafile = data.metafile
    origin.using = data.using
    return origin
end

---保存仓库
---@param instance? Repo 需要保存的仓库
---@return boolean
function RepoManager:save(instance)
    if instance then
        local uuid = instance:getUUID()
        local m = self.loaded[uuid]
        m.enabled = instance:isEnabled()
        m.metafile = instance:getLink()
        m.using = instance:getUsingGroup().name
    end
    Fs:writeTo(self.dir_cfg,JSON:stringify({
        format_version = Version:getNum(2),
        priority = self.priority,
        repos = self.loaded
    },true))
    return true
end

---刷新并获取优先级表
---@return table
function RepoManager:getPriorityList()
    local added = {}
    local all = self:getAllEnabled()
    added = array.create(#all,0)
    for _,uuid in pairs(all) do
        local ck = array.fetch(self.priority,uuid)
        if ck then
            table.insert(added,ck,uuid)
        else
            table.insert(added,uuid)
        end
    end
    self.priority = {}
    for _,uuid in pairs(added) do
        if uuid and uuid ~= 0 then
            self.priority[#self.priority+1] = uuid
        end
    end
    self:save()
    return self.priority
end

---获取所有已添加的仓库
---@return table
function RepoManager:getAll()
    local rtn = {}
    for uuid,_ in pairs(self.loaded) do
        rtn[#rtn+1] = uuid
    end
    return rtn
end

---获取当前已启用仓库UUID列表
---@return table
function RepoManager:getAllEnabled()
    local rtn = {}
    for uuid,res in pairs(self.loaded) do
        if res.enabled then
            rtn[#rtn+1] = uuid
        end
    end
    return rtn
end

return RepoManager