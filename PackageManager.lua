function PkgDB:getAll()
    local result = package_db:execute[[
        SELECT name _id FROM sqlite_master WHERE type ='table'
    ]]
    local rtn = {}
    local name = result:fetch()
    while name do
        rtn[#rtn+1] = name
    end
    return rtn
end

---删除数据库中指定repoUUID的Class(Name)
---@param uuid string
---@param class string
function PkgDB:remove(uuid,class)
    return self:removeTbl(('%s__%s'):format(uuid,class))
end

function PkgDB:removeTbl(name)
    return package_db:execute(([[
        DROP TABLE "%s"
    ]]):format(name))
end

---添加一条软件包信息到本地数据库中
---@param repo_uuid string 指定仓库UUID
---@param name string 软件包名
---@param uuid string 软件包UUID
---@param version string 软件包版本
---@param contributors string 贡献者信息
---@param description string 简短解释
---@param selflink string 软件包下载链接
function PkgDB:append(repo_uuid,class,name,uuid,version,contributors,description,selflink)
    package_db:execute(([[	
        CREATE TABLE IF NOT EXISTS "%s__%s"(
            name TEXT NOT NULL,
            uuid TEXT NOT NULL,
            version TEXT NOT NULL,
            contributors TEXT NOT NULL,
            description TEXT NOT NULL,
            download TEXT NOT NULL
        )
    ]]):format(repo_uuid,class))
    package_db:execute(([[
        INSERT INTO "%s" VALUES('%s','%s','%s','%s','%s','%s')
    ]]):format(name,uuid,version,contributors,description,selflink))
end

---获取一个仓库在本地软件包列表中持有的所有表名
---@param uuid string
---@return table
function PkgDB:getAvailableClasses(uuid)
    local rtn = {}
    local result = PkgDB:getAll()
    local n = uuid .. '__'
    for _,name in pairs(result) do
        if name:sub(1,n:len()) == n then
            rtn[#rtn+1] = name
        end
    end
    return rtn
end

---删除一个仓库在本地列表中
---@param uuid string
function PkgDB:purge(uuid)
    local avail = self:getAvailableClasses(uuid)
    for _,name in pairs(avail) do
        self:removeTbl(name)
    end
end

---从本地软件包列表中搜索
---@param keyword string 关键词
---@param messyMatch? boolean 启用模糊查找
---@param byUUID? boolean 通过UUID(keyword换成uuid)
---@return table 返回包含结果的表
function PkgDB:search(keyword,messyMatch,byUUID)
    local rtn = {
        isTop = false,
        data = {}
    }
    local byWhat = 'name'
    if byUUID then
        byWhat = 'uuid'
    end
    local cmd = [[ SELECT * FROM "%s__%s" WHERE %s="%s" ]]
    if messyMatch then
        cmd = [[ SELECT * FROM "%s__%s" WHERE "%s" LIKE "%%%s%%" ]]
    end
    for n,uuid in pairs(Repo:getPriorityList()) do
        local classes = self:getAvailableClasses(uuid)
        for _,class in pairs(classes) do
            local res = package_db:execute(cmd):format(uuid,class,byWhat,keyword)
            local name,pk_uuid,version,contributors,description,download = res:fetch()
            while name do
                rtn.data[#rtn.data+1] = {
                    repo = uuid,
                    class = class,
                    name = name,
                    uuid = pk_uuid,
                    version = version,
                    contributors = contributors,
                    description = description,
                    download = download
                }
                name,pk_uuid,version,contributors,description,download = res:fetch()
            end
        end
        if n == 1 and #rtn.data ~= 0 then --- top repo had result.
            rtn.isTop = true
            return rtn
        end
    end
    return rtn
end