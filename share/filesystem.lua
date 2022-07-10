--[[ ----------------------------------------

    [Deps] Lua File System.

--]] ----------------------------------------

require "native-type-helper"
local wf = require("winfile")
-- local dir_sym = package.config:sub(1,1)
local dir_sym = '/'

Fs = {}

---标准化目录
---@param path string
---@return string
local function directory(path)
    path = (path..dir_sym):gsub('\\',dir_sym):gsub(dir_sym..dir_sym,dir_sym)
    return path
end

---获取文件路径所在的目录路径
---
---例如 `C:/h/o/m/o.txt` --> `C:/h/o/m/`
---@param url string
---@return string
function Fs:getFileAtDir(url)
    return url:sub(1,url:len()-url:reverse():find('/')+1)
end

---获取当前路径
---@return string
function Fs:getCurrentPath()
    return directory(wf.currentdir())
end

---目录迭代器
---@param path? string
---@param callback function 原型 `cb(nowpath,file)`
---@return boolean
function Fs:iterator(path,callback)
    path = path or '.'
    path = directory(path)
    for file in wf.dir(path) do
        if file ~= '.' and file ~= '..' then
            local attr = wf.attributes(path..file)
            if attr and attr.mode == 'directory' then
                self:iterator(path..file..dir_sym,callback)
            elseif attr.mode == 'file' then
                callback(path,file)
            end
        end
    end
    return true
end

---获取目录下文件数目
---@param path string
---@return integer
function Fs:getFileCount(path)
    local rtn = 0
    Fs:iterator(path,function (nowpath,file)
        rtn = rtn + 1
    end)
    return rtn
end

---(sync)将内容写入至某文件
---@param path string
---@param content any
---@return boolean
function Fs:writeTo(path,content)
	local file = assert(wf.open(path, "wb"))
	file:write(content)
	file:close()
    return true
end

---(sync)读入某文件
---@param path string
---@return string
function Fs:readFrom(path)
    local file = assert(wf.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

---创建目录(可以递归)
---@param path string
---@return boolean
function Fs:mkdir(path)
    path = directory(path)
    local dirs = string.split(path,dir_sym)
    for k,v in pairs(dirs) do
        wf.mkdir(table.concat(dirs,dir_sym,1,k)..dir_sym)
    end
    return true
end

---删除目录
---@param path string 只能是空路径
---@param forceMode boolean 强制模式将使用命令行删除
---@return boolean
function Fs:rmdir(path,forceMode)
    local m = wf.remove(directory(path))
    if m then
       return true
    elseif forceMode then
        return wf.execute(('rd "%s" /s /q'):format(path))
    end
    return false
end

---获取文件大小
---@param path string
---@return number
function Fs:getFileSize(path)
    return wf.attributes(path).size
end

---获取路径类型，常用的有 `file` `directory`
---@param path string
---@return string
function Fs:getType(path)
    return wf.attributes(path).mode
end

---获取路径是否存在（不区分目录）
---@param path string
---@return boolean
function Fs:isExist(path)
    return wf.attributes(path) ~= nil
end

---文件是否内容一致
---@param path1 string
---@param path2 string
---@return boolean
function Fs:isSame(path1,path2)
    return Fs:readFrom(path1) == Fs:readFrom(path2)
end

---复制文件
---@param to_path string
---@param from_path string
function Fs:copy(to_path,from_path)
    Fs:writeTo(to_path,Fs:readFrom(from_path))
end

---删除文件
---@param path string
---@return boolean
function Fs:remove(path)
    return wf.remove(path)
end

---打开文件
---@param path string
---@param mode string
---@return file*
function Fs:open(path,mode)
    return wf.open(path,mode)
end

return Fs