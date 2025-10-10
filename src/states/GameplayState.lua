-- src/states/GameplayState.lua
local BaseState = require 'src.core.base_state'
local WorldInitializer = require 'src.core.managers.WorldInitializer'
local CameraManager = require 'src.core.managers.CameraManager'
local HUDManager = require 'src.core.managers.HUDManager'
local AnimationManager = require 'src.core.managers.AnimationManager'
local InputHandler = require 'src.core.managers.InputHandler'
local ParticleSystem = require 'src.core.ParticleSystem'
local SystemCorruption = require 'src.core.SystemCorruption'
ParticleFX = require 'src.core.effects.ParticleEffectsDB'
local Helpers = require 'src.utils.Helpers'
local UIHelpers = require 'src.ui.ui_helpers'
local Pickup = require 'src.core.Pickup'
local GlitchSwarmer = require 'src.core.enemies.GlitchSwarmer'

local config = ServiceLocator.get("config")
local fonts = ServiceLocator.get("fonts")

local GameplayState = {}
GameplayState.__index = GameplayState
setmetatable(GameplayState, { __index = BaseState })

GameplayState.Mode = {
    PLAYER_TURN = "player_turn",
    ENEMY_TURN = "enemy_turn",
    TARGETING = "targeting",
    GAME_OVER = "game_over",
    CORE_MODIFICATION = "core_modification",
    SUBROUTINE_CHOICE = "subroutine_choice",
    ENEMY_INTENT_DISPLAY = "enemy_intent_display",
    LOOKING = "looking"
}

function GameplayState:new(game)
    -- Ensure game object exists
    assert(game, "GameplayState requires game object")

    -- Call BaseState constructor
    local instance = BaseState.new(self, game)
    setmetatable(instance, GameplayState)
    instance.name = "GameplayState"

    -- Initialize all subsystems
    instance.systemCorruption = SystemCorruption:new(instance)
    instance.map = nil
    instance.player = nil
    instance.initilized = false
    instance.turnManager = nil
    instance.entities = {} -- All entities that take turns (player, enemies)
    instance.gameMessageLog = {}
    instance.logTimer = 0
    instance.cameraManager = CameraManager:new()
    instance.gameViewport = { x = 0, y = 0, width = 0, height = 0 }
    instance.lookCursor = { x = 0, y = 0, visible = false }
    instance.tileSize = game.config.spriteSize
    instance.fovRadius = 10
    instance.particleSystem = ParticleSystem:new()
    instance.hudManager = HUDManager:new()
    instance.animationManager = AnimationManager:new()

    instance.currentMode = GameplayState.Mode.PLAYER_TURN

    -- Add animation timing for smooth UI effects
    instance.uiAnimationTime = 0
    instance.lastFrameTime = love.timer.getTime()

    -- Enhanced visual state tracking
    instance.visualEffects = {
        screenShakeIntensity = 0,
        screenShakeDecay = 0.8,
        lastShakeTime = 0,
        cameraOffset = { x = 0, y = 0 }
    }

    -- Enhanced visual effects
    instance.cameraShakeIntensity = 0
    instance.backgroundEffects = {}
    instance.lightingEffects = {}
    instance.weatherEffects = {
        particles = {},
        intensity = 0,
        type = "none" -- "digital_rain", "data_storm", "glitch_cascade"
    }

    -- Run progression vars, will be set by WorldInitializer on new run
    instance.currentSector = 0
    instance.currentFloorInSector = 0
    instance.floorsPerSector = 3 -- Default, can be configured
    instance.isNextFloorBoss = false
    instance.totalFloorsCleared = -1

    -- Targeting specific properties
    instance.targetingSubroutine = nil
    instance.targetCursor = { x = 0, y = 0, visible = false }
    instance.maxTargetRange = 0

    instance.gameOver = false -- This is for the overall game over, distinct from currentMode
    instance.gameOverMessage = ""

    instance.isEnemyActionResolving = false
    instance.enemyActionDelayTimer = 0
    instance.enemyActionDelayDuration = game.config.enemyTurnActionDelay
    instance.actorWhoJustActed = nil                    -- To help with logging during delay
    instance.pendingBossReward_SubroutineChoice = false -- For boss reward flow
    instance.pausedForChoice = false                    -- Useful later
    return instance
end

function GameplayState:requestSpawnEnemy(EnemyClass, x, y, nameSuffix)
    if not EnemyClass or not x or not y then
        print("RequestSpawnEnemy: Invalid parameters.")
        return false, nil
    end

    -- Specific check for Swarmer cap
    if EnemyClass == GlitchSwarmer and GlitchSwarmer.activeSwarmerCount >= GlitchSwarmer.maxTotalSwarmers then
        print("RequestSpawnEnemy: Max GlitchSwarmers reached.")
        return false, nil
    end

    if self.map:isWalkable(x, y) and not self.map:getEntityAt(x, y) then
        local newEnemyNameSuffix = nameSuffix or tostring(love.math.random(100, 999))
        local newEnemy = EnemyClass:new(x, y, newEnemyNameSuffix) -- Pass suffix to constructor

        self.map:addEntity(newEnemy)
        table.insert(self.entities, newEnemy) -- Add to turn-taking list

        -- If it's mid-turn, the new enemy won't act until the next full round.
        -- We might need to re-sort self.entities or adjust TurnManager if spawning should
        -- allow the new entity to act in the current round (more complex).
        -- For now, it acts next round. TurnManager will pick it up when it rebuilds its list
        -- or if we explicitly tell TurnManager to resync.
        -- Let's resync TurnManager to include the new enemy in the current turn cycle if possible,
        -- but it will be placed at the end of the current list.
        self.turnManager:setEntities(self.entities)


        print("Spawned new enemy via request: " .. newEnemy.name)
        return true, newEnemy.name
    else
        print("RequestSpawnEnemy: Target location (" .. x .. "," .. y .. ") is blocked or invalid.")
        return false, nil
    end
end

function GameplayState:initNewGameOrLevel(isNewRun)
    WorldInitializer.setupLevel(self, isNewRun) -- Delegate to the new module
    if self.events then
        self.events:emit("level_started", {
            sector = self.currentSector,
            floor = self.currentFloorInSector,
            isBossLevel = self.isNextFloorBoss,
            enemyCount = #self.entities - 1
        })
    end
end

function GameplayState:enter(params)
    BaseState.enter(self, params)

    print(string.format("Entered GameplayState. IsInitialized %s", tostring(self.initialized)))
    love.graphics.setBackgroundColor(self.config.activeColors.background)

    local forceNewRun = params and params.resetLevel

    -- Emit event
    if self.events then
        self.events:emit("gameplay_entered", {
            isNewRun = not self.initialized or forceNewRun,
            currentSector = self.currentSector,
            currentFloor = self.currentFloorInSector
        })
    end

    if not self.isInitialized or forceNewRun then
        print("GameplayState:enter() - Starting a new run or forced reset.")
        self:initNewGameOrLevel(true)
    else
        print("GameplayState:enter() - Resuming current floor of existing run.")
        self.currentMode = GameplayState.Mode.PLAYER_TURN
        self.targetCursor.visible = false
        self.targetingSubroutine = nil
        self.isEnemyActionResolving = false

        if self.player and not self.player.actionTaken then
            if self.turnManager then
                self.turnManager.isPlayerTurn = true
            end
        end

        if not self.gameViewport or self.gameViewport.width == 0 then
            self:calculateGameViewport()
        end

        if self.map and self.player then
            self.map:computeFov(self.player.x, self.player.y, self.fovRadius)
            self.cameraManager:centerOn(self.player.x, self.player.y,
                self.gameViewport, self.map, true)
        end

        self:calculateAllEnemyIntents()
    end

    -- Listen for events from other states (optional)
    if self.events then
        -- Listen for subroutine events
        self.events:on("subroutine_learned", function(data)
            if data.message then
                self:logMessage(data.message, self.config.activeColors.pickup)
            end
        end)
        
        self.events:on("subroutine_upgraded", function(data)
            if data.message then
                self:logMessage(data.message, self.config.activeColors.pickup)
            end
        end)
        
        self.events:on("subroutine_choice_cancelled", function(data)
            if data.message then
                self:logMessage(data.message, self.config.activeColors.text)
            end
        end)
        
        -- Listen for core mod events
        self.events:on("core_modification_purchased", function(data)
            if data.message then
                self:logMessage(data.message, self.config.activeColors.pickup)
            end
        end)
        
        self.events:on("core_modification_purchase_failed", function(data)
            if data.message then
                self:logMessage(data.message, {1, 0.5, 0.5, 1})
            end
        end)
    end
