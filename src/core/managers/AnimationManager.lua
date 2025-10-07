-- src/core/AnimationManager.lua - New comprehensive animation system
local Helpers = require "src.utils.helpers"

local AnimationManager = {}
AnimationManager.__index = AnimationManager

function AnimationManager:new()
    local instance = setmetatable({}, AnimationManager)
    instance.animations = {}
    instance.globalTime = 0
    instance.shakeOffset = {x = 0, y = 0}
    instance.flashEffects = {}
    instance.pulseEffects = {}
    instance.floatingTexts = {}
    instance.particleTrails = {}
    
    return instance
end

function AnimationManager:update(dt)
    self.globalTime = self.globalTime + dt
    
    -- Update all active animations
    for i = #self.animations, 1, -1 do
        local anim = self.animations[i]
        anim.elapsed = anim.elapsed + dt
        
        if anim.elapsed >= anim.duration then
            if anim.onComplete then anim.onComplete() end
            table.remove(self.animations, i)
        else
            if anim.onUpdate then
                anim.onUpdate(anim.elapsed / anim.duration)
            end
        end
    end
    
    -- Update flash effects
    for i = #self.flashEffects, 1, -1 do
        local flash = self.flashEffects[i]
        flash.elapsed = flash.elapsed + dt
        if flash.elapsed >= flash.duration then
            table.remove(self.flashEffects, i)
        end
    end
    
    -- Update pulse effects
    for i = #self.pulseEffects, 1, -1 do
        local pulse = self.pulseEffects[i]
        pulse.elapsed = pulse.elapsed + dt
        if pulse.elapsed >= pulse.duration then
            table.remove(self.pulseEffects, i)
        end
    end
    
    -- Update floating texts
    for i = #self.floatingTexts, 1, -1 do
        local text = self.floatingTexts[i]
        text.elapsed = text.elapsed + dt
        text.y = text.y + text.vy * dt
        text.vy = text.vy + text.gravity * dt
        text.alpha = text.initialAlpha * (1 - text.elapsed / text.duration)
        
        if text.elapsed >= text.duration then
            table.remove(self.floatingTexts, i)
        end
    end
    
    -- Update particle trails
    for i = #self.particleTrails, 1, -1 do
        local trail = self.particleTrails[i]
        trail.elapsed = trail.elapsed + dt
        
        -- Update trail particles
        for j = #trail.particles, 1, -1 do
            local particle = trail.particles[j]
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            particle.life = particle.life + dt
            particle.alpha = math.max(0, 1 - particle.life / particle.maxLife)
            
            if particle.life >= particle.maxLife then
                table.remove(trail.particles, j)
            end
        end
        
        if trail.elapsed >= trail.duration and #trail.particles == 0 then
            table.remove(self.particleTrails, i)
        end
    end
end

-- Screen shake animation
function AnimationManager:addScreenShake(intensity, duration)
    local shakeAnim = {
        elapsed = 0,
        duration = duration or 0.3,
        intensity = intensity or 5,
        onUpdate = function(progress)
            local currentIntensity = intensity * (1 - progress) * (1 - progress) -- Ease out
            self.shakeOffset.x = (love.math.random() - 0.5) * currentIntensity * 2
            self.shakeOffset.y = (love.math.random() - 0.5) * currentIntensity * 2
        end,
        onComplete = function()
            self.shakeOffset.x = 0
            self.shakeOffset.y = 0
        end
    }
    table.insert(self.animations, shakeAnim)
end

-- Flash effect for damage/healing
function AnimationManager:addFlashEffect(color, intensity, duration)
    table.insert(self.flashEffects, {
        color = color or {1, 1, 1, 1},
        intensity = intensity or 0.5,
        duration = duration or 0.2,
        elapsed = 0
    })
end

-- Pulse effect for UI elements
function AnimationManager:addPulseEffect(x, y, maxRadius, color, duration)
    table.insert(self.pulseEffects, {
        x = x, y = y,
        maxRadius = maxRadius or 50,
        color = color or _G.Config.activeColors.accent,
        duration = duration or 0.8,
        elapsed = 0
    })
end

-- Floating combat text
function AnimationManager:addFloatingText(text, x, y, color, font, options)
    options = options or {}
    table.insert(self.floatingTexts, {
        text = text,
        x = x, y = y,
        vy = options.vy or -40,
        gravity = options.gravity or 20,
        color = color or {1, 1, 1, 1},
        font = font or _G.Fonts.medium,
        duration = options.duration or 1.5,
        initialAlpha = color and color[4] or 1,
        alpha = color and color[4] or 1,
        elapsed = 0
    })
end

-- Particle trail effect
function AnimationManager:addParticleTrail(startX, startY, endX, endY, particleCount, color, duration)
    local trail = {
        particles = {},
        duration = duration or 0.5,
        elapsed = 0
    }
    
    for i = 1, particleCount or 10 do
        local t = i / particleCount
        local x = startX + (endX - startX) * t
        local y = startY + (endY - startY) * t
        
        table.insert(trail.particles, {
            x = x + love.math.random(-5, 5),
            y = y + love.math.random(-5, 5),
            vx = love.math.random(-20, 20),
            vy = love.math.random(-20, 20),
            life = 0,
            maxLife = love.math.random(0.3, 0.8),
            alpha = 1,
            color = color or _G.Config.activeColors.accent
        })
    end
    
    table.insert(self.particleTrails, trail)
end

-- Draw all visual effects
function AnimationManager:draw()
    -- Draw flash effects
    for _, flash in ipairs(self.flashEffects) do
        local alpha = flash.intensity * (1 - flash.elapsed / flash.duration)
        love.graphics.setColor(flash.color[1], flash.color[2], flash.color[3], alpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
    
    -- Draw pulse effects
    for _, pulse in ipairs(self.pulseEffects) do
        local progress = pulse.elapsed / pulse.duration
        local radius = pulse.maxRadius * progress
        local alpha = (1 - progress) * 0.8
        
        love.graphics.setColor(pulse.color[1], pulse.color[2], pulse.color[3], alpha)
        love.graphics.circle("line", pulse.x, pulse.y, radius)
        love.graphics.setColor(pulse.color[1], pulse.color[2], pulse.color[3], alpha * 0.3)
        love.graphics.circle("fill", pulse.x, pulse.y, radius * 0.7)
    end
    
    -- Draw floating texts
    for _, text in ipairs(self.floatingTexts) do
        love.graphics.setFont(text.font)
        love.graphics.setColor(text.color[1], text.color[2], text.color[3], text.alpha)
        love.graphics.print(text.text, text.x, text.y)
    end
    
    -- Draw particle trails
    for _, trail in ipairs(self.particleTrails) do
        for _, particle in ipairs(trail.particles) do
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.alpha)
            love.graphics.circle("fill", particle.x, particle.y, 2)
        end
    end
end

function AnimationManager:getShakeOffset()
    return self.shakeOffset.x, self.shakeOffset.y
end

return AnimationManager