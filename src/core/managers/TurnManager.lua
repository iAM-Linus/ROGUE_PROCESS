-- src/core/TurnManager.lua
local TurnManager = {}
TurnManager.__index = TurnManager

function TurnManager:new(player)
    local instance = setmetatable({}, TurnManager)
    instance.player = player
    instance.entities = {} -- All entities that take turns (player + enemies)
    instance.currentActorIndex = 0 -- Start with the player (assuming player is first)
    instance.isPlayerTurn = true
    return instance
end

function TurnManager:setEntities(newEntitiesList)
    local oldCurrentActor = self:getCurrentActor() -- Get actor BEFORE changing self.entities list

    self.entities = newEntitiesList -- Update the list with the one from GameplayState

    if #self.entities == 0 then
        self.currentActorIndex = 0
        self.isPlayerTurn = false
        print("TurnManager:setEntities - No entities left.")
        return
    end

    local newActorIndexForOld = -1 -- Will store the new index of the oldCurrentActor, if found
    if oldCurrentActor then
        for i, entity in ipairs(self.entities) do
            if entity == oldCurrentActor then
                newActorIndexForOld = i -- Found the old current actor in the new list
                break
            end
        end
    end

    if newActorIndexForOld ~= -1 then
        -- The previous current actor is still in the list (or was re-added).
        -- Keep their turn by setting currentActorIndex to their new index.
        self.currentActorIndex = newActorIndexForOld
    else
        -- The previous current actor was removed (e.g., died), or this is an initial setup.
        -- Default to the first entity in the updated list.
        self.currentActorIndex = 1
    end
    
    -- Boundary checks for currentActorIndex
    if #self.entities > 0 then -- Only if there are entities
        if self.currentActorIndex > #self.entities or self.currentActorIndex < 1 then
            self.currentActorIndex = 1 -- Wrap around or fix if index became invalid
        end
    else -- List became empty
        self.currentActorIndex = 0
    end

    local currentActorAfterSync = self:getCurrentActor()
    if currentActorAfterSync then
        self.isPlayerTurn = (currentActorAfterSync == self.player)
        if self.isPlayerTurn and self.player then -- Ensure player object exists
            self.player.actionTaken = false -- Reset action flag if it's now player's turn
        end
        -- This log is crucial for debugging this specific issue:
        -- print("TurnManager:setEntities - Synced. Current actor: " .. currentActorAfterSync.name ..
        --      " (Index: " .. self.currentActorIndex .. "). Player turn: " .. tostring(self.isPlayerTurn))
    else
        self.isPlayerTurn = false
        -- print("TurnManager:setEntities - Synced. No current actor. Player turn: false")
    end
end

function TurnManager:getEntities()
    return self.entities
end

function TurnManager:getCurrentActor()
    if #self.entities == 0 or self.currentActorIndex > #self.entities then
        return nil
    end
    return self.entities[self.currentActorIndex]
end

function TurnManager:nextTurn()
    if #self.entities == 0 then
        self.isPlayerTurn = false
        -- print("TurnManager: No entities left to take a turn.")
        return
    end

    local actor = self:getCurrentActor() -- Re-fetch, might have changed if list modified
    -- print("TurnManager:nextTurn() - Actor ending turn: " .. (actorEndingTurn and actorEndingTurn.name or "N/A") ..
    --       " (Index: " .. self.currentActorIndex .. ")")
    
    if actor and not actor.isDead then
        -- Process end-of-turn status effects (DoT, duration ticks) for the actor whose turn just ended
        actor:processStatusEffectsEndTurn(_G.Game.states:getCurrent()) -- Pass gameplay state for logging

        -- If the actor is the player, also handle player-specific end-of-turn stuff
        if actor == self.player then
            self.player:endTurnUpdate() -- Handles cooldowns, CPU regen
        end
        -- Add similar enemy-specific end-of-turn updates here if needed later
    end

    -- Advance turn index
    self.currentActorIndex = self.currentActorIndex + 1
    if self.currentActorIndex > #self.entities then
        self.currentActorIndex = 1
    end

    -- Determine next actor and player turn status
    local nextActor = self:getCurrentActor()
    local enemyDelay = false
    if nextActor then
        self.isPlayerTurn = (nextActor == self.player)
        if self.isPlayerTurn then
            if self.player then self.player.actionTaken = false end   
        end
        -- print("TurnManager:nextTurn() - Next actor to act: " .. nextActor.name ..
        --      " (Index: " .. self.currentActorIndex .. "). Player turn: " .. tostring(self.isPlayerTurn))
    else
        -- print("Warning: No next actor found in TurnManager:nextTurn(). Entity count: " .. #self.entities)
        self.isPlayerTurn = false
    end
end

return TurnManager