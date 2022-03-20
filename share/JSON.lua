local base = require "dkjson"

JSON = {}

function JSON.parse(str)
    local stat,rtn = pcall(base.decode,str)
    if stat then
        return rtn
    end
    Logger:Debug('Could not parse JSON, content = %s',str)
    return nil
end

function JSON.stringify(object)
    local stat,rtn = pcall(base.encode,object)
    if stat then
        return rtn
    end
    Logger:Debug('Could not stringify object.',object)
    return nil
end

return JSON