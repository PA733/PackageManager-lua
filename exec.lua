--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "__init__"
require "logger"
require "native-type-helper"
require "JSON"
require "settings"
require "cmdline"
require "package-manager"
require "cloud"
require "settings"
require "version"

Fs = require "filesystem"
Log = Logger:new('Main')

--------------------- Initialization ---------------------

Settings:init()

----------------------------------------------------------

if Settings:get('output.noColor') then
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
    if dict.args['switch'] then

    end
    if dict.switch['check-all'] then
        
    end
    if dict.switch['update'] then
        
    end
    if dict.switch['list'] then
        
    end
end)
RepoCommand.Switch:add('check-all','检查配置的所有源')
RepoCommand.Switch:add('update','更新源')
RepoCommand.Switch:add('list','列出所有源')
RepoCommand.Argument:add('switch','另外选择一个源','string',true)
RepoCommand.Argument:add('set-branch','为当前源指定（一些）分支','table',true)

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
else
    Log:Error('没有命令键入，如需帮助请输入 "help"。')
end
