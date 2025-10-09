-- src/core/ai/AIBehaviors.lua
local Helpers = require "src.utils.helpers"
local ParticleFX = require "src.core.effects.ParticleEffectsDB"

local AIBehaviors = {}

--[[
    BEHAVIOR STRUCTURE:
    A behavior is a function that, when called, returns a "plan" table if the action
    can be performed, or nil otherwise. The plan table contains all necessary information
    for the `Enemy:executePlannedAction` method to carry out the action.
]]

-------------------------------------------------
-- MOVEMENT BEHAVIORS
-------------------------------------------------

-- Plans a move one step towards the player.
function AIBehaviors.planMoveToPlayer(enemy, player, map)
    local dx_p = player.x - enemy.x
    local dy_p = player.y - enemy.y
    local moveX, moveY = 0, 0
    if dx_p ~= 0 then moveX = dx_p / math.abs(dx_p) end
    if dy_p ~= 0 then moveY = dy_p / math.abs(dy_p) end

    local targetX, targetY = enemy.x, enemy.y
    
    -- Try moving diagonally first if applicable, then cardinally
    if moveX ~= 0 and moveY ~= 0 and not map:isBlocked(enemy.x + moveX, enemy.y + moveY, enemy) then
        targetX, targetY = enemy.x + moveX, enemy.y + moveY
    elseif moveX ~= 0 and not map:isBlocked(enemy.x + moveX, enemy.y, enemy) then
        targetX = enemy.x + moveX
    elseif moveY ~= 0 and not map:isBlocked(enemy.x, enemy.y + moveY, enemy) then
        targetY = enemy.y + moveY
    end

    if targetX ~= enemy.x or targetY ~= enemy.y then
        return { type = "move", targetPos = { x = targetX, y = targetY }, description = "HUNTING" }
    end
    return nil -- Blocked
end

-- Plans a move one step away from the player.
function AIBehaviors.planMoveAwayFromPlayer(enemy, player, map)
    local bestFleeX, bestFleeY = enemy.x, enemy.y
    local maxDistToPlayer = Helpers.distanceEuclidean(enemy, player)

    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx == 0 and dy == 0 then goto continue_flee_check end
            local nextX, nextY = enemy.x + dx, enemy.y + dy
            if not map:isBlocked(nextX, nextY, enemy) then
                local dist = Helpers.distanceEuclidean({ x = nextX, y = nextY }, player)
                if dist > maxDistToPlayer then
                    maxDistToPlayer = dist
                    bestFleeX, bestFleeY = nextX, nextY
                end
            end
            ::continue_flee_check::
        end
    end

    if bestFleeX ~= enemy.x or bestFleeY ~= enemy.y then
        return { type = "move", targetPos = { x = bestFleeX, y = bestFleeY }, description = "FLEEING" }
    end
    return nil -- Trapped
end

-- Plans a random one-step move.
function AIBehaviors.planRandomWalk(enemy, player, map)
    if love.math.random() < 0.5 then -- 50% chance to move
        local rDx, rDy = love.math.random(-1, 1), love.math.random(-1, 1)
        if rDx ~= 0 or rDy ~= 0 then
            local nX, nY = enemy.x + rDx, enemy.y + rDy
            if not map:isBlocked(nX, nY, enemy) and not map:getEntityAt(nX, nY) then
                return { type = "move", targetPos = { x = nX, y = nY }, description = "PATROLLING" }
            end
        end
    end
    return nil -- Decided not to move or was blocked
end

-------------------------------------------------
-- ATTACK BEHAVIORS
-------------------------------------------------

-- Plans a melee attack if the player is adjacent.
function AIBehaviors.planAttackIfAdjacent(enemy, player, map)
    local dx = math.abs(player.x - enemy.x)
    local dy = math.abs(player.y - enemy.y)
    if dx <= 1 and dy <= 1 and (dx + dy > 0) then
        return {
            type = "attack",
            targetEntity = player,
            damage = enemy.baseAttackPower or 5,
            description = "ATTACK (" .. (enemy.baseAttackPower or 5) .. " DMG)"
        }
    end
    return nil
end

-------------------------------------------------
-- SPECIAL ABILITY BEHAVIORS (Planning logic)
-------------------------------------------------

