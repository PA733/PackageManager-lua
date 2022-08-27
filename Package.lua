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
local manager = SoftwareManager

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
---@return string
function Package:getVersion()
    return self.meta.version
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
    if not Version:match(BDS:getVersion(),self.meta.applicable_game_version) then
        Log:Error('软件包与当前服务端版本不适配，安全检查失败。')
        return false
    end
    return true
end

---获取描述信息
---@return string
function Package:buildDescription()
    return ('软件包: %s\n版本: %s\n贡献者: %s\n主页: %s\n标签: %s\n介绍: %s').format(
        self:getName(),
        self:getVersion(),
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
    if not updateMode and manager:fromInstalled(self:getUUID()) then
        Log:Error('软件包已安装过，安全检查失败。')
    end
    if not updateMode and manager:getUuidByName(self:getName()) then
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
    local allow_unsafe = Settings:get('installer.allow_unsafe_directory') or manager.Helper:isWhitePackage(self:getUUID())
    Fs:iterator(unpacked .. 'content/', function(nowpath, file)
        if stopAndFailed then
            return
        end
        local ori_path = nowpath .. file
        local vpath = ori_path:sub((unpacked .. 'content/'):len() + 1)
        if not allow_unsafe and not manager.Helper:isSafeDirectory(vpath) then
            Log:Error('软件包尝试将文件安装到到不安全目录，安全检查失败。')
            stopAndFailed = true
            return
        end
        for _, dpath in pairs(meta.paths.data) do
            if not allow_unsafe and not manager.Helper:isSafeDirectory(dpath) then
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
    if manager:fromInstalled(uuid) then
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
    Log:Info('%s (%s) - %s', name, self:getVersion(), self:getContributors())
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
    if manager:registerChanged(self.meta,installed) then
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
    local old_IDPkg = manager:fromInstalled(uuid)
    if not old_IDPkg then
        Log:Info('%s 还未安装，因此无法升级。', name)
        return false
    end
    if Version:isBigger(old_IDPkg:getVersion(),self:getVersion()) then
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
    local version = self:getVersion()
    Log:Info('%s (%s->%s) - %s', name, old_IDPkg:getVersion(), version, self:getContributors())
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
    local installed_paths = old_IDPkg:getInstalledPaths()
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
            not array.fetch(installed_paths, relative_inst_path_file) then
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
    for _, ipath in pairs(installed_paths) do
        if not installed[ipath] then
            Log:Warn('请注意，在版本 %s 中，"%s" 被弃用。', version, ipath)
        end
    end
    if manager:registerChanged(self.meta,installed) then
        Log:Info('%s 已成功升级。', name)
    else
        Log:Error('升级失败。')
    end
    return true
end

---处理依赖
---@param scheme? table
---@return table 依赖处理方案
function Package:handleDependents(scheme)
    local pkgName = self:getName()
    local rtn = scheme or {
        ntree = NodeTree:create(pkgName),
        install = {},
        errors = {}
    }
    local ntree = rtn.ntree
    for _, against in pairs(self:getConflict()) do
        local instd = manager:fromInstalled(against.uuid)
        if instd and Version:match(instd:getVersion(), against.version) then
            rtn.status = false
            rtn.errors[#rtn.errors+1] = {
                type = 'conflict',
                uuid = against.uuid,
                version = against.version,
                name = against.name
            }
            ntree:branch(against.name):setNote(('与%s不兼容'):format(instd:getName()))
        end
    end
    local depends = self:getDependents()
    for _, rely in pairs(depends) do --- short information for depends(rely)
        local insted = manager:fromInstalled(rely.uuid)
        local name = manager:getNameByUuid(rely.uuid)
        name = name or rely.uuid
        if insted and Version:match(insted:getVersion(),rely.version) then
            ntree:branch(name):setNote('已安装')
        else
            local try = RepoManager:search(rely.uuid,false,'uuid',rely.version,nil,1)
            if #try == 0 then
                ntree:branch(name):setNote('版本不兼容')
                rtn.errors[#rtn.errors+1] = {
                    type = 'notfound',
                    uuid = rely.uuid,
                    version = rely.version,
                    name = name
                }
            elseif insted and Version:isBigger(insted:getVersion(),try:getVersion()) then
                ntree:branch(name):setNote('不能降级')
                rtn.errors[#rtn.errors+1] = {
                    type = 'cantdegrade',
                    uuid = rely.uuid,
                    version = rely.version,
                    name = name
                }
            else --- should update installed denpendent [this].
                rtn.install[#rtn.install+1] = try[1]
            end
        end
    end
    return rtn
end