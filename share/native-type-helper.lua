--[[ ----------------------------------------

    [Deps] Native types helper.

--]] ----------------------------------------

--- string

function string:split(reps)
	local result = {}
---@diagnostic disable-next-line: discard-returns
	self:gsub('[^'..reps..']+',function (n)
		table.insert(result,n)
	end)
	return result
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

function table.getKey(tab,path)

	--[[
		What is "path"?
		[A] the_table: {a=2,b=7,n=42,ok={pap=626}}
			<path> this.b			=>		7
			<path> this.ok.pap		=>		626
		[B] the_table: {2,3,1,ff={8}}
			<path> this.(*)3		=>		1
			<path> this.ff.(*)1		=>		8
	]]

	if string.sub(path,1,5) == 'this.' then
		path = string.sub(path,6)
	end

	local pathes = string.split(path,'.')
	if #pathes == 0 then
		return tab
	end
	if string.sub(pathes[1],1,3) == '(*)' then
		pathes[1] = tonumber(string.sub(pathes[1],4))
	end
	local lta = tab[pathes[1]]

	if type(lta) ~= 'table' then
		return lta
	end

	return table.getKey(lta,table.concat(pathes,'.',2,#pathes))

end

function table.setKey(tab,path,value)

	if string.sub(path,1,5) == 'this.' then
		path = string.sub(path,6)
	end

	local pathes = string.split(path,'.')
	if string.sub(pathes[1],1,3) == '(*)' then
		pathes[1] = tonumber(string.sub(pathes[1],4))
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

function table.toDebugString(tab)
	local rtn = 'Total: '..#tab
	for k,v in pairs(tab) do
		rtn = rtn..'\n'..tostring(k)..'\t'..tostring(v)
	end
	return rtn
end

array = {}

function array.concat(origin,array)
	for n,k in pairs(array) do
		origin[#origin+1] = k
	end
	return origin
end

function array.fetch(origin,element)
	for p,e in pairs(origin) do
		if element == e then
			return p
		end
	end
	return nil
end

function array.create(length,defaultValue)
	local rtn = {}
	for i=1,length do
		table.insert(rtn,defaultValue)
	end
	return rtn
end

function array.tonumber(original)
	local rtn = {}
	for a,n in pairs(original) do
		rtn[a] = tonumber(n)
	end
	return rtn
end

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
end