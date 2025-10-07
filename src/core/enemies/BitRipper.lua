-- src/core/enemies/BitRipper.lua
local Enemy = require "src.core.Enemy"
local Helpers = require "src.utils.helpers"
local ParticleFX = require "src.core.effects.ParticleEffectsDB"

local BitRipper = {}
BitRipper.__index = BitRipper
setmetatable(BitRipper, {__index = Enemy})

function BitRipper:new(x, y)
    local instance = Enemy:new(x, y, "BIT_RIPPER_SPRITE", _G.Config.activeColors.enemy, "BIT_RIPPER", 20, true) -- Moderate HP
    setmetatable(instance, BitRipper)

    instance.rangedAttackDamage = 7
    instance.attackRange = 6 -- Max range of its ranged attack
    instance.optimalRangeMin = 3 -- Tries to stay at least this far away
    instance.optimalRangeMax = instance.attackRange -1 -- Tries to stay within this range

    instance.attackCooldownTimer = 0
    instance.maxAttackCooldown = 1 -- Can attack almost every other turn if conditions met

    instance.phaseStepChance = 0.33 -- 33% chance to phase step after attacking
    instance.phaseStepRange = 3   -- How far it can teleport

    instance.aiState = "positioning" -- States: "positioning", "attacking", "repositioning"
    instance.dataFragmentsValue = love.math.random(8, 18)

    return instance
end

