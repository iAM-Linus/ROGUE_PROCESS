-- src/core/event_dispatcher.lua
-- Event system with filtering, history and error handling
local EventDispatcher = {}
EventDispatcher.__index = EventDispatcher

--- Create new EventDispatcher instance
---@param config table : Optional configuration
---@return EventDispatcher : New instance
function EventDispatcher:new(config)
    config = config or {}
    
    local instance = setmetatable({
        listeners = {},           -- {event_type: {listener_id: {callback, priority, filter}}}
        eventQueue = {},          -- Queued events to process later
        eventHistory = {},        -- Recent events for debugging
        maxHistorySize = config.maxHistorySize or 100,
        debugMode = config.debugMode or false,
        nextListenerId = 1,       -- Auto-increment ID for listeners
        wildcardListeners = {},   -- Listeners for all events
        enableHistory = config.enableHistory ~= false, -- Default true
    }, EventDispatcher)

    if instance.debugMode then
        print("[EventDispatcher] Created with debug mode enabled")
    end

    return instance
end

--- Subscribe to an event
---@param eventType string : Event type to listen for
---@param callback function : Function to call when event fires
---@param priority number : Optional priority (higher = earlier, default 0)
---@param filter function : Optional filter function(eventData) -> boolean
---@return number : Listener ID (for unsubscribing)
function EventDispatcher:on(eventType, callback, priority, filter)
    assert(type(eventType) == "string", "Event type must be a string")
    assert(type(callback) == "function", "Callback must be a function")

    priority = priority or 0

    if not self.listeners[eventType] then
        self.listeners[eventType] = {}
    end
    
    local listenerId = self.nextListenerId
    self.nextListenerId = self.nextListenerId + 1

    self.listeners[eventType][listenerId] = {
        callback = callback,
        priority = priority,
        filter = filter,
        id = listenerId
    }

    -- Sort listeners by priority (descending)
    self:sortListeners(eventType)

    if self.debugMode then
        print(string.format("[EventDispatcher] Registered listener %d for '%s' (priority: %d)",
            listenerId, eventType, priority))
    end
    
    return listenerId
end

--- Subscribe to all events (wildcard listener)
---@param callback function : Function to call for any event
---@param priority number : Optional priority
---@return number : Listener ID
function EventDispatcher:onAny(callback, priority)
    assert(type(callback) == "function", "Callback must be a function")
    
    priority = priority or 0
    local listenerId = self.nextListenerId
    self.nextListenerId = self.nextListenerId + 1

    table.insert(self.wildcardListeners, {
        callback = callback,
        priority = priority,
        id = listenerId
    })

    -- Sort by priority
    table.sort(self.wildcardListeners, function(a, b)
        return a.priority > b.priority
    end)

    if self.debugMode then
        print(string.format("[EventDispatcher] Registered wildcard listener %d (priority: %d)", 
            listenerId, priority))
    end

    return listenerId
end

--- Unsubscribe from an event
---@param eventType string : Event type
---@param listenerId number : Listener ID from on()
function EventDispatcher:off(eventType, listenerId)
    if self.listeners[eventType] and self.listener[eventType][listenerId] then
        self.listeners[eventType][listenerId] = nil

        if self.debugMode then
            print(string.format("[EventDispatcher] Removed listener %d from '%s'", listenerId, eventType))
        end
    end
end

--- Unsubscribe a wildcard listener
---@param listenerId number : Listener ID from onAny()
function EventDispatcher:offAny(listenerId)
    for i = #self.wildcardListeners, 1, -1 do
        if self.wildcardListeners[i].id == listenerId then
            table.remove(self.wildcardListeners, i)

            if self.debugMode then
                print(string.format("[EventDispatcher] Removed wildcard listener %d", listenerId))
            end
            break
        end
    end
end

--- Remove all listeners for an event type
---@param eventType string : Event type
function EventDispatcher:removeAllListeners(eventType)
    if eventType then
        self.listeners[eventType] = {}
        if self.debugMode then
            print(string.format("[EventDispatcher] Removed all listeners for '%s'", eventType))
        end
    else
        self.listeners = {}
        self.wildcardListeners = {}
        if self.debugMode then
            print("[EventDispather] Removed ALL listeners")
        end
    end
end

