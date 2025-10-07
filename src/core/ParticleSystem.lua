-- src/core/ParticleSystem.lua (Revised addParticle and draw)
local Helpers = require 'src.utils.Helpers'

local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem

function ParticleSystem:new()
    local instance = setmetatable({}, ParticleSystem)
    instance.particles = {}
    return instance
end

-- spec.gridX, spec.gridY: initial position in map grid coordinates
-- spec.offsetX, spec.offsetY: pixel offset from the tile's center (optional)
function ParticleSystem:addParticle(spec)
    local initialPixelX = (spec.gridX - 1) * _G.Config.spriteSize + (_G.Config.spriteSize / 2) + (spec.offsetX or 0)
    local initialPixelY = (spec.gridY - 1) * _G.Config.spriteSize + (_G.Config.spriteSize / 2) + (spec.offsetY or 0)

    local p = {
        worldX = initialPixelX, -- Current world pixel X
        worldY = initialPixelY, -- Current world pixel Y
        text = spec.text or "*",
        color = spec.color and Helpers.deepCopy(spec.color) or {1,1,1,1}, -- Deep copy color
        font = spec.font or _G.Fonts.small,
        duration = spec.duration or 1,
        vx = spec.vx or 0,
        vy = spec.vy or 0,
        ax = spec.ax or 0,
        ay = spec.ay or 0,
        fadeRate = spec.fadeRate or 1,
        initialAlpha = (spec.color and spec.color[4]) or 1,
        life = 0
    }
    table.insert(self.particles, p)
end

function ParticleSystem:update(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.life = p.life + dt

        if p.life >= p.duration then
            table.remove(self.particles, i)
        else
            p.worldX = p.worldX + p.vx * dt
            p.worldY = p.worldY + p.vy * dt
            p.vx = p.vx + p.ax * dt
            p.vy = p.vy + p.ay * dt

            if p.fadeRate > 0 then
                local fadeProgress = math.min(1, (p.life / p.duration) * p.fadeRate)
                p.color[4] = p.initialAlpha * (1 - fadeProgress)
            end
        end
    end
end

-- Draws particles. mapOffsetX/Y are the camera's top-left world coordinates.
function ParticleSystem:draw(mapOffsetX, mapOffsetY) -- Removed tileSize, not needed if worldX/Y are pixels
    for _, p in ipairs(self.particles) do
        love.graphics.setFont(p.font)
        love.graphics.setColor(p.color)
        
        -- Particle worldX, worldY are already in world pixel coordinates
        -- mapOffsetX, mapOffsetY is the negative of camera's world position for drawing
        -- So, screenX = p.worldX + mapOffsetX (if mapOffsetX is e.g. -camera.x)
        local screenX = p.worldX + mapOffsetX
        local screenY = p.worldY + mapOffsetY
        
        love.graphics.print(p.text, math.floor(screenX), math.floor(screenY))
    end
end

return ParticleSystem