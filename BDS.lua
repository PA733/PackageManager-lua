--[[ ----------------------------------------

    [Deps] Bedrock Server.

--]] ----------------------------------------

local Log = Logger:new('BDS')
BDS = {
    dir = '',
    dir_pdb_hash = 'data/pdb.json',
    version = 'NULL'
}

local function check_bds(path)
    return (Fs:isExist(path..'/bedrock_server.exe') or Fs:isExist(path..'/bedrock_server_mod.exe'))
            and Fs:isExist(path..'/bedrock_server.pdb')
end

local function search_bds(path)
    local rtn = {}
    local checked_dir = {}
    Fs:iterator(path,function (nowpath,file)
        if checked_dir[nowpath] then
            return
        end
        if check_bds(nowpath) then
            rtn[#rtn+1] = nowpath
        end
        checked_dir[nowpath] = 1
    end)
    return rtn
end

function BDS:init()

    --- Running Directory.
    local bdsdir = Settings:get('bds.running_directory')
    if bdsdir == '' or not check_bds(bdsdir) then
        local new_dir = ''
        Log:Warn('你的基岩版专用服务器路径尚未设定或无效，需要立即设定。')
        Log:Info('正在扫描...')
        local bds_list = search_bds('..')
        if #bds_list == 0 then
            bds_list = search_bds(os.getenv('USERPROFILE')..'/Desktop')
        end
        if #bds_list > 0 then
            local isFirstType = true
            while true do
                if not isFirstType then
                    Log:Error('输入错误，请重新输入。')
                end
                isFirstType = false
                Log:Info('找到 %s 个BDS，请选择：',#bds_list)
                Log:Print('[0] -> 手动输入')
                for n,path in pairs(bds_list) do
                    Log:Print('[%s] -> %s',n,path)
                end
                Log:Write('(0-%s) > ',#bds_list)
                local chosed = tonumber(io.read())
                if chosed then
                    if chosed > 0 and chosed < #bds_list then
                        new_dir = bds_list[chosed]
                    end
                    break
                end
            end
        else
            Log:Info('找不到BDS，请手动输入：')
        end
        if new_dir == '' then
            local isFirstType = true
            while true do
                if not isFirstType then
                    Log:Error('无法在您提供的目录下找到BDS，请重试')
                end
                isFirstType = false
                Log:Write('> ')
                local dir = io.read()
                if check_bds(dir) then
                    new_dir = dir
                    break
                end
            end
        end
        Settings:set('bds.running_directory',new_dir)
        bdsdir = new_dir
        Log:Info('设置成功')
    end
    self.dir = bdsdir

    local function update_pdb_hash_table(check_file_updated_time)
        local link = RepoManager:getMultiResource("PdbHashTable")
        if not link then
            Log:Error('获取 Ver-PdbHash 下载链接失败。')
            return
        end
        local recv = ''
        Cloud:NewTask {
            url = link,
            quiet = true,
            writefunction = function (str)
                recv = recv .. str
            end
        }
        local j = JSON:parse(recv)
        if not j then
            Log:Error('解析 Ver-PdbHash 对照表失败，可能是网络网络原因。')
            return
        end
        if j.format_version ~= Version:getNum(4) then
            Log:Error('Ver-PdbHash 对照表版本与管理器不匹配！')
            return
        end
        if check_file_updated_time and j.updated < check_file_updated_time then
            Log:Error('仓库中下载的 Ver-PdbHash 对照表比本地的更旧。')
            return
        end
        Fs:writeTo(self.dir_pdb_hash,JSON:stringify(j))
        return true
    end

    --- Running Version.
    if not Fs:isExist(self.dir_pdb_hash) then
        Log:Info('正在下载 Ver-PdbHash 对照表...')
        if not update_pdb_hash_table() then
            return false
        end
    end
    local updated = false
    local pdb
    while true do
        pdb = JSON:parse(Fs:readFrom(self.dir_pdb_hash))
        if not pdb then
            Log:Error('解析 Ver-PdbHash 对照表失败！')
            return false
        end
        local stat,sha1 = SHA1:file(self.dir..'bedrock_server.pdb')
        if not stat then
            Log:Error('获取 bedrock_server.pdb 的SHA1失败！')
            return false
        end
        self.version = pdb.pdb[sha1]
        if not self.version then
            if updated then
                Log:Error('对照表无法对应您的BDS，可能是仓库还未更新，或您的 PDB 被修改过。')
                return false
            else
                Log:Error('找不到当前PDB对应的版本，尝试更新 Ver-PdbHash 对照表...')
                if not update_pdb_hash_table(pdb.updated) then
                    return false
                end
                updated = true
            end
        else
            break
        end
    end

    --- Is latest.
    self.isLatestVersion = true
    for _,ver in pairs(pdb.pdb) do
        if Version:isBigger(ver,self.version) then
            self.isLatestVersion = false
            break
        end
    end
    return true
end

---获取设定的BDS运行目录
---@return string
function BDS:getRunningDirectory()
    return self.dir
end

---获取BDS运行版本
---@return string
function BDS:getVersion()
    return self.version
end

---是否是最新版本BDS
---@return boolean
function BDS:isLatest()
    return self.isLatestVersion
end

return BDS