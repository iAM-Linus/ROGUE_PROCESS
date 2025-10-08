-- src/core/Enemy.lua
local Entity = require "src.core.Entity"
local Helpers = require "src.utils.helpers" -- For things like LOS if generalized

local Enemy = {}
Enemy.__index = Enemy
setmetatable(Enemy, {__index = Entity}) -- Inherit from Entity

-- Constructor for the base Enemy
-- char, color, name, hp are specific to the enemy type
-- blocksMovement is usually true for enemies
function Enemy:new(x, y, char_or_quadName, color_tint, name, hp, blocksMovementOverride)
    -- Call the Entity constructor
    -- blocksMovementOverride defaults to true if not provided by specific enemy
    local instance = Entity:new(x, y, char_or_quadName, color_tint, name, blocksMovementOverride ~= nil and blocksMovementOverride or true, hp)
    setmetatable(instance, Enemy) -- Set metatable to Enemy for Enemy-specific methods

    instance.isEnemy = true -- Flag to easily identify enemies
    instance.playerTarget = nil -- Will be set by GameplayState or when player is detected
    instance.aiState = "idle" -- Common states: "idle", "patrolling", "hunting", "fleeing", "attacking"
    
    instance.visionRadius = 7 -- Default vision radius, can be overridden by specific enemies
    instance.dataFragmentsValue = love.math.random(3, 8) -- Default data fragments dropped on death

    -- plannedAction is already in Entity.lua from our intent system, so no need to re-declare
    -- instance.plannedAction = nil 

    return instance
end

-- Common method to update the AI state based on player visibility
-- This can be called by specific enemy 'act' methods
function Enemy:updateAiStateBasedOnPlayerVisibility(player, map, gameplayState)
    local canSeePlayer = false
    if Helpers.hasLineOfSight(self.x, self.y, player.x, player.y, function(lx, ly) return not map:isTransparent(lx, ly) end) then
        local dist = Helpers.distanceEuclidean({x=self.x, y=self.y}, {x=player.x, y=player.y}) -- Using Euclidean for radius
        if dist <= self.visionRadius then
            canSeePlayer = true
        end
    end

    if self.aiState == "fleeing" then
        -- If fleeing, only stop if HP is high enough AND player is not visible or far away
        if self.hp > (self.fleeThreshold or self.maxHp * 0.3) * 1.5 then
            if not canSeePlayer or (canSeePlayer and Helpers.distanceEuclidean({x=self.x, y=self.y}, {x=player.x, y=player.y}) > self.visionRadius * 1.2) then
                self.aiState = "idle" -- Or patrolling
                gameplayState:logMessage(self.name .. " calms down.", _G.Config.activeColors.text)
            end
        end
        -- Otherwise, continue fleeing if possible
    elseif canSeePlayer then
        if self.aiState ~= "hunting" then
            gameplayState:logMessage(self.name .. " spots " .. player.name .. "!", _G.Config.activeColors.enemy)
        end
        self.aiState = "hunting"
        self.playerTarget = player -- Keep track of the player
    elseif self.aiState == "hunting" then -- Was hunting but lost sight
        gameplayState:logMessage(self.name .. " lost sight of " .. player.name .. ".", _G.Config.activeColors.text)
        self.aiState = "patrolling" -- Or "idle"
        self.playerTarget = nil
    end
    -- If idle and can't see player, remains idle or could switch to patrolling
end


-- Base 'act' method for precomputation. Specific enemies will override this
-- to define their unique behaviors and planned actions.
function Enemy:act(player, map, entities, gameplayState, isPrecomputationPhase)
    if self.isDead then self.plannedAction = nil; return false end
    
    if isPrecomputationPhase then
        self.plannedAction = nil -- Clear previous plan
        -- Common pre-turn logic for enemies
        self:updateAiStateBasedOnPlayerVisibility(player, map, gameplayState)
        
        -- Default planned action if not overridden by specific enemy AI
        if not self.plannedAction then
            self.plannedAction = {type = "idle", description = string.upper(self.aiState)}
        end
    else
        -- If not precomputation, this base 'act' shouldn't be called directly.
        -- Instead, 'executePlannedAction' should be called.
        -- However, if it IS called, it means the enemy type didn't implement executePlannedAction.
        print("Warning: Base Enemy:act called for execution phase for " .. self.name .. ". Should use executePlannedAction.")
        if self.executePlannedAction then
            return self:executePlannedAction(player, map, entities, gameplayState)
        end
    end
    return false -- For precomputation, signal no turn taken yet
end

-- Base 'executePlannedAction'. Specific enemies can override or extend this.
function Enemy:executePlannedAction(player, map, entities, gameplayState)
    if not self.plannedAction or self.isDead then return false end

    local action = self.plannedAction
    local gs = gameplayState
    local actionTaken = false

    gs:logMessage(string.format("%s executing: %s", self.name, action.description or action.type), _G.Config.activeColors.text)

    if action.type == "idle" or action.type == "stunned" or action.type == "charging" then
        gs:logMessage(self.name .. " " .. (action.description or action.type) .. ".", _G.Config.activeColors.text)
        actionTaken = true
    else
        gs:logMessage(self.name .. " has an unhandled planned action type: " .. action.type, {1,0,0,1})
        actionTaken = true -- Consume turn even if unhandled
    end
    
    -- self.plannedAction = nil -- Clear after execution (optional, depends on if UI needs it for one more frame)
    return actionTaken
end


-- Override Entity's die method to add common enemy death behaviors (like dropping fragments)
function Enemy:die()
    if self.isDead then return end -- Prevent multiple calls
    Entity.die(self) -- Call base Entity die method (sets char, color, isDead flag etc.)

    -- Common enemy death behavior: drop data fragments
    local gameplay = _G.Game.states:getCurrent() -- Assuming current state is GameplayState
    if gameplay and gameplay.player then -- Check if player exists
        gameplay.player.dataFragments = gameplay.player.dataFragments + (self.dataFragmentsValue or 0)
        if (self.dataFragmentsValue or 0) > 0 then
            gameplay:logMessage(self.name .. " drops " .. (self.dataFragmentsValue or 0) .. " DATA_FRAGMENTS.", _G.Config.activeColors.pickup)
        end
    end
    -- Specific enemies can further override this to add unique drops or effects on death
end

return Enemy