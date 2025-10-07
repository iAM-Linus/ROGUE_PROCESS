-- src/core/CameraManager.lua
local Helpers = require "src.utils.helpers"
local Config = _G.Config -- Assuming global

local CameraManager = {}
CameraManager.__index = CameraManager

function CameraManager:new(initialX, initialY)
    local instance = setmetatable({}, CameraManager)
    instance.x = initialX or 0
    instance.y = initialY or 0
    instance.targetX = initialX or 0
    instance.targetY = initialY or 0
    instance.shake = 0
    instance.offsetX = 0 -- For shake
    instance.offsetY = 0 -- For shake
    print("CameraManager initialized.")
    return instance
end

function CameraManager:update(dt, player, gameViewport, map)
    if not player or not gameViewport or not map then return end

    local viewW, viewH = gameViewport.width, gameViewport.height
    if viewW == 0 or viewH == 0 then 
        viewW, viewH = love.graphics.getDimensions() -- Fallback, should use native if possible
        if Config and Config.nativeResolution then
            viewW, viewH = Config.nativeResolution.width, Config.nativeResolution.height
        end
    end

    local mapPixelWidth = map.width * Config.spriteSize
    local mapPixelHeight = map.height * Config.spriteSize

    self.targetX = player.x * Config.spriteSize - viewW / 2 + Config.spriteSize / 2
    self.targetY = player.y * Config.spriteSize - viewH / 2 + Config.spriteSize / 2

    self.targetX = Helpers.clamp(self.targetX, 0, math.max(0, mapPixelWidth - viewW))
    self.targetY = Helpers.clamp(self.targetY, 0, math.max(0, mapPixelHeight - viewH))

    local lerpFactor = 5 * dt
    self.x = self.x + (self.targetX - self.x) * lerpFactor
    self.y = self.y + (self.targetY - self.y) * lerpFactor
    
    if self.shake > 0 then
        self.shake = self.shake - dt * 10 
        if self.shake < 0 then self.shake = 0 end
        self.offsetX = (love.math.random() * 2 - 1) * self.shake
        self.offsetY = (love.math.random() * 2 - 1) * self.shake
    else
        self.offsetX = 0
        self.offsetY = 0
    end
end

function CameraManager:centerOn(targetTileX, targetTileY, gameViewport, map, instant)
    if not gameViewport or not map or not targetTileX or not targetTileY then
        print("CameraManager:centerOn - missing arguments or viewport/map not ready.")
        return
    end
    local viewW, viewH = gameViewport.width, gameViewport.height
    if viewW == 0 or viewH == 0 then
        print("CameraManager:centerOn - viewport dimensions are zero.")
        -- Potentially use Config.nativeResolution as a fallback if gameViewport isn't ready
        -- viewW, viewH = Config.nativeResolution.width, Config.nativeResolution.height
        return -- Or simply don't center if viewport is invalid
    end

    local mapPixelWidth = map.width * Config.spriteSize
    local mapPixelHeight = map.height * Config.spriteSize

    self.targetX = targetTileX * Config.spriteSize - viewW / 2 + Config.spriteSize / 2
    self.targetY = targetTileY * Config.spriteSize - viewH / 2 + Config.spriteSize / 2
    self.targetX = Helpers.clamp(self.targetX, 0, math.max(0, mapPixelWidth - viewW))
    self.targetY = Helpers.clamp(self.targetY, 0, math.max(0, mapPixelHeight - viewH))

    if instant then
        self.x = self.targetX
        self.y = self.targetY
    end
end

function CameraManager:triggerShake(intensity)
    self.shake = math.max(self.shake, intensity or 5)
end

function CameraManager:getDrawOffsets()
    return -self.x + self.offsetX, -self.y + self.offsetY
end

function CameraManager:getWorldCoordinates() -- To know what the camera is looking at
    return self.x, self.y
end

return CameraManager