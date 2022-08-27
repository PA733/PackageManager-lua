--[[ ----------------------------------------

    [Main] __init__

--]] ----------------------------------------

package.path = package.path..';./share/?.lua;./share/json/?.lua'
package.cpath = package.cpath..';./lib/?.dll'

require('filesystem')

--- Check developer mode.
DevMode = Fs:isExist('DevMode')

--- Fix code page.
os.execute('chcp 65001 > nul')