end

function GameplayState:moveToNextLevel()
    self:initNewGameOrLevel(false) -- false for isNewRun
    if self.events then
        self.events:emit("level_completed", {
            sector = self.currentSector,
            floor = self.currentFloorInSector,
            nextIsBoss = self.isNextFloorBoss,
            totalFloorsCleared = self.totalFloorsCleared
        })
    end
end

function GameplayState:resume()
    BaseState.resume(self)  -- Call base implementation
    
    print("GameplayState:resume() called.")
    
    -- Reset to player turn
    self.currentMode = GameplayState.Mode.PLAYER_TURN 
    self.targetCursor.visible = false
    self.targetingSubroutine = nil
    self.isEnemyActionResolving = false

    -- Handle boss reward flow
    if self.pendingBossReward_SubroutineChoice then
        print("Resuming after boss reward subroutine choice. Moving to next level.")
        self.pendingBossReward_SubroutineChoice = false
        ServiceLocator.get("sfx").play("level_exit")
        self:moveToNextLevel() 
    elseif self.player then
        -- Check if player took action while in overlay state
        if self.player.actionTaken then
            print("  Player action is true after choice/other sub-state, advancing turn from resume().")
            self.player:endTurnUpdate()
            self.turnManager:nextTurn()
            
            if self.turnManager.isPlayerTurn then 
                self.currentMode = GameplayState.Mode.PLAYER_TURN
                self:calculateAllEnemyIntents()
            else 
                self.currentMode = GameplayState.Mode.ENEMY_TURN
            end
            
            if self.player.isDead then 
                self:triggerGameOver("PID_PLAYER TERMINATED.") 
            end
        else
            -- Player didn't take action, reset state
            self.player.actionTaken = false
            if self.turnManager then 
                self.turnManager.isPlayerTurn = true 
            end
        end
    end

    -- Recalculate viewport and FOV
    if self.map and self.player and not self.pendingBossReward_SubroutineChoice then
        self.map:computeFov(self.player.x, self.player.y, self.fovRadius)
        self.cameraManager:centerOn(self.player.x, self.player.y, self.gameViewport, self.map, true)
    end
    
    print(string.format("Resumed Gameplay from sub-state. Mode: %s, Player ActionTaken: %s", 
        self.currentMode, 
        tostring(self.player and self.player.actionTaken)))
end

function GameplayState:startTargeting(subroutineInstance)
    local config = self.config

    if not subroutineInstance then return end

    local effectData, _ = subroutineInstance:getCurrentEffectData()
    if effectData.targetType == "enemy_at_cursor" or effectData.targetType == "aoe_at_cursor" then
        self.targetingSubroutine = subroutineInstance
        self.targetCursor.x = self.player.x -- Start cursor at player
        self.targetCursor.y = self.player.y
        self.targetCursor.visible = true
        self.maxTargetRange = effectData.range or 7 -- Default range if not specified
        self.currentMode = GameplayState.Mode.TARGETING
        self:logMessage(
            "TARGETING MODE: Use arrows to aim " .. subroutineInstance:getName() .. ". ENTER to fire, ESC to cancel.",
            config.activeColors.accent)
    else
        -- For self-cast or player-centered AoE, activate immediately
        self:activateSubroutine(subroutineInstance, nil) -- No specific target for these types
    end
end

