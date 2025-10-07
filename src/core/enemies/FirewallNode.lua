-- src/core/enemies/FirewallNode.lua
local Enemy = require "src.core.Enemy" -- Inherit from Enemy
local Helpers = require "src.utils.helpers"
local ParticleFX = require "src.core.effects.ParticleEffectsDB" -- For effects

local FirewallNode = {}
FirewallNode.__index = FirewallNode
setmetatable(FirewallNode, {__index = Enemy}) -- Inherit from Enemy

function FirewallNode:new(x, y)
    -- Call Enemy constructor. Firewall Node doesn't block player movement.
    local instance = Enemy:new(x, y, "FIREWALL_NODE_SPRITE", _G.Config.activeColors.enemy, "FIREWALL_NODE", 50, false)
    setmetatable(instance, FirewallNode)

    instance.pulseDamage = 8
    instance.pulseRange = 5
    instance.pulseCooldownTimer = 0 -- Renamed from pulseCooldown for clarity (counts down)
    instance.maxPulseCooldown = 4   -- Pulses every 4 turns
    instance.pulseDirection = love.math.random(1, 4) -- 1:Up, 2:Right, 3:Down, 4:Left
    
    instance.dataFragmentsValue = love.math.random(10, 25) -- Override default from Enemy

    return instance
end

-- Override 'act' for precomputation of planned action
function FirewallNode:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end
    
    if isPrecomputationPhase then
        self.plannedAction = nil -- Clear previous plan

        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
        elseif self.pulseCooldownTimer > 0 then
            self.plannedAction = {type = "charging", currentCooldown = self.pulseCooldownTimer, description = "CHARGING (" .. self.pulseCooldownTimer .. ")"}
        else
            local targetDir = self.pulseDirection 
            local canSeePlayer = false
            if Helpers.hasLineOfSight(self.x, self.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                local dx = player.x - self.x; local dy = player.y - self.y
                if math.abs(dx) > math.abs(dy) then targetDir = (dx > 0) and 2 or 4
                else targetDir = (dy > 0) and 3 or 1 end
                canSeePlayer = true
            end
            
            self.plannedAction = {
                type = "pulse",
                direction = targetDir,
                range = self.pulseRange,
                damage = self.pulseDamage,
                description = "PULSING " .. (canSeePlayer and "at Player" or ("dir." .. targetDir))
            }
        end
    else -- Execution phase
        -- Stun check for execution phase
        if self:processStatusEffectsStartTurn() then
             self.plannedAction = { type = "stunned", description = "STUNNED" }
             return Enemy.executePlannedAction(self, player, map, entities, gameplayState)
        end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false -- For precomputation, signal no turn taken yet
end

-- Override 'executePlannedAction' for FirewallNode's specific actions
function FirewallNode:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    local action = self.plannedAction
    local gs = gameplayState

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), _G.Config.activeColors.text)

    if action.type == "pulse" then
        local dx, dy = 0, 0
        if action.direction == 1 then dy = -1 elseif action.direction == 2 then dx = 1 
        elseif action.direction == 3 then dy = 1 else dx = -1 end

        for i = 1, action.range do
            local targetX, targetY = self.x + dx * i, self.y + dy * i
            if not map:isTransparent(targetX, targetY) then break end 
            
            -- Particle for pulse travel (optional)
            if ParticleFX then ParticleFX.spawnFloatingText(gs, ".", targetX, targetY, {color={1,0.6,0,0.7}, duration=0.2, vy=0, vx=0, font=_G.Fonts.large}) end

            local entityOnTile = map:getEntityAt(targetX, targetY)
            if entityOnTile and not entityOnTile.isDead and not entityOnTile.isPickup then
                if ParticleFX then ParticleFX.spawnHitSparks(gs, targetX, targetY, 3, {1.0,0.6,0.0,1}) end
                local logMsg = entityOnTile:takeDamage(action.damage, self.name)
                gs:logMessage(logMsg, _G.Config.activeColors.enemy)
                if entityOnTile.isDead then gs:logMessage(entityOnTile.name .. " purged by firewall.", _G.Config.activeColors.pickup) end
                break 
            end
        end
        self.pulseCooldownTimer = self.maxPulseCooldown -- Reset cooldown
        self.pulseDirection = (action.direction % 4) + 1 -- Next pulse will rotate
    elseif action.type == "charging" then
        self.pulseCooldownTimer = self.pulseCooldownTimer - 1
        gs:logMessage(self.name .. " " .. action.description .. " -> now " .. self.pulseCooldownTimer, _G.Config.activeColors.text)
    elseif action.type == "stunned" then
        gs:logMessage(self.name .. " is " .. action.description, _G.Config.activeColors.text)
    else
        -- Fallback to base Enemy execution for unknown types (like "idle" if it somehow gets here)
        return Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end
    return true -- All actions consume a turn
end

-- FirewallNode:die() can be removed if Enemy:die() is sufficient.
-- The base Enemy:die() already handles dropping self.dataFragmentsValue.
-- function FirewallNode:die()
--     Enemy.die(self) -- Call parent's die method
--     -- Add any FirewallNode-specific death effects here, if any
-- end

return FirewallNode