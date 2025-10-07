-- src/core/Player.lua
local Entity = require "src.core.Entity"
local SubroutineInstance = require 'src.core.SubroutineInstance'
local CoreModificationDB = require 'src.core.CoreModificationDB'
local AICoreDB = require 'src.core.AICoreDB'

local Player = {}
Player.__index = Player
setmetatable(Player, {__index = Entity}) -- Inherit from Entity

function Player:new(x, y, aiCoreData)
    if not aiCoreData then
        print("ERROR: Player:new() called without aiCoreData. Using fallback.")
        aiCoreData = AICoreDB.getById(_G.SelectedAICoreId or "standard_pid") -- Fallback
        if not aiCoreData then aiCoreData = AICoreDB.Cores.standard_pid end -- Absolute fallback
    end

    local quadName = aiCoreData.quadName or "PLAYER_STANDARD"
    local char = aiCoreData.char or _G.Config.playerChar
    local color = aiCoreData.color or _G.Config.activeColors.player
    local name = aiCoreData.name or "PID_PLAYER_UNKNOWN"
    local initialHp = aiCoreData.baseStats.hp
    
    local instance = Entity:new(x, y, quadName, aiCoreData.color, name, true, initialHp)
    setmetatable(instance, Player)

    instance.coreId = aiCoreData.id -- Store which core this player is

    -- Apply base stats from the core
    instance.hp = aiCoreData.baseStats.hp
    instance.maxHp = aiCoreData.baseStats.hp
    instance.cpuCycles = aiCoreData.baseStats.cpu
    instance.maxCPUCycles = aiCoreData.baseStats.cpu
    instance.cpuRegenRate = aiCoreData.baseStats.cpuRegen
    instance.baseAttackPower = aiCoreData.baseStats.attack or 10 -- Default if not specified

    instance.dataFragments = 0
    instance.actionTaken = false
    instance.subroutines = {}
    instance.maxSubroutines = 4
    instance.coreModifications = {} 
    instance.coreModificationFlags = {} 

    -- Grant starting subroutine
    if aiCoreData.startingSubroutineId then
        instance:learnSubroutine(aiCoreData.startingSubroutineId)
        -- Ensure the learned subroutine doesn't immediately put player in negative CPU if it has a cost
        -- (This is usually not an issue as learning is free, using it costs)
    end

    -- Apply passive perk if any
    if aiCoreData.passivePerk and aiCoreData.passivePerk.apply then
        aiCoreData.passivePerk.apply(instance)
        -- Log the perk application if GameplayState is available (tricky from here)
        -- This might be better handled in GameplayState:initNewLevel after player is created
    end
    
    print(string.format("Player created with AI Core: %s. HP:%d, CPU:%d, Sub:%s", 
        aiCoreData.name, instance.maxHp, instance.maxCPUCycles, aiCoreData.startingSubroutineId or "None"))

    return instance
end

--function Player:draw(tileX, tileY, tileSize)
--    local gameplayState = _G.GameState.current() -- Get current gameplay state for context
--
--    -- Default drawing behavior from Entity
--    -- Entity.draw(self, tileX, tileY, tileSize) -- This would draw the original character and color
--
--    -- Player-specific visual modifications
--    local r, g, b, a = self.color[1], self.color[2], self.color[3], self.color[4] or 1
--    local charToDraw = self.char
--    local fontToUse = _G.Fonts.medium -- Default entity font
--
--    if gameplayState and gameplayState.turnManager and gameplayState.turnManager.isPlayerTurn and 
--       self.actionTaken == false and not gameplayState.isEnemyActionResolving and
--       gameplayState.currentMode == gameplayState.Mode.PLAYER_TURN then
--        -- It's player's turn, player hasn't acted, and game is awaiting player input
--        
--        -- Subtle brightness pulse for the player character's color
--        local pulseBrightness = (math.sin(love.timer.getTime() * 6) + 1) / 2 -- Oscillates 0 to 1
--        local brightnessBoost = 0.3 -- How much brighter it gets
--        
--        -- Apply boost mainly to green component for a typical player color
--        g = math.min(1, g + pulseBrightness * brightnessBoost)
--        -- You could also make r and b slightly brighter too if desired
--        r = math.min(1, r + pulseBrightness * brightnessBoost * 0.5)
--        b = math.min(1, b + pulseBrightness * brightnessBoost * 0.5)
--
--        -- Example: Blinking player character (alternative to color pulse)
--        -- if not _G.showBlinker then -- Assuming _G.showBlinker is your global blink flag
--        --     return -- Don't draw the player character if blinker is off
--        -- end
--    end
--
--    love.graphics.setColor(r, g, b, a)
--    love.graphics.setFont(fontToUse)
--    love.graphics.print(charToDraw, 
--                        tileX + tileSize / 2 - (fontToUse:getWidth(charToDraw) / 2), 
--                        tileY + tileSize / 2 - (fontToUse:getHeight() / 2))
--    
--    -- If you wanted to draw something else on top of/around the player, do it here.
--    -- For example, if player has a strong shield effect, draw a border around their tile:
--    -- if self:hasStatusEffect("strong_shield_visual") then
--    --     love.graphics.setColor(Config.activeColors.accent[1], Config.activeColors.accent[2], Config.activeColors.accent[3], 0.5)
--    --     love.graphics.rectangle("line", tileX, tileY, tileSize, tileSize)
--    -- end
--end