function GameplayState:activateSubroutine(subroutineInstance, targetEntity)
    if not self.player or not subroutineInstance then return end

    local config = self.config

    local can, reason = subroutineInstance:canActivate(self.player)
    if not can then
        self:logMessage(reason, { 1, 1, 0.5, 1 })
        self:cancelTargeting() -- Ensure targeting mode is exited if it was active
        self.currentMode = GameplayState.Mode.PLAYER_TURN
        return
    end

    -- Actually activate
    local activated, msg = subroutineInstance:activate(self.player, targetEntity, self.map, self)

    if activated then
        self.player.actionTaken = true -- Using a subroutine costs the turn action
        -- Messages are logged by subroutineInstance:activate or its apply function
    else
        -- Activation failed, message logged by subroutineInstance:activate
        -- Player's turn is not consumed if activation failed after canActivate check (e.g. no valid target at cursor)
        self.player.actionTaken = false
    end

    -- Add visual effects for subroutine activation
    if self.animationManager and activated then
        local playerScreenX = self.player.x * config.spriteSize + config.spriteSize / 2
        local playerScreenY = self.player.y * config.spriteSize + config.spriteSize / 2

        -- Convert to screen coordinates
        if self.gameViewport then
            playerScreenX = playerScreenX + self.gameViewport.x
            playerScreenY = playerScreenY + self.gameViewport.y
        end

        -- Subroutine activation pulse
        local subColor = config.activeColors.accent
        if subroutineInstance.definition.type == "OFFENSIVE" then
            subColor = { 1, 0.5, 0.2, 1 }
        elseif subroutineInstance.definition.type == "DEFENSIVE" then
            subColor = { 0.2, 0.7, 1, 1 }
        end

        self.animationManager:addPulseEffect(playerScreenX, playerScreenY, 40, subColor, 0.6)

        -- Connect player to target with particle trail
        if targetEntity and targetEntity ~= self.player then
            local targetScreenX = targetEntity.x * config.spriteSize + config.spriteSize / 2
            local targetScreenY = targetEntity.y * config.spriteSize + config.spriteSize / 2

            if self.gameViewport then
                targetScreenX = targetScreenX + self.gameViewport.x
                targetScreenY = targetScreenY + self.gameViewport.y
            end

            self.animationManager:addParticleTrail(playerScreenX, playerScreenY,
                targetScreenX, targetScreenY,
                8, subColor, 0.4)
        end
    end

    -- Always exit targeting mode after an attempt
    self.currentMode = GameplayState.Mode.PLAYER_TURN
    self.targetCursor.visible = false
    self.targetingSubroutine = nil

    if self.player.actionTaken then
        print("[activateSubroutine] Action taken, ending turn.") -- DEBUG
        self.player:endTurnUpdate()
        self.turnManager:nextTurn()
        -- Update currentMode based on whose turn it is now (this is already in your keypressed, but good to ensure it's consistent)
        if self.turnManager.isPlayerTurn then
            self.currentMode = GameplayState.Mode.PLAYER_TURN
        else
            self.currentMode = GameplayState.Mode.ENEMY_TURN
        end
        if self.player.isDead then
            self:triggerGameOver("PID_PLAYER TERMINATED.")
        end
    else
        print("[activateSubroutine] Action NOT taken (activation failed or was cancelled).") -- DEBUG
    end
end

function GameplayState:cancelTargeting()
    local config = self.config

    self:logMessage(
        "Targeting cancelled for " ..
        (self.targetingSubroutine and self.targetingSubroutine:getName() or "subroutine") .. ".",
        config.activeColors.text)
    self.targetingSubroutine = nil
    self.targetCursor.visible = false
    self.currentMode = GameplayState.Mode.PLAYER_TURN
    -- Player did not take an action, so actionTaken remains false
end

function GameplayState:startLooking()
    local config = self.config

    if self.currentMode ~= GameplayState.Mode.PLAYER_TURN then return end -- Can only look on your turn

    self.currentMode = GameplayState.Mode.LOOKING
    self.lookCursor.x = self.player.x
    self.lookCursor.y = self.player.y
    self.lookCursor.visible = true
    self:logMessage("LOOK MODE: Use arrows to move cursor. ESC or X to exit.", config.activeColors.accent)
end

function GameplayState:cancelLooking()
    local config = self.config

    self.lookCursor.visible = false
    self.currentMode = GameplayState.Mode.PLAYER_TURN
    self:logMessage("Exited Look Mode.", config.activeColors.text)
end

function GameplayState:logMessage(msg, color)
    local config = self.config

    if msg == nil then
        print("ERROR: logMessage called with nil message!")
        msg = "[SYSTEM] Error: Logged nil message." -- Provide a fallback string
    elseif type(msg) ~= "string" then
        print("ERROR: logMessage called with non-string message: " .. tostring(msg))
        msg = "[SYSTEM] Error: Logged non-string: " .. tostring(msg) -- Convert to string
    end

    table.insert(self.gameMessageLog, 1,
        { text = msg, color = color or config.activeColors.text, time = love.timer.getTime() })
    if #self.gameMessageLog > config.logMessageCount then
        table.remove(self.gameMessageLog) -- Removes the oldest, which is at the end now
    end
end

function GameplayState:checkForPickups(x, y)
    local config = self.config
    local fonts = self.resources:getFonts()

    print("checkForPickups called for x=" .. x .. ", y=" .. y) -- DEBUG
    local entityOnTile = self.map:getEntityAt(x, y)

    if entityOnTile then -- DEBUG
        print("Entity found on tile: " ..
            entityOnTile.name ..
            ", isPickup: " .. tostring(entityOnTile.isPickup) .. ", isPlayer: " .. tostring(entityOnTile == self.player))
    else
        print("No entity found on tile " .. x .. "," .. y .. " by map:getEntityAt")
        return false
    end

    -- The player itself will be an entity on its tile. We need to find OTHER entities.
    -- A better approach for map:getEntityAt might be to return a list of entities,
    -- or have a specific map:getPickupAt(x,y)
    -- For now, let's iterate if map:getEntityAt might return the player.
    -- However, map:getEntityAt as written should return the *first* one it finds.
    -- If pickups are added to map.entities *after* player, player might be found first.
    -- Let's refine map:getEntityAt or how we use it.

    -- TEMPORARY REFINEMENT: Iterate through all entities on map to find a pickup at x,y
    local pickupFound = nil
    for _, entity in ipairs(self.map:getAllEntities()) do -- Assuming getAllEntities() returns map.entities
        if entity.x == x and entity.y == y and entity.isPickup and entity ~= self.player then
            pickupFound = entity
            print("Actually found pickup via iteration: " .. pickupFound.name) -- DEBUG
            break
        end
    end
    entityOnTile =
        pickupFound                                                                                -- Use the one found by iteration

    if entityOnTile and entityOnTile.isPickup and entityOnTile ~= self.player then                 -- Redundant check for entityOnTile.isPickup if loop worked
        print("Processing pickup: " .. entityOnTile.name .. ", type: " .. entityOnTile.pickupType) -- DEBUG
        if entityOnTile.pickupType == "SUBROUTINE_CACHE" then
            ServiceLocator.get("sfx").play("pickup_subroutine_cache")
            self:logMessage("Found a SUBROUTINE_CACHE!", config.activeColors.pickup)
            self.map:removeEntity(entityOnTile)
            self.pausedForChoice = true
            self.stateManager:push("subroutine_choice", self.player)
            return true
        elseif entityOnTile.pickupType == "DATA_FRAGMENT" then
            local value = entityOnTile.data.value or 10
            self.player.dataFragments = self.player.dataFragments + value
            ServiceLocator.get("sfx").play("pickup_data_fragment")
            self:logMessage(string.format("Collected DATA_FRAGMENT (%d). Total: %d", value, self.player.dataFragments),
                config.activeColors.pickup)
            self.map:removeEntity(entityOnTile)
            return true
        elseif entityOnTile.pickupType == "REPAIR_NANITES" then
            local healAmount = entityOnTile.data.value
            self.player.hp = math.min(self.player.maxHp, self.player.hp + healAmount)
            ServiceLocator.get("sfx").play("pickup_health")
            self:logMessage(string.format("Repaired %d INTEGRITY by Nanites.", healAmount), config.activeColors.player)
            self.map:removeEntity(entityOnTile)
            if ParticleFX then
                ParticleFX.spawnFloatingText(self, "+" .. healAmount .. " HP", self.player.x,
                    self.player.y, { color = config.activeColors.player })
            end
            return true
        elseif entityOnTile.pickupType == "ENERGY_CELL" then
            local cpuAmount = entityOnTile.data.value
            self.player.cpuCycles = math.min(self.player.maxCPUCycles, self.player.cpuCycles + cpuAmount)
            ServiceLocator.get("sfx").play("pickup_cpu")
            self:logMessage(string.format("Restored %d CPU_CYCLES from Energy Cell.", cpuAmount),
                config.activeColors.player)
            self.map:removeEntity(entityOnTile)
            if ParticleFX then
                ParticleFX.spawnFloatingText(self, "+" .. cpuAmount .. " CPU", self.player.x,
                    self.player.y, { color = { 0.4, 0.7, 1, 1 } })
            end
            return true
        end
    else
        if entityOnTile and entityOnTile ~= self.player then
            print("Entity on tile is not a pickup or is player: " .. entityOnTile.name) -- DEBUG
        elseif not entityOnTile then
            print("Still no pickup entity found at player location after iteration.")   -- DEBUG
        end
    end
    return false
end

function GameplayState:tryActivateSubroutine(slotIndex)
    local config = self.config

    if self.player.actionTaken then
        self:logMessage("Cannot use subroutine: Action already taken this turn.", { 1, 1, 0.5, 1 })
        return
    end
    if not self.player.subroutines[slotIndex] then
        self:logMessage("No subroutine in slot " .. slotIndex .. ".", config.activeColors.text)
        return
    end

    local subToUse = self.player.subroutines[slotIndex]
    local can, reason = subToUse:canActivate(self.player)

    if not can then
        self:logMessage(reason, { 1, 1, 0.5, 1 })
        return
    end

    -- If subroutine needs targeting, enter targeting mode. Otherwise, activate directly.
    local effectData, _ = subToUse:getCurrentEffectData()
    if effectData.targetType == "enemy_at_cursor" or effectData.targetType == "aoe_at_cursor" then
        self:startTargeting(subToUse)
    else
        -- Self-cast or player-centered AoE
        self:activateSubroutine(subToUse, self.player) -- Pass player as target for self-cast
    end
end

function GameplayState:_updateAnimations(dt)
    -- Update all animation systems
    if self.animationManager then
        self.animationManager:update(dt)
    end

    -- Update map animations
    if self.map then
        if self.map.updateAnimations then
            self.map:updateAnimations(dt)
        end
        -- Add corruption effects based on system corruption level
        if self.systemCorruption and self.map.addCorruptionEffects then
            self.map:addCorruptionEffects(self.systemCorruption:getCorruptionPercent())
        end
    end

    -- Update weather effects
    self:updateWeatherEffects(dt)

    -- Update background effects
    self:updateBackgroundEffects(dt)
end

function GameplayState:updateWeatherEffects(dt)
    local corruptionLevel = self.systemCorruption:getCorruptionPercent()

    -- Determine weather type based on corruption
    if corruptionLevel < 20 then
        self.weatherEffects.type = "none"
        self.weatherEffects.intensity = 0
    elseif corruptionLevel < 50 then
        self.weatherEffects.type = "digital_rain"
        self.weatherEffects.intensity = math.min(0.3, corruptionLevel / 100)
    elseif corruptionLevel < 80 then
        self.weatherEffects.type = "data_storm"
        self.weatherEffects.intensity = math.min(0.6, corruptionLevel / 100)
    else
        self.weatherEffects.type = "glitch_cascade"
        self.weatherEffects.intensity = math.min(1.0, corruptionLevel / 100)
    end

    -- Update weather particles
    if self.weatherEffects.type ~= "none" then
        -- Add new particles
        if love.math.random() < self.weatherEffects.intensity * 0.5 then
            table.insert(self.weatherEffects.particles, {
                x = love.math.random(0, self.gameViewport.width),
                y = -10,
                vx = love.math.random(-20, 20),
                vy = love.math.random(50, 150),
                life = love.math.random(2, 5),
                maxLife = love.math.random(2, 5),
                char = self:getWeatherChar(),
                color = self:getWeatherColor()
            })
        end

        -- Update existing particles
        for i = #self.weatherEffects.particles, 1, -1 do
            local p = self.weatherEffects.particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - dt

            if p.life <= 0 or p.y > self.gameViewport.height + 50 then
                table.remove(self.weatherEffects.particles, i)
            end
        end
    end
end

function GameplayState:getWeatherChar()
    if self.weatherEffects.type == "digital_rain" then
        return Helpers.choice({ "0", "1", "|", "!", "." })
    elseif self.weatherEffects.type == "data_storm" then
        return Helpers.choice({ "▓", "▒", "░", "█", "▄", "▀" })
    elseif self.weatherEffects.type == "glitch_cascade" then
        return Helpers.choice({ "@", "#", "%", "&", "*", "~", "^" })
    end
    return "·"
end

function GameplayState:getWeatherColor()
    if self.weatherEffects.type == "digital_rain" then
        return { 0.3, 1, 0.3, love.math.random(0.3, 0.8) }
    elseif self.weatherEffects.type == "data_storm" then
        return { 0.8, 0.3, 1, love.math.random(0.4, 0.9) }
    elseif self.weatherEffects.type == "glitch_cascade" then
        return { love.math.random(0.5, 1), love.math.random(0.2, 0.8), love.math.random(0.3, 1), love.math.random(0.6, 1) }
    end
    return { 1, 1, 1, 0.5 }
end

function GameplayState:updateBackgroundEffects(dt)
    -- Pulsing background based on player health
    if self.player then
        local healthPercent = self.player.hp / self.player.maxHp
        if healthPercent < 0.3 then
            local pulse = math.sin(love.timer.getTime() * 4) * 0.1 + 0.1
            table.insert(self.backgroundEffects, {
                type = "health_warning",
                intensity = pulse * (1 - healthPercent),
                color = { 1, 0.2, 0.2, pulse * 0.3 }
            })
        end
    end

    -- System corruption background distortion
    local corruptionLevel = self.systemCorruption:getCorruptionPercent()
    if corruptionLevel > 40 then
        local distortion = math.sin(love.timer.getTime() * 2) * (corruptionLevel / 100) * 0.2
        table.insert(self.backgroundEffects, {
            type = "corruption_distortion",
            intensity = distortion,
            color = { 0.8, 0.2, 0.8, distortion * 0.4 }
        })
    end

    -- Clear old effects
    self.backgroundEffects = {}
end

function GameplayState:update(dt)
    BaseState.update(self, dt)

    local config = self.config

    if self.paused then return end

    if not self.map or not self.player or self.gameOver then
        return
    end

    -- Update animation time
    self.uiAnimationTime = self.uiAnimationTime + dt

    -- Update all managers
    if self.particleSystem then
        self.particleSystem:update(dt)
    end

    if self.animationManager then
        self.animationManager:update(dt)
    end

    if self.systemCorruption then
        self.systemCorruption:update(dt)
    end

    if self.cameraManager then
        self.cameraManager:update(dt, self.player, self.gameViewport, self.map)
    end

    if self.hudManager then
        self.hudManager:update(dt)
    end

    self:_updateAnimations(dt)

    if self.player.isDead then
        self:triggerGameOver("PID_PLAYER TERMINATED.")
        return
    end

    -- Handle enemy action delay
    if self.isEnemyActionResolving then
        self.enemyActionDelayTimer = self.enemyActionDelayTimer - dt
        if self.enemyActionDelayTimer <= 0 then
            local previouslyActing = self.actorWhoJustActed and self.actorWhoJustActed.name or "N/A"
            print(string.format("[GS Update] Delay ENDED for %s. Resetting isEnemyActionResolving (was true).",
                previouslyActing))
            self.isEnemyActionResolving = false
            self.actorWhoJustActed = nil

            self.turnManager:nextTurn()

            if self.turnManager.isPlayerTurn then
                self.currentMode = GameplayState.Mode.PLAYER_TURN
                self:calculateAllEnemyIntents()
                print("[GS Update] Player's turn. Enemy intents calculated.")
            else
                self.currentMode = GameplayState.Mode.ENEMY_TURN
                -- No need to calculate intent here, it's done when it becomes player's turn
            end
        end
    elseif self.currentMode == GameplayState.Mode.ENEMY_TURN then -- Time for an enemy to ACTUALLY act
        local currentActor = self.turnManager:getCurrentActor()
        if currentActor and currentActor ~= self.player and not currentActor.isDead then
            print(string.format("[GS Update] Enemy %s EXECUTING ACTION. currentMode=%s", currentActor.name,
                self.currentMode))

            -- Call act WITHOUT isPrecomputationPhase, or call a specific execute method
            if currentActor.executePlannedAction then
                currentActor:executePlannedAction(self.player, self.map, self.entities, self)
            else
                -- Fallback if no executePlannedAction (shouldn't happen if all enemies updated)
                currentActor:act(self.player, self.map, self.entities, self, false)
            end

            if not self.player.isDead then
                self.actorWhoJustActed = currentActor
                self.isEnemyActionResolving = true -- Start post-action delay
                self.enemyActionDelayTimer = self.enemyActionDelayDuration
            end
        elseif (currentActor and currentActor.isDead) or not currentActor then
            print(string.format("[GS Update] Skipping turn for %s (dead or nil). Advancing turn. currentMode=%s",
                currentActor and currentActor.name or "N/A", self.currentMode))
            self.turnManager:nextTurn()
            if self.turnManager.isPlayerTurn then
                self.currentMode = GameplayState.Mode.PLAYER_TURN
                self:calculateAllEnemyIntents()
            else
                self.currentMode = GameplayState.Mode.ENEMY_TURN
            end
        end
    elseif self.currentMode == GameplayState.Mode.PLAYER_TURN then
        -- Player's turn, awaiting input. Intents should already be calculated and displayed.
    end

    self:removeDeadEntities()

    -- Update log message display times (same as before)
    self.logTimer = self.logTimer + dt
    if self.logTimer > 1 then
        self.logTimer = 0
        local currentTime = love.timer.getTime()
        for i = #self.gameMessageLog, 1, -1 do
            if currentTime - self.gameMessageLog[i].time > config.logMessageDuration then
                table.remove(self.gameMessageLog, i)
            end
        end
    end
end

function GameplayState:triggerScreenShake(intensity)
    if self.animationManager then
        self.animationManager:addScreenShake(intensity, 0.3)
    end
    -- Also trigger camera shake for compatibility
    if self.cameraManager then
        self.cameraManager:triggerShake(intensity)
    end
end

function GameplayState:centerCameraOnPlayer(instant)
    if not (self.player and self.map and self.cameraManager and self.viewportInitialized) then
        print("centerCameraOnPlayer: Missing player, map, cameraManager, or viewport not initialized.")
        return
    end
    -- DO NOT call calculateGameViewport from here.
    self.cameraManager:centerOn(self.player.x, self.player.y, self.gameViewport, self.map, instant)
    print(string.format("Camera centered on player (%d,%d) with instant=%s", self.player.x, self.player.y,
        tostring(instant)))
end

function GameplayState:showDamageEffect(entity, damage, damageType)
    if not self.animationManager or not entity then return end

    local config = self.config
    local fonts = self.resources:getFonts()

    local screenX = (entity.animX or entity.x) * config.spriteSize + config.spriteSize / 2
    local screenY = (entity.animY or entity.y) * config.spriteSize + config.spriteSize / 2

    -- Convert to screen coordinates if needed
    if self.gameViewport then
        screenX = screenX + self.gameViewport.x
        screenY = screenY + self.gameViewport.y
    end

    local color = { 1, 0.3, 0.3, 1 }
    local text = "-" .. damage

    if damageType == "heal" then
        color = { 0.3, 1, 0.3, 1 }
        text = "+" .. damage
    elseif damageType == "shield" then
        color = { 0.3, 0.7, 1, 1 }
        text = "BLOCKED"
    elseif damageType == "critical" then
        color = { 1, 0.8, 0.2, 1 }
        text = "CRIT! -" .. damage
        self.animationManager:addScreenShake(8, 0.4)
    end

    self.animationManager:addFloatingText(text, screenX, screenY, color, fonts.medium, {
        vy = -80,
        duration = 1.5,
        gravity = 30
    })

    -- Add impact effect
    self.animationManager:addPulseEffect(screenX, screenY, 30, color, 0.5)

    -- Screen flash for significant damage
    if damage > (entity.maxHp or 100) * 0.3 then
        self.animationManager:addFlashEffect(color, 0.4, 0.2)
    end
end

function GameplayState:calculateAllEnemyIntents()
    print("[GS] Calculating all enemy intents...")
    for _, entity in ipairs(self.entities) do
        if entity ~= self.player and not entity.isDead and entity.act then
            -- Call act in "precomputation" mode.
            -- The 'act' function should now populate entity.plannedAction
            entity:act(self.player, self.map, self.entities, self, true)
            if entity.plannedAction then
                print(string.format("  - %s plans: %s", entity.name,
                    entity.plannedAction.description or entity.plannedAction.type))
            else
                print(string.format("  - %s has no plan.", entity.name))
            end
        end
    end
end

function GameplayState:drawGameOver()
    local config = self.config
    local fonts = self.resources:getFonts()

    local screenW, screenH = love.graphics.getDimensions()

    -- Animated overlay
    local pulseAlpha = 0.6 + 0.1 * math.sin(love.timer.getTime() * 2)
    love.graphics.setColor(0.8, 0.1, 0.1, pulseAlpha)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main game over panel
    local panelW, panelH = 400, 200
    local panelX, panelY = (screenW - panelW) / 2, (screenH - panelH) / 2

    UIHelpers.drawPanel(panelX, panelY, panelW, panelH, "SYSTEM_FAILURE", "highlighted")

    -- Game over text with glow
    UIHelpers.drawTextWithGlow("PROCESS TERMINATED", panelX + panelW / 2, panelY + panelH / 2 - 20,
        fonts.large, config.activeColors.highlight, "center")

    UIHelpers.drawTextWithGlow(self.gameOverMessage, panelX + panelW / 2, panelY + panelH / 2 + 10,
        fonts.medium, config.activeColors.text, "center")

    UIHelpers.drawTextWithGlow("Press ENTER to return to Main Menu", panelX + panelW / 2, panelY + panelH / 2 + 40,
        fonts.small, config.activeColors.ui_text_dim, "center")
end

function GameplayState:draw()
    if not self.visible then return end

    BaseState.draw(self)

    if not self.map or not self.player then
        love.graphics.print("Initializing level...", 100, 100)
        return
    end

    -- Draw background effects
    self:drawBackgroundEffects()

    -- === Game World Drawing ===
    love.graphics.setScissor(self.gameViewport.x, self.gameViewport.y,
        self.gameViewport.width, self.gameViewport.height)

    -- Get camera offsets with shake
    local mapDrawX, mapDrawY = self.cameraManager:getDrawOffsets()
    if self.animationManager then
        local shakeX, shakeY = self.animationManager:getShakeOffset()
        mapDrawX = mapDrawX + shakeX
        mapDrawY = mapDrawY + shakeY
    end

    love.graphics.push()
    love.graphics.translate(self.gameViewport.x, self.gameViewport.y)

    -- Draw map with FOV
    if self.map.drawWithFov then
        self.map:drawWithFov(mapDrawX, mapDrawY, self.config.spriteSize,
            self.player.x, self.player.y, self.fovRadius)
    else
        -- Fallback to regular drawing
        self.map:draw(mapDrawX, mapDrawY, self.config.spriteSize)
    end

    -- Draw particle system
    if self.particleSystem then
        self.particleSystem:draw(mapDrawX, mapDrawY)
    end

    -- Draw weather effects
    self:drawWeatherEffects(mapDrawX, mapDrawY)

    -- Draw enemy intents with animations
    if self.currentMode == GameplayState.Mode.PLAYER_TURN or self.currentMode == GameplayState.Mode.TARGETING then
        for _, entity in ipairs(self.entities) do
            if entity ~= self.player and
                not entity.isDead and
                entity.plannedAction and
                self.map:isInFov(entity.x, entity.y) then
                self:drawAnimatedEnemyIntent(entity, mapDrawX, mapDrawY)
            end
        end
    end

    -- Draw cursors
    if self.currentMode == GameplayState.Mode.LOOKING and self.lookCursor.visible then
        self:drawAnimatedCursor(self.lookCursor, mapDrawX, mapDrawY,
            { 0.3, 0.9, 0.9, 0.8 }, "SCAN")
    end

    if self.currentMode == GameplayState.Mode.TARGETING and self.targetCursor.visible then
        self:drawAnimatedCursor(self.targetCursor, mapDrawX, mapDrawY, { 1.0, 0.3, 0.3, 0.8 }, "TARGET")
        self:drawEnhancedTargetingUI(mapDrawX, mapDrawY, self.config.spriteSize)
    end

    love.graphics.pop()
    love.graphics.setScissor()

    -- Draw animation effects
    if self.animationManager then
        self.animationManager:draw()
    end

    -- =Draw HUD
    if self.hudManager then
        self.hudManager:draw(
            self.player, self.map, self.turnManager, self.gameMessageLog,
            self.currentMode, self.lookCursor, self.targetCursor,
            self.targetingSubroutine, self.currentSector, self.currentFloorInSector,
            self.systemCorruption:getCorruptionPercent()
        )
    end

    if self.gameOver then
        self:drawGameOver()
    end
end

function GameplayState:drawBackgroundEffects()
    for _, effect in ipairs(self.backgroundEffects) do
        if effect.type == "health_warning" then
            love.graphics.setColor(effect.color)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        elseif effect.type == "corruption_distortion" then
            love.graphics.setColor(effect.color)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
        end
    end
end

function GameplayState:drawWeatherEffects(offsetX, offsetY)
    local fonts = self.resources:getFonts()

    if #self.weatherEffects.particles == 0 then return end

    love.graphics.setFont(fonts.small)
    for _, particle in ipairs(self.weatherEffects.particles) do
        love.graphics.setColor(particle.color)
        love.graphics.print(particle.char, particle.x + offsetX, particle.y + offsetY)
    end
end

function GameplayState:drawAnimatedCursor(cursor, mapOffsetX, mapOffsetY, color, label)
    local config = self.config
    local fonts = self.resources:getFonts()

    local cursorScreenX = mapOffsetX + (cursor.x - 1) * config.spriteSize
    local cursorScreenY = mapOffsetY + (cursor.y - 1) * config.spriteSize
    local time = love.timer.getTime()

    -- Multi-layered animated cursor
    local pulseOuter = 0.8 + 0.4 * math.sin(time * 4)
    local pulseInner = 0.6 + 0.6 * math.sin(time * 6)
    local rotation = time * 2

    -- Outer ring
    love.graphics.setColor(color[1] * pulseOuter, color[2] * pulseOuter, color[3] * pulseOuter, color[4] * 0.6)
    love.graphics.push()
    love.graphics.translate(cursorScreenX + config.spriteSize / 2, cursorScreenY + config.spriteSize / 2)
    love.graphics.rotate(rotation)
    love.graphics.circle("line", 0, 0, config.spriteSize / 2 + 4)
    love.graphics.pop()

    -- Inner ring
    love.graphics.setColor(color[1] * pulseInner, color[2] * pulseInner, color[3] * pulseInner, color[4])
    love.graphics.push()
    love.graphics.translate(cursorScreenX + config.spriteSize / 2, cursorScreenY + config.spriteSize / 2)
    love.graphics.rotate(-rotation * 0.7)
    love.graphics.circle("line", 0, 0, config.spriteSize / 3)
    love.graphics.pop()

    -- Corner brackets with animation
    local cornerSize = config.spriteSize / 3
    local cornerOffset = math.sin(time * 8) * 2
    local x, y, size = cursorScreenX - cornerOffset, cursorScreenY - cornerOffset, config.spriteSize + cornerOffset * 2

    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)

    -- Animated corner brackets
    love.graphics.line(x, y, x + cornerSize, y)
    love.graphics.line(x, y, x, y + cornerSize)
    love.graphics.line(x + size - cornerSize, y, x + size, y)
    love.graphics.line(x + size, y, x + size, y + cornerSize)
    love.graphics.line(x, y + size - cornerSize, x, y + size)
    love.graphics.line(x, y + size, x + cornerSize, y + size)
    love.graphics.line(x + size, y + size - cornerSize, x + size, y + size)
    love.graphics.line(x + size - cornerSize, y + size, x + size, y + size)

    love.graphics.setLineWidth(1)

    -- Animated label
    if label then
        love.graphics.setFont(fonts.small)
        local labelAlpha = 0.8 + 0.2 * math.sin(time * 3)
        love.graphics.setColor(color[1], color[2], color[3], labelAlpha)
        love.graphics.print(label, cursorScreenX + config.spriteSize + 6, cursorScreenY - 4)
    end
end

function GameplayState:drawEnhancedTargetingUI(mapWorldOffsetX, mapWorldOffsetY, visualTileSize)
    local config = self.config

    local targetScreenX = mapWorldOffsetX + (self.targetCursor.x - 1) * visualTileSize
    local targetScreenY = mapWorldOffsetY + (self.targetCursor.y - 1) * visualTileSize
    local time = love.timer.getTime()

    local effectData, _ = self.targetingSubroutine:getCurrentEffectData()
    local range = effectData.range or 0
    local aoeRadius = effectData.aoeRadius or 0

    -- Enhanced line of sight indicator
    local losColor
    local hasLOS = Helpers.hasLineOfSight(self.player.x, self.player.y, self.targetCursor.x, self.targetCursor.y,
        function(lx, ly) return not self.map:isTransparent(lx, ly) end)

    if hasLOS then
        losColor = { 0.3, 1.0, 0.8, 0.8 } -- Clear LOS
    else
        losColor = { 1.0, 0.3, 0.3, 0.8 } -- Blocked LOS
    end

    local playerScreenX = mapWorldOffsetX + (self.player.x - 1) * visualTileSize + visualTileSize / 2
    local playerScreenY = mapWorldOffsetY + (self.player.y - 1) * visualTileSize + visualTileSize / 2
    local cursorCenterX = targetScreenX + visualTileSize / 2
    local cursorCenterY = targetScreenY + visualTileSize / 2

    -- Multi-layered targeting line with animation
    local pulse = 0.6 + 0.4 * math.sin(time * 8)
    local lineOffset = math.sin(time * 10) * 2

    -- Background line
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.setLineWidth(5)
    love.graphics.line(playerScreenX, playerScreenY, cursorCenterX, cursorCenterY)

    -- Main targeting line with pulse
    love.graphics.setColor(losColor[1] * pulse, losColor[2] * pulse, losColor[3] * pulse, losColor[4])
    love.graphics.setLineWidth(3)
    love.graphics.line(playerScreenX + lineOffset, playerScreenY, cursorCenterX + lineOffset, cursorCenterY)

    -- Animated energy flow along the line
    local distance = math.sqrt((cursorCenterX - playerScreenX) ^ 2 + (cursorCenterY - playerScreenY) ^ 2)
    local flowCount = math.floor(distance / 20)

    for i = 1, flowCount do
        local t = (i / flowCount + time * 2) % 1
        local flowX = playerScreenX + (cursorCenterX - playerScreenX) * t
        local flowY = playerScreenY + (cursorCenterY - playerScreenY) * t

        love.graphics.setColor(losColor[1], losColor[2], losColor[3], 0.8 * (1 - t))
        love.graphics.circle("fill", flowX, flowY, 3 * (1 - t))
    end

    love.graphics.setLineWidth(1)

    -- Enhanced AoE preview with ripple effects
    if effectData.targetType == "aoe_at_cursor" and aoeRadius > 0 then
        local aoeColor = config.activeColors.highlight

        -- Multiple ripple layers
        for layer = 1, 3 do
            local layerTime = time * 2 + layer * 0.5
            local rippleRadius = (aoeRadius + math.sin(layerTime) * 0.3) * visualTileSize
            local rippleAlpha = 0.15 + 0.1 * math.sin(layerTime * 2)

            love.graphics.setColor(aoeColor[1], aoeColor[2], aoeColor[3], rippleAlpha)
            love.graphics.circle("line", cursorCenterX, cursorCenterY, rippleRadius)
        end

        -- Fill area with animated pattern
        for dx = -aoeRadius, aoeRadius do
            for dy = -aoeRadius, aoeRadius do
                if math.abs(dx) + math.abs(dy) <= aoeRadius then
                    local tileScreenX = mapWorldOffsetX + (self.targetCursor.x + dx - 1) * visualTileSize
                    local tileScreenY = mapWorldOffsetY + (self.targetCursor.y + dy - 1) * visualTileSize

                    local distance = math.sqrt(dx * dx + dy * dy)
                    local tilePulse = 0.2 + 0.2 * math.sin(time * 4 - distance * 0.8)
                    local tileRotation = time + distance * 0.2

                    love.graphics.push()
                    love.graphics.translate(tileScreenX + visualTileSize / 2, tileScreenY + visualTileSize / 2)
                    love.graphics.rotate(tileRotation)
                    love.graphics.setColor(aoeColor[1] * tilePulse, aoeColor[2] * tilePulse, aoeColor[3] * tilePulse, 0.3)
                    love.graphics.rectangle("fill", -visualTileSize / 2, -visualTileSize / 2, visualTileSize,
                        visualTileSize)
                    love.graphics.pop()
                end
            end
        end
    end

    -- Range indicator
    if range > 0 then
        love.graphics.setColor(losColor[1], losColor[2], losColor[3], 0.2)
        love.graphics.circle("line", playerScreenX, playerScreenY, range * visualTileSize)
    end
end

function GameplayState:drawAnimatedEnemyIntent(enemy, mapOffsetX, mapOffsetY)
    local config = self.config
    local fonts = self.resources:getFonts()

    if not enemy.plannedAction then return end

    local action = enemy.plannedAction
    local time = love.timer.getTime()
    local enemyScreenX = mapOffsetX + (enemy.x - 1) * config.spriteSize + config.spriteSize / 2
    local enemyScreenY = mapOffsetY + (enemy.y - 1) * config.spriteSize + config.spriteSize / 2

    -- Intent type colors
    local intentColor = { 1, 0.7, 0.3, 0.8 }
    if action.type == "attack" or action.type == "ranged_attack" then
        intentColor = { 1, 0.3, 0.3, 0.8 }
    elseif action.type == "move" then
        intentColor = { 0.3, 0.8, 1, 0.8 }
    elseif action.type == "buff_self" or action.type == "encrypt_ally" then
        intentColor = { 0.3, 1, 0.3, 0.8 }
    end

    -- Animated intent indicator above enemy
    local indicatorY = enemyScreenY - config.spriteSize - 10
    local pulse = 0.8 + 0.4 * math.sin(time * 4)
    local bounce = math.sin(time * 6) * 2

    -- Intent background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.circle("fill", enemyScreenX, indicatorY + bounce, 12)

    -- Intent icon with pulse
    love.graphics.setColor(intentColor[1] * pulse, intentColor[2] * pulse, intentColor[3] * pulse, intentColor[4])
    love.graphics.setFont(fonts.medium)

    local intentIcon = "?"
    if action.type == "attack" or action.type == "ranged_attack" then
        intentIcon = "⚔"
    elseif action.type == "move" then
        intentIcon = "→"
    elseif action.type == "buff_self" then
        intentIcon = "◈"
    elseif action.type == "encrypt_ally" then
        intentIcon = "+"
    elseif action.type == "pulse" then
        intentIcon = "※"
    elseif action.type == "leech_cpu" then
        intentIcon = "⚡"
    end

    love.graphics.printf(intentIcon, enemyScreenX - 8, indicatorY + bounce - 8, 16, "center")

    -- Movement/attack target indicators
    if (action.type == "move" or action.type == "attack") and action.targetPos then
        if self.map:isInFov(action.targetPos.x, action.targetPos.y) then
            local targetScreenX = mapOffsetX + (action.targetPos.x - 1) * config.spriteSize + config.spriteSize / 2
            local targetScreenY = mapOffsetY + (action.targetPos.y - 1) * config.spriteSize + config.spriteSize / 2

            -- Animated connection line
            local lineAlpha = 0.4 + 0.3 * math.sin(time * 3)
            love.graphics.setColor(intentColor[1], intentColor[2], intentColor[3], lineAlpha)
            love.graphics.setLineWidth(2)

            -- Dashed line effect
            local distance = math.sqrt((targetScreenX - enemyScreenX) ^ 2 + (targetScreenY - enemyScreenY) ^ 2)
            local dashCount = math.floor(distance / 10)

            for i = 0, dashCount do
                if i % 2 == 0 then
                    local t1 = i / dashCount
                    local t2 = math.min((i + 0.5) / dashCount, 1)
                    local x1 = enemyScreenX + (targetScreenX - enemyScreenX) * t1
                    local y1 = enemyScreenY + (targetScreenY - enemyScreenY) * t1
                    local x2 = enemyScreenX + (targetScreenX - enemyScreenX) * t2
                    local y2 = enemyScreenY + (targetScreenY - enemyScreenY) * t2
                    love.graphics.line(x1, y1, x2, y2)
                end
            end

            love.graphics.setLineWidth(1)

            -- Target marker with animation
            local targetPulse = 0.7 + 0.5 * math.sin(time * 5)
            love.graphics.setColor(intentColor[1] * targetPulse, intentColor[2] * targetPulse,
                intentColor[3] * targetPulse, 0.8)
            love.graphics.circle("line", targetScreenX, targetScreenY, config.spriteSize / 3)

            -- Rotating target brackets
            love.graphics.push()
            love.graphics.translate(targetScreenX, targetScreenY)
            love.graphics.rotate(time * 2)
            local bracketSize = config.spriteSize / 4
            love.graphics.line(-bracketSize, -bracketSize, -bracketSize / 2, -bracketSize)
            love.graphics.line(-bracketSize, -bracketSize, -bracketSize, -bracketSize / 2)
            love.graphics.line(bracketSize, -bracketSize, bracketSize / 2, -bracketSize)
            love.graphics.line(bracketSize, -bracketSize, bracketSize, -bracketSize / 2)
            love.graphics.line(-bracketSize, bracketSize, -bracketSize / 2, bracketSize)
            love.graphics.line(-bracketSize, bracketSize, -bracketSize, bracketSize / 2)
            love.graphics.line(bracketSize, bracketSize, bracketSize / 2, bracketSize)
            love.graphics.line(bracketSize, bracketSize, bracketSize, bracketSize / 2)
            love.graphics.pop()
        end
    end

    -- AoE indicators
    if action.aoeRadius and action.targetPos then
        local aoeAlpha = 0.2 + 0.2 * math.sin(time * 2)
        love.graphics.setColor(intentColor[1], intentColor[2], intentColor[3], aoeAlpha)

        for dx = -action.aoeRadius, action.aoeRadius do
            for dy = -action.aoeRadius, action.aoeRadius do
                local aoeTileX, aoeTileY = action.targetPos.x + dx, action.targetPos.y + dy
                if self.map:isInFov(aoeTileX, aoeTileY) then
                    local tileScreenX = mapOffsetX + (aoeTileX - 1) * config.spriteSize
                    local tileScreenY = mapOffsetY + (aoeTileY - 1) * config.spriteSize

                    -- Animated AoE tiles
                    local tileTime = time * 3 + (dx + dy) * 0.2
                    local tileScale = 0.8 + 0.2 * math.sin(tileTime)

                    love.graphics.push()
                    love.graphics.translate(tileScreenX + config.spriteSize / 2, tileScreenY + config.spriteSize / 2)
                    love.graphics.scale(tileScale, tileScale)
                    love.graphics.rectangle("fill", -config.spriteSize / 2, -config.spriteSize / 2, config.spriteSize,
                        config.spriteSize)
                    love.graphics.pop()
                end
            end
        end
    end

    -- Description text with typewriter effect (for dramatic effect)
    if action.description then
        love.graphics.setFont(fonts.small)
        local textY = indicatorY - 20
        local textAlpha = 0.7 + 0.3 * math.sin(time * 2)
        love.graphics.setColor(intentColor[1], intentColor[2], intentColor[3], textAlpha)

        -- Text background
        local textWidth = fonts.small:getWidth(action.description)
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", enemyScreenX - textWidth / 2 - 4, textY - 2, textWidth + 8,
            fonts.small:getHeight() + 4)

        -- Animated text
        love.graphics.setColor(intentColor[1] * textAlpha, intentColor[2] * textAlpha, intentColor[3] * textAlpha, 1)
        love.graphics.printf(action.description, enemyScreenX - textWidth / 2, textY, textWidth, "center")
    end
