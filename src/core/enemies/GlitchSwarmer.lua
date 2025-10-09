-- src/core/enemies/GlitchSwarmer.lua
local Enemy = require "src.core.Enemy"
local EnemyAI_DB = require "src/core/ai/EnemyAI_DB"
local ParticleFX = require "src.core.effects.ParticleEffectsDB"

local GlitchSwarmer = {}
GlitchSwarmer.__index = GlitchSwarmer
setmetatable(GlitchSwarmer, {__index = Enemy})

-- Static variable for the class to track total swarmers
GlitchSwarmer.activeSwarmerCount = 0
GlitchSwarmer.maxTotalSwarmers = 10 -- Max swarmers allowed on the map at once

function GlitchSwarmer:new(x, y)
    local instance = Enemy:new(x, y, "GLITCH_SWARMER_SPRITE", _G.Config.activeColors.enemy, "SWARMER", 10, true, EnemyAI_DB.GlitchSwarmer) -- Purple-ish, 10 HP
    setmetatable(instance, GlitchSwarmer)

    instance.baseAttackPower = 2
    instance.visionRadius = 6 
    
    instance.dataFragmentsValue = love.math.random(1, 3)

    GlitchSwarmer.activeSwarmerCount = GlitchSwarmer.activeSwarmerCount + 1
    -- print("New GlitchSwarmer. Active count: " .. GlitchSwarmer.activeSwarmerCount)
    return instance
end

-- The complex act() and executePlannedAction() methods are now removed.
-- All AI logic is handled by the base Enemy:act() which uses the AI definition
-- from EnemyAI_DB. The specific execution for its abilities is also defined there.

function GlitchSwarmer:die()
    Enemy.die(self) -- Call parent for char change, data fragments, etc.
    GlitchSwarmer.activeSwarmerCount = GlitchSwarmer.activeSwarmerCount - 1
    -- print("Swarmer died. Active count: " .. GlitchSwarmer.activeSwarmerCount)
    -- Add any GlitchSwarmer-specific death effects, like a tiny visual glitch
    local gs = _G.Game.states:getCurrent()
    if gs and ParticleFX then
        ParticleFX.spawnFloatingText(gs, "~", self.x, self.y, {color=self.color, duration=0.3, vy=-5, font=_G.Fonts.large})
    end
end

-- Call this when the game or level ends to reset the static counter
function GlitchSwarmer.resetGlobalCount()
    GlitchSwarmer.activeSwarmerCount = 0
    print("GlitchSwarmer global count reset.")
end


return GlitchSwarmer