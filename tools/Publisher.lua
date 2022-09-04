--[[ ----------------------------------------

    [Tools] Publisher.

--]] ----------------------------------------

Publisher = {}

---生成SHA1校验
---@param path string
function Publisher:generateVerification(path)
    if not (Fs:isExist(path) and Fs:isExist(path..'/content')) then
        return -1
    end
    local verify = {}
    local stopAndFailed = false
    local stopped = ''
    Fs:iterator(path..'/content/',function (nowpath,file)
        if stopAndFailed then
            return
        end
        local stat,sha1 = SHA1:file(nowpath..file)
        if not stat then
            stopped = nowpath..file
            stopAndFailed = true
        else
            verify[(nowpath..file):sub((path..'content/'):len()+1)] = sha1
        end
    end)
    if stopAndFailed then
        return -2,stopped
    end
    Fs:writeTo(path..'/verification.json',JSON:stringify({
        data = verify
    },true))
    return 0
end

function Publisher:makePackage(path)
    return P7zip:archive(path..'/*',('%s/../%s_%s.lpk'):format(path,Fs:splitDir(path).file,JSON:parse(Fs:readFrom(path..'/self.json')).version))
end