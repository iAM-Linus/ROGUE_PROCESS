-- src/core/base_state.lua
-- Base class for all game states with standardized lifecycle
---@class BaseState
local BaseState = {}
BaseState.__index = BaseState

--- Create new state instance
---@param game table : Game instance reference
---@return BaseState : New instance
function BaseState:new(game)
    local instance = setmetatable({
        game = game,
        name = "BaseState",

        -- Quick access to common services
        config = game and game.config or nil,
        events = game and game.events or nil,
        resources = game and game.resources or nil,
        stateManager = game and game.states or nil,

        -- State flags
        initialized = false,
        paused = false,
        visible = true,

        -- Performance tracking
        creationTime = love.timer.getTime(),
        updateCount = 0,
        drawCount = 0
    }, BaseState)

    return instance
end

--- Called when state becomes active
--- Override in subclasses
--- @param ... any : Arguments from state switch
function BaseState:enter(...)
    self.initilized = true
    self.paused = false

    if self.events then
        self.events:emit("state_entered", {state = self.name})
    end
end

--- Called when state becomes inactive
--- Override in subclasses
function BaseState:leave()
    if self.events then
        self.events:emit("state_left", {state = self.name})
    end
end

--- Called when state is removed (cleanup)
--- Override in subclasses
function BaseState:exit()
    self.initilized = false
end

--- Called when state is pushed onto stack
--- Override in subclasses
function BaseState:pause()
    self.paused = true
end

--- Called when state is popped from stack
--- Override in subclasses
function BaseState:resume()
    self.paused = false
end

--- Update state logic
--- Override in subclasses
--- @param dt number: Delta time
function BaseState:update(dt)
    if not self.paused then
        self.updateCount = self.updateCount + 1
    end
end

--- Draw state
--- Override in subclasses
function BaseState:draw()
    if self.visible then
        self.drawCount = self.drawCount + 1
    end
end

--- Draw state when it's under another state (for overlays)
--- Override in subclasses if state should be visible under overlays
function BaseState:drawUnder()
    -- Default: don't draw
end

--- Handle keyboard input
--- Override in subclasses
--- @param key string: Key pressed
--- @param scancode string: Scancode
--- @param isRepeat boolean: Is key repeat
--- @return boolean: Was input handled
function BaseState:keypressed(key, scancode, isRepeat)
    return false
end

--- Handle keyboard release
--- Override in subclasses
--- @param key string: Key released
--- @param scancode string: Scancode
function BaseState:keyreleased(key, scancode)
end

--- Handle mouse press
--- Override in subclasses
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param button number: Mouse button
--- @param istouch boolean: Is touch
--- @param presses number: Number of presses
function BaseState:mousepressed(x, y, button, istouch, presses)
end

--- Handle mouse release
--- Override in subclasses
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param button number: Mouse button
--- @param istouch boolean: Is touch
function BaseState:mousereleased(x, y, button, istouch)
end

--- Handle mouse movement
--- Override in subclasses
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param dx number: Delta X
--- @param dy number: Delta Y
--- @param istouch boolean: Is touch
function BaseState:mousemoved(x, y, dx, dy, istouch)
end

--- Handle window resize
--- Override in subclasses
--- @param w number: New width
--- @param h number: New height
function BaseState:resize(w, h)
end

--- Get state uptime
--- @return number: Seconds since creation
function BaseState:getUptime()
    return love.timer.getTime() - self.creationTime
end

--- Check if state is paused
--- @return boolean: True if paused
function BaseState:isPaused()
    return self.paused
end

--- Check if state is initialized
--- @return boolean: True if initialized
function BaseState:isInitialized()
    return self.initialized
end

--- Set visibility
--- @param visible boolean: Visibility state
function BaseState:setVisible(visible)
    self.visible = visible
end

--- Get performance stats
--- @return table: Stats table
function BaseState:getStats()
    return {
        name = self.name,
        uptime = self:getUptime(),
        updateCount = self.updateCount,
        drawCount = self.drawCount,
        paused = self.paused,
        initialized = self.initialized
    }
end

--- Print debug info
function BaseState:printDebugInfo()
    print(string.format("\n=== %s Debug Info ===", self.name))
    print(string.format("Uptime: %.2fs", self:getUptime()))
    print(string.format("Updates: %d", self.updateCount))
    print(string.format("Draws: %d", self.drawCount))
    print(string.format("Paused: %s", self.paused and "YES" or "NO"))
    print(string.format("Initialized: %s", self.initialized and "YES" or "NO"))
    print("========================\n")
end

return BaseState