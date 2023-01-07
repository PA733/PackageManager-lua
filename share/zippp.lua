--[[ ----------------------------------------

    [Deps] Zippp.

--]] ----------------------------------------

require "logger"
require "temp"
require "filesystem"
Wf = require "winfile"
local zippp = require("zippp")
local Log = Logger:new('zippp')

function zippp:init()

end

---解压缩
---@param path string 压缩文件路径
---@param topath string? 解压到路径, 若不提供则返回一个临时路径
---@return boolean isOk
---@return string path
function zippp:extract(path,topath)
    if not Fs:isExist(path) then
        Log:Error('解压缩失败，因为文件不存在。')
        return false,''
    end
    topath = topath or Temp:getDirectory()
    local success, msg = zippp.extract_zip(path, topath)
    return success, topath
end

---创建压缩包
---@param path string 欲压缩文件(夹)路径
---@param topath string 压缩文件创建路径
function zippp:archive(path,topath)
    local success, msg = zippp.create_zip(path, topath)
    return success
end

return zippp