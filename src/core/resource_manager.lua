-- src/core/ResourceManager.lua
-- Complete resource management system for fonts, sprites, sounds, shaders
local ResourceManager = {}
ResourceManager.__index = ResourceManager

--- Create new ResourceManager instance
--- @param config table: Configuration object
--- @return ResourceManager: New instance
function ResourceManager:new(config)
    local instance = setmetatable({
        config = config,
        fonts = {},
        sprites = {},
        sounds = {},
        shaders = {},
        canvases = {},
        loaded = false,
        debugMode = false
    }, ResourceManager)
    
    return instance
end

--- Load all resources
function ResourceManager:loadAll()
    if self.loaded then
        print("[ResourceManager] Resources already loaded, skipping")
        return
    end
    
    print("[ResourceManager] Loading all resources...")
    
    local startTime = love.timer.getTime()
    
    self:loadFonts()
    self:loadSprites()
    self:loadSounds()
    self:loadShaders()
    self:loadCanvases()
    
    self.loaded = true
    
    local loadTime = love.timer.getTime() - startTime
    print(string.format("[ResourceManager] All resources loaded in %.3fs", loadTime))
end

--- Load fonts
function ResourceManager:loadFonts()
    if not self.config then
        print("[ResourceManager] WARNING: No config provided, skipping font loading")
        return
    end
    
    local fontPath = self.config.fontPath
    local fontSize = self.config.fontSize or {}
    
    self.fonts = {
        small = love.graphics.newFont(fontPath, fontSize.small or 8),
        medium = love.graphics.newFont(fontPath, fontSize.medium or 10),
        large = love.graphics.newFont(fontPath, fontSize.large or 14),
        title = love.graphics.newFont(fontPath, fontSize.title or 18)
    }
    
    --- Set default font
    love.graphics.setFont(self.fonts.medium)
    
    if self.debugMode then
        print("[ResourceManager] Loaded fonts: small, medium, large, title")
    end
end

--- Load sprites (delegates to SpriteManager)
function ResourceManager:loadSprites()
    --- SpriteManager handles sprite loading
    --- This is a placeholder for future direct sprite management
    if _G.SpriteManager then
        _G.SpriteManager.load()
        if self.debugMode then
            print("[ResourceManager] SpriteManager loaded")
        end
    end
end

--- Load sounds (delegates to SFX system)
function ResourceManager:loadSounds()
    --- SFX system handles procedural sound generation
    --- This is a placeholder for future direct sound management
    if self.debugMode then
        print("[ResourceManager] Sound system ready (procedural)")
    end
end

--- Load shaders
function ResourceManager:loadShaders()
    --- Load composite scanlines shader if available
    local success, shaderModule = pcall(require, "src.utils.compositeScanlines")
    if success and shaderModule then
        self.shaders.compositeScanlines = shaderModule
        if self.debugMode then
            print("[ResourceManager] Loaded shader: compositeScanlines")
        end
    else
        if self.debugMode then
            print("[ResourceManager] Composite scanlines shader not loaded")
        end
    end
end

--- Load canvases
function ResourceManager:loadCanvases()
    if not self.config or not self.config.nativeResolution then
        print("[ResourceManager] WARNING: No native resolution config, skipping canvas creation")
        return
    end
    
    local nativeW = self.config.nativeResolution.width
    local nativeH = self.config.nativeResolution.height
    
    self.canvases.main = love.graphics.newCanvas(nativeW, nativeH)
    self.canvases.main:setFilter("nearest", "nearest")
    
    --- Configure shader if available
    if self.shaders.compositeScanlines then
        self.shaders.compositeScanlines:send("screen", {nativeW, nativeH})
    end
    
    if self.debugMode then
        print(string.format("[ResourceManager] Created main canvas: %dx%d", nativeW, nativeH))
    end
end

--- Get a font by name
--- @param name string: Font name (small, medium, large, title)
--- @return Font: Font object or default
function ResourceManager:getFont(name)
    return self.fonts[name] or self.fonts.medium
end

--- Get all fonts
--- @return table: Table of fonts
function ResourceManager:getFonts()
    return self.fonts
end

--- Get a shader by name
--- @param name string: Shader name
--- @return Shader: Shader object or nil
function ResourceManager:getShader(name)
    return self.shaders[name]
end

--- Get all shaders
--- @return table: Table of shaders
function ResourceManager:getShaders()
    return self.shaders
end

--- Get a canvas by name
--- @param name string: Canvas name
--- @return Canvas: Canvas object or nil
function ResourceManager:getCanvas(name)
    return self.canvases[name]
end

--- Get all canvases
--- @return table: Table of canvases
function ResourceManager:getCanvases()
    return self.canvases
end

--- Get main scene canvas
--- @return Canvas: Main canvas
function ResourceManager:getMainCanvas()
    return self.canvases.main
end

--- Check if resources are loaded
--- @return boolean: True if loaded
function ResourceManager:isLoaded()
    return self.loaded
end

--- Reload all resources (useful for hot-reloading)
function ResourceManager:reload()
    print("[ResourceManager] Reloading resources...")
    self.loaded = false
    self:loadAll()
end

--- Clean up resources
function ResourceManager:cleanup()
    print("[ResourceManager] Cleaning up resources...")
    
    --- Release canvases
    for name, canvas in pairs(self.canvases) do
        if canvas and canvas.release then
            canvas:release()
        end
    end
    
    self.fonts = {}
    self.sprites = {}
    self.sounds = {}
    self.shaders = {}
    self.canvases = {}
    self.loaded = false
    
    --- Force garbage collection
    collectgarbage("collect")
    
    print("[ResourceManager] Cleanup complete")
end

--- Set debug mode
--- @param enabled boolean: Debug mode state
function ResourceManager:setDebugMode(enabled)
    self.debugMode = enabled
end

--- Print debug information
function ResourceManager:printDebugInfo()
    print("\n=== ResourceManager Debug Info ===")
    print(string.format("Loaded: %s", self.loaded and "YES" or "NO"))
    
    print("\nFonts:")
    for name, font in pairs(self.fonts) do
        print(string.format("  - %s: %s", name, font:getHeight()))
    end
    
    print("\nShaders:")
    for name, _ in pairs(self.shaders) do
        print(string.format("  - %s", name))
    end
    
    print("\nCanvases:")
    for name, canvas in pairs(self.canvases) do
        local w, h = canvas:getDimensions()
        print(string.format("  - %s: %dx%d", name, w, h))
    end
    
    print("===================================\n")
end

return ResourceManager