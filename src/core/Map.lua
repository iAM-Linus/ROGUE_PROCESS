-- src/core/Map.lua
local Helpers = require "src.utils.helpers"

local Tile = _G.Config.tile

local Map = {}
Map.__index = Map

function Map:new(width, height)
    local instance = setmetatable({}, Map)
    instance.width = width or _G.Config.mapWidth
    instance.height = height or _G.Config.mapHeight
    instance.tiles = {} -- 2D array: instance.tiles[y][x]
    instance.entities = {} -- List of all entities on the map (player, enemies, items)
    instance.playerSpawn = {x = 0, y = 0}
    instance.exitPortal = {x = 0, y = 0, char = "X", color = _G.Config.activeColors.accent, active = true}
    instance.floorTiles = {} -- Keep track of floor tile coordinates
    instance.exploredTiles = {} -- exploredTiles[y .. "_" .. x] = true
 
    local genMethod = _G.Config.mapGeneration.method or "random_walk"
    if genMethod == "cellular_automata" then
        instance:generateCellularAutomataMap()
    elseif genMethod == "random_walk" then
        instance:generateRandomWalkMap()
    else
        instance:generateSimpleMap()
    end

    -- Animation properties
    instance.tileAnimations = {} -- For animated tiles
    instance.liquidTiles = {} -- For water/lava animation
    instance.glitchTiles = {} -- For corrupted areas
    instance.discoveryAnimations = {} -- For newly revealed tiles
    instance.ambientParticles = {} -- Environmental particles
    
    -- Initialize some animated elements
    instance:initializeAnimatedTiles()

    return instance
end

function Map:initializeAnimatedTiles()
    -- Find water tiles and make them animated
    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self:getTile(x, y)
            
            -- Add liquid animation to appropriate tiles
            if tile and (tile.quadName == "WATER" or string.find(tile.quadName or "", "WATER")) then
                table.insert(self.liquidTiles, {
                    x = x, y = y,
                    phase = love.math.random() * math.pi * 2,
                    amplitude = love.math.random(0.5, 1.5)
                })
            end
            
            -- Add subtle floor tile breathing
            if tile and tile.walkable and love.math.random() < 0.1 then
                table.insert(self.tileAnimations, {
                    x = x, y = y,
                    type = "breathe",
                    phase = love.math.random() * math.pi * 2,
                    intensity = love.math.random(0.02, 0.05)
                })
            end
        end
    end
    
    -- Add some ambient particles
    for i = 1, 20 do
        table.insert(self.ambientParticles, {
            x = love.math.random(1, self.width) * _G.Config.spriteSize,
            y = love.math.random(1, self.height) * _G.Config.spriteSize,
            vx = love.math.random(-10, 10),
            vy = love.math.random(-15, -5),
            life = love.math.random(2, 6),
            maxLife = love.math.random(2, 6),
            char = love.math.random() < 0.5 and "·" or "∘",
            color = {0.6, 0.8, 1, 0.3}
        })
    end
end

