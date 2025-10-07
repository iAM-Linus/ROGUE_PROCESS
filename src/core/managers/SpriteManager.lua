-- src/core/SpriteManager.lua
local SpriteManager = {}

SpriteManager.tilesheets = {} -- Will store {image, spriteWidth, spriteHeight, sourceWidth, sourceHeight}
SpriteManager.quads = {}      -- Will store {quad, image, spriteWidth, spriteHeight} for each named sprite

-- *** IMPORTANT: SET THIS TO THE DIMENSION OF A SINGLE SPRITE ON YOUR NEW SHEET ***
SpriteManager.DEFAULT_SPRITE_DIMENSION = 16 -- Assuming 10x10 pixels per sprite

-- Call this once in love.load()
function SpriteManager.load()
    local function loadImageAndDefineSheet(sheetName, path, spriteDefaultW, spriteDefaultH)
        local success, img = pcall(love.graphics.newImage, path)
        if not success or not img then
            error("Failed to load tilesheet image: " .. path .. " - " .. tostring(img))
            return nil
        end
        img:setFilter("nearest", "nearest")
        local iw, ih = img:getDimensions()
        SpriteManager.tilesheets[sheetName] = {
            image = img,
            spriteWidth = spriteDefaultW,
            spriteHeight = spriteDefaultH,
            sourceWidth = iw,
            sourceHeight = ih
        }
        print("Loaded tilesheet: " .. sheetName .. " (" .. path .. ")")
        return SpriteManager.tilesheets[sheetName]
    end

    -- Load your main new tilesheet
    -- Replace "input_file_0.png" with the actual name you save it as, e.g., "tileset_coq.png"
    local mainSheet = loadImageAndDefineSheet("main", _G.Config.spriteSheetPaths.main,
                                            SpriteManager.DEFAULT_SPRITE_DIMENSION, 
                                            SpriteManager.DEFAULT_SPRITE_DIMENSION)
    
    if not mainSheet then return end -- Stop if main sheet failed to load

    -- Helper function to create quads from the mainSheet
    local function newMainQuad(gridX, gridY)
        return love.graphics.newQuad(gridX * mainSheet.spriteWidth, gridY * mainSheet.spriteHeight, 
                                     mainSheet.spriteWidth, mainSheet.spriteHeight, 
                                     mainSheet.sourceWidth, mainSheet.sourceHeight)
    end

    -- Function to add a quad definition
    local function addQuad(name, sheet, gridX, gridY)
        if not sheet then print("Warning: Sheet not loaded for quad: " .. name); return end
        SpriteManager.quads[name] = {
            quad = newMainQuad(gridX, gridY), -- Assuming newMainQuad uses mainSheet's dimensions
            image = sheet.image,
            spriteWidth = sheet.spriteWidth,
            spriteHeight = sheet.spriteHeight
        }
    end

    -- === Define your quads from input_file_0.png ===
    -- These are VISUAL ESTIMATES. You MUST verify these (col, row) coordinates.
    -- (0,0) is the top-leftmost sprite.

    -- Terrain (Examples from top-left of your sheet)
    addQuad("FLOOR_GRASS_DARK_TUFT", mainSheet, 0, 0)  -- Dark green with tufts
    addQuad("FLOOR_GRASS_LIGHT_TUFT", mainSheet, 5, 0) -- Lighter green with tufts
    addQuad("TREE_GREEN_1", mainSheet, 0, 1)          -- A small green tree
    addQuad("TREE_GREEN_2", mainSheet, 1, 1)          -- Another small green tree
    addQuad("WALL_ROCK_BROWN_1", mainSheet, 0, 13)     -- Brownish rock wall texture
    addQuad("FLOOR_CAVE_1", mainSheet, 0, 2)          -- Dark cave floor
    addQuad("WALL_BRICK_RED", mainSheet, 8, 0)        -- Red brick wall from a different section
    addQuad("FLOOR_WOOD_PLANKS", mainSheet, 8, 2)     -- Wooden plank floor

    -- Player Characters (Examples - find suitable sprites)
    -- Let's pick a few humanoid figures from around column 20-25, row 2-4
    addQuad("PLAYER_DEFAULT", mainSheet, 25, 0)      -- Example: A figure in simple clothes
    addQuad("PLAYER_ASSAULT", mainSheet, 26, 0) -- Example: A figure with some armor/weapon
    addQuad("PLAYER_STEALTH", mainSheet, 30, 1) -- Example: A figure that looks more agile
    SpriteManager.quads.PLAYER_STD = SpriteManager.quads.PLAYER_DEFAULT -- Alias

    -- Enemies (Examples - find suitable sprites)
    -- Many creature-like sprites from column 20 onwards
    addQuad("SENTRY_BOT_SPRITE", mainSheet, 31, 6)    -- Example: A robotic looking one
    addQuad("DATA_LEECH_SPRITE", mainSheet, 28, 8)    -- Example: A more abstract/slimy one
    addQuad("FIREWALL_NODE_SPRITE", mainSheet, 30, 6) -- Example: A blocky/techy structure
    addQuad("GLITCH_SWARMER_SPRITE", mainSheet, 30, 5) -- Example: A small, glitchy looking sprite
    addQuad("CIPHER_SENTINEL_SPRITE", mainSheet, 27, 9)-- Example: A more imposing humanoid
    addQuad("BIT_RIPPER_SPRITE", mainSheet, 25, 5)    -- Example: An agile/ranged looking figure
    addQuad("BOSS_GUARDIAN_SPRITE", mainSheet, 31, 6) -- Example: A larger, distinct figure

    -- Pickups (Examples)
    addQuad("SUBROUTINE_CACHE_QUAD", mainSheet, 10, 6) -- Example: A chest-like object
    addQuad("DATA_FRAGMENT_QUAD", mainSheet, 22, 4)  -- Example: A small crystal/chip (near currency symbols)
    addQuad("REPAIR_NANITES_QUAD", mainSheet, 34, 10) -- Example: A heart symbol
    addQuad("ENERGY_CELL_QUAD", mainSheet, 32, 13)    -- Example: A potion/flask (blue one)
    
    -- Map Objects
    addQuad("TOMBSTONE_SPRITE", mainSheet, 0, 15)
    addQuad("EXIT_PORTAL_SPRITE", mainSheet, 1, 9)  -- Example: The pentagram or a distinct portal
    addQuad("DOOR_CLOSED", mainSheet, 9, 4)          -- Example: A wooden door
    addQuad("DOOR_OPEN", mainSheet, 10, 4)           -- Example: An open wooden door

    -- UI Elements / Font Characters (The bottom right of your sheet has a font)
    -- If you want to use this sheet AS a font for some UI text:
    -- addQuad("FONT_A", mainSheet, 48, 23); addQuad("FONT_B", mainSheet, 49, 23); ...

    print("SpriteManager: Main tilesheet loaded and example quads defined.")
    print("  IMPORTANT: Verify all quad coordinates (col, row) in SpriteManager.lua against your sheet!")
end

function SpriteManager.getQuadData(name)
    local quadData = SpriteManager.quads[name]
    if not quadData then
        print("Warning: QuadData not found for name: '" .. tostring(name) .. "'. Using fallback character.")
        -- You could return a default "missing sprite" quadData here if you define one
    end
    return quadData
end

return SpriteManager