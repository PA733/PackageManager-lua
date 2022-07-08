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

function Version:get(num)
    assert(type(num) == 'number')
    return self.data[num]
end

function Version:getNum(num)
    assert(type(num) == 'number')
    local a = self.data[num]
    return a.major*100 + a.minor*10 + a.revision
end

function Version:getStr(num)
    assert(type(num) == 'number')
    local a = self.data[num]
    return ('%s.%s.%s'):format(a.major,a.minor,a.revision)
end

return Version