-- src/core/SystemCorruption.lua
local Helpers = require "src.utils.helpers"
local Config = _G.Config -- Assuming Config is global for access to colors, etc.
-- ParticleFX will be passed in or accessed via GameplayState instance

local SystemCorruption = {}
SystemCorruption.__index = SystemCorruption

function SystemCorruption:new(gameplayState)
    local instance = setmetatable({}, SystemCorruption)
    instance.gs = gameplayState -- Store a reference to GameplayState for callbacks (like logging, accessing map/player)
    
    instance.level = 0         -- Current corruption level (0 to max)
    instance.maxLevel = 100    -- Max corruption before major effects
    
    -- Configurable rates (could also be passed in or read from Config directly)
    instance.corruptionPerKill = gameplayState.corruptionPerKill or 2
    instance.corruptionPerPowerfulSub = gameplayState.corruptionPerPowerfulSub or 5

    -- Visual Glitch Effect
    instance.glitchEffectTimer = 0
    instance.glitchEffectInterval = 0.1 
    instance.maxVisualGlitches = 10    
    instance.activeVisualGlitches = {} -- Stores {x, y, char, color, life, duration}

    -- Threshold effect tracking (for later expansion)
    -- instance.thresholdsTriggered = { low = false, medium = false, high = false }
    
    print("SystemCorruption module initialized.")
    return instance
end

function SystemCorruption:resetForNewNode()
    self.level = 0
    self.activeVisualGlitches = {}
    -- self.thresholdsTriggered = { low = false, medium = false, high = false }
    print("SystemCorruption: Reset for new node. Level:", self.level)
end

function SystemCorruption:add(amount)
    local oldLevel = self.level
    self.level = math.min(self.maxLevel, self.level + amount)
    if self.level > oldLevel then -- Log only if it actually increased
        print("SystemCorruption: Level increased by " .. amount .. ". Total: " .. self.level)
        if self.gs and self.gs.logMessage then -- Log to game console if possible
            -- self.gs:logMessage("System instability rising...", {1, 0.5, 0, 0.7}) -- Subtle warning
        end
        -- self:checkThresholds() -- For later expansion
    end
end

function SystemCorruption:getCorruptionPercent()
    return math.floor((self.level / self.maxLevel) * 100)
end

function SystemCorruption:update(dt)
    -- Visual Glitch Spawning
    if self.level > 10 then -- Only start glitching above a certain threshold
        self.glitchEffectTimer = self.glitchEffectTimer + dt
        if self.glitchEffectTimer >= self.glitchEffectInterval then
            self.glitchEffectTimer = 0
            if #self.activeVisualGlitches < self.maxVisualGlitches and self.gs and self.gs.map then
                local chanceToGlitch = self.level / self.maxLevel 
                if love.math.random() < chanceToGlitch * 0.3 then -- Modulate chance
                    local randomX, randomY = self.gs.map:getRandomFloorTileForEffect()
                    if randomX and self.gs.map:isInFov(randomX, randomY) then
                        table.insert(self.activeVisualGlitches, {
                            x = randomX, y = randomY,
                            char = Helpers.choice({"#", "%", "?", "!", "$", "&", "~", ":"}),
                            color = {math.random(), math.random(), math.random(), 1},
                            life = 0,
                            duration = love.math.random(0.2, 0.5) 
                        })
                    end
                end
            end
        end
    end

    -- Update active visual glitches
    for i = #self.activeVisualGlitches, 1, -1 do
        local glitch = self.activeVisualGlitches[i]
        glitch.life = glitch.life + dt
        if glitch.life >= glitch.duration then
            table.remove(self.activeVisualGlitches, i)
        end
    end
end

-- Drawing visual glitches is best handled by GameplayState or Map,
-- as they have camera offsets and tile sizes readily available.
-- This module will just hold the data for activeVisualGlitches.
function SystemCorruption:getActiveVisualGlitches()
    return self.activeVisualGlitches
end

-- Placeholder for more complex effects later
-- function SystemCorruption:checkThresholds()
--     if self.level >= self.maxLevel * 0.75 and not self.thresholdsTriggered.high then
--         self.gs:logMessage("CRITICAL SYSTEM INSTABILITY DETECTED!", {1,0,0,1})
--         self.thresholdsTriggered.high = true
--         -- Trigger a major anomaly via GameplayState
--         -- self.gs:triggerSystemAnomaly("major_corruption_event")
--     elseif self.level >= self.maxLevel * 0.4 and not self.thresholdsTriggered.medium then
--         self.gs:logMessage("System integrity failing...", {1,0.5,0,1})
--         self.thresholdsTriggered.medium = true
--         -- self.gs:triggerSystemAnomaly("minor_corruption_event")
--     end
-- end

return SystemCorruption