-- src/core/SubroutineDB.lua
local config = ServiceLocator.get("config")


local SubroutineDB = {}

-- Subroutine Categories/Types
SubroutineDB.Types = {
    OFFENSIVE = "OFFENSIVE",
    DEFENSIVE = "DEFENSIVE",
    UTILITY = "UTILITY",
    SYSTEM_MANIPULATION = "SYSTEM_MANIPULATION",
}

-- Define Subroutines
-- Each subroutine has:
--  id:             unique string identifier
--  name:           display name
--  type:           from SubroutineDB.Types
--  description:    base description
--  cpuCost:        base CPU cost
--  targetType:     "self", "enemy_at_cursor", "adjacent_enemy", "aoe_around_player",
--                  "aoe_at_cursor", "none" (for passives)
--  range:          (if applicable, in tiles)
--  cooldown:       (in turns)
--  maxLevel:       how many times it can be upgraded
--  effects:        table of functions or data defining what it does at each level
--      level_1: { description_suffix (optional), apply = function(caster, target, map, gameplayState, levelData) ... end, data = {...} }
--      level_2: ...
--  rarity:         (optional, e.g., 1 for common, 5 for rare - for weighted selection)

SubroutineDB.Subroutines = {
    -- === OFFENSIVE ===
    laser_exe = {
        id = "laser_exe",
        name = "LASER.EXE",
        type = SubroutineDB.Types.OFFENSIVE,
        description = "Fires a concentrated data beam at a target.",
        cpuCost = 10,
        targetType = "enemy_at_cursor", -- We'll need a targeting system for this
        range = 7,
        maxLevel = 3,
        rarity = 1,
        effects = {
            level_1 = {
                description_suffix = "Deals 15 damage.",
                data = { damage = 15 },
                apply = function(caster, target, map, gameplayState, levelData)
                    if not target or target.isDead then return false, "Invalid target." end
                    if ParticleFX then -- Check if ParticleFX is loaded/available
                        ParticleFX.spawnLaserBeam(gameplayState, caster, target)
                    end
                    local logMsg = target:takeDamage(levelData.damage, caster.name .. " (LASER.EXE)")
                    gameplayState:logMessage(logMsg, config.activeColors.enemy)
                    if target.isDead then
                        gameplayState:logMessage(target.name .. " was pierced by LASER.EXE.", config.activeColors.pickup)
                    end
                    -- TODO: Visual effect for laser (e.g., text particle line)
                    gameplayState:logMessage(caster.name .. " fires LASER.EXE at " .. target.name .. "!",
                        config.activeColors.player)
                    return true, caster.name .. " fires LASER.EXE."
                end
            },
            level_2 = {
                description_suffix = "Deals 20 damage and costs 8 CPU.",
                data = { damage = 20, cpuCost = 8 },
                apply = function(caster, target, map, gameplayState, levelData)
                    -- Apply logic is same, just data changes. We can reuse level 1 apply if data is passed correctly.
                    -- For simplicity here, we'll just copy, but a more advanced system could inherit/override.
                    if not target or target.isDead then return false, "Invalid target." end
                    if ParticleFX then -- Check if ParticleFX is loaded/available
                        ParticleFX.spawnLaserBeam(gameplayState, caster, target)
                    end
                    local logMsg = target:takeDamage(levelData.damage, caster.name .. " (LASER.EXE Lvl2)")
                    gameplayState:logMessage(logMsg, config.activeColors.enemy)
                    if target.isDead then
                        gameplayState:logMessage(target.name .. " was pierced by LASER.EXE.", config.activeColors.pickup)
                    end
                    gameplayState:logMessage(caster.name .. " fires enhanced LASER.EXE at " .. target.name .. "!",
                        config.activeColors.player)
                    return true, caster.name .. " fires enhanced LASER.EXE."
                end
            },
            level_3 = {
                description_suffix = "Deals 25 damage, costs 6 CPU, and pierces one target.",
                data = { damage = 25, cpuCost = 6, pierces = 1 },
                apply = function(caster, target, map, gameplayState, levelData)
                    -- For piercing, we'd need to trace the laser line and hit multiple targets.
                    -- This is a simplified version for now, just hitting the primary target harder.
                    -- A real pierce would require more complex targeting/line drawing.
                    if not target or target.isDead then return false, "Invalid target." end
                    if ParticleFX then -- Check if ParticleFX is loaded/available
                        ParticleFX.spawnLaserBeam(gameplayState, caster, target)
                    end
                    local logMsg = target:takeDamage(levelData.damage, caster.name .. " (LASER.EXE Lvl3)")
                    gameplayState:logMessage(logMsg, config.activeColors.enemy)
                    if target.isDead then
                        gameplayState:logMessage(target.name .. " was obliterated by LASER.EXE.",
                            config.activeColors.pickup)
                    end
                    gameplayState:logMessage(caster.name .. " fires piercing LASER.EXE at " .. target.name .. "!",
                        config.activeColors.player)
                    -- TODO: Implement actual piercing logic
                    return true, caster.name .. " fires piercing LASER.EXE."
                end
            }
        }
    },

    overclock_pulse_obj = {
        id = "overclock_pulse_obj",
        name = "OVERCLOCK_PULSE.OBJ",
        type = SubroutineDB.Types.OFFENSIVE,
        description = "Unleashes a burst of unstable energy around you.",
        cpuCost = 20,
        targetType = "aoe_around_player",
        range = 1, -- Radius 1 (3x3 area around player)
        maxLevel = 2,
        rarity = 2,
        effects = {
            level_1 = {
                description_suffix = "Deals 10 damage to all adjacent entities.",
                data = { damage = 10 },
                apply = function(caster, target, map, gameplayState, levelData) -- Target is ignored for AoE around player
                    local affectedCount = 0
                    if ParticleFX then
                        ParticleFX.spawnAoEPulse(gameplayState, caster.x, caster.y, levelData.range, "▒", {1,0.6,0.2,0.8})
                    end
                    gameplayState:logMessage(caster.name .. " emits an OVERCLOCK_PULSE!", config.activeColors.player)
                    for y_offset = -levelData.range, levelData.range do
                        for x_offset = -levelData.range, levelData.range do
                            if x_offset == 0 and y_offset == 0 then goto continue_loop end -- Skip self

                            local checkX, checkY = caster.x + x_offset, caster.y + y_offset
                            local entity = map:getEntityAt(checkX, checkY)
                            if entity and entity ~= caster and not entity.isDead then
                                local logMsg = entity:takeDamage(levelData.damage, caster.name .. " (OVERCLOCK_PULSE)")
                                gameplayState:logMessage(logMsg, config.activeColors.enemy)
                                if entity.isDead then
                                    gameplayState:logMessage(entity.name .. " was caught in the pulse.",
                                        config.activeColors.pickup)
                                end
                                affectedCount = affectedCount + 1
                            end
                            ::continue_loop::
                        end
                    end
                    if affectedCount == 0 then
                        return true, caster.name .. "'s pulse hits nothing."
                    end
                    return true, caster.name .. "'s pulse hits " .. affectedCount .. " targets."
                end
            },
            level_2 = {
                description_suffix = "Deals 15 damage in a larger radius (2). Costs 18 CPU.",
                data = { damage = 15, cpuCost = 18, range = 2 }, -- Note: range here overrides base range for this level
                apply = function(caster, target, map, gameplayState, levelData)
                    local affectedCount = 0
                    if ParticleFX then
                        ParticleFX.spawnAoEPulse(gameplayState, caster.x, caster.y, levelData.range, "▒", {1,0.6,0.2,0.8})
                    end
                    gameplayState:logMessage(caster.name .. " emits a powerful OVERCLOCK_PULSE!",
                        config.activeColors.player)
                    for y_offset = -levelData.range, levelData.range do
                        for x_offset = -levelData.range, levelData.range do
                            if x_offset == 0 and y_offset == 0 then goto continue_loop end

                            local checkX, checkY = caster.x + x_offset, caster.y + y_offset
                            local entity = map:getEntityAt(checkX, checkY)
                            if entity and entity ~= caster and not entity.isDead then
                                local logMsg = entity:takeDamage(levelData.damage,
                                    caster.name .. " (OVERCLOCK_PULSE Lvl2)")
                                gameplayState:logMessage(logMsg, config.activeColors.enemy)
                                if entity.isDead then
                                    gameplayState:logMessage(entity.name .. " was caught in the powerful pulse.",
                                        config.activeColors.pickup)
                                end
                                affectedCount = affectedCount + 1
                            end
                            ::continue_loop::
                        end
                    end
                    if affectedCount == 0 then
                        return true, caster.name .. "'s pulse hits nothing."
                    end
                    return true, caster.name .. "'s powerful pulse hits " .. affectedCount .. " targets."
                end
            }
        }
    },

    corrupt_data_bat = { -- NEW
        id = "corrupt_data_bat",
        name = "CORRUPT_DATA.BAT",
        type = SubroutineDB.Types.OFFENSIVE,
        description = "Inflicts decaying corruption on a target's data stream.",
        cpuCost = 12,
        targetType = "enemy_at_cursor",
        range = 6,
        maxLevel = 2,
        rarity = 1,
        effects = {
            level_1 = {
                description_suffix = "Deals 4 damage per turn for 3 turns.",
                data = { dotDamage = 4, duration = 3 },
                apply = function(caster, target, map, gameplayState, levelData)
                    if not target or target.isDead or target.isPickup then return false, "Invalid target." end
                    local effect = {
                        id = "corrupt_dot",
                        name = "Corruption",
                        duration = levelData.duration,
                        data = { damage = levelData.dotDamage }
                    }
                    target:addStatusEffect(effect)
                    gameplayState:logMessage(caster.name .. " corrupts " .. target.name .. "!",
                        config.activeColors.player)
                    return true, caster.name .. " applies Corruption."
                end
            },
            level_2 = {
                description_suffix = "Deals 6 damage per turn for 4 turns. Costs 10 CPU.",
                data = { dotDamage = 6, duration = 4, cpuCost = 10 },
                apply = function(caster, target, map, gameplayState, levelData)
                    if not target or target.isDead or target.isPickup then return false, "Invalid target." end
                    local effect = {
                        id = "corrupt_dot",
                        name = "Corruption Lvl.2",
                        duration = levelData.duration,
                        data = { damage = levelData.dotDamage }
                    }
                    target:addStatusEffect(effect)
                    gameplayState:logMessage(caster.name .. " severely corrupts " .. target.name .. "!",
                        config.activeColors.player)
                    return true, caster.name .. " applies severe Corruption."
                end
            }
        }
    },

    data_bomb_exe = {
        id = "data_bomb_exe",
        name = "DATA_BOMB.EXE",
        type = SubroutineDB.Types.OFFENSIVE,
        description = "Detonates a data charge at target location.",
        cpuCost = 25,
        targetType = "aoe_at_cursor",
        range = 6, -- Max targeting range
        maxLevel = 1,
        effects = {
            level_1 = {
                description_suffix = "Deals 20 damage in a 1-tile radius.",
                data = { damage = 20, aoeRadius = 1 }, -- aoeRadius = 1 means 3x3 area
                apply = function(caster, targetLocation, map, gameplayState, levelData)
                    -- targetLocation will be {x = cursorX, y = cursorY}
                    local affectedCount = 0
                    gameplayState:logMessage(
                    caster.name .. " detonates DATA_BOMB at " .. targetLocation.x .. "," .. targetLocation.y .. "!",
                        config.activeColors.player)
                    for dy = -levelData.aoeRadius, levelData.aoeRadius do
                        for dx = -levelData.aoeRadius, levelData.aoeRadius do
                            local currentX, currentY = targetLocation.x + dx, targetLocation.y + dy
                            local entity = map:getEntityAt(currentX, currentY)
                            if entity and entity ~= caster and not entity.isDead and not entity.isPickup then
                                -- Optional: Check LOS from explosion center to entity if desired
                                local logMsg = entity:takeDamage(levelData.damage, caster.name .. " (DATA_BOMB)")
                                gameplayState:logMessage(logMsg, config.activeColors.enemy)
                                if entity.isDead then end
                                affectedCount = affectedCount + 1
                            end
                        end
                    end
                    return true, "DATA_BOMB detonated, hitting " .. affectedCount .. " targets."
                end
            }
        }
    },

    -- === DEFENSIVE ===
    firewall_sys = {
        id = "firewall_sys",
        name = "FIREWALL.SYS",
        type = SubroutineDB.Types.DEFENSIVE,
        description = "Erects a temporary barrier, absorbing incoming damage.",
        cpuCost = 15,
        targetType = "self",
        maxLevel = 2,
        rarity = 1,
        effects = {
            level_1 = {
                description_suffix = "Absorbs 20 damage for 5 turns.",
                data = { shieldAmount = 20, duration = 5 },
                apply = function(caster, target, map, gameplayState, levelData)
                    local effect = {
                        id = "shield",
                        name = "Firewall",
                        duration = levelData.duration,
                        data = { amount = levelData.shieldAmount } -- Store shield amount in data payload
                    }
                    caster:addStatusEffect(effect)                 -- Add as a status effect
                    gameplayState:logMessage(
                    caster.name .. " activates FIREWALL.SYS (Shield: " .. levelData.shieldAmount .. ").",
                        config.activeColors.player)
                    return true, caster.name .. " activates FIREWALL.SYS."
                end
            },
            level_2 = {
                description_suffix = "Absorbs 35 damage for 7 turns. Costs 12 CPU.",
                data = { shieldAmount = 35, duration = 7, cpuCost = 12 },
                apply = function(caster, target, map, gameplayState, levelData)
                    local effect = {
                        id = "shield",
                        name = "Firewall Lvl.2",
                        duration = levelData.duration,
                        data = { amount = levelData.shieldAmount }
                    }
                    caster:addStatusEffect(effect)
                    gameplayState:logMessage(
                    caster.name .. " activates upgraded FIREWALL.SYS (Shield: " .. levelData.shieldAmount .. ").",
                        config.activeColors.player)
                    return true, caster.name .. " activates upgraded FIREWALL.SYS."
                end
            }
        }
    },
    -- More subroutines to be added here...

    -- === SYSTEM_MANIPULATION ===
    syscall_interrupt_c = { -- NEW
        id = "syscall_interrupt_c",
        name = "SYSCALL_INTERRUPT.C",
        type = SubroutineDB.Types.SYSTEM_MANIPULATION,
        description = "Sends an interrupt signal, attempting to stun a target.",
        cpuCost = 18,
        targetType = "enemy_at_cursor",
        range = 5,
        maxLevel = 2,
        rarity = 2,
        effects = {
            level_1 = {
                description_suffix = "Stuns target for 1 turn.",
                data = { duration = 1 }, -- Duration of stun
                apply = function(caster, target, map, gameplayState, levelData)
                    if not target or target.isDead or target.isPickup then return false, "Invalid target." end
                    -- Stun duration is N turns *after* the current one.
                    -- So duration 1 means they miss their *next* turn.
                    local effect = {
                        id = "stun",
                        name = "Stunned",
                        duration = levelData.duration + 1 -- +1 because duration ticks down *after* they would have acted
                    }
                    target:addStatusEffect(effect)
                    gameplayState:logMessage(caster.name .. " interrupts " .. target.name .. "!",
                        config.activeColors.player)
                    return true, caster.name .. " stuns " .. target.name .. "."
                end
            },
            level_2 = {
                description_suffix = "Stuns target for 2 turns. Costs 15 CPU.",
                data = { duration = 2, cpuCost = 15 },
                apply = function(caster, target, map, gameplayState, levelData)
                    if not target or target.isDead or target.isPickup then return false, "Invalid target." end
                    local effect = {
                        id = "stun",
                        name = "Stunned Lvl.2",
                        duration = levelData.duration + 1
                    }
                    target:addStatusEffect(effect)
                    gameplayState:logMessage(caster.name .. " severely interrupts " .. target.name .. "!",
                        config.activeColors.player)
                    return true, caster.name .. " stuns " .. target.name .. " for longer."
                end
            }
        }
    },
}

