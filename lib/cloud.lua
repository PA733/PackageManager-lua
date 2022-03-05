--[[ ----------------------------------------

    [Deps] Cloud download utils.

--]] ----------------------------------------

local socket = require "ssl.https"
local ltn12 = require "ltn12"
require "logger"

local Log = Logger:new('Cloud')

Cloud = {
    Download = function (str)
        local https = require 'ssl.https'
        local r, c, h, s = https.request{
            url = str,
            sink = ltn12.sink.table({}),
            protocol = "tlsv1"
        }
    end
}

return Cloud