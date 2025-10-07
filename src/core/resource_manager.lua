-- src/core/resource_manager.lua
local ResourceManager = {}
ResourceManager.__index = ResourceManager

function ResourceManager:new()
    return setmetatable({
        fonts = {},
        sprites = {},
        sounds = {},
        shaders = {}
    }, ResourceManager)
end

function ResourceManager:load_fonts()
    local config = ServiceLocator.get("config")
    local font_path = config.font_path
    
    self.fonts = {
        small = love.graphics.newFont(font_path, config.font_size.small),
        medium = love.graphics.newFont(font_path, config.font_size.medium),
        large = love.graphics.newFont(font_path, config.font_size.large),
        title = love.graphics.newFont(font_path, config.font_size.title)
    }
end

function ResourceManager:get_font(name)
    return self.fonts[name] or self.fonts.medium
end