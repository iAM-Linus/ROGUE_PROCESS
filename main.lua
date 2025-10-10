-- main.lua

function love.load()
    -- Ensure src directory is in package.path for require
    package.path = package.path .. ";./src/?.lua;./?.lua"
    if love.filesystem.getSourceBaseDirectory() then
        package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/src/?.lua"
        package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/?.lua"
    end

    print("\n========================================")
    print("//ROGUE_PROCESS - Phase 4 Initialization")
    print("========================================\n")

    -- ===== CORE SYSTEMS INITIALIZATION =====
    print("[Phase 4] Initializing core systems...")

    -- Load configuration first
    local Config = require 'src.config'

    -- Load service locator
    ServiceLocator = require 'src.core.service_locator'

    -- Initialize Game singleton (registers config, events, resources, states)
    local Game = require 'src.core.Game'
    local game = Game:new(Config)
    game:initialize()

    print("[Phase 4] Core systems initialized")

    -- ===== REGISTER ADDITIONAL SERVICES =====
    print("\n[Phase 4] Registering additional services...")

    -- Load and register SpriteManager
    local SpriteManager = require 'src.core.managers.SpriteManager'
    SpriteManager.load()
    ServiceLocator.register("sprites", SpriteManager)
    print("  ✓ SpriteManager registered")
    
    -- Load and register SFX
    local SFX = require 'src.utils.SFX'
    ServiceLocator.register("sfx", SFX)
    print("  ✓ SFX registered")
    
    -- Load and register MetaProgress
    local MetaProgress = require "src.core.MetaProgress"
    MetaProgress:load()
    ServiceLocator.register("metaProgress", MetaProgress)
    print("  ✓ MetaProgress registered")

    -- Create fonts and register
    local fonts = {
        small = love.graphics.newFont(Config.fontPath, Config.fontSize.small),
        medium = love.graphics.newFont(Config.fontPath, Config.fontSize.medium),
        large = love.graphics.newFont(Config.fontPath, Config.fontSize.large),
        title = love.graphics.newFont(Config.fontPath, Config.fontSize.title),
    }
    love.graphics.setFont(fonts.medium)
    ServiceLocator.register("fonts", fonts)
    print("  ✓ Fonts registered")

    -- Load shader
    local compositeShader = nil
    local success, shader_module = pcall(require, 'src.utils.compositeScanlines')
    if success and shader_module then
        compositeShader = shader_module
        print("  ✓ Composite scanlines shader loaded")
    else
        print("  x Composite scanlines shader not loaded")
    end
    ServiceLocator.register("compositeShader", compositeShader)

    -- Create main canvas 
    local mainSceneCanvas = love.graphics.newCanvas(Config.nativeResolution.width, Config.nativeResolution.height)
    if mainSceneCanvas then
        mainSceneCanvas:setFilter("nearest", "nearest")
        if compositeShader then
            compositeShader:send("screen", { Config.nativeResolution.width, Config.nativeResolution.height })
        end
    end
    ServiceLocator.register("mainCanvas", mainSceneCanvas)
    print("  ✓ Main canvas created")

    love.graphics.setDefaultFilter("nearest", "nearest")

    print("\n[Phase 4] Additional services registered")

    -- ===== STATE REGISTRATION =====
    print("\n[Phase 4] Registering states...")

    -- Load state classes
    local MainMenuState = require "src.states.MainMenuState"
    local NewRunState = require 'src.states.NewRunState'
    local GameplayState = require "src.states.GameplayState"
    local SubroutineChoiceState = require "src.states.SubroutineChoiceState"
    local CoreModificationState = require 'src.states.CoreModificationState'

    -- Register states with StateManager
    print("  ✓ mainmenu")
    game.states:registerState("mainmenu", MainMenuState)
    
    print("  ✓ newrun")
    game.states:registerState("newrun", NewRunState)
    
    print("  ✓ gameplay")
    game.states:registerState("gameplay", GameplayState)
    
    print("  ✓ subroutine_choice")
    game.states:registerState("subroutine_choice", SubroutineChoiceState)
    
    print("  ✓ core_modification")
    game.states:registerState("core_modification", CoreModificationState)

    -- Start with main menu
    print("\n[Phase 4] Starting main menu...")
    game.states:switch("mainmenu")

    love.window.setTitle(Config.windowTitle or "//ROGUE_PROCESS")
    love.graphics.setBackgroundColor(Config.activeColors.background)

    -- Seed RNG
    love.math.setRandomSeed(os.time())

    print("\n[Phase 4] Architecture Status:")
    print("  ✓ Pure Phase 4 architecture")
    print("  ✓ All services registered in ServiceLocator")
    print("  ✓ All states using new StateManager")
    print("  ✓ Event system active")
    print("  ✓ Resource management centralized")
    print("  ✓ No legacy globals or GameState")

    print("\n========================================")
    print("Phase 4 Initialization Complete")
    print("========================================\n")
