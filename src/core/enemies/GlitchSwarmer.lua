-- src/core/enemies/GlitchSwarmer.lua
local Enemy = require "src.core.Enemy"
local Helpers = require "src.utils.helpers"
local ParticleFX = require "src.core.effects.ParticleEffectsDB"

local GlitchSwarmer = {}
GlitchSwarmer.__index = GlitchSwarmer
setmetatable(GlitchSwarmer, {__index = Enemy})

-- Static variable for the class to track total swarmers
GlitchSwarmer.activeSwarmerCount = 0
GlitchSwarmer.maxTotalSwarmers = 10 -- Max swarmers allowed on the map at once

function GlitchSwarmer:new(x, y)
    local instance = Enemy:new(x, y, "GLITCH_SWARMER_SPRITE", _G.Config.activeColors.enemy, "SWARMER", 10) -- Purple-ish, 10 HP
    setmetatable(instance, GlitchSwarmer)

    instance.baseAttackPower = 2
    instance.visionRadius = 6 
    instance.aiState = "swarming" -- Default state

    instance.replicateCooldownTimer = love.math.random(3, 5) -- Turns until can try to replicate
    instance.maxReplicateCooldown = love.math.random(5, 8)
    
    instance.dataFragmentsValue = love.math.random(1, 3)

    GlitchSwarmer.activeSwarmerCount = GlitchSwarmer.activeSwarmerCount + 1
    -- print("New GlitchSwarmer. Active count: " .. GlitchSwarmer.activeSwarmerCount)
    return instance
end

function GlitchSwarmer:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end
    
    if isPrecomputationPhase then
        self.plannedAction = nil

        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
        else
            self:updateAiStateBasedOnPlayerVisibility(player, map, gameplayState) -- Sets hunting/patrolling/idle

            if self.replicateCooldownTimer > 0 and self.aiState ~= "fleeing" then -- Don't try to replicate if fleeing
                -- Not ready to replicate yet, prioritize moving/attacking
            elseif GlitchSwarmer.activeSwarmerCount < GlitchSwarmer.maxTotalSwarmers and self.aiState ~= "fleeing" then
                -- Try to replicate if cooldown is up and not too many swarmers
                local emptyAdjacent = {}
                for dx = -1, 1 do for dy = -1, 1 do
                    if dx == 0 and dy == 0 then goto next_rep_tile end
                    local checkX, checkY = self.x + dx, self.y + dy
                    if map:isWalkable(checkX, checkY) and not map:getEntityAt(checkX, checkY) then
                        table.insert(emptyAdjacent, {x = checkX, y = checkY})
                    end
                    ::next_rep_tile::
                end end
                if #emptyAdjacent > 0 then
                    local spawnPos = Helpers.choice(emptyAdjacent)
                    self.plannedAction = {type = "replicate", targetPos = spawnPos, description = "REPLICATING"}
                    goto end_plan_swarmer -- Prioritize replication
                end
            end
            ::end_plan_swarmer::

            if not self.plannedAction then -- If not replicating, do normal actions
                if self.aiState == "hunting" then
                    local dx_p = player.x - self.x; local dy_p = player.y - self.y
                    if math.abs(dx_p) <= 1 and math.abs(dy_p) <= 1 and (dx_p ~= 0 or dy_p ~= 0) then
                        self.plannedAction = { type = "attack", targetEntity = player, damage = self.baseAttackPower, description = "ATTACK (" .. self.baseAttackPower .. ")"}
                    else
                        local moveX, moveY = 0,0; if dx_p~=0 then moveX=dx_p/math.abs(dx_p) end; if dy_p~=0 then moveY=dy_p/math.abs(dy_p) end
                        local plannedTargetX, plannedTargetY = self.x, self.y; local canPlanMove = false
                        local potentialMoves = {}; if moveX~=0 then table.insert(potentialMoves,{x=self.x+moveX,y=self.y}) end; if moveY~=0 then table.insert(potentialMoves,{x=self.x,y=self.y+moveY}) end; if moveX~=0 and moveY~=0 then table.insert(potentialMoves,{x=self.x+moveX,y=self.y+moveY}) end
                        for _,pos in ipairs(potentialMoves) do local entOnPos=map:getEntityAt(pos.x,pos.y); if not map:isBlocked(pos.x,pos.y,self) or (entOnPos==player) then if not entOnPos or entOnPos==player then plannedTargetX,plannedTargetY=pos.x,pos.y; canPlanMove=true; break end end end
                        if canPlanMove then self.plannedAction = {type="move",targetPos={x=plannedTargetX,y=plannedTargetY},description="SWARMING to("..plannedTargetX..","..plannedTargetY..")"} else self.plannedAction={type="idle",description="BLOCKED(HUNT)"} end
                    end
                elseif self.aiState == "patrolling" or self.aiState == "idle" or self.aiState == "swarming" then
                    -- More erratic movement for swarmers
                    if love.math.random() < 0.7 then -- Higher chance to move
                        local rDx,rDy=love.math.random(-1,1),love.math.random(-1,1)
                        if rDx~=0 or rDy~=0 then local nX,nY=self.x+rDx,self.y+rDy; if not map:isBlocked(nX,nY,self) and not map:getEntityAt(nX,nY) then self.plannedAction={type="move",targetPos={x=nX,y=nY},description="DRIFTING"} else self.plannedAction={type="idle",description="IDLE_DRIFT"} end else self.plannedAction={type="idle",description="IDLE_DRIFT"} end
                    else
                        self.plannedAction = {type = "idle", description = "IDLING"}
                    end
                end
            end
        end
        if not self.plannedAction then self.plannedAction = {type = "idle", description = "IDLE_SWARM"} end
    else -- Execution phase
        if self:processStatusEffectsStartTurn() then
             self.plannedAction = { type = "stunned", description = "STUNNED" }
             return Enemy.executePlannedAction(self, player, map, entities, gameplayState)
        end
        if self.replicateCooldownTimer > 0 then self.replicateCooldownTimer = self.replicateCooldownTimer - 1 end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false
