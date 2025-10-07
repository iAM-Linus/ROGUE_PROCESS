-- main.lua

-- Configuration: Set to true to use migrated states
local USE_NEW_MAIN_MENU = true  -- MainMenuState migrated
local USE_NEW_NEWRUN = false     -- Not yet migrated
local USE_NEW_GAMEPLAY = false   -- Not yet migrated

function love.load()
    -- Ensure src directory is in package.path for require
    package.path = package.path .. ";./src/?.lua;./?.lua"
    if love.filesystem.getSourceBaseDirectory() then
        package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/src/?.lua"
        package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/?.lua"
    end

    print("\n========================================")
    print("//ROGUE_PROCESS - Phase 2 Initialization")
    print("========================================\n")

    -- ===== EXISTING GLOBAL SYSTEMS (Legacy - Still needed) =====
    print("[Legacy] Loading existing global systems...")
    
    _G.Config = require "src.config"
    _G.GameState = require "src.states.GameState"  -- Keep for non-migrated states
    _G.CompositeShader = nil
    _G.MainSceneCanvas = nil
    _G.SpriteManager = require 'src.core.managers.SpriteManager'
    _G.SFX = require 'src.utils.SFX'
    _G.MetaProgress = require "src.core.MetaProgress"
    _G.MetaProgress:load()
    _G.SelectedAICoreId = _G.MetaProgress:getSelectedAICoreId()

    -- Load Fonts (Legacy)
    _G.Fonts = {
        small = love.graphics.newFont(_G.Config.fontPath, _G.Config.fontSize.small),
        medium = love.graphics.newFont(_G.Config.fontPath, _G.Config.fontSize.medium),
        large = love.graphics.newFont(_G.Config.fontPath, _G.Config.fontSize.large),
        title = love.graphics.newFont(_G.Config.fontPath, _G.Config.fontSize.title),
    }
    love.graphics.setFont(_G.Fonts.medium)

    -- Load SpriteManager (Legacy)
    _G.SpriteManager.load()

    -- Load shader (Legacy)
    local success, shader_module = pcall(require, "src.utils.compositeScanlines")
    if success and shader_module then
        _G.CompositeShader = shader_module
        print("[Legacy] Composite Scanlines shader loaded.")
    else
        print("[Legacy] Composite scanlines shader not loaded")
        _G.CompositeShader = nil
    end

    -- Create main canvas (Legacy)
    _G.MainSceneCanvas = love.graphics.newCanvas(_G.Config.nativeResolution.width, _G.Config.nativeResolution.height)
    if _G.MainSceneCanvas then
        _G.MainSceneCanvas:setFilter("nearest", "nearest")
        if _G.CompositeShader then
            _G.CompositeShader:send("screen", {_G.Config.nativeResolution.width, _G.Config.nativeResolution.height})
        end
    end

    love.graphics.setDefaultFilter("nearest", "nearest")
    
    print("[Legacy] Legacy systems initialized\n")

    -- ===== NEW GAME SINGLETON (Phase 2) =====
    print("[Phase 2] Initializing new Game singleton...")
    
    local Game = require "src.core.Game"
    _G.Game = Game:new(_G.Config)
    _G.Game:initialize()
    
    -- Optional: Enable debug mode
    -- _G.Game:setDebugMode(true)
    
    print("[Phase 2] Game singleton initialized")
    
    -- ===== STATE REGISTRATION (Phase 2) =====
    print("\n[Phase 2] Registering states...")
    
    -- Load state classes
    local MainMenuState_Legacy = require "src.states.MainMenuState"
    local NewRunState = require 'src.states.NewRunState'
    local GameplayState = require "src.states.GameplayState"
    local SubroutineChoiceState = require "src.states.SubroutineChoiceState"
    local CoreModificationState = require 'src.states.CoreModificationState'
    
    -- Register with legacy GameState (for non-migrated states)
    print("[Phase 2] Registering with legacy GameState...")
    
    if USE_NEW_MAIN_MENU then
        -- Use migrated MainMenuState with legacy system (temporary bridge)
        -- This lets migrated state work with old system during transition
        print("  - mainmenu: MIGRATED version (via legacy bridge)")
        _G.GameState.register("mainmenu", MainMenuState_Legacy:new(_G.Game))
    else
        print("  - mainmenu: Legacy version")
        _G.GameState.register("mainmenu", MainMenuState_Legacy:new())
    end
    
    _G.GameState.register("newrun", NewRunState:new())
    _G.GameState.register("gameplay", GameplayState:new())
    _G.GameState.register("subroutine_choice", SubroutineChoiceState:new())
    _G.GameState.register("core_modification", CoreModificationState:new())
    
    -- Also register with new StateManager (for future use)
    print("\n[Phase 2] Registering with new StateManager...")
    if USE_NEW_MAIN_MENU then
        print("  - mainmenu: MIGRATED version")
        _G.Game.states:registerState("mainmenu", MainMenuState_Legacy)
    end
    -- Other states will be registered as they're migrated
    
    -- Start with main menu
    print("\n[Phase 2] Starting main menu...")
    _G.GameState.switch("mainmenu")

    love.window.setTitle(_G.Config.windowTitle or "//ROGUE_PROCESS")
    love.graphics.setBackgroundColor(_G.Config.activeColors.background)

    -- Seed RNG
    love.math.setRandomSeed(os.time())
    
    print("\n[Phase 2] Migration Status:")
    print("  MainMenuState: " .. (USE_NEW_MAIN_MENU and "✓ MIGRATED" or "○ Legacy"))
    print("  NewRunState: " .. (USE_NEW_NEWRUN and "✓ MIGRATED" or "○ Legacy"))
    print("  GameplayState: " .. (USE_NEW_GAMEPLAY and "✓ MIGRATED" or "○ Legacy"))
    print("  Other States: ○ Legacy")
    
    print("\n========================================")
    print("Phase 2 Initialization Complete")
    print("========================================\n")
