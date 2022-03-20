--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "__init__"
require "logger"
require "native-type-helper"
require "JSON"
require "settings"
require "cmdline"
require "core"
require "cloud"
require "version"

Fs = require "filesystem"
Log = Logger:new('Main')

--------------------- Initialization ---------------------

Settings:init()
Repo:init()

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
    if dict.args['set'] then
        local uuid = dict.args['set']
        if Repo:isExist(uuid) then
            Settings:set('repo.use',uuid)
            Log:Info('成功设置 %s 为主要仓库',Repo:getName(uuid))
        else
            Log:Error('无法通过UUID（%s）找到仓库，请检查输入',uuid)
        end
    end
    if dict.switch['check-all'] then
        
    end
    if dict.switch['update'] then
        
    end
    if dict.switch['list'] then
        local list = Repo:getAll()
        local using = Settings:get('repo.use')
        Log:Info('已装载 %s 个仓库',#list)
        for n,uuid in pairs(list) do
            local a = Repo:getName(uuid)
            if uuid == using then
                a = a .. '（Using）'
            end
            Log:Info('%s. %s - [%s]',n,a,uuid)
        end
    end
    if dict.args['set-branch'] then
        
    end
    if dict.args['add-branch'] then
        
    end
end)
RepoCommand.Switch:add('check-all','检查配置的所有源')
RepoCommand.Switch:add('update','更新源')
RepoCommand.Switch:add('list','列出所有源')
RepoCommand.Argument:add('set','另外选择一个源','string',true)
RepoCommand.Argument:add('set-branch','为当前源指定（一些）分支','table',true)
RepoCommand.Argument:add('add-branch','为当前源添加（一些）分支','table',true)

-- [CMD] Cloud Protocol

local CloudCommand = Command:register('cloud-protocol','下载组件',function (dict)
    if dict.switch['list'] then
        local list = Cloud.Protocol:getAll()
        Log:Info('已装载 %s 个下载组件',#list)
        for k,v in pairs(list) do
            Log:Info('%s. %s',k,v)
        end
    end
end)
CloudCommand.Switch:add('list','列出所有下载组件')

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
