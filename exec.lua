--[[
     __         ______   __    __
    /\ \       /\  == \ /\ "-./  \
    \ \ \____  \ \  _-/ \ \ \-./\ \
     \ \_____\  \ \_\    \ \_\ \ \_\
      \/_____/   \/_/     \/_/  \/_/
    LiteLoader Package Manager,
    Author: LiteLDev.
]]

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

Order = {}
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

Order.Install = Command:command 'install'
  :summary '安装一个软件包'
  :description '此命令将从源中检索软件包，并尝试安装。'
Order.Install:argument('name','软件包名称')

Order.Update = Command:command 'update'
  :summary '执行升级操作'
  :description '此命令将先从仓库拉取最新软件包列表，然后检查本地已安装软件版本。'

Order.Remove = Command:command 'remove'
  :summary '删除一个软件包'
  :description '此命令将删除指定软件包但不清除软件储存的数据。'
Order.Remove:flag('-p --purge','同时清除数据（危险）。')
Order.Remove:argument('name','软件包名称')

Order.Purge = Command:command 'purge'
  :summary '清除指定软件的数据'
  :description '此命令将清除指定软件储存的数据，但不卸载该软件。'
Order.Purge:argument('name','软件包名称')

Order.AddRepo = Command:command 'add-repo'
  :summary '添加新仓库'
  :description '提供仓库描述文件链接以添加一个新仓库'
  :action (function (dict)
    local metafile = ''
    local res = Cloud:NewTask {
        url = dict.link,
        writefunction = function (str)
            metafile = metafile .. str
        end
    }
    if res then
        local parsed_file = JSON.parse(metafile)
        if parsed_file then
            if parsed_file.format_version == Version:getNum(1) then
                if Repo:add(parsed_file.identifier,parsed_file.name,dict.link,not(dict.no_enable)) then
                    Log:Info('成功添加仓库 %s，标识符为 %s。',parsed_file.name,parsed_file.identifier)
                    if not dict.no_enable then
                        Repo:setStatus(parsed_file.identifier,false)
                        -- update repo here.
                    end
                else
                    Log:Error('仓库添加失败')
                end
            else
                Log:Error('描述文件版本与管理器不匹配。')
            end
        else
            Log:Error('解析描述文件时出错。')
        end
    else
        Log:Error('下载描述文件时出错。')
    end
  end)
Order.AddRepo:argument('link','仓库描述文件下载链接')
Order.AddRepo:flag('--no-enable','仅添加仓库（跳过自动启用与更新）')

Order.RmRepo = Command:command 'rm-repo'
  :summary '删除一个仓库'
  :description '此命令将删除现存的仓库'
  :action (function (dict)
    if Repo:remove(dict.uuid) then
      Log:Info('仓库（%s）已被删除',dict.uuid)
    end
  end)
Order.RmRepo:argument('uuid','目标仓库的UUID')

Order.ListRepo = Command:command 'list-repo'
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

Order.SetRepo = Command:command 'set-repo'
  :summary '开启或关闭指定仓库'
  :description '此命令将重设仓库开关状态并更新软件包列表。'
  :action (function (dict)
    if Repo:setStatus(dict.uuid,dict.status == 'enable') then
      Log:Info('仓库状态已更新。')
    end
  end)
Order.SetRepo:argument('uuid','目标仓库的UUID。')
Order.SetRepo:argument('status','开或关')
  :choices {'enable','disable'}

Order.ListProtocol = Command:command 'list-protocol'
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