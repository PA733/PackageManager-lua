--[[ ----------------------------------------

    [Main] Package Instance.

--]] ----------------------------------------

---@class Package
Package = {
    root_check_list = {
        'self.json',
        'verification.json',
        'content'
    },
    suffix = 'lpk',

    package_dir = 'NULL',
    unpacked_path = 'NULL',
    meta = {},
    verification = {}

}
local Log = Logger:new('Package')

---从软件包路径创建包对象
---@param dir string
---@return Package|nil
function Package:fromFile(dir)
    Log:Info('正在解析软件包...')
    local stat, unpacked_path = P7zip:extract(dir)
    if not stat then
        Log:Error('解压缩软件包时出现异常。')
        return nil
    end
    for _, n in pairs(self.root_check_list) do
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
    setmetatable(origin,self)
    self.__index = self
    origin.package_dir = dir
    origin.meta = pkgInfo
    origin.verification = verification
    origin.unpacked_path = unpacked_path
    return origin
end

---获取名称
---@return string
function Package:getName()
    return self.meta.name
end

---获取UUID
---@return string
function Package:getUUID()
    return self.meta.uuid
end

---获取版本
---@param release boolean 是否为发布序号
---@return string|number
function Package:getVersion(release)
    if release then
        return self.meta.release
    else
        return self.meta.version
    end
end

---获取贡献者列表
---@return table
function Package:getContributors()
    return self.meta.contributors:split(',')
end

---获取依赖信息列表
---@param ntree? NodeTree
---@param list? table
---@return table
function Package:getDependents(ntree,list)
    local rtn = {
        node_tree = ntree or NodeTree:create(self:getName()),
        list = list or {}
    }
    local depends = self.meta.depends
    for _,info in pairs(depends) do
        local sw = SoftwareManager:get(info.uuid)
        if sw then
            rtn.node_tree:branch(sw.name):setNote('已安装')
        else
            local res = SoftwareManager:search(info.uuid,false,true)
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
function Package:getConflict()
    return self.meta.conflict
end

---获取主页地址
---@return string
function Package:getHomepage()
    return self.meta.homepage
end

---获取标签
function Package:getTags()
    return self.meta.tags
end

function Package:getVerification()
    return self.verification
end

---检查是否适配当前游戏版本
---@return boolean
function Package:checkRequiredGameVersion()
    if not ApplicableVersionChecker:check(BDS:getVersion(),self.meta.applicable_game_version) then
        Log:Error('软件包与当前服务端版本不适配，安全检查失败。')
        return false
    end
    return true
end

---获取描述信息
---@return string
function Package:buildDescription()
    local deps = ''
    for _,depend in pairs(self:getDependents()) do
        deps = deps .. RepoManager:search(depend.uuid,true)
    end
    return ('软件包: %s\n版本: %s\n贡献者: %s\n主页: %s\n标签: %s\n介绍: %s').format(
        self:getName(),
        self:getVersion(false),
        table.concat(self:getContributors(),','),
        self:getHomepage(),
        table.concat(self:getTags(),','),
        table.concat(self.meta.description,'\n')
    )
end

---检验此软件包的完整性与合法性
---@param updateMode boolean? 升级模式，跳过部分检查
---@return boolean
function Package:verify(updateMode)
    Log:Info('正在校验包...')
    if not updateMode and SoftwareManager:getInstalled(self:getUUID()) then
        Log:Error('软件包已安装过，安全检查失败。')
    end
    if not updateMode and SoftwareManager:getUuidByName(self:getName()) then
        Log:Error('软件包与已安装软件有重名，安全检查失败。')
        return false
    end
    if not self:checkRequiredGameVersion() then
        return false
    end
    local meta = self.meta
    local verification = self:getVerification()
    local unpacked = self.unpacked_path
    local stopAndFailed = false
    local allow_unsafe = Settings:get('installer.allow_unsafe_directory') or SoftwareManager.Helper:isWhitePackage(self:getUUID())
    Fs:iterator(unpacked .. 'content/', function(nowpath, file)
        if stopAndFailed then
            return
        end
        local ori_path = nowpath .. file
        local vpath = ori_path:sub((unpacked .. 'content/'):len() + 1)
        if not allow_unsafe and not SoftwareManager.Helper:isSafeDirectory(vpath) then
            Log:Error('软件包尝试将文件安装到到不安全目录，安全检查失败。')
            stopAndFailed = true
            return
        end
        for _, dpath in pairs(meta.paths.data) do
            if not allow_unsafe and not SoftwareManager.Helper:isSafeDirectory(dpath) then
                Log:Error('软件包数据文件可能存放在不安全的目录，安全检查失败。')
                stopAndFailed = true
                return
            end
        end
        local sha1 = verification[vpath]
        local statu, pkg_file_sha1 = SHA1:file(ori_path)
        if not (sha1 and statu) or pkg_file_sha1 ~= sha1 then
            Log:Error('软件包校验失败。')
            stopAndFailed = true
            return
        end
    end)
    return not stopAndFailed
end

