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
end