-- src/core/VisualEffects.lua
local config = ServiceLocator.get("config")

local VisualEffects = {}

function VisualEffects.drawGlitchText(text, x, y, font, color, glitchIntensity)
    glitchIntensity = glitchIntensity or 1
    local time = love.timer.getTime() * 10
    
    love.graphics.setFont(font)
    
    -- Glitch layers
    if glitchIntensity > 0.5 then
        love.graphics.setColor(1, 0.2, 0.2, 0.4)
        love.graphics.print(text, x + math.sin(time) * 2, y - 1)
        love.graphics.setColor(0.2, 1, 0.2, 0.4)
        love.graphics.print(text, x - math.cos(time) * 2, y + 1)
    end
    
    -- Main text
    love.graphics.setColor(color)
    love.graphics.print(text, x, y)
end

function VisualEffects.drawDataStream(x, y, width, height, speed, density)
    speed = speed or 50
    density = density or 0.1
    
    local time = love.timer.getTime() * speed
    love.graphics.setColor(config.activeColors.accent[1], config.activeColors.accent[2], 
                          config.activeColors.accent[3], 0.3)
    
    for i = 0, width, 10 do
        local streamY = (y + (time + i * 2) % (height + 20)) - 20
        if math.random() < density then
            love.graphics.rectangle("fill", x + i, streamY, 2, 8)
        end
    end
end

function VisualEffects.drawHologramEffect(drawFunction, intensity)
    intensity = intensity or 0.5
    local time = love.timer.getTime()
    
    -- Scanline effect
    love.graphics.push()
    love.graphics.translate(0, math.sin(time * 5) * intensity)
    
    -- Color separation
    love.graphics.setColor(1, 0.8, 0.8, 0.9)
    love.graphics.translate(-intensity, 0)
    drawFunction()
    
    love.graphics.setColor(0.8, 1, 0.8, 0.9)
    love.graphics.translate(intensity * 2, 0)
    drawFunction()
    
    love.graphics.setColor(0.8, 0.8, 1, 0.9)
    love.graphics.translate(-intensity, 0)
    drawFunction()
    
    love.graphics.pop()
    
    -- Main pass
    love.graphics.setColor(1, 1, 1, 1)
    drawFunction()
end

return VisualEffects