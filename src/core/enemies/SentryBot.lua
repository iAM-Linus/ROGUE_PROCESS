-- src/core/enemies/SentryBot.lua
local Enemy = require "src.core.Enemy" -- CHANGE THIS from Entity
local Helpers = require "src.utils.helpers"

local SentryBot = {}
SentryBot.__index = SentryBot
setmetatable(SentryBot, {__index = Enemy}) -- INHERIT FROM ENEMY

function SentryBot:new(x, y)
    -- Call the Enemy constructor, which in turn calls Entity constructor
    local instance = Enemy:new(x, y, "SENTRY_BOT_SPRITE", _G.Config.activeColors.enemy, "SENTRY_BOT", 30)
    setmetatable(instance, SentryBot) -- Set metatable to SentryBot for its specific methods

    instance.baseAttackPower = 5
    -- visionRadius is inherited from Enemy, but can be overridden:
    -- instance.visionRadius = 10 
    instance.fleeThreshold = instance.maxHp * 0.3 -- Specific to SentryBot's fleeing logic
    
    -- dataFragmentsValue is inherited from Enemy, but can be overridden:
    instance.dataFragmentsValue = love.math.random(5, 15) 
    
    return instance
end

-- SentryBot's 'act' method will now primarily define its unique logic for each AI state
-- It can call self:updateAiStateBasedOnPlayerVisibility(player, map, gameplayState) from the base Enemy class
function SentryBot:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end
    
    if isPrecomputationPhase then
        self.plannedAction = nil -- Clear previous plan
        
        -- Handle stun at the start of precomputation for planning
        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
            -- Don't return yet, let executePlannedAction handle the "turn consumed by stun"
        else
            -- Call base enemy logic to update aiState (patrolling, hunting, fleeing)
            self:updateAiStateBasedOnPlayerVisibility(player, map, gameplayState)

            -- === SentryBot Specific Action Planning Based on Updated State ===
            if self.aiState == "fleeing" then
                -- Plan to move AWAY from player (copied from your previous SentryBot logic)
                local bestFleeX, bestFleeY = self.x, self.y; local maxDistToPlayer = -1
                for dx = -1, 1 do for dy = -1, 1 do
                    if dx == 0 and dy == 0 then goto continue_flee_check end
                    local nextX, nextY = self.x + dx, self.y + dy
                    if not map:isBlocked(nextX, nextY, self) then
                        local dist = Helpers.distanceEuclidean({x=nextX, y=nextY}, {x=player.x, y=player.y})
                        if dist > maxDistToPlayer then maxDistToPlayer = dist; bestFleeX, bestFleeY = nextX, nextY end
                    end
                    ::continue_flee_check::
                end end
                if bestFleeX ~= self.x or bestFleeY ~= self.y then
                    self.plannedAction = {type = "move", targetPos = {x=bestFleeX, y=bestFleeY}, description = "FLEEING"}
                else
                    self.plannedAction = {type = "idle", description = "TRAPPED (FLEE)"}
                end
            elseif self.aiState == "hunting" then
                local dx_p = player.x - self.x; local dy_p = player.y - self.y
                if math.abs(dx_p) <= 1 and math.abs(dy_p) <= 1 and (dx_p ~= 0 or dy_p ~= 0) then
                    self.plannedAction = { type = "attack", targetEntity = player, targetPos = {x=player.x, y=player.y}, damage = self.baseAttackPower, description = "ATTACK (" .. self.baseAttackPower .. ")"}
                else
                    local moveX, moveY = 0,0; if dx_p~=0 then moveX=dx_p/math.abs(dx_p) end; if dy_p~=0 then moveY=dy_p/math.abs(dy_p) end
                    local plannedTargetX, plannedTargetY = self.x, self.y; local canPlanMove = false
                    local potentialMoves = {}; if moveX~=0 then table.insert(potentialMoves,{x=self.x+moveX,y=self.y}) end; if moveY~=0 then table.insert(potentialMoves,{x=self.x,y=self.y+moveY}) end; if moveX~=0 and moveY~=0 then table.insert(potentialMoves,{x=self.x+moveX,y=self.y+moveY}) end
                    for _,pos in ipairs(potentialMoves) do local entOnPos=map:getEntityAt(pos.x,pos.y); if not map:isBlocked(pos.x,pos.y,self) or (entOnPos==player) then if not entOnPos or entOnPos==player then plannedTargetX,plannedTargetY=pos.x,pos.y; canPlanMove=true; break end end end
                    if canPlanMove then self.plannedAction = {type="move",targetPos={x=plannedTargetX,y=plannedTargetY},description="HUNT to("..plannedTargetX..","..plannedTargetY..")"} else self.plannedAction={type="idle",description="BLOCKED(HUNT)"} end
                end
            elseif self.aiState == "patrolling" then
                if love.math.random() < 0.5 then
                    local rDx,rDy=love.math.random(-1,1),love.math.random(-1,1)
                    if rDx~=0 or rDy~=0 then local nX,nY=self.x+rDx,self.y+rDy; if not map:isBlocked(nX,nY,self) then self.plannedAction={type="move",targetPos={x=nX,y=nY},description="PATROL"} else self.plannedAction={type="idle",description="PATROL_IDLE"} end else self.plannedAction={type="idle",description="PATROL_IDLE"} end
                else self.plannedAction={type="idle",description="PATROL_SCAN"} end
            end
        end
        if not self.plannedAction then self.plannedAction = {type = "idle", description = "IDLE_SENTRY"} end

    else -- Not precomputation phase, so execute
        -- Stun check for execution phase
        if self:processStatusEffectsStartTurn() then
            self.plannedAction = { type = "stunned", description = "STUNNED" } -- Ensure plan reflects stun
            -- Execute the "stunned" plan (which just logs and consumes turn)
            return Enemy.executePlannedAction(self, player, map, entities, gameplayState) -- Call base execute
        end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false -- For precomputation
