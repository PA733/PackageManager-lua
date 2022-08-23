--[[ ----------------------------------------

    [Main] Internal settings.

--]] ----------------------------------------

local Log = Logger:new('Settings')
local cfg = {
    format_version = Version:getNum(1),
    bds = {
        running_directory = ''
    },
    repo = {
        allow_insecure_protocol = false
    },
    installer = {
        allow_unsafe_directory = false
    },
    output = {
        no_color = false
    }
}

Settings = {
    dir = 'data/config.json',
    loaded = false
}

---初始化
---@return boolean
function Settings:init()
    if not Fs:isExist(self.dir) then
        Fs:writeTo(self.dir,JSON:stringify(cfg,true))
    end
    local loadcfg = JSON:parse(Fs:readFrom(self.dir))
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

---根据path获取配置项值
---@param path string
---@return any
function Settings:get(path)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前获得配置项 %s',path)
        return nil
    end
    return table.getKey(cfg,path)
end

---根据path设置配置项值
---@param path string
---@param value any
---@return boolean
function Settings:set(path,value)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前设定配置项 %s',path)
        return false
    end
    table.setKey(cfg,path,value)
    self:save()
    return true
end

---保存配置项
---@return boolean
function Settings:save()
    if not self.loaded then
        Log:Error('尝试在配置项初始化前保存')
        return false
    end
    Fs:writeTo(self.dir,JSON:stringify(cfg,true))
    return true
end

return Settings