function BitRipper:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end

    if isPrecomputationPhase then
        self.plannedAction = nil

        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
        else
            -- BitRipper AI:
            -- 1. Can it attack the player from its current position?
            -- 2. If not, can it move to a position to attack?
            -- 3. If it can attack, or after moving to attack, consider phase stepping.

            local canSeePlayer = false
            local playerDist = -1
            local hasLOS = Helpers.hasLineOfSight(self.x, self.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end)

            if hasLOS then
                playerDist = Helpers.distanceEuclidean(self, player)
                if playerDist <= self.visionRadius then -- visionRadius inherited from Enemy
                    canSeePlayer = true
                end
            end

            if not canSeePlayer then
                self.aiState = "idle" -- Or "patrolling" if you implement that for it
                self.plannedAction = {type = "idle", description = "SCANNING"}
            else -- Player is visible
                if self.attackCooldownTimer <= 0 and playerDist <= self.attackRange then
                    -- Within attack range and cooldown ready: Plan attack
                    self.aiState = "attacking"
                    self.plannedAction = {
                        type = "ranged_attack",
                        targetEntity = player,
                        damage = self.rangedAttackDamage,
                        description = "FIRING SHARD (" .. self.rangedAttackDamage .. " DMG)"
                    }
                    -- Phase step will be decided *after* this attack in execute phase
                else
                    -- Not attacking (either on CD or out of range). Try to reposition.
                    self.aiState = "positioning"
                    local bestMoveX, bestMoveY = self.x, self.y
                    local bestMoveScore = -1 -- Lower is better (closer to optimal range, maintains LOS)

                    for dx = -1, 1 do for dy = -1, 1 do
                        if dx == 0 and dy == 0 then goto next_pos_check end
                        local nextX, nextY = self.x + dx, self.y + dy
                        
                        if not map:isBlocked(nextX, nextY, self) and (not map:getEntityAt(nextX, nextY) or map:getEntityAt(nextX,nextY) == player) then
                            if Helpers.hasLineOfSight(nextX, nextY, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                                local distToPlayerFromNext = Helpers.distanceEuclidean({x=nextX, y=nextY}, player)
                                local score = math.abs(distToPlayerFromNext - (self.optimalRangeMin + self.optimalRangeMax)/2) -- Try to get to middle of optimal range
                                
                                if distToPlayerFromNext > self.attackRange then score = score + 100 end -- Heavily penalize moving out of attack range
                                if distToPlayerFromNext < self.optimalRangeMin then score = score + 10 end -- Penalize being too close

                                if bestMoveScore == -1 or score < bestMoveScore then
                                    bestMoveScore = score
                                    bestMoveX, bestMoveY = nextX, nextY
                                end
                            end
                        end
                        ::next_pos_check::
                    end end

                    if bestMoveX ~= self.x or bestMoveY ~= self.y then
                        self.plannedAction = {type="move", targetPos={x=bestMoveX, y=bestMoveY}, description="REPOSITIONING"}
                    else
                        self.plannedAction = {type="idle", description = (self.attackCooldownTimer > 0 and "AIMING (CD)" or "AIMING")}
                    end
                end
            end
        end
        if not self.plannedAction then self.plannedAction = {type = "idle", description = "IDLE_RIPPER"} end
    else -- Execution phase
        if self:processStatusEffectsStartTurn() then
             self.plannedAction = { type = "stunned", description = "STUNNED" }
             return Enemy.executePlannedAction(self, player, map, entities, gameplayState)
        end
        if self.attackCooldownTimer > 0 then self.attackCooldownTimer = self.attackCooldownTimer - 1 end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false
end

function BitRipper:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    local action = self.plannedAction
    local gs = gameplayState
    local actionTaken = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), _G.Config.activeColors.text)

    if action.type == "ranged_attack" then
        if action.targetEntity and not action.targetEntity.isDead then
            gs:logMessage(self.name .. " fires a bit shard at " .. action.targetEntity.name .. "!", self.color)
            -- Particle for projectile
            if ParticleFX then ParticleFX.spawnLaserBeam(gs, self, action.targetEntity) end -- Re-use laser for now
            
            local logMsg = action.targetEntity:takeDamage(action.damage, self.name)
            gs:logMessage(logMsg, (action.targetEntity == player and _G.Config.activeColors.player or _G.Config.activeColors.enemy))
            if action.targetEntity.isDead then gs:logMessage(action.targetEntity.name .. " shattered!", _G.Config.activeColors.pickup) end
            
            self.attackCooldownTimer = self.maxAttackCooldown

            -- Chance to Phase Step after attacking
            if love.math.random() < self.phaseStepChance then
                local validPhaseTiles = {}
                for i = 1, 10 do -- Try a few times to find a spot
                    local rdx = love.math.random(-self.phaseStepRange, self.phaseStepRange)
                    local rdy = love.math.random(-self.phaseStepRange, self.phaseStepRange)
                    if rdx == 0 and rdy == 0 then goto next_phase_try end
                    
                    local newX, newY = self.x + rdx, self.y + rdy
                    if newX >= 1 and newX <= map.width and newY >= 1 and newY <= map.height then
                        if not map:isBlocked(newX, newY, self) and not map:getEntityAt(newX, newY) then
                           if Helpers.hasLineOfSight(newX, newY, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                                table.insert(validPhaseTiles, {x=newX, y=newY})
                           end
                        end
                    end
                    ::next_phase_try::
                end
                if #validPhaseTiles > 0 then
                    local phaseTo = Helpers.choice(validPhaseTiles)
                    gs:logMessage(self.name .. " phases to a new position!", self.color)
                    if ParticleFX then ParticleFX.spawnFloatingText(gs, ">>", self.x, self.y, {color=self.color, duration=0.3, vx= (phaseTo.x-self.x)*20, vy=(phaseTo.y-self.y)*20}) end
                    self.x = phaseTo.x
                    self.y = phaseTo.y
                    if ParticleFX then ParticleFX.spawnFloatingText(gs, "<<", self.x, self.y, {color=self.color, duration=0.3}) end
                end
            end
        else
            gs:logMessage(self.name .. " ranged attack target invalid.", _G.Config.activeColors.text)
        end
        actionTaken = true
    elseif action.type == "move" then
        -- Standard move execution (BitRipper doesn't bump-attack, it tries to maintain range)
        if map:isBlocked(action.targetPos.x, action.targetPos.y, self) or map:getEntityAt(action.targetPos.x, action.targetPos.y) then
            gs:logMessage(self.name .. " move to (" .. action.targetPos.x .. "," .. action.targetPos.y .. ") blocked.", _G.Config.activeColors.text)
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
        end
        actionTaken = true 
    else
        actionTaken = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end
    
    return actionTaken
end

-- die() method can be inherited from Enemy.

return BitRipper