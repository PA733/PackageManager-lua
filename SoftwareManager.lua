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

---从软件包路径创建包对象
---@param dir string
---@return Package|nil
function SoftwareManager:fromFile(dir)
    Log:Info('正在解析软件包...')
    local stat, unpacked_path = P7zip:extract(dir)
    if not stat then
        Log:Error('解压缩软件包时出现异常。')
        return nil
    end
    for _, n in pairs(Package.root_check_list) do
        if not Fs:isExist(unpacked_path .. n) then
            Log:Error('软件包不合法，缺少 %s。', n)
            return nil
        end
    end
    local pkgInfo = JSON:parse(Fs:readFrom(unpacked_path .. 'self.json'))
    if not pkgInfo then
        Log:Error('读取包信息时出现异常。')
        return nil
    end
    if pkgInfo.format_version ~= Version:getNum(5) then
        Log:Error('软件包自述文件版本不匹配。')
        return nil
    end
    local verification = JSON:parse(Fs:readFrom(unpacked_path .. 'verification.json'))
    if not verification then
        Log:Error('读取校验信息时出现异常。')
        return nil
    end
    local origin = {}
    setmetatable(origin,Package)
    Package.__index = Package
    origin.package_dir = dir
    origin.meta = pkgInfo
    origin.verification = verification
    origin.unpacked_path = unpacked_path
    return origin
end

---使用UUID创建已安装软件对象
---@param uuid string
---@return Software|nil
function SoftwareManager:fromInstalled(uuid)
    if not self.installed[uuid] then
        return nil
    end
    local origin = {}
    setmetatable(origin,Software)
    Software.__index = Software
    origin.uuid = uuid
    origin.meta = self.installed[uuid]
    return origin
end

---获取已安装软件列表(uuid)
function SoftwareManager:getAll()
    local rtn = {}
    for uuid, _ in pairs(self.installed) do
        rtn[#rtn + 1] = uuid
    end
    return rtn
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

---通过UUID获取软件包名称
---@param uuid string
---@return string|nil
function SoftwareManager:getNameByUuid(uuid)
    local pkg = self:fromInstalled(uuid)
    if pkg then
        return pkg:getName()
    end
    local se = RepoManager:search(uuid,false,'uuid',nil,nil,1)
    if se then
        return se[1].name
    end
    return nil
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
    pkg.format_version = Version:getNum(6)
    self.installed[uuid] = pkg
    return Fs:writeTo(('%s%s.%s'):format(self.dir, uuid, Software.suffix), JSON:stringify(pkg))
end

return SoftwareManager