end

-- SentryBot can inherit executePlannedAction from Enemy if its planned actions
-- ("attack", "move", "idle", "stunned") are handled sufficiently by the base.
-- Or it can override it for more specific execution details.
-- For now, let's assume it might need its own for the bump-attack logic.

function SentryBot:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    local action = self.plannedAction
    local gs = gameplayState
    local actionTaken = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), _G.Config.activeColors.text)

    if action.type == "attack" then
        if action.targetEntity and not action.targetEntity.isDead then
            local logMsg = action.targetEntity:takeDamage(action.damage, self.name)
            gs:logMessage(logMsg, (action.targetEntity == player and _G.Config.activeColors.player or _G.Config.activeColors.enemy))
            gs:logMessage(self.name .. " attacks " .. action.targetEntity.name .. "!", _G.Config.activeColors.enemy)
            if action.targetEntity.isDead then gs:logMessage(action.targetEntity.name .. " destroyed!", _G.Config.activeColors.pickup) end
        else
            gs:logMessage(self.name .. " attack target invalid.", _G.Config.activeColors.text)
        end
        actionTaken = true
    elseif action.type == "move" then
        local entityAtTarget = map:getEntityAt(action.targetPos.x, action.targetPos.y)
        if entityAtTarget and entityAtTarget == player then
            gs:logMessage(self.name .. " bumps " .. player.name .. "! Attacking.", _G.Config.activeColors.enemy)
            local logMsg = player:takeDamage(self.baseAttackPower, self.name)
            gs:logMessage(logMsg, _G.Config.activeColors.player)
            if player.isDead then gs:logMessage(player.name .. " terminated!", {1,0,0,1}) end
            actionTaken = true
        elseif map:isBlocked(action.targetPos.x, action.targetPos.y, self) then
            gs:logMessage(self.name .. " move to (" .. action.targetPos.x .. "," .. action.targetPos.y .. ") blocked.", _G.Config.activeColors.text)
            actionTaken = true 
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
            gs:logMessage(self.name .. " moves to (" .. action.targetPos.x .. "," .. action.targetPos.y .. ").", _G.Config.activeColors.enemy)
            actionTaken = true
        end
    else
        -- Let base Enemy handle "idle", "stunned", etc.
        actionTaken = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end
    
    return actionTaken
end


-- SentryBot:die() can be removed if the base Enemy:die() (which drops dataFragmentsValue) is sufficient.
-- If SentryBot has unique death behavior beyond that, override it and call Enemy.die(self)
-- function SentryBot:die()
--     Enemy.die(self) -- Call parent's die method
--     -- Add any SentryBot-specific death effects here
-- end

return SentryBot