-- Plan to use Encrypt Ally (for Cipher Sentinel)
function AIBehaviors.planEncryptAlly(enemy, player, map, entities)
    local allyToEncrypt = nil
    local closestAllyDist = (enemy.encryptRange or 3) + 1

    for _, entity in ipairs(entities) do
        if entity.isEnemy and entity ~= enemy and not entity.isDead and not entity:hasStatusEffect("shield") then
            local distToAlly = Helpers.distanceEuclidean(enemy, entity)
            if distToAlly <= (enemy.encryptRange or 3) and distToAlly < closestAllyDist then
                if Helpers.hasLineOfSight(enemy.x, enemy.y, entity.x, entity.y, function(lx, ly) return not map:isTransparent(lx, ly) end) then
                    allyToEncrypt = entity
                    closestAllyDist = distToAlly
                end
            end
        end
    end

    if allyToEncrypt then
        return {
            type = "special_ability",
            description = "ENCRYPTING " .. allyToEncrypt.name,
            -- The execute function contains the actual logic
            execute = function(self, player, map, entities, gs, action)
                local shieldEffect = {
                    id = "shield", name = "Encryption Shield",
                    duration = self.encryptShieldDuration or 3,
                    data = { amount = self.encryptShieldAmount or 15 }
                }
                allyToEncrypt:addStatusEffect(shieldEffect)
                gs:logMessage(self.name .. " encrypts " .. allyToEncrypt.name .. ", granting a shield!", self.color)
                if ParticleFX then ParticleFX.spawnFloatingText(gs, "SHIELD+", allyToEncrypt.x, allyToEncrypt.y, {color=self.color, vy=-15, duration=0.8}) end
                return true
            end
        }
    end
    return nil
end

-- Plan to use Leech CPU (for Data Leech)
function AIBehaviors.planLeechCPU(enemy, player, map)
    local dx = math.abs(player.x - enemy.x)
    local dy = math.abs(player.y - enemy.y)
    if dx <= 1 and dy <= 1 and (dx + dy > 0) then
        return {
            type = "special_ability",
            description = "LEECHING CPU",
            execute = function(self, player, map, entities, gs, action)
                player.cpuCycles = math.max(0, player.cpuCycles - (self.leechAmount or 5))
                gs:logMessage(self.name .. " leeches " .. (self.leechAmount or 5) .. " CPU from " .. player.name .. "!", {1, 0.5, 1, 1})
                if ParticleFX then ParticleFX.spawnFloatingText(gs, "-"..(self.leechAmount or 5).." CPU", player.x, player.y, {color={0.8,0.3,0.8,1}, vy=-25}) end
                return true
            end
        }
    end
    return nil
end

-- Plan to Replicate (for Glitch Swarmer)
function AIBehaviors.planReplicate(enemy, player, map, entities, gs)
    local GlitchSwarmer = require "src.core.enemies.GlitchSwarmer" -- Late require to avoid circular dependency
    if GlitchSwarmer.activeSwarmerCount >= GlitchSwarmer.maxTotalSwarmers then return nil end

    local emptyAdjacent = {}
    for dx = -1, 1 do for dy = -1, 1 do
        if not (dx == 0 and dy == 0) then
            local checkX, checkY = enemy.x + dx, enemy.y + dy
            if map:isWalkable(checkX, checkY) and not map:getEntityAt(checkX, checkY) then
                table.insert(emptyAdjacent, { x = checkX, y = checkY })
            end
        end
    end end

    if #emptyAdjacent > 0 then
        local spawnPos = Helpers.choice(emptyAdjacent)
        return {
            type = "special_ability",
            description = "REPLICATING",
            execute = function(self, player, map, entities, gs, action)
                local success, newName = gs:requestSpawnEnemy(GlitchSwarmer, spawnPos.x, spawnPos.y, "REP")
                if success then
                    gs:logMessage(self.name .. " replicates! New: " .. newName, self.color)
                    if ParticleFX then ParticleFX.spawnFloatingText(gs, "++", spawnPos.x, spawnPos.y, {color=self.color, duration=0.5, vy=-10}) end
                else
                    gs:logMessage(self.name .. " replication failed.", _G.Config.activeColors.text)
                end
                return true -- Consume turn even if failed
            end
        }
    end
    return nil
end

