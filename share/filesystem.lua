--[[ ----------------------------------------

    [Deps] Lua File System.

--]] ----------------------------------------

require "native-type-helper"
local lfs = require("lfs")
local fs = {
    __VERSION = 100
}

local function directory(path)
    path = path .. '\\'
    path = string.gsub(path,'/','\\')
    path = string.gsub(path,'\\\\','\\')
    return path
end

function fs:getCurrentPath()
    return directory(lfs.currentdir())
end

function fs:getDirectoryList(path)
    local list = {}
    path = path or fs:getCurrentPath()
    path = directory(path)
    for file in lfs.dir(path) do
        if file~='.' and file~='..' then
            list[#list+1] = path..file
            local attr = lfs.attributes(path)
            if attr and attr.mode=='directory' then
                list = Array.Concat(list,fs:getDirectoryList(path..file..'\\'))
            end
        end
    end
    return list
end

function fs:writeTo(path,content)
	local file = assert(io.open(path, "wb"))
	file:write(content)
	file:close()
    return true
end

function fs:readFrom(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

function fs:mkdir(path)
    path = directory(path)
    local dirs = string.split(path,'\\')
    for k,v in pairs(dirs) do
        lfs.mkdir(table.concat(dirs,'\\',1,k)..'\\')
    end
    return true
end

function fs:rmdir(path)
    return lfs.rmdir(directory(path)..'\\')
end

function fs:getFileSize(path)
    return lfs.attributes(path).size
end

function fs:getType(path)
    return lfs.attributes(path).mode
end

function fs:isExist(path)
    return lfs.attributes(path) ~= nil
end

function fs:isSame(path1,path2)
    return fs:readFrom(path1) == fs:readFrom(path2)
end

function fs:copy(to_path,from_path)
    fs:writeTo(to_path,fs:readFrom(from_path))
end

return fs