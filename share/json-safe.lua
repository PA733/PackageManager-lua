--[[ ----------------------------------------

    [Deps] Json.

--]] ----------------------------------------

local base = require "json-beautify"
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

function JSON.stringify(object,beautify)
    beautify = beautify or false
    local stat,rtn
    if beautify then
        stat,rtn = pcall(base.beautify,object)
    else
        stat,rtn = pcall(base.encode,object)
    end
    if stat then
        return rtn
    end
    Log:Error('Could not stringify object.',object)
    return nil
end

return JSON