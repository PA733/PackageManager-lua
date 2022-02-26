--[[ ----------------------------------------

    [Deps] Simple Logger.

--]] ----------------------------------------

local Sym = string.char(0x1b)

Logger = {
    title = '',
    enableTime = true
}

function Logger:new(origin,title,disableTime)
    origin = origin or {}
    setmetatable(origin,self)
    self.__index = self
    self.title = title or 'Unnamed'
    self.enableTime = disableTime or true
    return origin
end

function Logger:Info(what)
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[38;2;032;178;170mINFO '..
        Sym..'[37m['..self.title..'] '..what..
        Sym..
        '[0m\n'
    )
end

function Logger:Warn(what)
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[93mWARN '..
        Sym..'[38;2;235;233;078m['..self.title..'] '..what..
        Sym..
        '[0m\n'
    )
end

function Logger:Error(what)
    io.write(
        Sym..'[38;2;173;216;230m'..os.date('%X')..' ',
        Sym..'[91mERROR '..
        Sym..'[38;2;239;046;046m['..self.title..'] '..what..
        Sym..
        '[0m\n'
    )
end

return Logger