--[[ ----------------------------------------

    [Main] __init__

--]] ----------------------------------------

package.path = package.path..';./lib/?.lua'
FileSystem = require('filesystem')

--- Check developer mode.
DevMode = FileSystem:isExist('DevMode')

--- Change Code Page.
os.execute('chcp 65001 > nul')