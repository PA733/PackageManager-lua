--[[ ----------------------------------------

    [Main] __init__

--]] ----------------------------------------

package.path = package.path..';.\\lib\\?.lua;.\\lib\\?\\?.lua;.\\lib\\socket\\?.lua'
package.cpath = package.cpath..';.\\lib\\?\\core.dll;.\\lib\\?.dll'
FileSystem = require('filesystem')

--- Check developer mode.
DevMode = FileSystem:isExist('DevMode')

--- Change Code Page.
os.execute('chcp 65001 > nul')