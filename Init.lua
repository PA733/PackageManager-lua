--[[ ----------------------------------------

    [Main] __init__

--]] ----------------------------------------

require('filesystem')

--- Check developer mode.
DevMode = Fs:isExist('DevMode')

--- Fix code page.
os.execute('chcp 65001 > nul')