end

function love.update(dt)
    -- Update legacy system (currently active)
    _G.GameState.update(dt)
    
    -- Update new system (ready for use)
    if _G.Game then
        _G.Game:update(dt)
    end
end

function love.draw()
    if not _G.MainSceneCanvas then
        love.graphics.print("ERROR: MainSceneCanvas not available!", 10, 10)
        if GameState then GameState.draw() end
        return
    end

    -- 1. Draw the entire game scene to MainSceneCanvas (at native resolution)
    love.graphics.setCanvas(_G.MainSceneCanvas)
    love.graphics.clear(Config.activeColors.background[1], Config.activeColors.background[2], 
                       Config.activeColors.background[3], Config.activeColors.background[4] or 1)
    
    GameState.draw() -- All game drawing happens here, using native coordinates
    
    love.graphics.setCanvas() -- Back to screen

    -- 2. Calculate scale factor to draw MainSceneCanvas onto the actual window
    local screenW, screenH = love.graphics.getDimensions()
    local canvasW, canvasH = Config.nativeResolution.width, Config.nativeResolution.height
    
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
    if _G.CompositeShader then
        --love.graphics.setShader(_G.CompositeShader)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(_G.MainSceneCanvas, drawX, drawY, 0, scale, scale)
    
    -- Reset shader
    if _G.CompositeShader then
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

--function love.keypressed(key, scancode, isrepeat)
--    local handled_by_state = GameState.keypressed(key, scancode, isrepeat)
--    
--    if not handled_by_state and key == 'escape' then
--        local current_state_object = GameState.current()
--        local main_menu_object = GameState.get("mainmenu")
--
--        if current_state_object ~= main_menu_object then
--            print("Global Escape pressed, switching to Main Menu.")
--            local gameplay = GameState.get("gameplay")
--            if gameplay then gameplay.isInitialized = false end
--            GameState.switch("mainmenu")
--        end
--    end
--end

function love.keypressed(key, scancode, isrepeat)
    -- Handle input through legacy system (currently active)
    local handled = _G.GameState.keypressed(key, scancode, isrepeat)
    
    -- Also pass to new system (for debug shortcuts, etc.)
    if _G.Game and not handled then
        handled = _G.Game:handleInput(key, scancode, isrepeat)
    end
    
    return handled
end

function love.mousepressed(x, y, button, istouch, presses)
    -- Legacy system
    _G.GameState.mousepressed(x, y, button, istouch, presses)
    
    -- New system
    if _G.Game then
        _G.Game:mousepressed(x, y, button, istouch, presses)
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    -- Legacy system
    _G.GameState.mousemoved(x, y, dx, dy, istouch)
    
    -- New system
    if _G.Game then
        _G.Game:mousemoved(x, y, dx, dy, istouch)
    end
end

function love.resize(w, h)
    -- Legacy system
    _G.GameState.resize(w, h)
    
    -- New system
    if _G.Game then
        _G.Game:resize(w, h)
    end
end

function love.quit()
    print("\n[Shutdown] Cleaning up...")
    
    -- Shutdown new system
    if _G.Game then
        _G.Game:shutdown()
    end
    
    -- Save legacy meta progress
    if _G.MetaProgress then
        _G.MetaProgress:save()
    end
    
    print("[Shutdown] Complete\n")
end