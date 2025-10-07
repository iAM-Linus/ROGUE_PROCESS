-- src/config.lua
local Config = {

    nativeResolution = { width = 640, height = 360 },

    -- Aesthetics
    colors = {
        -- Base colors
        black = { 0.02, 0.02, 0.05, 1 },     -- Deep space black
        dark_grey = { 0.12, 0.12, 0.18, 1 }, -- Rich dark blue-grey
        medium_grey = { 0.25, 0.28, 0.35, 1 }, -- Cool medium grey
        light_grey = { 0.65, 0.68, 0.75, 1 }, -- Light cool grey
        white = { 0.95, 0.97, 1.0, 1 },      -- Slightly blue-tinted white

        -- Accent colors with cyberpunk feel
        electric_blue = { 0.2, 0.6, 1.0, 1 }, -- Bright electric blue
        cyber_cyan = { 0.0, 0.8, 0.9, 1 },    -- Neon cyan
        neon_green = { 0.2, 1.0, 0.4, 1 },    -- Matrix green
        hot_pink = { 1.0, 0.2, 0.6, 1 },      -- Neon pink
        electric_purple = { 0.6, 0.2, 1.0, 1 }, -- Electric purple
        warning_orange = { 1.0, 0.5, 0.1, 1 }, -- Alert orange
        danger_red = { 1.0, 0.2, 0.3, 1 },    -- Danger red

        -- UI specific colors
        panel_bg = { 0.05, 0.05, 0.1, 0.95 },       -- Semi-transparent dark
        panel_bg_light = { 0.08, 0.08, 0.15, 0.9 }, -- Slightly lighter
        panel_border = { 0.3, 0.7, 0.9, 0.8 },      -- Cyan border
        panel_border_active = { 0.0, 0.8, 1.0, 1.0 }, -- Bright cyan

        -- Text hierarchy
        text_primary = { 0.9, 0.92, 0.95, 1 }, -- Primary text
        text_secondary = { 0.7, 0.72, 0.8, 1 }, -- Secondary text
        text_dim = { 0.5, 0.52, 0.6, 0.8 },   -- Dimmed text
        text_accent = { 0.0, 0.8, 0.9, 1 },   -- Accent text (cyan)
        text_success = { 0.2, 1.0, 0.4, 1 },  -- Success (green)
        text_warning = { 1.0, 0.8, 0.2, 1 },  -- Warning (yellow)
        text_error = { 1.0, 0.3, 0.3, 1 },    -- Error (red)

        -- Game element colors
        player_color = { 0.2, 1.0, 0.4, 1 }, -- Bright green for player
        enemy_color = { 1.0, 0.3, 0.3, 1 }, -- Red for enemies
        pickup_color = { 1.0, 0.8, 0.2, 1 }, -- Gold for pickups
        wall_color = { 0.2, 0.25, 0.35, 1 }, -- Dark blue-grey walls
        floor_color = { 0.08, 0.1, 0.15, 1 }, -- Very dark floor

        -- Status colors
        health_good = { 0.2, 1.0, 0.4, 1 }, -- Green health
        health_medium = { 1.0, 0.8, 0.2, 1 }, -- Yellow health
        health_low = { 1.0, 0.3, 0.3, 1 },  -- Red health
        cpu_color = { 0.2, 0.6, 1.0, 1 },   -- Blue for CPU
        shield_color = { 0.6, 0.2, 1.0, 1 }, -- Purple for shields
    },

    -- Visual effects configuration
    visualEffects = {
        enableParticles = true,
        enableScreenShake = true,
        enableGlow = true,
        enableScanlines = false, -- Can be toggled
        enableCRTEffect = false, -- Can be toggled

        -- Animation timings
        menuTransitionTime = 0.3,
        panelFadeTime = 0.2,
        buttonHoverTime = 0.15,

        -- Glow settings
        glowIntensity = 0.5,
        glowSize = 2,

        -- Screen shake settings
        shakeDecay = 0.8,
        maxShakeIntensity = 10,
    },

    -- Enhanced UI settings
    ui = {
        cornerRadius = 4,
        borderWidth = 1,
        panelPadding = 8,
        shadowOffset = 2,

        -- Animation curves (for advanced UI animations)
        easeInOut = function(t) return t * t * (3 - 2 * t) end,
        easeOut = function(t) return 1 - (1 - t) * (1 - t) end,
        easeIn = function(t) return t * t end,
    },
    fontPath = "src/assets/fonts/proggy_font.ttf", -- Placeholder, find a good monospaced font
    fontSize = {
        small = 8,                                 -- CoQ often uses smaller, dense fonts
        medium = 10,
        large = 14,
        title = 18,
    },
    gameViewport = { x = 0, y = 0, width = 0, height = 0 },
    ui_panel_heights = {
        top_bar = 50, -- Increased for better proportions (was 20)
        bottom_bar = 80, -- Increased for message log and controls (was 40)
    },
    ui_panel_widths = {
        left_sidebar = 0, -- Disabled left sidebar for now (was 150)
        right_sidebar = 180 -- Adjusted for minimap and subroutines (was 125)
    },

    spriteSheetPaths = {
        main = "src/assets/sprites/spritesheet.png", -- Give your main tilesheet a proper name
        -- If you had separate sheets as originally discussed:
        -- terrain = "src/assets/sprites/terrain_sheet.png",
        -- player_chars = "src/assets/sprites/player_sheet.png",
        -- enemies = "src/assets/sprites/enemy_sheet.png",
        -- items = "src/assets/sprites/item_sheet.png"
    },

    -- Sprite and Tile Configuration
    spriteSize = 16, -- *** SET THIS TO MATCH SpriteManager.DEFAULT_SPRITE_DIMENSION ***
    tile = {
        -- Update these quadNames to match what you defined in SpriteManager
        FLOOR = { quadName = "FLOOR_GRASS_DARK_TUFT", walkable = true, transparent = true },
        WALL  = { quadName = "WALL_ROCK_BROWN_1", walkable = false, transparent = false },
        EMPTY = { walkable = false, transparent = false }
    },
    mapWidth = 60, -- Adjust based on new spriteSize and desired game view
    mapHeight = 30,
    --tile = { -- Placeholder characters, will depend on your font/tileset
    --    FLOOR = { char = ".", color = {0.2, 0.2, 0.25, 1}, walkable = true, transparent = true },
    --    WALL  = { char = "▓", color = {0.4, 0.4, 0.45, 1}, walkable = false, transparent = false },
    --    EMPTY = { char = " ", color = {0.05, 0.05, 0.08, 1}, walkable = false, transparent = false }
    --},

    -- Map Generation
    mapGeneration = {
        method = "cellular_automata",  -- "random_walk" or "cellular_automata" or "simple"
        ca = {
            initialWallChance = 0.48,  -- Percentage of initial walls (40-55% is common)
            iterations = 4,            -- Number of simulation steps (3-5 is often good)
            birthLimit = 4,            -- A floor cell becomes a wall if it has > birthLimit wall neighbors
            survivalLimit = 3,         -- A wall cell stays a wall if it has >= survivalLimit wall neighbors
            neighborhoodRadius = 1,    -- Usually 1 (3x3 grid) or 2 (5x5 grid)
            ensureConnectivity = true, -- Attempt to connect all floor areas
            minCaveSize = 100,         -- Minimum size for a cave area to be kept after connectivity step
        }
    },

    -- Player
    playerChar = "@", -- or "§"
    playerIntegrity = 100,
    playerCPUCycles = 50,
    playerCPURegen = 1, -- per turn or per second? Let's say per turn for now.

    -- UI
    logMessageCount = 4,
    logMessageDuration = 7, -- seconds

    -- Turn system
    --turnDelay = 0.25, -- Small delay after player action before enemies move
    enemyTurnActionDelay = 0.0,

    sfx = {
        -- UI Sounds
        ui_navigate = { freq = 800, duration = 0.03, wave = "square", volume = 0.3 },
        ui_select = { freq = 1000, duration = 0.05, wave = "sine", volume = 0.4 },
        ui_back = { freq = 600, duration = 0.05, wave = "square", volume = 0.3 },
        ui_error = { freq = 200, duration = 0.15, wave = "sawtooth", volume = 0.4 },

        -- Gameplay Sounds
        player_move = { freq = 500, freqMax = 550, duration = 0.02, wave = "noise", volume = 0.15 }, -- Subtle click/step
        player_attack_hit = { freq = 300, duration = 0.08, wave = "saw", volume = 0.5 },
        player_attack_miss = { freq = 600, duration = 0.05, wave = "sine", volume = 0.3 },           -- Whoosh

        enemy_attack_hit = { freq = 250, duration = 0.1, wave = "square", volume = 0.5 },
        enemy_die = { freq = 150, freqMax = 100, duration = 0.3, wave = "noise", volume = 0.6 }, -- Descending noise burst

        subroutine_activate_generic = { freq = 700, duration = 0.1, wave = "triangle", volume = 0.4 },
        subroutine_activate_offensive = { freq = 900, freqMax = 1200, duration = 0.15, wave = "saw", volume = 0.5 },
        subroutine_activate_defensive = { freq = 600, duration = 0.2, wave = "sine", volume = 0.5 },
        subroutine_fail_cpu = { freq = 220, duration = 0.1, wave = "sawtooth", volume = 0.4 },
        subroutine_fail_cooldown = { freq = 330, duration = 0.08, wave = "square", volume = 0.3 },

        pickup_data_fragment = { freq = 1200, duration = 0.05, wave = "sine", volume = 0.4 },
        pickup_subroutine_cache = { freq = 800, freqMax = 1500, duration = 0.25, wave = "sine", volume = 0.5 }, -- Ascending chirp
        pickup_health = { freq = 700, freqMax = 900, duration = 0.15, wave = "triangle", volume = 0.45 },
        pickup_cpu = { freq = 750, freqMax = 950, duration = 0.15, wave = "sine", volume = 0.45 },

        level_exit = { freq = 1000, duration = 0.3, wave = "sawtooth", volume = 0.5 },
        boss_defeated = { freq = 440, freqMax = 880, duration = 1.0, wave = "sawtooth", volume = 0.7 } -- Longer, ascending
    },
}

