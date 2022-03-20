--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

local JSON = require "dkjson"
local fs = require "filesystem"

Repo = {
    loaded = {}
}

function Repo:init()
    self.loaded = JSON.decode(fs:readFrom('repo.json')).repo
    return true
end

function Repo:save()
    fs:writeTo('repo.json',JSON.encode {
        format_version = Settings.Version.get(),
        repo = self.loaded
    })
end

function Repo:isExist(uuid)
    for i,res in pairs(self.loaded) do
        if res.uuid == uuid then
            return true
        end
    end
    return false
end

function Repo:add(uuid,name,site,branch,ownfile)
    if self:isExist(uuid) then
        return false
    end
    self.loaded[#self.loaded+1] = {
        uuid = uuid,
        name = name,
        site = site,
        branch = branch,
        ['self'] = ownfile
    }
    self:save()
    return true
end

function Repo:remove(name)
    if not self:isExist(name) then
        return false
    end
    local pos
    for k,a in pairs(self.loaded) do
        if a.name == name then
            pos = k
            break
        end
    end
    if pos then
        table.remove(self.loaded,pos)
        self:save()
        return true
    end
    return false
end

function Repo:getAll()
    local rtn = {}
    for a,b in pairs(self.loaded) do
        rtn[#rtn+1] = b.name
    end
    return rtn
end

Software = {}

return Repo,Software