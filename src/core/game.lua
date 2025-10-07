-- src/core/game.lua
local ServiceLocator = require "src.core.service_locator"
local EventDispatcher = require "src.core.event_dispatcher"
local ResourceManager = require "src.core.resource_manager"
local StateManager = require "src.core.state_manager"

local Game = {}
Game.__index = Game

function Game:new(config)
    local instance = setmetatable({}, Game)
    
    -- Core services
    instance.config = config
    instance.events = EventDispatcher:new()
    instance.resources = ResourceManager:new()
    instance.states = StateManager:new(instance)
    
    -- Register services
    ServiceLocator.register("game", instance)
    ServiceLocator.register("config", config)
    ServiceLocator.register("events", instance.events)
    ServiceLocator.register("resources", instance.resources)
    ServiceLocator.register("states", instance.states)
    
    return instance
end

function Game:initialize()
    -- Load resources
    self.resources:load_fonts()
    self.resources:load_sprites()
    self.resources:load_sounds()
    
    -- Initialize states
    self.states:register_state("main_menu", require("src.states.main_menu_state"))
    self.states:register_state("gameplay", require("src.states.gameplay_state"))
    self.states:register_state("pause", require("src.states.pause_state"))
    
    -- Start with main menu
    self.states:switch("main_menu")
end

function Game:update(dt)
    self.events:process_queue()
    self.states:update(dt)
end

function Game:draw()
    self.states:draw()
end

function Game:handle_input(key, scancode, is_repeat)
    return self.states:handle_input(key, scancode, is_repeat)
end

return Game