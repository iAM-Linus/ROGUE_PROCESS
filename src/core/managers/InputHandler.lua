-- src/core/InputHandler.lua
local GameStateManager = _G.GameState -- To switch states (e.g., to main menu, core mods)
local Helpers = require 'src.utils.Helpers' -- If needed for any specific input logic

local InputHandler = {}

-- Processes key presses for the GameplayState
-- Returns true if the key was handled in a way that should consume it, false otherwise.
function InputHandler.processKey(key, scancode, isrepeat, gameplayState)
    local gs = gameplayState -- Shorter alias

    -- Overall checks that might block any further input processing
    if gs.currentMode == gameplayState.Mode.GAME_OVER then
        if key == "return" or key == "kpenter" then
            GameStateManager.switch("mainmenu", { resetLevel = true })
            return true 
        end
        return false 
    end

    if gs.isEnemyActionResolving then
        -- print("[InputHandler] Input blocked: Enemy action resolving.")
        return false -- Key not handled by gameplay logic yet
    end

    if not gs.turnManager or not gs.player or gs.player.isDead then
        -- print("[InputHandler] Input blocked: No turnManager, player, or player is dead.")
        return false
    end
    
    -- If it's player's turn, log general flags
    if gs.turnManager.isPlayerTurn then
        print(string.format("[InputHandler Key: %s] Flags: isPlayerTurn=%s, player.actionTaken=%s, currentMode=%s",
            key, tostring(gs.turnManager.isPlayerTurn),
            tostring(gs.player and gs.player.actionTaken), tostring(gs.currentMode)
        ))
    end

    -- Mode-specific input handling
    if gs.currentMode == gameplayState.Mode.LOOKING then
        return InputHandler.handleLookingMode(key, gs)
    elseif gs.currentMode == gameplayState.Mode.TARGETING then
        return InputHandler.handleTargetingMode(key, gs)
    elseif gs.currentMode == gameplayState.Mode.PLAYER_TURN then
        -- Further check: if it's player's turn but they've already acted
        if gs.player.actionTaken then
            print("[InputHandler PLAYER_TURN] Blocked: Player has already taken action this turn.")
            return false
        end
        return InputHandler.handlePlayerTurnMode(key, gs)
    end

    return false -- Key not handled by any active mode in gameplay
end

---------------------------------------------------------------------
-- Handler for LOOKING mode
---------------------------------------------------------------------
function InputHandler.handleLookingMode(key, gs)
    local dx, dy = 0,0
    local look_handled = false
    if key == "up" or key == "k" or key == "kp8" then dy = -1; look_handled = true
    elseif key == "down" or key == "j" or key == "kp2" then dy = 1; look_handled = true
    elseif key == "left" or key == "h" or key == "kp4" then dx = -1; look_handled = true
    elseif key == "right" or key == "l" or key == "kp6" then dx = 1; look_handled = true
    end

    if look_handled and (dx ~= 0 or dy ~= 0) then
        local newCursorX = gs.lookCursor.x + dx
        local newCursorY = gs.lookCursor.y + dy
        if newCursorX >= 1 and newCursorX <= gs.map.width and
           newCursorY >= 1 and newCursorY <= gs.map.height and
           gs.map:isInFov(newCursorX, newCursorY) then
            gs.lookCursor.x = newCursorX
            gs.lookCursor.y = newCursorY
        end
    elseif key == "escape" or key == "x" then 
        gs:cancelLooking() -- Call method on GameplayState
        look_handled = true
    end
    return look_handled 
end

