-- src/core/WorldInitializer.lua
local Helpers = require 'src.utils.Helpers'
local AICoreDB = require "src.core.AICoreDB"
local Player = require "src.core.Player"
local Map = require "src.core.Map"
local TurnManager = require "src.core.managers.TurnManager"
local Pickup = require 'src.core.Pickup'

-- Enemy Requires (needed for spawning)
local SentryBot = require "src.core.enemies.SentryBot"
local DataLeech = require 'src.core.enemies.DataLeech'
local FirewallNode = require 'src.core.enemies.FirewallNode'
local GlitchSwarmer = require 'src.core.enemies.GlitchSwarmer'
local CipherSentinel = require 'src.core.enemies.CipherSentinel'
local BitRipper = require 'src.core.enemies.BitRipper'
local Sector1Guardian = require 'src.core.bosses.sector_1.Sector1Guardian'


local WorldInitializer = {}

-- Main function to set up a new game level or a completely new run.
-- gs: The GameplayState instance.
-- isNewRun: Boolean, true if this is the start of a brand new run.
function WorldInitializer.setupLevel(gs, isNewRun)
    print(string.format("[WorldInit] Setup Level. isNewRun: %s", tostring(isNewRun)))

    if isNewRun then
        print("  [WorldInit] Initializing NEW RUN specifics...")
        gs.currentSector = 1
        gs.currentFloorInSector = 0 
        gs.totalFloorsCleared = -1 
        gs.isNextFloorBoss = false
        GlitchSwarmer.resetGlobalCount()
        gs.gameMessageLog = {} -- Clear log only for a completely new run

        local selectedCoreId = _G.MetaProgress:getSelectedAICoreId()
        local selectedCoreData = AICoreDB.getById(selectedCoreId)
        if not selectedCoreData then
            print("  Warning: SelectedAICoreId '" .. tostring(selectedCoreId) .. "' not found. Defaulting.")
            selectedCoreData = AICoreDB.getById("standard_pid")
            _G.MetaProgress:setSelectedAICoreId("standard_pid")
        end
        
        gs.player = Player:new(0, 0, selectedCoreData) -- Position set after map gen
        
        if selectedCoreData.passivePerk and selectedCoreData.passivePerk.apply then
            if selectedCoreData.passivePerk.description then
                 gs:logMessage("Core Perk Active (" .. selectedCoreData.passivePerk.name .. "): " .. selectedCoreData.passivePerk.description, _G.Config.activeColors.pickup)
            end
        end
        gs.entities = {} 
        table.insert(gs.entities, gs.player)
        gs.turnManager = TurnManager:new(gs.player) -- New TurnManager for new run
    else
        print("  [WorldInit] Initializing NEXT LEVEL (existing run)...")
        local tempPlayer = gs.player 
        gs.entities = {}            
        table.insert(gs.entities, tempPlayer) 
        gs.player = tempPlayer
        -- TurnManager persists for the run, just update entities
    end

    gs.systemCorruption:resetForNewNode()

    if gs.isNextFloorBoss then
        gs.currentFloorInSector = gs.currentFloorInSector -- Stays same or use a specific boss floor number
        print(string.format("  [WorldInit] Boss Floor for Sector %d", gs.currentSector))
    else
        gs.currentFloorInSector = gs.currentFloorInSector + 1
        print(string.format("  [WorldInit] Sector %d, Floor %d (Regular)", gs.currentSector, gs.currentFloorInSector))
    end
    gs.totalFloorsCleared = gs.totalFloorsCleared + 1

    local generateAsBossFloor = gs.isNextFloorBoss
    gs.isNextFloorBoss = false -- Reset for the *next* transition

    -- Map Generation
    if generateAsBossFloor then
        WorldInitializer.generateBossMap(gs)
    else
        gs.map = Map:new(_G.Config.mapWidth, _G.Config.mapHeight)
    end
    if not gs.map or not gs.map.playerSpawn or not gs.map.playerSpawn.x then
        error("FATAL: Map generation failed or produced no playerSpawn!")
    end
    gs.player.x, gs.player.y = gs.map.playerSpawn.x, gs.map.playerSpawn.y
    gs.map:addEntity(gs.player)
    print(string.format("  [WorldInit] Player positioned at (%d,%d)", gs.player.x, gs.player.y))

    -- Spawn Entities & Pickups
    if generateAsBossFloor then
        WorldInitializer.spawnBossAndMinions(gs)
        gs.objective = "defeat_boss"
        gs.objectiveMet = false
        if gs.map.exitPortal then gs.map.exitPortal.active = false; gs.map.exitPortal.char = "O"; end
    else
        WorldInitializer.spawnEnemies(gs, 3 + gs.currentSector) 
        WorldInitializer.spawnPickups(gs, 1, 5, love.math.random(0,1), love.math.random(1,2))
        gs.objective = "find_exit"
        gs.objectiveMet = false 
        if gs.map.exitPortal then gs.map.exitPortal.active = true; gs.map.exitPortal.char = "X"; end
    end

    gs.turnManager:setEntities(gs.entities)
    print(string.format("  [WorldInit] TurnManager entities set. Count: %d", #gs.entities))

    gs.currentMode = gs.Mode.PLAYER_TURN -- Ensure correct mode
    gs:calculateAllEnemyIntents()
    gs:calculateGameViewport() -- This will call centerCameraOnPlayer via its own logic
    gs.map:computeFov(gs.player.x, gs.player.y, gs.fovRadius)
    -- gs:centerCameraOnPlayer(true) -- Already called by calculateGameViewport if viewportInitialized

    local nodeType = generateAsBossFloor and "(BOSS ENCOUNTER)" or ""
    local entryMessage = isNewRun and ("SYSTEM: " .. gs.player.name .. " initialized in Node.") or 
                                   string.format("ENTERING NODE: SECTOR %d, LEVEL %d %s", gs.currentSector, gs.currentFloorInSector, nodeType)
    gs:logMessage(entryMessage, _G.Config.activeColors.accent)
    
    gs.isEnemyActionResolving = false
    gs.enemyActionDelayTimer = 0
    gs.actorWhoJustActed = nil
    gs.gameOver = false 
    gs.isInitialized = true 
    print("[WorldInit] Level setup finished.")
end

-- Helper: Generate Boss Map (moved from GameplayState)
function WorldInitializer.generateBossMap(gs)
    print("  [WorldInit - generateBossMap] Start.")
    local bossMapW = math.floor(_G.Config.mapWidth * 0.7) -- Slightly larger boss maps
    local bossMapH = math.floor(_G.Config.mapHeight * 0.7)
    gs.map = Map:new(bossMapW, bossMapH) 
    if not gs.map.playerSpawn or not gs.map.playerSpawn.x then
        print("    Warning: Boss map from Map:new has no playerSpawn! Fallback needed.")
        if #gs.map.floorTiles > 0 then gs.map.playerSpawn = Helpers.deepCopy(gs.map.floorTiles[1])
        else gs.map.playerSpawn = {x = math.floor(bossMapW/2), y = math.floor(bossMapH/2)}; gs.map.tiles[gs.map.playerSpawn.y][gs.map.playerSpawn.x] = _G.Config.tile.FLOOR; end
    end
    if gs.map.exitPortal then gs.map.exitPortal.char = "O" end
    print(string.format("  [WorldInit - generateBossMap] Done. PlayerSpawn: (%s,%s)", tostring(gs.map.playerSpawn.x), tostring(gs.map.playerSpawn.y)))
end

-- Helper: Spawn Boss and Minions (moved from GameplayState)
function WorldInitializer.spawnBossAndMinions(gs)
    print("  [WorldInit - spawnBossAndMinions] Start.")
    gs.currentBossEntity = nil 
    if gs.player and gs.map.playerSpawn then
        local bossX, bossY = math.floor(gs.map.width / 2), math.floor(gs.map.height / 3)
        -- ... (refined boss placement logic as before) ...
        local boss = Sector1Guardian:new(bossX, bossY) -- TODO: Choose boss by gs.currentSector
        gs.map:addEntity(boss); table.insert(gs.entities, boss); gs.currentBossEntity = boss
        print("    Boss spawned: " .. boss.name)
    end
    print("  [WorldInit - spawnBossAndMinions] Done.")
end

-- Helper: Spawn Enemies (moved from GameplayState)
function WorldInitializer.spawnEnemies(gs, numberOfEnemies)
    print(string.format("  [WorldInit - spawnEnemies] Spawning %d enemies...", numberOfEnemies))
    -- ... (Your existing spawnEnemies logic, using 'gs' instead of 'self')
    -- Example: local enemyX, enemyY = gs.map:getRandomFloorTile()
    --          gs.map:addEntity(enemy); table.insert(gs.entities, enemy)
    local enemyTypes = {SentryBot, DataLeech, FirewallNode, GlitchSwarmer, CipherSentinel, BitRipper}
    local enemyWeights = {3,2,1,2,2,3} -- Example weights
    local weightedTypes = {}
    for i, typeClass in ipairs(enemyTypes) do for w = 1, enemyWeights[i] do table.insert(weightedTypes, typeClass) end end
    local spawnedCount = 0
    for i = 1, numberOfEnemies do
        local enemyX, enemyY = gs.map:getRandomFloorTile()
        if enemyX and enemyY then
            if not gs.map:getEntityAt(enemyX, enemyY) then
                local EnemyClass = Helpers.choice(weightedTypes)
                if EnemyClass then
                    local baseName = "ENEMY"; -- Determine baseName from EnemyClass
                    if EnemyClass == SentryBot then baseName = "SENTRY" elseif EnemyClass == DataLeech then baseName = "LEECH" elseif EnemyClass == FirewallNode then baseName = "FWNODE" elseif EnemyClass == GlitchSwarmer then baseName = "SWARMER" elseif EnemyClass == CipherSentinel then baseName = "CIPHER" elseif EnemyClass == BitRipper then baseName = "RIPPER" end
                    local enemyFullName = baseName .. "_" .. string.format("%02d", i)
                    local enemy = EnemyClass:new(enemyX, enemyY, enemyFullName)
                    gs.map:addEntity(enemy); table.insert(gs.entities, enemy); spawnedCount = spawnedCount + 1
                end
            end
        else break end
    end
    print(string.format("    Spawned %d enemies.", spawnedCount))
end

-- Helper: Spawn Pickups (moved from GameplayState)
function WorldInitializer.spawnPickups(gs, numCaches, numFragments, numNanites, numCells)
    print(string.format("  [WorldInit - spawnPickups] Spawning C:%d, F:%d, N:%d, E:%d", numCaches, numFragments, numNanites or 0, numCells or 0 ))
    -- ... (Your existing spawnPickups logic, using 'gs' instead of 'self')
    -- Example: local x,y = gs.map:getRandomFloorTile()
    --          gs.map:addEntity(Pickup.newSubroutineCache(x,y))
    local spawnedCaches = 0; for i=1,numCaches do local x,y=gs.map:getRandomFloorTile(); if x and y and not gs.map:getEntityAt(x,y) then gs.map:addEntity(Pickup.newSubroutineCache(x,y)); spawnedCaches=spawnedCaches+1 else if not x then break end end end
    local spawnedFragments = 0; for i=1,numFragments do local x,y=gs.map:getRandomFloorTile(); if x and y and not gs.map:getEntityAt(x,y) then gs.map:addEntity(Pickup.newDataFragment(x,y)); spawnedFragments=spawnedFragments+1 else if not x then break end end end
    local spawnedNanites = 0; for i=1,numNanites or 0 do local x,y=gs.map:getRandomFloorTile(); if x and y and not gs.map:getEntityAt(x,y) then gs.map:addEntity(Pickup.newRepairNanites(x,y)); spawnedNanites=spawnedNanites+1 else if not x then break end end end
    local spawnedCells = 0; for i=1,numCells or 0 do local x,y=gs.map:getRandomFloorTile(); if x and y and not gs.map:getEntityAt(x,y) then gs.map:addEntity(Pickup.newEnergyCell(x,y)); spawnedCells=spawnedCells+1 else if not x then break end end end
    print(string.format("    Spawned: %d Caches, %d Frags, %d Nanites, %d Cells", spawnedCaches, spawnedFragments, spawnedNanites, spawnedCells))
end


return WorldInitializer