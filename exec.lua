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
require "json-safe"
require "logger"
require "7zip"
require "argparse"
require "cloud"
require "cURL"
require "filesystem"
require "native-type-helper"
require "sha1"
require "temp"

require "environment"
require "version"
require "settings"
require "i18n"
require "bds"
require "pkgmgr"
require "repo"

----------------------------------------------------------
-- |||||||||||||||||| Initialization |||||||||||||||||| --
----------------------------------------------------------

local Parser = require "argparse"
local Log = Logger:new('LPM')

Order = {}
Command = Parser() {
  name = 'lpm',
  description = '为 LiteLoader 打造的包管理程序。',
  epilog = '获得更多信息，请访问: https://repo.litebds.com/。'
}

Fs:mkdir('data')

local stat, msg = pcall(function()
  assert(Temp:init(), 'TempHelper')
  assert(Settings:init(), 'ConfigManager')
  assert(P7zip:init(), '7zHelper')
  assert(Repo:init(), 'RepoManager')
  assert(PackMgr:init(), 'LocalPackageManager')
  assert(BDS:init(), 'BDSHelper')
end)
if not stat then
  Log:Error('%s 类初始化失败，请检查。', msg)
  return
end

if Settings:get('output.no_color') then
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
    :description '此命令将从源中检索软件包，并 安装。'
    :action(function(dict)
      local name = dict.name
      if name:sub(name:len() - 3) == '.' .. ENV.INSTALLER_EXTNAME then
        PackMgr:install(name, dict.yes)
        return
      end
      local result = PkgDB:search(dict.name, false, dict.use_highest, dict.use_uuid)
      if #result.data == 0 then
        Log:Error('找不到名为 %s 的软件包', dict.name)
        return
      end
      if not result.isTop then
        Log:Warn('在最高优先级仓库中找不到 %s, 以下是来自其他仓库的结果, 输入序号以选择或回车取消安装。')
      end
      for n, res in pairs(result.data) do
        Log:Print('[%s] >> (%s/%s) %s - %s', n, Repo:getName(res.uuid), res.class, res.name, res.version)
      end
      Log:Print('您可以输入结果序号来查看软件包详细信息，或回车退出程序。')
      Log:Print('(%s-%s) > ', 1, #result.data)
      local chosed = result.data[tonumber(io.read())]
      if not chosed then
        return
      end
      Log:Info('正在下载 %s ...', chosed.name)
      local temp_main = Temp:getFile()
      if not Cloud:NewTask {
        url = chosed.download,
        writefunction = Fs:open(temp_main, 'wb')
      } then
        Log:Error('下载 %s 时发生错误。', chosed.name)
        return
      end
      Log:Info('正在解压缩 %s ...', chosed.name)
      local res, path = P7zip:extract(temp_main)
      if not res then
        Log:Error('解包 %s 时发生错误。', chosed.name)
        return
      end
      local pkg_self = JSON:parse(Fs:readFrom(path))
      if not pkg_self then
        Log:Error('解析 %s 的自述文件时发生错误。', chosed.name)
        return
      end
      if not PackMgr:verify(path, pkg_self) then
        return
      end
      Log:Error('正在处理依赖关系...')
      if not OrderHelper:handleDependents(pkg_self,dict.use_highest) then
        return
      end
    end)
Order.Install:argument('name', '软件包名称')
Order.Install:flag('--use-highest', '仅使用最高优先级的仓库')
Order.Install:flag('--use-uuid', '使用UUID索引')

Order.Update = Command:command 'update'
    :summary '执行升级操作'
    :description '此命令将先从仓库拉取最新软件包列表，然后升级本地已安装软件版本。如果提供name，则单独升级指定软件包。'
    :action(function(dict)
      local name = dict.name
      if name then
        if name:sub(name:len() - 3) == '.' .. ENV.INSTALLER_EXTNAME then
          Log:Info('正在读取即将升级的软件包列表...')
          PackMgr:update(name, dict.yes)
        else

        end
        return
      end
      for _, uuid in pairs(Repo:getAllEnabled()) do
        Repo:update(uuid)
      end
    end)
Order.Update:argument('name', '软件包名称'):args '?'

Order.Remove = Command:command 'remove'
    :summary '删除一个软件包'
    :description '此命令将删除指定软件包但不清除软件储存的数据。'
    :action(function(dict)
      local uuid = PackMgr:getUuidByName(dict.name)
      if not uuid then
        Log:Error('找不到软件包 %s，因此无法删除。', dict.name)
        return
      end
      PackMgr:remove(uuid, dict.purge)
    end)
Order.Remove:flag('-p --purge', '同时清除数据 (危险)')
Order.Remove:argument('name', '软件包名称')

Order.Purge = Command:command 'purge'
    :summary '清除指定软件的数据'
    :description '此命令将清除指定软件储存的数据 (危险)，但不卸载该软件。'
    :action(function(dict)
      local uuid = PackMgr:getUuidByName(dict.name)
      if not uuid then
        Log:Error('找不到软件包 %s，因此无法清除数据。', dict.name)
        return
      end
      PackMgr:purge(uuid)
    end)
Order.Purge:argument('name', '软件包名称')

Order.List = Command:command 'list'
    :summary '列出已安装软件包'
    :description '此命令将列出所有已经安装的软件包'
    :action(function(dict)
      local list = PackMgr:getInstalledList()
      Log:Info('已安装 %s 个软件包', #list)
      for n, uuid in pairs(list) do
        local pkg = PackMgr:getInstalled(uuid)
        if pkg then
          Log:Info('[%d] %s - %s (%s)', n, pkg.name, pkg.version, uuid)
        end
      end
    end)

Order.AddRepo = Command:command 'add-repo'
    :summary '添加新仓库'
    :description '提供仓库描述文件链接以添加一个新仓库'
    :action(function(dict)
      local metafile = ''
      Log:Info('正在下载描述文件...')
      local res = Cloud:NewTask {
        url = dict.link,
        writefunction = function(str)
          metafile = metafile .. str
        end
      }
      if not res then
        Log:Error('下载描述文件时出错。')
        return
      end
      local parsed_file = JSON:parse(metafile)
      if not parsed_file then
        Log:Error('解析描述文件时出错。')
        return
      end
      if parsed_file.format_version ~= Version:getNum(2) then
        Log:Error('描述文件版本与管理器不匹配。')
        return
      end
      local group
      local ver = BDS:getVersion()
      local can_use = {}
      local use_latest = false
      for _, gp in pairs(parsed_file.root.groups) do
        if ApplicableVersionChecker:check(ver, gp.required_game_version) then
          if gp.name == 'latest' and BDS:isLatest() then
            use_latest = true
            break
          end
          can_use[#can_use + 1] = gp.name
        end
      end
      if use_latest then
        group = 'latest'
      elseif #can_use == 1 then
        group = parsed_file.root.groups[can_use[1]].name
      elseif #can_use == 0 then
        Log:Error('当前选择的仓库无法适配当前的BDS版本。')
        return
      else
        Log:Print('当前仓库有以下可以选择的资源组：')
        for n, name in pairs(can_use) do
          Log:Print('[%d] >> %s', n, name)
        end
        Log:Write('(%d-%d) > ', 1, #can_use)
        local chosed = can_use[tonumber(io.read())]
        if chosed then
          group = chosed
        else
          Log:Error('输入错误！')
          return
        end
      end
      if not Repo:add(parsed_file.identifier, dict.link, group, not (dict.no_update)) then
        Log:Error('仓库添加失败')
        return
      end
      Log:Info('成功添加仓库 %s，标识符为 %s。', parsed_file.name, parsed_file.identifier)
    end)
Order.AddRepo:argument('link', '仓库描述文件下载链接')
Order.AddRepo:flag('--no-update', '仅添加仓库（跳过自动启用与更新）')

Order.RmRepo = Command:command 'rm-repo'
    :summary '删除一个仓库'
    :description '此命令将删除现存的仓库'
    :action(function(dict)
      if not dict.uuid then
        local plzUUID = OrderHelper:pleaseUUID()
        if not plzUUID then
          return
        end
        dict.uuid = plzUUID
      end
      if Repo:remove(dict.uuid) then
        Log:Info('仓库（%s）已被删除', dict.uuid)
      end
    end)
Order.RmRepo:argument('uuid', '目标仓库的UUID'):args '?'

Order.ListRepo = Command:command 'list-repo'
    :summary '列出所有仓库'
    :description '此命令将列出所有已配置的仓库。'
    :action(function(dict)
      local repo_list = Repo:getAll()
      local enabled, disabled = Repo:getPriorityList(), Repo:getAll()
      Log:Info('已配置 %s 个仓库。', #repo_list)
      Log:Info('已启用 %s 个仓库, 它们的优先级为:', #enabled)
      for n, uuid in pairs(enabled) do
        array.remove(disabled, uuid)
        Log:Info('%s. %s - [%s]', n, Repo:getName(uuid), uuid)
      end
      if #disabled ~= 0 then
        Log:Info('已禁用 %s 个仓库', #disabled)
        for n, uuid in pairs(disabled) do
          Log:Info('%s. %s - [%s]', n, Repo:getName(uuid), uuid)
        end
      end
    end)

Order.SetRepo = Command:command 'set-repo'
    :summary '重设使用的仓库'
    :description '此命令将重设仓库开关状态并更新软件包列表。'
    :action(function(dict)
      if not dict.uuid or dict.uuid == '?' then
        local plzUUID = OrderHelper:pleaseUUID()
        if not plzUUID then
          return
        end
        dict.uuid = plzUUID
      end
      Repo:setStatus(dict.uuid, dict.status == 'enable')
    end)
Order.SetRepo:argument('uuid', '目标仓库的UUID。'):args '?'
Order.SetRepo:argument('status', '开或关')
    :choices { 'enable', 'disable' }

Order.MoveRepo = Command:command 'move-repo'
    :summary '设置仓库优先级'
    :description '此命令将重设仓库优先级。'
    :action(function(dict)
      if not dict.uuid or dict.uuid == '?' then
        local plzUUID = OrderHelper:pleaseUUID(true)
        if not plzUUID then
          return
        end
        dict.uuid = plzUUID
      end
      if not Repo:isEnabled(dict.uuid) then
        Log:Error('目标仓库不存在或未开启。')
        return
      end
      Repo:movePriority(dict.uuid, dict.action == 'down')
      Log:Info('已更新仓库优先级。')
    end)
Order.MoveRepo:argument('uuid', '目标仓库的UUID。'):args '?'
Order.MoveRepo:argument('action', '提到最前或拉到最后')
    :choices { 'up', 'down' }

Order.ResetRepoGroup = Command:command('repo-reset-group')
    :summary '重设仓库资源组'
    :description '此命令将打印可用资源组列表，并允许重新选择资源组。'
    :action(function(dict)
      if not dict.uuid then
        local plzUUID = OrderHelper:pleaseUUID(true)
        if not plzUUID then
          return
        end
        dict.uuid = plzUUID
      end
      if not Repo:isExist(dict.uuid) then
        Log:Error('不存在的仓库！')
        return
      end
      local list = Repo:getAvailableGroups(dict.uuid, dict.update)
      if not list or #list < 1 then
        Log:Error('当前仓库没有资源分组适合您的BDS。')
        return
      end
      Log:Print('请选择要使用的资源分组...')
      for n, name in pairs(list) do
        Log:Print('[%s] >> %s', n, name)
      end
      Log:Write('(%d-%d) > ', 1, #list)
      local chosed = list[tonumber(io.read())]
      if not chosed then
        Log:Error('输入错误！')
        return
      end
      Repo:setGroup(dict.uuid, chosed)
      Log:Info('设置成功。')

    end)
Order.ResetRepoGroup:argument('uuid', '目标仓库UUID。'):args '?'
Order.ResetRepoGroup:flag('--update', '更新模式')

Order.ListProtocol = Command:command 'list-protocol'
    :summary '列出下载所有组件'
    :description '此命令将列出所有已安装的下载组件。'
    :action(function(dict)
      local list = Cloud:getAllProtocol()
      Log:Info('已装载 %s 个下载组件', #list)
      for k, v in pairs(list) do
        Log:Info('%s. %s', k, v)
      end
    end)

Order.Search = Command:command 'search'
    :summary '搜索软件包'
    :description '此命令将按照要求在数据库中搜索软件包'
    :action(function(dict)
      local result = PkgDB:search(dict.name, dict.use_highest, not dict.strict_mode, dict.use_uuid)
      if #result.data == 0 then
        Log:Error('找不到名为 %s 的软件包', dict.name)
        return
      end
      if result.isTop then
        Log:Info('这是来自最高优先级仓库的结果:')
      end
      for n, res in pairs(result.data) do
        Log:Print('[%s] >> (%s/%s) %s - %s', n, Repo:getName(res.uuid), res.class, res.name, res.version)
      end
      Log:Print('您可以输入结果序号来查看软件包详细信息，或回车退出程序。')
      Log:Print('(%s-%s) > ', 1, #result.data)
      local chosed = result.data[tonumber(io.read())]
      if not chosed then
        return
      end
      Log:Info('软件包详细信息:')
      Log:Info('名称: %s', chosed.name)
      Log:Info('唯一标识符: %s', chosed.uuid)
      Log:Info('版本: %s', chosed.versio)
      Log:Info('贡献者: %s', chosed.contributors)
      Log:Info('简介: %s', chosed.description)
    end)
Order.Search:argument('name', '软件包名称'):args '?'
Order.Search:flag('--use-highest', '仅使用最高优先级的仓库')
Order.Search:flag('--use-uuid', '使用UUID查找')
Order.Search:flag('--strict-mode', '关闭模糊匹配')

Command:flag('-y --yes', '许可当前执行的命令发出的所有询问。')

----------------------------------------------------------
-- ||||||||||||||||| Command Helper ||||||||||||||||| --
----------------------------------------------------------

OrderHelper = {}

---UUID助手
---@param shouldEnabled? boolean
---@return string|nil UUID
function OrderHelper:pleaseUUID(shouldEnabled)
  local list
  if shouldEnabled then
    list = Repo:getAllEnabled()
  else
    list = Repo:getAll()
  end
  Log:Print('请选择仓库以提供 UUID 参数:')
  for n, uuid in pairs(list) do
    Log:Print('[%s] >> %s - [%s]', n, Repo:getName(uuid), uuid)
  end
  Log:Write('(%d-%d) > ', 1, #list)
  local chosed = list[tonumber(io.read())]
  if not chosed then
    Log:Error('输入错误！')
    return nil
  end
  return chosed
end

---为某软件包处理依赖
---@param pkg table 软件包Self的表对象
---@param top_only? boolean 是否只使用顶级仓库
---@return boolean
function OrderHelper:handleDependents(pkg,top_only)
  local downloaded = {}
  for n, against in pairs(pkg.conflict) do
    local instd = PackMgr:getInstalled(against.uuid)
    if instd and ApplicableVersionChecker:check(instd.version,against.version) then
      Log:Error('无法处理 %s 的依赖, 其与软件包 %s(%s) 冲突。',pkg.name,instd.name,against.version)
      return false
    end
  end
  for n, rely in pairs(pkg.depends) do --- short information for depends(rely)
    Log:Info('(%d/%d) 正在处理 %s ...', n, #pkg.depends, rely.name)
    local tpack = PkgDB:search(pkg.uuid, false, top_only, true)
    if #tpack.data == 0 then
      Log:Error('无法处理依赖 %s, 因为在仓库中找不到软件。', rely.name)
      return false
    end
    local m = tpack.data[1]
    local dpath = Temp:getFile()
    if not Cloud:NewTask {
      url = m.download,
      path = dpath
    } then
      Log:Error('无法处理依赖 %s, 因为下载失败。', rely.name)
      return false
    end
    Log:Info('(%d/%d) 正在解压缩 %s ...', n, #pkg.depends, pkg.name)
    local tres, tpath = P7zip:extract(dpath)
    if not tres then
      Log:Error('无法处理依赖 %s, 因为解包 %s 时发生错误。', rely.name, pkg.name)
      return false
    end
    local dpkg_self = JSON:parse(Fs:readFrom(tpath))
    if not dpkg_self then
      Log:Error('无法处理依赖 %s, 因为解析 %s 的自述文件时发生错误。', rely.name, pkg.name)
      return false
    end
    if not PackMgr:verify(tpath, dpkg_self) then
      Log:Error('无法处理依赖 %s, 因为无法验证其软件包。', rely.name)
      return false
    end --- pre-check-completed.
    if not self:handleDependents(dpkg_self,top_only) then
      Log:Error('无法处理依赖 %s, 因为遇到了无法处理的嵌套依赖关系。',rely.name)
      return false
    end
    downloaded[#downloaded+1] = {rely.name,dpath}
  end
  for n,pk in pairs(downloaded) do
    if not PackMgr:install(pk[2],true) then
      Log:Error('无法处理依赖 %s, 因为安装失败。',pk[1])
      return false
    end
  end
  return true
end

----------------------------------------------------------
-- ||||||||||||||||| Command Executor ||||||||||||||||| --
----------------------------------------------------------

if #arg == 0 then
  arg[1] = '-h'
end

Command:parse(arg)

----------------------------------------------------------
-- |||||||||||||||| UnInitialization |||||||||||||||||| --
----------------------------------------------------------

Repo:uninit()
Temp:free()