-- src/core/Player.lua
local Entity = require "src.core.Entity"
local SubroutineInstance = require 'src.core.SubroutineInstance'
local CoreModificationDB = require 'src.core.CoreModificationDB'
local AICoreDB = require 'src.core.AICoreDB'

local Player = {}
Player.__index = Player
setmetatable(Player, {__index = Entity}) -- Inherit from Entity

function Player:new(x, y, aiCoreData)
    -- Get services
    local config = ServiceLocator.get("config")
    local metaProgress = ServiceLocator.get("metaProgress")

    if not aiCoreData then
        print("ERROR: Player:new() called without aiCoreData. Using fallback.")
        local selectedCoreId = metaProgress:getSelectedAICoreId() or "standard_pid"
        aiCoreData = AICoreDB.getById(selectedCoreId) -- Fallback
        if not aiCoreData then aiCoreData = AICoreDB.Cores.standard_pid end -- Absolute fallback
    end

    local quadName = aiCoreData.quadName or "PLAYER_STANDARD"
    local char = aiCoreData.char or config.playerChar
    local color = aiCoreData.color or config.activeColors.player
    local name = aiCoreData.name or "PID_PLAYER_UNKNOWN"
    local initialHp = aiCoreData.baseStats.hp
    
    local instance = Entity:new(x, y, quadName, aiCoreData.color, name, true, initialHp)
    setmetatable(instance, Player)

    instance.isPlayer = true
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
    end

    -- Apply passive perk if any
    if aiCoreData.passivePerk and aiCoreData.passivePerk.apply then
        aiCoreData.passivePerk.apply(instance)
    end
    
    print(string.format("Player created with AI Core: %s. HP:%d, CPU:%d, Sub:%s", 
        aiCoreData.name, instance.maxHp, instance.maxCPUCycles, aiCoreData.startingSubroutineId or "None"))

    return instance
end

function Player:regenerateCPU()
    self.cpuCycles = math.min(self.maxCPUCycles, self.cpuCycles + self.cpuRegenRate)
end


-- ===== Subroutines =====
function Player:learnSubroutine(subroutineId)
    if #self.subroutines >= self.maxSubroutines then
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

--- Purchase core modification
---@param modId string : Modification identifier
---@return boolean, string : success, message
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
    
    -- Apply the effect, passing events service for logging
    if modDef.applyEffect then
        local events = ServiceLocator.get("events")
        modDef.applyEffect(self, self.coreModifications[modId], events)
    end
    
    return true, modDef.name .. " acquired/upgraded."
end

-- Override takeDamage to account for shield
function Player:takeDamage(amount, attackerName)
    local config = ServiceLocator.get("config")
    local stateManager = ServiceLocator.get("states")
    local gameplayState = stateManager:getCurrent()
    local fonts = ServiceLocator.get("fonts")
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
        local shieldMsg = string.format("%s absorbs %d damage! (Shield: %d remaining)", 
            shieldEffect.name or "Shield", absorbed, shieldEffect.data.amount)
        gameplayState:logMessage(shieldMsg, config.activeColors.accent)

        if shieldEffect.data.amount <= 0 then
            gameplayState:logMessage(shieldEffect.name .. " depleted!", config.activeColors.accent)
        end
    end

    if actualAmount <= 0 then -- All damage absorbed
        if gameplayState and gameplayState.ParticleFX then
            gameplayState.ParticleFX.spawnFloatingText(gameplayState, "ABSORBED", self.x, self.y, {
            color = {0.7, 0.7, 1, 1},
            font = fonts.small,
            duration = 0.7,
            vy = -20
        })
        end
        return string.format("%s's attack fully absorbed...", attackerName or "Attack")
    end

    -- Apply remaining damage
    self.hp = self.hp - actualAmount

    if gameplayState and gameplayState.triggerScreenShake then
        local shakeIntensity = 5
        if actualAmount > self.maxHp * 0.3 then
            shakeIntensity = 10
        end
        gameplayState:triggerScreenShake(shakeIntensity)
    end

     -- Spawn Player Damage Particle
    if gameplayState and gameplayState.ParticleFX and amount > 0 then
        local damageColor = {1, 0.2, 0.2, 1} 
        if self == gameplayState.player then damageColor = {1, 0.5, 0.2, 1} end
        gameplayState.ParticleFX.spawnFloatingText(gameplayState, "-" .. tostring(amount), self.x, self.y, {
            color = damageColor,
            font = fonts.medium,
            vy = -35,
            ay = 70
        })
    end

    local message = string.format("%s takes %d damage from %s.", self.name, actualAmount, attackerName or "UNKNOWN_SOURCE")
    if self.hp <= 0 then
        self.hp = 0
        self:die()
        message = message .. " " .. self.name .. " is destroyed!"
    end
    return message
end

function Player:endTurnUpdate()
    -- Tick subroutine cooldowns
    for _, sub in ipairs(self.subroutines) do
        sub:tickCooldown()
    end

    self:regenerateCPU()
end

function Player:takeTurn(dx, dy, map, gameplayState)
    local config = ServiceLocator.get("config")

    if self.actionTaken then return false, "already_acted" end

    -- Check for stun etc. at start of turn attempt
    if self:processStatusEffectsStartTurn() then
        self.actionTaken = true
        return false, "stunned"
    end

    local newX, newY = self.x + dx, self.y + dy
    local targetEntity = map:getEntityAt(newX, newY)

    if targetEntity and targetEntity ~= self then
        if targetEntity.hp and targetEntity.hp > 0 and not targetEntity.isPickup then
            -- Attack logic
            local damage = self.baseAttackPower
            local logMessage = targetEntity:takeDamage(damage, self.name)
            gameplayState:logMessage(logMessage, config.activeColors.enemy)

            self.actionTaken = true
            return true, "attack"
        else
            -- Non-attackable entity, attempt to move
            if not map:isBlocked(newX, newY, self) then
                --map:moveEntity(self, newX, newY)
                self:move(dx, dy)
                self.actionTaken = true
                return true, "move"
            else
                return false, "blocked"
            end
        end
    else -- No entity, try to move
        if not map:isBlocked(newX, newY, self) then
            --map:moveEntity(self, newX, newY)
            self:move(dx, dy)
            self.actionTaken = true
            return true, "move"
        else
            return false, "blocked"
        end
    end
end

return Player