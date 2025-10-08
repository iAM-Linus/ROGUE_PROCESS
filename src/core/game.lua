-- src/core/game.
-- Game coordinator singleton - Phase 1 foundation
local ServiceLocator = require "src.core.service_locator"
local EventDispatcher = require "src.core.event_dispatcher"
local ResourceManager = require "src.core.resource_manager"
local StateManager = require "src.core.state_manager"

---@class Game
local Game = {}
Game.__index = Game

-- Singleton instance
local instance = nil

--- Create or get Game singleton
---@param config table : Configuration object
---@return Game : Game instance
function Game:new(config)
    if instance then
        print("[Game] WARNING: Game singleton already exists, returning existing instance")
        return instance
    end

    instance = setmetatable({
        config = config,
        events = nil,
        resources = nil,
        state = nil,

        -- System flags
        initialized = false,
        running = false,
        debugMode = false,

        -- Performance tracking
        frameCount = 0,
        updateTime = 0,
        drawTime = 0,

        
        -- Timing
        startTime = love.timer.getTime(),
        lastFrameTime = love.timer.getTime()
    }, Game)

    -- Initialize core systems
    instance:initializeSystems()

    return instance
end

--- Get singleton instance
--- @return Game|nil : Game instance or nil if not created
function Game.getInstance()
    return instance
end

--- Initialize core systems
function Game:initializeSystems()
    print("[Game] Initializing core systems...")

    -- Create core systems
    self.events = EventDispatcher:new({
        debugMode = self.debugMode,
        enableHistory = true,
        maxHistorySize = 100
    })

    self.resources = ResourceManager:new(self.config)
    self.states = StateManager:new(self)

    -- Register systems in ServiceLocator
    ServiceLocator.register("game", self)
    ServiceLocator.register("config", self.config)
    ServiceLocator.register("events", self.events)
    ServiceLocator.register("resources", self.resources)
    ServiceLocator.register("states", self.states)

    print("[Game] Core systems initialized")
end

--- Full initialization (called from main.lua)
function Game:initialize()
    if self.initialized then
        print("[Game] Already initialized")
        return
    end

    print("[Game] Running full initialization...")
    
    -- Load all resources
    self.resources:loadAll()

    -- System is ready
    self.initialized = true
    self.running = true
    
    -- Emit initialization event
    self.events:emit("game_initialized", {
        uptime = self:getUptime()
    })

    print("[Game] Initialization complete")
end

--- Update game systems
---@param dt number : Delta time
function Game:update(dt)
    if not self.running then return end

    local startTime = love.timer.getTime()

    -- Process event queue
    self.events:processQueue()

    -- Update current state
    self.states:update(dt)

    -- Update performance tracking
    self.updateTime = love.timer.getTime() - startTime
    self.frameCount = self.frameCount + 1
    self.lastFrameTime = love.timer.getTime()
end

--- Draw game
function Game:draw()
    if not self.running then return end

    local startTime = love.timer.getTime()

    -- Draw current state
    self.states:draw()

    -- Update performance tracking
    self.drawTime = love.timer.getTime() - startTime
end

--- Handle keyboard input
--- @param key string: Key pressed
--- @param scancode string: Scancode
--- @param isRepeat boolean: Is key repeat
--- @return boolean: Was input handled
function Game:handleInput(key, scancode, isRepeat)
    if not self.running then return false end
    
    -- Debug shortcuts (only in debug mode)
    if self.debugMode then
        if key == "f1" then
            self:printDebugInfo()
            return true
        elseif key == "f2" then
            self.resources:printDebugInfo()
            return true
        elseif key == "f3" then
            self.states:printDebugInfo()
            return true
        elseif key == "f4" then
            self.events:printDebugInfo()
            return true
        elseif key == "f5" then
            ServiceLocator.printDebugInfo()
            return true
        end
    end
    
    -- Pass to state manager
    return self.states:handleInput(key, scancode, isRepeat)
