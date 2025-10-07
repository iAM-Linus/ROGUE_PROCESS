-- src/core/object_pool.lua
local ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool:new(class, initial_size, reset_func)
    local instance = setmetatable({
        class = class,
        reset_func = reset_func,
        available = {},
        in_use = {}
    }, ObjectPool)
    
    -- Pre-allocate objects
    for i = 1, initial_size do
        table.insert(instance.available, class:new())
    end
    
    return instance
end

function ObjectPool:acquire(...)
    local object
    
    if #self.available > 0 then
        object = table.remove(self.available)
    else
        object = self.class:new()
    end
    
    if self.reset_func then
        self.reset_func(object, ...)
    end
    
    self.in_use[object] = true
    return object
end

function ObjectPool:release(object)
    if self.in_use[object] then
        self.in_use[object] = nil
        table.insert(self.available, object)
    end
end

function ObjectPool:clear()
    for object in pairs(self.in_use) do
        self:release(object)
    end
end

return ObjectPool