end

function GameplayState:removeDeadEntities()
    local config = self.config
    local fonts = self.resources:getFonts()

    local entitiesToKeep = {}
    local mapEntitiesToKeep = {}

    for _, entity in ipairs(self.entities) do
        if not entity.isDead then
            table.insert(entitiesToKeep, entity)
        elseif entity.isDead and self.animationManager then
            -- Trigger death animation effects
            local screenX = entity.x * config.spriteSize + config.spriteSize / 2
            local screenY = entity.y * config.spriteSize + config.spriteSize / 2

            if self.gameViewport then
                screenX = screenX + self.gameViewport.x
                screenY = screenY + self.gameViewport.y
            end

            self.animationManager:addPulseEffect(screenX, screenY, 40, { 1, 0.5, 0.5, 1 }, 1.0)
            self.animationManager:addFloatingText("ELIMINATED", screenX, screenY, { 1, 0.8, 0.2, 1 }, fonts.small)
        end
    end

    self.entities = entitiesToKeep

    -- Handle map entities (keep corpses for visual effect)
    for _, entity in ipairs(self.map.entities) do
        if not entity.isDead then
            table.insert(mapEntitiesToKeep, entity)
        elseif entity.isDead and entity ~= self.player then
            table.insert(mapEntitiesToKeep, entity)
        end
    end

    if self.player.isDead then
        local playerFoundInMapEntities = false
        for _, e in ipairs(mapEntitiesToKeep) do
            if e == self.player then
                playerFoundInMapEntities = true
                break
            end
        end
        if not playerFoundInMapEntities then
            table.insert(mapEntitiesToKeep, self.player)
        end
    end

    self.map.entities = mapEntitiesToKeep
    self.turnManager:setEntities(self.entities)
