--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "__init__"
require "logger"
require "native-type-helper"
require "cmdline"
require "package-manager"
require "cloud"

Fs = require "filesystem"
Log = Logger:new('Main')

JSON = {
	_base = require('dkjson')
}

LPM = {
    Version = {
        major = 1,
        minor = 0,
        revision = 0
    }
}

function LPM.Version:getNum()
    return self.major*100 + self.minor*10 + self.revision
end

function LPM.Version:getStr()
    return string.format('%s.%s%s',self.major,self.minor,self.revision)
end

function JSON.parse(str)
    local stat,rtn = pcall(JSON._base.decode,str)
    if stat then
        return rtn
    end
    Logger:Debug('Could not parse JSON, content = %s',str)
    return nil
end
function JSON.stringify(object)
    local stat,rtn = pcall(JSON._base.encode,object)
    if stat then
        return rtn
    end
    Logger:Debug('Could not stringify object.',object)
    return nil
end

--- Load config

local cfg = {
    version = LPM.Version:getNum(),
    output = {
        noColor = false
    }
}

local loadcfg = JSON.parse(Fs:readFrom('config.json'))
for n,path in pairs(table.getAllPaths(cfg,false)) do
    local m = table.getKey(loadcfg,path)
    if m ~= nil then
        table.setKey(cfg,path,m)
    else
        Log:Error('配置文件丢失 %s, 已使用默认值。',path)
    end
end

if cfg.output.noColor then
    Logger.setNoColor()
end

-- [CMD] Help

local HelpCommand = Command:register('help','显示帮助文本。',function (dict)
    CommandManager.Helper:printHelp(dict.pretext)
end)
HelpCommand.PreText:set('command',true)

-- [CMD] Install

local InstallCommand = Command:register('install','安装一个软件包',function (dict)
    
end)
InstallCommand.PreText:set('name')
InstallCommand.Switch:add('yes','跳过安装确认')
InstallCommand.Switch:add('fix-missing','修复安装')

-- [CMD] Update.

local UpdateCommand = Command:register('update','执行升级操作',function (dict)
    
end)
UpdateCommand.PreText:set('name')
UpdateCommand.Switch:add('yes','跳过升级确认')

-- [CMD] Remove

local RemoveCommand = Command:register('remove','删除一个软件包',function (dict)
    
end)
RemoveCommand.PreText:set('name')
RemoveCommand.Switch:add('yes','跳过删除确认')
RemoveCommand.Switch:add('purge','同时清除数据')

-- [CMD] Purge

local PurgeCommand = Command:register('purge','清除指定软件的数据',function (dict)
    
end)
PurgeCommand.PreText:set('name')
PurgeCommand.Switch:add('yes','跳过清除确认')

-- [CMD] Repo

local RepoCommand = Command:register('repo','管理仓库',function (dict)
    
end)
RepoCommand.Switch:add('check-all','检查配置的所有源')
RepoCommand.Switch:add('update','更新源')
RepoCommand.Switch:add('list','列出所有源')
RepoCommand.Argument:add('switch','选择源','string',true)

-- [CMD] Pack

local PackCommand = Command:register('pack','打包器',function (dict)
    
end)

-- [CMD] Config

local ConfigCommand = Command:register('config','配置LPM',function (dict)
    
end)
ConfigCommand.PreText:set('cfg')
ConfigCommand.Switch:add('reset','重设为默认值')
ConfigCommand.Argument:add('update','更新该项为...','string',true)

-- [CMD] Cloud Protocol

local CloudCommand = Command:register('cloud-protocol','下载组件',function (dict)

end)
CloudCommand.Switch:add('list','列出所有下载组件')
CloudCommand.Switch:add('test','测试并选中最优下载组件')

--- Developer Mode Actions

if DevMode then
    Log:Warn('You\'re in developer mode.')
end

--- Final Command Handler

local call_cmds = {}
for k,v in pairs(arg) do
    if k > 0 then
        call_cmds[k] = v
    end
end
if next(call_cmds) then
    CommandManager:execute(call_cmds)
end