-- --- Cellular Automata Generation ---
function Map:generateCellularAutomataMap()
    local caConf = _G.Config.mapGeneration.ca
    local initialWallChance = caConf.initialWallChance
    local iterations = caConf.iterations
    local birthLimit = caConf.birthLimit
    local survivalLimit = caConf.survivalLimit
    local radius = caConf.neighborhoodRadius

    -- 1. Initialize map with random walls and floors
    self.tiles = {}
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            if x == 1 or x == self.width or y == 1 or y == self.height then -- Border walls
                self.tiles[y][x] = Tile.WALL
            else
                if love.math.random() < initialWallChance then
                    self.tiles[y][x] = Tile.WALL
                else
                    self.tiles[y][x] = Tile.FLOOR
                end
            end
        end
    end

    -- 2. Simulation iterations
    for i = 1, iterations do
        local newTiles = {} -- Create a new grid for the next generation
        for y = 1, self.height do
            newTiles[y] = {}
            for x = 1, self.width do
                if x == 1 or x == self.width or y == 1 or y == self.height then -- Keep borders as walls
                    newTiles[y][x] = Tile.WALL
                    goto continue_cell
                end

                local wallNeighbors = self:_countWallNeighbors(x, y, radius)
                
                if self.tiles[y][x] == Tile.WALL then -- If current cell is a wall
                    if wallNeighbors >= survivalLimit then
                        newTiles[y][x] = Tile.WALL -- Survives
                    else
                        newTiles[y][x] = Tile.FLOOR -- Dies (becomes floor)
                    end
                else -- Current cell is a floor
                    if wallNeighbors > birthLimit then
                        newTiles[y][x] = Tile.WALL -- Born (becomes wall)
                    else
                        newTiles[y][x] = Tile.FLOOR -- Stays floor
                    end
                end
                ::continue_cell::
            end
        end
        self.tiles = newTiles -- Update map with the new generation
    end

    -- 3. Cleanup and Connectivity (Optional but recommended)
    if caConf.ensureConnectivity then
        self:_ensureMapConnectivity(caConf.minCaveSize)
    end
    
    -- 4. Populate floorTiles list (needed for player/exit/item placement)
    self.floorTiles = {}
    for y = 1, self.height do
        for x = 1, self.width do
            if self.tiles[y][x] == Tile.FLOOR then
                table.insert(self.floorTiles, {x = x, y = y})
            end
        end
    end

    if #self.floorTiles == 0 then
        print("ERROR: CA Map generation resulted in no floor tiles! Using failsafe.")
        self:generateSimpleMap() -- Failsafe
        return
    end

    -- 5. Place Player Spawn and Exit (using existing helper or similar logic)
    local spawnIndex = love.math.random(1, #self.floorTiles)
    self.playerSpawn = Helpers.deepCopy(self.floorTiles[spawnIndex]) -- Use deepCopy to avoid modifying original
    table.remove(self.floorTiles, spawnIndex)

    if #self.floorTiles == 0 then -- Edge case: only one floor tile
        self.exitPortal = {x = self.playerSpawn.x, y = self.playerSpawn.y, char="X", color=_G.Config.activeColors.accent}
        print("Warning: Only one floor tile for player and exit.")
    else
        local exitIndex = love.math.random(1, #self.floorTiles)
        self.exitPortal = {
            x = self.floorTiles[exitIndex].x,
            y = self.floorTiles[exitIndex].y,
            char = "X",
            color = _G.Config.activeColors.accent
        }
        table.remove(self.floorTiles, exitIndex)
    end
    
    print(string.format("CA Map generated. Player@(%d,%d), Exit@(%d,%d)",
          self.playerSpawn.x, self.playerSpawn.y, self.exitPortal.x, self.exitPortal.y))
end

function Map:_countWallNeighbors(cx, cy, radius)
    local count = 0
    for y = cy - radius, cy + radius do
        for x = cx - radius, cx + radius do
            if x == cx and y == cy then goto continue_neighbor end -- Skip self

            if x < 1 or x > self.width or y < 1 or y > self.height then
                count = count + 1 -- Count out-of-bounds as walls (helps solidify edges)
            elseif self.tiles[y][x] == Tile.WALL then
                count = count + 1
            end
            ::continue_neighbor::
        end
    end
    return count
end

-- Connectivity Logic (Flood Fill based)
function Map:_ensureMapConnectivity(minCaveSize)
    local regions = {} -- Stores lists of {x,y} coords for each region
    local visited = {} -- visited[y .. "_" .. x] = true

    for y = 1, self.height do
        for x = 1, self.width do
            if self.tiles[y][x] == Tile.FLOOR and not visited[y .. "_" .. x] then
                local currentRegion = {}
                local q = {{x=x, y=y}} -- Queue for flood fill
                visited[y .. "_" .. x] = true
                table.insert(currentRegion, {x=x, y=y})

                local head = 1
                while head <= #q do
                    local cell = q[head]
                    head = head + 1
                    
                    local neighbors = {
                        {x=cell.x+1, y=cell.y}, {x=cell.x-1, y=cell.y},
                        {x=cell.x, y=cell.y+1}, {x=cell.x, y=cell.y-1}
                    }
                    for _, n in ipairs(neighbors) do
                        if n.x >= 1 and n.x <= self.width and n.y >= 1 and n.y <= self.height then
                            if self.tiles[n.y][n.x] == Tile.FLOOR and not visited[n.y .. "_" .. n.x] then
                                visited[n.y .. "_" .. n.x] = true
                                table.insert(q, n)
                                table.insert(currentRegion, n)
                            end
                        end
                    end
                end
                if #currentRegion > 0 then
                    table.insert(regions, currentRegion)
                end
            end
        end
    end

    if #regions == 0 then return end -- No floor regions found

    -- Sort regions by size (largest first)
    table.sort(regions, function(a,b) return #a > #b end)

    -- Keep the largest region, fill others if they are too small or connect them
    local mainRegion = regions[1]
    for i = 2, #regions do
        local region = regions[i]
        if #region < minCaveSize then
            -- Fill small regions with walls
            for _, cell in ipairs(region) do
                self.tiles[cell.y][cell.x] = Tile.WALL
            end
            print("Filled small cave region of size: " .. #region)
        else
            -- For larger disconnected regions, you could implement tunnel carving here.
            -- For now, we'll just keep them if they are large enough, or fill them if not.
            -- A simple approach is to just keep the largest one and fill all others.
            -- For this example, let's fill all but the largest.
            -- More advanced: connect `regions[i]` to `mainRegion` with a tunnel.
            for _, cell in ipairs(region) do
                 self.tiles[cell.y][cell.x] = Tile.WALL
            end
            print("Filled disconnected cave region of size: " .. #region .. " (only keeping largest)")
        end
    end
    -- TODO: Implement tunnel carving between major regions if desired instead of just filling.
end

function Map:generateRandomWalkMap(targetFloorPercent, maxWalkers, stepsPerWalker)
    targetFloorPercent = targetFloorPercent or 0.45 -- Target 45% floor coverage
    maxWalkers = maxWalkers or 10 -- Number of distinct "walks"
    stepsPerWalker = stepsPerWalker or 200 -- Steps each walk takes

    local totalTiles = self.width * self.height
    local desiredFloorTiles = math.floor(totalTiles * targetFloorPercent)
    local currentFloorTiles = 0

    -- 1. Fill map with walls
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = Tile.WALL
        end
    end
    self.floorTiles = {} -- Reset floor tile list

    local walkers = {}
    -- Initialize walkers
    for i = 1, maxWalkers do
        table.insert(walkers, {
            x = love.math.random(2, self.width - 1), -- Start away from edges
            y = love.math.random(2, self.height - 1),
            steps = stepsPerWalker
        })
        -- Carve initial walker position
        if self.tiles[walkers[i].y][walkers[i].x] == Tile.WALL then
             self.tiles[walkers[i].y][walkers[i].x] = Tile.FLOOR
             table.insert(self.floorTiles, {x=walkers[i].x, y=walkers[i].y})
             currentFloorTiles = currentFloorTiles + 1
        end
    end

    local directions = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}} -- Up, Down, Left, Right

    -- 2. Perform walks
    local safetyBreak = maxWalkers * stepsPerWalker * 2 -- Prevent infinite loops
    local currentSteps = 0
    while currentFloorTiles < desiredFloorTiles and currentSteps < safetyBreak do
        for i = 1, #walkers do
            local walker = walkers[i]
            if walker.steps > 0 then
                local dir = Helpers.choice(directions)
                local nextX = Helpers.clamp(walker.x + dir[1], 1, self.width) -- Clamp within bounds
                local nextY = Helpers.clamp(walker.y + dir[2], 1, self.height)

                -- Carve floor tile if it was a wall
                if self.tiles[nextY][nextX] == Tile.WALL then
                    self.tiles[nextY][nextX] = Tile.FLOOR
                    table.insert(self.floorTiles, {x=nextX, y=nextY}) -- Add to list
                    currentFloorTiles = currentFloorTiles + 1
                end

                walker.x = nextX
                walker.y = nextY
                walker.steps = walker.steps - 1
            end
        end
        currentSteps = currentSteps + 1
        -- Check if all walkers are done
        local allDone = true
        for _, w in ipairs(walkers) do if w.steps > 0 then allDone = false; break end end
        if allDone and currentFloorTiles < desiredFloorTiles then
             -- Optional: Restart walkers if target not met? Or just stop. Let's stop for now.
             print("Walkers finished but target floor percent not met.")
             break
        end
        if currentFloorTiles >= desiredFloorTiles then break end -- Stop if target met
    end
    if currentSteps >= safetyBreak then print("Warning: Map gen hit safety break.") end

    -- 3. Place Player Spawn
    if #self.floorTiles == 0 then
        -- Failsafe: create a small room if generation failed badly
        print("ERROR: No floor tiles generated! Creating failsafe room.")
        self:generateSimpleMap() -- Call the old simple room generator as a backup
        return -- Exit early as simple map handles spawn/exit
    end

    local spawnIndex = love.math.random(1, #self.floorTiles)
    self.playerSpawn = self.floorTiles[spawnIndex]
    table.remove(self.floorTiles, spawnIndex) -- Remove spawn point from potential exit/item locations

    -- 4. Place Exit Portal
    local exitIndex = love.math.random(1, #self.floorTiles)
    self.exitPortal = {
        x = self.floorTiles[exitIndex].x,
        y = self.floorTiles[exitIndex].y,
        char = "X",
        color = _G.Config.activeColors.accent
    }
    -- Optional: Ensure exit is far enough from player spawn
    local minExitDist = math.min(self.width, self.height) / 3
    local exitAttempts = 0
    while self:_distance(self.playerSpawn, self.exitPortal) < minExitDist and exitAttempts < 50 do
         exitIndex = love.math.random(1, #self.floorTiles)
         self.exitPortal.x = self.floorTiles[exitIndex].x
         self.exitPortal.y = self.floorTiles[exitIndex].y
         exitAttempts = exitAttempts + 1
    end
    table.remove(self.floorTiles, exitIndex) -- Remove exit point from potential item locations

    print(string.format("Map generated: %d floor tiles. Player@(%d,%d), Exit@(%d,%d)",
          currentFloorTiles + 1, self.playerSpawn.x, self.playerSpawn.y, self.exitPortal.x, self.exitPortal.y))
end

function Map:generateSimpleMap()
    -- Fill with walls
    for y = 1, self.height do
        self.tiles[y] = {}
        for x = 1, self.width do
            self.tiles[y][x] = Tile.WALL
        end
    end

    -- Carve out a simple room
    local roomX = math.floor(self.width / 2) - 5
    local roomY = math.floor(self.height / 2) - 5
    local roomW = 10
    local roomH = 10

    for y = roomY, roomY + roomH - 1 do
        for x = roomX, roomX + roomW - 1 do
            if x > 0 and x <= self.width and y > 0 and y <= self.height then
                self.tiles[y][x] = Tile.FLOOR
            end
        end
    end

    -- Place player spawn in the center of the room
    self.playerSpawn = { x = math.floor(roomX + roomW / 2), y = math.floor(roomY + roomH / 2) }

    -- Place exit portal (simple placement for now)
    local exitX, exitY
    repeat
        exitX = roomX + love.math.random(0, roomW - 1)
        exitY = roomY + love.math.random(0, roomH - 1)
    until (exitX ~= self.playerSpawn.x or exitY ~= self.playerSpawn.y) and self.tiles[exitY][exitX] == Tile.FLOOR
    self.exitPortal.x = exitX
    self.exitPortal.y = exitY

    -- More advanced procedural generation later (e.g., random walker, BSP, cellular automata)
end

function Map:getTile(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return Tile.EMPTY -- Out of bounds
    end
    return self.tiles[y][x]
end

function Map:_distance(p1, p2)
    return math.abs(p1.x - p2.x) + math.abs(p1.y - p2.y)
end

function Map:getRandomFloorTile()
    if #self.floorTiles > 0 then
        local index = love.math.random(1, #self.floorTiles)
        local tileCoord = self.floorTiles[index]
        -- Remove it so we don't place multiple things on the same tile easily
        table.remove(self.floorTiles, index)
        return tileCoord.x, tileCoord.y
    else
        -- Fallback if somehow no floor tiles are left (shouldn't happen often)
        print("Warning: No available floor tiles left for placement.")
        return self.playerSpawn.x + 1, self.playerSpawn.y -- Place near player as fallback
    end
end

function Map:isWalkable(x, y)
    local tile = self:getTile(x, y)
    return tile and tile.walkable
end

function Map:isTransparent(x, y)
    local tile = self:getTile(x, y)
    return tile and tile.transparent
end

function Map:isBlocked(x, y, askingEntity)
    if not self:isWalkable(x, y) then
        return true
    end
    for _, entity in ipairs(self.entities) do
        if entity ~= askingEntity and entity.blocksMovement and entity.x == x and entity.y == y then
            return true
        end
    end
    return false
end

function Map:isExplored(x, y)
    return self.exploredTiles[y .. "_" .. x] == true
end

function Map:addEntity(entity)
    table.insert(self.entities, entity)
    entity.currentMap = self -- Give entity a reference to its map
end

function Map:removeEntity(entityToRemove)
    for i = #self.entities, 1, -1 do -- Iterate backwards when removing
        if self.entities[i] == entityToRemove then
            print("Map: Removing entity: " .. entityToRemove.name) -- DEBUG
            table.remove(self.entities, i)
            return -- Exit once removed
        end
    end
    print("Map:removeEntity - Entity not found to remove: " .. (entityToRemove and entityToRemove.name or "nil")) -- DEBUG
end

function Map:getEntityAt(x, y)
    -- This returns the FIRST entity found at x,y.
    -- Order of insertion into self.entities matters if multiple entities can occupy the same tile (player + pickup).
    for _, entity in ipairs(self.entities) do
        if entity.x == x and entity.y == y then
            -- print("Map:getEntityAt found:", entity.name, "at", x, y) -- Optional debug
            return entity
        end
    end
    return nil
end

function Map:getAllEntities()
    return self.entities
end

function Map:updateAnimations(dt)
    local time = love.timer.getTime()
    
    -- Update discovery animations
    for i = #self.discoveryAnimations, 1, -1 do
        local anim = self.discoveryAnimations[i]
        anim.elapsed = anim.elapsed + dt
        anim.scale = 1 + math.sin(anim.elapsed * 8) * 0.1 * (1 - anim.elapsed / anim.duration)
        anim.alpha = 1 - anim.elapsed / anim.duration
        
        if anim.elapsed >= anim.duration then
            table.remove(self.discoveryAnimations, i)
        end
    end
    
    -- Update ambient particles
    for i = #self.ambientParticles, 1, -1 do
        local particle = self.ambientParticles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.life = particle.life - dt
        particle.color[4] = (particle.life / particle.maxLife) * 0.3
        
        -- Wrap around screen
        if particle.x < 0 then particle.x = self.width * _G.Config.spriteSize end
        if particle.x > self.width * _G.Config.spriteSize then particle.x = 0 end
        if particle.y < 0 then 
            particle.y = self.height * _G.Config.spriteSize
            particle.life = particle.maxLife -- Reset life when wrapping
        end
        
        if particle.life <= 0 then
            -- Respawn particle
            particle.x = love.math.random(1, self.width) * _G.Config.spriteSize
            particle.y = self.height * _G.Config.spriteSize
            particle.life = particle.maxLife
            particle.vx = love.math.random(-10, 10)
            particle.vy = love.math.random(-15, -5)
        end
    end
    
    -- Update glitch effects
    for i = #self.glitchTiles, 1, -1 do
        local glitch = self.glitchTiles[i]
        glitch.elapsed = glitch.elapsed + dt
        glitch.intensity = math.sin(glitch.elapsed * 10) * 0.5 + 0.5
        
        if glitch.elapsed >= glitch.duration then
            table.remove(self.glitchTiles, i)
        end
    end
end

function Map:addGlitchEffect(x, y, duration)
    table.insert(self.glitchTiles, {
        x = x, y = y,
        duration = duration or 2,
        elapsed = 0,
        intensity = 1,
        chars = {"▓", "▒", "░", "█", "▄", "▀", "■", "□"},
        colors = {
            {1, 0.3, 0.8, 0.8},
            {0.3, 1, 0.8, 0.8},
            {0.8, 0.3, 1, 0.8}
        }
    })
end

function Map:addDiscoveryAnimation(x, y)
    table.insert(self.discoveryAnimations, {
        x = x, y = y,
        duration = 0.8,
        elapsed = 0,
        scale = 1,
        alpha = 1
    })
end

function Map:addCorruptionEffects(corruptionLevel)
    if corruptionLevel > 30 and love.math.random() < 0.02 then
        -- Add random glitch effects
        local x = love.math.random(1, self.width)
        local y = love.math.random(1, self.height)
        self:addGlitchEffect(x, y, love.math.random(1, 3))
    end
    
    if corruptionLevel > 60 and love.math.random() < 0.01 then
        -- More intense effects
        for i = 1, 3 do
            local x = love.math.random(1, self.width)
            local y = love.math.random(1, self.height)
            self:addGlitchEffect(x, y, love.math.random(2, 5))
        end
    end
end

function Map:draw(offsetX, offsetY, tileSize)
    love.graphics.setFont(_G.Fonts.large) -- Or a specific map font

    for y = 1, self.height do
        for x = 1, self.width do
            local tile = self:getTile(x, y)
            local screenX = offsetX + (x - 1) * tileSize
            local screenY = offsetY + (y - 1) * tileSize

            love.graphics.setColor(tile.color)
            love.graphics.print(tile.char, screenX + tileSize / 2 - (_G.Fonts.medium:getWidth(tile.char) / 2) , screenY + tileSize / 2 - (_G.Fonts.medium:getHeight() / 2))

            -- Draw exit portal
            if x == self.exitPortal.x and y == self.exitPortal.y then
                love.graphics.setColor(self.exitPortal.color)
                love.graphics.print(self.exitPortal.char, screenX + tileSize / 2 - (_G.Fonts.medium:getWidth(self.exitPortal.char) / 2), screenY + tileSize / 2 - (_G.Fonts.medium:getHeight() / 2))
            end
        end
    end

    -- Draw entities on the map
    for _, entity in ipairs(self.entities) do
        local screenX = offsetX + (entity.x - 1) * tileSize
        local screenY = offsetY + (entity.y - 1) * tileSize
        entity:draw(screenX, screenY, tileSize)
    end
end

function Map:computeFov(playerX, playerY, visionRadius)
    local previouslyVisible = {}
    for k, v in pairs(self.visibleTiles or {}) do
        previouslyVisible[k] = v
    end
    
    -- Existing FOV computation...
    self.visibleTiles = {}
    self.visibleTiles[playerY .. "_" .. playerX] = true
    self.exploredTiles[playerY .. "_" .. playerX] = true

    for octant = 0, 7 do
        self:_castLight(playerX, playerY, visionRadius, 1, 1.0, 0.0, octant)
    end
    
    -- Add discovery animations for newly visible tiles
    for k, v in pairs(self.visibleTiles) do
        if v and not previouslyVisible[k] then
            local y, x = k:match("(%d+)_(%d+)")
            if x and y then
                self:addDiscoveryAnimation(tonumber(x), tonumber(y))
            end
        end
    end
end

function Map:_castLight(cx, cy, radius, row, startSlope, endSlope, octant)
    if startSlope < endSlope then return end -- Invalid slope range

    local radiusSquared = radius * radius
    local gs = _G.GameState.current() -- For logging, if needed

    for i = row, radius do -- For each row (distance from center)
        local dx = -i - 1
        local dy = -i
        local blocked = false
        
        while dx <= 0 do
            dx = dx + 1
            
            -- Translate coordinates to map space based on octant
            local mapX, mapY = self:_transformOctant(cx, cy, dx, dy, octant)

            if mapX < 1 or mapX > self.width or mapY < 1 or mapY > self.height then
                goto continue_loop -- Out of bounds
            end

            local lSlope = (dx - 0.5) / (dy + 0.5)
            local rSlope = (dx + 0.5) / (dy - 0.5)

            if startSlope < rSlope then goto continue_loop end
            if endSlope > lSlope then break end -- Current scan line is beyond the shadow

            -- Check if tile is within vision radius
            if (dx * dx + dy * dy) < radiusSquared then
                self.visibleTiles[mapY .. "_" .. mapX] = true
                self.exploredTiles[mapY .. "_" .. mapX] = true
            end

            if blocked then -- Previous tile in this scan was a wall
                if not self:isTransparent(mapX, mapY) then -- Current tile is also a wall
                    newStart = rSlope
                    goto continue_loop -- Continue scan, but this new shadow starts
                else -- Current tile is a floor, but we are in a shadow
                    blocked = false
                    startSlope = newStart -- Previous wall created a new smaller cone of vision
                end
            else -- Not currently in a shadow cast by a previous tile in this row
                if not self:isTransparent(mapX, mapY) and i < radius then -- Current tile is a wall and not at max radius
                    blocked = true
                    -- Wall hit, recurse for the part of the cone that's still open
                    self:_castLight(cx, cy, radius, i + 1, startSlope, lSlope, octant)
                    newStart = rSlope -- The shadow starts after this wall
                end
            end
            ::continue_loop::
        end -- End while dx <= 0 (scan across the row)
        if blocked then break end -- If the entire row was blocked by its end, no need to go further in this cone
    end
end

function Map:_transformOctant(originX, originY, col, row, octant)
    -- Octant mapping:
    -- 0: E-NE, 1: NE-N, 2: N-NW, 3: NW-W, 4: W-SW, 5: SW-S, 6: S-SE, 7: SE-E
    -- This is a common setup for row-based scanning.
    if octant == 0 then return originX + col, originY - row end
    if octant == 1 then return originX + row, originY - col end
    if octant == 2 then return originX - row, originY - col end
    if octant == 3 then return originX - col, originY - row end
    if octant == 4 then return originX - col, originY + row end
    if octant == 5 then return originX - row, originY + col end
    if octant == 6 then return originX + row, originY + col end
    if octant == 7 then return originX + col, originY + row end
    return originX, originY -- Should not happen
end

function Map:isInFov(x, y)
    if not self.visibleTiles then return true end -- If FOV not computed, assume all visible
    return self.visibleTiles[y .. "_" .. x] == true
end

function Map:drawWithFov(offsetX, offsetY, visualTileSize, playerX, playerY, fovRadius)
    if not self.visibleTiles then self:computeFov(playerX, playerY, fovRadius) end
    
    self:updateAnimations(love.timer.getDelta())
    
    local gameplayState = _G.GameState.current()
    local time = love.timer.getTime()
    
    -- Draw ambient particles first (background layer)
    for _, particle in ipairs(self.ambientParticles) do
        if particle.color[4] > 0 then
            love.graphics.setFont(_G.Fonts.small)
            love.graphics.setColor(particle.color)
            love.graphics.print(particle.char, offsetX + particle.x, offsetY + particle.y)
        end
    end

    for y_map = 1, self.height do
        for x_map = 1, self.width do
            local tileScreenX = offsetX + (x_map - 1) * visualTileSize
            local tileScreenY = offsetY + (y_map - 1) * visualTileSize
            local isVisible = self:isInFov(x_map, y_map)
            local isExplored = self:isExplored(x_map, y_map)

            if isVisible or isExplored then
                local tileDataDef = self:getTile(x_map, y_map)
                local quadData = nil
                local tileColorTint = isVisible and {1,1,1,1} or {0.5,0.5,0.5,1}
                
                -- Apply tile animations
                local animOffset = {x = 0, y = 0}
                local animScale = {x = 1, y = 1}
                local animRotation = 0
                local animAlpha = 1
                
                -- Check for tile-specific animations
                for _, anim in ipairs(self.tileAnimations) do
                    if anim.x == x_map and anim.y == y_map then
                        if anim.type == "breathe" then
                            local breathe = math.sin(time * 2 + anim.phase) * anim.intensity
                            animScale.x = 1 + breathe
                            animScale.y = 1 + breathe
                        end
                    end
                end
                
                -- Check for liquid tile animations
                for _, liquid in ipairs(self.liquidTiles) do
                    if liquid.x == x_map and liquid.y == y_map then
                        animOffset.y = math.sin(time * 3 + liquid.phase) * liquid.amplitude
                        tileColorTint[3] = tileColorTint[3] + math.sin(time * 4 + liquid.phase) * 0.1
                    end
                end

                if tileDataDef.quadName then 
                    quadData = SpriteManager.getQuadData(tileDataDef.quadName) 
                end
                
                if quadData and quadData.quad and quadData.image then
                    love.graphics.push()
                    love.graphics.translate(tileScreenX + visualTileSize/2, tileScreenY + visualTileSize/2)
                    love.graphics.scale(animScale.x, animScale.y)
                    love.graphics.rotate(animRotation)
                    love.graphics.translate(-visualTileSize/2 + animOffset.x, -visualTileSize/2 + animOffset.y)
                    
                    love.graphics.setColor(tileColorTint[1], tileColorTint[2], tileColorTint[3], animAlpha)
                    love.graphics.draw(quadData.image, quadData.quad, 
                                       0, 0, 0,
                                       visualTileSize / quadData.spriteWidth,
                                       visualTileSize / quadData.spriteHeight)
                    love.graphics.pop()
                end
            end

            -- Draw discovery animations
            for _, discovery in ipairs(self.discoveryAnimations) do
                if discovery.x == x_map and discovery.y == y_map and isVisible then
                    love.graphics.push()
                    love.graphics.translate(tileScreenX + visualTileSize/2, tileScreenY + visualTileSize/2)
                    love.graphics.scale(discovery.scale, discovery.scale)
                    
                    love.graphics.setColor(_G.Config.activeColors.accent[1], 
                                          _G.Config.activeColors.accent[2], 
                                          _G.Config.activeColors.accent[3], 
                                          discovery.alpha * 0.6)
                    love.graphics.circle("line", 0, 0, visualTileSize/3)
                    
                    love.graphics.pop()
                end
            end

            -- Draw glitch effects
            for _, glitch in ipairs(self.glitchTiles) do
                if glitch.x == x_map and glitch.y == y_map and isVisible then
                    local glitchChar = glitch.chars[math.floor(glitch.elapsed * 10) % #glitch.chars + 1]
                    local glitchColor = glitch.colors[math.floor(glitch.elapsed * 5) % #glitch.colors + 1]
                    
                    love.graphics.setFont(_G.Fonts.medium)
                    love.graphics.setColor(glitchColor[1], glitchColor[2], glitchColor[3], 
                                          glitchColor[4] * glitch.intensity)
                    love.graphics.print(glitchChar,
                                       tileScreenX + visualTileSize/2 - _G.Fonts.medium:getWidth(glitchChar)/2, 
                                       tileScreenY + visualTileSize/2 - _G.Fonts.medium:getHeight()/2)
                end
            end

            -- Enhanced exit portal with animation
            if x_map == self.exitPortal.x and y_map == self.exitPortal.y and self.exitPortal.active then
                if self:isInFov(x_map, y_map) or self:isExplored(x_map, y_map) then
                    local portalPulse = 0.8 + 0.4 * math.sin(time * 4)
                    local portalRotation = time * 0.5
                    
                    love.graphics.push()
                    love.graphics.translate(tileScreenX + visualTileSize/2, tileScreenY + visualTileSize/2)
                    love.graphics.scale(portalPulse, portalPulse)
                    love.graphics.rotate(portalRotation)
                    
                    -- Portal glow effect
                    love.graphics.setColor(_G.Config.activeColors.accent[1], 
                                          _G.Config.activeColors.accent[2], 
                                          _G.Config.activeColors.accent[3], 0.3)
                    love.graphics.circle("fill", 0, 0, visualTileSize/2)
                    
                    -- Portal sprite or character
                    local exitQuadData = SpriteManager.getQuadData("EXIT_PORTAL_SPRITE")
                    if exitQuadData and exitQuadData.image and exitQuadData.quad then
                        love.graphics.setColor(self:isInFov(x_map,y_map) and _G.Config.activeColors.accent or {0.5,0.5,0.5,1})
                        love.graphics.draw(exitQuadData.image, exitQuadData.quad, 
                                          -visualTileSize/2, -visualTileSize/2, 0,
                                          visualTileSize / exitQuadData.spriteWidth,
                                          visualTileSize / exitQuadData.spriteHeight)
                    else
                        love.graphics.setColor(_G.Config.activeColors.accent)
                        love.graphics.print("◎", -_G.Fonts.medium:getWidth("◎")/2, -_G.Fonts.medium:getHeight()/2)
                    end
                    
                    love.graphics.pop()
                    
                    -- Portal particles
                    for i = 1, 3 do
                        local particleAngle = time * 2 + i * (math.pi * 2 / 3)
                        local particleRadius = 8 + math.sin(time * 3 + i) * 4
                        local particleX = tileScreenX + visualTileSize/2 + math.cos(particleAngle) * particleRadius
                        local particleY = tileScreenY + visualTileSize/2 + math.sin(particleAngle) * particleRadius
                        
                        love.graphics.setColor(_G.Config.activeColors.accent[1], 
                                              _G.Config.activeColors.accent[2], 
                                              _G.Config.activeColors.accent[3], 0.8)
                        love.graphics.circle("fill", particleX, particleY, 2)
                    end
                end
            end
        end
    end

    -- Draw entities with enhanced animations (they have their own draw method)
    for _, entity in ipairs(self.entities) do
        if self:isInFov(entity.x, entity.y) then
            local entityScreenX = offsetX + (entity.x - 1) * visualTileSize
            local entityScreenY = offsetY + (entity.y - 1) * visualTileSize
            entity:draw(math.floor(entityScreenX), math.floor(entityScreenY), visualTileSize)
            
            -- Draw health bar for damaged entities
            if entity.hp and entity.maxHp and entity.hp < entity.maxHp and not entity.isDead then
                entity:drawHealthBar(entityScreenX, entityScreenY, visualTileSize)
            end
        end
    end
end


return Map