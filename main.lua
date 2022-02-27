--[[ ----------------------------------------

    [Main] LiteLoader Package Manager.

--]] ----------------------------------------

require('__init__')
require('logger')
require('native-type-helper')
require('cmdline')

Log = Logger:new('Main')

--- Init Commands

-- [[ help ]]
local HelpCommand = Command:register('help','Show command help.',function (switches,arguments)
    CommandManager.Helper:printHelp(arguments['cmd'])
end)
HelpCommand:addArgument('cmd','give cmd.','string',true)

-- [[ test ]]
if DevMode then
    local TestCommand = Command:register('test','Test only',function (switches,arguments)
        Log:Debug('Receive switches:')
        Log:Debug(table.toDebugString(switches))
        Log:Debug('Receive arguments:')
        Log:Debug(table.toDebugString(arguments))
        Log:Debug('End Of Callback.')
    end)
    TestCommand:addArgument('homo','114514','number',true)
    TestCommand:addArgument('homo233','1919810','string')
    TestCommand:addSwitch('enableHengAAA','qianbei')
    TestCommand:addSwitch('enable233','wtf')
end

--- Final Command Handler

local call_cmds = {}
for k,v in pairs(arg) do
    if k > 0 then
        call_cmds[k] = v
    end
end
CommandManager:execute(call_cmds)