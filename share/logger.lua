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
    io.write(
        color.date..os.date('%X')..' ',
        color.type..type..' ',
        color.title..'['..logger.title..'] '..what,
        color.text..'\n'
    )
end

--- 全局禁用日志器颜色
---@return boolean
function Logger.setNoColor()
    Logger.no_color = true
    return true
end

--- 打印普通信息
---@param what string
---@param ... any
function Logger:Info(what,...)
    rawLog(self,'INFO',what:format(...))
end

--- 打印警告信息
---@param what string
---@param ... string
function Logger:Warn(what,...)
    rawLog(self,'WARN',what:format(...))
end

--- 打印错误信息
---@param what string
---@param ... string
function Logger:Error(what,...)
    rawLog(self,'ERROR',what:format(...))
end

--- 打印调试信息
---@param what any
---@param ... any
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

return Logger