-- ===== Subroutines =====
function Player:learnSubroutine(subroutineId)
    if #self.subroutines >= self.maxSubroutines then -- Or handle differently if no slot limit
        -- For now, just log, later could allow replacing
        print("Cannot learn " .. subroutineId .. ". Max subroutines reached.")
        return nil
    end
    local newSub = SubroutineInstance:new(subroutineId)
    table.insert(self.subroutines, newSub)
    print("Player learned: " .. newSub:getName())
    return newSub
end

function Player:getSubroutineById(subroutineId)
    for _, sub in ipairs(self.subroutines) do
        if sub.id == subroutineId then
            return sub
        end
    end
    return nil
end

function Player:upgradeSubroutine(subroutineInstance)
    if subroutineInstance and subroutineInstance.levelUp then
        if subroutineInstance:levelUp() then
            print(subroutineInstance:getName() .. " upgraded!")
            return true
        end
    end
    print("Failed to upgrade subroutine.")
    return false
end

-- ===== CoreModifications =====
function Player:getCoreModificationLevel(modId)
    return self.coreModifications[modId] or 0
end

function Player:hasCoreModificationFlag(modId)
    return self.coreModificationFlags[modId] == true
end

function Player:addCoreModificationFlag(modId)
    self.coreModificationFlags[modId] = true
end

function Player:purchaseCoreModification(modId)
    local modDef = CoreModificationDB.getById(modId)
    if not modDef then return false, "Modification not found." end

    local currentLevel = self:getCoreModificationLevel(modId)
    if currentLevel >= (modDef.maxLevel or 1) then return false, "Modification already at max level." end

    -- Cost calculation (can be a function or number)
    local cost = type(modDef.cost) == "function" and modDef.cost(self, currentLevel + 1) or modDef.cost
    if self.dataFragments < cost then return false, "Not enough DATA_FRAGMENTS." end

    -- Check prerequisites
    if modDef.prerequisites then
        for _, prereqId in ipairs(modDef.prerequisites) do
            local prereqDef = CoreModificationDB.getById(prereqId)
            if self:getCoreModificationLevel(prereqId) < (prereqDef.maxLevel or 1) then
                return false, "Prerequisite '" .. prereqDef.name .. "' not met."
            end
        end
    end

    self.dataFragments = self.dataFragments - cost
    self.coreModifications[modId] = currentLevel + 1
    
    if modDef.applyEffect then
        local gameplayStateInstance = _G.GameState.get("gameplay") -- Get GameplayState instance
        if gameplayStateInstance then
            modDef.applyEffect(self, self.coreModifications[modId]) -- Pass it
        else
            print("ERROR: GameplayState instance not found when applying core mod effect for " .. modId)
            -- Fallback or handle error if gameplay state is essential for the effect
            -- For effects that don't log, this might be okay, but logging will be missed.
        end
    end
    
    return true, modDef.name .. " acquired/upgraded."
end

-- Override takeDamage to account for shield
function Player:takeDamage(amount, attackerName)
    local actualAmount = amount
    local shieldEffect = nil

    -- Find shield effect
    for _, effect in ipairs(self.activeStatusEffects) do
        if effect.id == "shield" and effect.data and effect.data.amount > 0 then
            shieldEffect = effect
            break
        end
    end

    if shieldEffect then
        local absorbed = math.min(actualAmount, shieldEffect.data.amount)
        shieldEffect.data.amount = shieldEffect.data.amount - absorbed
        actualAmount = actualAmount - absorbed
        local shieldMsg = string.format("%s absorbs %d damage! (Shield: %d remaining)", shieldEffect.name or "Shield", absorbed, shieldEffect.data.amount)
        _G.GameState.current():logMessage(shieldMsg, _G.Config.activeColors.accent)
        if shieldEffect.data.amount <= 0 then
             _G.GameState.current():logMessage(shieldEffect.name .. " depleted!", _G.Config.activeColors.accent)
             -- Optionally remove the effect immediately when depleted, or let duration handle it
             -- For now, let duration handle removal. Just set amount to 0.
        end
    end

    if actualAmount <= 0 then -- All damage absorbed
        -- Spawn "Absorbed" particle?
        local gameplayState = _G.GameState.current()
        if gameplayState and gameplayState.ParticleFX then
        gameplayState.ParticleFX.spawnFloatingText(gameplayState, "ABSORBED", self.x, self.y, {
            color = {0.7, 0.7, 1, 1}, font = _G.Fonts.small, duration = 0.7, vy = -20
        })
    end
        return string.format("%s's attack fully absorbed...", attackerName or "Attack")
    end

    -- Apply remaining damage (copied from base Entity:takeDamage logic)
    self.hp = self.hp - actualAmount

    local gameplayState = _G.GameState.current()
    if gameplayState and gameplayState.triggerScreenShake then
        local shakeIntensity = 5 -- Player getting hit might feel more impactful
        if actualAmount > self.maxHp * 0.3 then
            shakeIntensity = 10 -- Stronger shake for big hits on player
        end
        gameplayState:triggerScreenShake(shakeIntensity)
    end

     -- Spawn Player Damage Particle
    if gameplayState and ParticleFX and amount > 0 then -- Check amount > 0 for damage numbers
        local damageColor = {1, 0.2, 0.2, 1} 
        if self == gameplayState.player then damageColor = {1, 0.5, 0.2, 1} end
        ParticleFX.spawnFloatingText(gameplayState, "-" .. tostring(amount), self.x, self.y, {
            color = damageColor,
            font = _G.Fonts.medium, -- Can be part of options
            vy = -35, ay = 70      -- Customize motion
        })
    end

    local message = string.format("%s takes %d damage from %s.", self.name, actualAmount, attackerName or "UNKNOWN_SOURCE")
    if self.hp <= 0 then
        self.hp = 0
        self:die() -- Calls Player:die
        message = message .. " " .. self.name .. " is destroyed!"
    end
    return message
