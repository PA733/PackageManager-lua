require "__init__"
require "sha1"
require "filesystem"
require "json-safe"
local result = {}
Fs:iterator('content',function (nowpath,file)
    local a,b = SHA1:file(nowpath..file)
    if not a then
        print('error!')
    end
    ---print(nowpath,'|',file)
    result[(nowpath..file):sub(("content/"):len()+1)] = b
end)

print(JSON:stringify({
    verification = result
},true))