-- Choose a color scheme (e.g., green on black)
Config.activeColors = {
    background = Config.colors.black,
    text = Config.colors.text_primary,
    ui_text_default = Config.colors.text_secondary,
    ui_text_dim = Config.colors.text_dim,
    ui_text_highlight = Config.colors.text_primary,
    ui_text_accent = Config.colors.text_accent,

    -- Panel colors
    ui_panel_border = Config.colors.panel_border,
    ui_panel_title = Config.colors.text_accent,

    -- Game elements
    player = Config.colors.player_color,
    enemy = Config.colors.enemy_color,
    pickup = Config.colors.pickup_color,
    wall = Config.colors.wall_color,
    floor = Config.colors.floor_color,

    -- Interactive elements
    highlight = Config.colors.electric_blue,
    accent = Config.colors.cyber_cyan,

    -- Status colors
    ui_text_player_positive = Config.colors.text_success,
    ui_text_enemy_negative = Config.colors.text_error,
    ui_text_neutral_info = Config.colors.text_warning,
}

Config.tile.FLOOR.color = Config.activeColors.floor
Config.tile.WALL.color = Config.activeColors.wall
Config.tile.EMPTY.color = Config.activeColors.background

-- Add visual effect helper functions
Config.fx = {
    -- Pulse effect for UI elements
    pulse = function(time, speed, min, max)
        speed = speed or 2
        min = min or 0.7
        max = max or 1.0
        return min + (max - min) * (0.5 + 0.5 * math.sin(time * speed))
    end,

    -- Lerp function for smooth transitions
    lerp = function(a, b, t)
        return a + (b - a) * t
    end,

    -- Color lerp
    lerpColor = function(color1, color2, t)
        return {
            Config.fx.lerp(color1[1], color2[1], t),
            Config.fx.lerp(color1[2], color2[2], t),
            Config.fx.lerp(color1[3], color2[3], t),
            Config.fx.lerp(color1[4] or 1, color2[4] or 1, t)
        }
    end,

    -- Get appropriate health color based on percentage
    getHealthColor = function(healthPercent)
        if healthPercent > 0.7 then
            return Config.colors.health_good
        elseif healthPercent > 0.3 then
            return Config.colors.health_medium
        else
            return Config.colors.health_low
        end
    end,

    -- Get pulsing color for critical elements
    getCriticalColor = function(time, baseColor)
        local intensity = Config.fx.pulse(time, 4, 0.5, 1.0)
        return {
            baseColor[1] * intensity,
            baseColor[2] * intensity,
            baseColor[3] * intensity,
            baseColor[4] or 1
        }
    end
}

return Config
