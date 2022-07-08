--[[ ----------------------------------------

    [Main] __init__

--]] ----------------------------------------

package.path = package.path..';./share/?.lua;./share/json/?.lua'
package.cpath = package.cpath..';./lib/?.dll'
FileSystem = require('filesystem')

--- Check developer mode.
DevMode = FileSystem:isExist('DevMode')

--- Change Code Page.
os.execute('chcp 65001 > nul')