--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "json-safe"
require "filesystem"
require "version"
require "logger"
require "cloud"

local Log = Logger:new('Repo')
Repo = {
    dir_cfg = 'data/repo.json',
    dir = 'data/repositories/',
    loaded = {}
}

---fetch by uuid.
---@param uuid string
---@return integer|nil
local function fetch(uuid)
    for i,res in pairs(Repo.loaded) do
        if res.uuid == uuid then
            return i
        end
    end
    return nil
end

---fetch the top repo.
---@return string|nil
local function fetchTop()
    for i,res in pairs(Repo.loaded) do
        if res.enabled then
            return i
        end
    end
    Log:Error('未启用任何仓库!')
    return nil
end

local function url_get_root(url)
    return url:sub(1,url:len()-url:reverse():find('/')+1)
end

function Repo:init()
    Fs:mkdir('data/repositories')
    if not Fs:isExist(self.dir_cfg) then
        Fs:writeTo(self.dir_cfg,JSON:stringify {
            format_version = Version:getNum(1),
            repo = {}
        })
    end
    self.loaded = JSON:parse(Fs:readFrom(self.dir_cfg)).repo
    return self.loaded ~= nil
end

---保存仓库列表
function Repo:save()
    Fs:writeTo(self.dir_cfg,JSON:stringify {
        format_version = Version:getNum(1),
        repo = self.loaded
    })
end

---判断指定仓库是否存在
---@param uuid string
---@return boolean
function Repo:isExist(uuid)
    return fetch(uuid) ~= nil
end

---添加一个仓库
---@param uuid string
---@param name string
---@param metafile string
---@param isEnabled? boolean
---@return boolean
function Repo:add(uuid,name,metafile,isEnabled)
    isEnabled = isEnabled or true
    if self:isExist(uuid) then
        Log:Error('该仓库与现有的某个仓库的UUID冲突，可能重复添加了？')
        return false
    end
    self.loaded[#self.loaded+1] = {
        uuid = uuid,
        name = name,
        metafile = metafile,
        enabled = isEnabled
    }
    self:save()
    Fs:mkdir(self.dir..uuid..'/classes')
    if isEnabled then
        self:update(uuid) 
    end
    return true
end

---开启或关闭指定仓库
---@param uuid string
---@param isEnabled boolean
---@return boolean
function Repo:setStatus(uuid,isEnabled)
    local pos = fetch(uuid)
    if pos then
        self.loaded[pos].enabled = isEnabled
        self:save()
        return true
    end
    Log:Error('正在为一个不存在的仓库 (%s) 设定开关状态。',uuid)
    return false
end

---删除指定仓库
---@param uuid string
---@return boolean
function Repo:remove(uuid)
    local pos = fetch(uuid)
    if pos then
        Fs:rmdir(self.dir..uuid,true)
        table.remove(self.loaded,pos)
        self:save()
        return true
    end
    Log:Error('正在删除一个不存在的仓库 (%s)',uuid)
    return false
end

---获取所有已添加的仓库
---@return table
function Repo:getAll()
    local rtn = {}
    for a,b in pairs(self.loaded) do
        rtn[#rtn+1] = b.uuid
    end
    return rtn
end

---获取指定仓库的名称
---@param uuid string
---@return string|nil
function Repo:getName(uuid)
    local pos = fetch(uuid)
    if pos then
        return self.loaded[pos].name
    end
    Log:Error('正在获取一个不存在的仓库的名称 (%s)',uuid)
    return nil
end

---获取指定仓库自述文件下载链接
---@param uuid string
---@return string|nil
function Repo:getLink(uuid)
    local pos = fetch(uuid)
    if pos then
        return self.loaded[pos].metafile
    end
    Log:Error('正在获取一个不存在的仓库的自述文件链接 (%s)',uuid)
    return nil
end

---获取当前已启用仓库UUID列表
---@return table
function Repo:getAllEnabled()
    local rtn = {}
    for pos,cont in pairs(self.loaded) do
        if cont.enabled then
            rtn[#rtn+1] = cont.uuid
        end
    end
    return rtn
end

---获取优先级最高的仓库的UUID
---@return string
function Repo:getTop()
    return self.loaded[fetchTop()].uuid
end

---获取指定仓库自述文件
---@param uuid string
---@param updateMode? boolean
function Repo:getMeta(uuid,updateMode)
    updateMode = updateMode or false
    local res = ''
    if not Fs:isExist(('%s%s/self.json'):format(self.dir,uuid)) then
        updateMode = true
    end
    if updateMode then
        Cloud:NewTask {
            url = self.loaded[fetch(uuid)].metafile,
            writefunction = function (str)
                res = res .. str
            end
        }
    else
        res = Fs:readFrom(('%s%s/self.json'):format(self.dir,uuid))
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
        Fs:writeTo(('%s%s/self.json'):format(self.dir,uuid),JSON:stringify(obj,true))
    end
    return obj
end

---更新指定仓库软件包列表
---@param uuid string
---@return boolean
function Repo:update(uuid)
    local repo = self.loaded[fetch(uuid)]
    Log:Info('正在更新仓库 %s ...',repo.name)
    Log:Info('正在拉取描述文件...')
    local meta
    local firstUpdate = not Fs:isExist(('%s%s/self.json'):format(self.dir,uuid))
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
                url = ('%s%s%s'):format(url_get_root(self.loaded[fetch(uuid)].metafile),'multi/',cont.resource)
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
        Fs:writeTo(('%s%s/self.json'):format(self.dir,uuid),JSON:stringify(meta))
        return true
    end
    return false
end

---@alias MultiFileType
---|>'"PdbHashTable"'   # PDB-SHA1版本对照表
---| '"SpeedTest"'      # 测速文件

---获取仓库提供的MiltiFile
---@param name MultiFileType
---@param writefunction function
function Repo:getMulti(name,writefunction)
    local load = self.loaded[fetchTop()]
    local meta = self:getMeta(load.uuid)
    if not meta then
        return false
    end
    local item = meta.multi[name]
    if not item.enable then
        Log:Error('当前仓库没有提供 %s。',name)
        return false
    end
    local url = item.file
    if not Cloud:parseLink(item.file) then
        url = ('%s%s%s'):format(url_get_root(load.metafile),'multi/',item.file)
    end
    Cloud:NewTask {
        url = url,
        writefunction = writefunction
    }
    return true
end

return Repo