-- Plan to Pulse (for Firewall Node)
function AIBehaviors.planPulse(enemy, player, map)
    local targetDir = enemy.pulseDirection
    if Helpers.hasLineOfSight(enemy.x, enemy.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
        local dx = player.x - enemy.x; local dy = player.y - enemy.y
        if math.abs(dx) > math.abs(dy) then targetDir = (dx > 0) and 2 or 4
        else targetDir = (dy > 0) and 3 or 1 end
    end

    return {
        type = "special_ability",
        description = "PULSING",
        execute = function(self, player, map, entities, gs, action)
            local dx, dy = 0, 0
            if targetDir == 1 then dy = -1 elseif targetDir == 2 then dx = 1
            elseif targetDir == 3 then dy = 1 else dx = -1 end

            for i = 1, self.pulseRange do
                local targetX, targetY = self.x + dx * i, self.y + dy * i
                if not map:isTransparent(targetX, targetY) then break end
                if ParticleFX then ParticleFX.spawnFloatingText(gs, ".", targetX, targetY, {color={1,0.6,0,0.7}, duration=0.2, vy=0, vx=0, font=_G.Fonts.large}) end
                local entityOnTile = map:getEntityAt(targetX, targetY)
                if entityOnTile and not entityOnTile.isDead and not entityOnTile.isPickup then
                    if ParticleFX then ParticleFX.spawnHitSparks(gs, targetX, targetY, 3, {1.0,0.6,0.0,1}) end
                    local logMsg = entityOnTile:takeDamage(self.pulseDamage, self.name)
                    gs:logMessage(logMsg, _G.Config.activeColors.enemy)
                    break
                end
            end
            self.pulseDirection = (targetDir % 4) + 1 -- Rotate for next pulse
            return true
        end
    }
end

-- Plan Ranged Attack (for BitRipper)
function AIBehaviors.planRangedAttack(enemy, player, map)
    local dist = Helpers.distanceEuclidean(enemy, player)
    if dist <= enemy.attackRange and Helpers.hasLineOfSight(enemy.x, enemy.y, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
        return {
            type = "special_ability",
            description = "FIRING SHARD (" .. enemy.rangedAttackDamage .. " DMG)",
            execute = function(self, player, map, entities, gs, action)
                gs:logMessage(self.name .. " fires a bit shard at " .. player.name .. "!", self.color)
                if ParticleFX then ParticleFX.spawnLaserBeam(gs, self, player) end
                local logMsg = player:takeDamage(self.rangedAttackDamage, self.name)
                gs:logMessage(logMsg, _G.Config.activeColors.player)

                -- Phase Step logic is part of the execution
                if love.math.random() < self.phaseStepChance then
                    local validTiles = {}
                    for i=1,10 do
                        local rdx = love.math.random(-self.phaseStepRange, self.phaseStepRange)
                        local rdy = love.math.random(-self.phaseStepRange, self.phaseStepRange)
                        
                        if not (rdx == 0 and rdy == 0) then
                            local newX, newY = self.x + rdx, self.y + rdy
                            if map:isWalkable(newX, newY) and not map:getEntityAt(newX, newY) and Helpers.hasLineOfSight(newX, newY, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                                table.insert(validTiles, {x=newX, y=newY})
                            end
                        end
                    end
                    if #validTiles > 0 then
                        local phaseTo = Helpers.choice(validTiles)
                        gs:logMessage(self.name .. " phases to a new position!", self.color)
                        if ParticleFX then 
                            ParticleFX.spawnFloatingText(gs, ">>", self.x, self.y, {color=self.color, duration=0.3, vx= (phaseTo.x-self.x)*20, vy=(phaseTo.y-self.y)*20})
                            self.x = phaseTo.x; self.y = phaseTo.y
                            ParticleFX.spawnFloatingText(gs, "<<", self.x, self.y, {color=self.color, duration=0.3})
                        else
                            self.x = phaseTo.x; self.y = phaseTo.y
                        end
                    end
                end
                return true
            end
        }
    end
    return nil
end

-- Plan Repositioning (for BitRipper)
function AIBehaviors.planRepositionForRange(enemy, player, map)
    local bestMoveX, bestMoveY = enemy.x, enemy.y
    local bestMoveScore = -1

    for dx = -1, 1 do for dy = -1, 1 do
        if not (dx == 0 and dy == 0) then
            local nextX, nextY = enemy.x + dx, enemy.y + dy
            if not map:isBlocked(nextX, nextY, enemy) and (not map:getEntityAt(nextX, nextY) or map:getEntityAt(nextX,nextY) == player) then
                if Helpers.hasLineOfSight(nextX, nextY, player.x, player.y, function(lx,ly) return not map:isTransparent(lx,ly) end) then
                    local dist = Helpers.distanceEuclidean({x=nextX, y=nextY}, player)
                    local score = math.abs(dist - (enemy.optimalRangeMin + enemy.optimalRangeMax)/2)
                    if dist > enemy.attackRange then score = score + 100 end
                    if dist < enemy.optimalRangeMin then score = score + 10 end
                    if bestMoveScore == -1 or score < bestMoveScore then
                        bestMoveScore = score
                        bestMoveX, bestMoveY = nextX, nextY
                    end
                end
            end
        end
    end end

    if bestMoveX ~= enemy.x or bestMoveY ~= enemy.y then
        return {type="move", targetPos={x=bestMoveX, y=bestMoveY}, description="REPOSITIONING"}
    end
    return nil
end


return AIBehaviors