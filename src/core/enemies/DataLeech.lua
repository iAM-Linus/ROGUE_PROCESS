-- src/core/enemies/DataLeech.lua
local Enemy = require "src.core.Enemy" -- Inherit from Enemy
local Helpers = require "src.utils.helpers"
local ParticleFX = require "src.core.effects.ParticleEffectsDB"

local DataLeech = {}
DataLeech.__index = DataLeech
setmetatable(DataLeech, {__index = Enemy}) -- Inherit from Enemy

function DataLeech:new(x, y)
    local instance = Enemy:new(x, y, "DATA_LEECH_SPRITE", _G.Config.activeColors.enemy, "DATA_LEECH", 25) -- Magenta, 25 HP
    setmetatable(instance, DataLeech)

    -- visionRadius is inherited from Enemy (default 7), can override if needed
    -- instance.visionRadius = 6 
    instance.leechAmount = 5
    instance.leechAbilityCooldownTimer = 0 -- Renamed for clarity
    instance.maxLeechAbilityCooldown = 2
    
    instance.dataFragmentsValue = love.math.random(3, 10) -- Override default

    return instance
end

function DataLeech:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end

    if isPrecomputationPhase then
        self.plannedAction = nil -- Clear

        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
        else
            self:updateAiStateBasedOnPlayerVisibility(player, map, gameplayState) -- Use base method

            if self.aiState == "hunting" then
                local dx_p = player.x - self.x
                local dy_p = player.y - self.y

                if math.abs(dx_p) <= 1 and math.abs(dy_p) <= 1 and (dx_p ~= 0 or dy_p ~= 0) then -- Adjacent
                    if self.leechAbilityCooldownTimer <= 0 then
                        self.plannedAction = {type = "leech_cpu", targetEntity = player, amount = self.leechAmount, description = "LEECHING CPU"}
                    else
                        -- Cooldown active, maybe plan a weak melee attack or idle
                        -- For now, let's make it try to move away slightly if it can't leech, to reposition
                        local bestRetreatX, bestRetreatY = self.x, self.y; local movedSlightly = false
                        for i=1,4 do -- Try a few random moves
                            local rDx, rDy = love.math.random(-1,1), love.math.random(-1,1)
                            if rDx == 0 and rDy == 0 then goto next_leech_retreat_try end
                            local nX, nY = self.x + rDx, self.y + rDy
                            if not map:isBlocked(nX, nY, self) and (not map:getEntityAt(nX,nY) or map:getEntityAt(nX,nY) == player) then
                                bestRetreatX, bestRetreatY = nX, nY; movedSlightly = true; break
                            end
                            ::next_leech_retreat_try::
                        end
                        if movedSlightly then
                             self.plannedAction = {type = "move", targetPos = {x=bestRetreatX, y=bestRetreatY}, description = "REPOSITIONING"}
                        else
                            self.plannedAction = {type = "idle", description = "PULSING (CD)"}
                        end
                    end
                else -- Not adjacent, plan to move towards player
                    local moveX, moveY = 0,0; if dx_p~=0 then moveX=dx_p/math.abs(dx_p) end; if dy_p~=0 then moveY=dy_p/math.abs(dy_p) end
                    local plannedTargetX, plannedTargetY = self.x, self.y; local canPlanMove = false
                    local potentialMoves = {}; if moveX~=0 then table.insert(potentialMoves,{x=self.x+moveX,y=self.y}) end; if moveY~=0 then table.insert(potentialMoves,{x=self.x,y=self.y+moveY}) end; if moveX~=0 and moveY~=0 then table.insert(potentialMoves,{x=self.x+moveX,y=self.y+moveY}) end
                    for _,pos in ipairs(potentialMoves) do local entOnPos=map:getEntityAt(pos.x,pos.y); if not map:isBlocked(pos.x,pos.y,self) or (entOnPos==player) then if not entOnPos or entOnPos==player then plannedTargetX,plannedTargetY=pos.x,pos.y; canPlanMove=true; break end end end
                    if canPlanMove then self.plannedAction = {type="move",targetPos={x=plannedTargetX,y=plannedTargetY},description="SLITHERING to("..plannedTargetX..","..plannedTargetY..")"} else self.plannedAction={type="idle",description="BLOCKED(HUNT)"} end
                end
            elseif self.aiState == "patrolling" or self.aiState == "idle" then
                 -- Simple random move or idle for patrolling/idle DataLeech
                if love.math.random() < 0.3 then -- Less likely to move than Sentry
                    local rDx,rDy=love.math.random(-1,1),love.math.random(-1,1)
                    if rDx~=0 or rDy~=0 then local nX,nY=self.x+rDx,self.y+rDy; if not map:isBlocked(nX,nY,self) then self.plannedAction={type="move",targetPos={x=nX,y=nY},description="WANDERING"} else self.plannedAction={type="idle",description="IDLE_WANDER"} end else self.plannedAction={type="idle",description="IDLE_WANDER"} end
                else
                    self.plannedAction = {type = "idle", description = "IDLING"}
                end
            end
        end
        if not self.plannedAction then self.plannedAction = {type = "idle", description = "IDLE_LEECH"} end
    else -- Execution phase
        if self:processStatusEffectsStartTurn() then
             self.plannedAction = { type = "stunned", description = "STUNNED" }
             return Enemy.executePlannedAction(self, player, map, entities, gameplayState)
        end
        -- Tick leech cooldown BEFORE executing action for this turn
        if self.leechAbilityCooldownTimer > 0 then self.leechAbilityCooldownTimer = self.leechAbilityCooldownTimer - 1 end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false
end

function DataLeech:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    local action = self.plannedAction
    local gs = gameplayState
    local actionTaken = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), Config.activeColors.text)

    if action.type == "leech_cpu" then
        if action.targetEntity and action.targetEntity == player then
            player.cpuCycles = math.max(0, player.cpuCycles - action.amount)
            gs:logMessage(self.name .. " leeches " .. action.amount .. " CPU from " .. player.name .. "!", {1, 0.5, 1, 1})
            if ParticleFX then ParticleFX.spawnFloatingText(gs, "-"..action.amount.." CPU", player.x, player.y, {color={0.8,0.3,0.8,1}, vy=-25}) end
            self.leechAbilityCooldownTimer = self.maxLeechAbilityCooldown
        else
            gs:logMessage(self.name .. " leech target invalid.", Config.activeColors.text)
        end
        actionTaken = true
    elseif action.type == "move" then
        -- Standard move execution (can use SentryBot's bump logic or Enemy's base if simpler)
        local entityAtTarget = map:getEntityAt(action.targetPos.x, action.targetPos.y)
        if entityAtTarget and entityAtTarget == player then
            gs:logMessage(self.name .. " bumps " .. player.name .. "! (No attack)", Config.activeColors.enemy)
            actionTaken = true -- DataLeech doesn't bump attack, just gets blocked
        elseif map:isBlocked(action.targetPos.x, action.targetPos.y, self) then
            gs:logMessage(self.name .. " move to (" .. action.targetPos.x .. "," .. action.targetPos.y .. ") blocked.", Config.activeColors.text)
            actionTaken = true 
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
            gs:logMessage(self.name .. " " .. (action.description or "moves") .. ".", Config.activeColors.enemy)
            actionTaken = true
        end
    else
        -- Fallback to base Enemy execution for "idle", "stunned"
        actionTaken = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end
    
    return actionTaken
end

-- DataLeech:die() can be removed if Enemy:die() is sufficient.
-- function DataLeech:die()
--     Enemy.die(self)
-- end

return DataLeech