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
end