-- === HELPER FUNCTIONS ===

function SubroutineDB.getById(id)
    return SubroutineDB.Subroutines[id]
end

-- Helper function to get a list of N random subroutine IDs (respecting rarity, optionally)
-- For now, simple random choice. Rarity can be added later.
function SubroutineDB.getRandomSubroutineIds(count, existingSubroutineIds)
    existingSubroutineIds = existingSubroutineIds or {}
    local available = {}
    for id, _ in pairs(SubroutineDB.Subroutines) do
        local isExisting = false
        for _, existingId in ipairs(existingSubroutineIds) do
            if id == existingId then
                isExisting = true
                break
            end
        end
        if not isExisting then -- Only offer new subroutines for now (upgrades handled separately)
            table.insert(available, id)
        end
    end

    local chosen = {}
    if #available == 0 then return chosen end

    for i = 1, count do
        if #available == 0 then break end
        local randomIndex = love.math.random(1, #available)
        table.insert(chosen, available[randomIndex])
        table.remove(available, randomIndex)
    end
    return chosen
end

-- Helper to get upgrade options or new subroutines
function SubroutineDB.getChoices(count, playerSubroutines)
    local choices = {}
    local playerSubroutineIds = {}
    local upgradablePlayerSubroutines = {}

    for _, subInst in ipairs(playerSubroutines) do
        table.insert(playerSubroutineIds, subInst.id)
        local def = SubroutineDB.getById(subInst.id)
        if subInst.level < def.maxLevel then
            table.insert(upgradablePlayerSubroutines, subInst)
        end
    end

    -- Prioritize offering upgrades if available and count allows
    local upgradeSlots = math.min(#upgradablePlayerSubroutines, math.floor(count / 2)) -- e.g., up to half choices can be upgrades
    if count == 1 and #upgradablePlayerSubroutines > 0 then upgradeSlots = 1 end       -- If only 1 choice, can be upgrade

    for i = 1, upgradeSlots do
        if #upgradablePlayerSubroutines == 0 then break end
        local randIdx = love.math.random(1, #upgradablePlayerSubroutines)
        local subToUpgrade = table.remove(upgradablePlayerSubroutines, randIdx)
        table.insert(choices, { type = "upgrade", subroutineInstance = subToUpgrade })
    end

    -- Fill remaining slots with new subroutines
    local newSubroutineCount = count - #choices
    if newSubroutineCount > 0 then
        local availableNew = {}
        for id, def in pairs(SubroutineDB.Subroutines) do
            local isOwned = false
            for _, ownedId in ipairs(playerSubroutineIds) do
                if id == ownedId then
                    isOwned = true; break
                end
            end
            if not isOwned then
                table.insert(availableNew, id)
            end
        end

        -- Simple random selection for new ones (can add rarity weighting later)
        for i = 1, newSubroutineCount do
            if #availableNew == 0 then break end
            local randIdx = love.math.random(1, #availableNew)
            local newSubId = table.remove(availableNew, randIdx)
            table.insert(choices, { type = "new", subroutineId = newSubId })
        end
    end

    -- If not enough choices, try to fill with more upgrades if any were skipped
    if #choices < count and #upgradablePlayerSubroutines > 0 then
        for i = 1, count - #choices do
            if #upgradablePlayerSubroutines == 0 then break end
            local randIdx = love.math.random(1, #upgradablePlayerSubroutines)
            local subToUpgrade = table.remove(upgradablePlayerSubroutines, randIdx)
            table.insert(choices, { type = "upgrade", subroutineInstance = subToUpgrade })
        end
    end


    -- Shuffle choices to make the order random
    for i = #choices, 2, -1 do
        local j = love.math.random(i)
        choices[i], choices[j] = choices[j], choices[i]
    end

    return choices
end

return SubroutineDB
