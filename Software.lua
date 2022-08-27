--[[ ----------------------------------------

    [Main] Software Instance.

--]] ----------------------------------------

---@class Software
Software = {
    suffix = 'package',

    uuid = 'NULL',
    meta = {}

}
local Log = Logger:new('Software')
local manager = SoftwareManager

---获取软件包UUID
---@return string
function Software:getUUID()
    return self.uuid
end

---获取软件包名称
---@return string
function Software:getName()
    return self.meta.name
end

---获取软件包版本
---@return string
function Software:getVersion()
    return self.meta.version
end

---获取贡献者列表
---@return table
function Software:getContributors()
    return self.meta.contributors:split(',')
end

---获取标签列表
---@return table
function Software:getTags()
    return self.meta.tags
end

---获取依赖信息
---@param ntree NodeTree
---@param list table
---@return table
function Software:getDependents(ntree,list)
    local rtn = {
        node_tree = ntree or NodeTree:create(self:getName()),
        list = list or {}
    }
    local depends = self.meta.depends
    for _,info in pairs(depends) do
        local sw = manager:fromInstalled(info.uuid)
        if sw then
            rtn.node_tree:branch(sw:getName()):setNote('已安装')
        else
            local res = manager:search(info.uuid,false,true)
            if #res.data == 0 then
                rtn.node_tree:branch(info.uuid):setNote('未找到')
            else
                rtn.list[#rtn.list+1] = res.data[1]
                rtn.node_tree:branch(res.data[1].name)
            end
        end
    end
    return rtn
end

---获取冲突表
---@return table
function Software:getConflict()
    return self.meta.conflict
end

---获取数据路径
---@return table
function Software:getDataPaths()
    return self.meta.paths.data or {}
end

---获取已安装文件路径
---@return table
function Software:getInstalledPaths()
    return self.meta.paths.installed or {}
end

---获取主页地址
---@return string
function Software:getHomepage()
    return self.meta.homepage
end

---获取简介
---@return string
function Software:buildDescription()
    return ('软件包: %s\n版本: %s\n贡献者: %s\n主页: %s\n标签: %s\n介绍: %s').format(
        self:getName(),
        self:getVersion(),
        table.concat(self:getContributors(),','),
        self:getHomepage(),
        table.concat(self:getTags(),','),
        table.concat(self.meta.description,'\n')
    )
end

---删除软件包
---@param purge? boolean 是否删除数据文件
---@return boolean 是否成功删除
---@return boolean 删除过程中是否遇到错误
function Software:remove(purge)
    if purge then
        self:purge()
    end
    local hasFail = false
    local name = self:getName()
    local uuid = self:getUUID()
    Log:Info('正在删除软件包 %s ...', name)
    local bds_dir = BDS:getRunningDirectory()
    local installed_paths = self:getInstalledPaths()
    for n, path in pairs(installed_paths) do
        Log:Info('(%s/%s) 删除 -> %s', n, #installed_paths, path)
        if Fs:isExist(bds_dir .. path) and not Fs:remove(bds_dir .. path) then
            Log:Warn('%s 删除失败！', path)
            hasFail = true
        end
    end
    for n, fpath in pairs(installed_paths) do
        local xpath = Fs:getFileAtDir(fpath)
        local rpath = bds_dir .. xpath
        if Fs:isExist(rpath) then
            if Fs:getFileCount(rpath) ~= 0 then
                if not manager.Helper:isSafeDirectory(xpath) and not manager.Helper:isWhitePackage(uuid) then
                    Log:Warn('%s 不是空目录，跳过清除...', xpath)
                    hasFail = true
                end
            else
                Fs:rmdir(bds_dir .. xpath)
            end
        end
    end
    local info
    if not hasFail then
        info = ('软件包 %s 已被成功删除。'):format(name)
    else
        info = ('软件包 %s 已被成功删除，但还有一些文件/文件夹需要手动处理。'):format(name)
    end
    Fs:remove(('%s%s.%s'):format(manager.dir, uuid, Software.suffix))
    manager.installed[uuid] = nil
    Log:Info(info)
    return true, not hasFail
end

---删除指定软件的数据文件
---@return boolean 是否成功删除
function Software:purge()
    Log:Info('正在清除数据 %s ...', self:getName())
    local bds_dir = BDS:getRunningDirectory()
    local data_paths = self:getDataPaths()
    for n, xpath in pairs(data_paths) do
        Log:Info('(%s/%s) 删除 -> %s', n, #data_paths, xpath)
        Fs:rmdir(bds_dir .. xpath .. '/')
    end
    return true
end