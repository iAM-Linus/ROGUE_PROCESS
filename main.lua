function love.load()
    -- Ensure src directory is in package.path for require
    package.path = package.path .. ";./src/?.lua;./?.lua"
    if love.filesystem.getSourceBaseDirectory() then
        package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/src/?.lua"
        package.path = package.path .. ";" .. love.filesystem.getSourceBaseDirectory() .. "/?.lua"
    end

    _G.Config = require "src.config"
    _G.GameState = require "src.states.GameState"
    _G.CompositeShader = nil
    _G.MainSceneCanvas = nil
    _G.SpriteManager = require 'src.core.managers.SpriteManager'
    _G.SFX = require 'src.utils.SFX'
    _G.MetaProgress = require "src.core.MetaProgress"
    _G.MetaProgress:load()

    _G.SelectedAICoreId = _G.MetaProgress:getSelectedAICoreId()

    -- Load Fonts
    _G.Fonts = {
        small = love.graphics.newFont(Config.fontPath, Config.fontSize.small),
        medium = love.graphics.newFont(Config.fontPath, Config.fontSize.medium),
        large = love.graphics.newFont(Config.fontPath, Config.fontSize.large),
        title = love.graphics.newFont(Config.fontPath, Config.fontSize.title),
    }
    love.graphics.setFont(_G.Fonts.medium)

    SpriteManager.load()

    -- Load the shader
    local success, shader_module = pcall(require, "src.utils.compositeScanlines")
    if success and shader_module then
        _G.CompositeShader = shader_module
        print("Composite Scanlines shader loaded.")
    else
        print("ERROR loading composite scanlines shader: " .. tostring(shader_module))
        _G.CompositeShader = nil
    end

    -- Create the main canvas AT NATIVE RESOLUTION
    _G.MainSceneCanvas = love.graphics.newCanvas(Config.nativeResolution.width, Config.nativeResolution.height)
    if _G.MainSceneCanvas then
        _G.MainSceneCanvas:setFilter("nearest", "nearest")
        if _G.CompositeShader then
            _G.CompositeShader:send("screen", {Config.nativeResolution.width, Config.nativeResolution.height})
        end
    end

    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Initialize and register states
    local MainMenuState = require "src.states.MainMenuState"
    local GameplayState = require "src.states.GameplayState"
    local NewRunState = require 'src.states.NewRunState'
    local SubroutineChoiceState = require "src.states.SubroutineChoiceState"
    local CoreModificationState = require 'src.states.CoreModificationState'

    GameState.register("mainmenu", MainMenuState:new())
    GameState.register("newrun", NewRunState:new())
    GameState.register("gameplay", GameplayState:new())
    GameState.register("subroutine_choice", SubroutineChoiceState:new())
    GameState.register("core_modification", CoreModificationState:new())

    -- Start with the main menu
    GameState.switch("mainmenu")

    love.window.setTitle(Config.windowTitle or "//ROGUE_PROCESS")
    love.graphics.setBackgroundColor(Config.activeColors.background)

    -- Seed RNG
    love.math.setRandomSeed(os.time())
end

function love.update(dt)
    GameState.update(dt)
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

function love.keypressed(key, scancode, isrepeat)
    local handled_by_state = GameState.keypressed(key, scancode, isrepeat)
    
    if not handled_by_state and key == 'escape' then
        local current_state_object = GameState.current()
        local main_menu_object = GameState.get("mainmenu")

        if current_state_object ~= main_menu_object then
            print("Global Escape pressed, switching to Main Menu.")
            local gameplay = GameState.get("gameplay")
            if gameplay then gameplay.isInitialized = false end
            GameState.switch("mainmenu")
        end
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    GameState.mousepressed(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    GameState.mousemoved(x, y, dx, dy, istouch)
end

function love.resize(w, h)
    if w == 0 or h == 0 then return end

    -- MainSceneCanvas size doesn't change, only the scaling changes
    if _G.CompositeShader then
        -- The shader's screen uniform stays the same (canvas size)
        -- but you could send new screen dimensions if needed for other effects
    end

    if GameState then GameState.resize(w, h) end
end

function love.quit()
    print("Shutting down //ROGUE_PROCESS. Goodbye!")
    if _G.MetaProgress then
        _G.MetaProgress:save()
    end
end