-- src/core/effects/ParticleEffectsDB.lua
local Helpers = require "src.utils.helpers" -- If needed for random choices, etc.
local config = ServiceLocator.get("config")
local fonts = ServiceLocator.get("fonts")
-- It's better if the functions return specs, and the ParticleSystem or GameplayState applies the actual font object.

local ParticleEffectsDB = {}

-- Effect functions take parameters (like start/end points, entity, damage amount)
-- and call gameplayState.particleSystem:addParticle() or return a table of particle specs.
-- For better decoupling, let them return a table of particle specs,
-- and a central function in GameplayState can then add them.
-- OR, they can directly call gameplayState.particleSystem.addParticle if gameplayState is passed.
-- Let's try passing gameplayState for direct addition.

---
-- Spawns floating text (e.g., damage numbers, status messages)
-- @param gs GameplayState instance (must have .particleSystem)
-- @param text The text to display
-- @param gridX, gridY The map grid coordinates for the effect's origin
-- @param options Table of optional overrides for particle spec (color, font, duration, vy, etc.)
function ParticleEffectsDB.spawnFloatingText(gs, text, gridX, gridY, options)
    if not gs or not gs.particleSystem then return end
    options = options or {}

    local spec = {
        gridX = gridX,
        gridY = gridY,
        text = text,
        color = options.color or {1, 1, 0.5, 1}, -- Default: Yellowish
        font = options.font or fonts.medium,   -- Requires fonts to be loaded
        duration = options.duration or 0.8,
        offsetX = options.offsetX or love.math.random(-config.spriteSize/4, config.spriteSize/4),
        offsetY = options.offsetY or -config.spriteSize / 2,
        vx = options.vx or 0,
        vy = options.vy or -30, -- Moves upwards
        ax = options.ax or 0,
        ay = options.ay or 60,  -- Gravity/Deceleration
        fadeRate = options.fadeRate or 1.2
    }
    gs.particleSystem:addParticle(spec)
end

---
-- Spawns a generic "hit spark" effect
-- @param gs GameplayState instance
-- @param gridX, gridY Origin grid coordinates
-- @param numParticles Number of spark particles
-- @param baseColor Base color for sparks
function ParticleEffectsDB.spawnHitSparks(gs, gridX, gridY, numParticles, baseColor)
    if not gs or not gs.particleSystem then return end
    numParticles = numParticles or love.math.random(3, 5)
    baseColor = baseColor or {1, 1, 0.5, 1} -- Yellowish

    for _ = 1, numParticles do
        gs.particleSystem:addParticle({
            gridX = gridX, gridY = gridY,
            offsetX = love.math.random(-config.spriteSize/4, config.spriteSize/4),
            offsetY = love.math.random(-config.spriteSize/4, config.spriteSize/4),
            text = Helpers.choice({"*", ".", "`"}),
            color = {baseColor[1]*math.random(0.7,1), baseColor[2]*math.random(0.7,1), baseColor[3]*math.random(0.5,1), 1},
            font = fonts.small,
            duration = love.math.random(0.3, 0.6),
            vx = love.math.random(-60, 60),
            vy = love.math.random(-60, 60),
            ay = 80, -- Gravity
            fadeRate = 1.5
        })
    end
end

---
-- Spawns a "death explosion" of characters
-- @param gs GameplayState instance
-- @param entity The entity that died (for its position)
function ParticleEffectsDB.spawnDeathExplosion(gs, entity)
    if not gs or not gs.particleSystem then return end
    local deathChars = {"%", "#", "*", "@", "X", "!", ";", ":"}
    for _ = 1, love.math.random(8, 15) do
        gs.particleSystem:addParticle({
            gridX = entity.x, gridY = entity.y,
            offsetX = love.math.random(-config.spriteSize/3, config.spriteSize/3),
            offsetY = love.math.random(-config.spriteSize/3, config.spriteSize/3),
            text = Helpers.choice(deathChars),
            color = {math.random(0.5,1), math.random(0.5,1), math.random(0.5,1), 1}, -- Random bright-ish color
            font = fonts.medium,
            duration = love.math.random(0.6, 1.3),
            vx = love.math.random(-70, 70),
            vy = love.math.random(-80, 40), -- Tend to fly up more
            ax = 0, ay = 100, -- Gravity
            fadeRate = 1
        })
    end
end

---
-- Spawns a laser beam effect from caster to target
-- @param gs GameplayState instance
-- @param caster Entity casting the laser
-- @param target Target entity or {x,y} target position
function ParticleEffectsDB.spawnLaserBeam(gs, caster, target)
    if not gs or not gs.particleSystem then return end

    local dist = Helpers.distanceEuclidean({x=caster.x, y=caster.y}, {x=target.x, y=target.y}) -- Euclidean for smoother line
    local steps = math.max(3, math.floor(dist * 3)) -- Number of particles along the beam, at least 3
    local particleChar = "*"
    local particleColor = {0.8, 1, 0.8, 1} -- Bright green/white

    for i = 0, steps do
        local t = i / steps -- Interpolation factor
        local pGridX = caster.x + (target.x - caster.x) * t
        local pGridY = caster.y + (target.y - caster.y) * t
        
        gs.particleSystem:addParticle({
            gridX = pGridX, gridY = pGridY, -- Particle system handles conversion to pixel world coords
            text = particleChar,
            color = particleColor,
            font = fonts.small,
            duration = 0.15 + t * 0.1, -- Particles appear sequentially and last briefly
            vx = 0, vy = 0,      -- Stationary once placed
            fadeRate = 2.5       -- Fade out quickly
        })
    end
end

---
-- Spawns an Area of Effect pulse (e.g., for Overclock Pulse)
-- @param gs GameplayState instance
-- @param centerX, centerY Grid coordinates for the center of the pulse
-- @param radius The radius of the pulse in tiles
-- @param particleChar Character to use for pulse particles
-- @param color Color of the particles
function ParticleEffectsDB.spawnAoEPulse(gs, centerX, centerY, radius, particleChar, color)
    if not gs or not gs.particleSystem then return end
    particleChar = particleChar or "░" -- Block character
    color = color or {1, 0.5, 0, 0.8} -- Orange-ish

    for r = 1, radius do -- Spawn rings outwards
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then -- Only on the perimeter of this ring
                    local px, py = centerX + dx, centerY + dy
                    gs.particleSystem:addParticle({
                        gridX = px, gridY = py,
                        text = particleChar,
                        color = Helpers.deepCopy(color),
                        font = fonts.medium,
                        duration = 0.3 + r * 0.1, -- Outer rings last a bit longer/appear later
                        vx = 0, vy = 0,
                        fadeRate = 1.5,
                        -- To make them expand:
                        -- vx = dx * (Config.tileSize / (0.3 + r*0.1)) / 2, -- Move outwards
                        -- vy = dy * (Config.tileSize / (0.3 + r*0.1)) / 2,
                    })
                end
            end
        end
    end
end


return ParticleEffectsDB