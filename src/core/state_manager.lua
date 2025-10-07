-- src/core/state_manager.lua
-- State manager with state stack support for overlays/modals
---@class StateManager
local StateManager = {}
StateManager.__index = StateManager

--- Create new StateManager instance
---@param game table : Game instance reference
---@return StateManager : New instance
function StateManager:new(game)
    local instance =  setmetatable({
        game = game,
        states = {},                -- Registered state classes                
        currentState = nil,        -- Active state
        stateStack = {},           -- Stack for push/pop (overlays, pause, etc.)
        stateHistory = {},          -- History of state transitions
        maxHistorySize = 20,
        debugMode = false
    }, StateManager)

    return instance
end

--- Register a state class
---@param name string : State identifier
---@param stateClass table : State class (not instance)
function StateManager:registerState(name, stateClass)
    assert(type(name) == "string", "State name must be a string")
    assert(type(stateClass) == "table", "State class must be a table")

    if self.states[name] then
        print(string.format("[StateManager] WARNING: State '%s' already registered, overwriting", name))
    end

    self.states[name] = stateClass

    if self.debugMode then
        print(string.format("[StateManager] Registered state: %s", name))
    end
end

-- Alias for compatibility (underscore version)
StateManager.register_state = StateManager.registerState

--- Swtich to a new state (replaces current state)
---@param name string : State identifier
---@param ... any : Arguments to pass to state:enter()
function StateManager:switch(name, ...)
    local stateClass = self.states[name]
    assert(stateClass, string.format("Unknown state: %s", tostring(name)))

    local previousStateName = self.currentState and self.currentState.name or "none"

    -- Exit current state
    if self.currentState then
        if self.currentState.leave then
            self.currentState:leave()
        end
        if self.currentState.exit then
            self.currentState:exit()
        end
    end
    
    -- Create new state instance
    self.currentState = stateClass:new(self.game)
    self.currentState.name = name
    
    -- Enter new state
    if self.currentState.enter then
        self.currentState:enter(...)
    end

    -- Record in history
    self:addToHistory({
        action = "switch",
        from = previousStateName,
        to = name,
        timestamp = love.timer.getTime()
    })
    
    -- Emit state change event
    if self.game and self.game.events then
        self.game.events:emit("state_changed", {
            previous = previousStateName,
            current = name,
            action = "switch"
        })
    end

    if self.debugMode then
        print(string.format("[StateManager] Switch: %s -> %s", previousStateName, name))
    end
end

