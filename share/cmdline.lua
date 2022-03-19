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
---@class CommandPreText
Command = {
    _prefix = 'lpm',
    Argument = {},
    Switch = {},
    PreText = {}
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
        PreText = {
            data = {
                used = false
            }
        },
        handler = callback
    }
    setmetatable(origin,self)
    setmetatable(origin.Argument,self.Argument)
    setmetatable(origin.Switch,self.Switch)
    setmetatable(origin.PreText,self.PreText)
    self.__index = self
    self.Argument.__index = self.Argument
    self.Switch.__index = self.Switch
    self.PreText.__index = self.PreText
    _cmds[#_cmds+1] = {
        name = name,
        base = origin
    }
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

--- 设置预提供信息
---@param name string
---@param canIgnore boolean
---@return boolean
function Command.PreText:set(name,canIgnore)
    self.data = {
        used = true,
        name = name,
        required = not canIgnore
    }
    return true
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
    local pretext = nil
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
        elseif i == 2 then
            if cmd.PreText.data.used then
                pretext = m
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
        if cmd.PreText.data.required and not pretext then
            Log:Error('缺少参数 %s，如需帮助请使用 help。',cmd.PreText.data.name)
            inErr = true
        end
        if not inErr then
            cmd.handler({
                switch = switches,
                args = arguments,
                pretext = pretext
            })
        end
    end
    return false
end

--- 获取一个已注册命令
---@param name string
---@return Command
function CommandManager:getCommand(name)
    for i,da in pairs(_cmds) do
        if da.name == name then
            return _cmds[i].base
        end
    end
    return nil
end

--- 打印一个命令的帮助信息
---@param command string 可选，需要打印的指令名，留空打印所有。
function CommandManager.Helper:printHelp(command)
    local m
    if not command then
        command = _cmds
        m = '[options]'
    else
        local cmd = CommandManager:getCommand(command)
        if not cmd or cmd.hidden then
            Log:Error('不存在的指令！')
            return
        end
        m = command
        command = {
            {
                name = command,
                base = cmd
            }
        }
    end
    Log:Info('Usage: %s %s --[arguments|switches] ...',Command._prefix,m)
    Log:Info('Available options are:')
    for i,da in pairs(command) do
        local name = da.name
        local res = da.base
        if not res.hidden then
            local pt = ''
            local pret = res.PreText
            if pret.data.used then
                if pret.data.required then
                    pt = string.format(' <%s>',pret.data.name)
                else
                    pt = string.format(' [%s]',pret.data.name)
                end

            end
            Log:Info('      %s%s\t%s',name,pt,res.description)
            for aname,ares in pairs(res.Argument.data) do
                local f = ''
                if ares.required then
                    f = '|required'
                end
                Log:Info('          %s - (%s%s) %s',aname,ares.type,f,ares.description)
            end
            for aname,ares in pairs(res.Switch.data) do
                Log:Info('          %s - (switch) %s',aname,ares.description)
            end
        end
    end
end

return Command,CommandManager