--[[ ----------------------------------------

    [Deps] Command Handler.

--]] ----------------------------------------

require('logger')
require('native-type-helper')
local Log = Logger:new('Command')

local _cmds = {}

---@class Command
---@class CommandSwitch
---@class CommandArgument
Command = {
    _prefix = 'lpm',
    Argument = {},
    Switch = {}
}

--- 注册一个命令
---@param name string
---@param description string
---@param hidden boolean
---@return Command
function Command:register(name,description,callback,hidden)
    local origin = {
        name = name,
        description = description,
        hidden = hidden or false,
        Argument = {
            data = {}
        },
        Switch = {
            data = {}
        },
        handler = callback
    }
    setmetatable(origin,self)
    setmetatable(origin.Argument,self.Argument)
    setmetatable(origin.Switch,self.Switch)
    self.__index = self
    self.Argument.__index = self.Argument
    self.Switch.__index = self.Switch
    _cmds[name] = origin
    Log:Debug('Registering command: %s',name)
    return origin
end

--- 添加一个开关
---@param name string
---@param description string
---@return boolean
function Command.Switch:add(name,description)
    self.data[name] = {
        description = description
    }
    return true
end

--- 获取一个开关的信息
---@param name string
---@return CommandSwitch
function Command.Switch:get(name)
    return self.data[name]
end

--- 获取所有开关
---@return table
function Command.Switch:getAll()
    local rtn = {}
    for name,val in pairs(self.data) do
        rtn[#rtn+1] = name
    end
    return rtn
end

--- 添加一个参数
---@param name string
---@param description string
---@param type string
---@param canIgnore boolean
---@return boolean
function Command.Argument:add(name,description,type,canIgnore)
    canIgnore = canIgnore or false
    self.data[name] = {
        description = description,
        type = type,
        required = not canIgnore
    }
    return true
end

--- 获取一个参数信息
---@param name string
---@return CommandArgument
function Command.Argument:get(name)
    return self.data[name]
end

function Command.Argument:getAll()
    local rtn = {}
    for name,val in pairs(self.data) do
        rtn[#rtn+1] = name
    end
    return rtn
end

---@class CommandManager
CommandManager = {
    Helper = {}
}

--- 执行一个命令
---@param args table
---@return boolean
function CommandManager:execute(args)
    local function isArg(sth)
        return string.sub(sth,1,2) == '--'
    end
    local cmd = self:getCommand(args[1])
    if not cmd then
        Log:Error('未定义的指令\"%s\"，如需帮助请使用 help。',args[1])
        return false
    end
    local switches = {}
    local arguments = {}
    for n,switch in pairs(cmd.Switch:getAll()) do
        switches[switch] = false
    end
    for n,argument in pairs(cmd.Argument:getAll()) do
        arguments[argument] = '(*nil)'
    end
    local inErr = false
    for i=2,#args do
        local m = args[i]
        if not m then
            break
        end
        if isArg(m) then -- arg/swi or val
            local raArg = string.sub(m,3)
            if cmd.Switch:get(raArg) then
                if args[i+1] and not isArg(args[i+1]) then
                    Log:Error('语法错误，提供在 %s 的值没有对应的参数。',i+1)
                    inErr = true
                    break
                end
                switches[raArg] = true
            elseif cmd.Argument:get(raArg) then
                if not args[i+1] or isArg(args[i+1]) then
                    Log:Error('语法错误，参数 %s 的未提供值。',m)
                    inErr = true
                    break
                end
                local tarType = cmd.Argument:get(raArg).type
                if tarType == 'boolean' then
                    arguments[raArg] = toBool(args[i+1])
                elseif tarType == 'number' then
                    arguments[raArg] = tonumber(args[i+1])
                elseif tarType == 'string' then
                    arguments[raArg] = tostring(args[i+1])
                elseif tarType == 'table' then
                    arguments[raArg] = string.split(args[i+1],',')
                end
            else
                Log:Error('未定义的参数\"%s\"，如需帮助请使用 help --cmd %s。',m,args[1])
                inErr = true
                break
            end
        end
    end
    if not inErr then
        for arg,cont in pairs(arguments) do
            if cont == '(*nil)' then
                if cmd.Argument:get(arg).required then
                    Log:Error('缺少参数 %s，如需帮助请使用 help。',arg)
                    inErr = true
                    break
                else
                    arguments[arg] = nil
                end
            end
        end
        if not inErr then
            cmd.handler(switches,arguments)
        end
    end
    return false
end

--- 获取一个已注册命令
---@param name string
---@return Command
function CommandManager:getCommand(name)
    return _cmds[name]
end

--- 打印一个命令的帮助信息
---@param whatCmd string
function CommandManager.Helper:printHelp(whatCmd)
    local m
    if not whatCmd then
        whatCmd = _cmds
        m = '[options]'
    else
        local tCmd = _cmds[whatCmd]
        if not tCmd or tCmd.hidden then
            Log:Error('不存在的指令！')
            return
        end
        m = whatCmd
        whatCmd = { [whatCmd] = tCmd }
    end
    Log:Info('Usage: %s %s --[arguments|switches] ...',Command._prefix,m)
    Log:Info('Available options are:')
    for name,res in pairs(whatCmd) do
        if not res.hidden then
            Log:Info('      %s\t%s',name,res.description)
            for aname,ares in pairs(res.Argument.data) do
                local m = ''
                if ares.required then
                    m = '|required'
                end
                Log:Info('          %s - (%s%s) %s',aname,ares.type,m,ares.description)
            end
            for aname,ares in pairs(res.Switch.data) do
                Log:Info('          %s - (switch) %s',aname,ares.description)
            end
        end
    end
end

return Command,CommandManager