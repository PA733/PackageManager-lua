--[[ ----------------------------------------

    [Main] Version manager.

--]] ----------------------------------------

Version = {
    major = 1,
    minor = 0,
    revision = 0
}

function Version:get()
    return {
        self.major,
        self.minor,
        self.revision
    }
end

function Version:getNum()
    return self.major*100 + self.minor*10 + self.revision
end

function Version:getStr()
    return string.format('%s.%s.%s',self.major,self.minor,self.revision)
end

return Version