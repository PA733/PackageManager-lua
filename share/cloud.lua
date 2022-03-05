--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local curl = require "cURL"
local Fs = require "filesystem"
require "logger"

local Log = Logger:new('Cloud')

Cloud = {
    Download = function (str)
        curl.easy {
            url = 'http://httpbin.org/get',
            writefunction = io.stderr
          }
          :perform()
        :close()
    end
}

return Cloud