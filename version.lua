--[[ ----------------------------------------

    [Main] Version manager.

--]] ----------------------------------------

require "native-type-helper"
require "logger"

local Log = Logger:new('Version')
Version = {
    data = {},
    register = function (_,major,minor,revision)
        local a = Version
        table.insert(a.data,{
            major = major,
            minor = minor,
            revision = revision
        })
    end
}

Version.register('Main',1,0,0)
Version.register('Repo',1,0,0)
Version.register('Installed',1,0,0)
Version.register('PdbHashTab',1,0,0)
Version.register('Package',1,0,0)
Version.register('InstalledPackage',1,0,0)

---@alias VersionType
---|> 1     # Main
---|  2     # Repo
---|  3     # Installed
---|  4     # PdbHashTable
---|  5     # Package
---|  6     # InstalledPackage

---获取版本 (obj)
---@param num VersionType
---@return table
function Version:get(num)
    assert(type(num) == 'number')
    return self.data[num]
end

---获取版本 (int)
---@param num VersionType
---@return integer
function Version:getNum(num)
    assert(type(num) == 'number')
    local a = self.data[num]
    return a.major*100 + a.minor*10 + a.revision
end

---获取版本 (str)
---@param num VersionType
---@return string
function Version:getStr(num)
    assert(type(num) == 'number')
    local a = self.data[num]
    return ('%s.%s.%s'):format(a.major,a.minor,a.revision)
end

ApplicableVersionChecker = {}

---检查`ver1`是否符合`method`
---@param ver1 string
---@param method string
---@return boolean
function ApplicableVersionChecker:check(ver1,method)
    -- 比较运算符:
    -- [大于]＞ [小于]＜ [等于]＝ [大于等于]≥ [小于等于]≤
    -- tips: 等于号可以省略
    -- e.g. "> 1.19.0" 相当于 major >= 1 || minor == 1 and major >=19 || minor == 1 and major == 10 and revision > 0
    -- 范围运算符:
    -- [区间]1~22
    -- e.g "1.19.1~22" 相当于 major == 1 && minor == 19 && 1 <= revision <= 22
    -- 特殊运算符:
    -- [全部]*
    local sym = method:sub(1,1)
    if sym == '*' then
        return true
    else
        local t = method:sub(3)
        if method:sub(1,2) == '>=' then
            return self:check(ver1,'>'..t) or self:check(ver1,'='..t)
        elseif method:sub(1,2) == '<=' then
            return self:check(ver1,'<'..t) or self:check(ver1,'='..t)
        end
    end
    if tonumber(sym) then
        sym = '='
        method = '=' .. method
    end
    local box = method:sub(2):split('.')
    local tpl = ver1:split('.')
    tpl = array.tonumber(tpl)
    if box[#box]:find('~') then --- ranged.
        local t = box[#box]:split('~')
        box = array.tonumber(box)
        for i=1,#box-1 do
            if tpl[i] ~= box[i] then
                return false
            end
        end
        if tpl[#box+1] >= tonumber(t[1]) and tpl[#box+1] <= tonumber(t[2]) then
            return true
        else
            return false
        end
    end
    box = array.tonumber(box)
    if sym == '>' then --- compared.
        for i=1,#box do
            if tpl[i] > box[i] then
                return true
            elseif tpl[i] < box[i] then
                return false
            end
        end
        return false
    elseif sym == '<' then
        for i=1,#box do
            if tpl[i] < box[i] then
                return true
            elseif tpl[i] > box[i] then
                return false
            end
        end
        return false
    elseif sym == '=' then
        for i=1,#box do
            if box[i] ~= tpl[i] then
                return false
            end
        end
        return true
    end
    Log:Error('[ApplicableChecker] Unknown symbol found "%s".',sym)
    return false
end

return Version,ApplicableVersionChecker