end

function GameplayState:triggerGameOver(message)
    if self.gameOver then return end -- Already game over

    self.gameOver = true
    self.gameOverMessage = message or "SYSTEM FAILURE."
    self:logMessage(self.gameOverMessage, { 1, 0, 0, 1 })
    print("GAME OVER: " .. self.gameOverMessage)
    if self.events then
        self.events:emit("game_over", {
            reason = message,
            sector = self.currentSector,
            floor = self.currentFloorInSector,
            totalFloorsCleared = self.totalFloorsCleared,
            finalStats = {
                hp = self.player.hp,
                maxHp = self.player.maxHp,
                dataFragments = self.player.dataFragments
            }
        })
    end
end

function GameplayState:triggerBossDefeatedRewards()
    local config = self.config
    print("Boss defeated! Granting major rewards.")
    self:logMessage("SECTOR " .. self.currentSector .. " GUARDIAN DEFEATED!", config.activeColors.highlight)

    -- 1. Full Heal & CPU Restore
    self.player.hp = self.player.maxHp
    self.player.cpuCycles = self.player.maxCPUCycles
    self:logMessage("Integrity and CPU Cycles fully restored.", config.activeColors.player)

    -- 2. Significant DATA_FRAGMENTS
    local fragmentReward = 100 + self.currentSector * 50
    self.player.dataFragments = self.player.dataFragments + fragmentReward
    self:logMessage("Acquired " .. fragmentReward .. " DATA_FRAGMENTS from Guardian core.", config.activeColors
        .pickup)

    -- 3. Guaranteed Subroutine Cache Choice
    -- For now, let's directly switch to SubroutineChoiceState.
    -- A more elaborate system might have a dedicated "Boss Reward State"
    -- that then leads to subroutine choice.
    self.pendingBossReward_SubroutineChoice = true -- Set flag

    -- Emit event
    if self.events then
        self.events:emit("boss_defeated", {
            sector = self.currentSector,
            floor = self.currentFloorInSector
        })
    end

    self.stateManager:swtich("subroutine_choice", self.player)
    -- When SubroutineChoiceState returns, GameplayState:resume() or :enter() will be called.
    -- The next level (initNewLevel) will be triggered *after* the choice is made and we return to gameplay.
    -- This means the initNewLevel in keypressed for exit won't run immediately after boss.
    -- This needs careful handling of game flow.

    -- Alternative: Store that a choice is pending, and offer it at start of next GameplayState:enter
    -- self.pendingBossRewardSubroutineChoice = true
