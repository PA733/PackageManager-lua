--[[ ----------------------------------------

    [Deps] Lua File System.

--]] ----------------------------------------

local function stdpath(path)
    local a = string.reverse(path)
    if string.find(a,'\\')==1 then
        return string.sub(path,1,string.len(path)-1)
    end
    return path
end

local lfs = require("lfs")
local fs = {}

function fs:getCurrentPath()
    return lfs.currentdir()..'\\'
end

function fs:getDirectoryList(path)
    local list = {}
    for file in lfs.dir(path) do
        if file~='.' and file~='..' then
            list[#list+1] = path..file
            local attr = lfs.attributes(stdpath(path))
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
end

function fs:readFrom(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

function fs:mkdir(path)
    if not string.find(path,'\\') then
        return lfs.mkdir(path)
    else
        local ms = string.split(path,'\\')
        table.remove(ms,1) -- rm first "\"
        local npath = ""
        for i,path_t in pairs(ms) do
            npath = npath..'\\'..path_t
            lfs.mkdir(npath)
        end
    end
end

function fs:rmdir(path)
    return lfs.rmdir(path)
end

function fs:getFileSize(path)
    local attr = lfs.attributes(path)
    return attr.size
end

function fs:getType(path)
    local attr = lfs.attributes(path)
    return attr.mode
end

function fs:isExist(path)
    local attr = lfs.attributes(stdpath(path))
    return attr ~= nil
end

function fs:isSame(path1,path2)
    local a = fs:readFrom(path1)
    local b = fs:readFrom(path2)
    return a == b
end

function fs:copy(to_path,from_path)
    fs:writeTo(to_path,fs:readFrom(from_path))
end

return fs