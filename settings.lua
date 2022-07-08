--[[ ----------------------------------------

    [Main] Internal settings.

--]] ----------------------------------------

require "version"
require "logger"
require "JSON"
require "filesystem"

local Log = Logger:new('Settings')
local cfg = {
    version = Version:getNum(0),
    output = {
        no_color = false
    }
}

Settings = {
    dir = 'data/config.json',
    loaded = false
}

function Settings:init()
    if not Fs:isExist(self.dir) then
        Fs:writeTo(self.dir,JSON.stringify(cfg))
    end
    local loadcfg = JSON.parse(Fs:readFrom(self.dir))
    for n,path in pairs(table.getAllPaths(cfg,false)) do
        local m = table.getKey(loadcfg,path)
        if m ~= nil then
            table.setKey(cfg,path,m)
        else
            Log:Error('配置文件丢失 %s, 已使用默认值。',path)
        end
    end
    self.loaded = true
    return self.loaded
end

function Settings:get(path)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前获得配置项 %s',path)
        return
    end
    return table.getKey(cfg,path)
end

function Settings:set(path,value)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前设定配置项 %s',path)
        return
    end
    table.setKey(cfg,path,value)
    self:save()
    return true
end

function Settings:save()
    if not self.loaded then
        Log:Error('尝试在配置项初始化前保存')
        return
    end
    Fs:writeTo(self.dir,JSON.stringify(cfg))
    return true
end

return Settings