end

function GlitchSwarmer:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    local action = self.plannedAction
    local gs = gameplayState
    local actionTaken = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), _G.Config.activeColors.text)

    if action.type == "attack" then
        if action.targetEntity and not action.targetEntity.isDead then
            local logMsg = action.targetEntity:takeDamage(action.damage, self.name)
            gs:logMessage(logMsg, (action.targetEntity == player and _G.Config.activeColors.player or _G.Config.activeColors.enemy))
            if ParticleFX then ParticleFX.spawnHitSparks(gs, action.targetEntity.x, action.targetEntity.y, 1, self.color) end
        end
        actionTaken = true
    elseif action.type == "move" then
        local entityAtTarget = map:getEntityAt(action.targetPos.x, action.targetPos.y)
        if entityAtTarget and entityAtTarget == player then
            gs:logMessage(self.name .. " swarms " .. player.name .. "! Attacking.", self.color)
            local logMsg = player:takeDamage(self.baseAttackPower, self.name)
            gs:logMessage(logMsg, _G.Config.activeColors.player)
            actionTaken = true
        elseif map:isBlocked(action.targetPos.x, action.targetPos.y, self) then
            gs:logMessage(self.name .. " path blocked.", _G.Config.activeColors.text)
            actionTaken = true 
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
            actionTaken = true
        end
    elseif action.type == "replicate" then
        -- Request GameplayState to spawn a new swarmer
        local success, newSwarmerName = gs:requestSpawnEnemy(GlitchSwarmer, action.targetPos.x, action.targetPos.y, "REP")
        if success then
            gs:logMessage(self.name .. " replicates! New: " .. newSwarmerName, self.color)
            if ParticleFX then ParticleFX.spawnFloatingText(gs, "++", action.targetPos.x, action.targetPos.y, {color=self.color, duration=0.5, vy=-10}) end
            self.replicateCooldownTimer = self.maxReplicateCooldown
        else
            gs:logMessage(self.name .. " replication failed (no space/cap reached).", _G.Config.activeColors.text)
            -- If replication fails, swarmer essentially idles this turn
        end
        actionTaken = true
    else
        actionTaken = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end
    
    return actionTaken
end

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