---安装此软件包
---@return boolean
function Package:install()
    local uuid = self:getUUID()
    if SoftwareManager:getInstalled(uuid) then
        Log:Error('软件包 %s 已安装，不可以重复安装。', uuid)
        return false
    end
    if not self:verify() then
        return false
    end
    Log:Error('正在处理依赖关系...')
    if not self:handleDependents() then
        return false
    end
    local name = self:getName()
    Log:Info('%s (%s) - %s', name, self:getVersion(false), self:getContributors())
    io.write(('是否安装 %s (y/N)? '):format(name))
    local chosed = io.read():lower()
    if chosed ~= 'y' then
        return false
    end
    local unpacked_path = self.unpacked_path
    local all_count = Fs:getFileCount(unpacked_path .. 'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    local bds_dir = BDS:getRunningDirectory()
    if uuid == 'be3bf7fe-360a-46b2-b6e3-6cf7151f641b' then --- lpM
        bds_dir = './'
    end
    Fs:iterator(unpacked_path .. 'content/', function(nowpath, file)
        local ori_path_file = nowpath .. file
        local inst_path_file = bds_dir .. ori_path_file:sub((unpacked_path .. 'content/'):len() + 1)
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
    if SoftwareManager:registerChanged(self.meta,installed) then
        Log:Info('%s 已成功安装。', name)
    else
        Log:Error('安装未成功。')
    end
    return true
end

---以此软件包为源，升级软件
---@return boolean
function Package:update()
    local uuid = self:getUUID()
    local name = self:getName()
    local old_IDPkg = SoftwareManager:getInstalled(uuid)
    if not old_IDPkg then
        Log:Info('%s 还未安装，因此无法升级。', name)
        return false
    end
    if old_IDPkg.release > self:getVersion(true) then
        Log:Info('不可以向旧版本升级')
        return false
    end
    if not self:verify(true) then
        return false
    end
    Log:Error('正在处理依赖关系...')
    if not self:handleDependents() then
        return false
    end
    local version = self:getVersion(false)
    Log:Info('%s (%s->%s) - %s', name, old_IDPkg.version, version, self:getContributors())
    io.write(('是否升级 %s (y/N)? '):format(name))
    local chosed = io.read():lower()
    if chosed ~= 'y' then
        return false
    end
    local unpacked_path = self.unpacked_path
    local all_count = Fs:getFileCount(unpacked_path .. 'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    local bds_dir = BDS:getRunningDirectory()
    Fs:iterator(unpacked_path .. 'content/', function(nowpath, file)
        local ori_path_file = nowpath .. file
        local inst_path_file = bds_dir .. ori_path_file:sub((unpacked_path .. 'content/'):len() + 1)
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
            Log:Warn('请注意，在版本 %s 中，"%s" 被弃用。', version, ipath)
        end
    end
    if SoftwareManager:registerChanged(self.meta,installed) then
        Log:Info('%s 已成功升级。', name)
    else
        Log:Error('升级失败。')
    end
    return true
end

---处理依赖
---@param ntree? NodeTree
---@return boolean
function Package:handleDependents(ntree)
    local ext_need_install = {}
    local pkgName = self:getName()
    ntree = ntree or NodeTree:create(pkgName)
    for n, against in pairs(self:getConflict()) do
        local instd = SoftwareManager:getInstalled(against.uuid)
        if instd and ApplicableVersionChecker:check(instd.version, against.version) then
            Log:Error('无法处理 %s 的依赖, 其与软件包 %s(%s) 冲突。', pkgName, instd.name, against.version)
            return false
        end
    end
    local depends = self:getDependents()
    for n, rely in pairs(depends) do --- short information for depends(rely)
        Log:Info('(%d/%d) 正在处理 %s ...', n, #depends, rely.name)
        local insted = SoftwareManager:getInstalled(self:getUUID())
        local tpack
        if insted then
            if ApplicableVersionChecker:check(insted.version,rely.version) then
                Log:Info('(%d/%d) 已安装 %s。', n, #depends, rely.name)
            else
                local try = RepoManager:search(rely.uuid,false)
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
            tpack = RepoManager:search(rely.uuid, false)
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
        Log:Info('(%d/%d) 正在解压缩 %s ...', n, #depends, pkgName)
        local tres, tpath = P7zip:extract(dpath)
        if not tres then
            Log:Error('无法处理依赖 %s, 因为解包时发生错误。', rely.name)
            return false
        end
        local path,dpkg_self = self:parse(tpath)
        if not (path and dpkg_self) then
            return false
        end
        if not self:verify() then
            Log:Error('无法处理依赖 %s, 因为无法验证其软件包。', rely.name)
            return false
        end --- pre-check-completed.
        ext_need_install[#ext_need_install + 1] = { rely.name, dpath }
    end
    for n, pk in pairs(ext_need_install) do
        if not self:install(pk[2], true) then
            Log:Error('无法处理依赖 %s, 因为安装失败。', pk[1])
            return false
        else
            Log:Info('(%d/%d) 正在安装 %s ...',n,#ext_need_install,pk[1])
        end
    end
    return true
end