end

function GameplayState:keypressed(key, scancode, isrepeat)
    -- Emit event for input tracking
    if self.events then
        self.events:emit("gameplay_input", {
            key = key,
            mode = self.currentMode,
            isGameOver = self.gameover
        })
    end

    -- Delegate to InputHandler
    return InputHandler.processKey(key, scancode, isrepeat, self)
end

function GameplayState:handleGameOverReturn()
    if self.stateManager then
        self.stateManager:switch("mainmenu")
    end
end

function GameplayState:leave()
    GlitchSwarmer.resetGlobalCount()
    print("Left GameplayState")

    -- Emit event
    if self.events then
        self.events:emit("gameplay_left", {
            currentSector = self.currentSector,
            currentFloor = self.currentFloorInSector,
            wasGameOver = self.gameOver
        })
    end

    self.gameMessageLog = {}

    BaseState.leave(self)
end

function GameplayState:calculateGameViewport()
    local screenW, screenH = config.nativeResolution.width, config.nativeResolution.height

    if screenW == 0 or screenH == 0 then
        print("[CALC_VIEWPORT] Warning: Native resolution dimensions are zero. Aborting calculation.")
        self.viewportInitialized = false
        return
    end

    -- Adjust these margins to be more reasonable for the 640x360 resolution
    local topMargin = 60    -- Space for top status bar (was 20, now more reasonable)
    local bottomMargin = 90 -- Space for bottom panels (was 40, now more for message log)
    local leftMargin = 0    -- No left sidebar for now
    local rightMargin = 200 -- Space for right sidebar (was 125, now 200 for better proportions)

    self.gameViewport.x = leftMargin
    self.gameViewport.y = topMargin
    self.gameViewport.width = screenW - leftMargin - rightMargin
    self.gameViewport.height = screenH - topMargin - bottomMargin

    -- Debug output to see what we're getting
    print(string.format("[CALC_VIEWPORT] Native screenW:%d, screenH:%d", screenW, screenH))
    print(string.format("  Margins - Top:%d, Bottom:%d, Left:%d, Right:%d", topMargin, bottomMargin, leftMargin,
        rightMargin))
    print(string.format("  Resulting Viewport: x=%d, y=%d, w=%d, h=%d",
        self.gameViewport.x, self.gameViewport.y, self.gameViewport.width, self.gameViewport.height))

    -- Sanity check - ensure viewport has reasonable dimensions
    if self.gameViewport.width < 200 or self.gameViewport.height < 150 then
        print("[CALC_VIEWPORT] WARNING: Viewport dimensions too small, adjusting...")
        -- Fall back to using most of the screen
        self.gameViewport.x = 0
        self.gameViewport.y = 50
        self.gameViewport.width = screenW - 180  -- Leave space for right sidebar
        self.gameViewport.height = screenH - 100 -- Leave space for top/bottom
        print(string.format("  Adjusted Viewport: x=%d, y=%d, w=%d, h=%d",
            self.gameViewport.x, self.gameViewport.y, self.gameViewport.width, self.gameViewport.height))
    end

    self.viewportInitialized = true
end

function GameplayState:resize(w, h)
    print(string.format("GameplayState:resize(%d, %d) called.", w, h))
    if w > 0 and h > 0 then
        self:calculateGameViewport()    -- Calculate new viewport
        self:centerCameraOnPlayer(true) -- Re-center camera based on new viewport
    end
end

return GameplayState
