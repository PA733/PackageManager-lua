--[[ ----------------------------------------

    [Main] Version manager.

--]] ----------------------------------------

Version = {
    [0] = { -- *** Main ***
        major = 1,
        minor = 0,
        revision = 0
    },
    [1] = { -- *** Repo file ***
        major = 1,
        minor = 0,
        revision = 0
    },
    [2] = { -- *** Verification file ***
        major = 1,
        minor = 0,
        revision = 0
    }
}

function Version:get(num)
    assert(type(num) == 'number')
    local a = self[num]
    return {
        a.major,
        a.minor,
        a.revision
    }
end

function Version:getNum(num)
    assert(type(num) == 'number')
    local a = self[num]
    return a.major*100 + a.minor*10 + a.revision
end

function Version:getStr(num)
    assert(type(num) == 'number')
    local a = self[num]
    return string.format('%s.%s.%s',a.major,a.minor,a.revision)
end

return Version