---------------------------------------------------------------------
-- Handler for TARGETING mode
---------------------------------------------------------------------
function InputHandler.handleTargetingMode(key, gs)
    local dx, dy = 0,0
    local targeting_handled = false
    if key == "up" or key == "k" or key == "kp8" then dy = -1; targeting_handled = true
    elseif key == "down" or key == "j" or key == "kp2" then dy = 1; targeting_handled = true
    elseif key == "left" or key == "h" or key == "kp4" then dx = -1; targeting_handled = true
    elseif key == "right" or key == "l" or key == "kp6" then dx = 1; targeting_handled = true
    end

    if targeting_handled and (dx ~= 0 or dy ~= 0) then
        local newCursorX = gs.targetCursor.x + dx
        local newCursorY = gs.targetCursor.y + dy
        local dist = Helpers.distanceEuclidean({x=newCursorX, y=newCursorY}, {x=gs.player.x, y=gs.player.y})
        if newCursorX >= 1 and newCursorX <= gs.map.width and
           newCursorY >= 1 and newCursorY <= gs.map.height and
           dist <= gs.maxTargetRange then
            gs.targetCursor.x = newCursorX
            gs.targetCursor.y = newCursorY
        else
            gs:logMessage("Target out of range or bounds.", {1,1,0.5,1})
        end
    elseif key == "return" or key == "kpenter" then
        local targetEntity = gs.map:getEntityAt(gs.targetCursor.x, gs.targetCursor.y)
        local effectData, _ = gs.targetingSubroutine:getCurrentEffectData()
        local isValidTarget = false
        if effectData.targetType == "enemy_at_cursor" then
            if targetEntity and targetEntity ~= gs.player and not targetEntity.isDead and not targetEntity.isPickup then
                if Helpers.hasLineOfSight(gs.player.x, gs.player.y, targetEntity.x, targetEntity.y, function(lx,ly) return not gs.map:isTransparent(lx,ly) end) then
                    isValidTarget = true
                else gs:logMessage("Target not in line of sight.", {1,1,0.5,1}) end
            else gs:logMessage("Invalid target for " .. gs.targetingSubroutine:getName() .. ".", {1,1,0.5,1}) end
        elseif effectData.targetType == "aoe_at_cursor" then
             if Helpers.hasLineOfSight(gs.player.x, gs.player.y, gs.targetCursor.x, gs.targetCursor.y, function(lx,ly) return not gs.map:isTransparent(lx,ly) end) then
                isValidTarget = true; targetEntity = {x = gs.targetCursor.x, y = gs.targetCursor.y}
             else gs:logMessage("Target point not in line of sight.", {1,1,0.5,1}) end
        end
        if isValidTarget then gs:activateSubroutine(gs.targetingSubroutine, targetEntity) end
        targeting_handled = true 
    elseif key == "escape" then
        gs:cancelTargeting()
        targeting_handled = true 
    end
    return targeting_handled 
end

