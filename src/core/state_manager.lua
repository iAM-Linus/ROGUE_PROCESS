-- src/core/state_manager.lua
local StateManager = {}
StateManager.__index = StateManager

function StateManager:new(game)
    return setmetatable({
        game = game,
        states = {},
        current_state = nil,
        state_stack = {}
    }, StateManager)
end

function StateManager:register_state(name, state_class)
    self.states[name] = state_class
end

function StateManager:switch(name, ...)
    local state_class = self.states[name]
    assert(state_class, "Unknown state: " .. tostring(name))
    
    if self.current_state then
        if self.current_state.exit then
            self.current_state:exit()
        end
    end
    
    self.current_state = state_class:new(self.game)
    
    if self.current_state.enter then
        self.current_state:enter(...)
    end
    
    self.game.events:emit("state_changed", name)
end

function StateManager:push(name, ...)
    table.insert(self.state_stack, self.current_state)
    self:switch(name, ...)
end

function StateManager:pop()
    if #self.state_stack > 0 then
        local previous_state = table.remove(self.state_stack)
        self.current_state = previous_state
        
        if self.current_state.resume then
            self.current_state:resume()
        end
    end
end