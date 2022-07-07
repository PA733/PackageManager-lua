--[[ ----------------------------------------

    [Deps] Lua File System.

--]] ----------------------------------------

require "native-type-helper"
local wf = require("winfile")
local dir_sym = package.config:sub(1,1)

Fs = {}

local function directory(path)
    path = path .. dir_sym
    if dir_sym == '/' then
        path = string.gsub(path,'/',dir_sym)
    elseif dir_sym == '\\' then
        path = string.gsub(path,'\\',dir_sym)
    end
    path = string.gsub(path,dir_sym..dir_sym,dir_sym)
    return path
end

function Fs:getCurrentPath()
    return directory(wf.currentdir())
end

function Fs:getDirectoryList(path)
    local list = {}
    path = path or self:getCurrentPath()
    path = directory(path)
    for file in wf.dir(path) do
        if file~='.' and file~='..' then
            local attr = wf.attributes(path..file)
            if attr and attr.mode=='directory' then
                list = Array.Concat(list,self:getDirectoryList(path..file..dir_sym))
            end
            list[#list+1] = path..file
        end
    end
    return list
end

function Fs:writeTo(path,content)
	local file = assert(wf.open(path, "wb"))
	file:write(content)
	file:close()
    return true
end

function Fs:readFrom(path)
    local file = assert(wf.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

function Fs:mkdir(path)
    path = directory(path)
    local dirs = string.split(path,dir_sym)
    for k,v in pairs(dirs) do
        wf.mkdir(table.concat(dirs,dir_sym,1,k)..dir_sym)
    end
    return true
end

function Fs:rmdir(path,forceMode)
    local m = wf.remove(directory(path))
    if m then
       return true
    elseif forceMode then
        local ret
        if dir_sym == '/' then -- linux
            ret = wf.execute(('rm -rf "%s"'):format(path))
        elseif dir_sym == '\\' then -- windows
            ret = wf.execute(('rd "%s" /s /q'):format(path))
        end
        return ret
    end
    return false
end

function Fs:getFileSize(path)
    return wf.attributes(path).size
end

function Fs:getType(path)
    return wf.attributes(path).mode
end

function Fs:isExist(path)
    return wf.attributes(path) ~= nil
end

function Fs:isSame(path1,path2)
    return Fs:readFrom(path1) == Fs:readFrom(path2)
end

function Fs:copy(to_path,from_path)
    Fs:writeTo(to_path,Fs:readFrom(from_path))
end

function Fs:remove(path)
    return wf.remove(path)
end

function Fs:open(path,mode)
    return wf.open(path,mode)
end

return Fs