end

function Player:endTurnUpdate() -- Call this at the end of player's turn
    -- Tick subroutine cooldowns
    for _, sub in ipairs(self.subroutines) do
        sub:tickCooldown()
    end

    self:regenerateCPU()
end

function Player:takeTurn(dx, dy, map, gameplayState) -- Added gameplayState for logging
    if self.actionTaken then return false, "already_acted" end -- Already acted this turn

    -- Check for stun etc. at start of turn attempt
    if self:processStatusEffectsStartTurn() then
        -- If stunned, the turn action is consumed
        -- but we still need to trigger end-of-turn processing later
        self.actionTaken = true
        return false, "stunned"
    end

    local newX, newY = self.x + dx, self.y + dy
    local targetEntity = map:getEntityAt(newX, newY)

    if targetEntity and targetEntity ~= self then -- Is there an entity on the target tile, and it's not me?
        -- Check if the entity is attackable (e.g., has hp and is considered an enemy)
        -- For now, we'll assume any entity with hp > 0 that isn't the player is attackable.
        -- A more robust system might involve factions or an `isAttackable` property.
        if targetEntity.hp and targetEntity.hp > 0 and not targetEntity.isPickup then
            -- Attack logic
            local damage = self.baseAttackPower -- Could be modified by subroutines later
            local logMessage = targetEntity:takeDamage(damage, self.name)
            gameplayState:logMessage(logMessage, _G.Config.activeColors.enemy) -- Log damage to enemy

            if targetEntity.isDead then
                -- Death messages/loot handled by entity's die() method or GameplayState
            end

            self.actionTaken = true
            return true, "attack"
        else
            -- It's a non-attackable entity (pickup, corpse, friendly that doesn't block, etc.)
            -- OR an entity that we can't attack (e.g. already dead).
            -- We attempt to move onto this tile. The map:isBlocked check will determine if this is possible.
            -- map:isBlocked considers both tile walkability AND other blocking entities.
            -- We pass 'self' to isBlocked so it doesn't consider the player itself as blocking the destination.
            if not map:isBlocked(newX, newY, self) then
                self:move(dx, dy)
                self.actionTaken = true
                return true, "move_onto_entity" -- Moved onto a tile that had a non-blocking entity
            else
                -- Cannot move onto the tile, either because the tile itself is unwalkable
                -- or a *different* blocking entity is there (which shouldn't be the case if targetEntity was the only one)
                -- or targetEntity itself, despite being non-attackable, is set to blocksMovement = true (e.g. a friendly NPC wall)
                if targetEntity.blocksMovement then
                     gameplayState:logMessage("Cannot pass through " .. targetEntity.name .. ".", _G.Config.activeColors.text)
                else
                     gameplayState:logMessage("Path blocked at " .. targetEntity.name .. "'s location.", _G.Config.activeColors.text)
                end
                return false, "blocked_by_entity_or_tile"
            end
        end
    else -- No entity on the target tile, regular move attempt
        if not map:isBlocked(newX, newY, self) then -- Check if tile is walkable and not blocked by other entities
            self:move(dx, dy)
            self.actionTaken = true
            return true, "move"
        else
            -- It's a wall or blocked by some other means not covered by getEntityAt
            return false, "blocked_by_wall"
        end
    end
end

function Player:regenerateCPU()
    self.cpuCycles = math.min(self.maxCPUCycles, self.cpuCycles + self.cpuRegenRate)
end

-- Override die method if player needs special handling (e.g., game over)
function Player:die()
    Entity.die(self) -- Call base die method
    self.char = "X" -- Player corpse looks different
    self.color = {1,0,0,1} -- Red
    -- Game over logic will be triggered by GameplayState checking player.isDead
end


-- update and draw can be inherited or customized

return Player