-- src/core/event_dispatcher.lua
local EventDispatcher = {}
EventDispatcher.__index = EventDispatcher

function EventDispatcher:new()
    return setmetatable({
        listeners = {},
        event_queue = {}
    }, EventDispatcher)
end

function EventDispatcher:on(event_type, callback, priority)
    priority = priority or 0
    if not self.listeners[event_type] then
        self.listeners[event_type] = {}
    end
    
    table.insert(self.listeners[event_type], {
        callback = callback,
        priority = priority
    })
    
    table.sort(self.listeners[event_type], function(a, b)
        return a.priority > b.priority
    end)
end

function EventDispatcher:emit(event_type, ...)
    local listeners = self.listeners[event_type]
    if not listeners then return end
    
    for _, listener in ipairs(listeners) do
        local success, err = pcall(listener.callback, ...)
        if not success then
            print("Event error:", event_type, err)
        end
    end
end

function EventDispatcher:queue(event_type, data)
    table.insert(self.event_queue, {
        type = event_type,
        data = data,
        timestamp = love.timer.getTime()
    })
end

function EventDispatcher:process_queue()
    local queue = self.event_queue
    self.event_queue = {}
    
    for _, event in ipairs(queue) do
        self:emit(event.type, event.data)
    end
end

return EventDispatcher