--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "__init__"
require "logger"
require "native-type-helper"
require "JSON"
require "settings"
require "cmdline"
require "repo"
require "cloud"
require "version"

Fs = require "filesystem"
Log = Logger:new('Main')

--------------------- Initialization ---------------------

Settings:init()
Repo:init()

if Settings:get('output.noColor') then
    Logger.setNoColor()
end

if DevMode then
    Log:Warn('You\'re in developer mode.')
end

--------------------- Command Handler ---------------------

Command.Handler = {

    help = function (dict)
        CommandManager.Helper:printHelp(dict.pretext)
    end,

    install = function (dict)

    end,

    update = function (dict)

    end,

    remove = function (dict)

    end,

    purge = function (dict)

    end,

    repo = function (dict)
        local repo_list = Repo:getAll()
        local repo_using = Settings:get('repo.use')
        if dict.args['set'] then
            local uuid = dict.args['set']
            if Repo:isExist(uuid) then
                Settings:set('repo.use',uuid)
                Log:Info('成功设置 %s 为主要仓库',Repo:getName(uuid))
            else
                Log:Error('无法通过UUID（%s）找到仓库，请检查输入',uuid)
            end
        elseif dict.switch['update'] then
            Log:Info('目前正在使用仓库 %s',Repo:getName(repo_using))
            Log:Info('正在获取仓库摘要信息...')
            local link = Repo:getLink(repo_using)
        elseif dict.switch['list'] then
            Log:Info('已装载 %s 个仓库',#repo_list)
            for n,uuid in pairs(repo_list) do
                local a = Repo:getName(uuid)
                if uuid == repo_using then
                    a = a .. '（Using）'
                end
                Log:Info('%s. %s - [%s]',n,a,uuid)
            end
        end
    end,

    cloud = function (dict)
        if dict.switch['list'] then
            local list = Cloud.Protocol:getAll()
            Log:Info('已装载 %s 个下载组件',#list)
            for k,v in pairs(list) do
                Log:Info('%s. %s',k,v)
            end
        end
    end

}

-------------------- Command Registry --------------------

HelpCommand = Command:register('help','显示帮助文本。')
InstallCommand = Command:register('install','安装一个软件包')
UpdateCommand = Command:register('update','执行升级操作')
RemoveCommand = Command:register('remove','删除一个软件包')
PurgeCommand = Command:register('purge','清除指定软件的数据')
RepoCommand = Command:register('repo','管理仓库')
CloudCommand = Command:register('cloud','下载组件')

---------------------- Command Setup ----------------------

CloudCommand.Switch:add('list','列出所有下载组件')
RepoCommand.Switch:add('update','更新源')
RepoCommand.Switch:add('list','列出所有源')
RepoCommand.Argument:add('set','另外选择一个源','string',true)
PurgeCommand.PreText:set('name')
PurgeCommand.Switch:add('yes','跳过清除确认')
RemoveCommand.PreText:set('name')
RemoveCommand.Switch:add('yes','跳过删除确认')
RemoveCommand.Switch:add('purge','同时清除数据')
UpdateCommand.PreText:set('name')
UpdateCommand.Switch:add('yes','跳过升级确认')
HelpCommand.PreText:set('command',true)
InstallCommand.PreText:set('name')
InstallCommand.Switch:add('yes','跳过安装确认')
InstallCommand.Switch:add('fix-missing','修复安装')

-------------------- Command Executor --------------------

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
