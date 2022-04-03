--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require "__init__"
require "logger"
require "native-type-helper"
require "JSON"
require "settings"
require "repo"
require "cloud"
require "version"

Fs = require "filesystem"
Parser = require "argparse"
Log = Logger:new('Main')

----------------------------------------------------------
-- |||||||||||||||||| Initialization |||||||||||||||||| --
----------------------------------------------------------

LpmOrder = {}
Command = Parser() {
    name = 'lpm',
    description = '为 LiteLoader 打造的包管理程序。',
    epilog = '获得更多信息，请访问: https://repo.litebds.com/。'
}

Settings:init()
Repo:init()

if Settings:get('output.noColor') then
    Logger.setNoColor()
end

if DevMode then
    Log:Warn('You\'re in developer mode.')
end

----------------------------------------------------------
-- ||||||||||||||||||||| Commands ||||||||||||||||||||| --
----------------------------------------------------------

LpmOrder.Install = Command:command 'install'
  :summary '安装一个软件包'
  :description '此命令将从目前选择的源中检索软件包，并尝试安装。'
LpmOrder.Install:argument('name','软件包名称')

LpmOrder.Update = Command:command 'update'
  :summary '执行升级操作'
  :description '此命令将先从仓库拉取最新软件包列表，然后检查本地已安装软件版本。'

LpmOrder.Remove = Command:command 'remove'
  :summary '删除一个软件包'
  :description '此命令将删除指定软件包但不清除软件储存的数据。'
LpmOrder.Remove:flag('-p --purge','同时清除数据（危险）。')
LpmOrder.Remove:argument('name','软件包名称')

LpmOrder.Purge = Command:command 'purge'
  :summary '清除指定软件的数据'
  :description '此命令将清除指定软件储存的数据，但不卸载该软件。'
LpmOrder.Purge:argument('name','软件包名称')

LpmOrder.AddRepo = Command:command 'add-repo'
  :summary '添加新仓库'
  :description '提供仓库描述文件链接以添加一个新仓库'
  :action (function ()
      
  end)
LpmOrder.AddRepo:argument('link','仓库描述文件下载链接')
LpmOrder.AddRepo:flag('--no-enable','仅添加仓库（跳过自动选中与更新）')

LpmOrder.ListRepo = Command:command 'list-repo'
  :summary '列出所有仓库'
  :description '此命令将列出所有已配置的仓库。'
  :action (function (dict)
    local repo_list = Repo:getAll()
    local repo_using = Settings:get('repo.use')
    Log:Info('已装载 %s 个仓库',#repo_list)
    for n,uuid in pairs(repo_list) do
        local a = Repo:getName(uuid)
        if uuid == repo_using then
            a = a .. '（Using）'
        end
        Log:Info('%s. %s - [%s]',n,a,uuid)
    end
  end)

LpmOrder.SetRepo = Command:command 'set-repo'
  :summary '设置默认仓库并更新软件列表'
  :description '此命令将设置一个已配置软件源并更新软件包列表。'
  :action (function (dict)
    local uuid = dict.UUID
    if Repo:isExist(uuid) then
        Settings:set('repo.use',uuid)
        Log:Info('成功设置 %s 为主要仓库',Repo:getName(uuid))
    else
        Log:Error('无法通过UUID（%s）找到仓库，请检查输入',uuid)
    end
  end)
LpmOrder.SetRepo:argument('UUID','目标仓库的UUID。')

LpmOrder.ListProtocol = Command:command 'list-protocol'
  :summary '列出下载所有组件'
  :description '此命令将列出所有已安装的下载组件。'
  :action (function (dict)
    local list = Cloud.Protocol:getAll()
    Log:Info('已装载 %s 个下载组件',#list)
    for k,v in pairs(list) do
        Log:Info('%s. %s',k,v)
    end
  end)

Command:flag('-y --yes','许可当前执行的命令发出的所有询问。')

----------------------------------------------------------
-- ||||||||||||||||| Command Executor ||||||||||||||||| --
----------------------------------------------------------

Command:parse(arg)