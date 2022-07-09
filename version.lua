--[[ ----------------------------------------

    [Main] Version manager.

--]] ----------------------------------------

Version = {
    data = {},
    count = 0,
    register = function (_,major,minor,revision)
        local a = Version
        a.data[a.count] = {
            major = major,
            minor = minor,
            revision = revision
        }
        a.count = a.count + 1
    end
}

Version.register('Main',1,0,0)
Version.register('Repo',1,0,0)
Version.register('Verification',1,0,0)
Version.register('Installed',1,0,0)
Version.register('PdbHashTab',1,0,0)

---@alias VersionType
---|> 1     # Main
---|  2     # Repo
---|  3     # Verification
---|  4     # Installed
---|  5     # PdbHashTable

---获取版本 (obj)
---@param num VersionType
---@return table
function Version:get(num)
    assert(type(num) == 'number')
    return self.data[num]
end

---获取版本 (int)
---@param num VersionType
---@return integer
function Version:getNum(num)
    assert(type(num) == 'number')
    local a = self.data[num]
    return a.major*100 + a.minor*10 + a.revision
end

---获取版本 (str)
---@param num VersionType
---@return string
function Version:getStr(num)
    assert(type(num) == 'number')
    local a = self.data[num]
    return ('%s.%s.%s'):format(a.major,a.minor,a.revision)
end

return Version