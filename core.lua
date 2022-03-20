--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "JSON"
require "filesystem"

Repo = {
    loaded = {}
}

local function fetch(uuid)
    for i,res in pairs(Repo.loaded) do
        if res.uuid == uuid then
            return i
        end
    end
    return nil
end

function Repo:init()
    self.loaded = JSON.parse(Fs:readFrom('repo.json')).repo
    return true
end

function Repo:save()
    Fs:writeTo('repo.json',JSON.stringify {
        format_version = Settings.Version.get(),
        repo = self.loaded
    })
end

function Repo:isExist(uuid)
    return fetch(uuid) ~= nil
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
        rtn[#rtn+1] = b.uuid
    end
    return rtn
end

function Repo:getName(uuid)
    local pos = fetch(uuid)
    if pos then
        return self.loaded[pos].name
    end
    return nil
end

Software = {}

return Repo,Software