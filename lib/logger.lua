--[[ ----------------------------------------

    [Deps] Simple Logger.

--]] ----------------------------------------

local Sym = string.char(0x1b)
Logger = {}

function Logger:new(title)
    local origin = {}
    setmetatable(origin,self)
    self.__index = self
    origin.title = title or 'Unknown'
    return origin
end

function Logger:Info(what,...)
    what = string.format(what,...)
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[38;2;032;178;170mINFO '..
        Sym..'[37m['..self.title..'] '..what..
        Sym..'[0m\n'
    )
end

function Logger:Warn(what,...)
    what = string.format(what,...)
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[93mWARN '..
        Sym..'[38;2;235;233;078m['..self.title..'] '..what..
        Sym..'[0m\n'
    )
end

function Logger:Error(what,...)
    what = string.format(what,...)
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[91mERROR '..
        Sym..'[38;2;239;046;046m['..self.title..'] '..what..
        Sym..'[0m\n'
    )
end

function Logger:Debug(what,...)
    what = string.format(what,...)
    if not DevMode then
        return
    end
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[38;2;030;144;255mDEBUG '..
        Sym..'[37m['..self.title..'] '..what..
        Sym..'[0m\n'
    )
end

return Logger