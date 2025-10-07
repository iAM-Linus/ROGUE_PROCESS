-- src/core/base_state.lua
local BaseState = {}
BaseState.__index = BaseState

function BaseState:new(game)
    return setmetatable({
        game = game,
        config = game.config,
        events = game.events,
        resources = game.resources
    }, BaseState)
end

function BaseState:enter(...) end
function BaseState:exit() end
function BaseState:resume() end
function BaseState:update(dt) end
function BaseState:draw() end
function BaseState:handle_input(key, scancode, is_repeat) return false end

return BaseState