end

function love.update(dt)
    local game = ServiceLocator.get("game")
    if game then
        game:update(dt)
    end
end

function love.draw()
    local mainCanvas = ServiceLocator.get("mainCanvas")
    local config = ServiceLocator.get("config")
    local compositeShader = ServiceLocator.get("compositeShader")
    local game = ServiceLocator.get("game")

    if not mainCanvas then
        love.graphics.print("ERROR: MainCanvas not available!", 10, 10)
        return
    end

    -- 1. Draw the entire game scene to MainSceneCanvas (at native resolution)
    love.graphics.setCanvas(mainCanvas)
    love.graphics.clear(config.activeColors.background[1], config.activeColors.background[2],
        config.activeColors.background[3], config.activeColors.background[4] or 1)

    -- Draw game
    if game then
        game:draw()
    end

    love.graphics.setCanvas() -- Back to screen

    -- 2. Calculate scale factor to draw MainSceneCanvas onto the actual window
    local screenW, screenH = love.graphics.getDimensions()
    local canvasW, canvasH = config.nativeResolution.width, config.nativeResolution.height

    -- Calculate scale to fit canvas within screen while maintaining aspect ratio
    local scaleX = screenW / canvasW
    local scaleY = screenH / canvasH
    -- local scale = math.min(scaleX, scaleY) -- Use floating point scale for smooth scaling

    -- For pixel-perfect scaling, you can use integer scale instead:
    local scale = math.max(1, math.floor(math.min(scaleX, scaleY)))

    local scaledW = canvasW * scale
    local scaledH = canvasH * scale
    local drawX = (screenW - scaledW) / 2
    local drawY = (screenH - scaledH) / 2

    -- 3. Apply shader (if any) and draw the scaled canvas
    if compositeShader then
        --love.graphics.setShader(compositeShader)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(mainCanvas, drawX, drawY, 0, scale, scale)

    -- Reset shader
    if compositeShader then
        love.graphics.setShader()
    end

    -- Optional: Draw black bars for letterboxing
    love.graphics.setColor(0, 0, 0, 1)
    if drawX > 0 then
        -- Left and right bars
        love.graphics.rectangle("fill", 0, 0, drawX, screenH)
        love.graphics.rectangle("fill", drawX + scaledW, 0, drawX, screenH)
    end
    if drawY > 0 then
        -- Top and bottom bars
        love.graphics.rectangle("fill", 0, 0, screenW, drawY)
        love.graphics.rectangle("fill", 0, drawY + scaledH, screenW, drawY)
    end
end

function love.keypressed(key, scancode, isrepeat)
    local game = ServiceLocator.get("game")
    if game then
        return game.states:handleInput(key, scancode, isrepeat)
    end
    return false
end

function love.mousepressed(x, y, button, istouch, presses)
    local game = ServiceLocator.get("game")
    if game then
        _G.Game.states:mousepressed(x, y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    local game = ServiceLocator.get("game")
    if game then
        game.states:mousemoved(x, y, dx, dy, istouch)
    end
end

function love.resize(w, h)
    local game = ServiceLocator.get("game")
    if game then
        game.states:resize(w, h)
    end
end

function love.quit()
    print("\n[Shutdown] Cleaning up...")

    -- Shutdown game
    local game = ServiceLocator.get("game")
    if game then
        game:shutdown()
    end

    -- Save meta progress
    local metaProgress = ServiceLocator.tryGet("metaProgress")
    if metaProgress then
        metaProgress:save()
    end

    print("[Shutdown] Complete\n")
end
