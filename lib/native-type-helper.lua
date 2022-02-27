--[[ ----------------------------------------

    [Deps] Native types helper.

--]] ----------------------------------------

--- string

function string.split(str,reps)
	local result = {}
	string.gsub(str,'[^'..reps..']+',function (n)
		table.insert(result,n)
	end)
	return result
end

--- table

function table.toDebugString(tab)
	local rtn = 'Total: '..#tab
	for k,v in pairs(tab) do
		rtn = rtn..'\n'..tostring(k)..'\t'..tostring(v)
	end
	return rtn
end

Array = {
	Concat = function(origin,array)
		for n,k in pairs(array) do
			origin[#origin+1] = k
		end
		return origin
	end,
}

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
end