--- Emit an event immediately
---@param eventType string : Event type
---@param eventData any : Data to pass to listeners
function EventDispatcher:emit(eventType, eventData)
    assert(type(eventType) == "string", "Event type must be a string")

    local event = {
        type = eventType,
        data = eventData,
        timestamp = love.timer.getTime()
    }

    -- Add to history
    if self.enableHistory then
        self:addToHistory(event)
    end
    
    if self.debugMode then
        print(string.format("[EventDispatcher] Emitting '%s'", eventType))
    end

    -- Call wildcard listeners first
    self:callWildcardListeners(event)

    -- Call specific listeners
    local listeners = self.listeners[eventType]
    if not listeners then return end

    -- Create sorted array of listeners
    local sortedListeners = self:getSortedListeners(eventType)

    for _, listener in ipairs(sortedListeners) do
        -- Apply filter if present
        if not listener.filter or listener.filter(eventData) then
            local success, err = pcall(listener.callback, eventData, event)
            if not success then
                print(string.format("[EventDispatcher] ERROR in listener for '%s': %s", eventType, err))
                if self.debugMode then
                    print(debug.traceback())
                end
            end
        end
    end
end

--- Queue an event for later processing
---@param eventType string : Event tyoe
---@param eventData any : Data to pass to listeners
function EventDispatcher:queue(eventType, eventData)
    assert(type(eventType) == "string", "Event type must be a string")

    table.insert(self.eventQueue, {
        type = eventType,
        data = eventData,
        timestamp = love.timer.getTime()
    })

    if self.debugMode then
        print(string.format("[EventDispatcher] Queued '%s' (queue size: %d)", eventType, #self.eventQueue))
    end
end

--- Process all queued events
function EventDispatcher:processQueue()
    local queue = self.eventQueue
    self.eventQueue = {}
    
    for _, event in ipairs(queue) do
        self:emit(event.type, event.data)
    end
end

--- Get event history
---@param eventType string: Optional filter by event type
---@param limit number : Optional limit on results
---@return table : Array of events
function EventDispatcher:getHistory(eventType, limit)
    if not eventType then
        if limit then
            local result = {}
            for i = math.max(1, #self.eventHistory - limit + 1), #self.eventHistory do
                table.insert(result, self.eventHistory[i])
            end
            return result
        end
        return self.eventHistory
    end
    
    local filtered = {}
    for _, event in ipairs(self.eventHistory) do
        if event.type == eventType then
            table.insert(filtered, event)
        end
    end

    if limit and #filtered > limit then
        local result = {}
        for i = math.max(1, #filtered - limit + 1), #filtered do
            table.insert(result, filtered[i])
        end
        return result
    end

    return filtered
end

--- Clear event history
function EventDispatcher:clearHistory()
    self.eventHistory = {}
end

function EventDispatcher:getListenerCount(eventType)
    if not self.listeners[eventType] then return 0 end
    
    local count = 0
    for _ in ipairs(self.listeners[eventType]) do
    count = count + 1
    end
    return count
end

-- Print debug information
function EventDispatcher:printDebugInfo()
    print("\n=== EventDispatcher Debug Info ===")
    print(string.format("Queued events: %d", #self.eventQueue))
    print(string.format("History size: %d", #self.eventHistory))
    print(string.format("Wildcard listeners: %d", #self.wildcardListeners))
    
    print("\nEvent types with listeners:")
    for eventType, _ in pairs(self.listeners) do
        print(string.format("  - %s: %d listeners", eventType, self:getListenerCount(eventType)))
    end
    
    if #self.eventHistory > 0 then
        print("\nRecent events:")
        local recentCount = math.min(5, #self.eventHistory)
        for i = #self.eventHistory - recentCount + 1, #self.eventHistory do
            local event = self.eventHistory[i]
            print(string.format("  - %s (%.3fs ago)", event.type, love.timer.getTime() - event.timestamp))
        end
    end
    
    print("==================================\n")
end

-- Private: Sort listeners by priority
function EventDispatcher:sortListeners(eventType)
    -- We'll sort when getting listeners instead for efficiency
end

-- Private: Get sorted array of listeners
function EventDispatcher:getSortedListeners(eventType)
    local listeners = self.listeners[eventType]
    if not listeners then return {} end
    
    local sortedListeners = {}
    for _, listener in pairs(listeners) do
        table.insert(sortedListeners, listener)
    end
    
    table.sort(sortedListeners, function(a, b)
        return a.priority > b.priority
    end)
    
    return sortedListeners
end

-- Private: Call wildcard listeners
function EventDispatcher:callWildcardListeners(event)
    for _, listener in ipairs(self.wildcardListeners) do
        local success, err = pcall(listener.callback, event.data, event)
        if not success then
            print(string.format("[EventDispatcher] ERROR in wildcard listener: %s", err))
        end
    end
end

-- Private: Add event to history
function EventDispatcher:addToHistory(event)
    table.insert(self.eventHistory, event)
    
    -- Trim history if too large
    while #self.eventHistory > self.maxHistorySize do
        table.remove(self.eventHistory, 1)
    end
end

return EventDispatcher