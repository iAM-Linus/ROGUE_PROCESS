-- src/core/enemies/Boss.lua (A base class for all Bosses)
local Helpers = require 'src.utils.Helpers'
local Enemy = require "src.core.Enemy"
local BossBehaviorDB = require "src.core.bosses.BossBehaviorDB" -- If behaviors are stored separately

local Boss = {}
Boss.__index = Boss
setmetatable(Boss, { __index = Enemy })

function Boss:new(x, y, char, color, name, hp, bossId)            -- bossId links to BossBehaviorDB
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

    local gs = _G.GameState.current()
    if gs and gs.logMessage and bossInstance.currentPhase.entryMessage then
        gs:logMessage(bossInstance.currentPhase.entryMessage, bossInstance.color)
    end

    -- Reset cooldowns for abilities in this new phase (or manage them globally)
    for _, abilityDef in ipairs(bossInstance.currentPhase.abilities) do
        bossInstance.abilityCooldowns[abilityDef.id] = 0
    end
end

-- Boss's main AI logic
function Boss:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then
        self.plannedAction = nil; return false
    end

    if isPrecomputationPhase then
        self.plannedAction = nil 
        local gs = gameplayState -- for logging convenience
        gs:logMessage(string.format("[BossAct %s] Phase: %s. HP: %d/%d", self.name, self.currentPhase.name, self.hp, self.maxHp), self.color)

        -- Check for phase transition based on HP
        local currentHpRatio = self.hp / self.maxHp
        for i = #self.behavior.phases, 1, -1 do -- Check from highest threshold phase downwards
            local phaseDef = self.behavior.phases[i]
            if currentHpRatio <= phaseDef.healthThreshold and i > self.currentPhaseIndex then
                self:_enterPhase(self, i) -- 'self' is correct here as it's an instance method call
                break                     -- Transitioned to the highest possible new phase
            end
        end

        if self:hasStatusEffect("stun") then
            self.plannedAction = { type = "stunned", description = "STUNNED" }
            gs:logMessage(string.format("  Plan: STUNNED"), self.color)
        else
            local availableAbilities = {}
            if self.currentPhase and self.currentPhase.abilities then
                for _, abilityDef in ipairs(self.currentPhase.abilities) do
                    local cd = self.abilityCooldowns[abilityDef.id] or 0
                    gs:logMessage(string.format("  Ability Check: %s, CD: %d", abilityDef.id, cd), self.color)
                    if cd <= 0 then
                        table.insert(availableAbilities, abilityDef)
                    end
                end
            end
            gs:logMessage(string.format("  #Available Abilities (off CD): %d", #availableAbilities), self.color)

            if #availableAbilities > 0 then
                local chosenAbilityDef = Helpers.weightedChoice(availableAbilities) 
                if not chosenAbilityDef then chosenAbilityDef = Helpers.choice(availableAbilities) end 
                gs:logMessage(string.format("  Chosen Ability (weighted): %s", chosenAbilityDef and chosenAbilityDef.id or "None"), self.color)

                if chosenAbilityDef and chosenAbilityDef.plan then
                    self.plannedAction = chosenAbilityDef.plan(self, player, map, entities, gameplayState)
                    if self.plannedAction then 
                        self.plannedAction.abilityId = chosenAbilityDef.id 
                        self.plannedAction.abilityMaxCooldown = chosenAbilityDef.maxCooldown
                        gs:logMessage(string.format("  Plan: Ability %s -> %s", chosenAbilityDef.id, self.plannedAction.description), self.color)
                    else
                        gs:logMessage(string.format("  Ability %s plan() returned nil.", chosenAbilityDef.id), self.color)
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
    local action = self.plannedAction
    local gs = gameplayState
    local actionExecuted = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type),
        Config.activeColors.text)

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
                Config.activeColors.text)
        else
            self:move(action.targetPos.x - self.x, action.targetPos.y - self.y)
        end
        actionExecuted = true
    else
        -- Fallback to base Enemy execution for "idle", "stunned", etc.
        actionExecuted = Enemy.executePlannedAction(self, player, map, entities, gameplayState)
    end

    return actionExecuted
end

-- die() method can be inherited from Enemy.
-- If boss has specific on-death sequence (e.g. final attack, multiple stages), override it.

return Boss
