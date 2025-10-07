-- src/core/enemies/CipherSentinel.lua
local Enemy = require "src.core.Enemy"
local Helpers = require "src.utils.helpers"
local ParticleFX = require "src.core.effects.ParticleEffectsDB"

local CipherSentinel = {}
CipherSentinel.__index = CipherSentinel
setmetatable(CipherSentinel, {__index = Enemy})

function CipherSentinel:new(x, y)
    -- Bluish/Cyan color, high HP, blocks movement
    local instance = Enemy:new(x, y, "CIPHER_SENTINEL_SPRITE", _G.Config.activeColors.enemy, "CIPHER_SENTINEL", 75, true) 
    setmetatable(instance, CipherSentinel)

    instance.baseAttackPower = 6
    instance.visionRadius = 5 -- Shorter vision, more defensive
    instance.aiState = "guarding" -- States: "guarding", "attacking"

    instance.encryptAbilityCooldownTimer = 0
    instance.maxEncryptAbilityCooldown = 4 -- Cooldown for encrypt ability
    instance.encryptRange = 3           -- Range to find an ally to encrypt
    instance.encryptShieldAmount = 15
    instance.encryptShieldDuration = 3
    
    instance.dataFragmentsValue = love.math.random(15, 30) -- Drops more fragments

    return instance
end

