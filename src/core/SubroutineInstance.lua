-- src/core/SubroutineInstance.lua
local SubroutineDB = require "src.core.SubroutineDB"
local CoreModificationDB = require 'src.core.CoreModificationDB'

local SubroutineInstance = {}
SubroutineInstance.__index = SubroutineInstance

function SubroutineInstance:new(subroutineId)
    local instance = setmetatable({}, SubroutineInstance)
    instance.id = subroutineId
    instance.definition = SubroutineDB.getById(subroutineId)
    if not instance.definition then
        error("Attempted to create SubroutineInstance for unknown ID: " .. subroutineId)
    end

    instance.level = 1
    instance.currentCooldown = 0 -- Turns remaining on cooldown

    return instance
end

function SubroutineInstance:getName()
    return self.definition.name .. (self.level > 1 and " Lvl." .. self.level or "")
end

function SubroutineInstance:getCurrentEffectData()
    local effectDef = self.definition.effects["level_" .. self.level]
    if not effectDef then
        error("No effect definition for " .. self.id .. " at level " .. self.level)
    end

    -- Combine base definition with level-specific overrides
    local currentData = {}
    for k, v in pairs(self.definition) do -- Start with base definition
        if k ~= "effects" and k ~= "maxLevel" then currentData[k] = v end
    end
    for k, v in pairs(effectDef.data or {}) do -- Override with level-specific data
        currentData[k] = v
    end
    if effectDef.cpuCost then currentData.cpuCost = effectDef.cpuCost end -- Explicit cpuCost override for level

    return currentData, effectDef.apply -- Return combined data and the apply function for this level
end

function SubroutineInstance:getActualCpuCost(caster)
    local baseCostData, _ = self:getCurrentEffectData()
    local baseCost = baseCostData.cpuCost or self.definition.cpuCost

    local finalCost = baseCost
    if caster.hasCoreModificationFlag and caster:hasCoreModificationFlag("data_compression_1") then
        local modDef = CoreModificationDB.getById("data_compression_1")
        if modDef and modDef.getEffectValue then
            local reductionPercent = modDef.getEffectValue(caster, caster:getCoreModificationLevel("data_compression_1"))
            finalCost = math.max(1, math.floor(baseCost * (1 - reductionPercent))) -- Ensure cost is at least 1
        end
    end
    return finalCost
end

function SubroutineInstance:getDescription(caster) -- Pass caster to get actual cost
    local baseDesc = self.definition.description
    local effectDef = self.definition.effects["level_" .. self.level]
    local suffix = effectDef and effectDef.description_suffix or ""
    
    local actualCost = self:getActualCpuCost(caster)

    return string.format("%s (Cost: %d CPU) %s", baseDesc, actualCost, suffix)
end

function SubroutineInstance:canActivate(caster)
    local actualCost = self:getActualCpuCost(caster)
    if caster.cpuCycles < actualCost then return false, "Not enough CPU_CYCLES." end
    if self.currentCooldown > 0 then return false, "Subroutine on cooldown (" .. self.currentCooldown .. " turns)." end
    return true
end

function SubroutineInstance:activate(caster, target, map, gameplayState)
    local can, reason = self:canActivate(caster)
    if not can then
        gameplayState:logMessage(reason, {1,1,0.5,1})
        return false, reason
    end

    local currentData, applyFunc = self:getCurrentEffectData()
    local actualCost = self:getActualCpuCost(caster) -- Use actual cost

    caster.cpuCycles = caster.cpuCycles - actualCost -- Deduct actual cost
    local success, message = applyFunc(caster, target, map, gameplayState, currentData)

    if success then
        -- Cooldown
        if self.definition.cooldown and self.definition.cooldown > 0 then
            self.currentCooldown = self.definition.cooldown
        end
        -- Corruption
        if self.definition.tags then
            for _, tag in ipairs(self.definition.tags) do
                if tag == "destabilizing" and gameplayState.systemCorruption then
                    gameplayState.systemCorruption:add(gameplayState.systemCorruption.corruptionPerPowerfulSub or 5)
                    break
                end
            end
        end
        -- SFX
        if self.definition.type == SubroutineDB.Types.OFFENSIVE then
            ServiceLocator.get("sfx").play("subroutine_activate_offensive")
        elseif self.definition.type == SubroutineDB.Types.DEFENSIVE then
            ServiceLocator.get("sfx").play("subroutine_activate_defensive")
        else
            ServiceLocator.get("sfx").play("subroutine_activate_generic")
        end
    else
        if reason == "Not enough CPU_CYCLES." then
            ServiceLocator.get("sfx").play("subroutine_fail_cpu")
        elseif reason:find("cooldown") then -- Basic check for cooldown message
            ServiceLocator.get("sfx").play("subroutine_fail_cooldown")
        else
            ServiceLocator.get("sfx").play("ui_error")
        end
        gameplayState:logMessage(message or (self:getName() .. " activation failed."), {1,0.5,0.5,1})
    end
    return success, message
end

function SubroutineInstance:levelUp()
    if self.level < self.definition.maxLevel then
        self.level = self.level + 1
        print(self.id .. " leveled up to " .. self.level)
        return true
    end
    return false
end

function SubroutineInstance:tickCooldown()
    if self.currentCooldown > 0 then
        self.currentCooldown = self.currentCooldown - 1
    end
end

return SubroutineInstance