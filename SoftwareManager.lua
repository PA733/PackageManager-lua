--[[ ----------------------------------------

    [Main] Software Manager.

--]] ----------------------------------------

local Log = Logger:new('SoftwareManager')
SoftwareManager = {
    dir = 'data/installed/',
    installed = {}
}

local function is_safe_dir(tpath)
    if tpath:find('%.%.') then -- check '..'
        return false
    end
    for _, sfpath in pairs(ENV.INSTALLER_SAFE_DIRS) do
        if tpath:sub(0, sfpath:len()) == sfpath then
            return true
        end
    end
    return false
end

local function is_in_whitelist(uuid)
    return array.fetch(ENV.INSTALLER_WHITELIST, uuid) ~= nil
end

function SoftwareManager:init()
    Fs:mkdir(self.dir)
    Fs:iterator(self.dir, function(nowpath, file)
        local path = nowpath .. file
        if path:sub(path:len() - 7) == '.' .. ENV.INSTALLED_PACKAGE and Fs:getType(path) == 'file' then
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

---提供软件包路径，解析软件包
---@param lpkdir string
---@return string|nil 解析后所在的临时路径
---@return table|nil PkgInfo
function SoftwareManager:parse(lpkdir)
    Log:Info('正在解析软件包...')
    local stat, path = P7zip:extract(lpkdir)
    if not stat then
        Log:Error('解压缩软件包时出现异常。')
        return
    end
    for _, n in pairs(ENV.INSTALLER_PACKAGE_CHECK_LIST) do
        if not Fs:isExist(path .. n) then
            Log:Error('不合法的包，缺少 %s。', n)
            return
        end
    end
    local pkgInfo = JSON:parse(Fs:readFrom(path .. 'self.json'))
    if not pkgInfo then
        Log:Error('读取包信息时出现异常。')
        return
    end
    if pkgInfo.format_version ~= Version:getNum(5) then
        Log:Error('软件包自述文件版本不匹配。')
        return
    end
    return path, pkgInfo
end

---验证软件包完整/合法性
---@param path string 存放软件包的临时路径
---@param pkgInfo table object from `self.json`
---@param updateMode boolean? 升级模式，跳过部分检查
---@return boolean 是否完整且合法
function SoftwareManager:verify(path, pkgInfo, updateMode)
    Log:Info('正在校验包...')
    if not updateMode and self:getInstalled(pkgInfo.uuid) then
        Log:Error('软件包已安装过，安全检查失败。')
    end
    if not updateMode and self:getUuidByName(pkgInfo.name) then
        Log:Error('软件包与已安装软件有重名，安全检查失败。')
        return false
    end
    if not ApplicableVersionChecker:check(BDS:getVersion(), pkgInfo.applicable_game_version) then
        Log:Error('软件包与当前服务端版本不适配，安全检查失败。')
        return false
    end
    local stopAndFailed = false
    local allow_unsafe = Settings:get('installer.allow_unsafe_directory') or is_in_whitelist(pkgInfo.uuid)
    Fs:iterator(path .. 'content/', function(nowpath, file)
        if stopAndFailed then
            return
        end
        local ori_path = nowpath .. file
        local vpath = ori_path:sub((path .. 'content/'):len() + 1)
        if not allow_unsafe and not is_safe_dir(vpath) then
            Log:Error('软件包尝试将文件安装到到不安全目录，安全检查失败。')
            stopAndFailed = true
            return
        end
        for _, dpath in pairs(pkgInfo.paths.data) do
            if not allow_unsafe and not is_safe_dir(dpath) then
                Log:Error('软件包数据文件可能存放在不安全的目录，安全检查失败。')
                stopAndFailed = true
                return
            end
        end
        local sha1 = pkgInfo.verification[vpath]
        local statu, pkg_file_sha1 = SHA1:file(ori_path)
        if not (sha1 and statu) or pkg_file_sha1 ~= sha1 then
            Log:Error('软件包校验失败。')
            stopAndFailed = true
            return
        end
    end)
    return not stopAndFailed
end

---安装lpk软件包
---@param lpkdir string 软件包路径
---@param noask? boolean
---@return boolean
function SoftwareManager:install(lpkdir, noask)
    noask = noask or false
    local path, pkgInfo = self:parse(lpkdir)
    if not (path and pkgInfo) then
        return false
    end
    if self:getInstalled(pkgInfo.uuid) then
        Log:Error('软件包 %s 已安装，不可以重复安装。', pkgInfo.uuid)
        return false
    end
    if not self:verify(path, pkgInfo) then
        return false
    end
    Log:Error('正在处理依赖关系...')
    if not self:handleDependents(pkgInfo) then
        return false
    end
    Log:Info('%s (%s) - %s', pkgInfo.name, pkgInfo.version, pkgInfo.contributors)
    if not noask then
        io.write(('是否安装 %s (y/N)? '):format(pkgInfo.name))
        local chosed = io.read():lower()
        if chosed ~= 'y' then
            return false
        end
    end
    local all_count = Fs:getFileCount(path .. 'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    local bds_dir = BDS:getRunningDirectory()
    if pkgInfo.uuid == 'be3bf7fe-360a-46b2-b6e3-6cf7151f641b' then
        bds_dir = './'
    end
    Fs:iterator(path .. 'content/', function(nowpath, file)
        local ori_path_file = nowpath .. file
        local inst_path_file = bds_dir .. ori_path_file:sub((path .. 'content/'):len() + 1)
        local inst_path = Fs:getFileAtDir(inst_path_file)
        local relative_inst_path_file = inst_path_file:gsub(bds_dir, '')
        if not mkdired[inst_path] and (not Fs:isExist(inst_path) or Fs:getType(inst_path) ~= 'directory') then
            Fs:mkdir(inst_path)
            mkdired[inst_path] = 1
        end
        count = count + 1
        if not overwrite_noask and Fs:isExist(inst_path_file) then
            if jumpout_noask then
                return
            end
            Log:Warn('文件 %s 在BDS目录下已存在，请选择...', relative_inst_path_file)
            while true do
                Log:Warn('[o]覆盖 [q]跳过 [O]全部覆盖 [Q]全部跳过')
                Log:Write('(O/o/Q/q) > ')
                local chosed = io.read()
                if chosed == 'O' then
                    overwrite_noask = true
                    break
                elseif chosed == 'Q' then
                    jumpout_noask = true
                    return
                elseif chosed == 'o' then
                    break
                elseif chosed == 'q' then
                    return
                else
                    Log:Error('输入有误，请重新输入！')
                end
            end
        end
        Fs:copy(inst_path_file, ori_path_file)
        Log:Info('(%s/%s) 复制 -> %s', count, all_count, relative_inst_path_file)
        installed[#installed + 1] = relative_inst_path_file
    end)
    local pkg = table.clone(pkgInfo)
    pkg.verification = nil
    pkg.paths.installed = installed
    pkg.platform = nil
    pkg.format_version = Version:getNum(6)
    self.installed[pkg.uuid] = pkg
    Fs:writeTo(('%s%s.%s'):format(self.dir, pkgInfo.uuid, ENV.INSTALLED_PACKAGE), JSON:stringify(pkg))
    Log:Info('%s 已成功安装。', pkgInfo.name)
    return true
end

---升级软件包
---@param lpkdir string
---@return boolean
function SoftwareManager:update(lpkdir)
    local path, pkgInfo = self:parse(lpkdir)
    if not (path and pkgInfo) then
        return false
    end
    local old_IDPkg = self:getInstalled(pkgInfo.uuid)
    if not old_IDPkg then
        Log:Info('%s 还未安装，因此无法升级。', pkgInfo.name)
        return false
    end
    if old_IDPkg.release > pkgInfo.release then
        Log:Info('不可以向旧版本升级')
        return false
    end
    if not self:verify(path, pkgInfo, true) then
        return false
    end
    Log:Error('正在处理依赖关系...')
    if not self:handleDependents(pkgInfo) then
        return false
    end
    Log:Info('%s (%s->%s) - %s', pkgInfo.name, old_IDPkg.version, pkgInfo.version, pkgInfo.contributors)
    io.write(('是否升级 %s (y/N)? '):format(pkgInfo.name))
    local chosed = io.read():lower()
    if chosed ~= 'y' then
        return false
    end
    local all_count = Fs:getFileCount(path .. 'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    local bds_dir = BDS:getRunningDirectory()
    Fs:iterator(path .. 'content/', function(nowpath, file)
        local ori_path_file = nowpath .. file
        local inst_path_file = bds_dir .. ori_path_file:sub((path .. 'content/'):len() + 1)
        local inst_path = Fs:getFileAtDir(inst_path_file)
        local relative_inst_path_file = inst_path_file:gsub(bds_dir, '')
        if not mkdired[inst_path] and (not Fs:isExist(inst_path) or Fs:getType(inst_path) ~= 'directory') then
            Fs:mkdir(inst_path)
            mkdired[inst_path] = 1
        end
        count = count + 1
        if not overwrite_noask and Fs:isExist(inst_path_file) and
            not array.fetch(old_IDPkg.paths.installed, relative_inst_path_file) then
            if jumpout_noask then
                return
            end
            Log:Warn('文件 %s 在BDS目录下已存在，请选择...', relative_inst_path_file)
            while true do
                Log:Warn('[o]覆盖 [q]跳过 [O]全部覆盖 [Q]全部跳过')
                Log:Write('(O/o/Q/q) > ')
                chosed = io.read()
                if chosed == 'O' then
                    overwrite_noask = true
                    break
                elseif chosed == 'Q' then
                    jumpout_noask = true
                    return
                elseif chosed == 'o' then
                    break
                elseif chosed == 'q' then
                    return
                else
                    Log:Error('输入有误，请重新输入！')
                end
            end
        end
        Fs:copy(inst_path_file, ori_path_file)
        Log:Info('(%s/%s) 复制 -> %s', count, all_count, relative_inst_path_file)
        installed[#installed + 1] = relative_inst_path_file
    end)
    for _, ipath in pairs(old_IDPkg.paths.installed) do
        if not installed[ipath] then
            Log:Warn('请注意，在版本 %s 中，"%s" 被弃用。', pkgInfo.version, ipath)
        end
    end
    local pkg = table.clone(pkgInfo)
    pkg.verification = nil
    pkg.paths.installed = installed
    pkg.platform = nil
    pkg.format_version = Version:getNum(6)
    self.installed[pkg.uuid] = pkg
    Fs:writeTo(('%s%s.%s'):format(self.dir, pkgInfo.uuid, ENV.INSTALLED_PACKAGE), JSON:stringify(pkg))
    Log:Info('%s 已成功升级。', pkgInfo.name)
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
                if not is_safe_dir(xpath) and not is_in_whitelist(pkg.uuid) then
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
    Fs:remove(('%s%s.%s'):format(self.dir, pkg.uuid, ENV.INSTALLED_PACKAGE))
    self.installed[pkg.uuid] = nil
    Log:Info(info)
    return true, not hasFail
end

---删除指定软件包的数据文件
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

---获取已安装软件包列表(uuid)
function SoftwareManager:getAll()
    local rtn = {}
    for uuid, _ in pairs(self.installed) do
        rtn[#rtn + 1] = uuid
    end
    return rtn
end

---根据UUID获取软件包信息(从已安装列表)
---@param uuid string
---@return table|nil
function SoftwareManager:get(uuid)
    return self.installed[uuid]
end

---为某软件包处理依赖
---@param pkg table 软件包Self的表对象
---@return boolean
function SoftwareManager:handleDependents(pkg)
    local downloaded = {}
    for n, against in pairs(pkg.conflict) do
        local instd = self:getInstalled(against.uuid)
        if instd and ApplicableVersionChecker:check(instd.version, against.version) then
            Log:Error('无法处理 %s 的依赖, 其与软件包 %s(%s) 冲突。', pkg.name, instd.name, against.version)
            return false
        end
    end
    for n, rely in pairs(pkg.depends) do --- short information for depends(rely)
        Log:Info('(%d/%d) 正在处理 %s ...', n, #pkg.depends, rely.name)
        local insted = SoftwareManager:getInstalled(pkg.uuid)
        local tpack
        if insted then
            if ApplicableVersionChecker:check(insted.version,rely.version) then
                Log:Info('(%d/%d) 已安装 %s。', n, #pkg.depends, rely.name)
            else
                local try = self:search(rely.uuid,false,true)
                if try.data == 0 then
                    Log:Error('无法处理依赖 %s, 此软件包不存在于当前仓库。',rely.name)
                    return false
                elseif ApplicableVersionChecker:check(try.version,rely.version) then
                    Log:Error('无法处理依赖 %s, 无法满足的版本要求(%s)。',rely.name,rely.version)
                    return false
                else --- should update installed denpendent [this].
                    tpack = try
                end
            end
        else
            tpack = self:search(rely.uuid, false, true)
        end
        if #tpack.data == 0 then
            Log:Error('无法处理依赖 %s, 因为在仓库中找不到软件。', rely.name)
            return false
        end
        local m = tpack.data[1]
        local dpath = Temp:getFile()
        if not Cloud:NewTask {
            url = m.download,
            path = dpath
        } then
            Log:Error('无法处理依赖 %s, 因为下载失败。', rely.name)
            return false
        end
        Log:Info('(%d/%d) 正在解压缩 %s ...', n, #pkg.depends, pkg.name)
        local tres, tpath = P7zip:extract(dpath)
        if not tres then
            Log:Error('无法处理依赖 %s, 因为解包时发生错误。', rely.name)
            return false
        end
        local path,dpkg_self = self:parse(tpath)
        if not (path and dpkg_self) then
            return false
        end
        if not self:verify(tpath, dpkg_self) then
            Log:Error('无法处理依赖 %s, 因为无法验证其软件包。', rely.name)
            return false
        end --- pre-check-completed.
        downloaded[#downloaded + 1] = { rely.name, dpath }
    end
    for n, pk in pairs(downloaded) do
        if not self:install(pk[2], true) then
            Log:Error('无法处理依赖 %s, 因为安装失败。', pk[1])
            return false
        else
            Log:Info('(%d/%d) 正在安装 %s ...',n,#downloaded,pk[1])
        end
    end
    return true
end

return SoftwareManager