--- Push a new state onto the stack (keeps current state)
---@param name string : State identifier
---@param ... any : Arguments to pass to state:enter()
function StateManager:push(name, ...)
    local stateClass = self.states[name]
    assert(stateClass, string.format("Unknown state: %s", tostring(name)))

    -- Pause current state
    if self.currentState then
        if self.currentState.pause then
            self.currentState:pause()
        end
    table.insert(self.stateStack, self.currentState)
    end

    local previousStateName = self.currentState and self.currentState.name or "none"

    -- Create and enter new state
    self.currentState = stateClass:new(self.game)
    self.currentState.name = name

    if self.currentState.enter then
        self.currentState:enter(...)
    end

    -- Record in history
    self:addToHistory({
        action = "push",
        from = previousStateName,
        to = name,
        stackDepth = #self.stateStack,
        timestamp = love.timer.getTime()
    })

    -- Emit event
    if self.game and self.game.events then
        self.game.events:emit("state_change", {
            previous = previousStateName,
            current = name,
            action = "push",
            stackDepth = #self.stateStack
        })
    end

    if self.debugMode then
        print(string.format("[StateManager] Pushed: %s (stack depth: %d)", name, #self.stateStack))
    end
end

--- Pop the current state and return to previous
function StateManager:pop()
    if #self.state_stack == 0 then
        print("[StateManager] WARNING: Cannot pop, state stack is empty")
        return
    end

    local poppedStateName = self.currentState and self.currentState.name or "unknown"

    -- Exit current state
    if self.currentState then
        if self.currentState.leave then
            self.currentState:leave()
        end
        if self.currentState.exit then
            self.currentState:exit()
        end
    end

    -- Restore previous state
    local previousState = table.remove(self.stateStack)
        self.currentState = previousState
    
    -- Resume previous state
    if self.currentState.resume then
        self.currentState:resume()
    end

    local resumedStateName = self.currentState and self.currentState.name or "unknown"

    -- Record in history
    self:addToHistory({
        action = "pop",
        from = poppedStateName,
        to = resumedStateName,
        stackDepth = #self.stateStack,
        timestamp = love.timer.getTime()
    })
    
    -- Emit event
    if self.game and self.game.events then
        self.game.events:emit("state_changed", {
            previous = poppedStateName,
            current = resumedStateName,
            action = "pop",
            stackDepth = #self.stateStack
        })
    end
    
    if self.debugMode then
        print(string.format("[StateManager] Popped: %s -> %s (stack depth: %d)", 
            poppedStateName, resumedStateName, #self.stateStack))
    end
end

--- Update current state
--- @param dt number : Delta time
function StateManager:update(dt)
    if self.currentState and self.currentState.update then
        self.currentState:update(dt)
    end
end

--- Draw current state
function StateManager:draw()
    -- Draw all states in stack (for overlay support)
    for _, state in ipairs(self.stateStack) do
        if state.drawUnder then
            state:drawUnder()
        elseif state.draw then
            state:draw()
        end
    end

    -- Draw current state on top
    if self.currentState and self.currentState.draw then
        self.currentState:draw()
    end
end

--- Handle input for current state
---@param key string : Key pressed
---@param scancode string : Scancode
---@param isRepeat boolean : Is key repeat
---@return boolean : Was input handled
function StateManager:handleInput(key, scancode, isRepeat)
    if self.currentState and self.currentState.keypressed then
        return self.currentState:keypressed(key, scancode, isRepeat)
    end
    if self.currentState and self.currentState.handleInput then
        return self.currentState:handleInput(key, scancode, isRepeat)
    end
    return false
end

--- Handle mouse press for current state
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param button number: Mouse button
--- @param istouch boolean: Is touch
--- @param presses number: Number of presses
function StateManager:mousepressed(x, y, button, istouch, presses)
    if self.currentState and self.currentState.mousepressed then
        self.currentState:mousepressed(x, y, button, istouch, presses)
    end
end

--- Handle mouse movement for current state
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param dx number: Delta X
--- @param dy number: Delta Y
--- @param istouch boolean: Is touch
function StateManager:mousemoved(x, y, dx, dy, istouch)
    if self.currentState and self.currentState.mousemoved then
        self.currentState:mousemoved(x, y, dx, dy, istouch)
    end
end

--- Handle window resize for current state
--- @param w number: New width
--- @param h number: New height
function StateManager:resize(w, h)
    -- Resize all states in stack
    for _, state in ipairs(self.stateStack) do
        if state.resize then
            state:resize(w, h)
        end
    end
    
    if self.currentState and self.currentState.resize then
        self.currentState:resize(w, h)
    end
end

--- Get current state
--- @return table|nil: Current state instance
function StateManager:getCurrent()
    return self.currentState
end

--- Get current state name
--- @return string: Current state name or "none"
function StateManager:getCurrentName()
    return self.currentState and self.currentState.name or "none"
end

--- Get state stack depth
--- @return number: Stack depth
function StateManager:getStackDepth()
    return #self.stateStack
end

--- Check if a state is registered
--- @param name string: State identifier
--- @return boolean: True if registered
function StateManager:hasState(name)
    return self.states[name] ~= nil
end

--- Get state history
--- @param limit number: Optional limit on results
--- @return table: Array of history entries
function StateManager:getHistory(limit)
    if not limit or limit >= #self.stateHistory then
        return self.stateHistory
    end
    
    local result = {}
    for i = math.max(1, #self.stateHistory - limit + 1), #self.stateHistory do
        table.insert(result, self.stateHistory[i])
    end
    return result
end

--- Clear state history
function StateManager:clearHistory()
    self.stateHistory = {}
end

--- Get all registered state names
--- @return table: Array of state names
function StateManager:getAllStateNames()
    local names = {}
    for name, _ in pairs(self.states) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Set debug mode
--- @param enabled boolean: Debug mode state
function StateManager:setDebugMode(enabled)
    self.debugMode = enabled
end

--- Print debug information
function StateManager:printDebugInfo()
    print("\n=== StateManager Debug Info ===")
    print(string.format("Current state: %s", self:getCurrentName()))
    print(string.format("Stack depth: %d", #self.stateStack))
    
    if #self.stateStack > 0 then
        print("\nState stack:")
        for i, state in ipairs(self.stateStack) do
            print(string.format("  %d. %s", i, state.name or "unnamed"))
        end
    end
    
    print("\nRegistered states:")
    local names = self:getAllStateNames()
    for _, name in ipairs(names) do
        print(string.format("  - %s", name))
    end
    
    if #self.stateHistory > 0 then
        print("\nRecent transitions:")
        local recentCount = math.min(5, #self.stateHistory)
        for i = #self.stateHistory - recentCount + 1, #self.stateHistory do
            local entry = self.stateHistory[i]
            print(string.format("  - %s: %s -> %s (%.3fs ago)", 
                entry.action, entry.from, entry.to, 
                love.timer.getTime() - entry.timestamp))
        end
    end
    
    print("================================\n")
end

--- Private: Add entry to history
function StateManager:addToHistory(entry)
    table.insert(self.stateHistory, entry)
    
    -- Trim history if too large
    while #self.stateHistory > self.maxHistorySize do
        table.remove(self.stateHistory, 1)
    end
end

return StateManager