--[[ ----------------------------------------

    [Deps] Json.

--]] ----------------------------------------

require "logger"
local base = require "json-beautify"
local Log = Logger:new('Json')

JSON = {}

---解析JSON字符串
---@param str string
---@return table|nil
function JSON:parse(str)
    local stat,rtn = pcall(base.decode,str)
    if stat then
        return rtn
    end
    Log:Error('Could not parse JSON, content = "%s"',str)
    return nil
end

---将对象转换为JSON字符串
---@param object table
---@param beautify? boolean 是否美化
---@return string|nil
function JSON:stringify(object,beautify)
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
    Log:Error('Could not stringify object.')
    return nil
end

return JSON