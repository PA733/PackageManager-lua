--[[ ----------------------------------------

    [Deps] Json.

--]] ----------------------------------------

local base = require "json/json"
require "logger"

Log = Logger:new('Json')
JSON = {}

function JSON.parse(str)
    local stat,rtn = pcall(base.decode,str)
    if stat then
        return rtn
    end
    Log:Error('Could not parse JSON, content = "%s"',str)
    return nil
end

function JSON.stringify(object)
    local stat,rtn = pcall(base.encode,object,{ indent = true })
    if stat then
        return rtn
    end
    Log:Error('Could not stringify object.',object)
    return nil
end

return JSON