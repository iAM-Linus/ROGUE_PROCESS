-- src/states/GameState.lua
local GameState = {}
GameState.__index = GameState

local currentState = nil
local states = {} -- To store instances of states

function GameState.register(name, stateInstance)
    states[name] = stateInstance
end

function GameState.switch(stateName, ...)
    if currentState and currentState.leave then
        currentState:leave()
    end
    currentState = states[stateName]
    if not currentState then
        error("Attempted to switch to unknown state: " .. tostring(stateName))
    end
    if currentState.enter then
        currentState:enter(...)
    end
end

function GameState.current()
    return currentState
end

function GameState.get(stateName)
    return states[stateName]
end

function GameState.update(dt)
    if currentState and currentState.update then
        currentState:update(dt)
    end
end

function GameState.draw()
    if currentState and currentState.draw then
        currentState:draw()
    end
end

function GameState.keypressed(key, scancode, isrepeat)
    if currentState and currentState.keypressed then
        return currentState:keypressed(key, scancode, isrepeat)
    end
    return false
end

function GameState.mousepressed(x, y, button, istouch, presses)
    if currentState and currentState.mousepressed then
        currentState:mousepressed(x, y, button, istouch, presses)
    end
end

function GameState.mousemoved(x, y, dx, dy, istouch)
    if currentState and currentState.mousemoved then
        currentState:mousemoved(x, y, dx, dy, istouch)
    end
end

function GameState.resize(w, h)
    if currentState and currentState.resize then
        currentState:resize(w,h)
    else
        -- Default resize behavior if state doesn't handle it
        love.graphics.setCanvas() -- Reset canvas if any
        love.graphics.clear()
        love.graphics.printf("Window resized to " .. w .. "x" .. h, 0,0, w, 'center')
    end
end


return GameState