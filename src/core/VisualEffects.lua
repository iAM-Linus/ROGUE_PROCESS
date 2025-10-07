-- Add this new file: src/core/VisualEffects.lua
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
    love.graphics.setColor(Config.activeColors.accent[1], Config.activeColors.accent[2], 
                          Config.activeColors.accent[3], 0.3)
    
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

--[[
INTEGRATION CHECKLIST:

□ 1. Replace src/ui/ui_helpers.lua with the modern version
□ 2. Replace src/core/managers/HUDManager.lua with the modern version  
□ 3. Update GameplayState constructor to use hudManager instead of hudRoot
□ 4. Update GameplayState:draw() method to use hudManager:draw()
□ 5. Remove or comment out old HUD methods in GameplayState
□ 6. Update src/states/MainMenuState.lua with enhanced version
□ 7. Update src/states/SubroutineChoiceState.lua with enhanced version
□ 8. Update src/states/CoreModificationState.lua with enhanced version
□ 9. Add enhanced colors to your config.lua
□ 10. Add src/core/VisualEffects.lua file
□ 11. Test each state to ensure proper integration

OPTIONAL ENHANCEMENTS:
□ Add particle system for menu backgrounds
□ Implement smooth transitions between states
□ Add sound effects for UI interactions (already in your SFX system)
□ Add gamepad/controller support for UI navigation
□ Implement UI themes/skins system
□ Add screen reader accessibility support

PERFORMANCE NOTES:
- The new UI system uses more draw calls but provides much better visuals
- Consider disabling some effects on lower-end systems
- Particle effects can be toggled via Config.visualEffects.enableParticles
- Use Config.visualEffects.enableGlow to toggle glow effects
--]]

return VisualEffects