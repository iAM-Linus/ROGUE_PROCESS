-- src/core/bosses/BossBehaviorDB.lua
local Helpers = require "src.utils.helpers" -- Make sure this is at the top if used
local ParticleFX = _G.ParticleFX -- Assuming ParticleFX is global (from GameplayState require)
local SentryBot = require "src.core.enemies.SentryBot" -- Required for summon
local config = ServiceLocator.get("config")

local BossBehaviorDB = {}

-- This table will hold the behavior definitions for each boss ID
BossBehaviorDB.Behaviors = {

    ["sector_1_guardian"] = { -- The key is the bossId
        -- No need for bossId field inside here again, it's the key
        phases = {
            {
                name = "Phase 1: Defensive Probing",
                healthThreshold = 1.0, 
                entryMessage = "GUARDIAN ONLINE. Threat assessment initiated.",
                abilities = {
                    { 
                        id = "probe_shot", weight = 3, maxCooldown = 2, 
                        plan = function(boss, player, map, entities, gs) 
                            if not Helpers.hasLineOfSight(boss.x, boss.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                                return nil -- Can't shoot if no LOS
                            end
                            return { type = "ranged_attack", targetEntity = player, damage = 10, 
                                     description = "PROBE SHOT (10 DMG)" } 
                        end,
                        execute = function(boss, player, map, entities, gs, action) 
                            gs:logMessage(boss.name .. " fires a probe at " .. player.name, boss.color)
                            if ParticleFX then ParticleFX.spawnLaserBeam(gs, boss, player) end
                            local logMsg = player:takeDamage(action.damage, boss.name)
                            gs:logMessage(logMsg, config.activeColors.player)
                            if player.isDead then gs:logMessage(player.name .. " terminated by probe.", {1,0,0,1}) end
                            return true
                        end
                    },
                    { 
                        id = "deploy_sentry_turret", weight = 1, maxCooldown = 5,
                        plan = function(boss, player, map, entities, gs)
                            local emptyAdj = {}
                            for dx = -1, 1 do for dy = -1, 1 do
                                if not (dx == 0 and dy == 0) then
                                    local checkX, checkY = boss.x + dx, boss.y + dy
                                    if map:isWalkable(checkX, checkY) and not map:getEntityAt(checkX, checkY) then
                                        table.insert(emptyAdj, {x = checkX, y = checkY})
                                    end
                                end
                            end end
                            if #emptyAdj > 0 then
                                return { type = "summon", targetPos = Helpers.choice(emptyAdj), 
                                         enemyClass = SentryBot, -- Pass the actual class
                                         summonNameSuffix = "TRT",
                                         description = "DEPLOYING TURRET" }
                            end
                            return nil 
                        end,
                        execute = function(boss, player, map, entities, gs, action)
                            gs:logMessage(boss.name .. " deploys a Sentry Turret!", boss.color)
                            local success, newName = gs:requestSpawnEnemy(action.enemyClass, action.targetPos.x, action.targetPos.y, action.summonNameSuffix)
                            if success and ParticleFX then ParticleFX.spawnFloatingText(gs, "SPAWN", action.targetPos.x, action.targetPos.y, {color=config.activeColors.enemy, duration=0.4}) end
                            return success
                        end
                    },
                    { 
                        id = "fortify_self", weight = 2, maxCooldown = 4,
                        plan = function(boss, player, map, entities, gs)
                            if boss:hasStatusEffect("shield") then return nil end -- Don't re-shield if already shielded
                            return { type = "buff_self", effectId = "shield", amount = 20, duration = 3, -- Increased duration
                                     description = "FORTIFYING (Shield +20)"}
                        end,
                        execute = function(boss, player, map, entities, gs, action)
                            boss:addStatusEffect({id=action.effectId, name="Guardian Shield", duration=action.duration, data={amount=action.amount}})
                            gs:logMessage(boss.name .. " reinforces its defenses!", boss.color)
                            if ParticleFX then ParticleFX.spawnFloatingText(gs, "SHIELD", boss.x, boss.y, {color=boss.color, vy=-10, duration=0.6}) end
                            return true
                        end
                    }
                },
                movementPattern = function(boss, player, map) 
                    -- Stay relatively still in phase 1, or move slightly if player is too close/far
                    local dist = Helpers.distanceEuclidean(boss, player)
                    if dist < 3 then -- Too close, try to back up a step
                        local bestMoveX, bestMoveY = boss.x, boss.y
                        local currentBestDist = dist
                        for dx = -1, 1 do for dy = -1, 1 do
                            if dx == 0 and dy == 0 then goto cont_p1_move end
                            local nextX, nextY = boss.x + dx, boss.y + dy
                            if not map:isBlocked(nextX, nextY, boss) and (not map:getEntityAt(nextX,nextY) or map:getEntityAt(nextX,nextY) == player) then
                                local d = Helpers.distanceEuclidean({x=nextX,y=nextY}, player)
                                if d > currentBestDist then currentBestDist = d; bestMoveX,bestMoveY = nextX,nextY; end
                            end
                            ::cont_p1_move::
                        end end
                        if bestMoveX ~= boss.x or bestMoveY ~= boss.y then return {x=bestMoveX, y=bestMoveY} end
                    end
                    return nil
                end
            },
            {
                name = "Phase 2: Overload Protocol",
                healthThreshold = 0.50,
                entryMessage = "WARNING: Core integrity compromised! Overload protocol active!",
                abilities = {
                    {
                        id = "overload_beam", weight = 3, maxCooldown = 3,
                        plan = function(boss, player, map, entities, gs)
                             if not Helpers.hasLineOfSight(boss.x, boss.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                                return nil 
                            end
                            return { type = "ranged_attack", targetEntity = player, damage = 20, 
                                     description = "OVERLOAD BEAM (20 DMG)" }
                        end,
                        execute = function(boss, player, map, entities, gs, action)
                            gs:logMessage(boss.name .. " unleashes an OVERLOAD BEAM at " .. player.name, boss.color)
                            if ParticleFX then ParticleFX.spawnLaserBeam(gs, boss, player) end -- Could make this laser visually different
                            local logMsg = player:takeDamage(action.damage, boss.name)
                            gs:logMessage(logMsg, config.activeColors.player)
                            if player.isDead then gs:logMessage(player.name .. " vaporized by overload.", {1,0,0,1}) end
                            return true
                        end
                    },
                    {
                        id = "system_shockwave", weight = 1, maxCooldown = 6,
                        plan = function(boss, player, map, entities, gs)
                            return { type = "aoe_attack", radius = 2, damage = 15, 
                                     description = "SYSTEM SHOCKWAVE (AOE 15 DMG)" }
                        end,
                        execute = function(boss, player, map, entities, gs, action)
                            gs:logMessage(boss.name .. " emits a powerful shockwave!", boss.color)
                            if ParticleFX then ParticleFX.spawnAoEPulse(gs, boss.x, boss.y, action.radius, "▓", boss.color) end
                            for _, entity in ipairs(entities) do -- Check all entities in GameplayState's list
                                if entity == player then -- Only target player for this AoE
                                    if Helpers.distanceEuclidean(boss, entity) <= action.radius then
                                        local logMsg = player:takeDamage(action.damage, boss.name .. " (Shockwave)")
                                        gs:logMessage(logMsg, config.activeColors.player)
                                        if player.isDead then gs:logMessage(player.name .. " caught in shockwave.", {1,0,0,1}) end
                                    end
                                end
                            end
                            return true
                        end
                    }
                },
                movementPattern = function(boss, player, map)
                    local dist = Helpers.distanceEuclidean(boss, player)
                    if dist > 2 then -- Try to get closer if not adjacent
                        local dx_p = player.x - boss.x; local dy_p = player.y - boss.y
                        local moveX, moveY = 0,0; if math.abs(dx_p)>0 then moveX=dx_p/math.abs(dx_p) end; if math.abs(dy_p)>0 then moveY=dy_p/math.abs(dy_p) end
                        local targetX, targetY = boss.x, boss.y
                        if moveX ~= 0 and not map:isBlocked(boss.x+moveX, boss.y, boss) and (not map:getEntityAt(boss.x+moveX,boss.y) or map:getEntityAt(boss.x+moveX,boss.y)==player) then targetX = boss.x+moveX
                        elseif moveY ~= 0 and not map:isBlocked(boss.x, boss.y+moveY, boss) and (not map:getEntityAt(boss.x,boss.y+moveY) or map:getEntityAt(boss.x,boss.y+moveY)==player) then targetY = boss.y+moveY end
                        if targetX ~= boss.x or targetY ~= boss.y then return {x=targetX, y=targetY} end
                    end
                    return nil
                end
            }
        }
    },
    -- You can add other boss behaviors here:
    -- ["sector_2_overmind"] = { ... } 
}

function BossBehaviorDB.getForBoss(bossId)
    if not bossId then
        print("ERROR: BossBehaviorDB.getForBoss called with nil bossId")
        return nil
    end
    local behavior = BossBehaviorDB.Behaviors[bossId]
    if not behavior then
        print("ERROR: No behavior defined in BossBehaviorDB for bossId: " .. bossId)
    end
    return behavior
end

return BossBehaviorDB