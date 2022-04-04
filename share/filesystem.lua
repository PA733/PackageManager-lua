--[[ ----------------------------------------

    [Deps] Lua File System.

--]] ----------------------------------------

require "native-type-helper"
local lfs = require("lfs")

Fs = {}
local function directory(path)
    path = path .. '\\'
    path = string.gsub(path,'/','\\')
    path = string.gsub(path,'\\\\','\\')
    return path
end

function Fs:getCurrentPath()
    return directory(lfs.currentdir())
end

function Fs:getDirectoryList(path)
    local list = {}
    path = path or self:getCurrentPath()
    path = directory(path)
    for file in lfs.dir(path) do
        if file~='.' and file~='..' then
            local attr = lfs.attributes(path..file)
            if attr and attr.mode=='directory' then
                list = Array.Concat(list,self:getDirectoryList(path..file..'\\'))
            end
            list[#list+1] = path..file
        end
    end
    return list
end

function Fs:writeTo(path,content)
	local file = assert(io.open(path, "wb"))
	file:write(content)
	file:close()
    return true
end

function Fs:readFrom(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

function Fs:mkdir(path)
    path = directory(path)
    local dirs = string.split(path,'\\')
    for k,v in pairs(dirs) do
        lfs.mkdir(table.concat(dirs,'\\',1,k)..'\\')
    end
    return true
end

function Fs:rmdir(path,forceMode)
    local m = lfs.rmdir(directory(path))
    if m then
       return true
    elseif forceMode then
        for a,tph in pairs(self:getDirectoryList(path)) do
            os.remove(tph)
        end
        return self:rmdir(path)
    end
    return false
end

function Fs:getFileSize(path)
    return lfs.attributes(path).size
end

function Fs:getType(path)
    return lfs.attributes(path).mode
end

function Fs:isExist(path)
    return lfs.attributes(path) ~= nil
end

function Fs:isSame(path1,path2)
    return Fs:readFrom(path1) == Fs:readFrom(path2)
end

function Fs:copy(to_path,from_path)
    Fs:writeTo(to_path,Fs:readFrom(from_path))
end

return Fs