--[[ ----------------------------------------

    [Deps] SHA1 Calculator.

--]] ----------------------------------------

require "native-type-helper"
Wf = require "winfile"

SHA1 = {
    exec = 'certutil'
}

function SHA1:file(path)
    local res = Wf.popen(('%s -hashfile "%s" SHA1'):format(self.exec,path)):read('*a')
    local stat = res:find('ERROR') == nil
    local sha1
    if stat then
        sha1 = res:split('\n')[2]
    end
    return stat,sha1
end

return SHA1