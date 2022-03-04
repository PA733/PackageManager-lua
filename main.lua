--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require('__init__')
require('logger')
require('native-type-helper')
require('cmdline')
require('package-manager')

Log = Logger:new('Main')

-- [CMD] Help

local HelpCommand = Command:register('help','显示帮助文本。',function (switches,arguments)
    CommandManager.Helper:printHelp(arguments['cmd'])
end)
HelpCommand.Argument:add('cmd','give cmd.','string',true)

-- [CMD] Install

local InstallCommand = Command:register('install','安装一个软件包',function (switches,arguments)
    
end)
InstallCommand.Switch:add('yes','跳过安装确认')

-- [CMD] Update.

local UpdateCommand = Command:register('update','执行升级操作',function ()
    
end)
UpdateCommand.Switch:add('yes','跳过升级确认')

-- [CMD] Remove

local RemoveCommand = Command:register('remove','删除一个软件包',function ()
    
end)
RemoveCommand.Switch:add('yes','跳过删除确认')
RemoveCommand.Switch:add('purge','同时清除数据')

-- [CMD] Purge

local PurgeCommand = Command:register('purge','清除指定软件的数据',function ()
    
end)
PurgeCommand.Switch:add('yes','跳过清除确认')

-- [CMD] Repo

local RepoCommand = Command:register('repo','管理仓库',function ()
    
end)
RepoCommand.Switch:add('check-all','检查配置的所有源')
RepoCommand.Switch:add('update','更新源')
RepoCommand.Switch:add('list','列出所有源')
RepoCommand.Argument:add('switch','选择源','string',true)

-- [CMD] Pack

local PackCommand = Command:register('pack','打包器',function ()
    
end)

-- [CMD] Config

local ConfigCommand = Command:register('config','配置LPM',function ()
    
end)
ConfigCommand.Switch:add('reset','重设为默认值')
ConfigCommand.Argument:add('update','更新该项为...','string',true)

-- [CMD] Cloud Protocol

local CloudCommand = Command:register('cloud-protocol','下载组件',function ()

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
CommandManager:execute(call_cmds)