--[[ ----------------------------------------

    [Deps] 7Zip client.

--]] ----------------------------------------

require "logger"
require "temp"
Wf = require "winfile"
Fs = require "filesystem"
Log = Logger:new('7Zip')

P7zip = {
    path = 'lib\\7zip\\',
    files = {
        '7za.exe',
        '7za.dll',
        '7zxa.dll'
    }
}

function P7zip:init()

    -- pre-check
    for n,i in pairs(self.files) do
       if not Fs:isExist(self.path..i) then
           Log:Error('找不到 %s，模块不可用。',i)
           return false
       end
    end
    if not Wf.popen(('%s%s i'):format(self.path,'7za')):read("*a"):find('7-Zip %(a%)') then
        Log:Error('初始化失败，模块不可用。')
        return false
    end

end

---解压缩
---@param path string 压缩文件路径
---@param topath string? 解压到路径, 若不提供则返回一个临时路径
function P7zip:extract(path,topath)
    topath = topath or Temp:getDirectory()
    
    return Wf.popen(('%s%s x -o"%s" -y "%s"'):format(self.path,'7za',topath,path)):read('*a'):find('Everything is Ok')~=nil,topath
end

---创建压缩包
---@param path string 欲压缩文件(夹)路径
---@param topath string 压缩文件创建路径
function P7zip:archive(path,topath)
    return Wf.popen(('%s%s a -y "%s" "%s"'):format(self.path,'7za',topath,path)):read('*a'):find('Everything is Ok') ~= nil
end

return P7zip