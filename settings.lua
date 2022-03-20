--[[ ----------------------------------------

    [Main] Internal settings.

--]] ----------------------------------------

require "version"
require "logger"

local Log = Logger:new('Settings')
local cfg = {
    version = Version:getNum(),
    output = {
        noColor = false
    },
    repo = {
        use = "e725ab8b-d5a4-47a0-afb0-242d8e0c7461"
    }
}

Settings = {
    loaded = false
}

function Settings:init()
    local loadcfg = JSON.parse(Fs:readFrom('config.json'))
    for n,path in pairs(table.getAllPaths(cfg,false)) do
        local m = table.getKey(loadcfg,path)
        if m ~= nil then
            table.setKey(cfg,path,m)
        else
            Log:Error('配置文件丢失 %s, 已使用默认值。',path)
        end
    end
    self.loaded = true
end

function Settings:get(path)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前获得配置项 %s',path)
        return
    end
    return table.getKey(cfg,path)
end

return Settings