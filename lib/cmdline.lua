--[[ ----------------------------------------

    [Deps] Command Handler.

--]] ----------------------------------------

require('logger')
require('native-type-helper')
local Log = Logger:new('Command')

Command = {
    _prefix = 'lpm'
}
local _cmds = {}

function Command:register(name,description,callback,hidden)
    local origin = {
        name = name,
        description = description,
        switches = {},
        arguments = {},
        hidden = hidden or false,
        handler = callback
    }
    setmetatable(origin,self)
    self.__index = self
    _cmds[name] = origin
    return origin
end

function Command:addSwitch(name,description)
    self.switches[name] = {
        description = description
    }
    return true
end

function Command:addArgument(name,description,type,canIgnore)
    canIgnore = canIgnore or false
    self.arguments[name] = {
        description = description,
        type = type,
        required = not canIgnore
    }
    return true
end

CommandManager = {
    Helper = {}
}

function CommandManager:execute(args)
    local function isArg(sth)
        return string.sub(sth,1,2) == '--'
    end
    local cmd = self:getCommand(args[1])
    if cmd then
        local switches = {}
        local arguments = {}
        for switch,v in pairs(cmd.switches) do
            switches[switch] = false
        end
        for argument,v in pairs(cmd.arguments) do
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
                if cmd.switches[raArg] then
                    if args[i+1] and not isArg(args[i+1]) then
                        Log:Error('语法错误，提供在 %s 的值没有对应的参数。',i+1)
                        inErr = true
                        break
                    end
                    switches[raArg] = true
                elseif cmd.arguments[raArg] then
                    if not args[i+1] or isArg(args[i+1]) then
                        Log:Error('语法错误，参数 %s 的未提供值。',m)
                        inErr = true
                        break
                    end
                    local tarType = cmd.arguments[raArg].type
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
                    if cmd.arguments[arg].required then
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
    else
        Log:Error('未定义的指令\"%s\"，如需帮助请使用 --help。',args[1])
    end
    return false
end

function CommandManager:getCommand(name)
    return _cmds[name]
end

function CommandManager.Helper:printHelp(whatCmd)
    if not whatCmd then
        whatCmd = _cmds
    else
        local tCmd = _cmds[whatCmd]
        if not tCmd or tCmd.hidden then
            Log:Error('不存在的指令！')
            return
        end
        whatCmd = { [whatCmd] = tCmd }
    end
    Log:Info('Usage: %s [options] --[arguments|switches]',Command._prefix)
    Log:Info('Available options are:')
    for name,res in pairs(whatCmd) do
        if not res.hidden then
            Log:Info('      %s\t\t%s',name,res.description)
            for aname,ares in pairs(res.arguments) do
                local m = ''
                if ares.required then
                    m = '|required'
                end
                Log:Info('          %s\t   (%s%s) %s',aname,ares.type,m,ares.description)
            end
            for aname,ares in pairs(res.switches) do
                Log:Info('          %s\t   %s',aname,ares.description)
            end
        end
    end
end