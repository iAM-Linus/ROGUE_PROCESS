-- src/core/CoreModificationDB.lua

local CoreModificationDB = {}

--[[
Each modification definition:
{
    id = "unique_id",
    name = "Display Name",
    description = "What it does.",
    cost = function(player, currentLevel) or number, -- Cost in DATA_FRAGMENTS, can scale
    maxLevel = number (optional, default 1),
    prerequisites = { "other_mod_id", ... } (optional),
    applyEffect = function(player, level, GameplayState), -- Called when purchased/upgraded
    removeEffect = function(player, level), -- (Optional) If effects need to be un-applied (rare for passives)
    getEffectValue = function(player, level) (Optional) For querying current bonus from this mod
    tags = {"stat_boost", "cpu", "integrity"} (Optional, for UI filtering/organization)
}
--]]

CoreModificationDB.Modifications = {
    max_integrity_boost_1 = {
        id = "max_integrity_boost_1",
        name = "Reinforced Core Shell",
        description = "Increases Maximum INTEGRITY by 20.",
        cost = 50,
        maxLevel = 1,
        applyEffect = function(player, level, events)
            player.maxHp = player.maxHp + 20
            player.hp = player.hp + 20
        
            -- Emit event for logging
            if events then
                events:emit("log_message", {
                    text = "Core Shell Reinforced: INTEGRITY.max += 20.",
                    color = {0.4, 1, 0.5, 1}
                })
            end
        end,
        tags = {"integrity", "survivability"}
    },
    max_integrity_boost_2 = {
        id = "max_integrity_boost_2",
        name = "Optimized Integrity Matrix",
        description = "Increases Maximum INTEGRITY by a further 30.",
        cost = 100,
        maxLevel = 1,
        prerequisites = {"max_integrity_boost_1"},
        applyEffect = function(player, level, events)
            player.maxHp = player.maxHp + 30
            player.hp = player.hp + 30
            
            if events then
                events:emit("log_message", {
                    text = "ECC Modules Active: Stun Resistance increased.",
                    color = {0.4, 1, 0.5, 1}
                })
            end
        end,
        tags = {"integrity", "survivability"}
    },
    cpu_regen_boost_1 = {
        id = "cpu_regen_boost_1",
        name = "Auxiliary CPU Capacitor",
        description = "Increases CPU_CYCLE regeneration per turn by 1.",
        cost = 75,
        maxLevel = 1,
        applyEffect = function(player, level, events)
            player.cpuRegenRate = player.cpuRegenRate + 1
            
            if events then
                events:emit("log_message", {
                    text = "Capacitor charged: Regen increased by +1.0.",
                    color = {0.4, 1, 0.5, 1}
                })
            end
        end,
        tags = {"cpu", "resource"}
    },
    max_cpu_boost_1 = {
        id = "max_cpu_boost_1",
        name = "Expanded CPU Cache",
        description = "Increases Maximum CPU_CYCLES by 25.",
        cost = 60,
        maxLevel = 1,
        applyEffect = function(player, level, events)
            player.maxCPUCycles = player.maxCPUCycles + 25
            player.cpuCycles = player.cpuCycles + 25 
            
            if events then
                events:emit("log_message", {
                    text = "Cache optimized: CPU_CYCLES.max_value += 25.",
                    color = {0.4, 1, 0.5, 1}
                })
            end
        end,
        tags = {"cpu", "resource"}
    },
    data_compression_1 = {
        id = "data_compression_1",
        name = "Subroutine Optimizer Mk1",
        description = "Reduces CPU cost of all subroutines by 10% (min 1).",
        cost = 120,
        maxLevel = 1,
        applyEffect = function(player, level, events)
            player:addCoreModificationFlag(CoreModificationDB.Modifications.data_compression_1.id)
            
            if events then
                events:emit("log_message", {
                    text = "Mk1 Optimizer: CPU Cost -= (cost*.9).",
                    color = {0.4, 1, 0.5, 1}
                })
            end
        end,
        getEffectValue = function(player, level) return 0.10 end,
        tags = {"cpu", "subroutine_efficiency"}
    },
    error_correction_1 = {
        id = "error_correction_1",
        name = "ECC Memory Modules",
        description = "Grants a 25% chance to resist STUN effects.",
        cost = 90,
        maxLevel = 1,
        applyEffect = function(player, level, events)
            player:addCoreModificationFlag(CoreModificationDB.Modifications.error_correction_1.id)
            
            if events then
                events:emit("log_message", {
                    text = "ECC Modules Active: Stun Resistance increased.",
                    color = {0.4, 1, 0.5, 1}
                })
            end
        end,
        getEffectValue = function(player, level) return 0.25 end,
        tags = {"defense", "status_resistance"}
    },
}

function CoreModificationDB.getById(id)
    return CoreModificationDB.Modifications[id]
end

-- Helper to get available modifications for the player
function CoreModificationDB.getAvailableForPlayer(player)
    local available = {}
    for id, modDef in pairs(CoreModificationDB.Modifications) do
        local currentLevel = player:getCoreModificationLevel(id)
        if currentLevel < (modDef.maxLevel or 1) then -- Can still be purchased/upgraded
            local canAfford = true -- Placeholder, cost check done in UI
            local prereqsMet = true
            if modDef.prerequisites then
                for _, prereqId in ipairs(modDef.prerequisites) do
                    if player:getCoreModificationLevel(prereqId) < (CoreModificationDB.getById(prereqId).maxLevel or 1) then
                        prereqsMet = false
                        break
                    end
                end
            end
            if prereqsMet then
                table.insert(available, modDef)
            end
        end
    end
    -- Sort alphabetically or by cost, etc.
    table.sort(available, function(a,b) return a.name < b.name end)
    return available
end

return CoreModificationDB