function CipherSentinel:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end
    
    if isPrecomputationPhase then
        self.plannedAction = nil

        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
        else
            -- Cipher Sentinel doesn't use the standard hunt/patrol/flee from base Enemy:updateAiState...
            -- Its state is simpler: if player is close, attack. Otherwise, try to encrypt an ally.
            
            local canSeePlayer = false
            local playerDist = -1
            if Helpers.hasLineOfSight(self.x, self.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                playerDist = Helpers.distanceEuclidean({x=self.x, y=self.y}, {x=player.x, y=player.y})
                if playerDist <= self.visionRadius then
                    canSeePlayer = true
                end
            end

            if canSeePlayer and playerDist <= 1.5 then -- Player is adjacent
                self.aiState = "attacking"
                self.plannedAction = { type = "attack", targetEntity = player, damage = self.baseAttackPower, description = "ATTACK (" .. self.baseAttackPower .. ")"}
            else
                self.aiState = "guarding"
                -- Try to use Encrypt Ally ability if cooldown is ready
                if self.encryptAbilityCooldownTimer <= 0 then
                    local allyToEncrypt = nil
                    local closestAllyDist = self.encryptRange + 1
                    
                    for _, entity in ipairs(entities) do
                        if entity.isEnemy and entity ~= self and not entity.isDead and not entity:hasStatusEffect("shield") then
                            local distToAlly = Helpers.distanceEuclidean(self, entity)
                            if distToAlly <= self.encryptRange and distToAlly < closestAllyDist then
                                if Helpers.hasLineOfSight(self.x, self.y, entity.x, entity.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                                    allyToEncrypt = entity
                                    closestAllyDist = distToAlly
                                end
                            end
                        end
                    end

                    if allyToEncrypt then
                        self.plannedAction = {
                            type = "encrypt_ally", 
                            targetEntity = allyToEncrypt,
                            shieldAmount = self.encryptShieldAmount,
                            shieldDuration = self.encryptShieldDuration,
                            description = "ENCRYPTING " .. allyToEncrypt.name
                        }
                    else
                        -- No ally to encrypt, or player is close but not adjacent.
                        -- If player is visible but not adjacent, move towards them slowly.
                        if canSeePlayer then
                            local dx_p = player.x - self.x; local dy_p = player.y - self.y
                            local moveX, moveY = 0,0
                            if math.abs(dx_p) > 0 then moveX = dx_p / math.abs(dx_p) end
                            if math.abs(dy_p) > 0 then moveY = dy_p / math.abs(dy_p) end
                            
                            -- Prefer to move only one step if possible
                            local plannedTargetX, plannedTargetY = self.x, self.y
                            local canPlanMove = false
                            if moveX ~= 0 and not map:isBlocked(self.x + moveX, self.y, self) and (not map:getEntityAt(self.x+moveX, self.y) or map:getEntityAt(self.x+moveX, self.y) == player) then
                                plannedTargetX = self.x + moveX; canPlanMove = true;
                            elseif moveY ~= 0 and not map:isBlocked(self.x, self.y + moveY, self) and (not map:getEntityAt(self.x, self.y+moveY) or map:getEntityAt(self.x, self.y+moveY) == player) then
                                plannedTargetY = self.y + moveY; canPlanMove = true;
                            end
                            if canPlanMove and (plannedTargetX ~= self.x or plannedTargetY ~= self.y) then
                                self.plannedAction = {type="move",targetPos={x=plannedTargetX,y=plannedTargetY},description="ADVANCING to("..plannedTargetX..","..plannedTargetY..")"}
                            else
                                self.plannedAction = {type = "idle", description = "GUARDING"}
                            end
                        else
                             self.plannedAction = {type = "idle", description = "GUARDING"}
                        end
                    end
                else
                    -- Encrypt on cooldown, just guard or move if player is visible but not adjacent
                     if canSeePlayer then
                        local dx_p = player.x - self.x; local dy_p = player.y - self.y
                        local moveX, moveY = 0,0; if math.abs(dx_p)>0 then moveX=dx_p/math.abs(dx_p) end; if math.abs(dy_p)>0 then moveY=dy_p/math.abs(dy_p) end
                        local plannedTargetX, plannedTargetY = self.x, self.y; local canPlanMove = false
                        if moveX~=0 and not map:isBlocked(self.x+moveX,self.y,self) and (not map:getEntityAt(self.x+moveX,self.y) or map:getEntityAt(self.x+moveX,self.y)==player) then plannedTargetX=self.x+moveX; canPlanMove=true;
                        elseif moveY~=0 and not map:isBlocked(self.x,self.y+moveY,self) and (not map:getEntityAt(self.x,self.y+moveY) or map:getEntityAt(self.x,self.y+moveY)==player) then plannedTargetY=self.y+moveY; canPlanMove=true; end
                        if canPlanMove and (plannedTargetX ~= self.x or plannedTargetY ~= self.y) then self.plannedAction={type="move",targetPos={x=plannedTargetX,y=plannedTargetY},description="ADVANCING to("..plannedTargetX..","..plannedTargetY..")"}
                        else self.plannedAction={type="idle",description="GUARDING (CD)"} end
                    else
                        self.plannedAction = {type = "idle", description = "GUARDING (CD)"}
                    end
                end
            end
        end
        if not self.plannedAction then self.plannedAction = {type = "idle", description = "IDLE_CIPHER"} end
    else -- Execution phase
        if self:processStatusEffectsStartTurn() then
             self.plannedAction = { type = "stunned", description = "STUNNED" }
             return Enemy.executePlannedAction(self, player, map, entities, gameplayState)
        end
        if self.encryptAbilityCooldownTimer > 0 then self.encryptAbilityCooldownTimer = self.encryptAbilityCooldownTimer - 1 end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false
end

function CipherSentinel:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    local action = self.plannedAction
    local gs = gameplayState
    local actionTaken = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), _G.Config.activeColors.text)

    if action.type == "attack" then
        if action.targetEntity and not action.targetEntity.isDead then
            local logMsg = action.targetEntity:takeDamage(action.damage, self.name)
            gs:logMessage(logMsg, (action.targetEntity == player and _G.Config.activeColors.player or _G.Config.activeColors.enemy))
            if ParticleFX then ParticleFX.spawnHitSparks(gs, action.targetEntity.x, action.targetEntity.y, 3, self.color) end
        end
        actionTaken = true
    elseif action.type == "encrypt_ally" then
        if action.targetEntity and not action.targetEntity.isDead then
            local shieldEffect = {
                id = "shield", name = "Encryption Shield",
                duration = action.shieldDuration,
                data = { amount = action.shieldAmount }
            }
            action.targetEntity:addStatusEffect(shieldEffect)
            gs:logMessage(self.name .. " encrypts " .. action.targetEntity.name .. ", granting a shield!", self.color)
            if ParticleFX then ParticleFX.spawnFloatingText(gs, "SHIELD+", action.targetEntity.x, action.targetEntity.y, {color=self.color, vy=-15, duration=0.8}) end
            self.encryptAbilityCooldownTimer = self.maxEncryptAbilityCooldown
        else
            gs:logMessage(self.name .. " encryption target invalid.", _G.Config.activeColors.text)
        end
        actionTaken = true
    elseif action.type == "move" then
        -- Standard move execution (can use SentryBot's bump logic or Enemy's base if simpler)
        local entityAtTarget = map:getEntityAt(action.targetPos.x, action.targetPos.y)
        if entityAtTarget and entityAtTarget == player then
            gs:logMessage(self.name .. " bumps " .. player.name .. "! Attacking.", self.color)
            local logMsg = player:takeDamage(self.baseAttackPower, self.name)
            gs:logMessage(logMsg, _G.Config.activeColors.player)
            actionTaken = true
        elseif map:isBlocked(action.targetPos.x, action.targetPos.y, self) then
            gs:logMessage(self.name .. " move to (" .. action.targetPos.x .. "," .. action.targetPos.y .. ") blocked.", _G.Config.activeColors.text)
            actionTaken = true 
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
            actionTaken = true
        end
    else
        actionTaken = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end
    
    return actionTaken
end

-- die() method can be inherited from Enemy if default data fragment drop is sufficient.

return CipherSentinel