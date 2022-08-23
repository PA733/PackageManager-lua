--[[ ----------------------------------------

    [Main] Software Manager.

--]] ----------------------------------------

local Log = Logger:new('SoftwareManager')
SoftwareManager = {
    dir = 'data/installed/',
    installed = {},

    Helper = {
        safe_dirs = {
            'plugins/',
            'behavior_packs/',
            'resource_packs/'
        }
    }
}

function SoftwareManager.Helper:isSafeDirectory(tpath)
    if tpath:find('%.%.') then -- check '..'
        return false
    end
    for _, sfpath in pairs(self.safe_dirs) do
        if tpath:sub(0, sfpath:len()) == sfpath then
            return true
        end
    end
    return false
end

function SoftwareManager.Helper:isWhitePackage(uuid)
    return array.fetch(ENV.INSTALLER_WHITELIST, uuid) ~= nil
end

---初始化
---@return boolean
function SoftwareManager:init()
    Fs:mkdir(self.dir)
    Fs:iterator(self.dir, function(nowpath, file)
        local path = nowpath .. file
        if path:sub(path:len() - 7) == '.' .. Software.suffix and Fs:getType(path) == 'file' then
            local m = JSON:parse(Fs:readFrom(path))
            if not m then
                Log:Error('%s 无效软件包信息', path)
            elseif m.format_version ~= Version:getNum(6) then
                Log:Error('%s 不匹配的格式版本')
            else
                self.installed[m.uuid] = m
            end
        end
    end)
    return true
end

---在已安装列表中通过名称检索UUID
---@param name string
---@return string|nil
function SoftwareManager:getUuidByName(name)
    for uuid, pkg in pairs(self.installed) do
        if pkg.name == name then
            return uuid
        end
    end
    return nil
end

---删除软件包
---@param uuid string 软件包唯一ID
---@param purge? boolean 是否删除数据文件
---@return boolean 是否成功删除
---@return boolean 删除过程中是否遇到错误
function SoftwareManager:remove(uuid, purge)
    local pkg = self:getInstalled(uuid)
    if not pkg then
        Log:Error('软件包 %s 未安装，无法卸载。', uuid)
        return false, true
    end
    if purge then
        self:purge(uuid)
    end
    local hasFail = false
    Log:Info('正在删除软件包 %s ...', pkg.name)
    local bds_dir = BDS:getRunningDirectory()
    for n, path in pairs(pkg.paths.installed) do
        Log:Info('(%s/%s) 删除 -> %s', n, #pkg.paths.installed, path)
        if Fs:isExist(bds_dir .. path) and not Fs:remove(bds_dir .. path) then
            Log:Warn('%s 删除失败！', path)
            hasFail = true
        end
    end
    for n, fpath in pairs(pkg.paths.installed) do
        local xpath = Fs:getFileAtDir(fpath)
        local rpath = bds_dir .. xpath
        if Fs:isExist(rpath) then
            if Fs:getFileCount(rpath) ~= 0 then
                if not self.Helper:isSafeDirectory(xpath) and not self.Helper:isWhitePackage(pkg.uuid) then
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
        info = ('软件包 %s 已被成功删除。'):format(pkg.name)
    else
        info = ('软件包 %s 已被成功删除，但还有一些文件/文件夹需要手动处理。'):format(pkg.name)
    end
    Fs:remove(('%s%s.%s'):format(self.dir, pkg.uuid, Software.suffix))
    self.installed[pkg.uuid] = nil
    Log:Info(info)
    return true, not hasFail
end

---删除指定软件的数据文件
---@param uuid string
---@return boolean 是否成功删除
function SoftwareManager:purge(uuid)
    local pkg = self:getInstalled(uuid)
    if not pkg then
        Log:Error('软件包 %s 未安装，无法删除数据文件。', uuid)
        return false
    end
    Log:Info('正在清除数据 %s ...', pkg.name)
    local bds_dir = BDS:getRunningDirectory()
    for n, xpath in pairs(pkg.paths.data) do
        Log:Info('(%s/%s) 删除 -> %s', n, #pkg.paths.data, xpath)
        Fs:rmdir(bds_dir .. xpath .. '/')
    end
    return true
end

---获取已安装软件列表(uuid)
function SoftwareManager:getAll()
    local rtn = {}
    for uuid, _ in pairs(self.installed) do
        rtn[#rtn + 1] = uuid
    end
    return rtn
end

---根据UUID获取软件信息(从已安装列表)
---@param uuid string
---@return table|nil
function SoftwareManager:get(uuid)
    return self.installed[uuid]
end

---注册安装或升级信息
---@param pkgInfo table
---@param installed table
---@return boolean
function SoftwareManager:registerChanged(pkgInfo,installed)
    local pkg = table.clone(pkgInfo)
    local uuid = pkg.uuid
    pkg.verification = nil
    pkg.paths.installed = installed
    pkg.platform = nil
    pkg.format_version = Version:getNum(6)
    self.installed[uuid] = pkg
    return Fs:writeTo(('%s%s.%s'):format(self.dir, uuid, Software.suffix), JSON:stringify(pkg))
end

return SoftwareManager