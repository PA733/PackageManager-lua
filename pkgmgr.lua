--[[ ----------------------------------------

    [Main] Software Manager.

--]] ----------------------------------------

require "logger"
require "json-safe"
require "filesystem"
require "environment"
require "sha1"
require "settings"
require "version"
require "native-type-helper"
require "7zip"

local Log = Logger:new('PackMgr')
PackMgr = {
    dir = 'data/installed/',
    installed = {}
}

function PackMgr:init()
    Fs:mkdir(self.dir)
    Fs:iterator(self.dir,function (nowpath,file)
        local path = nowpath .. file
        if path:sub(path:len() - 7) == '.' .. ENV.INSTALLED_PACKAGE and Fs:getType(path) == 'file' then
            local m = JSON:parse(Fs:readFrom(path))
            if not m then
                Log:Error('%s 无效软件包信息', path)
            elseif m.format_version ~= Version:getNum(6) then
                Log:Error('%s 不匹配的格式版本')
            else
                self.installed[#self.installed + 1] = m
            end
        end
    end)
    return true
end

---安装lpk软件包, 不处理依赖
---@param lpkdir string 软件包路径
---@param noask? boolean 是否跳过在安装过程中询问
---@param noverify? boolean 是否跳过校验包
function PackMgr:install(lpkdir,noask,noverify)
    noask = noask or false
    noverify = noverify or false
    Log:Info('正在解析软件包...')
    local stat,path = P7zip:extract(lpkdir)
    if not stat then
        Log:Error('解压缩软件包时出现异常。')
        return false
    end
    for _,n in pairs(ENV.INSTALLER_PACKAGE_CHECK_LIST) do
        if not Fs:isExist(path .. n) then
            Log:Error('不合法的包，缺少 %s。',n)
            return false
        end
    end
    local pkgInfo = JSON:parse(Fs:readFrom(path .. 'self.json'))
    if not pkgInfo then
        Log:Error('读取包信息时出现异常。')
        return false
    end
    if pkgInfo.format_version ~= Version:getNum(5) then
        Log:Error('软件包自述文件版本不匹配。')
        return false
    end

    local function is_dangerous_dir(tpath)
        if Settings:get('installer.allow_unsafe_directory') then
            return true
        end
        for _,sfpath in pairs(ENV.INSTALLER_SAFE_DIRS) do
            if tpath:sub(0,sfpath:len()) == sfpath then
                break
            end
        end
        return false
    end

    Log:Info('正在校验包...')
    if not noverify then
        local stopAndFailed = false
        Fs:iterator(path..'content/',function (nowpath,file)
            if stopAndFailed then
                return
            end
            local ori_path = nowpath .. file
            local vpath = ori_path:sub((path..'content/'):len()+1)
            if is_dangerous_dir(vpath) then
                Log:Error('软件包尝试将文件放到不安全目录，校验失败。')
                return
            end
            local sha1 = pkgInfo.verification[vpath]
            local statu,pkg_file_sha1 = SHA1:file(ori_path)
            if not (sha1 and statu) or pkg_file_sha1 ~= sha1 then
                Log:Error('软件包校验失败。')
                stopAndFailed = true
                return
            end
        end)
        if stopAndFailed then
            return false
        end
    end
    if not noask then
        io.write(('是否安装 %s (y/N)? '):format(pkgInfo.name))
        local chosed = io.read():lower()
        if chosed ~= 'y' then
            return false
        end
    end
    local all_count = Fs:getFileCount(path..'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    Fs:iterator(path..'content/',function (nowpath,file)
        local ori_path_file = nowpath .. file
        local bds_dir = BDS:getRunningDirectory()
        local inst_path_file = bds_dir..ori_path_file:sub((path..'content/'):len()+1)
        local inst_path = Fs:getFileAtDir(inst_path_file)
        local relative_inst_path_file = inst_path_file:gsub(bds_dir,'')
        if not mkdired[inst_path] and (not Fs:isExist(inst_path) or Fs:getType(inst_path) ~= 'directory') then
            Fs:mkdir(inst_path)
            mkdired[inst_path] = 1
        end
        count = count + 1
        if not (noask or overwrite_noask) and Fs:isExist(inst_path_file) then
            if jumpout_noask then
                return
            end
            Log:Warn('文件 %s 在BDS目录下已存在，请选择...',relative_inst_path_file)
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
        Fs:copy(inst_path_file,ori_path_file)
        Log:Info('(%s/%s) 复制 -> %s',count,all_count,relative_inst_path_file)
        installed[#installed+1] = relative_inst_path_file
    end)
    local pkg = table.clone(pkgInfo)
    pkg.verification = nil
    pkg.installed = installed
    pkg.platform = nil
    pkg.format_version = Version:getNum(6)
    Fs:writeTo(('%s%s.%s'):format(self.dir,pkgInfo.uuid,ENV.INSTALLED_PACKAGE),JSON:stringify(pkg))
    Log:Info('%s 已成功安装。',pkgInfo.name)
    return true
end

---删除软件包
---@param uuid string 软件包唯一ID
---@param purge boolean 是否删除数据文件
function PackMgr:remove(uuid, purge)

end

---删除指定软件包的数据文件
---@param uuid string
function PackMgr:purge(uuid)

end

---升级软件包, 不处理依赖
---@param uuid string
---@param lpkdir string
function PackMgr:update(uuid, lpkdir)

end

---获取已安装软件包列表(uuid)
function PackMgr:getInstalledList()

end

---根据UUID获取软件包摘要
---@param uuid string
function PackMgr:getSoftware(uuid)

end

return PackMgr
