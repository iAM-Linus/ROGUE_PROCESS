-- src/core/bosses/Boss.lua
local Helpers = require 'src.utils.Helpers'
local Enemy = require "src.core.Enemy"
local BossBehaviorDB = require "src.core.bosses.BossBehaviorDB"

local Boss = {}
Boss.__index = Boss
setmetatable(Boss, { __index = Enemy })

function Boss:new(x, y, char, color, name, hp, bossId)
    local instance = Enemy:new(x, y, char, color, name, hp, true) -- Bosses usually block movement
    setmetatable(instance, Boss)

    instance.isBoss = true
    instance.bossId = bossId
    instance.behavior = BossBehaviorDB.getForBoss(bossId)
    if not instance.behavior then
        error("No behavior found in BossBehaviorDB for bossId: " .. tostring(bossId))
    end

    instance.currentPhaseIndex = 0 -- Will be set to 1 initially
    instance.currentPhase = nil
    instance.abilityCooldowns = {} -- Store cooldowns for abilities: { ["ability_id"] = timer }

    self:_enterPhase(instance, 1)  -- Enter the first phase

    return instance
end

-- Method to transition to a new phase
function Boss:_enterPhase(bossInstance, phaseIndex)
    if not bossInstance.behavior.phases[phaseIndex] then
        print("Warning: Boss " .. bossInstance.name .. " tried to enter invalid phase index: " .. phaseIndex)
        return
    end

    bossInstance.currentPhaseIndex = phaseIndex
    bossInstance.currentPhase = bossInstance.behavior.phases[phaseIndex]
    print(bossInstance.name .. " entering phase: " .. bossInstance.currentPhase.name)

    -- Get current gameplay state and log entry message
    local stateManager = ServiceLocator.get("states")
    local gameplayState = stateManager:getCurrent()
    
    if gameplayState and gameplayState.logMessage and bossInstance.currentPhase.entryMessage then
        gameplayState:logMessage(bossInstance.currentPhase.entryMessage, bossInstance.color)
    end

    -- Reset cooldowns for abilities in this new phase (or manage them globally)
    for _, abilityDef in ipairs(bossInstance.currentPhase.abilities) do
        bossInstance.abilityCooldowns[abilityDef.id] = 0
    end
end

-- Boss's main AI logic
function Boss:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then
        self.plannedAction = nil
        return false
    end

    if isPrecomputationPhase then
        self.plannedAction = nil 
        local gs = gameplayState -- for logging convenience
        gs:logMessage(string.format("[BossAct %s] Phase: %s.", self.name, self.currentPhase.name), self.color)

        -- Check for phase transitions based on HP
        local hpPercent = self.hp / self.maxHp
        for phaseIdx, phaseDef in ipairs(self.behavior.phases) do
            if phaseIdx > self.currentPhaseIndex and phaseDef.triggerCondition then
                if phaseDef.triggerCondition(self, player, map, gameplayState) then
                    self:_enterPhase(self, phaseIdx)
                    gs:logMessage(string.format("  %s transitioned to Phase %d!", self.name, phaseIdx), self.color)
                    break
                end
            end
        end

        -- Try to use an available ability
        local usableAbilities = {}
        for _, abilityDef in ipairs(self.currentPhase.abilities) do
            local cd = self.abilityCooldowns[abilityDef.id] or 0
            if cd == 0 then
                if not abilityDef.canUse or abilityDef.canUse(self, player, map, gameplayState) then
                    table.insert(usableAbilities, abilityDef)
                end
            end
        end

        if #usableAbilities > 0 then
            -- Choose ability (could be by priority, random, etc.)
            local chosenAbilityDef = usableAbilities[love.math.random(#usableAbilities)]
            
            -- Plan the action
            if chosenAbilityDef.plan then
                self.plannedAction = chosenAbilityDef.plan(self, player, map, gameplayState)
                if self.plannedAction then
                    self.plannedAction.abilityId = chosenAbilityDef.id
                    self.plannedAction.abilityMaxCooldown = chosenAbilityDef.cooldown or 0
                    gs:logMessage(string.format("  Plan: Ability -> %s", chosenAbilityDef.id), self.color)
                end
            end
        end
        
        if not self.plannedAction then 
            gs:logMessage(string.format("  No ability planned. Trying movementPattern."), self.color)
            if self.currentPhase.movementPattern then
                local moveTarget = self.currentPhase.movementPattern(self, player, map)
                if moveTarget then
                    self.plannedAction = {type="move", targetPos=moveTarget, description="TACTICAL MOVE"}
                    gs:logMessage(string.format("  Plan: Movement -> TACTICAL MOVE to (%d,%d)", moveTarget.x, moveTarget.y), self.color)
                else
                    gs:logMessage(string.format("  MovementPattern returned nil."), self.color)
                end
            else
                gs:logMessage(string.format("  No movementPattern for this phase."), self.color)
            end
        end
        
        if not self.plannedAction then
            self.plannedAction = {type="idle", description="CALCULATING..."}
            gs:logMessage(string.format("  Plan: Default -> CALCULATING..."), self.color)
        end
    else -- Execution Phase
        if self:processStatusEffectsStartTurn() then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
            return Enemy.executePlannedAction(self, player, map, entities, gameplayState)  -- Use base for stun
        end

        -- Tick ability cooldowns (those not used this turn)
        for id, timer in pairs(self.abilityCooldowns) do
            if self.plannedAction and self.plannedAction.abilityId == id then
                -- This ability is about to be used, its cooldown will be set by execute
            elseif timer > 0 then
                self.abilityCooldowns[id] = timer - 1
            end
        end
        return self:executePlannedAction(player, map, entities, gameplayState)
    end
    return false
end

function Boss:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end
    
    local config = ServiceLocator.get("config")
    local action = self.plannedAction
    local gs = gameplayState
    local actionExecuted = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type),
        config.activeColors.text)

    -- Find the ability definition to get the execute function
    local abilityDefToExecute = nil
    if action.abilityId then
        for _, phaseAbility in ipairs(self.currentPhase.abilities) do
            if phaseAbility.id == action.abilityId then
                abilityDefToExecute = phaseAbility
                break
            end
        end
    end

    if abilityDefToExecute and abilityDefToExecute.execute then
        actionExecuted = abilityDefToExecute.execute(self, player, map, entities, gameplayState, action)
        if actionExecuted and action.abilityMaxCooldown then
            self.abilityCooldowns[action.abilityId] = action.abilityMaxCooldown
        end
    elseif action.type == "move" then
        -- Handle generic move if not part of a specific ability's execute
        if map:isBlocked(action.targetPos.x, action.targetPos.y, self) or map:getEntityAt(action.targetPos.x, action.targetPos.y) then
            gs:logMessage(self.name .. " move to (" .. action.targetPos.x .. "," .. action.targetPos.y .. ") blocked.",
                config.activeColors.text)
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
        end
        actionExecuted = true
    else
        -- Fallback to base Enemy execution for "idle", "stunned", etc.
        actionExecuted = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end

    self.plannedAction = nil
    return actionExecuted
end

return Boss