end

--- Handle mouse press
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param button number: Mouse button
--- @param istouch boolean: Is touch
--- @param presses number: Number of presses
function Game:mousepressed(x, y, button, istouch, presses)
    if not self.running then return end
    self.states:mousepressed(x, y, button, istouch, presses)
end

--- Handle mouse movement
--- @param x number: Mouse X
--- @param y number: Mouse Y
--- @param dx number: Delta X
--- @param dy number: Delta Y
--- @param istouch boolean: Is touch
function Game:mousemoved(x, y, dx, dy, istouch)
    if not self.running then return end
    self.states:mousemoved(x, y, dx, dy, istouch)
end

--- Handle window resize
--- @param w number: New width
--- @param h number: New height
function Game:resize(w, h)
    if not self.running then return end
    self.states:resize(w, h)
    self.events:emit("window_resized", {width = w, height = h})
end

--- Pause game
function Game:pause()
    if not self.running then return end
    
    self.running = false
    self.events:emit("game_paused", {})
    print("[Game] Paused")
end

--- Resume game
function Game:resume()
    if self.running then return end
    
    self.running = true
    self.events:emit("game_resumed", {})
    print("[Game] Resumed")
end

--- Shutdown game
function Game:shutdown()
    print("[Game] Shutting down...")
    
    self.running = false
    
    -- Emit shutdown event
    self.events:emit("game_shutdown", {})
    
    -- Cleanup resources
    if self.resources then
        self.resources:cleanup()
    end
    
    -- Clear service locator
    ServiceLocator.clear()
    
    -- Clear singleton
    instance = nil
    
    print("[Game] Shutdown complete")
end

--- Get game uptime
--- @return number: Seconds since creation
function Game:getUptime()
    return love.timer.getTime() - self.startTime
end

--- Get average FPS
--- @return number: Frames per second
function Game:getFPS()
    local uptime = self:getUptime()
    if uptime == 0 then return 0 end
    return self.frameCount / uptime
end

--- Get performance stats
--- @return table: Stats table
function Game:getStats()
    return {
        uptime = self:getUptime(),
        frameCount = self.frameCount,
        fps = self:getFPS(),
        updateTime = self.updateTime,
        drawTime = self.drawTime,
        initialized = self.initialized,
        running = self.running
    }
end

--- Set debug mode
--- @param enabled boolean: Debug mode state
function Game:setDebugMode(enabled)
    self.debugMode = enabled
    
    -- Propagate to subsystems
    if self.events then self.events.debugMode = enabled end
    if self.resources then self.resources:setDebugMode(enabled) end
    if self.states then self.states:setDebugMode(enabled) end
    
    ServiceLocator.setDebugMode(enabled)
    
    print(string.format("[Game] Debug mode: %s", enabled and "ENABLED" or "DISABLED"))
    
    if enabled then
        print("Debug shortcuts:")
        print("  F1 - Game debug info")
        print("  F2 - Resources debug info")
        print("  F3 - States debug info")
        print("  F4 - Events debug info")
        print("  F5 - Services debug info")
    end
end

--- Print debug information
function Game:printDebugInfo()
    print("\n========== GAME DEBUG INFO ==========")
    print(string.format("Uptime: %.2fs", self:getUptime()))
    print(string.format("Frame Count: %d", self.frameCount))
    print(string.format("Average FPS: %.1f", self:getFPS()))
    print(string.format("Last Update Time: %.3fms", self.updateTime * 1000))
    print(string.format("Last Draw Time: %.3fms", self.drawTime * 1000))
    print(string.format("Initialized: %s", self.initialized and "YES" or "NO"))
    print(string.format("Running: %s", self.running and "YES" or "NO"))
    print(string.format("Debug Mode: %s", self.debugMode and "YES" or "NO"))
    print(string.format("Current State: %s", self.states:getCurrentName()))
    print("=====================================\n")
end

return Game