---------------------------------------------------------------------
-- Handler for PLAYER_TURN mode
---------------------------------------------------------------------
function InputHandler.handlePlayerTurnMode(key, gs)
    local player_turn_handled = false 
    local dx, dy = 0, 0
    
    if key == "up" or key == "k" or key == "kp8" then dy = -1; player_turn_handled = true
    elseif key == "down" or key == "j" or key == "kp2" then dy = 1; player_turn_handled = true
    -- ... (all other movement keys) ...
    elseif key == "left" or key == "h" or key == "kp4" then dx = -1; player_turn_handled = true
    elseif key == "right" or key == "l" or key == "kp6" then dx = 1; player_turn_handled = true
    elseif key == "y" or key == "kp7" then dx = -1; dy = -1; player_turn_handled = true
    elseif key == "u" or key == "kp9" then dx = 1; dy = -1; player_turn_handled = true
    elseif key == "b" or key == "kp1" then dx = -1; dy = 1; player_turn_handled = true
    elseif key == "n" or key == "kp3" then dx = 1; dy = 1; player_turn_handled = true
    elseif key == "." or key == "kp5" or key == "space" then
        gs.player.actionTaken = true
        gs:logMessage(gs.player.name .. " waits.", _G.Config.activeColors.player)
        player_turn_handled = true
    elseif key == "1" then gs:tryActivateSubroutine(1); player_turn_handled = true
    elseif key == "2" then gs:tryActivateSubroutine(2); player_turn_handled = true
    elseif key == "3" then gs:tryActivateSubroutine(3); player_turn_handled = true
    elseif key == "4" then gs:tryActivateSubroutine(4); player_turn_handled = true
    elseif key == "c" then 
        GameStateManager.switch("core_modification", gs.player)
        player_turn_handled = true -- Opening menu is handled, but doesn't consume player action yet
                                 -- If it should, set gs.player.actionTaken = true here
    elseif key == "x" then 
        gs:startLooking()
        player_turn_handled = true -- Looking is free, doesn't set actionTaken
    elseif key == "escape" then
        return false -- Let main.lua handle global escape
    end

    if player_turn_handled and (dx ~= 0 or dy ~= 0) then -- Movement attempt
        local success, actionType = gs.player:takeTurn(dx, dy, gs.map, gs)
        if success then
            if actionType == "move" or actionType == "move_onto_entity" then
                _G.SFX.play("player_move")
                gs:logMessage(gs.player.name .. " moves.", _G.Config.activeColors.player)
                gs.map:computeFov(gs.player.x, gs.player.y, gs.fovRadius)
                gs:centerCameraOnPlayer(false)
                local pickedUpSomething = gs:checkForPickups(gs.player.x, gs.player.y)
                if not pickedUpSomething and gs.player.x == gs.map.exitPortal.x and gs.player.y == gs.map.exitPortal.y then
                    if gs.objective == "defeat_boss" and not gs.objectiveMet then
                        gs:logMessage("GUARDIAN PROCESS still active. Exit locked.", {1,0.5,0.5,1})
                    elseif not gs.map.exitPortal.active then
                         gs:logMessage("Exit portal is currently inactive.", {1,0.5,0.5,1})
                    else
                        local wasBossFloor = (gs.objective == "defeat_boss" and gs.objectiveMet)
                        gs:logMessage("Exit portal activated. Descending...", _G.Config.activeColors.accent)
                        _G.SFX.play("level_exit")
                        if wasBossFloor then
                            gs:triggerBossDefeatedRewards() 
                            gs.currentSector = gs.currentSector + 1
                            gs.currentFloorInSector = 0 
                            if not gs.pendingBossReward_SubroutineChoice then gs:moveToNextLevel() end
                        else
                            gs.player.dataFragments = gs.player.dataFragments + (10 + gs.currentSector * 5)
                            gs.player.cpuCycles = math.min(gs.player.maxCPUCycles, gs.player.cpuCycles + math.floor(gs.player.maxCPUCycles * 0.25))
                            gs:logMessage(string.format("+%d DATA, +%d CPU", (10 + gs.currentSector * 5), math.floor(gs.player.maxCPUCycles * 0.25)), _G.Config.activeColors.pickup)
                            if gs.currentFloorInSector >= gs.floorsPerSector then gs.isNextFloorBoss = true end
                            gs:moveToNextLevel()
                        end
                        return true -- Exited level, full handling
                    end
                end
            elseif actionType == "attack" then
                -- Attack sounds/logs handled in takeDamage or by subroutine
            end
        else -- Player:takeTurn failed
            if actionType == "blocked_by_wall" then gs:logMessage("Path blocked by terrain.", {1,1,0.5,1})
            elseif actionType == "stunned" then gs:logMessage(gs.player.name .. " is stunned!", {1,1,0.5,1})
            end
            -- If takeTurn failed, player.actionTaken is still false (unless stunned), so player can try another key.
            -- We return player_turn_handled (which is true) because a movement key *was* processed.
            return player_turn_handled 
        end
    end

    -- Turn advancement logic (if an action was successfully taken that sets player.actionTaken)
    if gs.player.actionTaken then
        gs.player:endTurnUpdate()
        gs.turnManager:nextTurn()
        if gs.turnManager.isPlayerTurn then
            gs.currentMode = gs.Mode.PLAYER_TURN
            gs:calculateAllEnemyIntents()
        else
            gs.currentMode = gs.Mode.ENEMY_TURN
        end
        if gs.player.isDead then gs:triggerGameOver("PID_PLAYER TERMINATED.") end
    end
    return player_turn_handled
end

return InputHandler