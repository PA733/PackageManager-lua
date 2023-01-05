#!/usr/bin/env lua
package.preload['Init'] = (function (...)
--[[ ----------------------------------------

    [Main] __init__

--]] ----------------------------------------

package.path = package.path..';./share/?.lua;./share/json/?.lua'
package.cpath = package.cpath..';./lib/?.dll'

require('filesystem')

--- Check developer mode.
DevMode = Fs:isExist('DevMode')

--- Fix code page.
os.execute('chcp 65001 > nul') end)
package.preload['filesystem'] = (function (...)
--[[ ----------------------------------------

    [Deps] Lua File System.

--]] ----------------------------------------

require "native-type-helper"
local wf = require("winfile")
-- local dir_sym = package.config:sub(1,1)
local dir_sym = '/'

Fs = {}

---标准化目录
---@param path string
---@return string
local function directory(path)
    path = (path..dir_sym):gsub('\\',dir_sym)
    return path
end

---分割文件名称与目录  
---例如 `C:/h/o/m/o.txt` --> {path = `C:/h/o/m/` file = `o.txt`}
---@param url string
---@return table
function Fs:splitDir(url)
    url = self:removeSymbolEndOfPathIfHas(directory(url))
    local path = url:sub(1,url:len()-url:reverse():find('/')+1)
    return {
        path = path,
        file = url:sub(path:len()+1)
    }
end

---获取当前路径
---@return string
function Fs:getCurrentPath()
    return directory(wf.currentdir())
end

---目录迭代器
---@param path? string
---@param callback function 原型 `cb(nowpath,file)`
---@return boolean
function Fs:iterator(path,callback)
    path = path or '.'
    path = directory(path)
    for file in wf.dir(path) do
        if file ~= '.' and file ~= '..' then
            local attr = wf.attributes(path..file)
            if not attr then
                -- do nothing.
            elseif attr.mode == 'directory' then
                self:iterator(path..file..dir_sym,callback)
            elseif attr.mode == 'file' then
                callback(path,file)
            end
        end
    end
    return true
end

---获取目录下文件数目
---@param path string
---@return integer
function Fs:getFileCount(path)
    local rtn = 0
    Fs:iterator(path,function (nowpath,file)
        rtn = rtn + 1
    end)
    return rtn
end

---(sync)将内容写入至某文件
---@param path string
---@param content any
---@return boolean
function Fs:writeTo(path,content)
	local file = assert(wf.open(path, "wb"))
	file:write(content)
	file:close()
    return true
end

---(sync)读入某文件
---@param path string
---@return string
function Fs:readFrom(path)
    local file = assert(wf.open(path, "rb"))
    local content = file:read("*all")
    file:close()
    return content
end

---创建目录(可以递归)
---@param path string
---@return boolean
function Fs:mkdir(path)
    path = directory(path)
    local dirs = path:split(dir_sym)
    for k,v in pairs(dirs) do
        wf.mkdir(table.concat(dirs,dir_sym,1,k)..dir_sym)
    end
    return true
end

---删除目录
---@param path string
---@return boolean
function Fs:rmdir(path)
    return wf.execute(('rd "%s" /s /q'):format(path))
end

---获取文件大小
---@param path string
---@return number
function Fs:getFileSize(path)
    return wf.attributes(path).size
end

---获取路径类型，常用的有 `file` `directory`
---@param path string
---@return string
function Fs:getType(path)
    return wf.attributes(self:removeSymbolEndOfPathIfHas(path)).mode
end

---获取路径是否存在（不区分目录）
---@param path string
---@return boolean
function Fs:isExist(path)
    return wf.attributes(self:removeSymbolEndOfPathIfHas(directory(path))) ~= nil
end

---文件是否内容一致
---@param path1 string
---@param path2 string
---@return boolean
function Fs:isSame(path1,path2)
    return Fs:readFrom(path1) == Fs:readFrom(path2)
end

---复制文件
---@param to_path string
---@param from_path string
function Fs:copy(to_path,from_path)
    Fs:writeTo(to_path,Fs:readFrom(from_path))
end

---删除文件
---@param path string
---@return boolean
function Fs:remove(path)
    return wf.remove(path)
end

---打开文件
---@param path string
---@param mode string
---@return file*
function Fs:open(path,mode)
    return wf.open(path,mode)
end

---删除路径尾的 `/`
---@param path string
---@return string
function Fs:removeSymbolEndOfPathIfHas(path)
    if path:sub(path:len()) == dir_sym then
        path = path:sub(1,path:len()-1)
        return self:removeSymbolEndOfPathIfHas(path)
    else
        return path
    end
end

return Fs end)
package.preload['json-safe'] = (function (...)
--[[ ----------------------------------------

    [Deps] Json.

--]] ----------------------------------------

require "logger"
local base = require "json-beautify"
local Log = Logger:new('Json')

JSON = {}

---解析JSON字符串
---@param str string
---@return table|nil
function JSON:parse(str)
    local stat,rtn = pcall(base.decode,str)
    if stat then
        return rtn
    end
    Log:Error('Could not parse JSON, content = "%s"',str)
    return nil
end

---将对象转换为JSON字符串
---@param object table
---@param beautify? boolean 是否美化
---@return string|nil
function JSON:stringify(object,beautify)
    beautify = beautify or false
    local stat,rtn
    if beautify then
        stat,rtn = pcall(base.beautify,object)
    else
        stat,rtn = pcall(base.encode,object)
    end
    if stat then
        return rtn
    end
    Log:Error('Could not stringify object.')
    return nil
end

return JSON end)
package.preload['logger'] = (function (...)
--[[ ----------------------------------------

    [Deps] Simple Logger.

--]] ----------------------------------------

local Sym = string.char(0x1b)
local emptyColor = {
    INFO = {
        date = '',type = '',title = '',text = ''
    },
    WARN = {
        date = '',type = '',title = '',text = ''
    },
    ERROR = {
        date = '',type = '',title = '',text = ''
    },
    DEBUG = {
        date = '',type = '',title = '',text = ''
    }
}

---@class Logger
Logger = {
    no_color = false
}

--- 创建一个新Logger
---@param title string
---@return Logger
function Logger:new(title)
    local origin = {}
    setmetatable(origin,self)
    self.__index = self
    origin.title = title or 'Unknown'
    origin.color = {
        INFO = {
            date = Sym..'[38;2;173;216;230m',
            type = Sym..'[38;2;032;178;170m',
            title = Sym..'[37m',
            text = Sym..'[0m'
        },
        WARN = {
            date = Sym..'[38;2;173;216;230m',
            type = Sym..'[93m',
            title = Sym..'[38;2;235;233;078m',
            text = Sym..'[0m'
        },
        ERROR = {
            date = Sym..'[38;2;173;216;230m',
            type = Sym..'[91m',
            title = Sym..'[38;2;239;046;046m',
            text = Sym..'[0m'
        },
        DEBUG = {
            date = Sym..'[38;2;173;216;230m',
            type = Sym..'[38;2;030;144;255m',
            title = Sym..'[37m',
            text = Sym..'[0m'
        }
    }
    return origin
end

local function rawLog(logger,type,what)
    local color
    if Logger.no_color then
        color = emptyColor[type]
    else
        color = logger.color[type]
    end
    for _,text in pairs(what:split('\n')) do
        io.write(
            color.date..os.date('%X')..' ',
            color.type..type..' ',
            color.title..'['..logger.title..'] '..text,
            color.text..'\n'
        )
    end
end

--- 全局禁用日志器颜色
---@return boolean
function Logger.setNoColor()
    Logger.no_color = true
    return true
end

--- 打印普通信息
---@param what string
---@param ... string|number
function Logger:Info(what,...)
    rawLog(self,'INFO',what:format(...))
end

--- 打印警告信息
---@param what string
---@param ... string|number
function Logger:Warn(what,...)
    rawLog(self,'WARN',what:format(...))
end

--- 打印错误信息
---@param what string
---@param ... string|number
function Logger:Error(what,...)
    rawLog(self,'ERROR',what:format(...))
end

--- 直接打印(有换行符)
---@param what string
---@param ... string|number
function Logger:Print(what,...)
    io.write(what:format(...)..'\n')
end

---直接打印(不换行)
---@param what string
---@param ... string|number
function Logger:Write(what,...)
    io.write(what:format(...))
end

--- 打印调试信息
---@param what any
---@param ... string|number
function Logger:Debug(what,...)
    if not DevMode then
        return
    end
    local T = type(what)
    if T == 'boolean' then
        what = tostring(what)
    elseif T == 'string' then
        what = what:format(...)
    elseif T == 'table' then
        what = table.toDebugString(what)
    end
    rawLog(self,'DEBUG',what)
    if T ~= 'string' then
        for k,v in pairs({...}) do
            self:Debug(v)
        end
    end
end

return Logger end)
package.preload['json-beautify'] = (function (...)
local json = require "json"
local type = type
local next = next
local error = error
local table_concat = table.concat
local table_sort = table.sort
local string_rep = string.rep
local setmetatable = setmetatable

local math_type

if _VERSION == "Lua 5.1" or _VERSION == "Lua 5.2" then
    local math_floor = math.floor
    function math_type(v)
        if v >= -2147483648 and v <= 2147483647 and math_floor(v) == v then
            return "integer"
        end
        return "float"
    end
else
    math_type = math.type
end

local statusVisited
local statusBuilder
local statusDep
local statusOpt

local defaultOpt = {
    newline = "\n",
    indent = "    ",
    depth = 0,
}
defaultOpt.__index = defaultOpt

local function encode_newline()
    statusBuilder[#statusBuilder+1] = statusOpt.newline..string_rep(statusOpt.indent, statusDep)
end

local encode_map = {}
local encode_string = json._encode_string
for k ,v in next, json._encode_map do
    encode_map[k] = v
end

local function encode(v)
    local res = encode_map[type(v)](v)
    statusBuilder[#statusBuilder+1] = res
end

function encode_map.string(v)
    statusBuilder[#statusBuilder+1] = '"'
    statusBuilder[#statusBuilder+1] = encode_string(v)
    return '"'
end

function encode_map.table(t)
    local first_val = next(t)
    if first_val == nil then
        if json.isObject(t) then
            return "{}"
        else
            return "[]"
        end
    end
    if statusVisited[t] then
        error("circular reference")
    end
    statusVisited[t] = true
    if type(first_val) == 'string' then
        local key = {}
        for k in next, t do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types: "..k)
            end
            key[#key+1] = k
        end
        table_sort(key)
        statusBuilder[#statusBuilder+1] = "{"
        statusDep = statusDep + 1
        encode_newline()
        local k = key[1]
        statusBuilder[#statusBuilder+1] = '"'
        statusBuilder[#statusBuilder+1] = encode_string(k)
        statusBuilder[#statusBuilder+1] = '": '
        encode(t[k])
        for i = 2, #key do
            local k = key[i]
            statusBuilder[#statusBuilder+1] = ","
            encode_newline()
            statusBuilder[#statusBuilder+1] = '"'
            statusBuilder[#statusBuilder+1] = encode_string(k)
            statusBuilder[#statusBuilder+1] = '": '
            encode(t[k])
        end
        statusDep = statusDep - 1
        encode_newline()
        statusVisited[t] = nil
        return "}"
    elseif json.supportSparseArray then
        local max = 0
        for k in next, t do
            if math_type(k) ~= "integer" or k <= 0 then
                error("invalid table: mixed or invalid key types: "..k)
            end
            if max < k then
                max = k
            end
        end
        statusBuilder[#statusBuilder+1] = "["
        statusDep = statusDep + 1
        encode_newline()
        encode(t[1])
        for i = 2, max do
            statusBuilder[#statusBuilder+1] = ","
            encode_newline()
            encode(t[i])
        end
        statusDep = statusDep - 1
        encode_newline()
        statusVisited[t] = nil
        return "]"
    else
        if t[1] == nil then
            error("invalid table: sparse array is not supported")
        end
        statusBuilder[#statusBuilder+1] = "["
        statusDep = statusDep + 1
        encode_newline()
        encode(t[1])
        local count = 2
        while t[count] ~= nil do
            statusBuilder[#statusBuilder+1] = ","
            encode_newline()
            encode(t[count])
            count = count + 1
        end
        if next(t, count-1) ~= nil then
            local k = next(t, count-1)
            if type(k) == "number" then
                error("invalid table: sparse array is not supported")
            else
                error("invalid table: mixed or invalid key types: "..k)
            end
        end
        statusDep = statusDep - 1
        encode_newline()
        statusVisited[t] = nil
        return "]"
    end
end

local function beautify_option(option)
    return setmetatable(option or {}, defaultOpt)
end

local function beautify(v, option)
    statusVisited = {}
    statusBuilder = {}
    statusOpt = beautify_option(option)
    statusDep = statusOpt.depth
    encode(v)
    return table_concat(statusBuilder)
end

json.beautify = beautify
json.beautify_option = beautify_option

return json
 end)
package.preload['json'] = (function (...)
local type = type
local next = next
local error = error
local tonumber = tonumber
local tostring = tostring
local table_concat = table.concat
local table_sort = table.sort
local string_char = string.char
local string_byte = string.byte
local string_find = string.find
local string_match = string.match
local string_gsub = string.gsub
local string_sub = string.sub
local string_format = string.format
local setmetatable = setmetatable
local getmetatable = getmetatable
local huge = math.huge
local tiny = -huge

local utf8_char
local math_type

if _VERSION == "Lua 5.1" or _VERSION == "Lua 5.2" then
    local math_floor = math.floor
    function utf8_char(c)
        if c <= 0x7f then
            return string_char(c)
        elseif c <= 0x7ff then
            return string_char(math_floor(c / 64) + 192, c % 64 + 128)
        elseif c <= 0xffff then
            return string_char(
                math_floor(c / 4096) + 224,
                math_floor(c % 4096 / 64) + 128,
                c % 64 + 128
            )
        elseif c <= 0x10ffff then
            return string_char(
                math_floor(c / 262144) + 240,
                math_floor(c % 262144 / 4096) + 128,
                math_floor(c % 4096 / 64) + 128,
                c % 64 + 128
            )
        end
        error(string_format("invalid UTF-8 code '%x'", c))
    end
    function math_type(v)
        if v >= -2147483648 and v <= 2147483647 and math_floor(v) == v then
            return "integer"
        end
        return "float"
    end
else
    utf8_char = utf8.char
    math_type = math.type
end

local json = {}

json.supportSparseArray = true

local objectMt = {}

function json.createEmptyObject()
    return setmetatable({}, objectMt)
end

function json.isObject(t)
    if t[1] ~= nil then
        return false
    end
    return next(t) ~= nil or getmetatable(t) == objectMt
end

if debug and debug.upvalueid then
    -- Generate a lightuserdata
    json.null = debug.upvalueid(json.createEmptyObject, 1)
else
    json.null = function() end
end

-- json.encode --
local statusVisited
local statusBuilder

local encode_map = {}

local encode_escape_map = {
    [ "\"" ] = "\\\"",
    [ "\\" ] = "\\\\",
    [ "/" ]  = "\\/",
    [ "\b" ] = "\\b",
    [ "\f" ] = "\\f",
    [ "\n" ] = "\\n",
    [ "\r" ] = "\\r",
    [ "\t" ] = "\\t",
}

local decode_escape_set = {}
local decode_escape_map = {}
for k, v in next, encode_escape_map do
    decode_escape_map[v] = k
    decode_escape_set[string_byte(v, 2)] = true
end

for i = 0, 31 do
    local c = string_char(i)
    if not encode_escape_map[c] then
        encode_escape_map[c] = string_format("\\u%04x", i)
    end
end

local function encode(v)
    local res = encode_map[type(v)](v)
    statusBuilder[#statusBuilder+1] = res
end

encode_map["nil"] = function ()
    return "null"
end

local function encode_string(v)
    return string_gsub(v, '[%z\1-\31\\"]', encode_escape_map)
end

function encode_map.string(v)
    statusBuilder[#statusBuilder+1] = '"'
    statusBuilder[#statusBuilder+1] = encode_string(v)
    return '"'
end

local function convertreal(v)
    local g = string_format('%.16g', v)
    if tonumber(g) == v then
        return g
    end
    return string_format('%.17g', v)
end

if string_match(tostring(1/2), "%p") == "," then
    local _convertreal = convertreal
    function convertreal(v)
        return string_gsub(_convertreal(v), ',', '.')
    end
end

function encode_map.number(v)
    if v ~= v or v <= tiny or v >= huge then
        error("unexpected number value '" .. tostring(v) .. "'")
    end
    if math_type(v) == "integer" then
        return string_format('%d', v)
    end
    return convertreal(v)
end

function encode_map.boolean(v)
    if v then
        return "true"
    else
        return "false"
    end
end

function encode_map.table(t)
    local first_val = next(t)
    if first_val == nil then
        if getmetatable(t) == objectMt then
            return "{}"
        else
            return "[]"
        end
    end
    if statusVisited[t] then
        error("circular reference")
    end
    statusVisited[t] = true
    if type(first_val) == 'string' then
        local keys = {}
        for k in next, t do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types: "..k)
            end
            keys[#keys+1] = k
        end
        table_sort(keys)
        local k = keys[1]
        statusBuilder[#statusBuilder+1] = '{"'
        statusBuilder[#statusBuilder+1] = encode_string(k)
        statusBuilder[#statusBuilder+1] = '":'
        encode(t[k])
        for i = 2, #keys do
            local k = keys[i]
            statusBuilder[#statusBuilder+1] = ',"'
            statusBuilder[#statusBuilder+1] = encode_string(k)
            statusBuilder[#statusBuilder+1] = '":'
            encode(t[k])
        end
        statusVisited[t] = nil
        return "}"
    elseif json.supportSparseArray then
        local max = 0
        for k in next, t do
            if math_type(k) ~= "integer" or k <= 0 then
                error("invalid table: mixed or invalid key types: "..k)
            end
            if max < k then
                max = k
            end
        end
        statusBuilder[#statusBuilder+1] = "["
        encode(t[1])
        for i = 2, max do
            statusBuilder[#statusBuilder+1] = ","
            encode(t[i])
        end
        statusVisited[t] = nil
        return "]"
    else
        if t[1] == nil then
            error("invalid table: sparse array is not supported")
        end
        statusBuilder[#statusBuilder+1] = "["
        encode(t[1])
        local count = 2
        while t[count] ~= nil do
            statusBuilder[#statusBuilder+1] = ","
            encode(t[count])
            count = count + 1
        end
        if next(t, count-1) ~= nil then
            local k = next(t, count-1)
            if type(k) == "number" then
                error("invalid table: sparse array is not supported")
            else
                error("invalid table: mixed or invalid key types: "..k)
            end
        end
        statusVisited[t] = nil
        return "]"
    end
end

local function encode_unexpected(v)
    if v == json.null then
        return "null"
    else
        error("unexpected type '"..type(v).."'")
    end
end
encode_map[ "function" ] = encode_unexpected
encode_map[ "userdata" ] = encode_unexpected
encode_map[ "thread"   ] = encode_unexpected

function json.encode(v)
    statusVisited = {}
    statusBuilder = {}
    encode(v)
    return table_concat(statusBuilder)
end

json._encode_map = encode_map
json._encode_string = encode_string

-- json.decode --

local statusBuf
local statusPos
local statusTop
local statusAry = {}
local statusRef = {}

local function find_line()
    local line = 1
    local pos = 1
    while true do
        local f, _, nl1, nl2 = string_find(statusBuf, '([\n\r])([\n\r]?)', pos)
        if not f then
            return line, statusPos - pos + 1
        end
        local newpos = f + ((nl1 == nl2 or nl2 == '') and 1 or 2)
        if newpos > statusPos then
            return line, statusPos - pos + 1
        end
        pos = newpos
        line = line + 1
    end
end

local function decode_error(msg)
    error(string_format("ERROR: %s at line %d col %d", msg, find_line()), 2)
end

local function get_word()
    return string_match(statusBuf, "^[^ \t\r\n%]},]*", statusPos)
end

local function next_byte()
    local pos = string_find(statusBuf, "[^ \t\r\n]", statusPos)
    if pos then
        statusPos = pos
        return string_byte(statusBuf, pos)
    end
    return -1
end

local function consume_byte(c)
    local _, pos = string_find(statusBuf, c, statusPos)
    if pos then
        statusPos = pos + 1
        return true
    end
end

local function expect_byte(c)
    local _, pos = string_find(statusBuf, c, statusPos)
    if not pos then
        decode_error(string_format("expected '%s'", string_sub(c, #c)))
    end
    statusPos = pos
end

local function decode_unicode_surrogate(s1, s2)
    return utf8_char(0x10000 + (tonumber(s1, 16) - 0xd800) * 0x400 + (tonumber(s2, 16) - 0xdc00))
end

local function decode_unicode_escape(s)
    return utf8_char(tonumber(s, 16))
end

local function decode_string()
    local has_unicode_escape = false
    local has_escape = false
    local i = statusPos + 1
    while true do
        i = string_find(statusBuf, '[%z\1-\31\\"]', i)
        if not i then
            decode_error "expected closing quote for string"
        end
        local x = string_byte(statusBuf, i)
        if x < 32 then
            statusPos = i
            decode_error "control character in string"
        end
        if x == 34 --[[ '"' ]] then
            local s = string_sub(statusBuf, statusPos + 1, i - 1)
            if has_unicode_escape then
                s = string_gsub(string_gsub(s
                    , "\\u([dD][89aAbB]%x%x)\\u([dD][c-fC-F]%x%x)", decode_unicode_surrogate)
                    , "\\u(%x%x%x%x)", decode_unicode_escape)
            end
            if has_escape then
                s = string_gsub(s, "\\.", decode_escape_map)
            end
            statusPos = i + 1
            return s
        end
        --assert(x == 92 --[[ "\\" ]])
        local nx = string_byte(statusBuf, i+1)
        if nx == 117 --[[ "u" ]] then
            if not string_match(statusBuf, "^%x%x%x%x", i+2) then
                statusPos = i
                decode_error "invalid unicode escape in string"
            end
            has_unicode_escape = true
            i = i + 6
        else
            if not decode_escape_set[nx] then
                statusPos = i
                decode_error("invalid escape char '" .. (nx and string_char(nx) or "<eol>") .. "' in string")
            end
            has_escape = true
            i = i + 2
        end
    end
end

local function decode_number()
    local num, c = string_match(statusBuf, '^([0-9]+%.?[0-9]*)([eE]?)', statusPos)
    if not num or string_byte(num, -1) == 0x2E --[[ "." ]] then
        decode_error("invalid number '" .. get_word() .. "'")
    end
    if c ~= '' then
        num = string_match(statusBuf, '^([^eE]*[eE][-+]?[0-9]+)[ \t\r\n%]},]', statusPos)
        if not num then
            decode_error("invalid number '" .. get_word() .. "'")
        end
    end
    statusPos = statusPos + #num
    return tonumber(num)
end

local function decode_number_zero()
    local num, c = string_match(statusBuf, '^(.%.?[0-9]*)([eE]?)', statusPos)
    if not num or string_byte(num, -1) == 0x2E --[[ "." ]] or string_match(statusBuf, '^.[0-9]+', statusPos) then
        decode_error("invalid number '" .. get_word() .. "'")
    end
    if c ~= '' then
        num = string_match(statusBuf, '^([^eE]*[eE][-+]?[0-9]+)[ \t\r\n%]},]', statusPos)
        if not num then
            decode_error("invalid number '" .. get_word() .. "'")
        end
    end
    statusPos = statusPos + #num
    return tonumber(num)
end

local function decode_number_negative()
    statusPos = statusPos + 1
    local c = string_byte(statusBuf, statusPos)
    if c then
        if c == 0x30 then
            return -decode_number_zero()
        elseif c > 0x30 and c < 0x3A then
            return -decode_number()
        end
    end
    decode_error("invalid number '" .. get_word() .. "'")
end

local function decode_true()
    if string_sub(statusBuf, statusPos, statusPos+3) ~= "true" then
        decode_error("invalid literal '" .. get_word() .. "'")
    end
    statusPos = statusPos + 4
    return true
end

local function decode_false()
    if string_sub(statusBuf, statusPos, statusPos+4) ~= "false" then
        decode_error("invalid literal '" .. get_word() .. "'")
    end
    statusPos = statusPos + 5
    return false
end

local function decode_null()
    if string_sub(statusBuf, statusPos, statusPos+3) ~= "null" then
        decode_error("invalid literal '" .. get_word() .. "'")
    end
    statusPos = statusPos + 4
    return json.null
end

local function decode_array()
    statusPos = statusPos + 1
    if consume_byte "^[ \t\r\n]*%]" then
        return {}
    end
    local res = {}
    statusTop = statusTop + 1
    statusAry[statusTop] = true
    statusRef[statusTop] = res
    return res
end

local function decode_object()
    statusPos = statusPos + 1
    if consume_byte "^[ \t\r\n]*}" then
        return json.createEmptyObject()
    end
    local res = {}
    statusTop = statusTop + 1
    statusAry[statusTop] = false
    statusRef[statusTop] = res
    return res
end

local decode_uncompleted_map = {
    [ string_byte '"' ] = decode_string,
    [ string_byte "0" ] = decode_number_zero,
    [ string_byte "1" ] = decode_number,
    [ string_byte "2" ] = decode_number,
    [ string_byte "3" ] = decode_number,
    [ string_byte "4" ] = decode_number,
    [ string_byte "5" ] = decode_number,
    [ string_byte "6" ] = decode_number,
    [ string_byte "7" ] = decode_number,
    [ string_byte "8" ] = decode_number,
    [ string_byte "9" ] = decode_number,
    [ string_byte "-" ] = decode_number_negative,
    [ string_byte "t" ] = decode_true,
    [ string_byte "f" ] = decode_false,
    [ string_byte "n" ] = decode_null,
    [ string_byte "[" ] = decode_array,
    [ string_byte "{" ] = decode_object,
}
local function unexpected_character()
    decode_error("unexpected character '" .. string_sub(statusBuf, statusPos, statusPos) .. "'")
end
local function unexpected_eol()
    decode_error("unexpected character '<eol>'")
end

local decode_map = {}
for i = 0, 255 do
    decode_map[i] = decode_uncompleted_map[i] or unexpected_character
end
decode_map[-1] = unexpected_eol

local function decode()
    return decode_map[next_byte()]()
end

local function decode_item()
    local top = statusTop
    local ref = statusRef[top]
    if statusAry[top] then
        ref[#ref+1] = decode()
    else
        expect_byte '^[ \t\r\n]*"'
        local key = decode_string()
        expect_byte '^[ \t\r\n]*:'
        statusPos = statusPos + 1
        ref[key] = decode()
    end
    if top == statusTop then
        repeat
            local chr = next_byte(); statusPos = statusPos + 1
            if chr == 44 --[[ "," ]] then
                return
            end
            if statusAry[statusTop] then
                if chr ~= 93 --[[ "]" ]] then decode_error "expected ']' or ','" end
            else
                if chr ~= 125 --[[ "}" ]] then decode_error "expected '}' or ','" end
            end
            statusTop = statusTop - 1
        until statusTop == 0
    end
end

function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    statusBuf = str
    statusPos = 1
    statusTop = 0
    local res = decode()
    while statusTop > 0 do
        decode_item()
    end
    if string_find(statusBuf, "[^ \t\r\n]", statusPos) then
        decode_error "trailing garbage"
    end
    return res
end

return json
 end)
package.preload['7zip'] = (function (...)
--[[ ----------------------------------------

    [Deps] 7Zip client.

--]] ----------------------------------------

require "logger"
require "temp"
require "filesystem"
Wf = require "winfile"
local Log = Logger:new('7Zip')

P7zip = {
    path = 'lib/7zip/',
    files = {
        '7za.exe',
        '7za.dll',
        '7zxa.dll'
    }
}

local function finmt(str)
    return ({str:gsub('/','\\')})[1]
end

function P7zip:init()

    -- pre-check
    for n,i in pairs(self.files) do
       if not Fs:isExist(self.path..i) then
           Log:Error('找不到 %s，模块不可用。',i)
           return false
       end
    end
    if not Wf.popen(finmt(('%s7za.exe i'):format(self.path))):read("*a"):find('7-Zip %(a%)') then
        Log:Error('初始化失败，模块不可用。')
        return false
    end
    return true

end

---解压缩
---@param path string 压缩文件路径
---@param topath string? 解压到路径, 若不提供则返回一个临时路径
---@return boolean isOk
---@return string path
function P7zip:extract(path,topath)
    if not Fs:isExist(path) then
        Log:Error('解压缩失败，因为文件不存在。')
        return false,''
    end
    topath = topath or Temp:getDirectory()
    return Wf.popen(finmt(('%s7za x -o"%s" -y "%s"'):format(self.path,topath,path))):read('*a'):find('Everything is Ok')~=nil,topath
end

---创建压缩包
---@param path string 欲压缩文件(夹)路径
---@param topath string 压缩文件创建路径
function P7zip:archive(path,topath)
    return Wf.popen(finmt(('%s7za a -y "%s" "%s"'):format(self.path,topath,path))):read('*a'):find('Everything is Ok') ~= nil
end

return P7zip end)
package.preload['temp'] = (function (...)
--[[ ----------------------------------------

    [Deps] Temp.

--]] ----------------------------------------

Fs = require "filesystem"

Temp = {
    baseDir = 'temp/'
}

local function getRandStr()
    math.randomseed(os.time())
    return string.gsub('********', '[*]', function (c)
        return string.format('%x', math.random(0,0xf))
    end)
end

function Temp:init()
    Fs:mkdir(self.baseDir)
    return self:free()
end

function Temp:free()
    return Fs:rmdir(self.baseDir) and Fs:mkdir(self.baseDir)
end

---获取一个临时文件，返回路径。
---@param ext? string
---@return string
function Temp:getFile(ext)
    local n
    ext = ext or ''
    while true do
        n = self.baseDir..getRandStr() .. '.' .. ext
        if not Fs:isExist(n) then
            break
        end
    end
    Fs:writeTo(n,'')
    return n
end

---获取一个临时目录，返回路径。
---@return string
function Temp:getDirectory()
    local n
    while true do
        n = self.baseDir..getRandStr()
        if not Fs:isExist(n) then
            break
        end
    end
    Fs:mkdir(n)
    return n..'/'
end

return Temp end)
package.preload['argparse'] = (function (...)
-- The MIT License (MIT)

-- Copyright (c) 2013 - 2018 Peter Melnichenko
--                      2019 Paul Ouellette

-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
-- the Software, and to permit persons to whom the Software is furnished to do so,
-- subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
-- FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
-- COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
-- IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local function deep_update(t1, t2)
   for k, v in pairs(t2) do
      if type(v) == "table" then
         v = deep_update({}, v)
      end

      t1[k] = v
   end

   return t1
end

-- A property is a tuple {name, callback}.
-- properties.args is number of properties that can be set as arguments
-- when calling an object.
local function class(prototype, properties, parent)
   -- Class is the metatable of its instances.
   local cl = {}
   cl.__index = cl

   if parent then
      cl.__prototype = deep_update(deep_update({}, parent.__prototype), prototype)
   else
      cl.__prototype = prototype
   end

   if properties then
      local names = {}

      -- Create setter methods and fill set of property names.
      for _, property in ipairs(properties) do
         local name, callback = property[1], property[2]

         cl[name] = function(self, value)
            if not callback(self, value) then
               self["_" .. name] = value
            end

            return self
         end

         names[name] = true
      end

      function cl.__call(self, ...)
         -- When calling an object, if the first argument is a table,
         -- interpret keys as property names, else delegate arguments
         -- to corresponding setters in order.
         if type((...)) == "table" then
            for name, value in pairs((...)) do
               if names[name] then
                  self[name](self, value)
               end
            end
         else
            local nargs = select("#", ...)

            for i, property in ipairs(properties) do
               if i > nargs or i > properties.args then
                  break
               end

               local arg = select(i, ...)

               if arg ~= nil then
                  self[property[1]](self, arg)
               end
            end
         end

         return self
      end
   end

   -- If indexing class fails, fallback to its parent.
   local class_metatable = {}
   class_metatable.__index = parent

   function class_metatable.__call(self, ...)
      -- Calling a class returns its instance.
      -- Arguments are delegated to the instance.
      local object = deep_update({}, self.__prototype)
      setmetatable(object, self)
      return object(...)
   end

   return setmetatable(cl, class_metatable)
end

local function typecheck(name, types, value)
   for _, type_ in ipairs(types) do
      if type(value) == type_ then
         return true
      end
   end

   error(("bad property '%s' (%s expected, got %s)"):format(name, table.concat(types, " or "), type(value)))
end

local function typechecked(name, ...)
   local types = {...}
   return {name, function(_, value) typecheck(name, types, value) end}
end

local multiname = {"name", function(self, value)
   typecheck("name", {"string"}, value)

   for alias in value:gmatch("%S+") do
      self._name = self._name or alias
      table.insert(self._aliases, alias)
      table.insert(self._public_aliases, alias)
      -- If alias contains '_', accept '-' also.
      if alias:find("_", 1, true) then
         table.insert(self._aliases, (alias:gsub("_", "-")))
      end
   end

   -- Do not set _name as with other properties.
   return true
end}

local multiname_hidden = {"hidden_name", function(self, value)
   typecheck("hidden_name", {"string"}, value)

   for alias in value:gmatch("%S+") do
      table.insert(self._aliases, alias)
      if alias:find("_", 1, true) then
         table.insert(self._aliases, (alias:gsub("_", "-")))
      end
   end

   return true
end}

local function parse_boundaries(str)
   if tonumber(str) then
      return tonumber(str), tonumber(str)
   end

   if str == "*" then
      return 0, math.huge
   end

   if str == "+" then
      return 1, math.huge
   end

   if str == "?" then
      return 0, 1
   end

   if str:match "^%d+%-%d+$" then
      local min, max = str:match "^(%d+)%-(%d+)$"
      return tonumber(min), tonumber(max)
   end

   if str:match "^%d+%+$" then
      local min = str:match "^(%d+)%+$"
      return tonumber(min), math.huge
   end
end

local function boundaries(name)
   return {name, function(self, value)
      typecheck(name, {"number", "string"}, value)

      local min, max = parse_boundaries(value)

      if not min then
         error(("bad property '%s'"):format(name))
      end

      self["_min" .. name], self["_max" .. name] = min, max
   end}
end

local actions = {}

local option_action = {"action", function(_, value)
   typecheck("action", {"function", "string"}, value)

   if type(value) == "string" and not actions[value] then
      error(("unknown action '%s'"):format(value))
   end
end}

local option_init = {"init", function(self)
   self._has_init = true
end}

local option_default = {"default", function(self, value)
   if type(value) ~= "string" then
      self._init = value
      self._has_init = true
      return true
   end
end}

local add_help = {"add_help", function(self, value)
   typecheck("add_help", {"boolean", "string", "table"}, value)

   if self._help_option_idx then
      table.remove(self._options, self._help_option_idx)
      self._help_option_idx = nil
   end

   if value then
      local help = self:flag()
         :description "Show this help message and exit."
         :action(function()
            print(self:get_help())
            os.exit(0)
         end)

      if value ~= true then
         help = help(value)
      end

      if not help._name then
         help "-h" "--help"
      end

      self._help_option_idx = #self._options
   end
end}

local Parser = class({
   _arguments = {},
   _options = {},
   _commands = {},
   _mutexes = {},
   _groups = {},
   _require_command = true,
   _handle_options = true
}, {
   args = 3,
   typechecked("name", "string"),
   typechecked("description", "string"),
   typechecked("epilog", "string"),
   typechecked("usage", "string"),
   typechecked("help", "string"),
   typechecked("require_command", "boolean"),
   typechecked("handle_options", "boolean"),
   typechecked("action", "function"),
   typechecked("command_target", "string"),
   typechecked("help_vertical_space", "number"),
   typechecked("usage_margin", "number"),
   typechecked("usage_max_width", "number"),
   typechecked("help_usage_margin", "number"),
   typechecked("help_description_margin", "number"),
   typechecked("help_max_width", "number"),
   add_help
})

local Command = class({
   _aliases = {},
   _public_aliases = {}
}, {
   args = 3,
   multiname,
   typechecked("description", "string"),
   typechecked("epilog", "string"),
   multiname_hidden,
   typechecked("summary", "string"),
   typechecked("target", "string"),
   typechecked("usage", "string"),
   typechecked("help", "string"),
   typechecked("require_command", "boolean"),
   typechecked("handle_options", "boolean"),
   typechecked("action", "function"),
   typechecked("command_target", "string"),
   typechecked("help_vertical_space", "number"),
   typechecked("usage_margin", "number"),
   typechecked("usage_max_width", "number"),
   typechecked("help_usage_margin", "number"),
   typechecked("help_description_margin", "number"),
   typechecked("help_max_width", "number"),
   typechecked("hidden", "boolean"),
   add_help
}, Parser)

local Argument = class({
   _minargs = 1,
   _maxargs = 1,
   _mincount = 1,
   _maxcount = 1,
   _defmode = "unused",
   _show_default = true
}, {
   args = 5,
   typechecked("name", "string"),
   typechecked("description", "string"),
   option_default,
   typechecked("convert", "function", "table"),
   boundaries("args"),
   typechecked("target", "string"),
   typechecked("defmode", "string"),
   typechecked("show_default", "boolean"),
   typechecked("argname", "string", "table"),
   typechecked("choices", "table"),
   typechecked("hidden", "boolean"),
   option_action,
   option_init
})

local Option = class({
   _aliases = {},
   _public_aliases = {},
   _mincount = 0,
   _overwrite = true
}, {
   args = 6,
   multiname,
   typechecked("description", "string"),
   option_default,
   typechecked("convert", "function", "table"),
   boundaries("args"),
   boundaries("count"),
   multiname_hidden,
   typechecked("target", "string"),
   typechecked("defmode", "string"),
   typechecked("show_default", "boolean"),
   typechecked("overwrite", "boolean"),
   typechecked("argname", "string", "table"),
   typechecked("choices", "table"),
   typechecked("hidden", "boolean"),
   option_action,
   option_init
}, Argument)

function Parser:_inherit_property(name, default)
   local element = self

   while true do
      local value = element["_" .. name]

      if value ~= nil then
         return value
      end

      if not element._parent then
         return default
      end

      element = element._parent
   end
end

function Argument:_get_argument_list()
   local buf = {}
   local i = 1

   while i <= math.min(self._minargs, 3) do
      local argname = self:_get_argname(i)

      if self._default and self._defmode:find "a" then
         argname = "[" .. argname .. "]"
      end

      table.insert(buf, argname)
      i = i+1
   end

   while i <= math.min(self._maxargs, 3) do
      table.insert(buf, "[" .. self:_get_argname(i) .. "]")
      i = i+1

      if self._maxargs == math.huge then
         break
      end
   end

   if i < self._maxargs then
      table.insert(buf, "...")
   end

   return buf
end

function Argument:_get_usage()
   local usage = table.concat(self:_get_argument_list(), " ")

   if self._default and self._defmode:find "u" then
      if self._maxargs > 1 or (self._minargs == 1 and not self._defmode:find "a") then
         usage = "[" .. usage .. "]"
      end
   end

   return usage
end

function actions.store_true(result, target)
   result[target] = true
end

function actions.store_false(result, target)
   result[target] = false
end

function actions.store(result, target, argument)
   result[target] = argument
end

function actions.count(result, target, _, overwrite)
   if not overwrite then
      result[target] = result[target] + 1
   end
end

function actions.append(result, target, argument, overwrite)
   result[target] = result[target] or {}
   table.insert(result[target], argument)

   if overwrite then
      table.remove(result[target], 1)
   end
end

function actions.concat(result, target, arguments, overwrite)
   if overwrite then
      error("'concat' action can't handle too many invocations")
   end

   result[target] = result[target] or {}

   for _, argument in ipairs(arguments) do
      table.insert(result[target], argument)
   end
end

function Argument:_get_action()
   local action, init

   if self._maxcount == 1 then
      if self._maxargs == 0 then
         action, init = "store_true", nil
      else
         action, init = "store", nil
      end
   else
      if self._maxargs == 0 then
         action, init = "count", 0
      else
         action, init = "append", {}
      end
   end

   if self._action then
      action = self._action
   end

   if self._has_init then
      init = self._init
   end

   if type(action) == "string" then
      action = actions[action]
   end

   return action, init
end

-- Returns placeholder for `narg`-th argument.
function Argument:_get_argname(narg)
   local argname = self._argname or self:_get_default_argname()

   if type(argname) == "table" then
      return argname[narg]
   else
      return argname
   end
end

function Argument:_get_choices_list()
   return "{" .. table.concat(self._choices, ",") .. "}"
end

function Argument:_get_default_argname()
   if self._choices then
      return self:_get_choices_list()
   else
      return "<" .. self._name .. ">"
   end
end

function Option:_get_default_argname()
   if self._choices then
      return self:_get_choices_list()
   else
      return "<" .. self:_get_default_target() .. ">"
   end
end

-- Returns labels to be shown in the help message.
function Argument:_get_label_lines()
   if self._choices then
      return {self:_get_choices_list()}
   else
      return {self._name}
   end
end

function Option:_get_label_lines()
   local argument_list = self:_get_argument_list()

   if #argument_list == 0 then
      -- Don't put aliases for simple flags like `-h` on different lines.
      return {table.concat(self._public_aliases, ", ")}
   end

   local longest_alias_length = -1

   for _, alias in ipairs(self._public_aliases) do
      longest_alias_length = math.max(longest_alias_length, #alias)
   end

   local argument_list_repr = table.concat(argument_list, " ")
   local lines = {}

   for i, alias in ipairs(self._public_aliases) do
      local line = (" "):rep(longest_alias_length - #alias) .. alias .. " " .. argument_list_repr

      if i ~= #self._public_aliases then
         line = line .. ","
      end

      table.insert(lines, line)
   end

   return lines
end

function Command:_get_label_lines()
   return {table.concat(self._public_aliases, ", ")}
end

function Argument:_get_description()
   if self._default and self._show_default then
      if self._description then
         return ("%s (default: %s)"):format(self._description, self._default)
      else
         return ("default: %s"):format(self._default)
      end
   else
      return self._description or ""
   end
end

function Command:_get_description()
   return self._summary or self._description or ""
end

function Option:_get_usage()
   local usage = self:_get_argument_list()
   table.insert(usage, 1, self._name)
   usage = table.concat(usage, " ")

   if self._mincount == 0 or self._default then
      usage = "[" .. usage .. "]"
   end

   return usage
end

function Argument:_get_default_target()
   return self._name
end

function Option:_get_default_target()
   local res

   for _, alias in ipairs(self._public_aliases) do
      if alias:sub(1, 1) == alias:sub(2, 2) then
         res = alias:sub(3)
         break
      end
   end

   res = res or self._name:sub(2)
   return (res:gsub("-", "_"))
end

function Option:_is_vararg()
   return self._maxargs ~= self._minargs
end

function Parser:_get_fullname(exclude_root)
   local parent = self._parent
   if exclude_root and not parent then
      return ""
   end
   local buf = {self._name}

   while parent do
      if not exclude_root or parent._parent then
         table.insert(buf, 1, parent._name)
      end
      parent = parent._parent
   end

   return table.concat(buf, " ")
end

function Parser:_update_charset(charset)
   charset = charset or {}

   for _, command in ipairs(self._commands) do
      command:_update_charset(charset)
   end

   for _, option in ipairs(self._options) do
      for _, alias in ipairs(option._aliases) do
         charset[alias:sub(1, 1)] = true
      end
   end

   return charset
end

function Parser:argument(...)
   local argument = Argument(...)
   table.insert(self._arguments, argument)
   return argument
end

function Parser:option(...)
   local option = Option(...)
   table.insert(self._options, option)
   return option
end

function Parser:flag(...)
   return self:option():args(0)(...)
end

function Parser:command(...)
   local command = Command():add_help(true)(...)
   command._parent = self
   table.insert(self._commands, command)
   return command
end

function Parser:mutex(...)
   local elements = {...}

   for i, element in ipairs(elements) do
      local mt = getmetatable(element)
      assert(mt == Option or mt == Argument, ("bad argument #%d to 'mutex' (Option or Argument expected)"):format(i))
   end

   table.insert(self._mutexes, elements)
   return self
end

function Parser:group(name, ...)
   assert(type(name) == "string", ("bad argument #1 to 'group' (string expected, got %s)"):format(type(name)))

   local group = {name = name, ...}

   for i, element in ipairs(group) do
      local mt = getmetatable(element)
      assert(mt == Option or mt == Argument or mt == Command,
         ("bad argument #%d to 'group' (Option or Argument or Command expected)"):format(i + 1))
   end

   table.insert(self._groups, group)
   return self
end

local usage_welcome = "Usage: "

function Parser:get_usage()
   if self._usage then
      return self._usage
   end

   local usage_margin = self:_inherit_property("usage_margin", #usage_welcome)
   local max_usage_width = self:_inherit_property("usage_max_width", 70)
   local lines = {usage_welcome .. self:_get_fullname()}

   local function add(s)
      if #lines[#lines]+1+#s <= max_usage_width then
         lines[#lines] = lines[#lines] .. " " .. s
      else
         lines[#lines+1] = (" "):rep(usage_margin) .. s
      end
   end

   -- Normally options are before positional arguments in usage messages.
   -- However, vararg options should be after, because they can't be reliable used
   -- before a positional argument.
   -- Mutexes come into play, too, and are shown as soon as possible.
   -- Overall, output usages in the following order:
   -- 1. Mutexes that don't have positional arguments or vararg options.
   -- 2. Options that are not in any mutexes and are not vararg.
   -- 3. Positional arguments - on their own or as a part of a mutex.
   -- 4. Remaining mutexes.
   -- 5. Remaining options.

   local elements_in_mutexes = {}
   local added_elements = {}
   local added_mutexes = {}
   local argument_to_mutexes = {}

   local function add_mutex(mutex, main_argument)
      if added_mutexes[mutex] then
         return
      end

      added_mutexes[mutex] = true
      local buf = {}

      for _, element in ipairs(mutex) do
         if not element._hidden and not added_elements[element] then
            if getmetatable(element) == Option or element == main_argument then
               table.insert(buf, element:_get_usage())
               added_elements[element] = true
            end
         end
      end

      if #buf == 1 then
         add(buf[1])
      elseif #buf > 1 then
         add("(" .. table.concat(buf, " | ") .. ")")
      end
   end

   local function add_element(element)
      if not element._hidden and not added_elements[element] then
         add(element:_get_usage())
         added_elements[element] = true
      end
   end

   for _, mutex in ipairs(self._mutexes) do
      local is_vararg = false
      local has_argument = false

      for _, element in ipairs(mutex) do
         if getmetatable(element) == Option then
            if element:_is_vararg() then
               is_vararg = true
            end
         else
            has_argument = true
            argument_to_mutexes[element] = argument_to_mutexes[element] or {}
            table.insert(argument_to_mutexes[element], mutex)
         end

         elements_in_mutexes[element] = true
      end

      if not is_vararg and not has_argument then
         add_mutex(mutex)
      end
   end

   for _, option in ipairs(self._options) do
      if not elements_in_mutexes[option] and not option:_is_vararg() then
         add_element(option)
      end
   end

   -- Add usages for positional arguments, together with one mutex containing them, if they are in a mutex.
   for _, argument in ipairs(self._arguments) do
      -- Pick a mutex as a part of which to show this argument, take the first one that's still available.
      local mutex

      if elements_in_mutexes[argument] then
         for _, argument_mutex in ipairs(argument_to_mutexes[argument]) do
            if not added_mutexes[argument_mutex] then
               mutex = argument_mutex
            end
         end
      end

      if mutex then
         add_mutex(mutex, argument)
      else
         add_element(argument)
      end
   end

   for _, mutex in ipairs(self._mutexes) do
      add_mutex(mutex)
   end

   for _, option in ipairs(self._options) do
      add_element(option)
   end

   if #self._commands > 0 then
      if self._require_command then
         add("<command>")
      else
         add("[<command>]")
      end

      add("...")
   end

   return table.concat(lines, "\n")
end

local function split_lines(s)
   if s == "" then
      return {}
   end

   local lines = {}

   if s:sub(-1) ~= "\n" then
      s = s .. "\n"
   end

   for line in s:gmatch("([^\n]*)\n") do
      table.insert(lines, line)
   end

   return lines
end

local function autowrap_line(line, max_length)
   -- Algorithm for splitting lines is simple and greedy.
   local result_lines = {}

   -- Preserve original indentation of the line, put this at the beginning of each result line.
   -- If the first word looks like a list marker ('*', '+', or '-'), add spaces so that starts
   -- of the second and the following lines vertically align with the start of the second word.
   local indentation = line:match("^ *")

   if line:find("^ *[%*%+%-]") then
      indentation = indentation .. " " .. line:match("^ *[%*%+%-]( *)")
   end

   -- Parts of the last line being assembled.
   local line_parts = {}

   -- Length of the current line.
   local line_length = 0

   -- Index of the next character to consider.
   local index = 1

   while true do
      local word_start, word_finish, word = line:find("([^ ]+)", index)

      if not word_start then
         -- Ignore trailing spaces, if any.
         break
      end

      local preceding_spaces = line:sub(index, word_start - 1)
      index = word_finish + 1

      if (#line_parts == 0) or (line_length + #preceding_spaces + #word <= max_length) then
         -- Either this is the very first word or it fits as an addition to the current line, add it.
         table.insert(line_parts, preceding_spaces) -- For the very first word this adds the indentation.
         table.insert(line_parts, word)
         line_length = line_length + #preceding_spaces + #word
      else
         -- Does not fit, finish current line and put the word into a new one.
         table.insert(result_lines, table.concat(line_parts))
         line_parts = {indentation, word}
         line_length = #indentation + #word
      end
   end

   if #line_parts > 0 then
      table.insert(result_lines, table.concat(line_parts))
   end

   if #result_lines == 0 then
      -- Preserve empty lines.
      result_lines[1] = ""
   end

   return result_lines
end

-- Automatically wraps lines within given array,
-- attempting to limit line length to `max_length`.
-- Existing line splits are preserved.
local function autowrap(lines, max_length)
   local result_lines = {}

   for _, line in ipairs(lines) do
      local autowrapped_lines = autowrap_line(line, max_length)

      for _, autowrapped_line in ipairs(autowrapped_lines) do
         table.insert(result_lines, autowrapped_line)
      end
   end

   return result_lines
end

function Parser:_get_element_help(element)
   local label_lines = element:_get_label_lines()
   local description_lines = split_lines(element:_get_description())

   local result_lines = {}

   -- All label lines should have the same length (except the last one, it has no comma).
   -- If too long, start description after all the label lines.
   -- Otherwise, combine label and description lines.

   local usage_margin_len = self:_inherit_property("help_usage_margin", 3)
   local usage_margin = (" "):rep(usage_margin_len)
   local description_margin_len = self:_inherit_property("help_description_margin", 25)
   local description_margin = (" "):rep(description_margin_len)

   local help_max_width = self:_inherit_property("help_max_width")

   if help_max_width then
      local description_max_width = math.max(help_max_width - description_margin_len, 10)
      description_lines = autowrap(description_lines, description_max_width)
   end

   if #label_lines[1] >= (description_margin_len - usage_margin_len) then
      for _, label_line in ipairs(label_lines) do
         table.insert(result_lines, usage_margin .. label_line)
      end

      for _, description_line in ipairs(description_lines) do
         table.insert(result_lines, description_margin .. description_line)
      end
   else
      for i = 1, math.max(#label_lines, #description_lines) do
         local label_line = label_lines[i]
         local description_line = description_lines[i]

         local line = ""

         if label_line then
            line = usage_margin .. label_line
         end

         if description_line and description_line ~= "" then
            line = line .. (" "):rep(description_margin_len - #line) .. description_line
         end

         table.insert(result_lines, line)
      end
   end

   return table.concat(result_lines, "\n")
end

local function get_group_types(group)
   local types = {}

   for _, element in ipairs(group) do
      types[getmetatable(element)] = true
   end

   return types
end

function Parser:_add_group_help(blocks, added_elements, label, elements)
   local buf = {label}

   for _, element in ipairs(elements) do
      if not element._hidden and not added_elements[element] then
         added_elements[element] = true
         table.insert(buf, self:_get_element_help(element))
      end
   end

   if #buf > 1 then
      table.insert(blocks, table.concat(buf, ("\n"):rep(self:_inherit_property("help_vertical_space", 0) + 1)))
   end
end

function Parser:get_help()
   if self._help then
      return self._help
   end

   local blocks = {self:get_usage()}

   local help_max_width = self:_inherit_property("help_max_width")

   if self._description then
      local description = self._description

      if help_max_width then
         description = table.concat(autowrap(split_lines(description), help_max_width), "\n")
      end

      table.insert(blocks, description)
   end

   -- 1. Put groups containing arguments first, then other arguments.
   -- 2. Put remaining groups containing options, then other options.
   -- 3. Put remaining groups containing commands, then other commands.
   -- Assume that an element can't be in several groups.
   local groups_by_type = {
      [Argument] = {},
      [Option] = {},
      [Command] = {}
   }

   for _, group in ipairs(self._groups) do
      local group_types = get_group_types(group)

      for _, mt in ipairs({Argument, Option, Command}) do
         if group_types[mt] then
            table.insert(groups_by_type[mt], group)
            break
         end
      end
   end

   local default_groups = {
      {name = "Arguments", type = Argument, elements = self._arguments},
      {name = "Options", type = Option, elements = self._options},
      {name = "Commands", type = Command, elements = self._commands}
   }

   local added_elements = {}

   for _, default_group in ipairs(default_groups) do
      local type_groups = groups_by_type[default_group.type]

      for _, group in ipairs(type_groups) do
         self:_add_group_help(blocks, added_elements, group.name .. ":", group)
      end

      local default_label = default_group.name .. ":"

      if #type_groups > 0 then
         default_label = "Other " .. default_label:gsub("^.", string.lower)
      end

      self:_add_group_help(blocks, added_elements, default_label, default_group.elements)
   end

   if self._epilog then
      local epilog = self._epilog

      if help_max_width then
         epilog = table.concat(autowrap(split_lines(epilog), help_max_width), "\n")
      end

      table.insert(blocks, epilog)
   end

   return table.concat(blocks, "\n\n")
end

function Parser:add_help_command(value)
   if value then
      assert(type(value) == "string" or type(value) == "table",
         ("bad argument #1 to 'add_help_command' (string or table expected, got %s)"):format(type(value)))
   end

   local help = self:command()
      :description "Show help for commands."
   help:argument "command"
      :description "The command to show help for."
      :args "?"
      :action(function(_, _, cmd)
         if not cmd then
            print(self:get_help())
            os.exit(0)
         else
            for _, command in ipairs(self._commands) do
               for _, alias in ipairs(command._aliases) do
                  if alias == cmd then
                     print(command:get_help())
                     os.exit(0)
                  end
               end
            end
         end
         help:error(("unknown command '%s'"):format(cmd))
      end)

   if value then
      help = help(value)
   end

   if not help._name then
      help "help"
   end

   help._is_help_command = true
   return self
end

function Parser:_is_shell_safe()
   if self._basename then
      if self._basename:find("[^%w_%-%+%.]") then
         return false
      end
   else
      for _, alias in ipairs(self._aliases) do
         if alias:find("[^%w_%-%+%.]") then
            return false
         end
      end
   end
   for _, option in ipairs(self._options) do
      for _, alias in ipairs(option._aliases) do
         if alias:find("[^%w_%-%+%.]") then
            return false
         end
      end
      if option._choices then
         for _, choice in ipairs(option._choices) do
            if choice:find("[%s'\"]") then
               return false
            end
         end
      end
   end
   for _, argument in ipairs(self._arguments) do
      if argument._choices then
         for _, choice in ipairs(argument._choices) do
            if choice:find("[%s'\"]") then
               return false
            end
         end
      end
   end
   for _, command in ipairs(self._commands) do
      if not command:_is_shell_safe() then
         return false
      end
   end
   return true
end

function Parser:add_complete(value)
   if value then
      assert(type(value) == "string" or type(value) == "table",
         ("bad argument #1 to 'add_complete' (string or table expected, got %s)"):format(type(value)))
   end

   local complete = self:option()
      :description "Output a shell completion script for the specified shell."
      :args(1)
      :choices {"bash", "zsh", "fish"}
      :action(function(_, _, shell)
         io.write(self["get_" .. shell .. "_complete"](self))
         os.exit(0)
      end)

   if value then
      complete = complete(value)
   end

   if not complete._name then
      complete "--completion"
   end

   return self
end

function Parser:add_complete_command(value)
   if value then
      assert(type(value) == "string" or type(value) == "table",
         ("bad argument #1 to 'add_complete_command' (string or table expected, got %s)"):format(type(value)))
   end

   local complete = self:command()
      :description "Output a shell completion script."
   complete:argument "shell"
      :description "The shell to output a completion script for."
      :choices {"bash", "zsh", "fish"}
      :action(function(_, _, shell)
         io.write(self["get_" .. shell .. "_complete"](self))
         os.exit(0)
      end)

   if value then
      complete = complete(value)
   end

   if not complete._name then
      complete "completion"
   end

   return self
end

local function base_name(pathname)
   return pathname:gsub("[/\\]*$", ""):match(".*[/\\]([^/\\]*)") or pathname
end

local function get_short_description(element)
   local short = element:_get_description():match("^(.-)%.%s")
   return short or element:_get_description():match("^(.-)%.?$")
end

function Parser:_get_options()
   local options = {}
   for _, option in ipairs(self._options) do
      for _, alias in ipairs(option._aliases) do
         table.insert(options, alias)
      end
   end
   return table.concat(options, " ")
end

function Parser:_get_commands()
   local commands = {}
   for _, command in ipairs(self._commands) do
      for _, alias in ipairs(command._aliases) do
         table.insert(commands, alias)
      end
   end
   return table.concat(commands, " ")
end

function Parser:_bash_option_args(buf, indent)
   local opts = {}
   for _, option in ipairs(self._options) do
      if option._choices or option._minargs > 0 then
         local compreply
         if option._choices then
            compreply = 'COMPREPLY=($(compgen -W "' .. table.concat(option._choices, " ") .. '" -- "$cur"))'
         else
            compreply = 'COMPREPLY=($(compgen -f -- "$cur"))'
         end
         table.insert(opts, (" "):rep(indent + 4) .. table.concat(option._aliases, "|") .. ")")
         table.insert(opts, (" "):rep(indent + 8) .. compreply)
         table.insert(opts, (" "):rep(indent + 8) .. "return 0")
         table.insert(opts, (" "):rep(indent + 8) .. ";;")
      end
   end

   if #opts > 0 then
      table.insert(buf, (" "):rep(indent) .. 'case "$prev" in')
      table.insert(buf, table.concat(opts, "\n"))
      table.insert(buf, (" "):rep(indent) .. "esac\n")
   end
end

function Parser:_bash_get_cmd(buf, indent)
   if #self._commands == 0 then
      return
   end

   table.insert(buf, (" "):rep(indent) .. 'args=("${args[@]:1}")')
   table.insert(buf, (" "):rep(indent) .. 'for arg in "${args[@]}"; do')
   table.insert(buf, (" "):rep(indent + 4) .. 'case "$arg" in')

   for _, command in ipairs(self._commands) do
      table.insert(buf, (" "):rep(indent + 8) .. table.concat(command._aliases, "|") .. ")")
      if self._parent then
         table.insert(buf, (" "):rep(indent + 12) .. 'cmd="$cmd ' .. command._name .. '"')
      else
         table.insert(buf, (" "):rep(indent + 12) .. 'cmd="' .. command._name .. '"')
      end
      table.insert(buf, (" "):rep(indent + 12) .. 'opts="$opts ' .. command:_get_options() .. '"')
      command:_bash_get_cmd(buf, indent + 12)
      table.insert(buf, (" "):rep(indent + 12) .. "break")
      table.insert(buf, (" "):rep(indent + 12) .. ";;")
   end

   table.insert(buf, (" "):rep(indent + 4) .. "esac")
   table.insert(buf, (" "):rep(indent) .. "done")
end

function Parser:_bash_cmd_completions(buf)
   local cmd_buf = {}
   if self._parent then
      self:_bash_option_args(cmd_buf, 12)
   end
   if #self._commands > 0 then
      table.insert(cmd_buf, (" "):rep(12) .. 'COMPREPLY=($(compgen -W "' .. self:_get_commands() .. '" -- "$cur"))')
   elseif self._is_help_command then
      table.insert(cmd_buf, (" "):rep(12)
         .. 'COMPREPLY=($(compgen -W "'
         .. self._parent:_get_commands()
         .. '" -- "$cur"))')
   end
   if #cmd_buf > 0 then
      table.insert(buf, (" "):rep(8) .. "'" .. self:_get_fullname(true) .. "')")
      table.insert(buf, table.concat(cmd_buf, "\n"))
      table.insert(buf, (" "):rep(12) .. ";;")
   end

   for _, command in ipairs(self._commands) do
      command:_bash_cmd_completions(buf)
   end
end

function Parser:get_bash_complete()
   self._basename = base_name(self._name)
   assert(self:_is_shell_safe())
   local buf = {([[
_%s() {
    local IFS=$' \t\n'
    local args cur prev cmd opts arg
    args=("${COMP_WORDS[@]}")
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="%s"
]]):format(self._basename, self:_get_options())}

   self:_bash_option_args(buf, 4)
   self:_bash_get_cmd(buf, 4)
   if #self._commands > 0 then
      table.insert(buf, "")
      table.insert(buf, (" "):rep(4) .. 'case "$cmd" in')
      self:_bash_cmd_completions(buf)
      table.insert(buf, (" "):rep(4) .. "esac\n")
   end

   table.insert(buf, ([=[
    if [[ "$cur" = -* ]]; then
        COMPREPLY=($(compgen -W "$opts" -- "$cur"))
    fi
}

complete -F _%s -o bashdefault -o default %s
]=]):format(self._basename, self._basename))

   return table.concat(buf, "\n")
end

function Parser:_zsh_arguments(buf, cmd_name, indent)
   if self._parent then
      table.insert(buf, (" "):rep(indent) .. "options=(")
      table.insert(buf, (" "):rep(indent + 2) .. "$options")
   else
      table.insert(buf, (" "):rep(indent) .. "local -a options=(")
   end

   for _, option in ipairs(self._options) do
      local line = {}
      if #option._aliases > 1 then
         if option._maxcount > 1 then
            table.insert(line, '"*"')
         end
         table.insert(line, "{" .. table.concat(option._aliases, ",") .. '}"')
      else
         table.insert(line, '"')
         if option._maxcount > 1 then
            table.insert(line, "*")
         end
         table.insert(line, option._name)
      end
      if option._description then
         local description = get_short_description(option):gsub('["%]:`$]', "\\%0")
         table.insert(line, "[" .. description .. "]")
      end
      if option._maxargs == math.huge then
         table.insert(line, ":*")
      end
      if option._choices then
         table.insert(line, ": :(" .. table.concat(option._choices, " ") .. ")")
      elseif option._maxargs > 0 then
         table.insert(line, ": :_files")
      end
      table.insert(line, '"')
      table.insert(buf, (" "):rep(indent + 2) .. table.concat(line))
   end

   table.insert(buf, (" "):rep(indent) .. ")")
   table.insert(buf, (" "):rep(indent) .. "_arguments -s -S \\")
   table.insert(buf, (" "):rep(indent + 2) .. "$options \\")

   if self._is_help_command then
      table.insert(buf, (" "):rep(indent + 2) .. '": :(' .. self._parent:_get_commands() .. ')" \\')
   else
      for _, argument in ipairs(self._arguments) do
         local spec
         if argument._choices then
            spec = ": :(" .. table.concat(argument._choices, " ") .. ")"
         else
            spec = ": :_files"
         end
         if argument._maxargs == math.huge then
            table.insert(buf, (" "):rep(indent + 2) .. '"*' .. spec .. '" \\')
            break
         end
         for _ = 1, argument._maxargs do
            table.insert(buf, (" "):rep(indent + 2) .. '"' .. spec .. '" \\')
         end
      end

      if #self._commands > 0 then
         table.insert(buf, (" "):rep(indent + 2) .. '": :_' .. cmd_name .. '_cmds" \\')
         table.insert(buf, (" "):rep(indent + 2) .. '"*:: :->args" \\')
      end
   end

   table.insert(buf, (" "):rep(indent + 2) .. "&& return 0")
end

function Parser:_zsh_cmds(buf, cmd_name)
   table.insert(buf, "\n_" .. cmd_name .. "_cmds() {")
   table.insert(buf, "  local -a commands=(")

   for _, command in ipairs(self._commands) do
      local line = {}
      if #command._aliases > 1 then
         table.insert(line, "{" .. table.concat(command._aliases, ",") .. '}"')
      else
         table.insert(line, '"' .. command._name)
      end
      if command._description then
         table.insert(line, ":" .. get_short_description(command):gsub('["`$]', "\\%0"))
      end
      table.insert(buf, "    " .. table.concat(line) .. '"')
   end

   table.insert(buf, '  )\n  _describe "command" commands\n}')
end

function Parser:_zsh_complete_help(buf, cmds_buf, cmd_name, indent)
   if #self._commands == 0 then
      return
   end

   self:_zsh_cmds(cmds_buf, cmd_name)
   table.insert(buf, "\n" .. (" "):rep(indent) .. "case $words[1] in")

   for _, command in ipairs(self._commands) do
      local name = cmd_name .. "_" .. command._name
      table.insert(buf, (" "):rep(indent + 2) .. table.concat(command._aliases, "|") .. ")")
      command:_zsh_arguments(buf, name, indent + 4)
      command:_zsh_complete_help(buf, cmds_buf, name, indent + 4)
      table.insert(buf, (" "):rep(indent + 4) .. ";;\n")
   end

   table.insert(buf, (" "):rep(indent) .. "esac")
end

function Parser:get_zsh_complete()
   self._basename = base_name(self._name)
   assert(self:_is_shell_safe())
   local buf = {("#compdef %s\n"):format(self._basename)}
   local cmds_buf = {}
   table.insert(buf, "_" .. self._basename .. "() {")
   if #self._commands > 0 then
      table.insert(buf, "  local context state state_descr line")
      table.insert(buf, "  typeset -A opt_args\n")
   end
   self:_zsh_arguments(buf, self._basename, 2)
   self:_zsh_complete_help(buf, cmds_buf, self._basename, 2)
   table.insert(buf, "\n  return 1")
   table.insert(buf, "}")

   local result = table.concat(buf, "\n")
   if #cmds_buf > 0 then
      result = result .. "\n" .. table.concat(cmds_buf, "\n")
   end
   return result .. "\n\n_" .. self._basename .. "\n"
end

local function fish_escape(string)
   return string:gsub("[\\']", "\\%0")
end

function Parser:_fish_get_cmd(buf, indent)
   if #self._commands == 0 then
      return
   end

   table.insert(buf, (" "):rep(indent) .. "set -e cmdline[1]")
   table.insert(buf, (" "):rep(indent) .. "for arg in $cmdline")
   table.insert(buf, (" "):rep(indent + 4) .. "switch $arg")

   for _, command in ipairs(self._commands) do
      table.insert(buf, (" "):rep(indent + 8) .. "case " .. table.concat(command._aliases, " "))
      table.insert(buf, (" "):rep(indent + 12) .. "set cmd $cmd " .. command._name)
      command:_fish_get_cmd(buf, indent + 12)
      table.insert(buf, (" "):rep(indent + 12) .. "break")
   end

   table.insert(buf, (" "):rep(indent + 4) .. "end")
   table.insert(buf, (" "):rep(indent) .. "end")
end

function Parser:_fish_complete_help(buf, basename)
   local prefix = "complete -c " .. basename
   table.insert(buf, "")

   for _, command in ipairs(self._commands) do
      local aliases = table.concat(command._aliases, " ")
      local line
      if self._parent then
         line = ("%s -n '__fish_%s_using_command %s' -xa '%s'")
            :format(prefix, basename, self:_get_fullname(true), aliases)
      else
         line = ("%s -n '__fish_%s_using_command' -xa '%s'"):format(prefix, basename, aliases)
      end
      if command._description then
         line = ("%s -d '%s'"):format(line, fish_escape(get_short_description(command)))
      end
      table.insert(buf, line)
   end

   if self._is_help_command then
      local line = ("%s -n '__fish_%s_using_command %s' -xa '%s'")
         :format(prefix, basename, self:_get_fullname(true), self._parent:_get_commands())
      table.insert(buf, line)
   end

   for _, option in ipairs(self._options) do
      local parts = {prefix}

      if self._parent then
         table.insert(parts, "-n '__fish_" .. basename .. "_seen_command " .. self:_get_fullname(true) .. "'")
      end

      for _, alias in ipairs(option._aliases) do
         if alias:match("^%-.$") then
            table.insert(parts, "-s " .. alias:sub(2))
         elseif alias:match("^%-%-.+") then
            table.insert(parts, "-l " .. alias:sub(3))
         end
      end

      if option._choices then
         table.insert(parts, "-xa '" .. table.concat(option._choices, " ") .. "'")
      elseif option._minargs > 0 then
         table.insert(parts, "-r")
      end

      if option._description then
         table.insert(parts, "-d '" .. fish_escape(get_short_description(option)) .. "'")
      end

      table.insert(buf, table.concat(parts, " "))
   end

   for _, command in ipairs(self._commands) do
      command:_fish_complete_help(buf, basename)
   end
end

function Parser:get_fish_complete()
   self._basename = base_name(self._name)
   assert(self:_is_shell_safe())
   local buf = {}

   if #self._commands > 0 then
      table.insert(buf, ([[
function __fish_%s_print_command
    set -l cmdline (commandline -poc)
    set -l cmd]]):format(self._basename))
      self:_fish_get_cmd(buf, 4)
      table.insert(buf, ([[
    echo "$cmd"
end

function __fish_%s_using_command
    test (__fish_%s_print_command) = "$argv"
    and return 0
    or return 1
end

function __fish_%s_seen_command
    string match -q "$argv*" (__fish_%s_print_command)
    and return 0
    or return 1
end]]):format(self._basename, self._basename, self._basename, self._basename))
   end

   self:_fish_complete_help(buf, self._basename)
   return table.concat(buf, "\n") .. "\n"
end

local function get_tip(context, wrong_name)
   local context_pool = {}
   local possible_name
   local possible_names = {}

   for name in pairs(context) do
      if type(name) == "string" then
         for i = 1, #name do
            possible_name = name:sub(1, i - 1) .. name:sub(i + 1)

            if not context_pool[possible_name] then
               context_pool[possible_name] = {}
            end

            table.insert(context_pool[possible_name], name)
         end
      end
   end

   for i = 1, #wrong_name + 1 do
      possible_name = wrong_name:sub(1, i - 1) .. wrong_name:sub(i + 1)

      if context[possible_name] then
         possible_names[possible_name] = true
      elseif context_pool[possible_name] then
         for _, name in ipairs(context_pool[possible_name]) do
            possible_names[name] = true
         end
      end
   end

   local first = next(possible_names)

   if first then
      if next(possible_names, first) then
         local possible_names_arr = {}

         for name in pairs(possible_names) do
            table.insert(possible_names_arr, "'" .. name .. "'")
         end

         table.sort(possible_names_arr)
         return "\nDid you mean one of these: " .. table.concat(possible_names_arr, " ") .. "?"
      else
         return "\nDid you mean '" .. first .. "'?"
      end
   else
      return ""
   end
end

local ElementState = class({
   invocations = 0
})

function ElementState:__call(state, element)
   self.state = state
   self.result = state.result
   self.element = element
   self.target = element._target or element:_get_default_target()
   self.action, self.result[self.target] = element:_get_action()
   return self
end

function ElementState:error(fmt, ...)
   self.state:error(fmt, ...)
end

function ElementState:convert(argument, index)
   local converter = self.element._convert

   if converter then
      local ok, err

      if type(converter) == "function" then
         ok, err = converter(argument)
      elseif type(converter[index]) == "function" then
         ok, err = converter[index](argument)
      else
         ok = converter[argument]
      end

      if ok == nil then
         self:error(err and "%s" or "malformed argument '%s'", err or argument)
      end

      argument = ok
   end

   return argument
end

function ElementState:default(mode)
   return self.element._defmode:find(mode) and self.element._default
end

local function bound(noun, min, max, is_max)
   local res = ""

   if min ~= max then
      res = "at " .. (is_max and "most" or "least") .. " "
   end

   local number = is_max and max or min
   return res .. tostring(number) .. " " .. noun ..  (number == 1 and "" or "s")
end

function ElementState:set_name(alias)
   self.name = ("%s '%s'"):format(alias and "option" or "argument", alias or self.element._name)
end

function ElementState:invoke()
   self.open = true
   self.overwrite = false

   if self.invocations >= self.element._maxcount then
      if self.element._overwrite then
         self.overwrite = true
      else
         local num_times_repr = bound("time", self.element._mincount, self.element._maxcount, true)
         self:error("%s must be used %s", self.name, num_times_repr)
      end
   else
      self.invocations = self.invocations + 1
   end

   self.args = {}

   if self.element._maxargs <= 0 then
      self:close()
   end

   return self.open
end

function ElementState:check_choices(argument)
   if self.element._choices then
      for _, choice in ipairs(self.element._choices) do
         if argument == choice then
            return
         end
      end
      local choices_list = "'" .. table.concat(self.element._choices, "', '") .. "'"
      local is_option = getmetatable(self.element) == Option
      self:error("%s%s must be one of %s", is_option and "argument for " or "", self.name, choices_list)
   end
end

function ElementState:pass(argument)
   self:check_choices(argument)
   argument = self:convert(argument, #self.args + 1)
   table.insert(self.args, argument)

   if #self.args >= self.element._maxargs then
      self:close()
   end

   return self.open
end

function ElementState:complete_invocation()
   while #self.args < self.element._minargs do
      self:pass(self.element._default)
   end
end

function ElementState:close()
   if self.open then
      self.open = false

      if #self.args < self.element._minargs then
         if self:default("a") then
            self:complete_invocation()
         else
            if #self.args == 0 then
               if getmetatable(self.element) == Argument then
                  self:error("missing %s", self.name)
               elseif self.element._maxargs == 1 then
                  self:error("%s requires an argument", self.name)
               end
            end

            self:error("%s requires %s", self.name, bound("argument", self.element._minargs, self.element._maxargs))
         end
      end

      local args

      if self.element._maxargs == 0 then
         args = self.args[1]
      elseif self.element._maxargs == 1 then
         if self.element._minargs == 0 and self.element._mincount ~= self.element._maxcount then
            args = self.args
         else
            args = self.args[1]
         end
      else
         args = self.args
      end

      self.action(self.result, self.target, args, self.overwrite)
   end
end

local ParseState = class({
   result = {},
   options = {},
   arguments = {},
   argument_i = 1,
   element_to_mutexes = {},
   mutex_to_element_state = {},
   command_actions = {}
})

function ParseState:__call(parser, error_handler)
   self.parser = parser
   self.error_handler = error_handler
   self.charset = parser:_update_charset()
   self:switch(parser)
   return self
end

function ParseState:error(fmt, ...)
   self.error_handler(self.parser, fmt:format(...))
end

function ParseState:switch(parser)
   self.parser = parser

   if parser._action then
      table.insert(self.command_actions, {action = parser._action, name = parser._name})
   end

   for _, option in ipairs(parser._options) do
      option = ElementState(self, option)
      table.insert(self.options, option)

      for _, alias in ipairs(option.element._aliases) do
         self.options[alias] = option
      end
   end

   for _, mutex in ipairs(parser._mutexes) do
      for _, element in ipairs(mutex) do
         if not self.element_to_mutexes[element] then
            self.element_to_mutexes[element] = {}
         end

         table.insert(self.element_to_mutexes[element], mutex)
      end
   end

   for _, argument in ipairs(parser._arguments) do
      argument = ElementState(self, argument)
      table.insert(self.arguments, argument)
      argument:set_name()
      argument:invoke()
   end

   self.handle_options = parser._handle_options
   self.argument = self.arguments[self.argument_i]
   self.commands = parser._commands

   for _, command in ipairs(self.commands) do
      for _, alias in ipairs(command._aliases) do
         self.commands[alias] = command
      end
   end
end

function ParseState:get_option(name)
   local option = self.options[name]

   if not option then
      self:error("unknown option '%s'%s", name, get_tip(self.options, name))
   else
      return option
   end
end

function ParseState:get_command(name)
   local command = self.commands[name]

   if not command then
      if #self.commands > 0 then
         self:error("unknown command '%s'%s", name, get_tip(self.commands, name))
      else
         self:error("too many arguments")
      end
   else
      return command
   end
end

function ParseState:check_mutexes(element_state)
   if self.element_to_mutexes[element_state.element] then
      for _, mutex in ipairs(self.element_to_mutexes[element_state.element]) do
         local used_element_state = self.mutex_to_element_state[mutex]

         if used_element_state and used_element_state ~= element_state then
            self:error("%s can not be used together with %s", element_state.name, used_element_state.name)
         else
            self.mutex_to_element_state[mutex] = element_state
         end
      end
   end
end

function ParseState:invoke(option, name)
   self:close()
   option:set_name(name)
   -- self:check_mutexes(option, name)
   self:check_mutexes(option)

   if option:invoke() then
      self.option = option
   end
end

function ParseState:pass(arg)
   if self.option then
      if not self.option:pass(arg) then
         self.option = nil
      end
   elseif self.argument then
      self:check_mutexes(self.argument)

      if not self.argument:pass(arg) then
         self.argument_i = self.argument_i + 1
         self.argument = self.arguments[self.argument_i]
      end
   else
      local command = self:get_command(arg)
      self.result[command._target or command._name] = true

      if self.parser._command_target then
         self.result[self.parser._command_target] = command._name
      end

      self:switch(command)
   end
end

function ParseState:close()
   if self.option then
      self.option:close()
      self.option = nil
   end
end

function ParseState:finalize()
   self:close()

   for i = self.argument_i, #self.arguments do
      local argument = self.arguments[i]
      if #argument.args == 0 and argument:default("u") then
         argument:complete_invocation()
      else
         argument:close()
      end
   end

   if self.parser._require_command and #self.commands > 0 then
      self:error("a command is required")
   end

   for _, option in ipairs(self.options) do
      option.name = option.name or ("option '%s'"):format(option.element._name)

      if option.invocations == 0 then
         if option:default("u") then
            option:invoke()
            option:complete_invocation()
            option:close()
         end
      end

      local mincount = option.element._mincount

      if option.invocations < mincount then
         if option:default("a") then
            while option.invocations < mincount do
               option:invoke()
               option:close()
            end
         elseif option.invocations == 0 then
            self:error("missing %s", option.name)
         else
            self:error("%s must be used %s", option.name, bound("time", mincount, option.element._maxcount))
         end
      end
   end

   for i = #self.command_actions, 1, -1 do
      self.command_actions[i].action(self.result, self.command_actions[i].name)
   end
end

function ParseState:parse(args)
   for _, arg in ipairs(args) do
      local plain = true

      if self.handle_options then
         local first = arg:sub(1, 1)

         if self.charset[first] then
            if #arg > 1 then
               plain = false

               if arg:sub(2, 2) == first then
                  if #arg == 2 then
                     if self.options[arg] then
                        local option = self:get_option(arg)
                        self:invoke(option, arg)
                     else
                        self:close()
                     end

                     self.handle_options = false
                  else
                     local equals = arg:find "="
                     if equals then
                        local name = arg:sub(1, equals - 1)
                        local option = self:get_option(name)

                        if option.element._maxargs <= 0 then
                           self:error("option '%s' does not take arguments", name)
                        end

                        self:invoke(option, name)
                        self:pass(arg:sub(equals + 1))
                     else
                        local option = self:get_option(arg)
                        self:invoke(option, arg)
                     end
                  end
               else
                  for i = 2, #arg do
                     local name = first .. arg:sub(i, i)
                     local option = self:get_option(name)
                     self:invoke(option, name)

                     if i ~= #arg and option.element._maxargs > 0 then
                        self:pass(arg:sub(i + 1))
                        break
                     end
                  end
               end
            end
         end
      end

      if plain then
         self:pass(arg)
      end
   end

   self:finalize()
   return self.result
end

function Parser:error(msg)
   io.stderr:write(("%s\n\nError: %s\n"):format(self:get_usage(), msg))
   os.exit(1)
end

-- Compatibility with strict.lua and other checkers:
local default_cmdline = rawget(_G, "arg") or {}

function Parser:_parse(args, error_handler)
   return ParseState(self, error_handler):parse(args or default_cmdline)
end

function Parser:parse(args)
   return self:_parse(args, self.error)
end

local function xpcall_error_handler(err)
   return tostring(err) .. "\noriginal " .. debug.traceback("", 2):sub(2)
end

function Parser:pparse(args)
   local parse_error

   local ok, result = xpcall(function()
      return self:_parse(args, function(_, err)
         parse_error = err
         error(err, 0)
      end)
   end, xpcall_error_handler)

   if ok then
      return true, result
   elseif not parse_error then
      error(result, 0)
   else
      return false, parse_error
   end
end

local argparse = {}

argparse.version = "0.7.1"

setmetatable(argparse, {__call = function(_, ...)
   return Parser(default_cmdline[0]):add_help(true)(...)
end})

return argparse
 end)
package.preload['cloud'] = (function (...)
--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local curl = require "cURL"

require "json-safe"
require "logger"
require "native-type-helper"

local Log = Logger:new('Cloud')

local SizeConv = {
    Byte2Mb = function (num,saveBit)
        saveBit = saveBit or 2
        return tonumber(('%.'..saveBit..'f'):format(num/1048576))
    end
}

Cloud = {
    Protocol = {
        ['Http'] = {
            prefix = { 'http://', 'https://' }
        },
        ['Lanzou'] = {
            prefix = { 'lanzou://' },
            api = 'https://api-lanzou.amd.rocks/?url=%s&pwd=%s'
        }
        --- ['Ftp'] = {
        ---     prefix = { 'ftp://' }
        --- }
    },
    UA = "Mozilla/5.0 (Linux; Android 4.4.2; Nexus 4 Build/KOT49H) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.114 Mobile Safari/537.36"
}

---解析链接, 返回protocol名称
---@param url string 链接
---@return string|nil
function Cloud:parseLink(url)
    for name,protoObj in pairs(Cloud.Protocol) do
        if type(protoObj) == 'table' then
            for _,prefix in pairs(protoObj.prefix) do
                if url:sub(1,prefix:len()) == prefix then
                    return name
                end
            end
        end
    end
    return nil
end

---获取所有支持的协议
---@return table
function Cloud:getAllProtocol()
    local rtn = {}
    for k,v in pairs(self.Protocol) do
        if type(v) == 'table' then
            rtn[#rtn+1] = k
        end
    end
    return rtn
end

--- 创建新任务
---
--- **HTTP** `https://hengaaaa.ugly/114.zip`
---
--- **LANZOU** `lanzou://tiansuohao2:pwd=humo`
---
---@param dict table 需提供 url, writefunction, 可选 ua, header。
---@return boolean
function Cloud:NewTask(dict)
    local name = self:parseLink(dict.url)
    if not name then
        Log:Error('正在解析无法识别的URL：%s',dict.url)
        return false
    end
    if not Settings:get('repo.allow_insecure_protocol') and dict.url:sub(1,7) == 'http://' then
        Log:Error('已禁用不安全的传输协议。')
        return false
    end
    local protocol = self.Protocol[name]
    if dict.payload then
        for _,v in pairs(dict.payload) do
            dict.k = v
        end
        dict.payload = nil
    end
    if name == 'Http' then
        return protocol:get(dict.url,dict)
    elseif name == 'Lanzou' then
        local tmp = dict.url:split(':')
        local shareId = tmp[2]:sub(3)
        if shareId:sub(-1) == '/' then
            shareId = shareId:sub(1,shareId:len()-1)
        end
        local passwd
        if tmp[3] then
            passwd = tmp[3]:split('=')
            if passwd then passwd = passwd[2] end 
        end
        return protocol:get(shareId,passwd,dict)
    end
    return false
end

--- 蓝奏云解析下载
---
--- *注意* 只支持单文件解析，目录解析暂不支持
---
---@param shareId string 分享ID, 即分享链接末部分
---@param passwd? string 密码(如果有), 可以为nil
---@param payload table 请求载荷
---@return boolean
function Cloud.Protocol.Lanzou:get(shareId,passwd,payload)
    local url = ('https://www.lanzouy.com/%s'):format(shareId) --- not important.
    passwd = passwd or ''
    local L = Logger:new('LanZou')
    L:Info('正在获取下载链接...')
    local res = ''
    Cloud:NewTask {
        url = self.api:format(url,passwd),
        writefunction = function (data)
            res = res .. data
        end,
        quiet = true
    }
    local obj = JSON:parse(res)
    if not obj then
        L:Error('获取下载链接失败，API返回了错误的信息。')
        return false
    end
    if obj.code ~= 200 then
        L:Error('获取下载链接失败 (%s:%s)',obj.code,obj.msg)
        return false
    end
    L:Info('正在下载: %s',obj.name)
    return Cloud:NewTask {
        url = obj.downUrl,
        writefunction = payload.writefunction,
        quiet = payload.quiet
    }

end

--- HTTP (s) 下载
---@param url string 链接
---@param payload table 请求载荷
---@return boolean
function Cloud.Protocol.Http:get(url,payload)
    local blocks = 40
    local proInfo = {
        recording = {},
        call_times = 0,
        average_speed = 0,
        max_size = 0,
        steps = { '○','◔','◑','◕','●' },
        step = 1,
        progress = ('━'):rep(blocks),
        size_vaild = false,
        completed = false
    }
    payload.ua = payload.ua or Cloud.UA
    payload.quiet = payload.quiet or false
    local tmp_wfunc = ''
    local easy = curl.easy {
        url = url,
        httpheader = payload.header,
        useragent = payload.ua,
        accept_encoding = 'gzip, deflate, br',
        writefunction = function (str)
            tmp_wfunc = tmp_wfunc .. str
        end,
        progressfunction = function (size,downloaded,uks_1,uks_2)
            local Rec = proInfo
            Rec.call_times = Rec.call_times + 1
            local time = os.time()
            local speed = Rec.average_speed
            if not Rec.recording[time] or (size~=0 and not Rec.size_vaild) then
                --- calc avg speed.
                local add_t,add_d = 0,0
                for i = time-3,time do
                    if Rec.recording[i] and Rec.recording[i-1] then
                        add_t = add_t + 1
                        add_d = add_d + (Rec.recording[i]-Rec.recording[i-1])
                    end
                end
                speed = SizeConv.Byte2Mb(add_d/add_t)
                Rec.average_speed = speed or Rec.average_speed
                --- calc progress
                if size ~= 0 then
                    Rec.size_vaild = true
                    Rec.progress = ('—'):rep(blocks):gsub('—','━',math.floor(blocks*(downloaded/size)))
                end
            end
            Rec.recording[time] = downloaded
            if Rec.call_times % 10 == 0 then
                -- next step.
                Rec.step = Rec.step + 1
                if Rec.step > #Rec.steps then
                    Rec.step = 1
                end
            end
            local prog
            if size ~= 0 then
                prog = math.floor(downloaded/size*100)
            else
                prog = 0
            end
            local formatted = (' %s %.3d%% %s %.2fM/s (%sM/%sM)'):format(Rec.steps[Rec.step],prog,Rec.progress,Rec.average_speed,SizeConv.Byte2Mb(downloaded),SizeConv.Byte2Mb(size))
            local strlen = formatted:len()
            if Rec.max_size < strlen then
                Rec.max_size = strlen
            end
            Log:Write('\r',formatted,(' '):rep(Rec.max_size - strlen))
        end,
        noprogress = payload.quiet,
        ssl_verifypeer = false,
        ssl_verifyhost = false
    }
    local msf = easy:perform()
    local code = msf:getinfo_response_code()
    if not payload.quiet then
        Log:Write('\r √ 100%% %s %.2fM/s  (%sM).'..(' '):rep(15)..'\n',('━'):rep(blocks),SizeConv.Byte2Mb(msf:getinfo_speed_download()),SizeConv.Byte2Mb(msf:getinfo_size_download()))
    end
    if code == 200 then
        local T = type(payload.writefunction)
        if T == 'userdata' then
            payload.writefunction:write(tmp_wfunc)
            payload.writefunction:close()
        elseif T == 'function' then
            payload.writefunction(tmp_wfunc)
        else
            Log:Error('Unknown writefunction type: %s',T)
        end
        easy:close()
        return true
    end
    easy:close()
    return false
end

return Cloud end)
package.preload['cURL'] = (function (...)
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2014-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of Lua-cURL library.
--

local curl = require "lcurl.safe"
local impl = require "cURL.impl.cURL"

return impl(curl)
 end)
package.preload['cURL.impl.cURL'] = (function (...)
--
--  Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Copyright (C) 2014-2021 Alexey Melnichuk <alexeymelnichuck@gmail.com>
--
--  Licensed according to the included 'LICENSE' document
--
--  This file is part of Lua-cURL library.
--

local module_info = {
  _NAME      = "Lua-cURL";
  _VERSION   = "0.3.13";
  _LICENSE   = "MIT";
  _COPYRIGHT = "Copyright (c) 2014-2021 Alexey Melnichuk";
}

local function hash_id(str)
  local id = string.match(str, "%((.-)%)") or string.match(str, ': (%x+)$')
  return id
end

local function clone(t, o)
  o = o or {}
  for k,v in pairs(t) do o[k]=v end
  return o
end

local function wrap_function(k)
  return function(self, ...)
    local ok, err = self._handle[k](self._handle, ...)
    if ok == self._handle then return self end
    return ok, err
  end
end

local function wrap_setopt_flags(k, flags)
  k = "setopt_" .. k
  local flags2 = clone(flags)
  for k, v in pairs(flags) do flags2[v] = v end

  return function(self, v)
    v = assert(flags2[v], "Unsupported value " .. tostring(v))
    local ok, err = self._handle[k](self._handle, v)
    if ok == self._handle then return self end
    return ok, err
  end
end

local function new_buffers()
  local buffers = {resp = {}, _ = {}}

  function buffers:append(e, ...)
    local resp = assert(e:getinfo_response_code())
    if not self._[e] then self._[e] = {} end

    local b = self._[e]

    if self.resp[e] ~= resp then
      b[#b + 1] = {"response", resp}
      self.resp[e] = resp
    end

    b[#b + 1] = {...}
  end

  function buffers:next()
    for e, t in pairs(self._) do
      local m = table.remove(t, 1)
      if m then return e, m end
    end
  end

  return buffers
end

local function make_iterator(self, perform)
  local curl = require "lcurl.safe"

  local buffers = new_buffers()

  -- reset callbacks to all easy handles
  local function reset_easy(self)
    if not self._easy_mark then -- that means we have some new easy handles
      for h, e in pairs(self._easy) do if h ~= 'n' then 
          e:setopt_writefunction (function(str) buffers:append(e, "data",   str) end)
          e:setopt_headerfunction(function(str) buffers:append(e, "header", str) end)
      end end
      self._easy_mark = true
    end
    return self._easy.n
  end

  if 0 == reset_easy(self) then return end

  assert(perform(self))

  return function()
    -- we can add new handle during iteration
    local remain = reset_easy(self)

    -- wait next event
    while true do
      local e, t = buffers:next()
      if t then return t[2], t[1], e end
      if remain == 0 then break end

      self:wait()

      local n = assert(perform(self))

      if n <= remain then
        while true do
          local e, ok, err = assert(self:info_read())
          if e == 0 then break end
          if ok then
            ok = e:getinfo_response_code() or ok
            buffers:append(e, "done", ok)
          else buffers:append(e, "error", err) end
          self:remove_handle(e)
          e:unsetopt_headerfunction()
          e:unsetopt_writefunction()
        end
      end

      remain = n
    end
  end
end

-- name = <string>/<stream>/<file>/<buffer>/<content>
--
-- <stream> = {
--   stream  = function/object
--   length  = ?number
--   name    = ?string
--   type    = ?string
--   headers = ?table
-- }
--
-- <file> = {
--   file    = string
--   type    = ?string
--   name    = ?string
--   headers = ?table
-- }
--
-- <buffer> = {
--   data    = string
--   name    = string
--   type    = ?string
--   headers = ?table
-- }
--
-- <content> = {
--   content = string -- or first key in table
--   type    = ?string
--   headers = ?table
-- }
-- 

local function form_add_element(form, name, value)
  local vt = type(value)
  if vt == "string" then return form:add_content(name, value) end

  assert(type(name) == "string")
  assert(vt == "table")
  assert((value.name    == nil) or (type(value.name   ) == 'string'))
  assert((value.type    == nil) or (type(value.type   ) == 'string'))
  assert((value.headers == nil) or (type(value.headers) == 'table' ))

  if value.stream then
    local vst = type(value.stream)

    if vst == 'function' then
      assert(type(value.length) == 'number')
      local length = value.length
      return form:add_stream(name, value.name, value.type, value.headers, length, value.stream)
    end

    if (vst == 'table') or (vst == 'userdata') then
      local length = value.length or assert(value.stream:length())
      assert(type(length) == 'number')
      return form:add_stream(name, value.name, value.type, value.headers, length, value.stream)
    end

    error("Unsupported stream type: " .. vst)
  end

  if value.file then
    assert(type(value.file) == 'string')
    return form:add_file(name, value.file, value.type, value.filename, value.headers)
  end

  if value.data then
    assert(type(value.data) == 'string')
    assert(type(value.name) == 'string')
    return form:add_buffer(name, value.name, value.data, value.type, value.headers)
  end

  local content = value[1] or value.content
  if content then
    assert(type(content) == 'string')
    if value.type then
      return form:add_content(name, content, value.type, value.headers)
    end
    return form:add_content(name, content, value.headers)
  end

  return form
end

local function form_add(form, data)
  for k, v in pairs(data) do
    local ok, err = form_add_element(form, k, v)
    if not ok then return nil, err end
  end

  return form
end

local function class(ctor)
  local C = {}
  C.__index = function(self, k)
    local fn = C[k]

    if not fn and self._handle[k] then
      fn = wrap_function(k)
      C[k] = fn
    end
    return fn
  end

  function C:new(...)
    local h, err = ctor()
    if not h then return nil, err end

    local o = setmetatable({
      _handle = h
    }, self)

    if self.__init then return self.__init(o, ...) end

    return o
  end

  function C:handle()
    return self._handle
  end

  return C
end

local function Load_cURLv2(cURL, curl)

-------------------------------------------
local Easy = class(curl.easy) do

local perform             = wrap_function("perform")
local setopt_share        = wrap_function("setopt_share")
local setopt_readfunction = wrap_function("setopt_readfunction")

local NONE = {}

function Easy:_call_readfunction(...)
  if self._rd_ud == NONE then
    return self._rd_fn(...)
  end
  return self._rd_fn(self._rd_ud, ...)
end

function Easy:setopt_readfunction(fn, ...)
  assert(fn)

  if select('#', ...) == 0 then
    if type(fn) == "function" then
      self._rd_fn = fn
      self._rd_ud = NONE
    else
      self._rd_fn = assert(fn.read)
      self._rd_ud = fn
    end
  else
    self._rd_fn = fn
    self._ud_fn = ...
  end

  return setopt_readfunction(self, fn, ...)
end

function Easy:perform(opt)
  opt = opt or {}

  local oerror = opt.errorfunction or function(err) return nil, err end

  if opt.readfunction then
    local ok, err = self:setopt_readfunction(opt.readfunction)
    if not ok then return oerror(err) end
  end

  if opt.writefunction then
    local ok, err = self:setopt_writefunction(opt.writefunction)
    if not ok then return oerror(err) end
  end

  if opt.headerfunction then
    local ok, err = self:setopt_headerfunction(opt.headerfunction)
    if not ok then return oerror(err) end
  end

  local ok, err = perform(self)
  if not ok then return oerror(err) end

  return self 
end

function Easy:post(data)
  local form = curl.form()
  local ok, err = true, nil

  for k, v in pairs(data) do
    if type(v) == "string" then
      ok, err = form:add_content(k, v)
    else
      assert(type(v) == "table")
      if v.stream_length then
        local len = assert(tonumber(v.stream_length))
        assert(v.file)
        if v.stream then
          ok, err = form:add_stream(k, v.file, v.type, v.headers, len, v.stream)
        else
          ok, err = form:add_stream(k, v.file, v.type, v.headers, len, self._call_readfunction, self)
        end
      elseif v.data then
        ok, err = form:add_buffer(k, v.file, v.data, v.type, v.headers)
      else
        ok, err = form:add_file(k, v.file, v.type, v.filename, v.headers)
      end
    end
    if not ok then break end
  end

  if not ok then
    form:free()
    return nil, err
  end

  ok, err = self:setopt_httppost(form)
  if not ok then
    form:free()
    return nil, err
  end

  return self
end

function Easy:setopt_share(s)
  return setopt_share(self, s:handle())
end

Easy.setopt_proxytype = wrap_setopt_flags("proxytype", {
  ["HTTP"            ] = curl.PROXY_HTTP;
  ["HTTP_1_0"        ] = curl.PROXY_HTTP_1_0;
  ["SOCKS4"          ] = curl.PROXY_SOCKS4;
  ["SOCKS5"          ] = curl.PROXY_SOCKS5;
  ["SOCKS4A"         ] = curl.PROXY_SOCKS4A;
  ["SOCKS5_HOSTNAME" ] = curl.PROXY_SOCKS5_HOSTNAME;
  ["HTTPS"           ] = curl.PROXY_HTTPS;
})

Easy.setopt_httpauth  = wrap_setopt_flags("httpauth", {
  ["NONE"            ] = curl.AUTH_NONE;
  ["BASIC"           ] = curl.AUTH_BASIC;
  ["DIGEST"          ] = curl.AUTH_DIGEST;
  ["GSSNEGOTIATE"    ] = curl.AUTH_GSSNEGOTIATE;
  ["NEGOTIATE"       ] = curl.AUTH_NEGOTIATE;
  ["NTLM"            ] = curl.AUTH_NTLM;
  ["DIGEST_IE"       ] = curl.AUTH_DIGEST_IE;
  ["GSSAPI"          ] = curl.AUTH_GSSAPI;
  ["NTLM_WB"         ] = curl.AUTH_NTLM_WB;
  ["ONLY"            ] = curl.AUTH_ONLY;
  ["ANY"             ] = curl.AUTH_ANY;
  ["ANYSAFE"         ] = curl.AUTH_ANYSAFE;
  ["BEARER"          ] = curl.AUTH_BEARER;
})

Easy.setopt_ssh_auth_types = wrap_setopt_flags("ssh_auth_types", {
  ["NONE"        ] = curl.SSH_AUTH_NONE;
  ["ANY"         ] = curl.SSH_AUTH_ANY;
  ["PUBLICKEY"   ] = curl.SSH_AUTH_PUBLICKEY;
  ["PASSWORD"    ] = curl.SSH_AUTH_PASSWORD;
  ["HOST"        ] = curl.SSH_AUTH_HOST;
  ["GSSAPI"      ] = curl.SSH_AUTH_GSSAPI;
  ["KEYBOARD"    ] = curl.SSH_AUTH_KEYBOARD;
  ["AGENT"       ] = curl.SSH_AUTH_AGENT;
  ["DEFAULT"     ] = curl.SSH_AUTH_DEFAULT;
})

end
-------------------------------------------

-------------------------------------------
local Multi = class(curl.multi) do

local perform       = wrap_function("perform")
local add_handle    = wrap_function("add_handle")
local remove_handle = wrap_function("remove_handle")

function Multi:__init()
  self._easy = {n = 0}
  return self
end

function Multi:perform()
  return make_iterator(self, perform)
end

function Multi:add_handle(e)
  assert(self._easy.n >= 0)

  local h = e:handle()
  if self._easy[h] then return self end

  local ok, err = add_handle(self, h)
  if not ok then return nil, err end
  self._easy[h], self._easy.n = e, self._easy.n + 1
  self._easy_mark = nil

  return self
end

function Multi:remove_handle(e)
  local h = e:handle()

  if self._easy[h] then
    self._easy[h], self._easy.n = nil, self._easy.n - 1
  end
  assert(self._easy.n >= 0)

  return remove_handle(self, h)
end

function Multi:info_read(...)
  while true do
    local h, ok, err = self:handle():info_read(...)
    if not h then return nil, ok end
    if h == 0 then return h end

    local e = self._easy[h]
    if e then
      if ... then
        self._easy[h], self._easy.n = nil, self._easy.n - 1
      end
      return e, ok, err
    end
  end
end

end
-------------------------------------------

-------------------------------------------
local Share = class(curl.share) do

Share.setopt_share = wrap_setopt_flags("share", {
  [ "COOKIE"      ] = curl.LOCK_DATA_COOKIE;
  [ "DNS"         ] = curl.LOCK_DATA_DNS;
  [ "SSL_SESSION" ] = curl.LOCK_DATA_SSL_SESSION;
})

end
-------------------------------------------

assert(cURL.easy_init == nil)
function cURL.easy_init()  return Easy:new()  end

assert(cURL.multi_init == nil)
function cURL.multi_init() return Multi:new() end

assert(cURL.share_init == nil)
function cURL.share_init() return Share:new() end

end

local function Load_cURLv3(cURL, curl)

-------------------------------------------
local Form = class(curl.form) do

function Form:__init(opt)
  if opt then return self:add(opt) end
  return self
end

function Form:add(data)
  return form_add(self, data)
end

function Form:__tostring()
  local id = hash_id(tostring(self._handle))
  return string.format("%s %s (%s)", module_info._NAME, 'Form', id)
end

end
-------------------------------------------

-------------------------------------------
local Easy = class(curl.easy) do

function Easy:__init(opt)
  if opt then return self:setopt(opt) end
  return self
end

local perform = wrap_function("perform")
function Easy:perform(opt)
  if opt then
    local ok, err = self:setopt(opt)
    if not ok then return nil, err end
  end

  return perform(self)
end

local setopt_httppost = wrap_function("setopt_httppost")
function Easy:setopt_httppost(form)
  return setopt_httppost(self, form:handle())
end

if curl.OPT_STREAM_DEPENDS then

local setopt_stream_depends = wrap_function("setopt_stream_depends")
function Easy:setopt_stream_depends(easy)
  return setopt_stream_depends(self, easy:handle())
end

local setopt_stream_depends_e = wrap_function("setopt_stream_depends_e")
function Easy:setopt_stream_depends_e(easy)
  return setopt_stream_depends_e(self, easy:handle())
end

end

local setopt = wrap_function("setopt")
local custom_setopt = {
  [curl.OPT_HTTPPOST         or true] = 'setopt_httppost';
  [curl.OPT_STREAM_DEPENDS   or true] = 'setopt_stream_depends';
  [curl.OPT_STREAM_DEPENDS_E or true] = 'setopt_stream_depends_e';
}
custom_setopt[true] = nil

function Easy:setopt(k, v)
  if type(k) == 'table' then
    local t = k

    local t2
    local hpost = t.httppost or t[curl.OPT_HTTPPOST]
    if hpost and hpost._handle then
      t = t2 or clone(t); t2 = t;
      if t.httppost           then t.httppost           = hpost:handle() end
      if t[curl.OPT_HTTPPOST] then t[curl.OPT_HTTPPOST] = hpost:handle() end
    end

    local easy = t.stream_depends or t[curl.OPT_STREAM_DEPENDS]
    if easy and easy._handle then
      t = t2 or clone(t); t2 = t;
      if t.stream_depends           then t.stream_depends           = easy:handle() end
      if t[curl.OPT_STREAM_DEPENDS] then t[curl.OPT_STREAM_DEPENDS] = easy:handle() end
    end

    local easy = t.stream_depends_e or t[curl.OPT_STREAM_DEPENDS_E]
    if easy and easy._handle then
      t = t2 or clone(t); t2 = t;
      if t.stream_depends_e           then t.stream_depends_e           = easy:handle() end
      if t[curl.OPT_STREAM_DEPENDS_E] then t[curl.OPT_STREAM_DEPENDS_E] = easy:handle() end
    end

    return setopt(self, t)
  end

  local setname = custom_setopt[k]
  if setname then
    return self[setname](self, v)
  end

  return setopt(self, k, v)
end

function Easy:__tostring()
  local id = hash_id(tostring(self._handle))
  return string.format("%s %s (%s)", module_info._NAME, 'Easy', id)
end

end
-------------------------------------------

-------------------------------------------
local Multi = class(curl.multi) do

local add_handle    = wrap_function("add_handle")
local remove_handle = wrap_function("remove_handle")

function Multi:__init(opt)
  self._easy = {n = 0}
  if opt then self:setopt(opt) end
  return self
end

function Multi:iperform()
  return make_iterator(self, self.perform)
end

function Multi:add_handle(e)
  assert(self._easy.n >= 0)

  local h = e:handle()
  if self._easy[h] then
    return nil, curl.error(curl.ERROR_MULTI, curl.E_MULTI_ADDED_ALREADY or curl.E_MULTI_BAD_EASY_HANDLE)
  end

  local ok, err = add_handle(self, h)
  if not ok then return nil, err end
  self._easy[h], self._easy.n = e, self._easy.n + 1
  self._easy_mark = nil

  return self
end

function Multi:remove_handle(e)
  local h = e:handle()

  if self._easy[h] then
    self._easy[h], self._easy.n = nil, self._easy.n - 1
  end
  assert(self._easy.n >= 0)

  return remove_handle(self, h)
end

function Multi:info_read(...)
  while true do
    local h, ok, err = self:handle():info_read(...)
    if not h then return nil, ok end
    if h == 0 then return h end

    local e = self._easy[h]
    if e then
      if ... then
        self._easy[h], self._easy.n = nil, self._easy.n - 1
      end
      return e, ok, err
    end
  end
end

local function wrap_callback(...)
  local n = select("#", ...)
  local fn, ctx, has_ctx
  if n >= 2 then
    has_ctx, fn, ctx = true, assert(...)
  else
    fn = assert(...)
    if type(fn) ~= "function" then
      has_ctx, fn, ctx = true, assert(fn.socket), fn
    end
  end
  if has_ctx then
    return function(...) return fn(ctx, ...) end
  end
  return function(...) return fn(...) end
end

local function wrap_socketfunction(self, cb)
  local ptr = setmetatable({value = self},{__mode = 'v'})
  return function(h, ...)
    local e = ptr.value._easy[h]
    if e then return cb(e, ...) end
    return 0
  end
end

local setopt_socketfunction = wrap_function("setopt_socketfunction")
function Multi:setopt_socketfunction(...)
  local cb = wrap_callback(...)

  return setopt_socketfunction(self, wrap_socketfunction(self, cb))
end

local setopt = wrap_function("setopt")
function Multi:setopt(k, v)
  if type(k) == 'table' then
    local t = k

    local socketfunction = t.socketfunction or t[curl.OPT_SOCKETFUNCTION]
    if socketfunction then
      t = clone(t)
      local fn = wrap_socketfunction(self, socketfunction)
      if t.socketfunction           then t.socketfunction           = fn end
      if t[curl.OPT_SOCKETFUNCTION] then t[curl.OPT_SOCKETFUNCTION] = fn end
    end

    return setopt(self, t)
  end

  if k == curl.OPT_SOCKETFUNCTION then
    return self:setopt_socketfunction(v)
  end

  return setopt(self, k, v)
end

function Multi:__tostring()
  local id = hash_id(tostring(self._handle))
  return string.format("%s %s (%s)", module_info._NAME, 'Multi', id)
end

end
-------------------------------------------

setmetatable(cURL, {__index = curl})

function cURL.form(...)  return Form:new(...)  end

function cURL.easy(...)  return Easy:new(...)  end

function cURL.multi(...) return Multi:new(...) end

end

return function(curl)
  local cURL = clone(module_info)

  Load_cURLv3(cURL, curl)

  Load_cURLv2(cURL, curl)

  return cURL
end
 end)
package.preload['native-type-helper'] = (function (...)
--[[ ----------------------------------------

    [Deps] Native types helper.

--]] ----------------------------------------

--- string

---分割字符串 - 匹配法
---@param reps string
---@return table
function string:split(reps)
	local result = {}
---@diagnostic disable-next-line: discard-returns
	self:gsub('[^'..reps..']+',function (n)
		table.insert(result,n)
	end)
	return result
end

---判断字符串是否仅含有数字和字母
function string:isVaild()
    local rule = ''
    for _=1,self:len() do
        rule = rule .. '[%w]'
    end
    return self:match(rule)
end

--- table

local function typeEx(value)
	local T = type(value)
	if T ~= 'table' then
		return T
	else
		if table.isArray(value) then
			return 'array'
		else
			return 'table'
		end
	end
end

---判断表是否可以认定为数组
---@param tab table
---@return boolean
function table.isArray(tab)
	local count = 1
	for k,v in pairs(tab) do
		if type(k) ~= 'number' or k~=count then
			return false
		end
		count = count + 1
	end
	return true
end

---遍历表获取所有路径
---@param tab table
---@param ExpandArray boolean 是否展开数组
---@param UnNeedThisPrefix? boolean 是否需要包含 `this.` 前缀
---@return table
function table.getAllPaths(tab,ExpandArray,UnNeedThisPrefix)
	local result = {}
	local inner_tmp
	for k,v in pairs(tab) do
		local Tk = typeEx(k)
		local Tv = typeEx(v)
		if Tv == 'table' or (ExpandArray and Tv == 'array') then
			inner_tmp = table.getAllPaths(v,ExpandArray,true)
			for a,b in pairs(inner_tmp) do
				result[#result+1] = k..'.'..b
			end
		else
			result[#result+1] = k
		end
		if Tk == 'number' then
			result[#result] = '(*)'..result[#result]
		end
	end
	if not UnNeedThisPrefix then
		for i,v in pairs(result) do
			result[i] = 'this.'..result[i]
		end
	end

	return result
end

---根据path获取表中元素  
---何为path?  
---**A** e.g. `{a=2,b=7,n=42,ok={pap=626}}`  
---    <path> *this.b*			=>		7  
---    <path> *this.ok.pap*		=>		626  
---**B** e.g. `{2,3,1,ff={8}}`  
---    <path> *this.(\*)3*         =>		1  
---    <path> *this.ff.(\*)1*		=>		8  
---@param tab any
---@param path any
---@return any
function table.getKey(tab,path)

	if path:sub(1,5) == 'this.' then
		path = path:sub(6)
	end

	local pathes = path:split('.')
	if #pathes == 0 then
		return tab
	end
	if pathes[1]:sub(1,3) == '(*)' then
		pathes[1] = tonumber(pathes[1]:sub(4))
	end
	local lta = tab[pathes[1]]

	if type(lta) ~= 'table' then
		return lta
	end

	return table.getKey(lta,table.concat(pathes,'.',2,#pathes))

end

---根据path设置表中元素  
---何为path? 请看getKey注释
---@param tab table
---@param path string
---@param value any
function table.setKey(tab,path,value)

	if path:sub(1,5) == 'this.' then
		path = path:sub(6)
	end

	local pathes = path:split('.')
	if pathes[1]:sub(1,3) == '(*)' then
		pathes[1] = tonumber(pathes[1]:sub(4))
	end
	if tab[pathes[1]] == nil then
		return
	end

	local T = typeEx(tab[pathes[1]])
	if T ~= 'table' and (T~='array' or (T=='array' and typeEx(value)=='array')) then
		tab[pathes[1]] = value
		return
	end
	table.setKey(tab[pathes[1]],table.concat(pathes,'.',2,#pathes),value)

end

---深复制表
---@param orig table
---@return table
function table.clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.clone(orig_key)] = table.clone(orig_value)
        end
        setmetatable(copy, table.clone(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

---将表信息转为字符串
---@param tab table
---@return string
function table.toDebugString(tab)
	local rtn = 'Total: '..#tab
	for k,v in pairs(tab) do
		rtn = rtn..'\n'..tostring(k)..'\t'..tostring(v)
	end
	return rtn
end

array = {}

---连接array到origin尾部
---@param origin table
---@param array table
---@return table
function array.concat(origin,array)
	for n,k in pairs(array) do
		origin[#origin+1] = k
	end
	return origin
end

---在数组中查找某元素, 并返回位置  
---@param origin table
---@param element any
---@return integer|nil
function array.fetch(origin,element)
    for p,e in pairs(origin) do
        if element == e then
            return p
        end
    end
	return nil
end

---创建一个全部为 `defaultValue` 的数组
---@param length integer
---@param defaultValue any
---@return table
function array.create(length,defaultValue)
	local rtn = {}
	for i=1,length do
		table.insert(rtn,defaultValue)
	end
	return rtn
end

---将数组中每个元素转为数字
---@param original table
---@return table
function array.tonumber(original)
	local rtn = {}
	for a,n in pairs(original) do
		rtn[a] = tonumber(n)
	end
	return rtn
end

---从数组中删除元素
---@param origin table
---@param element any
---@return any
function array.remove(origin,element)
	return table.remove(origin,array.fetch(origin,element))
end

--- other

function toBool(any)
	local T = type(any)
	if T == 'string' then
		return any == 'true'
	elseif T == 'number' then
		return any ~= 0
	else
		return any ~= nil
	end
end end)
package.preload['sha1'] = (function (...)
--[[ ----------------------------------------

    [Deps] SHA1 Calculator.

--]] ----------------------------------------

require "native-type-helper"
Wf = require "winfile"

SHA1 = {
    exec = 'certutil'
}

---获取指定文件的SHA1
---@param path string 路径
---@return true|false
---@return string
function SHA1:file(path)
    local res = Wf.popen(('%s -hashfile "%s" SHA1'):format(self.exec,path)):read('*a')
    local stat = res:find('ERROR') == nil
    local sha1
    if stat then
        sha1 = res:split('\n')[2]
        stat = sha1 ~= nil
    end
    return stat,sha1
end

return SHA1 end)
package.preload['node-tree'] = (function (...)
--[[ ----------------------------------------

    [Deps] Node Tree

--]] ----------------------------------------

require "native-type-helper"

---@class NodeTree
NodeTree = {

    name = 'NULL',
    sub = {},

    PREFIX_ROOT_START = '─ ',
    PREFIX_SPACE = '   ',
    PREFIX_MIDDLE = '   ├─ ',
    PREFIX_PASSED = '│',
    PREFIX_END = '   └─ '

}

---创建节点树对象
---@return NodeTree
function NodeTree:create(name)
    local origin = {}
    setmetatable(origin,self)
    self.__index = self
    origin.name = name
    origin.sub = {}
    origin.note = ''
    origin.description = ''
    return origin
end

---创建新分支
---@param name string
---@return NodeTree
function NodeTree:branch(name)
    local obj = self:create(name)
    self.sub[#self.sub+1] = obj
    return obj
end

---设置Note, `toString` 生成为 name [noteStr]
---@param note any
function NodeTree:setNote(note)
    self.note = note
end

---设置Description, `toString` 生成为 name - desStr
---@param describe any
function NodeTree:setDescription(describe)
    self.description = describe
end

---获取当前分支名称
---@return string
function NodeTree:getName()
    return self.name
end

---获取Description
---@return string|nil
function NodeTree:getDescription()
    if self.description == '' then
        return nil
    end
    return self.description
end

---获取Note
---@return string|nil
function NodeTree:getNote()
    if self.note == '' then
        return nil
    end
    return self.note
end

---转为文本形式树
---@return string
function NodeTree:toString()
    local rtn = ''
    local len = #self.sub
    for n,subobj in pairs(self.sub) do
        local prefix = ''
        if n < len then
            prefix = self.PREFIX_MIDDLE
        elseif n == len then
            prefix = self.PREFIX_END
        end
        local addstr = ''
        local desc = subobj:getDescription()
        local note = subobj:getNote()
        if desc and note then
            error('INVAILD SET WHAT?!')
        elseif desc then
            addstr = ' - ' .. desc
        elseif note then
            addstr = (' [%s]'):format(note)
        end
        rtn = rtn .. prefix .. subobj:getName() .. addstr .. '\n'
        for n2,sub2 in pairs(subobj:toString():split('\n')) do
            if n2 ~= 1 then
                local passed = self.PREFIX_PASSED
                if prefix == self.PREFIX_END then
                    passed = ' '
                end
                rtn = rtn .. self.PREFIX_SPACE .. passed .. sub2 .. '\n'
            end
        end
    end
    rtn = self.PREFIX_ROOT_START .. self:getName() .. '\n' .. rtn
    return rtn
end end)
package.preload['Environment'] = (function (...)
--[[ ----------------------------------------

    [Main] Environment Settings.

--]] ----------------------------------------

ENV = {

    INSTALLER_WHITELIST = {
        --- [Spec] LPM.
        'be3bf7fe-360a-46b2-b6e3-6cf7151f641b',
        --- [Spec] LiteLoaderBDS.
        '8cb3f98e-db18-4b84-85ca-cbc607cee32f'
    }

}

return ENV end)
package.preload['Version'] = (function (...)
--[[ ----------------------------------------

    [Main] Version manager.

--]] ----------------------------------------

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

---检查`ver1`是否符合`method`  
-- **比较运算符**  
-- *大于*＞ *小于*＜ *等于*＝ *大于等于*≥ *小于等于*≤  
-- Tips: 等于号可以省略  
-- e.g. "> 1.19.0" 相当于 major >= 1 || minor == 1 and major >=19 || minor == 1 and major == 10 and revision > 0  
-- **范围运算符**  
-- *区间* 1\~22  
-- e.g "1.19.1\~22" 相当于 major == 1 && minor == 19 && 1 <= revision <= 22  
-- **特殊运算符**  
-- *全部* *  
---@param ver1 string
---@param method string
---@return boolean
function Version:match(ver1,method)
    local sym = method:sub(1,1)
    if sym == '*' then
        return true
    else
        local t = method:sub(3)
        if method:sub(1,2) == '>=' then
            return self:match(ver1,'>'..t) or self:match(ver1,'='..t)
        elseif method:sub(1,2) == '<=' then
            return self:match(ver1,'<'..t) or self:match(ver1,'='..t)
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
    Log:Error('Unknown symbol found "%s".',sym)
    return false
end

---检查`ver1`是否大于`ver2`
---@param ver1 string
---@param ver2 string
---@return boolean
function Version:isBigger(ver1,ver2)
    return self:match(ver1,'>'..ver2)
end

return Version end)
package.preload['I18N'] = (function (...)
--[[ ----------------------------------------

    [Main] LangPack Functions.

--]] ----------------------------------------
 end)
package.preload['Settings'] = (function (...)
--[[ ----------------------------------------

    [Main] Internal settings.

--]] ----------------------------------------

local Log = Logger:new('Settings')
local cfg = {
    format_version = Version:getNum(1),
    bds = {
        running_directory = ''
    },
    repo = {
        allow_insecure_protocol = false
    },
    installer = {
        allow_unsafe_directory = false
    },
    output = {
        no_color = false
    }
}

Settings = {
    dir = 'data/config.json',
    loaded = false
}

---初始化
---@return boolean
function Settings:init()
    if not Fs:isExist(self.dir) then
        Fs:writeTo(self.dir,JSON:stringify(cfg,true))
    end
    local loadcfg = JSON:parse(Fs:readFrom(self.dir))
    for n,path in pairs(table.getAllPaths(cfg,false)) do
        local m = table.getKey(loadcfg,path)
        if m ~= nil then
            table.setKey(cfg,path,m)
        else
            Log:Error('配置文件丢失 %s, 已使用默认值。',path)
        end
    end
    self.loaded = true
    return self.loaded
end

---根据path获取配置项值
---@param path string
---@return any
function Settings:get(path)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前获得配置项 %s',path)
        return nil
    end
    return table.getKey(cfg,path)
end

---根据path设置配置项值
---@param path string
---@param value any
---@return boolean
function Settings:set(path,value)
    if not self.loaded then
        Log:Error('尝试在配置项初始化前设定配置项 %s',path)
        return false
    end
    table.setKey(cfg,path,value)
    self:save()
    return true
end

---保存配置项
---@return boolean
function Settings:save()
    if not self.loaded then
        Log:Error('尝试在配置项初始化前保存')
        return false
    end
    Fs:writeTo(self.dir,JSON:stringify(cfg,true))
    return true
end

return Settings end)
package.preload['RepoManager'] = (function (...)
--[[ ----------------------------------------

    [Main] Repoistroy Manager.

--]] ----------------------------------------

local Log = Logger:new('RepoManager')

---@class RepoManager
RepoManager = {
    dir = 'data/repositories/',
    dir_cfg = 'data/repo.json',
    loaded = {},
    --- use `self:getPriorityList()` to get me!
    priority = {}
}

---初始化
---@return boolean
function RepoManager:init()
    Fs:mkdir(self.dir..'/cache')
    if not Fs:isExist(self.dir_cfg) then
        Fs:writeTo(self.dir_cfg,JSON:stringify {
            format_version = Version:getNum(2),
            priority = {},
            repos = {
                ["2ae709c3-31c2-41cc-8ced-4686faaabae9"] = {
                    enabled = true,
                    metafile = "https://raw.githubusercontent.com/Redbeanw44602/TestRepo/main/self.json",
                    using = "latest"
                }
            }
        })
    end
    self.loaded = JSON:parse(Fs:readFrom(self.dir_cfg)).repos
    return self.loaded ~= nil
end

---添加一个仓库
---@param uuid string
---@param metafile string 自述文件下载链接
---@param isEnabled? boolean
---@return Repo
function RepoManager:add(uuid,metafile,group,isEnabled)
    isEnabled = isEnabled or true
    local repo = self:get(uuid)
    if repo then
        Log:Error('该仓库与现有的某个仓库的UUID冲突，可能重复添加了？')
        return repo
    end
    self.loaded[uuid] = {
        using = group,
        metafile = metafile,
        enabled = isEnabled
    }
    repo = self:get(uuid)
    assert(repo)
    self:save()
    if isEnabled then
        repo:update(true)
    end
    return repo
end

---删除仓库
---@param uuid string
---@return boolean
function RepoManager:remove(uuid)
    local repo = self:get(uuid)
    if not repo then
        Log:Error('正在删除不存在的仓库 %s。',uuid)
        return false
    end
    if #self:getAllEnabled() <= 1 then
        Log:Error('若要删除 %s, 必须先启用另一个仓库。',repo:getName())
        return false
    end
    repo:purge()
    Log:Info('正在清除软件包目录...')
    Fs:rmdir(self.dir..uuid)
    self.loaded[uuid] = nil
    self:save()
    return true
end

---获取仓库对象
---@param uuid string UUID
---@return Repo|nil
function RepoManager:get(uuid)
    local origin = {}
    local data = self.loaded[uuid]
    if not data then
        return nil
    end
    setmetatable(origin,Repo)
    Repo.__index = Repo
    origin.uuid = uuid
    origin.enabled = data.enabled
    origin.metafile = data.metafile
    origin.using = data.using
    return origin
end

---保存仓库
---@param instance? Repo 需要保存的仓库
---@return boolean
function RepoManager:save(instance)
    if instance then
        local uuid = instance:getUUID()
        local m = self.loaded[uuid]
        m.enabled = instance:isEnabled()
        m.metafile = instance:getLink()
        m.using = instance:getUsingGroup():getName()
    end
    Fs:writeTo(self.dir_cfg,JSON:stringify({
        format_version = Version:getNum(2),
        priority = self.priority,
        repos = self.loaded
    },true))
    return true
end

---刷新并获取优先级表
---@return table
function RepoManager:getPriorityList()
    local added = {}
    local all = self:getAllEnabled()
    added = array.create(#all,0)
    for _,uuid in pairs(all) do
        local ck = array.fetch(self.priority,uuid)
        if ck then
            table.insert(added,ck,uuid)
        else
            table.insert(added,uuid)
        end
    end
    self.priority = {}
    for _,uuid in pairs(added) do
        if uuid and uuid ~= 0 then
            self.priority[#self.priority+1] = uuid
        end
    end
    self:save()
    return self.priority
end

---获取所有已添加的仓库
---@return table
function RepoManager:getAll()
    local rtn = {}
    for uuid,_ in pairs(self.loaded) do
        rtn[#rtn+1] = uuid
    end
    return rtn
end

---获取当前已启用仓库UUID列表
---@return table
function RepoManager:getAllEnabled()
    local rtn = {}
    for uuid,res in pairs(self.loaded) do
        if res.enabled then
            rtn[#rtn+1] = uuid
        end
    end
    return rtn
end

---判断名称是否合法
---@param str string
---@return boolean
function RepoManager:isLegalName(str)
    return not (
        str:find('\\') or
        str:find('/') or
        str:find('*') or
        str:find('?') or
        str:find('"') or
        str:find('<') or
        str:find('>') or
        str:find('|') or
        str:find('_')
    )
end

---获取资源
---@param type string `PdbHashTable` | `SpeedTest`
---@return string|nil 下载链接
function RepoManager:getMultiResource(type)
    for _,uuid in pairs(self:getPriorityList()) do
        local link = self:get(uuid):getMultiResource(type)
        if link then
            return link
        end
    end
    return nil
end

---在全部仓库中搜索
---@param pattern string 关键词, 可以是模式匹配字符串
---@param topOnly? boolean 只在顶级仓库搜索, 默认否
---@param matchBy? string **name** or uuid
---@param version? string 版本匹配表达式
---@param tags? table 要求包含tags列表
---@param limit? number 最大结果数量, 默认无限制
---@return table 结果
function RepoManager:search(pattern,topOnly,matchBy,version,tags,limit)
    local rtn = {}
    local searchs
    if not topOnly then
        searchs =  self:getAllEnabled()
    else
        searchs = self:getPriorityList()[1]
    end
    for _,uuid in pairs(searchs) do
        local repo = self:get(uuid)
        assert(repo)
        array.concat(rtn,repo:search(pattern,matchBy,version,tags,limit))
    end
    return rtn
end

return RepoManager end)
package.preload['SoftwareManager'] = (function (...)
--[[ ----------------------------------------

    [Main] Software Manager.

--]] ----------------------------------------

local Log = Logger:new('SoftwareManager')
SoftwareManager = {
    dir = 'data/installed/',
    installed = {},

    Helper = {
        safe_dirs = {
            'plugins/',
            'behavior_packs/',
            'resource_packs/'
        }
    }
}

function SoftwareManager.Helper:isSafeDirectory(tpath)
    if tpath:find('%.%.') then -- check '..'
        return false
    end
    for _, sfpath in pairs(self.safe_dirs) do
        if tpath:sub(0, sfpath:len()) == sfpath then
            return true
        end
    end
    return false
end

function SoftwareManager.Helper:isWhitePackage(uuid)
    return array.fetch(ENV.INSTALLER_WHITELIST, uuid) ~= nil
end

function SoftwareManager.Helper:parseDependentReq(tab)
    local rtn = {}
    rtn.name = tab[1]
    rtn.uuid = tab[2]
    rtn.version = tab[3] or '*'
    return rtn
end

---初始化
---@return boolean
function SoftwareManager:init()
    Fs:mkdir(self.dir)
    Fs:iterator(self.dir, function(nowpath, file)
        local path = nowpath .. file
        if path:sub(path:len() - 7) == '.' .. Software.suffix and Fs:getType(path) == 'file' then
            local m = JSON:parse(Fs:readFrom(path))
            if not m then
                Log:Error('%s 无效软件包信息', path)
            elseif m.format_version ~= Version:getNum(6) then
                Log:Error('%s 不匹配的格式版本')
            else
                self.installed[m.uuid] = m
            end
        end
    end)
    return true
end

---从软件包路径创建包对象
---@param dir string
---@return Package|nil
function SoftwareManager:fromFile(dir)
    Log:Info('正在解析软件包...')
    local stat, unpacked_path = P7zip:extract(dir)
    if not stat then
        Log:Error('解压缩软件包时出现异常。')
        return nil
    end
    for _, n in pairs(Package.root_check_list) do
        if not Fs:isExist(unpacked_path .. n) then
            Log:Error('软件包不合法，缺少 %s。', n)
            return nil
        end
    end
    local pkgInfo = JSON:parse(Fs:readFrom(unpacked_path .. 'self.json'))
    if not pkgInfo then
        Log:Error('读取包信息时出现异常。')
        return nil
    end
    if pkgInfo.format_version ~= Version:getNum(5) then
        Log:Error('软件包自述文件版本不匹配。')
        return nil
    end
    local verification = JSON:parse(Fs:readFrom(unpacked_path .. 'verification.json'))
    if not verification then
        Log:Error('读取校验信息时出现异常。')
        return nil
    end
    local origin = {}
    setmetatable(origin,Package)
    Package.__index = Package
    origin.package_dir = dir
    origin.meta = pkgInfo
    origin.verification = verification
    origin.unpacked_path = unpacked_path
    return origin
end

---使用UUID创建已安装软件对象
---@param uuid string
---@return Software|nil
function SoftwareManager:fromInstalled(uuid)
    if not self.installed[uuid] then
        return nil
    end
    local origin = {}
    setmetatable(origin,Software)
    Software.__index = Software
    origin.uuid = uuid
    origin.meta = self.installed[uuid]
    return origin
end

---获取已安装软件列表(uuid)
function SoftwareManager:getAll()
    local rtn = {}
    for uuid, _ in pairs(self.installed) do
        rtn[#rtn + 1] = uuid
    end
    return rtn
end

---在已安装列表中通过名称检索UUID
---@param name string
---@return string|nil
function SoftwareManager:getUuidByName(name)
    for uuid, pkg in pairs(self.installed) do
        if pkg.name == name then
            return uuid
        end
    end
    return nil
end

---通过UUID获取软件包名称
---@param uuid string
---@return string|nil
function SoftwareManager:getNameByUuid(uuid)
    local pkg = self:fromInstalled(uuid)
    if pkg then
        return pkg:getName()
    end
    local se = RepoManager:search(uuid,false,'uuid',nil,nil,1)
    if se then
        return se[1].name
    end
    return nil
end

---注册安装或升级信息
---@param pkgInfo table
---@param installed table
---@return boolean
function SoftwareManager:registerChanged(pkgInfo,installed)
    local pkg = table.clone(pkgInfo)
    local uuid = pkg.uuid
    pkg.verification = nil
    pkg.paths.installed = installed
    pkg.format_version = Version:getNum(6)
    self.installed[uuid] = pkg
    return Fs:writeTo(('%s%s.%s'):format(self.dir, uuid, Software.suffix), JSON:stringify(pkg))
end

return SoftwareManager end)
package.preload['Package'] = (function (...)
--[[ ----------------------------------------

    [Main] Package Instance.

--]] ----------------------------------------

---@class Package
Package = {
    root_check_list = {
        'self.json',
        'verification.json',
        'content'
    },
    suffix = 'lpk',

    package_dir = 'NULL',
    unpacked_path = 'NULL',
    meta = {},
    verification = {}

}
local Log = Logger:new('Package')
local manager = SoftwareManager

---获取名称
---@return string
function Package:getName()
    return self.meta.name
end

---获取UUID
---@return string
function Package:getUUID()
    return self.meta.uuid
end

---获取版本
---@return string
function Package:getVersion()
    return self.meta.version
end

---获取贡献者列表
---@return table
function Package:getContributors()
    return self.meta.contributors:split(',')
end

---获取依赖信息列表
---@param ntree? NodeTree
---@param list? table
---@return table
function Package:getDependents(ntree,list)
    local rtn = {
        node_tree = ntree or NodeTree:create(self:getName()),
        list = list or {}
    }
    local depends = self.meta.depends
    for _,info in pairs(depends) do
        local depend = manager.Helper:handleDependents(info)
        local sw = manager:fromInstalled(depend.uuid)
        if sw then
            rtn.node_tree:branch(sw:getName()):setNote('已安装')
        else
            local res = manager:search(info.uuid,false,true)
            if #res.data == 0 then
                rtn.node_tree:branch(info.uuid):setNote('未找到')
            else
                rtn.list[#rtn.list+1] = res.data[1]
                rtn.node_tree:branch(res.data[1].name)
            end
        end
    end
    return rtn
end

---获取冲突表
---@return table
function Package:getConflict()
    return self.meta.conflict
end

---获取主页地址
---@return string
function Package:getHomepage()
    return self.meta.homepage
end

---获取标签
function Package:getTags()
    return self.meta.tags
end

function Package:getVerification()
    return self.verification
end

---检查是否适配当前游戏版本
---@return boolean
function Package:checkRequiredGameVersion()
    if not Version:match(BDS:getVersion(),self.meta.applicable_game_version) then
        Log:Error('软件包与当前服务端版本不适配，安全检查失败。')
        return false
    end
    return true
end

---获取描述信息
---@return string
function Package:buildDescription()
    return ('软件包: %s\n版本: %s\n贡献者: %s\n主页: %s\n标签: %s\n介绍: %s').format(
        self:getName(),
        self:getVersion(),
        table.concat(self:getContributors(),','),
        self:getHomepage(),
        table.concat(self:getTags(),','),
        table.concat(self.meta.description,'\n')
    )
end

---检验此软件包的完整性与合法性
---@param updateMode boolean? 升级模式，跳过部分检查
---@return boolean
function Package:verify(updateMode)
    Log:Info('正在校验包...')
    if not updateMode and manager:fromInstalled(self:getUUID()) then
        Log:Error('软件包已安装过，安全检查失败。')
    end
    if not updateMode and manager:getUuidByName(self:getName()) then
        Log:Error('软件包与已安装软件有重名，安全检查失败。')
        return false
    end
    if not self:checkRequiredGameVersion() then
        return false
    end
    local meta = self.meta
    local verification = self:getVerification()
    local unpacked = self.unpacked_path
    local stopAndFailed = false
    local allow_unsafe = Settings:get('installer.allow_unsafe_directory') or manager.Helper:isWhitePackage(self:getUUID())
    Fs:iterator(unpacked .. 'content/', function(nowpath, file)
        if stopAndFailed then
            return
        end
        local ori_path = nowpath .. file
        local vpath = ori_path:sub((unpacked .. 'content/'):len() + 2)
        if not allow_unsafe and not manager.Helper:isSafeDirectory(vpath) then
            Log:Error('软件包尝试将文件安装到到不安全目录，安全检查失败。')
            stopAndFailed = true
            return
        end
        for _, dpath in pairs(meta.paths.data) do
            if not allow_unsafe and not manager.Helper:isSafeDirectory(dpath) then
                Log:Error('软件包数据文件可能存放在不安全的目录，安全检查失败。')
                stopAndFailed = true
                return
            end
        end
        local sha1 = verification[vpath]
        local statu, pkg_file_sha1 = SHA1:file(ori_path)
        print(statu,pkg_file_sha1,sha1,ori_path,vpath)
        if not (sha1 and statu) or pkg_file_sha1 ~= sha1 then
            Log:Error('软件包校验失败。')
            stopAndFailed = true
            return
        end
    end)
    return not stopAndFailed
end

---安装此软件包
---@return boolean
function Package:install()
    local uuid = self:getUUID()
    if manager:fromInstalled(uuid) then
        Log:Error('软件包 %s 已安装，不可以重复安装。', uuid)
        return false
    end
    if not self:verify() then
        return false
    end
    Log:Error('正在处理依赖关系...')
    if not self:handleDependents() then
        return false
    end
    local name = self:getName()
    Log:Info('%s (%s) - %s', name, self:getVersion(), self:getContributors())
    io.write(('是否安装 %s (y/N)? '):format(name))
    local chosed = io.read():lower()
    if chosed ~= 'y' then
        return false
    end
    local unpacked_path = self.unpacked_path
    local all_count = Fs:getFileCount(unpacked_path .. 'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    local bds_dir = BDS:getRunningDirectory()
    if uuid == 'be3bf7fe-360a-46b2-b6e3-6cf7151f641b' then --- lpM
        bds_dir = './'
    end
    Fs:iterator(unpacked_path .. 'content/', function(nowpath, file)
        local ori_path_file = nowpath .. file
        local inst_path_file = bds_dir .. ori_path_file:sub((unpacked_path .. 'content/'):len() + 1)
        local inst_path = Fs:splitDir(inst_path_file).path
        local relative_inst_path_file = inst_path_file:gsub(bds_dir, '')
        if not mkdired[inst_path] and (not Fs:isExist(inst_path) or Fs:getType(inst_path) ~= 'directory') then
            Fs:mkdir(inst_path)
            mkdired[inst_path] = 1
        end
        count = count + 1
        if not overwrite_noask and Fs:isExist(inst_path_file) then
            if jumpout_noask then
                return
            end
            Log:Warn('文件 %s 在BDS目录下已存在，请选择...', relative_inst_path_file)
            while true do
                Log:Warn('[o]覆盖 [q]跳过 [O]全部覆盖 [Q]全部跳过')
                Log:Write('(O/o/Q/q) > ')
                chosed = io.read()
                if chosed == 'O' then
                    overwrite_noask = true
                    break
                elseif chosed == 'Q' then
                    jumpout_noask = true
                    return
                elseif chosed == 'o' then
                    break
                elseif chosed == 'q' then
                    return
                else
                    Log:Error('输入有误，请重新输入！')
                end
            end
        end
        Fs:copy(inst_path_file, ori_path_file)
        Log:Info('(%s/%s) 复制 -> %s', count, all_count, relative_inst_path_file)
        installed[#installed + 1] = relative_inst_path_file
    end)
    if manager:registerChanged(self.meta,installed) then
        Log:Info('%s 已成功安装。', name)
    else
        Log:Error('安装未成功。')
    end
    return true
end

---以此软件包为源，升级软件
---@return boolean
function Package:update()
    local uuid = self:getUUID()
    local name = self:getName()
    local old_IDPkg = manager:fromInstalled(uuid)
    if not old_IDPkg then
        Log:Info('%s 还未安装，因此无法升级。', name)
        return false
    end
    if Version:isBigger(old_IDPkg:getVersion(),self:getVersion()) then
        Log:Info('不可以向旧版本升级')
        return false
    end
    if not self:verify(true) then
        return false
    end
    Log:Error('正在处理依赖关系...')
    if not self:handleDependents() then
        return false
    end
    local version = self:getVersion()
    Log:Info('%s (%s->%s) - %s', name, old_IDPkg:getVersion(), version, self:getContributors())
    io.write(('是否升级 %s (y/N)? '):format(name))
    local chosed = io.read():lower()
    if chosed ~= 'y' then
        return false
    end
    local unpacked_path = self.unpacked_path
    local all_count = Fs:getFileCount(unpacked_path .. 'content/')
    local count = 0
    local installed = {}
    local mkdired = {}
    local overwrite_noask = false
    local jumpout_noask = false
    local bds_dir = BDS:getRunningDirectory()
    local installed_paths = old_IDPkg:getInstalledPaths()
    Fs:iterator(unpacked_path .. 'content/', function(nowpath, file)
        local ori_path_file = nowpath .. file
        local inst_path_file = bds_dir .. ori_path_file:sub((unpacked_path .. 'content/'):len() + 1)
        local inst_path = Fs:splitDir(inst_path_file).path
        local relative_inst_path_file = inst_path_file:gsub(bds_dir, '')
        if not mkdired[inst_path] and (not Fs:isExist(inst_path) or Fs:getType(inst_path) ~= 'directory') then
            Fs:mkdir(inst_path)
            mkdired[inst_path] = 1
        end
        count = count + 1
        if not overwrite_noask and Fs:isExist(inst_path_file) and
            not array.fetch(installed_paths, relative_inst_path_file) then
            if jumpout_noask then
                return
            end
            Log:Warn('文件 %s 在BDS目录下已存在，请选择...', relative_inst_path_file)
            while true do
                Log:Warn('[o]覆盖 [q]跳过 [O]全部覆盖 [Q]全部跳过')
                Log:Write('(O/o/Q/q) > ')
                chosed = io.read()
                if chosed == 'O' then
                    overwrite_noask = true
                    break
                elseif chosed == 'Q' then
                    jumpout_noask = true
                    return
                elseif chosed == 'o' then
                    break
                elseif chosed == 'q' then
                    return
                else
                    Log:Error('输入有误，请重新输入！')
                end
            end
        end
        Fs:copy(inst_path_file, ori_path_file)
        Log:Info('(%s/%s) 复制 -> %s', count, all_count, relative_inst_path_file)
        installed[#installed + 1] = relative_inst_path_file
    end)
    for _, ipath in pairs(installed_paths) do
        if not installed[ipath] then
            Log:Warn('请注意，在版本 %s 中，"%s" 被弃用。', version, ipath)
        end
    end
    if manager:registerChanged(self.meta,installed) then
        Log:Info('%s 已成功升级。', name)
    else
        Log:Error('升级失败。')
    end
    return true
end

---处理依赖
---@param scheme? table
---@return table 依赖处理方案
function Package:handleDependents(scheme)
    local pkgName = self:getName()
    local rtn = scheme or {
        ntree = NodeTree:create(pkgName),
        install = {},
        errors = {}
    }
    local ntree = rtn.ntree
    for _, against in pairs(self:getConflict()) do
        local instd = manager:fromInstalled(against.uuid)
        if instd and Version:match(instd:getVersion(), against.version) then
            rtn.status = false
            rtn.errors[#rtn.errors+1] = {
                type = 'conflict',
                uuid = against.uuid,
                version = against.version,
                name = against.name
            }
            ntree:branch(against.name):setNote(('与%s不兼容'):format(instd:getName()))
        end
    end
    local depends = self:getDependents()
    for _, rely in pairs(depends) do --- short information for depends(rely)
        local depend = manager.Helper:handleDependents(rely)
        local insted = manager:fromInstalled(depend.uuid)
        local name = depend.name
        if insted and Version:match(insted:getVersion(),depend.version) then
            ntree:branch(name):setNote('已安装')
        else
            local try = RepoManager:search(depend.uuid,false,'uuid',depend.version,nil,1)
            if #try == 0 then
                ntree:branch(name):setNote('版本不兼容')
                rtn.errors[#rtn.errors+1] = {
                    type = 'notfound',
                    uuid = depend.uuid,
                    version = depend.version,
                    name = name
                }
            elseif insted and Version:isBigger(insted:getVersion(),try:getVersion()) then
                ntree:branch(name):setNote('不能降级')
                rtn.errors[#rtn.errors+1] = {
                    type = 'cantdegrade',
                    uuid = depend.uuid,
                    version = depend.version,
                    name = name
                }
            else --- should update installed denpendent [this].
                rtn.install[#rtn.install+1] = try[1]
            end
        end
    end
    return rtn
end end)
package.preload['Software'] = (function (...)
--[[ ----------------------------------------

    [Main] Software Instance.

--]] ----------------------------------------

---@class Software
Software = {
    suffix = 'package',

    uuid = 'NULL',
    meta = {}

}
local Log = Logger:new('Software')
local manager = SoftwareManager

---获取软件包UUID
---@return string
function Software:getUUID()
    return self.uuid
end

---获取软件包名称
---@return string
function Software:getName()
    return self.meta.name
end

---获取软件包版本
---@return string
function Software:getVersion()
    return self.meta.version
end

---获取贡献者列表
---@return table
function Software:getContributors()
    return self.meta.contributors:split(',')
end

---获取标签列表
---@return table
function Software:getTags()
    return self.meta.tags
end

---获取依赖信息
---@param ntree NodeTree
---@param list table
---@return table
function Software:getDependents(ntree,list)
    local rtn = {
        node_tree = ntree or NodeTree:create(self:getName()),
        list = list or {}
    }
    local depends = self.meta.depends
    for _,info in pairs(depends) do
        local depend = manager.Helper:handleDependents(info)
        local sw = manager:fromInstalled(depend.uuid)
        if sw then
            rtn.node_tree:branch(sw:getName()):setNote('已安装')
        else
            local res = manager:search(depend.uuid,false,true)
            if #res.data == 0 then
                rtn.node_tree:branch(depend.uuid):setNote('未找到')
            else
                rtn.list[#rtn.list+1] = res.data[1]
                rtn.node_tree:branch(res.data[1].name)
            end
        end
    end
    return rtn
end

---获取冲突表
---@return table
function Software:getConflict()
    return self.meta.conflict
end

---获取数据路径
---@return table
function Software:getDataPaths()
    return self.meta.paths.data or {}
end

---获取已安装文件路径
---@return table
function Software:getInstalledPaths()
    return self.meta.paths.installed or {}
end

---获取主页地址
---@return string
function Software:getHomepage()
    return self.meta.homepage
end

---获取简介
---@return string
function Software:buildDescription()
    return ('软件包: %s\n版本: %s\n贡献者: %s\n主页: %s\n标签: %s\n介绍: %s').format(
        self:getName(),
        self:getVersion(),
        table.concat(self:getContributors(),','),
        self:getHomepage(),
        table.concat(self:getTags(),','),
        table.concat(self.meta.description,'\n')
    )
end

---删除软件包
---@param purge? boolean 是否删除数据文件
---@return boolean 是否成功删除
---@return boolean 删除过程中是否遇到错误
function Software:remove(purge)
    if purge then
        self:purge()
    end
    local hasFail = false
    local name = self:getName()
    local uuid = self:getUUID()
    Log:Info('正在删除软件包 %s ...', name)
    local bds_dir = BDS:getRunningDirectory()
    local installed_paths = self:getInstalledPaths()
    for n, path in pairs(installed_paths) do
        Log:Info('(%s/%s) 删除 -> %s', n, #installed_paths, path)
        if Fs:isExist(bds_dir .. path) and not Fs:remove(bds_dir .. path) then
            Log:Warn('%s 删除失败！', path)
            hasFail = true
        end
    end
    for n, fpath in pairs(installed_paths) do
        local xpath = Fs:splitDir(fpath).path
        local rpath = bds_dir .. xpath
        if Fs:isExist(rpath) then
            if Fs:getFileCount(rpath) ~= 0 then
                if not manager.Helper:isSafeDirectory(xpath) and not manager.Helper:isWhitePackage(uuid) then
                    Log:Warn('%s 不是空目录，跳过清除...', xpath)
                    hasFail = true
                end
            else
                Fs:rmdir(bds_dir .. xpath)
            end
        end
    end
    local info
    if not hasFail then
        info = ('软件包 %s 已被成功删除。'):format(name)
    else
        info = ('软件包 %s 已被成功删除，但还有一些文件/文件夹需要手动处理。'):format(name)
    end
    Fs:remove(('%s%s.%s'):format(manager.dir, uuid, Software.suffix))
    manager.installed[uuid] = nil
    Log:Info(info)
    return true, not hasFail
end

---删除指定软件的数据文件
---@return boolean 是否成功删除
function Software:purge()
    Log:Info('正在清除数据 %s ...', self:getName())
    local bds_dir = BDS:getRunningDirectory()
    local data_paths = self:getDataPaths()
    for n, xpath in pairs(data_paths) do
        Log:Info('(%s/%s) 删除 -> %s', n, #data_paths, xpath)
        Fs:rmdir(bds_dir .. xpath .. '/')
    end
    return true
end end)
package.preload['Repo'] = (function (...)
--[[ ----------------------------------------

    [Main] Repo Instance.

--]] ----------------------------------------

local manager = RepoManager
local Log = Logger:new('Repo')

---@class Repo
Repo = {}

---获取仓库的UUID
---@return string
function Repo:getUUID()
    return self.uuid
end

---仓库是否已启用?
---@return boolean
function Repo:isEnabled()
    return self.enabled
end

---获取仓库自述文件下载链接
---@return string
function Repo:getLink()
    return self.metafile
end

---获取指定仓库自述文件
---@param netMode? boolean
---@return table|nil
function Repo:getMeta(netMode)
    netMode = netMode or false
    local uuid = self:getUUID()
    local res = ''
    if not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid)) then
        netMode = true
    end
    if netMode then
        Cloud:NewTask {
            url = self:getLink(),
            writefunction = function (str)
                res = res .. str
            end
        }
    else
        res = Fs:readFrom(('%s%s.repo'):format(manager.dir,uuid))
    end
    local obj = JSON:parse(res)
    if not obj then
        Log:Error('描述文件解析失败。')
        return nil
    end
    if obj.format_version ~= Version:getNum(2) then
        Log:Error('描述文件的版本与管理器不匹配！')
        return nil
    end
    return obj
end

---获取正在使用的资源组对象
---@return ResourceGroup|nil
function Repo:getUsingGroup()
    return ResourceGroup:fromList(self:getMeta().root.groups,self.using)
end

---获取指定仓库的名称
---@return string
function Repo:getName()
    return self:getMeta().name
end

---获取指定仓库优先级
---@return integer
function Repo:getPriority()
    local id = self:getUUID()
    for sort,uuid in pairs(manager:getPriorityList()) do
        if uuid == id then
            return sort
        end
    end
    return #manager:getAllEnabled()
end

---设置指定仓库状态
---@param enable boolean 开启或关闭
---@return boolean
function Repo:setStatus(enable)
    if #manager:getAllEnabled() == 1 and not enable then
        Log:Error('无法更新 %s 状态，必须先启用另一个仓库。',self:getName())
        return false
    end
    self.enabled = enable
    manager:save(self)
    Log:Info('仓库 %s 的启用状态已更新为 %s。',self:getName(),enable)
    return true
end

---设定仓库优先级
---@param isDown? boolean
---@return boolean
function Repo:movePriority(isDown)
    local uuid = self:getUUID()
    array.remove(manager.priority,uuid)
    if not isDown then
        table.insert(manager.priority,1,uuid)
    else
        table.insert(manager.priority,uuid)
    end
    return true
end

---设置资源组
---@param name string
function Repo:setUsingGroup(name)
    self.using = name
    return manager:save(self)
end

---获取仓库最近更新的时间戳
---@return integer
function Repo:getLastUpdated()
    return self:getUsingGroup():getLastUpdated()
end

---更新指定仓库软件包列表
---@param firstUpdate? boolean 是否为首次更新
---@return boolean
function Repo:update(firstUpdate)
    local uuid = self:getUUID()
    if not firstUpdate then
        firstUpdate = not Fs:isExist(('%s%s.repo'):format(manager.dir,uuid))
    end
    local meta_new = self:getMeta(true)
    if not meta_new then
        return false
    end
    local name = self:getName()
    Log:Info('正在更新仓库 %s ...',name)
    Log:Info('正在拉取描述文件...')
    local group = self:getUsingGroup()
    if not group then
        Log:Error('获取正在使用的资源组时出现错误！')
        return false
    end
    local net_group = ResourceGroup:fromList(meta_new.root.groups,group:getName())
    if not net_group then
        Log:Error('远端没有本地正在使用的资源组，建议重新添加该仓库。')
        return false
    end
    if meta_new.status == 1 then
        Log:Warn('无法更新 %s (%s)，因为该仓库正在维护。',name,uuid)
        return false
    elseif not firstUpdate and self:getLastUpdated() >= net_group:getLastUpdated() then
        Log:Info('仓库 %s 已是最新了，无需再更新。',name)
        return true
    end
    Log:Info('正在开始下载...')
    local hasErr = false
    for n,class in pairs(group.classes) do
        if manager:isLegalName(class.name) and manager:isLegalName(group.name) then
            local path = ('%s/cache/%s_%s_%s.json'):format(manager.dir,uuid,group.name,class.name)
            Log:Info('(%d/%d) 正在下载分类 %s 的软件包列表...',n,#group.classes,class.name)
            local file = Fs:open(path,"wb")
            local url = class.list
            if not Cloud:parseLink(class.list) then
                url = ('%sgroups/%s/%s'):format(Fs:splitDir(self:getLink()).path,group.name,class.list)
            end
            local res = Cloud:NewTask {
                url = url,
                writefunction = file
            }
            file:close()
            if not res then
                Log:Error('(%d/%d) 分类 %s 的软件包列表下载失败！',n,#group.classes,class.name)
                hasErr = true
                break
            end
        else
            Log:Warn('(%d/%d) 分组 %s 的分类 %s 存在不合法字符，跳过...',n,#group.classes,group.name,class.name)
        end
    end
    if not hasErr then
        Fs:writeTo(('%s%s.repo'):format(manager.dir,uuid),JSON:stringify(meta_new,true))
    end
    return true
end

---获取可用资源组
---@param netMode? boolean
---@return string[]|nil
function Repo:getAvailableGroups(netMode)
    local ver = BDS:getVersion()
    local can_use = {}
    for _,gp in pairs(self:getMeta(netMode).root.groups) do
      if Version:match(ver,gp.required_game_version) then
        can_use[#can_use+1] = gp.name
      end
    end
    return can_use
end

---获取仓库提供的MiltiFile的下载链接
---@param name string `PdbHashTable` | `SpeedTest`
---@return string|nil
function Repo:getMultiResource(name)
    local item = self:getMeta().multi[name]
    if not item.enable then
        return nil
    end
    local url = item.file
    if not Cloud:parseLink(item.file) then
        url = ('%s%s%s'):format(Fs:splitDir(self:getLink()).path,'multi/',item.file)
    end
    return url
end

---清除仓库缓存
---@return boolean
function Repo:purge()
    local prefix = self:getUUID() .. '_'
    return Fs:iterator(manager.dir..'/cache/',function (path,name)
        if name:sub(1,prefix:len()) == prefix then
            Fs:remove(path..name)
        end
    end)
end

---加载/重载缓存的软件包列表
---@return boolean
function Repo:loadPkgs()
    self.pkgs = {}
    local prefix = self:getUUID() .. '_'
    return Fs:iterator(manager.dir..'/cache/',function (path,name)
        if name:sub(1,prefix:len()) ~= prefix then
            return
        end
        local data = JSON:parse(Fs:readFrom(path..name))
        if not (data and data.data) then
            Log:Error('加载 %s 时出错!',name)
            return
        end
        local cls = name:sub(name:len()-name:reverse():find('_')+2,name:len()-5)
        for k,_ in pairs(data.data) do
            data.data[k].class = cls
            data.data[k].repo = self:getUUID()
        end
        array.concat(self.pkgs,data.data)
    end)
end

---在仓库中执行搜索
---@param pattern string 关键词, 可以是模式匹配字符串
---@param matchBy? string **name** or uuid
---@param version? string 版本匹配表达式
---@param tags? table 要求包含tags列表
---@param limit? number 最大结果数量, 默认无限制
---@return table 结果
function Repo:search(pattern,matchBy,version,tags,limit)
    local rtn = {}
    matchBy = matchBy or 'name'
    version = version or '*'
    tags = tags or {}
    limit = limit or -1
    pattern = pattern:lower()
    self:loadPkgs()
    local function matchTags(taggs)
        if #tags == 0 then
            return true
        end
        for _,tag in pairs(tags) do
            if array.fetch(taggs,tag) then
                return true
            end
        end
        return false
    end
    for _,info in pairs(self.pkgs) do
        if matchBy == 'name' then
            if info.name:lower():find(pattern)
                and Version:match(info.version,version)
                and matchTags(info.tags)
            then
                rtn[#rtn+1] = info
            end
        elseif matchBy == 'uuid' then
            if info.uuid == pattern
                and Version:match(info.version,version)
                and matchTags(info.tags)
            then
                rtn[#rtn+1] = info
            end
        else
            Log:Error('未知的匹配方式 %s !',matchBy)
            break
        end
        if limit > 0 and #rtn >= limit then
            break
        end
    end
    return rtn
end

---@class ResourceGroup
ResourceGroup = {
    name = 'NULL',
    required_game_version = 'NULL',
    classes = {}
}

---从多个group列表中创建资源组对象
---@param list table
---@param name string
---@return ResourceGroup|nil
function ResourceGroup:fromList(list,name)
    for _,group in pairs(list) do
        if group.name == name then
            return self:create(group)
        end
    end
    return nil
end

---从表中创建资源组对象
---@param tab table
---@return ResourceGroup|nil
function ResourceGroup:create(tab)
    if not Version:match(BDS:getVersion(),tab.required_game_version) then
        return nil
    end
    local origin = {}
    setmetatable(origin,self)
    self.__index = self
    origin.name = tab.name
    origin.classes = tab.classes
    return origin
end

---获取资源组名称
---@return string
function ResourceGroup:getName()
    return self.name
end

---通过名称获取资源类信息
---@param name string
---@return table|nil
function ResourceGroup:getClass(name)
    for _,class in pairs(self.classes) do
        if class.name == name then
            return class
        end
    end
    return nil
end

---获取上一次更新时间
---@return integer
function ResourceGroup:getLastUpdated()
    local rtn = 0
    for _,ins in pairs(self.classes) do
        if ins.updated > rtn then
            rtn = ins.updated
        end
    end
    return rtn
end

return Repo,ResourceGroup end)
package.preload['BDS'] = (function (...)
--[[ ----------------------------------------

    [Deps] Bedrock Server.

--]] ----------------------------------------

local Log = Logger:new('BDS')
BDS = {
    dir = '',
    dir_pdb_hash = 'data/pdb.json',
    version = 'NULL'
}

local function check_bds(path)
    return (Fs:isExist(path..'/bedrock_server.exe') or Fs:isExist(path..'/bedrock_server_mod.exe'))
            and Fs:isExist(path..'/bedrock_server.pdb')
end

local function search_bds(path)
    local rtn = {}
    local checked_dir = {}
    Fs:iterator(path,function (nowpath,file)
        if checked_dir[nowpath] then
            return
        end
        if check_bds(nowpath) then
            rtn[#rtn+1] = nowpath
        end
        checked_dir[nowpath] = 1
    end)
    return rtn
end

function BDS:init()

    --- Running Directory.
    local bdsdir = Settings:get('bds.running_directory')
    if bdsdir == '' or not check_bds(bdsdir) then
        local new_dir = ''
        Log:Warn('你的基岩版专用服务器路径尚未设定或无效，需要立即设定。')
        Log:Info('正在扫描...')
        local bds_list = search_bds('..')
        if #bds_list == 0 then
            bds_list = search_bds(os.getenv('USERPROFILE')..'/Desktop')
        end
        if #bds_list > 0 then
            local isFirstType = true
            while true do
                if not isFirstType then
                    Log:Error('输入错误，请重新输入。')
                end
                isFirstType = false
                Log:Info('找到 %s 个BDS，请选择：',#bds_list)
                Log:Print('[0] -> 手动输入')
                for n,path in pairs(bds_list) do
                    Log:Print('[%s] -> %s',n,path)
                end
                Log:Write('(0-%s) > ',#bds_list)
                local chosed = tonumber(io.read())
                if chosed then
                    if chosed > 0 and chosed <= #bds_list then
                        new_dir = bds_list[chosed]
                    end
                    break
                end
            end
        else
            Log:Info('找不到BDS，请手动输入：')
        end
        if new_dir == '' then
            local isFirstType = true
            while true do
                if not isFirstType then
                    Log:Error('无法在您提供的目录下找到BDS，请重试')
                end
                isFirstType = false
                Log:Write('> ')
                local dir = io.read()
                if check_bds(dir) then
                    new_dir = dir
                    break
                end
            end
        end
        Settings:set('bds.running_directory',new_dir)
        bdsdir = new_dir
        Log:Info('设置成功')
    end
    self.dir = bdsdir

    local function update_pdb_hash_table(check_file_updated_time)
        local link = RepoManager:getMultiResource("PdbHashTable")
        if not link then
            Log:Error('获取 Ver-PdbHash 下载链接失败。')
            return
        end
        local recv = ''
        Cloud:NewTask {
            url = link,
            quiet = true,
            writefunction = function (str)
                recv = recv .. str
            end
        }
        local j = JSON:parse(recv)
        if not j then
            Log:Error('解析 Ver-PdbHash 对照表失败，可能是网络网络原因。')
            return
        end
        if j.format_version ~= Version:getNum(4) then
            Log:Error('Ver-PdbHash 对照表版本与管理器不匹配！')
            return
        end
        if check_file_updated_time and j.updated < check_file_updated_time then
            Log:Error('仓库中下载的 Ver-PdbHash 对照表比本地的更旧。')
            return
        end
        Fs:writeTo(self.dir_pdb_hash,JSON:stringify(j))
        return true
    end

    --- Running Version.
    if not Fs:isExist(self.dir_pdb_hash) then
        Log:Info('正在下载 Ver-PdbHash 对照表...')
        if not update_pdb_hash_table() then
            return false
        end
    end
    local updated = false
    local pdb
    while true do
        pdb = JSON:parse(Fs:readFrom(self.dir_pdb_hash))
        if not pdb then
            Log:Error('解析 Ver-PdbHash 对照表失败！')
            return false
        end
        local stat,sha1 = SHA1:file(self.dir..'bedrock_server.pdb')
        if not stat then
            Log:Error('获取 bedrock_server.pdb 的SHA1失败！')
            return false
        end
        self.version = pdb.pdb[sha1]
        if not self.version then
            if updated then
                Log:Error('对照表无法对应您的BDS，可能是仓库还未更新，或您的 PDB 被修改过。')
                return false
            else
                Log:Error('找不到当前PDB对应的版本，尝试更新 Ver-PdbHash 对照表...')
                if not update_pdb_hash_table(pdb.updated) then
                    return false
                end
                updated = true
            end
        else
            break
        end
    end

    --- Is latest.
    self.isLatestVersion = true
    for _,ver in pairs(pdb.pdb) do
        if Version:isBigger(ver,self.version) then
            self.isLatestVersion = false
            break
        end
    end
    return true
end

---获取设定的BDS运行目录
---@return string
function BDS:getRunningDirectory()
    return self.dir
end

---获取BDS运行版本
---@return string
function BDS:getVersion()
    return self.version
end

---是否是最新版本BDS
---@return boolean
function BDS:isLatest()
    return self.isLatestVersion
end

return BDS end)
package.preload['tools.Publisher'] = (function (...)
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
end end)
--[[
     __         ______   __    __
    /\ \       /\  == \ /\ "-./  \
    \ \ \____  \ \  _-/ \ \ \-./\ \
     \ \_____\  \ \_\    \ \_\ \ \_\
      \/_____/   \/_/     \/_/  \/_/
    LiteLoader Package Manager,
    Author: LiteLDev.
]]

require "Init"
require "json-safe"
require "logger"
require "7zip"
require "argparse"
require "cloud"
require "cURL"
require "filesystem"
require "native-type-helper"
require "sha1"
require "temp"
require "node-tree"

require "Environment"
require "Version"
require "I18N"
require "Settings"
require "RepoManager"
require "SoftwareManager"
require "Package"
require "Software"
require "Repo"
require "BDS"

require "tools.Publisher"

----------------------------------------------------------
-- |||||||||||||||||| Initialization |||||||||||||||||| --
----------------------------------------------------------

local Parser = require "argparse"
local Log = Logger:new('LPM')

StaticCommand = {}
Command = Parser() {
    name = 'lpm',
    description = '为 LiteLoader 打造的包管理程序。',
    epilog = '获得更多信息，请访问: https://repo.litebds.com/。'
}

Fs:mkdir('data')

if not xpcall(function()
    assert(Temp:init(), 'TempHelper')
    assert(Settings:init(), 'ConfigManager')
    assert(P7zip:init(), '7zHelper')
    assert(RepoManager:init(), 'RepoManager')
    assert(SoftwareManager:init(), 'LocalPackageManager')
    assert(BDS:init(), 'BDSHelper')
end,function (msg)
    Log:Debug(msg)
    Log:Debug(debug.traceback())
    Log:Error('%s 类初始化失败，请检查。', msg)
end) then
    return
end

if Settings:get('output.no_color') then
    Logger.setNoColor()
end

if DevMode then
    Log:Warn('You\'re in developer mode.')
end

----------------------------------------------------------
-- ||||||||||||||||||||| Commands ||||||||||||||||||||| --
----------------------------------------------------------

StaticCommand.Install = Command:command 'install'
    :summary '安装一个软件包'
    :description '此命令将从源中检索软件包，并安装。'
    :action(function(dict)
        local name = dict.name
        local temp_main,pkgname
        if name:sub(name:len() - 3) ~= '.' .. Package.suffix then
            local result = RepoManager:search(dict.name, dict.use_uuid)
            if #result == 0 then
                Log:Error('找不到名为 %s 的软件包', dict.name)
                return
            end
            for n, res in pairs(result) do
                Log:Print('[%s] >> (%s/%s) %s - %s', n, RepoManager:get(res.repo):getName(), res.class, res.name, res.version)
            end
            Log:Print('您可以输入结果序号来安装软件包，或回车退出程序。')
            Log:Write('(%s-%s) > ', 1, #result)
            local chosed = result[tonumber(io.read())]
            if not chosed then
                return
            end
            pkgname = chosed.name
            Log:Info('正在下载 %s ...', pkgname)
            temp_main = Temp:getFile('lpk')
            local url = chosed.file
            if not url or not Cloud:parseLink(url) then
                url = ('%spackages/%s_%s.%s'):format(Fs:splitDir(RepoManager:get(chosed.repo):getLink()).path,chosed.name,chosed.version,Package.suffix)
            end
            if not Cloud:NewTask {
                url = url,
                writefunction = Fs:open(temp_main, 'wb')
            } then
                Log:Error('下载 %s 时发生错误。', pkgname)
                return
            end
        else
            temp_main = name
            pkgname = '本地软件包'
        end
        local sw = SoftwareManager:fromFile(temp_main)
        if sw then
            sw:install()
        end
    end)
StaticCommand.Install:argument('name', '软件包名称')
StaticCommand.Install:flag('--use-uuid', '使用UUID索引')

StaticCommand.Update = Command:command 'update'
    :summary '执行升级操作'
    :description '此命令将先从仓库拉取最新软件包列表，然后升级本地已安装软件版本。如果提供name，则单独升级指定软件包。'
    :action(function(dict)
        local name = dict.name
        if not name then
            for _, uuid in pairs(RepoManager:getAllEnabled()) do
                RepoManager:get(uuid):update()
            end
            if dict.repo_only then
                return
            end
        end
        -------- ↑ Update Repo | ↓ Update Software --------
        Log:Info('正在获取待更新软件包列表...')
        local need_update = {}
        for _,uuid in pairs(SoftwareManager:getAll()) do
            local old = SoftwareManager:fromInstalled(uuid).version
            local new = RepoManager:search(uuid,true)
            if #new.data == 0 then
                Log:Error('无法在仓库中找到 %s ！',old.name)
                return
            end
            local tfile = Temp:getFile()
            if not Cloud:NewTask {
                url = new.data[1].download,
                writefunction = Fs:open(tfile,'wb')
            } then
                Log:Error('下载 %s 时出错！',old.name)
                return
            end
            need_update[#need_update+1] = {old.name,tfile}
        end
        Log:Info('完成。')
    end)
StaticCommand.Update:argument('name', '软件包名称'):args '?'
StaticCommand.Update:flag('--use-uuid', '使用UUID索引')
StaticCommand.Update:flag('--repo-only','只更新仓库')

StaticCommand.Remove = Command:command 'remove'
    :summary '删除一个软件包'
    :description '此命令将删除指定软件包但不清除软件储存的数据。'
    :action(function(dict)
        local uuid = SoftwareManager:getUuidByName(dict.name)
        if not uuid then
            Log:Error('找不到软件包 %s，因此无法删除。', dict.name)
        else
            SoftwareManager:fromInstalled(uuid):remove(dict.purge)
        end
    end)
StaticCommand.Remove:flag('-p --purge', '同时清除数据 (危险)')
StaticCommand.Remove:argument('name', '软件包名称')

StaticCommand.Purge = Command:command 'purge'
    :summary '清除指定软件的数据'
    :description '此命令将清除指定软件储存的数据 (危险)，但不卸载该软件。'
    :action(function(dict)
        local uuid = SoftwareManager:getUuidByName(dict.name)
        if not uuid then
            Log:Error('找不到软件包 %s，因此无法清除数据。', dict.name)
        else
            SoftwareManager:fromInstalled(uuid):purge()
        end
    end)
StaticCommand.Purge:argument('name', '软件包名称')

StaticCommand.List = Command:command 'list'
    :summary '列出已安装软件包'
    :description '此命令将列出所有已经安装的软件包'
    :action(function(dict)
        local list = SoftwareManager:getAll()
        Log:Info('已安装 %s 个软件包', #list)
        for n, uuid in pairs(list) do
            local pkg = SoftwareManager:fromInstalled(uuid)
            if pkg then
                Log:Info('[%d] %s - %s (%s)', n, pkg:getName(), pkg:getVersion(), uuid)
            end
        end
    end)

StaticCommand.AddRepo = Command:command 'add-repo'
    :summary '添加新仓库'
    :description '提供仓库描述文件链接以添加一个新仓库'
    :action(function(dict)
        local metafile = ''
        Log:Info('正在下载描述文件...')
        local res = Cloud:NewTask {
            url = dict.link,
            writefunction = function(str)
                metafile = metafile .. str
            end
        }
        if not res then
            Log:Error('下载描述文件时出错。')
            return
        end
        local parsed_file = JSON:parse(metafile)
        if not parsed_file then
            Log:Error('解析描述文件时出错。')
            return
        end
        if parsed_file.format_version ~= Version:getNum(2) then
            Log:Error('描述文件版本与管理器不匹配。')
            return
        end
        local group
        local ver = BDS:getVersion()
        local can_use = {}
        local use_latest = false
        for _, gp in pairs(parsed_file.root.groups) do
            if Version:match(ver, gp.required_game_version) then
                if gp.name == 'latest' and BDS:isLatest() then
                    use_latest = true
                    break
                end
                can_use[#can_use + 1] = gp.name
            end
        end
        if use_latest then
            group = 'latest'
        elseif #can_use == 1 then
            group = parsed_file.root.groups[can_use[1]].name
        elseif #can_use == 0 then
            Log:Error('当前选择的仓库无法适配当前的BDS版本。')
            return
        else
            Log:Print('当前仓库有以下可以选择的资源组：')
            for n, name in pairs(can_use) do
                Log:Print('[%d] >> %s', n, name)
            end
            Log:Write('(%d-%d) > ', 1, #can_use)
            local chosed = can_use[tonumber(io.read())]
            if chosed then
                group = chosed
            else
                Log:Error('输入错误！')
                return
            end
        end
        if not RepoManager:add(parsed_file.identifier, dict.link, group, not (dict.no_update)) then
            Log:Error('仓库添加失败')
            return
        end
        Log:Info('成功添加仓库 %s，标识符为 %s。', parsed_file.name, parsed_file.identifier)
    end)
StaticCommand.AddRepo:argument('link', '仓库描述文件下载链接')
StaticCommand.AddRepo:flag('--no-update', '仅添加仓库（跳过自动启用与更新）')

StaticCommand.RmRepo = Command:command 'rm-repo'
    :summary '删除一个仓库'
    :description '此命令将删除现存的仓库'
    :action(function(dict)
        if not dict.uuid then
            local plzUUID = OrderHelper:pleaseUUID()
            if not plzUUID then
                return
            end
            dict.uuid = plzUUID
        end
        if RepoManager:remove(dict.uuid) then
            Log:Info('仓库（%s）已被删除', dict.uuid)
        end
    end)
StaticCommand.RmRepo:argument('uuid', '目标仓库的UUID'):args '?'

StaticCommand.ListRepo = Command:command 'list-repo'
    :summary '列出所有仓库'
    :description '此命令将列出所有已配置的仓库。'
    :action(function(dict)
        local repo_list = RepoManager:getAll()
        local enabled, disabled = RepoManager:getPriorityList(), RepoManager:getAll()
        Log:Info('已配置 %s 个仓库。', #repo_list)
        Log:Info('已启用 %s 个仓库, 它们的优先级为:', #enabled)
        for n, uuid in pairs(enabled) do
            array.remove(disabled, uuid)
            Log:Info('%s. %s - [%s]', n, RepoManager:get(uuid):getName(), uuid)
        end
        if #disabled ~= 0 then
            Log:Info('已禁用 %s 个仓库', #disabled)
            for n, uuid in pairs(disabled) do
                Log:Info('%s. %s - [%s]', n, RepoManager:get(uuid):getName(), uuid)
            end
        end
    end)

StaticCommand.SetRepo = Command:command 'set-repo'
    :summary '重设使用的仓库'
    :description '此命令将重设仓库开关状态并更新软件包列表。'
    :action(function(dict)
        if not dict.uuid or dict.uuid == '?' then
            local plzUUID = OrderHelper:pleaseUUID()
            if not plzUUID then
                return
            end
            dict.uuid = plzUUID
        end
        local repo = RepoManager:get(dict.uuid)
        if not repo then
            Log:Error('未知的仓库！')
            return
        end
        repo:setStatus(dict.status == 'enable')
    end)
StaticCommand.SetRepo:argument('uuid', '目标仓库的UUID。'):args '?'
StaticCommand.SetRepo:argument('status', '开或关')
    :choices { 'enable', 'disable' }

StaticCommand.MoveRepo = Command:command 'move-repo'
    :summary '设置仓库优先级'
    :description '此命令将重设仓库优先级。'
    :action(function(dict)
        if not dict.uuid or dict.uuid == '?' then
            local plzUUID = OrderHelper:pleaseUUID(true)
            if not plzUUID then
                return
            end
            dict.uuid = plzUUID
        end
        local repo = RepoManager:get(dict.uuid)
        if not repo or not repo:isEnabled() then
            Log:Error('目标仓库不存在或未开启。')
            return
        end
        repo:movePriority(dict.action == 'down')
        Log:Info('已更新仓库优先级。')
    end)
StaticCommand.MoveRepo:argument('uuid', '目标仓库的UUID。'):args '?'
StaticCommand.MoveRepo:argument('action', '提到最前或拉到最后')
    :choices { 'up', 'down' }

StaticCommand.ResetRepoGroup = Command:command('repo-reset-group')
    :summary '重设仓库资源组'
    :description '此命令将打印可用资源组列表，并允许重新选择资源组。'
    :action(function(dict)
        if not dict.uuid then
            local plzUUID = OrderHelper:pleaseUUID(true)
            if not plzUUID then
                return
            end
            dict.uuid = plzUUID
        end
        local repo = RepoManager:get(dict.uuid)
        if not repo then
            Log:Error('不存在的仓库！')
            return
        end
        local list = repo:getAvailableGroups(dict.update)
        if not list or #list < 1 then
            Log:Error('当前仓库没有资源分组适合您的BDS。')
            return
        end
        Log:Print('请选择要使用的资源分组...')
        for n, name in pairs(list) do
            Log:Print('[%s] >> %s', n, name)
        end
        Log:Write('(%d-%d) > ', 1, #list)
        local chosed = list[tonumber(io.read())]
        if not chosed then
            Log:Error('输入错误！')
            return
        end
        repo:setUsingGroup(chosed)
        Log:Info('设置成功。')

    end)
StaticCommand.ResetRepoGroup:argument('uuid', '目标仓库UUID。'):args '?'
StaticCommand.ResetRepoGroup:flag('--update', '更新模式')

StaticCommand.ListProtocol = Command:command 'list-protocol'
    :summary '列出下载所有组件'
    :description '此命令将列出所有已安装的下载组件。'
    :action(function(dict)
        local list = Cloud:getAllProtocol()
        Log:Info('已装载 %s 个下载组件', #list)
        for k, v in pairs(list) do
            Log:Info('%s. %s', k, v)
        end
    end)

StaticCommand.Search = Command:command 'search'
    :summary '搜索软件包'
    :description '此命令将按照要求在数据库中搜索软件包'
    :action(function(dict)
        local match_by = 'name'
        if dict.use_uuid then
            match_by = 'uuid'
        end
        if dict.tags then
            dict.tags = dict.tags:gsub('，',','):gsub(' ',''):split(',')
        end
        if dict.limit then
            dict.limit = tonumber(dict.limit[1])
        end
        local result = RepoManager:search(dict.pattern, dict.top_only,match_by,dict.version,dict.tags,dict.limit)
        if #result == 0 then
            Log:Error('找不到名为 %s 的软件包', dict.pattern)
            return
        end
        for n, res in pairs(result) do
            Log:Print('[%s] >> (%s/%s) %s - %s', n, RepoManager:get(res.repo):getName(), res.class, res.name, res.version)
        end
        Log:Print('您可以输入结果序号来查看软件包详细信息，或回车退出程序。')
        Log:Write('(%s-%s) > ', 1, #result)
        local chosed = result[tonumber(io.read())]
        if not chosed then
            return
        end
        Log:Info(('软件包: %s\n版本: %s\n贡献者: %s\n主页: %s\n标签: %s\n介绍: %s'):format(
            chosed.name,
            chosed.version,
            chosed.contributors,
            chosed.homepage,
            table.concat(chosed.tags,','),
            table.concat(chosed.description,'\n')
        ))
    end)
StaticCommand.Search:argument('pattern', '用于模式匹配的字符串/或UUID')
StaticCommand.Search:option('--version -v', '版本匹配表达式'):args '?'
StaticCommand.Search:option('--tags', '标签匹配列表，使用逗号分割'):args '?'
StaticCommand.Search:option('--limit', '限制结果数量，默认无限制'):args '?'
StaticCommand.Search:flag('--use-uuid', '使用UUID查找')
StaticCommand.Search:flag('--top-only', '只在最高优先级仓库中查找')

StaticCommand.MakePackage = Command:command 'make-package'
    :summary '[DEV] 生成校验文件并打包为LPK'
    :description '此命令将在提供的目录下生成对应的校验文件然后执行打包。'
    :action(function (dict)
        local rtn,fail_file = Publisher:generateVerification(dict.path)
        if rtn == 0 then
            Log:Info('校验计算成功。')
        elseif rtn == -1 then
            Log:Error('路径不存在或不是正确的软件包。')
        elseif rtn == -2 then
            Log:Error('为文件 %s 计算SHA1时出错。',fail_file)
        end
        local stat = Publisher:makePackage(dict.path)
        if stat then
            Log:Info('生成成功。')
        else
            Log:Error('生成失败。')
        end
    end)
StaticCommand.MakePackage:argument('path','半成品软件包路径')

----------------------------------------------------------
-- ||||||||||||||||| Command Helper ||||||||||||||||| --
----------------------------------------------------------

OrderHelper = {}

---UUID助手
---@param shouldEnabled? boolean
---@return string|nil UUID
function OrderHelper:pleaseUUID(shouldEnabled)
    local list
    if shouldEnabled then
        list = RepoManager:getAllEnabled()
    else
        list = RepoManager:getAll()
    end
    Log:Print('请选择仓库以提供 UUID 参数:')
    for n, uuid in pairs(list) do
        Log:Print('[%s] >> %s - [%s]', n, RepoManager:get(uuid):getName(), uuid)
    end
    Log:Write('(%d-%d) > ', 1, #list)
    local chosed = list[tonumber(io.read())]
    if not chosed then
        Log:Error('输入错误！')
        return nil
    end
    return chosed
end

----------------------------------------------------------
-- ||||||||||||||||| Command Executor ||||||||||||||||| --
----------------------------------------------------------

if #arg == 0 then
    arg[1] = '-h'
end

Command:parse(arg)

----------------------------------------------------------
-- |||||||||||||||| UnInitialization |||||||||||||||||| --
----------------------------------------------------------

Temp:free()
